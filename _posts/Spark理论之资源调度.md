记录Spark1.6.3源码分析在客户端以cluster模式提交Application时集群中的资源调度过程

# 基础理论

引例: Master总经理、Worker项目经理、Executor程序员、Driver客户.

交互: Master、Worker、Driver三者会沟通，Driver、Worker、Executor三者也会沟通；但Master不会直接和Excecutor沟通.

注册: Master接受Worker、Driver、Application的注册；而Executor是向Driver的SchedulerBackend(SparkDeploySchedulerBackend)注册，并非是Master.


# 资源调度流程

## Worker反向注册

1. 集群启动，Worker主动向Master反向注册当前Worker节点所管理的本地资源信息（这样设计的好处: 生产环境下添加新Worker节点到运行中的Spark集群中时，不需要重启集群）.

```java
package org.apache.spark.deploy.worker

/** Worker节点启动反向注册给Master */
private[deploy] class Worker(...) extends ThreadSafeRpcEndpoint {

  //Worker启动后调用onStart()
  override def onStart() {
    assert(!registered)
    createWorkDir()
    shuffleService.startIfEnabled()
    webUi = new WorkerWebUI(this, workDir, webUiPort)
    webUi.bind()
    //然后调用registerWithMaster()注册给Master
    registerWithMaster()
    ...
  }

  private def registerWithMaster() {
    /*onDisconnected()可能会被多次触发，所以如果有未完成的注册尝试，请不要尝试注册
    override def onDisconnected(remoteAddress: RpcAddress): Unit = {
      if (master.exists(_.address == remoteAddress)) {
        connected = false
        registerWithMaster()
      }
    }*/
    registrationRetryTimer match {
      case None =>
        registered = false
        //调用tryRegisterAllMasters()
        registerMasterFutures = tryRegisterAllMasters()
        ...
    }
  }

  /** 连接Master */
  private def tryRegisterAllMasters(): Array[JFuture[_]] = {
    masterRpcAddresses.map { masterAddress =>
      registerMasterThreadPool.submit(new Runnable {
        override def run(): Unit = {
          try {
          val masterEndpoint =
            rpcEnv.setupEndpointRef(Master.SYSTEM_NAME, masterAddress, Master.ENDPOINT_NAME)
          //连接Master，发送注册信息
          registerWithMaster(masterEndpoint)
          } catch {
            case ie: InterruptedException =>
            case NonFatal(e) => //Failed connect to master
          }
        }
      })
    }
  }

  //上面空参数registerWithMaster()的重载，发送资源信息
  private def registerWithMaster(masterEndpoint: RpcEndpointRef): Unit = {
    /*Worker发送一个RegisterWorker的case class（资源信息）到Master的masterEndpoint
    case class RegisterWorker(...) extends DeployMessage {
      //先判断host是否空值、port是否>0
      Utils.checkHost(host, "Required hostname")
      assert (port > 0)
    }*/
    masterEndpoint.ask[RegisterWorkerResponse](RegisterWorker(
      workerId, host, port, self, cores, memory, webUi.boundPort, publicAddress))
      .onComplete {
        //This is a very fast action so we can use "ThreadUtils.sameThread"
        case Success(msg) =>
          //get register response msg
        case Failure(e) =>
          //Cannot register with master
          System.exit(1)
    }(ThreadUtils.sameThread)
  }
}
```

2. Master接收到注册请求后先判断是否可以注册，然后将可注册Worker的注册信息写入Master进程的数据结构``HashSet``里: ``val workers = new HashSet[WorkerInfo]``（Worker节点的个数决定HashSet的大小），这样Master就掌握了当前Spark集群的资源信息（每个Worker有多少资源可供使用）.

```java
package org.apache.spark.deploy.master

private[deploy] class Master(...) extends ThreadSafeRpcEndpoint with LeaderElectable {

  /** Master接收到Worker注册的请求后，一系列条件判断是否可以注册 */
  override def receiveAndReply(context: RpcCallContext): PartialFunction[Any, Unit] = {
    case RegisterWorker(...) => {
      if (state == RecoveryState.STANDBY) {
        //当前Master处于Standby状态，无法注册
        context.reply(MasterInStandby)
      } else if (idToWorker.contains(id)) {
        //idToWorker = new HashMap[String, WorkerInfo]中已有该Worker注册信息，不会重复注册
        //case class RegisterWorkerFailed(message: String)
        context.reply(RegisterWorkerFailed("Duplicate worker ID"))
      } else {
        //Master决定接受Worker的注册，先创建WorkerInfo对象保存注册的Worker信息
        val worker = new WorkerInfo(id, workerHost, workerPort, cores, memory,
        workerRef, workerUiPort, publicAddress)
        //调用registerWorker()执行具体的注册过程
        if (registerWorker(worker)) {
          persistenceEngine.addWorker(worker)
          /*通过持久化引擎（ZooKeeper）将注册信息持久化
          abstract class PersistenceEngine {
            final def addWorker(worker: WorkerInfo): Unit = {
              persist("worker_" + worker.id, worker)
            }
          }*/
          //正常注册逻辑
          context.reply(RegisteredWorker(self, masterWebUiUrl))
          //新Worker节点加入集群调用schedule()（新应用提交或集群可用资源发生改变都会调用这个方法）
          schedule()
        } else {
          //Worker处于DEAD状态会被过滤掉
          //UNKNOWN状态会调用removeWorker()清理（包括Executor和Driver）
          val workerAddress = worker.endpoint.address
          context.reply(RegisterWorkerFailed("re-register worker at same address")
        }
      }
    }
  }
}

/** Worker注册信息 */
private[spark] class WorkerInfo(
  val id: String,
  val host: String,
  val port: Int,
  val cores: Int,  //worker管理的core
  val memory: Int, //worker管理的内存
  val endpoint: RpcEndpointRef,
  val webUiPort: Int,
  val publicAddress: String
) {...}
```

## Worker启动Driver进程

3. 在客户端以cluster模式运行``./spark-submit --master hdfs://spark1:7077 --deploy-mode cluster ../lib/FilterCount.jar``提交应用后，首先在客户端启动一个``spark-submit``进程， 然后该进程携带Driver启动所需资源信息向Master请求启动一个Driver进程``RequestSubmitDriver()``，将资源信息写入Master的数据结构``ArrayBuffer``中，同时触发``schedule()``，发送启动Driver的消息``LaunchDriver``给Worker.

