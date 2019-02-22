---
title: zookeeper之开源客户端框架Curator
date: 2017-04-16 22:43:01
tags:
- zookeeper
- Curator
categories: 
- zookeeper
---

记录Apache维护的zookeeper客户端顶级开源框架Curator

<!--more-->

# 什么是Curator

Curator是对zookeeper自带的客户端做的封装的开源框架，主要实现了以下内容：

* API基于链式风格（Fluent）实现

* 对ZKClient与ZKServer之间连接处理的封装

* 提供ZooKeeper各种应用场景recipe的抽象封装（如：分布式计数器、分布式队列、共享锁服务、Leader选举机制、事务等；除了两阶段提交）

* 以及提供实用的工具类

# recipe实现

## client与server的连接重试

重试策略：以ExponentialBackoffRetry为例，它继承自SleepingRetry，而SleepingRetry实现了RetryPolicy接口，理解下ExponentialBackoffRetry的实现：

```bash
//一般选择该构造初始ExponentialBackoffRetry即可，参数为重试等待的初始时间、重试次数.
public ExponentialBackoffRetry(int baseSleepTimeMs, int maxRetries) {
    this(baseSleepTimeMs, maxRetries, DEFAULT_MAX_SLEEP_MS);
}

//还可以指定最大等待时间maxSleepMs，不添加该参数选择上一种构造则默认maxSleepMs=Integer.MAX_VALUE
public ExponentialBackoffRetry(int baseSleepTimeMs, int maxRetries, int maxSleepMs) {
    super(validateMaxRetries(maxRetries));
    this.baseSleepTimeMs = baseSleepTimeMs;
    this.maxSleepMs = maxSleepMs;
}

//每次重试之间等待时间是动态逐渐增加的
int sleepMs = baseSleepTimeMs * Math.max(1, random.nextInt(1 << (retryCount + 1)));
//如果通过初始等待时间计算出的随机时间大于规定的最大等待时间，则使用规定最大等待时间
if (sleepMs > maxSleepMs) {
    sleepMs = maxSleepMs;
}

//同样的重试次数如果大于默认最大重试次数29，则使用29
private static int validateMaxRetries(int maxRetries) {
    if (maxRetries > MAX_RETRIES_LIMIT) {
        maxRetries = MAX_RETRIES_LIMIT;
    }
    return maxRetries;
}
```

## 工厂方法创建连接

示例代码：使用工厂方法简单的创建节点

```bash
//1. 重试：初始等待时间为1s，重试10次.
RetryPolicy retryPolicy = new ExponentialBackoffRetry(1000, 10);

//2. 通过工厂创建连接
CuratorFramework cf = CuratorFrameworkFactory.builder()
    .connectString("192.168.154.40:2181,192.168.154.41:2181,192.168.154.42:2181")
    .connectionTimeoutMs(5000)
    .sessionTimeoutMs(50000)
    .retryPolicy(retryPolicy)
    .namespace("super")
    .build();

//3. 开启连接
cf.start();

//4. 支持递归的创建节点、指定节点类型（不加withMode默认为持久类型节点）、路径、数据内容
try {
    cf.create()
        .creatingParentsIfNeeded()
        .withMode(CreateMode.PERSISTENT)
        .forPath("/c1","c1内容".getBytes());
}catch(Exception e) {
    System.out.println("新增节点异常...");
    e.printStackTrace();
}finally {
    //使用CuratorFramwork提供的工具类优雅关闭
    //内部使用Guava的API：com.google.common.io.Closeables.close(cf, true);
    CloseableUtils.closeQuietly(cf);
}
```

关于namespace：CuratorFramework提供命名空间的概念，由于zk集群是应用间空间共享的，可以通过添加namespace避免多个应用的节点路径名称冲突；若不设置则默认为/根目录，若设置了namespace，会在操作znode的path前添加namespace作为root目录（如：上面的create path其实是/super/c1依次递归创建）.

