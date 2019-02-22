在standalong模式下的任务调度流程

# 基础理论

## 相关概念

1. Master: 资源管理的主节点（进程） 管理Worker，会与Worker进行频繁的通信.
2. Worker: 资源管理的从节点（进程） 管理本机资源（core、内存）的进程，接收到Master消息后为每个Application启动各自的Executor.（standalone模式中Master和Worker在一个节点上）
3. Cluster Manager: 在集群上获取资源的外部服务（standalone、Mesos、Yarn）.
4. Driver: 驱动进程，用来连接工作进程（Worker）的程序，分发task并根据不同action类算子决定是否回收task的计算结果.
5. Executor: 在一个Worker节点上为某Application启动的一个JVM进程，task在其内部的线程池中运行并将数据存在内存或者磁盘上（每个Application都有各自独立的Executor）.
6. Application: 基于Spark的应用程序（包含客户端Driver程序和运行在集群上的Executor程序）.
7. Job: 包含很多任务(Task)的并行计算，可以看做和action对应，一个Application中有n个action类算子就有n个job.
8. Stage: ⼀个Job会被拆分很多组任务，每组任务被称为Stage(就像Mapreduce分map task和reduce task一样)，一个job中有n个宽依赖就划分成n+1个stage.
9. Task: 就相当于thread，被送到某个Executor的threadpool中处理任务的工作单元.
10. 并发、并行: Executor中某一时刻所有core处理task的数量称为该Executor的并行度，每个core分配的task数量称为该core的并发度.
11. DAGScheduler: 是面向Job和Stage的高层调度器.
12. TaskScheduler: （接口）是底层调度器，不同的ClusterManager会有不同的实现（Standalone模式下为TaskSchedulerImpl）.
13. SchedulerBackend: （接口）不同ClusterManager也会有不同的实现（Standalone模式下为SparkDeploySchedulerBackend）.
14. SparkDeploySchedulerBackend: 负责连接Master并注册当前程序（RegisterWithMaster）、负责接收Spark集群为当前应用分配的计算资源Executor的注冊并管理Executor、 负责发送Task到具体的Executor端执行.

## 设置并行度

```java
--spark.default.parallelism

SparkConf conf = new SparkConf()
conf.set("spark.default.parallelism", "500")
```

## RDD依赖关系

> 窄依赖 Narrow Dependencies

如果父RDD与子RDD之间的partition分区是一对一或多对一的关系，则该父子RDD间的依赖关系就是窄依赖；每个stage内部的RDD之间都是窄依赖，stage内部都是进行pipeline操作，没有shuffle.

> 宽依赖 Wide Dependencies

如果父RDD与子RDD中间的partition是一对多的对应关系，则该父子RDD间的依赖关系就是宽依赖；宽依赖会发生shuffle，stage之间是宽依赖，所以stage之间会发生数据传输及shuffle.


## stage内部的计算原理

1. stage内部是由n个RDD组成（n>=1），RDD之间都是窄依赖，就是pipeline计算模式，1+1+1=3而非1+1=2、2+1=3，由于中间没有计算结果，所以不需要保存中间结果，因此计算快.

2. stage中的并行度（并行task数）是由该stage最终RDD的partition个数决定的.

3. stage中每个task封装的计算逻辑就是由该task所贯穿的每一个partition中的计算逻辑以递归函数的展开式整合的逻辑.

```java
val lineRDD = sc.textFile("hdfs://spark1:9000/input/log.txt")
val mapRDD = lineRDD.map(x => {
    println("map: " + x)
    x.split(" ")(1)
})
val filterRDD = mapRDD.filter(x => {
    println("filter: " + x)
    true
})
filterRDD.count()
```

假设以上stage只有一个task，则此时task的逻辑就是 filter(map(textFile(block0)))递归执行，然后重复读取block0中数据，返回结果的打印顺序如下：

```bash
map: 2017-10-11 浙江杭州 3301
filter: 浙江杭州
map: 2017-10-12 浙江宁波 3302
filter: 浙江宁波
```

## 总结

![png1](/img/Spark/Spark_stage.png)

Application包含几个action类算子，就有多少个Job，每个Job会根据其中RDD之间的依赖关系，从action算子的前一个RDD开始回溯，以RDD间宽依赖为切割点，该Job被切割成多组stage，每组stage包含n个task，因为RDD中不存储数据，RDD的partition只存储计算逻辑，所以根据pipeline的工作模式，每个基本工作单元task的计算逻辑就是该stage中所有partition存储的计算逻辑以递归函数的展开式的形式整合起来的.