```java
/** cluster模式提交时这个数据结构中才有数据,client模式下waitingDrivers中无数据 */
private[deploy] class Master(...) {
  private val waitingDrivers = new ArrayBuffer[DriverInfo]
}

private[deploy] class DriverInfo(
  val startTime: Long,
  val id: String,
  val desc: DriverDescription,
  val submitDate: Date
)
```

```java
package org.apache.spark.deploy.master

private[deploy] class Master(...) extends ThreadSafeRpcEndpoint with LeaderElectable {

 case RequestSubmitDriver(description) => {
    if (state != RecoveryState.ALIVE) {
      context.reply(SubmitDriverResponse(self, false, None, msg))
    } else {
      //Driver successfully submitted
      val driver = createDriver(description)
      persistenceEngine.addDriver(driver)
      waitingDrivers += driver
      drivers.add(driver)
      //见下
      schedule()
      context.reply(SubmitDriverResponse(self, true, Some(driver.id),"success"))
    }
  }


  /** RequestSubmitDriver()中调用触发 */
  private def schedule(): Unit = {
    if (state != RecoveryState.ALIVE) { return }
    //保留ALIVE状态Worker，随机打乱WorkerInfo对象在HashSet中的位置（为了负载均衡）
    val shuffledAliveWorkers = Random.shuffle(workers.toSeq.filter(_.state == WorkerState.ALIVE))
    val numWorkersAlive = shuffledAliveWorkers.size
    var curPos = 0
    //遍历包含启动Driver进程资源信息的DriverInfo对象集合
    for (driver <- waitingDrivers.toList) {
      var launched = false
      var numWorkersVisited = 0
      //遍历打乱顺序后的包含WorkerInfo对象的集合，一旦匹配成功将停止循环
      while (numWorkersVisited < numWorkersAlive && !launched) {
        val worker = shuffledAliveWorkers(curPos)
        numWorkersVisited += 1
        //WorkerInfo匹配DriverInfo的满足条件
        if (worker.memoryFree >= driver.desc.mem && worker.coresFree >= driver.desc.cores) {
          //见下
          launchDriver(worker, driver)
          //完成该driver启动，结束该driver匹配循环
          waitingDrivers -= driver
          launched = true
        }
        curPos = (curPos + 1) % numWorkersAlive
      }
    }
    startExecutorsOnWorkers()
  }


  /** Master向Worker发送启动Driver进程的消息:LaunchDriver */
  private def launchDriver(worker: WorkerInfo, driver: DriverInfo) {
    //告知Worker节点启动Driver进程的资源信息
    worker.addDriver(driver)
    /*def addDriver(driver: DriverInfo) {
      drivers(driver.id) = driver
      memoryUsed += driver.desc.mem
      coresUsed += driver.desc.cores
    }*/ 
    driver.worker = Some(worker)
    //endpoint：消息循环体，发送消息与接受消息同时启动Driver
    //case class LaunchDriver(driverId: String, driverDesc: DriverDescription)
    worker.endpoint.send(LaunchDriver(driver.id, driver.desc))
    driver.state = DriverState.RUNNING
  }  
}
```

4. 会有一台随机的Worker节点接收到Master发送的``LaunchDriver``，在该Worker节点新启动一个线程启动Driver进程（默认使用1G内存、1core），该进程会将Driver的状态变化信息``driver.state = DriverState.RUNNING``发给Worker，Worker再发送给Master，调用``schedule()``整理资源变化.        

```java
/** Worker可能启动多个Executor，可以把DriverRunner看作是Driver进程的一个proxy */
private[deploy] class DriverRunner(
  conf: SparkConf,
  val driverId: String,
  val workDir: File,
  val sparkHome: File,
  val driverDesc: DriverDescription,
  val worker: RpcEndpointRef,
  val workerUrl: String,
  val securityManager: SecurityManager
)

/** Driver启动失败时，若Supervise=true，则启动该Driver进程的Worker节点负责重启该Driver */
private[deploy] case class DriverDescription(
  jarUrl: String,
  mem: Int,
  cores: Int,
  supervise: Boolean,
  command: Command
)
```

```java
package org.apache.spark.deploy.worker

/** Worker接收到Master发来的LaunchDriver信息，启动Driver进程 */
private[deploy] class Worker(...) extends ThreadSafeRpcEndpoint {
  
  /** Worker接收到Master发送的LaunchDriver */
  case LaunchDriver(driverId, driverDesc) => {
    //先创建一个DriverRunner的实例对象
    val driver = new DriverRunner(
    conf,driverId,workDir,sparkHome,
    driverDesc.copy(command = Worker.maybeUpdateSSLSettings(driverDesc.command, conf)),
    self,workerUri,securityMgr
    )
    //将DriverRunner实例交给drivers数据结构保存信息
    //val drivers = new HashMap[String, DriverRunner]
    drivers(driverId) = driver
    //见下
    driver.start()
    //累计Worker上已使用资源
    coresUsed += driverDesc.cores
    memoryUsed += driverDesc.mem
  }

  /** 启动一个线程运行、管理Driver进程 */
  private[worker] def start() = {
    new Thread("DriverRunner for " + driverId) {
      override def run() {
        try {
          //为该Driver在本地创建一个工作目录
          val driverDir = createWorkingDirectory()
          //下载相关依赖Jar包到本地，因为程序是提交到Spark集群中
          val localJarFilename = downloadUserJar(driverDir)
          ...
          //见下
          launchDriver(builder, driverDir, driverDesc.supervise)
        }
        catch {case e: Exception => finalException = Some(e)}
        //判断并收集它的状态
        val state =
          if (killed) {DriverState.KILLED} 
          else if (finalException.isDefined) {DriverState.ERROR}
          else {
            finalExitCode match {
              case Some(0) => DriverState.FINISHED
              case _ => DriverState.FAILED
            }
          }
        finalState = Some(state)
        //给Worker发送一个状态变化的消息，见下
        worker.send(DriverStateChanged(driverId, state, finalException))
      }
    }.start()
  }
}


/** 管理Driver的执行，包括故障时自动重启Driver；目前仅在Cluster Manager=standlone模式下使用 */
private[deploy] class DriverRunner(...) {
  /** 启动Driver */
  private def launchDriver(builder: ProcessBuilder, baseDir: File, supervise: Boolean) {
    //创建目录
    builder.directory(baseDir)
    def initialize(process: Process): Unit = {
      //Redirect stdout and stderr to files
      val stdout = new File(baseDir, "stdout")
      CommandUtils.redirectStream(process.getInputStream, stdout)
      val stderr = new File(baseDir, "stderr")
      CommandUtils.redirectStream(process.getErrorStream, stderr)
    }
    //DriverRunner启动进程是通过ProcessBuilder中的process.get.waitFor()实现
    runCommandWithRetry(ProcessBuilderLike(builder), initialize, supervise)
  }
}
```