## 基础API

```bash
//创建节点create方法
cf.create().
    creatingParentsIfNeeded()
    .withMode(CreateMode.PERSISTENT)
    .forPath("/super/c2","c2 infomation".getBytes());

//读取节点getData方法
String ret = new String(cf.getData().forPath("/super/c2"));
System.out.println(ret);

//修改节点setData方法
cf.setData().forPath("/super/c2", "c2 updating infomation".getBytes());

// 读取子节点getChildren方法
List<String> list = cf.getChildren().forPath("/super");
for(String p : list) {
    System.out.println(p);
}

//判断节点是否存在checkExists方法
Stat stat = cf.checkExists().forPath("/super/c3");
System.out.println(stat);

// 绑定回调函数
ExecutorService pool = Executors.newCachedThreadPool();//支持线程池异步执行
cf.create()
    .creatingParentsIfNeeded()
    .withMode(CreateMode.PERSISTENT)
    .inBackground(new BackgroundCallback() {
        @Override
        public void processResult(CuratorFramework cf, CuratorEvent ce) throws Exception {
            System.out.println("code:" + ce.getResultCode());
            System.out.println("type:" + ce.getType());
            System.out.println("线程为:" + Thread.currentThread().getName());
        }
    }, pool)
    .forPath("/super/c3","c3 infomation".getBytes());
Thread.sleep(Integer.MAX_VALUE);

//递归删除，guaranteed()是一个保障措施，只要客户端会话有效，那么Curator会在后台持续进行删除操作，直到删除节点成功
cf.delete()
    .guaranteed()
    .deletingChildrenIfNeeded()
    .forPath("/super");
```

## 事务

2.x版本中的事务控制，在3.x中被废弃

```bash
cf.create().creatingParentsIfNeeded().withMode(CreateMode.PERSISTENT).forPath("/super/tran1", "tran1_info".getBytes());
cf.create().creatingParentsIfNeeded().withMode(CreateMode.PERSISTENT).forPath("/super/tran2", "tran2_info".getBytes());
//开启事务
CuratorTransaction transaction = cf.inTransaction();
//复合型操作，保证事务的原子性不受并发影响
try {
    Collection<CuratorTransactionResult> results = transaction
        .create()
        .forPath("/super/tran3", "tran3_info".getBytes())
        .and()
        .setData()
        .forPath("super/tran1", "tran1_updating_info".getBytes())
        .and()
        .delete()
        .forPath("/super/tran2")
        .and()
        .commit();
    for(CuratorTransactionResult result : results) {
        System.out.println(result.getForPath() + "-" + result.getType());
    }
}catch(Exception e) {
    e.printStackTrace();
    System.out.println("事务异常....");
}finally {
    CloseableUtils.closeQuietly(cf);
}
```

3.x版本中的事务控制

```bash
cf.create().creatingParentsIfNeeded().withMode(CreateMode.PERSISTENT).forPath("/super/tran1", "tran1_info".getBytes());
cf.create().creatingParentsIfNeeded().withMode(CreateMode.PERSISTENT).forPath("/super/tran2", "tran2_info".getBytes());

//复合型操作，保证事务的原子性不受并发影响
try {
    CuratorOp createOp = cf.transactionOp().create().forPath("super/tran3", "tran3_info".getBytes());
    CuratorOp setDataOp = cf.transactionOp().setData().forPath("super/tran1", "tran1_updating_info".getBytes());
    CuratorOp deleteOp = cf.transactionOp().delete().forPath("super/tran2");
    Collection<CuratorTransactionResult> results = cf.transaction().forOperations(createOp, setDataOp, deleteOp);
    for(CuratorTransactionResult result : results) {
        System.out.println(result.getForPath() + "-" + result.getType());
    }
}catch(Exception e) {
    e.printStackTrace();
    System.out.println("事务异常....");
}finally {
    CloseableUtils.closeQuietly(cf);
}
```