# 任务调度源码分析

![png2](/img/Spark/Spark_schedule.png)

1. 承接资源调度中CoarseGrainedExecutorBackend接收到DriverEndpoint(CoraseGrainedSchedulerBackend)发送过来的``RegisteredExecutor``消息后会启动Executor实例对象.

2. 在实例化Executor的同时会启动一个线程池用于Task计算，创建的 threadPool 中以多线程并发执行和线程复用的方式来高效的执行 Spark 发过来的 Task.

```java
package org.apache.spark.executor

private[spark] class Executor(...)
{
  // Start worker thread pool
  private val threadPool = ThreadUtils.newDaemonCachedThreadPool("Executor task launch worker")
  private val executorSource = new ExecutorSource(threadPool, executorId)
}


private[spark] object ThreadUtils
{
  def newDaemonCachedThreadPool(prefix: String): ThreadPoolExecutor = {
    val threadFactory = namedThreadFactory(prefix)
    Executors.newCachedThreadPool(threadFactory).asInstanceOf[ThreadPoolExecutor]
  }
}
```

3. 程序执行时遇到action类算子时会触发job的执行，DAGScheduler会切割这个job，根据RDD的宽窄依赖划分stage，DAGScheduler会将切割后的stage中的所有task封装到TaskSet对象中，然后提交给TaskScheduler，TaskScheduler会遍历接收到的每一个TaskSet集合，将集合中每一个task发送给CoarseGrainedExecutorBackend（RpcEndpoint），而不是直接发送给Executor（因为Executor不是消息循环体，所以永远也无法直接接受远程发来的信息)；CoarseGrainedExecutorBackend在接收到Driver发来的消息后会通过调用LaunchTask将Task交给Executor去执行.

```java
package org.apache.spark.executor

private[spark] class CoarseGrainedExecutorBackend(...)
  extends ThreadSafeRpcEndpoint with ExecutorBackend
{

  override def receive: PartialFunction[Any, Unit] = {
    //先判断如果有Executor，进行反序例化（在执行具体的业务逻辑前会进行3次反序例化，TaskDescription、Task本身以及RDD）
    case LaunchTask(data) =>
      if (executor == null) {
        logError("Received LaunchTask command but executor was null")
        System.exit(1)
      } else {
        val taskDesc = ser.deserialize[TaskDescription](data.value)
        logInfo("Got assigned task " + taskDesc.taskId)
        executor.launchTask(this, taskId = taskDesc.taskId, 
          attemptNumber = taskDesc.attemptNumber,
          taskDesc.name, taskDesc.serializedTask)
      }
  }


  //发送LaunchTask消息，创建一个TaskRunner实例存入runningTasks的数据结构中，最后交给线程池去执行
  private[spark] class Executor(...)
  {
    def launchTask(...): Unit = {
      val tr = new TaskRunner(context, taskId = taskId,
        attemptNumber = attemptNumber, taskName,
        serializedTask)
      runningTasks.put(taskId, tr)
      threadPool.execute(tr)
    }
  }
}
```

```java
package org.apache.spark.executor

private[spark] class Executor(...)
{
  /* Executor通过TaskRunner在ThreadPool中运行具体的Task */
  class TaskRunner(...) extends Runnable {
    override def run(): Unit = {
      val taskMemoryManager = new TaskMemoryManager(env.memoryManager, taskId)
      val deserializeStartTime = System.currentTimeMillis()
      Thread.currentThread.setContextClassLoader(replClassLoader)
      val ser = env.closureSerializer.newInstance()
      //在TaskRunner的run()方法中调用stateUpdate()向Driver汇报自己的状态（RUNNING）
      execBackend.statusUpdate(taskId, TaskState.RUNNING, EMPTY_BYTE_BUFFER)
      var taskStart: Long = 0
      startGCTime = computeTotalGcTime()

      try {
        //反序例化Task的依赖获得一个包含task依赖文件地址、Jar包地址、byte buffer形式task的Tuple
        val (taskFiles, taskJars, taskBytes) = Task.deserializeWithDependencies(serializedTask)
        //通过网络下载需要的文件、Jar等，在同一个Stage内部并发线程会共享这些资源，该方法会被线程并发调用所以加锁
        updateDependencies(taskFiles, taskJars)
        //反序列化taskBytes得到task类型的Task对象
        task = ser.deserialize[Task[Any]](taskBytes, Thread.currentThread.getContextClassLoader)
        task.setTaskMemoryManager(taskMemoryManager)
      }

      //运行真实Task
      val (value, accumUpdates) = try {
        //见下
        val res = task.run(
          taskAttemptId = taskId,
          attemptNumber = attemptNumber,
          metricsSystem = env.metricsSystem)
        threwException = false
        res
      }
    }
  }
```