```java
package org.apache.spark.deploy.worker

/** Worker接收到Driver进程发送来的状态变化信息并转发给Master */
private[deploy] class Worker(...) extends ThreadSafeRpcEndpoint {

  //接收到状态变化的消息
  case driverStateChanged @ DriverStateChanged(driverId, state, exception) => {
    handleDriverStateChanged(driverStateChanged)
  }

  //处理Driver状态变化
  private[worker] def handleDriverStateChanged(driverStateChanged: DriverStateChanged): Unit = {
    val driverId = driverStateChanged.driverId
    val exception = driverStateChanged.exception
    val state = driverStateChanged.state
    state match {
      case DriverState.ERROR => logWarning
      case DriverState.FAILED => logWarning
      case DriverState.FINISHED => logInfo
      case DriverState.KILLED => logInfo
      case _ => logDebug
    }
    //见下
    sendToMaster(driverStateChanged)
    val driver = drivers.remove(driverId).get
    finishedDrivers(driverId) = driver
    trimFinishedDriversIfNecessary()
    memoryUsed -= driver.driverDesc.mem
    coresUsed -= driver.driverDesc.cores
  }
 
  //发送信息给Master
  private def sendToMaster(message: Any): Unit = {
    master match {
      //masterRef.send(DriverStateChanged)
      case Some(masterRef) => masterRef.send(message)
      case None =>
        logWarning("connection master has't been established")
    }
  }
}
```

```java
package org.apache.spark.deploy.master

/** Matser接收到Worker发来的Driver状态变化信息做相应处理 */
private[deploy] class Master(...) extends ThreadSafeRpcEndpoint with LeaderElectable {

  //将Driver状态=ERROR、FINISHED、KILLED、FAILED的Driver删除掉
  case DriverStateChanged(driverId, state, exception) => {
    state match {
      case DriverState.ERROR | DriverState.FINISHED | DriverState.KILLED | DriverState.FAILED =>
        //见下
        removeDriver(driverId, state, exception)
        /*private def removeDriver(...) {
          drivers.find(d => d.id == driverId) match {
            case Some(driver) =>
              drivers -= driver
              completedDrivers += driver
              persistenceEngine.removeDriver(driver)
              driver.worker.foreach(w => w.removeDriver(driver))
              schedule()
          }
        }*/
    }
  }
}
``` 

## 创建SparkContext对象

5. 创建SparkContext对象: 同时创建DAGScheduler、TaskScheduler、SchedulerBackend三大核心对象，因为SparkDeploySchedulerBackend受TaskSchedulerImpl管理，所以SparkContext最主要是实例化TaskSchedulerImpl.

![png3](/img/Spark/Spark_sparkcontext.png)

```java
package org.apache.spark

/**
 * 程序运行会先实例化SparkContext，所有方法外的成员都会被实例化
 */
class SparkContext(config: SparkConf) extends ExecutorAllocationClient 
{
  //关键代码: 位于SparkContext的私有构造器中，返回TaskScheduler和SchedulerBackend的实例
  val (sched, ts) = SparkContext.createTaskScheduler(this, master)
  _schedulerBackend = sched
  _taskScheduler = ts
  //TaskScheduler实例化后再创建DAGScheduler，因为TaskScheduler受DAGScheduler管理
  _dagScheduler = new DAGScheduler(this)

  //调用TaskScheduler的start方法
  _taskScheduler.start()
}


/**
 * 具体SparkContext.createTaskScheduler方法实现（Spark对象本身，setMaster中传入的字符串）
 * 根据new SparkContext(new SparkConf().setMaster("Spark://spark1:7077"))匹配运行模式
 */
private def createTaskScheduler(sc: SparkContext, master: String): (SchedulerBackend, TaskScheduler) = 
{
  import SparkMasterRegex._
  /*private object SparkMasterRegex {
    // Spark集群模式
    val SPARK_REGEX = """spark://(.*)""".r
  }*/

  //注意local模式task执行失败不会进行重试
  val MAX_LOCAL_TASK_FAILURES = 1

  master match {
    case SPARK_REGEX(sparkUrl) =>
    //创建TaskSchdulerImpl、SparkDeploySchedulerBackend
    val scheduler = new TaskSchedulerImpl(sc)
    val masterUrls = sparkUrl.split(",").map("spark://" + _)
    //TaskSchedulerImpl管理SparkDeploySchedulerBackend，所以先创建TaskScheduler实例后实例化backend
    val backend = new SparkDeploySchedulerBackend(scheduler, sc, masterUrls)
    //调用TaskSchedulerImpl的initialize方法
    scheduler.initialize(backend)
    //最后返回 (SparkDeploySchedulerBackend，TaskSchedulerImpl) 的实例对象
    (backend, scheduler)
  }
}
```

```java
package org.apache.spark.scheduler

private[spark] class TaskSchedulerImpl(...) extends TaskScheduler
{
  //默认Task失败后重试4次
  def this(sc: SparkContext) = 
      this(sc, sc.conf.getInt("spark.task.maxFailures", 4))
  //SparkConf配置
  val conf = sc.conf
  //默认先进先出模式
  private val schedulingModeConf = conf.get("spark.scheduler.mode", "FIFO")
  
  //TaskSchedulerImpl的initialize方法
  def initialize(backend: SchedulerBackend) {
    this.backend = backend
    // temporarily set rootPool name to empty
    rootPool = new Pool("", schedulingMode, 0, 0)
    //创建一个pool初定义资源分布的模式
    schedulableBuilder = {
      schedulingMode match {
      case SchedulingMode.FIFO =>
        new FIFOSchedulableBuilder(rootPool)
      case SchedulingMode.FAIR =>
        new FairSchedulableBuilder(rootPool, conf)
      }
    }
    schedulableBuilder.buildPools()
  }
}
```

```java
package org.apache.spark.scheduler

/**
 * DAGScheduler、TaskScheduler、SchedulerBackend三个对象都被实例化后
 * 执行_taskScheduler.start()，这里就是实现类TaskSchedulerImpl.start()
 */
override def start()
{
  //内部调用SparkDeploySchedulerBackend.start() 
  backend.start()

  if (!isLocal && conf.getBoolean("spark.speculation", false)) {
    logInfo("Starting speculative execution thread")
    speculationScheduler.scheduleAtFixedRate(new Runnable {
      override def run(): Unit = Utils.tryOrStopSparkContext(sc) {
        checkSpeculatableTasks()
      }
    }, SPECULATION_INTERVAL_MS, SPECULATION_INTERVAL_MS, TimeUnit.MILLISECONDS)
  }
}
```