## watcher

### 第一种watcher 删除节点的时候并不触发

通过客户端本地建立一个cache缓存以提高性能，初始化创建cf对象后加载监听节点的数据缓存到本地client，一旦监听节点数据发生改变，将Server节点更新后的数据通知到client，与缓存中数据对比，如果发生了改变，修改本地缓存数据，同时触发Listener，执行nodeChanged方法.

需要测试setData()方法数据修改内容为原内容时，是否触发listener?????

```bash
final NodeCache cache = new NodeCache(cf, "/super", false);//false表示数据不进行压缩，数据量大的时候可以设为true进行压缩，一般false就好
cache.start(true);//初始化缓存
cache.getListenable().addListener(new NodeCacheListener() {
    /**
      * <B>方法名称：</B>nodeChanged<BR>
      * <B>概要说明：</B>触发事件为创建节点和更新节点，在删除节点的时候并不触发此操作。<BR>
      */
    @Override
    public void nodeChanged() throws Exception {
        //可以发现NodeCacheListener()并不需要传参，而是操作缓存中同步server后的CurrentData
        //以下获取的数据是从本地缓存取出来的
        System.out.println("路径为：" + cache.getCurrentData().getPath());
        System.out.println("数据为：" + new String(cache.getCurrentData().getData()));
        System.out.println("状态为：" + cache.getCurrentData().getStat());
        System.out.println("---------------------------------------");
    }
});

Thread.sleep(1000);
cf.create().forPath("/super", "123".getBytes());
Thread.sleep(1000);
cf.setData().forPath("/super", "456".getBytes());
Thread.sleep(1000);
cf.delete().forPath("/super");
Thread.sleep(Integer.MAX_VALUE);
```

### 常用的一种watcher

对子节点的所有操作都监听，本身节点的操作不监听，在实际应用中也不需要监听本身节点，所以这种watcher比较常用；而第一种是监听节点及其子节点的创建、更新都触发，但删除不触发.

```bash
//4 建立一个PathChildrenCache缓存,第三个参数为是否接受节点数据内容对数据进行本地缓存，若为false则不接收数据缓存
PathChildrenCache cache = new PathChildrenCache(cf, "/super", true);
//5 在初始化的时候就进行缓存监听
cache.start(StartMode.POST_INITIALIZED_EVENT);
cache.getListenable().addListener(new PathChildrenCacheListener() {
    /**
      * <B>方法名称：</B>监听子节点变更,本身节点并不监听<BR>
      * <B>概要说明：</B>新建、修改、删除<BR>
      * childEvent方法提供回调
      */
    @Override
    public void childEvent(CuratorFramework cf, PathChildrenCacheEvent event) throws Exception {
        switch (event.getType()) {
        case CHILD_ADDED:
            System.out.println("CHILD_ADDED :" + event.getData().getPath());
            break;
        case CHILD_UPDATED:
            System.out.println("CHILD_UPDATED :" + event.getData().getPath());
            break;
        case CHILD_REMOVED:
            System.out.println("CHILD_REMOVED :" + event.getData().getPath());
            break;
        default:
            break;
        }
    }
});

//创建本身节点不发生变化
cf.create().forPath("/super", "init".getBytes());

//添加子节点
Thread.sleep(1000);
cf.create().forPath("/super/c1", "c1_info".getBytes());
Thread.sleep(1000);
cf.create().forPath("/super/c2", "c2_info".getBytes());

//修改子节点
Thread.sleep(1000);
cf.setData().forPath("/super/c1", "c1_updating_info".getBytes());

//删除子节点
Thread.sleep(1000);
cf.delete().forPath("/super/c2");		

//删除本身节点
Thread.sleep(1000);
cf.delete().deletingChildrenIfNeeded().forPath("/super");

Thread.sleep(Integer.MAX_VALUE);
```