```java
package org.apache.spark.scheduler
/* Task是一个abstract class，它的子类为ShuffleMapTask或ResultTask */
private[spark] abstract class Task[T](...){
  //task.run()方法
  final def run(...): (T, AccumulatorUpdates) = {
    context = new TaskContextImpl(...)
    TaskContext.setTaskContext(context)
    context.taskMetrics.setHostname(Utils.localHostName())
    context.taskMetrics.setAccumulatorsUpdater(context.collectInternalAccumulators)
    taskThread = Thread.currentThread()
    if (_killed) {
      kill(interruptThread = false)
    }
    try {
      //Task的runTask有两种实现:ShuffleMapTask、ResultTask
      (runTask(context), context.collectAccumulators())
    } catch {
      ... 
    }
  }
}
```

4. ShuffleMapTask负责对partition数据计算，并通过Shuffle Write将计算结果写入磁盘（由BlockManager来管理），等待下游的RDD通过Shuffle Read读取.

```java
package org.apache.spark.scheduler
/* 为下游RDD计算输入数据: */
private[spark] class ShuffleMapTask(...) extends Task[MapStatus](...)
{
  override def runTask(context: TaskContext): MapStatus = {
    // Deserialize the RDD using the broadcast variable.
    val deserializeStartTime = System.currentTimeMillis()
    val ser = SparkEnv.get.closureSerializer.newInstance()
    //针对ShuffleMapTask先要对RDD及其他依赖关系进行反序例化
    val (rdd, dep) = ser.deserialize[(RDD[_], ShuffleDependency[_, _, _])](
      ByteBuffer.wrap(taskBinary.value), Thread.currentThread.getContextClassLoader)
    _executorDeserializeTime = System.currentTimeMillis() - deserializeStartTime
    metrics = Some(context.taskMetrics)
    var writer: ShuffleWriter[Any, Any] = null
    try {
      //SparkEnv中获取ShuffleManager对象
      val manager = SparkEnv.get.shuffleManager
      //获取可将Partition数据写入文件系统中的写对象ShuffleWriter
      writer = manager.getWriter[Any, Any](dep.shuffleHandle, partitionId, context)
      //在ShuffleMapTask的runTask内部调用RDD的iterator()方法，见下
      writer.write(rdd.iterator(partition, context).asInstanceOf[Iterator[_ <: Product2[Any, Any]]])
      //停止Writer并返回结果
      writer.stop(success = true).get
    } catch {
      ...
    }
  }
}
```

```java
package org.apache.spark.rdd

abstract class RDD[T: ClassTag](
    @transient private var _sc: SparkContext,
    @transient private var deps: Seq[Dependency[_]])
{
  /* 迭代Partition的元素并交给先定义好的Function进行处理 */
  final def iterator(split: Partition, context: TaskContext): Iterator[T] = {
    if (storageLevel != StorageLevel.NONE) {
      SparkEnv.get.cacheManager.getOrCompute(this, split, context, storageLevel)
    } else {
      //见下
      computeOrReadCheckpoint(split, context)
    }
  }


  private[spark] def computeOrReadCheckpoint(split: Partition, context: TaskContext): Iterator[T] =
  {
    if (isCheckpointedAndMaterialized) {
      //read it from a checkpoint if the RDD is checkpointing
      firstParent[T].iterator(split, context)
    } else {
      //见下
      compute(split, context)
    }
  }

  //最终计算会调用RDD的compute()方法，具体计算的时候有具体的RDD
  @DeveloperApi
  def compute(split: Partition, context: TaskContext): Iterator[T]
}
```