```java
package org.apache.spark.scheduler.cluster

/**
 * SparkDeploySchedulerBackend的start方法
 */
private[spark] class SparkDeploySchedulerBackend(...)
    extends CoarseGrainedSchedulerBackend(scheduler, sc.env.rpcEnv) with AppClientListener
{
  override def start() {
    super.start()
    launcherBackend.connect()

    //Master给Worker发送指令启动所有Executor进程时加载Main方法所在的入口类就是command中的CoarseGrainedExecutorBackend
    val command = Command("org.apache.spark.executor.CoarseGrainedExecutorBackend",
        args, sc.executorEnvs, classPathEntries ++ testingClassPath, libraryPathEntries, javaOpts)
    val appUIAddress = sc.ui.map(_.appUIAddress).getOrElse("")
    val coresPerExecutor = conf.getOption("spark.executor.cores").map(_.toInt)
    val appDesc = new ApplicationDescription(sc.appName, maxCores, sc.executorMemory,
        command, appUIAddress, sc.eventLogDir, sc.eventLogCodec, coresPerExecutor)
    //创建AppClient对象，并调用AppClient.start()，创建一个ClientEndpoint对象
    client = new AppClient(sc.env.rpcEnv, masters, appDesc, this, conf)
    client.start()
    launcherBackend.setState(SparkAppHandle.State.SUBMITTED)
    waitForRegistration()
    launcherBackend.setState(SparkAppHandle.State.RUNNING)
  }
}


package org.apache.spark.deploy.client

/**
 * 调用AppClient.start()，创建一个RpcEndPoint对象
 */
private[spark] class AppClient(...)
{
  def start() {
    // Just launch an rpcEndpoint; it will call back into the listener.
    endpoint.set(rpcEnv.setupEndpoint("AppClient", new ClientEndpoint(rpcEnv)))
  }

  private class ClientEndpoint(override val rpcEnv: RpcEnv) extends ThreadSafeRpcEndpoint
  {
    ...
  }
}
```

6. DAGScheduler, TaskScheduler, SchedulerBackend对象创建完毕后，TaskScheduler中的SchedulerBackend连接Master，发送请求为当前的Application申请资源.

```java
package org.apache.spark.deploy.client

/** 注册Application到Master: Driver进程中的SparkDeploySchedulerBackend对象内部会创建AppClient实例，
    AppClient会创建一个ClientEndpoint对象，发送注册Application信息给Master.
    private[spark] class SparkDeploySchedulerBackend(...){
      client = new AppClient(sc.env.rpcEnv, masters, appDesc, this, conf)
      client.start()
    }*/
private[spark] class AppClient(...)
{

  private class ClientEndpoint(...) extends ThreadSafeRpcEndpoint
  {
    //注册程序到Master上是阻塞操作，利用线程池确保在多个Master时能同时被注册
    private val registerMasterThreadPool = ThreadUtils.newDaemonCachedThreadPool(
      "appclient-register-master-threadpool",
      masterRpcAddresses.length
    )

    //依次调用onStart() -> registerWithMaster() -> tryRegisterAllMasters()
    override def onStart(): Unit = {
      ...
      registerWithMaster(1)
      ...
    }

    private def registerWithMaster(nthRetry: Int) {
      registerMasterFutures.set(tryRegisterAllMasters())
      ...
    }

    //开一条新线程来注册，发送一条信息(RegisterApplication的case class)给Master
    private def tryRegisterAllMasters(): Array[JFuture[_]] = {
      for (masterAddress <- masterRpcAddresses) yield {
        registerMasterThreadPool.submit(new Runnable {
          override def run(): Unit = try {
            if (registered.get) {
              return
            }
            val masterRef = rpcEnv.setupEndpointRef(...)
            //SparkDeploySchedulerBackend中的AppClient的ClientEndpoint发送Application注册信息给Master
            masterRef.send(RegisterApplication(appDescription, self))
            /** SparkDeploySchedulerBackend AppClient -> Master
              case class RegisterApplication(ApplicationDescription, driver: RpcEndpointRef)
              extends DeployMessage*/
          } catch {
            ...
          }
        })
      }
    }
  }
}


//ApplicationDescription的case class
private[spark] case class ApplicationDescription(
    name: String,
    maxCores: Option[Int],
    memoryPerExecutorMB: Int,
    command: Command,
    appUiUrl: String,
    eventLogDir: Option[URI] = None,
    eventLogCodec: Option[String] = None,
    coresPerExecutor: Option[Int] = None,
    user: String = System.getProperty("user.name", "<unknown>")
) {
    override def toString: String = "ApplicationDescription(" + name + ")"
}
```


## 注册Application并启动Executor进程

7. Driver进程启动，SparkContext创建完成，Master接收到SparkDeploySchedulerBackend发送的Application注册信息，并将这些信息写入数据结构``ArrayBuffer``中等待调度.      

```java
package org.apache.spark.deploy.master

/** 注册Application*/
private[deploy] class Master(...)
{
  override def receive: PartialFunction[Any, Unit] =
  {
    ...
    //Master接收到Application注册信息后开始注册
    case RegisterApplication(description, driver) =>
    {
      // TODO Prevent repeated registrations from some driver
      if (state == RecoveryState.STANDBY) {
        // ignore, don't send response
      } else {
        val app = createApplication(description, driver)
        registerApplication(app)
        persistenceEngine.addApplication(app)
        /** Master -> Driver AppClient
        case class RegisteredApplication(appId, master: RpcEndpointRef)*/
        driver.send(RegisteredApplication(app.id, self))
        //Application注册后需要进行资源调度
        schedule()
      }
    }
  }

  private def createApplication(desc: ApplicationDescription, driver: RpcEndpointRef): ApplicationInfo = 
  {
    val now = System.currentTimeMillis()
    val date = new Date(now)
    val appId = newApplicationId(date)
    new ApplicationInfo(now, appId, desc, date, driver, defaultCores)
  }

  private def registerApplication(app: ApplicationInfo): Unit =
  {
    val appAddress = app.driver.address
    if (addressToApp.contains(appAddress)) {
      //重复注册的application使用原地址即可
      return
    }
    applicationMetricsSystem.registerSource(app.appSource)
    apps += app
    idToApp(app.id) = app
    endpointToApp(app.driver) = app
    addressToApp(appAddress) = app
    //将Application信息加入等待调度的队列
    waitingApps += app
    /**等待调度的队列：waitingApps
    val waitingApps = new ArrayBuffer[ApplicationInfo]

    private[spark] class ApplicationInfo(
      val startTime: Long,
      val id: String,
      val desc: ApplicationDescription,
      val submitDate: Date,
      val driver: RpcEndpointRef,
      defaultCores: Int)*/
  }
}
```