## 分布式锁

在分布式场景中，为保证数据的一致性，我们需要对程序运行中的某一个点进行同步操作；在非分布式环境中，使用java为我们提供的synchronized或Reentrantlock，可以保证高并发下访问同一个程序（同一jvm）时数据的一致性；但是在分布式环境中，高并发访问多个服务器节点上的相同程序时，服务器间（多个jvm）就会出现分布式不同步的问题.   

我们可以使用Curator基于zookeeper的特性提供的分布式锁来实现分布式场景中的数据一致性（zookeeper本身的分布式存在写的问题，建议使用Curator的分布式锁）；实现原理就是Curator是针对某个节点上添加锁，一旦其中一台服务器中该节点被一个客户端占用，那么需要操作该节点的其他客户端（不论连接分布式环境中的哪一台server，只要操作该节点的客户端）都阻塞着等待当前占用的客户端释放.

```bash
public static CuratorFramework createCuratorFramework(){
    RetryPolicy retryPolicy = new ExponentialBackoffRetry(1000, 10);
    CuratorFramework cf = CuratorFrameworkFactory.builder()
                .connectString("192.168.154.40:2181,192.168.154.41:2181,192.168.154.42:2181")
                .sessionTimeoutMs(5000)
                .retryPolicy(retryPolicy)
                .build();
    return cf;
}

public static void main(String[] args) throws Exception {
    final CountDownLatch coutdown = new CountDownLatch(1);
    for(int i = 0; i < 10; i++){
        new Thread(new Runnable() {
            @Override
            public void run() {
                CuratorFramework cf = createCuratorFramework();
                cf.start();
                //指定节点加锁
                final InterProcessMutex lock = new InterProcessMutex(cf, "/super");
                try {
                    //阻塞着
                    coutdown.await();
                    //获取锁
                    lock.acquire();
                    System.out.println(Thread.currentThread().getName() + "执行业务逻辑..");
                    Thread.sleep(1000);
                } catch (Exception e) {
                    e.printStackTrace();
                } finally {
                    try {
                        //释放
                        lock.release();
                    } catch (Exception e) {
                        e.printStackTrace();
                    }
                }
            }
        },"t" + i).start();
    }
    //等待10个线程创建完成
    Thread.sleep(3000);
    //释放阻塞，10个线程同时获取锁模拟并发
    coutdown.countDown();
}

打印结果：
t7执行业务逻辑..
t0执行业务逻辑..
t6执行业务逻辑..
t1执行业务逻辑..
t8执行业务逻辑..
t9执行业务逻辑..
t2执行业务逻辑..
t5执行业务逻辑..
t4执行业务逻辑..
t3执行业务逻辑..
```

## 分布式计数器

与分布式锁类似，java只能保证在单个jvm中多线程并发时计数器的正常顺序自增（java的AtomicInteger）；而在分布式环境中，也是依靠zookeeper在某一个节点上加分布式锁，通过zookeeper的特性保证多线程并发访问该节点时分布式环境下计数器的同步完整性

```bash
//这里的RetryNTimes参数：3代表重试次数，1000代表每次重试前等待1s
DistributedAtomicInteger atomicIntger = 
        new DistributedAtomicInteger(cf, "/super", new RetryNTimes(3, 1000));
//atomicIntger.forceSet(0);//重置为0
//atomicIntger.increment();//+1
AtomicValue<Integer> value = atomicIntger.add(1);//自增1
System.out.println(value.preValue());	//原始值0
System.out.println(value.succeeded());
if(value.succeeded) {
    System.out.println(value.postValue());	//最新值1
}
```

## 选举机制

Curator有两种leader选举的recipe,分别是LeaderSelector和LeaderLatch。

LeaderSelector是所有存活的客户端不间断的轮流做Leader；LeaderLatch是一旦选举出Leader，除非有客户端挂掉重新触发选举，否则不会交出领导权.