```java
package org.apache.spark.rdd
/* 如:MapPartitionsRDD.compute，其中的 f 就是在当前Stage内使用Partition做具体计算的业务逻辑代码 */
private[spark] class MapPartitionsRDD[U: ClassTag, T: ClassTag](
    var prev: RDD[T],
    f: (TaskContext, Int, Iterator[T]) => Iterator[U],
    preservesPartitioning: Boolean = false)
  extends RDD[U](prev)
{
  ...

  override def compute(split: Partition, context: TaskContext): Iterator[U] =
    f(context, split.index, firstParent[T].iterator(split, context))

  override def clearDependencies() {
    super.clearDependencies()
    prev = null
  }
}

  //诸如map、flatMap、filter常用RDD都会调用MapPartitionsRDD
  def map[U: ClassTag](f: T => U): RDD[U] = withScope {
    val cleanF = sc.clean(f)
    new MapPartitionsRDD[U, T](this, (context, pid, iter) => iter.map(cleanF))
  }

  def flatMap[U: ClassTag](f: T => TraversableOnce[U]): RDD[U] = withScope {
    val cleanF = sc.clean(f)
    new MapPartitionsRDD[U, T](this, (context, pid, iter) => iter.flatMap(cleanF))
  }

  def filter(f: T => Boolean): RDD[T] = withScope {
    val cleanF = sc.clean(f)
    new MapPartitionsRDD[T, T](this, (context, pid, iter) => iter.filter(cleanF), preservesPartitioning = true)
  }
```

操作完成后会把 MapStatus 发送给 DAGScheduler； (把 MapStatus 汇报给 MapOutputTracker)



5. ResultTask:根据前面Stage的执行结果进行Shuffle产生整个Job 最后的结果
MapOutputTracker会将ShuffleMapTask的执行结果交给ResultTask.
ResultTask对partition数据进行计算得到计算结果并汇报给Driver
CoraseGrainedExectorBackend 给 DriverEndpoint 发送 StatusUpdate 来传执行结果
```java
package org.apache.spark.scheduler

private[spark] class ResultTask[T, U](...) extends Task[U](...)
{
  override def runTask(context: TaskContext): U = {
    val deserializeStartTime = System.currentTimeMillis()
    val ser = SparkEnv.get.closureSerializer.newInstance()
    //针对ResultTask:使用广播变量对RDD及func函数进行反序例化
    val (rdd, func) = ser.deserialize[(RDD[T], (TaskContext, Iterator[T]) => U)](
      ByteBuffer.wrap(taskBinary.value), Thread.currentThread.getContextClassLoader)
    _executorDeserializeTime = System.currentTimeMillis() - deserializeStartTime

    metrics = Some(context.taskMetrics)
    func(context, rdd.iterator(partition, context))
  }
}
```


8. 程序继续执行，当遇到action类算子时会触发job的执行，DAGScheduler会切割这个job，根据RDD的宽窄依赖划分stage，DAGScheduler会将切割后的stage中的所有task封装到TaskSet对象中，然后提交给TaskScheduler.

9. TaskScheduler会遍历接收到的每一个TaskSet集合，将集合中每一个task发送给Executor中执行（TaskScheduler保留有Executor的地址列表，所以它知道task应该发送给哪些Executor），发送task时Spark会自动考虑到数据本地化的问题（即在数据所在的节点上执行task）.

```java
package org.apache.spark.rdd

/**
   * Get the preferred locations of a partition, taking into account whether the
   * RDD is checkpointed.
   */
  final def preferredLocations(split: Partition): Seq[String] = {
    checkpointRDD.map(_.getPreferredLocations(split)).getOrElse {
      getPreferredLocations(split)
    }
  }
```

10. task发送到Executor的线程池中执行有可能会失败，失败后会由TaskScheduler负责重试（重新发送该失败的task去执行），默认重试3次后仍失败，那么task所属的stage就执行失败；然后TaskScheduler会向DAGScheduler汇报，DAGScheduler会将该失败的stage重新封装到TaskSet集合，默认重试4次后仍失败，则此stage所属job就执行失败（job失败后不会重试）.

11. 遇到sc.stop()，释放所有资源.

## 资源调度的粒度

粗粒度（典型：spark）：在Application执行之前，将所有的资源（Executor）全部申请完毕；资源申请完毕后，才会进行任务的调度，当所有的任务执行完毕后，才会释放这部分资源.
优点：在每一个task执行之前，不需要自己去申请资源，task启动的时间短，相应的stage、job和application耗费的时间变短.
缺点：在所有的task执行完毕后才会释放资源，导致集群的资源无法充分利用.