8. 调用调度方法``schedule()``通知资源充足的Worker节点启动Executor进程``startExecutorsOnWorkers()``.

```java
package org.apache.spark.deploy.master

/** 启动Executor进程 */
private[deploy] class Master(...)
{
  //新的Application加入调用此方法
  private def schedule(): Unit = {
    ...
    //给作业分配资源（Executors），见下
    startExecutorsOnWorkers()
  }

  //Schedule and launch executors on workers
  private def startExecutorsOnWorkers(): Unit = 
  {
    /**
     * private[master] def coresLeft: Int = requestedCores - coresGranted
     * requestedCores: 所有Executor所使用的cores （--total-executor-cores 参数可以指定）
     * coresGranted: 已经分配的cores 
     * requestedCores - coresGranted = coresLeft 还需要分配的cores
     */
    for (app <- waitingApps if app.coresLeft > 0) {
      //每个Executor启动的cores，默认为Worker管理的cores，也可以使用--executor-cores参数指定
      val coresPerExecutor: Option[Int] = app.desc.coresPerExecutor
      //过滤掉不处于ALIVE状态和资源不足以启动Executor的worker，获得按可用cores降序排列的Array[WorkerInfo]数组
      val usableWorkers = workers.toArray.filter(_.state == WorkerState.ALIVE)
      .filter(worker => worker.memoryFree >= app.desc.memoryPerExecutorMB &&
      worker.coresFree >= coresPerExecutor.getOrElse(1))
      .sortBy(_.coresFree).reverse
      //spreadOutApps：默认值为true，见下
      val assignedCores = scheduleExecutorsOnWorkers(app, usableWorkers, spreadOutApps)

      // Now that we've decided how many cores to allocate on each worker, let's allocate them
      for (pos <- 0 until usableWorkers.length if assignedCores(pos) > 0) {
        //见下
        allocateWorkerResourceToExecutors(
          app, assignedCores(pos), coresPerExecutor, usableWorkers(pos))
      }
    }
  }
}
```

1. There are two modes of launching executors. The first attempts to spread out an application's executors on as many workers as possible, while the second does the opposite (i.e. launch them on as few workers as possible). The former is usually better for data locality purposes and is the default. ---- 有两种启动executors的模式：第一种尝试将应用程序的executors分散到尽可能多的worker上，更符合数据本地化是默认的方式；而第二种尝试恰好相反（即尽可能少的worker上）.
 
2. The number of cores assigned to each executor is configurable. When this is explicitly set, multiple executors from the same application may be launched on the same worker if the worker has enough cores and memory. Otherwise, each executor grabs all the cores available on the worker by default, in which case only one executor may be launched on each worker. ---- 分配给每个executor的cores是可配置的. 如果明确配置了coresPerExecutor，且worker拥有足够的cores和内存，则可以为同一Application在同一个worker上启动多个executor；否则，每个executor默认使用worker上可用的所有cores，如此每个worker只能启动一个executor.

3. It is important to allocate coresPerExecutor on each worker at a time (instead of 1 core at a time). Consider the following example: cluster has 4 workers with 16 cores each. User requests 3 executors (spark.cores.max = 48, spark.executor.cores = 16). If 1 core is allocated at a time, 12 cores from each worker would be assigned to each executor. Since 12 < 16, no executors would launch. ---- 一次为每个worker分配coresPerExecutor（而不是一次分配一个core）是很重要的，举例：集群有4个worker，每个worker有16个core，Driver请求启动3个executor（spark.cores.max = 48，spark.executor.cores = 16），如果一次分配1个core，则为每个executor被分配来自每个worker的12个内核，而这12cores无法满足executor启动的16cores的要求，所以没有executor会启动.

```java
package org.apache.spark.deploy.master

private[deploy] class Master(...)
{
  /**
   * Schedule executors to be launched on the workers.
   * Returns an array containing number of cores assigned to each worker.
   */
  private def scheduleExecutorsOnWorkers(app: ApplicationInfo,
    usableWorkers: Array[WorkerInfo],spreadOutApps: Boolean): Array[Int] =
  {
    //每个Executor的core个数 默认None
    val coresPerExecutor = app.desc.coresPerExecutor
    //每个Executor所需core最少个数 默认1
    val minCoresPerExecutor = coresPerExecutor.getOrElse(1)
    //若没有设置 --executor-cores 则为true
    val oneExecutorPerWorker = coresPerExecutor.isEmpty
    //每个executor所需内存 默认1G
    val memoryPerExecutor = app.desc.memoryPerExecutorMB
    //可用worker的个数
    val numUsable = usableWorkers.length
    //Int型数组，初始大小为可用worker个数，初始值为0
    val assignedCores = new Array[Int](numUsable)
    val assignedExecutors = new Array[Int](numUsable)
    //app.coresLeft > 集群剩余可用cores  = 集群可用总cores
    //app.coresLeft < 集群剩余可用cores  = App还需要的cores
    var coresToAssign = math.min(app.coresLeft, usableWorkers.map(_.coresFree).sum)

    // 过滤条件：当前worker的可用资源是否满足为该app启动一个executor
    def canLaunchExecutor(pos: Int): Boolean =
	{
      //集群可用cores满足启动一个executor
      val keepScheduling = coresToAssign >= minCoresPerExecutor
      //worker剩余的cores - 当前worker为App已奉献的cores = 当前worker可用的cores是否满足启动一个executor
      val enoughCores = usableWorkers(pos).coresFree - assignedCores(pos) >= minCoresPerExecutor
      //assignedExecutors(pos) == 0 代表当前worker之前没有为该app启动过executor
      //oneExecutorPerWorker: 不设置参数则默认为true，代表一个worker节点上只为该app启动一个executor
      val launchingNewExecutor = !oneExecutorPerWorker || assignedExecutors(pos) == 0
      if (launchingNewExecutor) {
        //当前worker为App已奉献的内存
        val assignedMemory = assignedExecutors(pos) * memoryPerExecutor
        //当前worker可用的内存是否满足启动一个executor
        val enoughMemory = usableWorkers(pos).memoryFree - assignedMemory >= memoryPerExecutor
        val underLimit = assignedExecutors.sum + app.executors.size < app.executorLimit
        keepScheduling && enoughCores && enoughMemory && underLimit
      } else {
        //当前worker只能为app启动一个executor且已经启动过了，所以不需要check memory和executor limits
        keepScheduling && enoughCores
      }
    }

    //上述条件过滤后，freeWorkers就是所有符合条件（启动一个executor）的worker集合了
    var freeWorkers = (0 until numUsable).filter(canLaunchExecutor)
    while (freeWorkers.nonEmpty) {
	  freeWorkers.foreach { pos =>
	  var keepScheduling = true
	  while (keepScheduling && canLaunchExecutor(pos)) {
	    //真正启动executor进程
		coresToAssign -= minCoresPerExecutor
		assignedCores(pos) += minCoresPerExecutor
		//默认没有添加参数，则assignedExecutors集合中元素值永久为1
		if (oneExecutorPerWorker) {
		  assignedExecutors(pos) = 1
		  } else {
		    assignedExecutors(pos) += 1
		  }
		  //spreadOutApps默认为true，保证轮询启动executor进程，保障全部或大部分worker都能启动executor进程，在一定程度上有利于数据的本地化计算
		  if (spreadOutApps) {
		    keepScheduling = false
		  }
	    }
	  }
      /**
       * 遍历完毕后，再进行一次过滤，满足freeWorkers不为空，又会进行一次遍历，循环反复；
	   * 默认不加参数的情况下oneExecutorPerWorker始终为true，在一次又一次的遍历freeWorkers中的worker的过程中，assignedExecutors元素值始终为1；
	   * 而只要当前worker的剩余cores满足启动条件，assignedCores元素值始终会以minCoresPerExecutor为单位递增，也验证了默认每个executor会占用worker管理的所有cores.
	   */
	  freeWorkers = freeWorkers.filter(canLaunchExecutor)
    }
    assignedCores
  }


  /** 分配Worker上的资源给一个或多个Executor */
  private def allocateWorkerResourceToExecutors(
    app: ApplicationInfo,
    assignedCores: Int,
	coresPerExecutor: Option[Int],
	worker: WorkerInfo): Unit = {
	// If the number of cores per executor is specified, we divide the cores assigned
	// to this worker evenly among the executors with no remainder.
	// Otherwise, we launch a single executor that grabs all the assignedCores on this worker.
	val numExecutors = coresPerExecutor.map { assignedCores / _ }.getOrElse(1)
	val coresToAssign = coresPerExecutor.getOrElse(assignedCores)
	for (i <- 1 to numExecutors) {
	  val exec = app.addExecutor(worker, coresToAssign)
	  /*private[master] def addExecutor(WorkerInfo,cores,useID): ExecutorDesc = {
	  executors(exec.id) = new ExecutorDesc(
	  newExecutorId(useID), this, worker,
	  cores, desc.memoryPerExecutorMB)
      coresGranted += cores
      exec
      }*/
      //见下
      launchExecutor(worker, exec)
      app.state = ApplicationState.RUNNING
    }
  }

  
  /** 新增Executor并发送信息给Worker真正启动Executor */
  private def launchExecutor(worker: WorkerInfo, exec: ExecutorDesc): Unit = 
  {
    //添加为当前应用程序分配的Executor信息
    worker.addExecutor(exec)    
    /*def addExecutor(exec: ExecutorDesc) {
      executors(exec.fullId) = exec
      coresUsed += exec.cores
      memoryUsed += exec.memory
    }*/
    //Master通过远程通信发指令给Worker启动ExecutorBackend进程
    worker.endpoint.send(LaunchExecutor(masterUrl,
      exec.application.id, exec.id, exec.application.desc, exec.cores, exec.memory))
    //Master通过远程通信给Driver发送一条ExecutorAdded信息
    exec.application.driver.send(
      ExecutorAdded(exec.id, worker.id, worker.hostPort, exec.cores, exec.memory))
  }
}
```

```java
package org.apache.spark.deploy

private[deploy] sealed trait DeployMessage extends Serializable

/** send messages between Scheduler endpoint nodes.*/
private[deploy] object DeployMessages {
  //Master发送数据到Worker，见下
  case class LaunchExecutor(masterUrl, appId, execId, appDesc: ApplicationDescription, cores, memory)
    extends DeployMessage

  //Master发送数据到Driver
  case class ExecutorAdded(id: Int, workerId: String, hostPort: String, cores: Int, memory: Int) {
    Utils.checkHostPort(hostPort, "Required hostport")
	/*Driver端接收到消息后处理
	package org.apache.spark.deploy.client
	private[spark] class AppClient(...) {
	  case ExecutorAdded(id: Int, workerId: String, hostPort: String, cores: Int, memory: Int) =>
	    val fullId = appId + "/" + id
	    //Executor added
	    listener.executorAdded(fullId, workerId, hostPort, cores, memory}
	*/
  }
}
```

9. Worker接收到Master发来的``LaunchExecutor``信息后，在Worker进程中首先创建一个ExecutorRunner实例，在其内部启动一个Thread线程，Thread创建Executor在本地文件系统的工作目录，通过``buildProcessBuilder``启动Executor进程.

```java
package org.apache.spark.deploy.worker

private[deploy] class Worker(...)
{
  //Worker接收到Master发送的LaunchExecutor信息
  case LaunchExecutor(masterUrl, appId, execId, appDesc, cores_, memory_) =>
    if (masterUrl != activeMasterUrl) {
      //Invalid MasterUrl
    } else {
    try {
      //创建Executor工作目录
      val executorDir = new File(workDir, appId + "/" + execId)
      if (!executorDir.mkdirs()) {
        throw new IOException("Failed to create directory " + executorDir)
      }
	  //为Executor创建本地目录，当Application完成执行后会被Worker进程移除
      val appLocalDirs = appDirectories.get(appId).getOrElse {
        Utils.getOrCreateLocalRootDirs(conf).map { dir =>
          val appDir = Utils.createDirectory(dir, namePrefix = "executor")
          Utils.chmod700(appDir)
          appDir.getAbsolutePath()
        }.toSeq
      }
      appDirectories(appId) = appLocalDirs
        val manager = new ExecutorRunner(
        appId, execId,
        appDesc.copy(command = Worker.maybeUpdateSSLSettings(appDesc.command, conf)),
        cores_, memory_, self, workerId, host, webUi.boundPort, publicAddress,
        sparkHome, executorDir, workerUri, conf, appLocalDirs, ExecutorState.RUNNING)
        executors(appId + "/" + execId) = manager
		//见下
        manager.start()
        coresUsed += cores_
        memoryUsed += memory_
		//Worker发送ExecutorStateChanged消息给Master，见下
        sendToMaster(ExecutorStateChanged(appId, execId, manager.state, None, None))
      } catch {
        //Failed to launch Executor
        sendToMaster(ExecutorStateChanged(appId, execId, ExecutorState.FAILED,Some(e.toString), None))
      }
    }
}
```