细粒度（典型：MR）：在Application执行之前，不需要将资源全部申请好，直接进行任务调度。在每一个task执行之前，自己去申请资源，资源申请成功后，才会执行任务。当任务执行完成后，立即释放这部分资源。
优点：一个task执行完毕后，会立即释放这部分资源，集群的资源可以充分利用.
缺点：每一个task在执行之前，需要自己去申请资源，这样就导致task启动时间变长，进而导致stage、job、application的运行时间变长.


> Worker与Master节点间有心跳吗？发送心跳会携带当前资源情况吗？

Worker进程会定时向Master进程发送心跳；但是不会携带当前资源情况，因为Spark集群的资源调度基于粗粒度的调度方式，当前资源使用情况只需要在任务执行中减去之前申请的资源或任务执行完毕加上之前申请的资源即可.

> Spark 与 MapReduce 的区别（Spark为什么比MR运算速度快）？

1. Spark是基于内存迭代的，而MR是基于磁盘迭代的.

2. Spark的计算模式是pipeline模式，即1+1+1=3 ；MR的计算模式是：1+1=2，2+1=3. 

3. Spark是可以进行资源复用的（同一个Application中，不同的job之间可以进行资源复用，这里的资源指Executor，而Application之间是无法进行资源复用的）；而MR无法进行资源复用（job完成后会kill Executor进程，下一个job开始时需要重新申请资源启动Executor）.

4. Spark是粗粒度的资源调度；MR是细粒度的资源调度.


## 提交方式

Spark在客户端提交Application时，应用部署方式分为两种：client模式、cluster模式.

### client模式

若是以Client方式提交Application的，Driver进程会在客户端创建启动，一般适用于测试环境.

```bash
./spark-submit --master spark://spark1:7077 --deploy-mode client ../lib/FilterCount.jar
```

### cluster模式

若是以Cluster方式提交Application的，Driver进程会在集群中的某一台Worker节点（随机选取）上创建启动，一般适用于生产环境.

```bash
./spark-submit --master spark://spark1:7077 --deploy-mode cluster ../lib/FilterCount.jar
```

> 为什么Client模式适用于测试环境，Cluster模式适用于生产环境？

在任务与资源调度的流程中，我们知道Driver进程与Spark集群之间会有以下通信：

1. Driver向Master申请资源

2. Executor启动完毕后，反向注册到Driver端

3. Driver向Executor分发task

4. Executor进程与Driver进程有心跳机制

在生产环境中会频繁地提交应用程序，Driver进程与Spark集群之间会进行大量的通信：如果使用client模式提交，Driver进程只在客户端启动，则客户端网卡流量会被占满，导致其他应用程序卡死，所以client模式不适合生产环境；如果使用cluster模式提交，每个应用对应的Driver进程随机在集群任一Worker节点上启动，网卡流量激增的问题也就分散到集群中各个Worker节点上，所以cluster模式适用于生产环境.

而测试环境主要负责测试，并不会频繁地提交应用程序，不太会出现client模式提交导致客户端网卡流量被占满的情况；同时使用client模式提交应用在客户端上可以跟踪到task的运行情况和运行结果，而使用cluster模式在客户端上则无法跟踪到运行情况和结果（只能通过webUI查看），所以client模式适用于测试环境.


> 客户端提交应用与cluster模式部署区分？

使用客户端提交应用是为了防止因上传jar包时磁盘IO性能问题引起Spark集群节点间性能产生差异，而客户端提交jar包与启动Driver进程无关联，使用cluster模式部署随机在worker节点上启动Driver进程是为了防止频繁提交应用使得Driver进程与集群间大量通信导致卡死的问题.



```bash
若Application程序中和spark-submit时都未指定申请的资源信息，则会使用默认值.

同时在spark-submit提交Application时可以自定义：
--executor-memory       每个Executor进程需要使用的内存     default:1G
--executor-cores        每个Executor进程需要使用的core     default:每个Worker管理的core数
--total-executor-cores  当前Application总共需要使用的core  default:Int的最大值

若--executor-memory 3G --executor-cores 2 --total-executor-cores 10
不考虑集群Worker数则需要启动5个Executor进程
```