```java
package org.apache.spark.deploy.worker

/** 管理一个Executor进程.只适用于standalone模式 */
private[deploy] class ExecutorRunner(...){
  //承接manager.start()
  private[worker] def start() {
	//新起一个线程Download and run the executor described in our ApplicationDescription
    workerThread = new Thread("ExecutorRunner for " + fullId) {
	  //见下
      override def run() { fetchAndRunExecutor() }
    }
    workerThread.start()
    // Shutdown hook that kills actors on shutdown.
    shutdownHook = ShutdownHookManager.addShutdownHook { () =>
      //有可能会进到这里，需要将此时RUNNING改成FAILD
      if (state == ExecutorState.RUNNING) {
        state = ExecutorState.FAILED
      }	
      killProcess(Some("Worker shutting down"))
	}
  }
}


/*Download and run the executor described in our ApplicationDescription */
private def fetchAndRunExecutor() {
  try {
	//封装好Executor启动的command
	val builder = CommandUtils.buildProcessBuilder(appDesc.command, ...)
	val command = builder.command()
	builder.directory(executorDir)
	//启动Executor
	process = builder.start()
	// Redirect its stdout and stderr to files
	val stdout = new File(executorDir, "stdout")
	stdoutAppender = FileAppender(process.getInputStream, stdout, conf)
	val stderr = new File(executorDir, "stderr")
	stderrAppender = FileAppender(process.getErrorStream, stderr, conf)
	val exitCode = process.waitFor()
	state = ExecutorState.EXITED
	//ExecutorRunner中的workerThread线程将ExecutorStateChanged发送给Worker
	worker.send(ExecutorStateChanged(appId, execId, state, Some(message), Some(exitCode)))
  } catch {
	state = ExecutorState.FAILED
	killProcess()
  }
}
```

10. Worker进程接收到Thread发来的Executor状态消息``ExecutorStateChanged``后转发给Master，调用``schedule()``.

```java
package org.apache.spark.deploy.worker

private[deploy] class Worker(...)
{
  //Worker接收到ExecutorStateChanged，并调用handleExecutorStateChanged()
  case executorStateChanged @ ExecutorStateChanged(appId, execId, state, message, exitStatus) =>
    handleExecutorStateChanged(executorStateChanged)

  private[worker] def handleExecutorStateChanged(executorStateChanged: ExecutorStateChanged): Unit =
  {
	//Worker将ExecutorStateChanged转发给Master
    sendToMaster(executorStateChanged)
    val state = executorStateChanged.state
    if (ExecutorState.isFinished(state)) {
      val appId = executorStateChanged.appId
      val fullId = appId + "/" + executorStateChanged.execId
      val message = executorStateChanged.message
      val exitStatus = executorStateChanged.exitStatus
      executors.get(fullId) match {
        case Some(executor) =>
          executors -= fullId
          finishedExecutors(fullId) = executor
          trimFinishedExecutorsIfNecessary()
          coresUsed -= executor.cores
          memoryUsed -= executor.memory
      }
      maybeCleanupApplication(appId)
    }
  }
}
```

```java
package org.apache.spark.deploy.master

  //Master接收到Worker发送过来的ExecutorStateChanged信息
  case ExecutorStateChanged(appId, execId, state, message, exitStatus) => {
    val execOption = idToApp.get(appId).flatMap(app => app.executors.get(execId))
    execOption match {
      case Some(exec) => {
        val appInfo = idToApp(appId)
        val oldState = exec.state
        exec.state = state
        if (state == ExecutorState.RUNNING) {
          assert(oldState == ExecutorState.LAUNCHING,
          appInfo.resetRetryCount()
        }
		//Master发送ExecutorUpdated消息给Driver(SparkDeploySchedulerBackend)中的AppClient
        exec.application.driver.send(ExecutorUpdated(execId, state, message, exitStatus))
        if (ExecutorState.isFinished(state)) {
          //Remove this executor in worker and app，If an application has finished
          if (!appInfo.isFinished) {
            appInfo.removeExecutor(exec)
          }
          exec.worker.removeExecutor(exec)
          val normalExit = exitStatus == Some(0)
		  //获得Executor的状态后，若Executor挂掉，系统会尝试最多10次的重启，无果则remove该Application
		  //MAX_EXECUTOR_RETRIES=conf.getInt("spark.deploy.maxExecutorRetries", 10)
          if (!normalExit
            && appInfo.incrementRetryCount() >= MAX_EXECUTOR_RETRIES
            && MAX_EXECUTOR_RETRIES >= 0) { // < 0 disables this application-killing path
            val execs = appInfo.executors.values
            if (!execs.exists(_.state == ExecutorState.RUNNING)) {
              removeApplication(appInfo, ApplicationState.FAILED)
            }
          }
        }
        schedule()
      }
    }
  }
}
```

```java
private[deploy] object DeployMessages {
  /** Master -> AppClient */
  case class ExecutorUpdated(id: Int, state: ExecutorState, 
    message: Option[String], exitStatus: Option[Int])
}


package org.apache.spark.deploy.client

private[spark] class AppClient(...)
{
  case ExecutorUpdated(id, state, message, exitStatus) =>
    val fullId = appId + "/" + id
    val messageText = message.map(s => " (" + s + ")").getOrElse("")
    //Executor updated
    if (ExecutorState.isFinished(state)) {
      listener.executorRemoved(fullId, message.getOrElse(""), exitStatus)
    }
}
```

## Executor启动后注册给Driver

11. Master发指令给Worker启动所有Executor进程时加载Main方法所在的入口类就是command中的CoarseGrainedExecutorBackend.

```java
val command = Command("org.apache.spark.executor.CoarseGrainedExecutorBackend",...)
```

12. Worker会启动另外一个进程CoarseGrainedExecutorBackend来向Driver发送注册Executor的信息``RegisterExecutor`.

```java
package org.apache.spark.executor

private[spark] class CoarseGrainedExecutorBackend(...)
  extends ThreadSafeRpcEndpoint with ExecutorBackend
{
  def main(args: Array[String]) {
    run(driverUrl, executorId, hostname, cores, appId, workerUrl, userClassPath)
  }
}


private[spark] object CoarseGrainedExecutorBackend {
  private def run(...) {
    SparkHadoopUtil.get.runAsSparkUser { () =>
      env.rpcEnv.setupEndpoint("Executor", new CoarseGrainedExecutorBackend(...))
    }
  }
}


private[spark] class CoarseGrainedExecutorBackend(...)
  extends ThreadSafeRpcEndpoint with ExecutorBackend
{
  override def onStart() {
    //Connecting to Driver
    rpcEnv.asyncSetupEndpointRefByURI(driverUrl).flatMap { ref =>
      driver = Some(ref)
	  //向Driver发送注册信息
      ref.ask[RegisterExecutorResponse](
        RegisterExecutor(executorId, self, hostPort, cores, extractLogUrls))
    }(ThreadUtils.sameThread).onComplete {
      case Success(msg) => Utils.tryLogNonFatalError {
        Option(self).foreach(_.send(msg))
      }
    }(ThreadUtils.sameThread)
  }
}
```

13. 在DriverEndpoint中会接受到RegisterExecutor注册信息并完成注册，在DriverEndpoint中通过ExecutorData封装接收到的注册信息到Driver的CoarseGraninedSchedulerBackend的内存数据结构executorMapData中，所以最终是注册给了CoarseGraninedSchedulerBackend，也就是说CoarseGraninedSchedulerBackend掌握了为当前程序分配的所有的CoarseGraninedExecutorBackend进程（该进程实例中会通过Executor对象来负责具体Task的运行）.

```java
private[spark] class CoarseGrainedSchedulerBackend(scheduler: TaskSchedulerImpl, val rpcEnv: RpcEnv)
  extends ExecutorAllocationClient with SchedulerBackend
{

  private val executorDataMap = new HashMap[String, ExecutorData]

  class DriverEndpoint(override val rpcEnv: RpcEnv, sparkProperties: Seq[(String, String)])
    extends ThreadSafeRpcEndpoint
  {
    override def receiveAndReply(context: RpcCallContext): PartialFunction[Any, Unit] = {

      case RegisterExecutor(executorId, executorRef, hostPort, cores, logUrls) =>
        if (executorDataMap.contains(executorId)) {
          context.reply(RegisterExecutorFailed("Duplicate executor ID: " + executorId))
        } else {
          // If the executor's rpc env is not listening for incoming connections, `hostPort`
          // will be null, and the client connection should be used to contact the executor.
          val executorAddress = if (executorRef.address != null) {
              executorRef.address
            } else {
              context.senderAddress
            }
          logInfo(s"Registered executor $executorRef ($executorAddress) with ID $executorId")
          addressToExecutorId(executorAddress) = executorId
          totalCoreCount.addAndGet(cores)
          totalRegisteredExecutors.addAndGet(1)
          val data = new ExecutorData(executorRef, executorRef.address, executorAddress.host,
            cores, cores, logUrls)
          //使用synchronised保证executorMapData安全的并发写操作
          CoarseGrainedSchedulerBackend.this.synchronized {
            executorDataMap.put(executorId, data)
            if (numPendingExecutors > 0) {
              numPendingExecutors -= 1
              logDebug(s"Decremented number of pending executors ($numPendingExecutors left)")
            }
          }
          // Note: some tests expect the reply to come after we put the executor in the map
          context.reply(RegisteredExecutor(executorAddress.host))
          listenerBus.post(
            SparkListenerExecutorAdded(System.currentTimeMillis(), executorId, data))
          makeOffers()
        }
	}
```

14. CoarseGrainedExecutorBackend是一个消息通信体(实现了ThreadSafeRpcEndPoint)，可以发送注册信息给Driver，并接受Driver中发来的指令(启动Task等).

```java
package org.apache.spark.executor

private[spark] class CoarseGrainedExecutorBackend(...)
  extends ThreadSafeRpcEndpoint with ExecutorBackend
{
  override def receive: PartialFunction[Any, Unit] = {
    case RegisteredExecutor(hostname) =>
      //注册成功
      executor = new Executor(executorId, hostname, env, userClassPath, isLocal = false)
  }
}
```

> 为什么不在原有的Worker进程里发送注册信息给Driver而要单独另开一个进程？

Worker主要管理当前机器资源并将资源变动汇报给Master，并不用于计算；且若多个应用程序在同一进程中运行，其中一个程序崩溃会导致其他程序跟着崩溃.
CoarseGrainedExecutorBackend是Executor运行所在的进程名称，存在一对一的关系，Executor才是真正处理Task的对象，Executor内部是通过线程池的方式来完成Task的计算的.

> 在Driver进程中有两个至关重要的Endpoint:

AppClient中的ClientEndpoint: 主要负责向Master注册当前的程序;
CoraseGraninedSchedulerBackend中的DriverEndpoint: 整个程序运行时候的驱动器，注册Executor并分发task.

# 结论

默认在提交Application时不指定--executor-cores参数的情况下，每个Worker节点只会为当前Application启动一个Executor，每个Executor会使用Worker所管理的所有cores.

如果想在一个Worker节点上启动多个Executor进程，则需要在提交Application时指定--executor-core参数.

spreadOutApps这个参数可以决定启动executor的方式：默认为true，则轮询启动executor进程，保障全部或大部分worker都能启动executor进程，在一定程度上有利于数据的本地化计算；若为false，则先在一个Worker上启动，待这个Worker没有可用启动资源了，再轮询到下一个Worker.

一般一个core分配2-3个task，因为cores之间性能存在差异，高性能的core可以相应的分担低性能core上的任务，从而缩短计算时间；task的并行度由RDD的分区数决定，知道了task的并行度就大概知道了需要的cores，就可以在提交Application的时候指定参数.

# 测试

现在集群中有2个Worker，每个Worker管理2核和3G内存，通过spark-shell添加不同参数提交命令，查看结果.

|Spark-shell|ExecutorsPerWorker|CoresPerExecutor|MomeryPerExecutor|
|---|---|---|---|
|./spark-shell --master spark://spark1:7077|2|2|1G|
|./spark-shell --master spark://spark1:7077 --executor-cores 1|4|1|1G|
|./spark-shell --master spark://spark1:7077 --executor-cores 1 --total-executor-cores 3|3|1|1G|
|./spark-shell --master spark://spark1:7077 --executor-cores 1 --total-executor-cores 3 --executor-memory 3G|2|1|3G|
|./spark-shell --master spark://spark1:7077 --executor-cores 3 --executor-memory 3G|0|||

