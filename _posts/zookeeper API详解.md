---
title: zookeeper API详解
date: 2017-04-14 22:43:01
tags:
- zookeeper
- API
categories: 
- zookeeper
---

记录zookeeper的原生Java API的使用

<!--more-->

## shell操作

zookeeper内部是一个树形的数据结构，数据的key作为路径，每个key都对应一个value，value的值可以理解为String类型，/为根路径；通过例子可以看到zookeeper集群中数据的一致性

```bash
# zkCli.sh 进入zookeeper客户端
根据提示命令进行操作： 
	查找：ls /   ls /zookeeper
	创建并赋值：create /name stefan
	获取：get /name 
	设值：set /name lvfan
	删除：delete /name
```

```bash
[zk: localhost:2181(CONNECTED) 0] ls /
[zookeeper]
[zk: localhost:2181(CONNECTED) 1] ls /zookeeper
[quota]
[zk: localhost:2181(CONNECTED) 2] ls /zookeeper/quota
[]

---- 创建 ----
[zk: localhost:2181(CONNECTED) 3] create /name stefan
Created /name
---- 查看 ----
[zk: localhost:2181(CONNECTED) 4] ls /
[name, zookeeper] （在根路径创建了name）
[zk: localhost:2181(CONNECTED) 5] get /name
stefan
dataVersion = 0
dataLength = 6 （value长度）
---- 更新 ----
[zk: localhost:2181(CONNECTED) 6] set /name lvfan
dataVersion = 1 （更新后版本+1）
dataLength = 5
[zk: localhost:2181(CONNECTED) 7] get /name
lvfan
dataVersion = 1
dataLength = 5

---- 全路径创建 ----
[zk: localhost:2181(CONNECTED) 8] ls /name
[]
[zk: localhost:2181(CONNECTED) 9] create /name/0001 mary
Created /name/0001
[zk: localhost:2181(CONNECTED) 10] create /name/0002 john
Created /name/0002
[zk: localhost:2181(CONNECTED) 11] create /name/0003 tony
Created /name/0003
[zk: localhost:2181(CONNECTED) 12] create /name/0004 lucy
Created /name/0004
[zk: localhost:2181(CONNECTED) 13] create /name/0005 judy
Created /name/0005
[zk: localhost:2181(CONNECTED) 14] ls /name
[0004, 0005, 0002, 0003, 0001]

---- 删除 ----
[zk: localhost:2181(CONNECTED) 15] delete /name/0005
[zk: localhost:2181(CONNECTED) 16] ls /name
[0004, 0002, 0003, 0001]
```

## 代码实现

### 主线程阻塞

```bash
/**
 * 客户端简单连接zookeeper服务器集群
 * @author lf
 *
 */
public class ZookeeperBase {
	/** 集群地址  */
	static final String CONNECT_ADDR = "192.168.154.40:2181,192.168.154.41:2181,192.168.154.42:2181";
	/** session超时时间  */
	static final int SESSION_OUTTIME = 2000;
	/** 阻塞程序执行，用于等待zookeeper连接成功 */
	static final CountDownLatch ConnectedSemaphore = new CountDownLatch(1);
	
	public static void main(String[] args) throws Exception{
		ZooKeeper zk = new ZooKeeper(CONNECT_ADDR, SESSION_OUTTIME, new Watcher() {
			@Override
			public void process(WatchedEvent event) {
				//获取事件的状态
				KeeperState keeperState = event.getState();
				EventType eventType = event.getType();
				if(KeeperState.SyncConnected == keeperState) {
					if(EventType.None == eventType) {
						//后续阻塞程序向下执行
						//Ⅰ
						ConnectedSemaphore.countDown();
						System.out.println("--------->zk建立连接<---------");
					}
				}
			}
		});
		//阻塞着，主线程不着急往下走，等着另一个新启的线程zk建立连接后再往下走
		//Ⅱ
		ConnectedSemaphore.await();
		System.out.println("--------->zk:" + zk);
		//Ⅳ
		
		System.out.println("--------->程序继续执行<---------");
		//Ⅲ
		
		zk.close();
		System.out.println("--------->程序结束<---------");
	}
}
```

主线程执行阻塞返回结果打印

```bash
--------->zk建立连接<---------
--------->zk:State:CONNECTED Timeout:4000 sessionid:0x15de3d033660000 local:/192.168.154.1:60412 remoteserver:192.168.154.41/192.168.154.41:2181 lastZxid:0 xid:1 sent:1 recv:1 queuedpkts:0 pendingresp:0 queuedevents:0
--------->程序继续执行<---------
--------->程序结束<---------
```

主线程不执行阻塞（注销Ⅰ和Ⅱ处的ConnectedSemaphore；Ⅲ处添加TimeUnit.SECONDS.sleep(25)；）返回结果打印

```bash
--------->zk:State:CONNECTING sessionid:0x0 local:null remoteserver:null lastZxid:0 xid:1 sent:0 recv:0 queuedpkts:0 pendingresp:0 queuedevents:0
--------->程序继续执行<---------
--------->zk建立连接<---------
--------->程序结束<---------
```

由两次结果比较可以发现，Watcher的process()方法是一个异步的回调过程（因为没有提供同步的执行方法，create是有同步的方法，但是底层也是对异步做了封装而已）

使用ConnectedSemaphore.await()阻塞着，主线程不着急往下走，等着另一个新启的线程zk建立连接后ConnectedSemaphore.countDown()了再往下走；否则如第二个打印信息所示，zk还没初始化完成，主线程就已经使用了空信息的zk对象，结果肯定会出错。

### 同步创建节点

使用主线程阻塞正确建立zk连接后，在代码Ⅳ处分别添加如下代码创建节点；需要注意的是create的CreateMode参数有两种类型：短暂（ephemeral）、持久（persistent）

持久类型：

```bash
String ret = zk.create("/PERSISTENT", "PERSISTENT".getBytes(), Ids.OPEN_ACL_UNSAFE, CreateMode.PERSISTENT);
System.out.println("--------->ret:" + ret);

打印结果：
--------->zk建立连接<---------
--------->zk:State:CONNECTED Timeout:4000 sessionid:0x25dee47ebfd0000 local:/192.168.154.1:60699 remoteserver:192.168.154.42/192.168.154.42:2181 lastZxid:0 xid:1 sent:1 recv:1 queuedpkts:0 pendingresp:0 queuedevents:0
--------->ret:/PERSISTENT
--------->程序继续执行<---------
--------->程序结束<---------

在zk客户端断开连接后，PERSISTENT节点依然在服务端存在
```

短暂类型：

```bash
String ret = zk.create("/EPHEMERAL", "EPHEMERAL".getBytes(), Ids.OPEN_ACL_UNSAFE, CreateMode.EPHEMERAL);
System.out.println("--------->ret:" + ret);
TimeUnit.SECONDS.sleep(10);

打印结果：
--------->zk建立连接<---------
--------->zk:State:CONNECTED Timeout:4000 sessionid:0x5dee47edcc0002 local:/192.168.154.1:61123 remoteserver:192.168.154.40/192.168.154.40:2181 lastZxid:0 xid:1 sent:1 recv:1 queuedpkts:0 pendingresp:0 queuedevents:0
--------->ret:/EPHEMERAL
--------->程序继续执行<---------
--------->程序结束<---------

在sleep的10秒内，EPHEMERAL节点在服务器端存在着，但是zk.close后节点就消失了；说明EPHEMERAL类型创建的节点只在客户端连接状态临时存在
```

### 创建子节点

原生的不支持递归创建节点，只能先创建/node节点，再创建/node/test

```bash
String ret = zk.create("/node/test", "EPHEMERAL".getBytes(), Ids.OPEN_ACL_UNSAFE, CreateMode.EPHEMERAL);
System.out.println("--------->ret:" + ret);

打印结果：
--------->zk建立连接<---------
--------->zk:State:CONNECTED Timeout:4000 sessionid:0x15dee47ebc10000 local:/192.168.154.1:61364 remoteserver:192.168.154.41/192.168.154.41:2181 lastZxid:0 xid:1 sent:1 recv:1 queuedpkts:0 pendingresp:0 queuedevents:0
Exception in thread "main" org.apache.zookeeper.KeeperException$NoNodeException: KeeperErrorCode = NoNode for /node/test
	at org.apache.zookeeper.KeeperException.create(KeeperException.java:111)
	at org.apache.zookeeper.KeeperException.create(KeeperException.java:51)
	at org.apache.zookeeper.ZooKeeper.create(ZooKeeper.java:783)
	at com.zoo.base.ZookeeperBase.main(ZookeeperBase.java:50)
```

### 异步创建节点

相对来说异步的效率更高，增删改查都有回调的api，以创建为例

```bash
zk.create("/node/async", "async".getBytes(), Ids.OPEN_ACL_UNSAFE, CreateMode.PERSISTENT, new AsyncCallback.StringCallback() {
    @Override
    public void processResult(int resultCode, String parentPath, Object ctx, String name) {
        System.out.println("------------->回调线程:" + Thread.currentThread().getName());
        System.out.println("------------->resultCode:" + resultCode);//=0表示正常执行
        System.out.println("------------->parentPath:" + parentPath);
        System.out.println("------------->context:" + ctx);//上下文
        System.out.println("------------->name:" + name);
    }
}, "param");
System.out.println("------------->主线程:" + Thread.currentThread().getName());
System.out.println("--------->程序继续执行<---------");
TimeUnit.SECONDS.sleep(5);
zk.close();
System.out.println("--------->程序结束<---------");

打印结果：
--------->zk建立连接<---------
--------->zk:State:CONNECTED Timeout:4000 sessionid:0x15dee47ebc10002 local:/192.168.154.1:61995 remoteserver:192.168.154.41/192.168.154.41:2181 lastZxid:0 xid:1 sent:1 recv:1 queuedpkts:0 pendingresp:0 queuedevents:0
------------->主线程:main
--------->程序继续执行<---------
------------->回调线程:main-EventThread
------------->resultCode:0
------------->parentPath:/node/async
------------->context:param
------------->name:/node/async
--------->程序结束<---------
```

### 获取节点信息

单个节点获取

```bash
byte[] data = zk.getData("/name/0001", false, null);
System.out.println("-------------->data:"+new String(data));

打印信息：
--------->zk建立连接<---------
--------->zk:State:CONNECTED Timeout:4000 sessionid:0x5dee47edcc0004 local:/192.168.154.1:62554 remoteserver:192.168.154.40/192.168.154.40:2181 lastZxid:0 xid:1 sent:1 recv:1 queuedpkts:0 pendingresp:0 queuedevents:0
-------------->data:mary
--------->程序继续执行<---------
--------->程序结束<---------
```

多节点获取

```bash
//获取的path只是相对路径
for(String path : zk.getChildren("/name", false)) {
	System.out.println("----------->data:" + new String(zk.getData("/name/"+path, false, null)));
}

打印信息：
--------->zk建立连接<---------
--------->zk:State:CONNECTED Timeout:4000 sessionid:0x25dee47ebfd0002 local:/192.168.154.1:62787 remoteserver:192.168.154.42/192.168.154.42:2181 lastZxid:0 xid:1 sent:1 recv:1 queuedpkts:0 pendingresp:0 queuedevents:0
----------->data:lucy
----------->data:john
----------->data:tony
----------->data:mary
--------->程序继续执行<---------
--------->程序结束<---------
```

### 修改节点信息

```bash
zk.setData("/name/0001", "stefan".getBytes(), -1);//-1为版本号设置，不加也无所谓主要是规范，-1的作用是将节点的版本号更新到最新状态
System.out.println("------------->modify data:" + new String(zk.getData("/name/0001", false, null)));

打印信息：
--------->zk建立连接<---------
--------->zk:State:CONNECTED Timeout:4000 sessionid:0x15dee47ebc10003 local:/192.168.154.1:62951 remoteserver:192.168.154.41/192.168.154.41:2181 lastZxid:0 xid:1 sent:1 recv:1 queuedpkts:0 pendingresp:0 queuedevents:0
------------->modify data:stefan
--------->程序继续执行<---------
--------->程序结束<---------
```

### 删除节点

先判断需要删除的节点是否存在，若=null则不存在

```bash
//删除之前先判断节点是否存在
System.out.println("------------->exist1:"+ zk.exists("/name/0001", false));
System.out.println("------------->exist2:"+ zk.exists("/name/00010000", false));

打印信息：
------------->exist1:12884901895,25769803810,1502739400632,1502956447470,2,0,0,0,6,0,12884901895
------------->exist2:null
```

删除节点

```bash
//正常删除
zk.delete("/node/asyn", -1);

//异常删除
zk.delete("/node/", -1);

打印信息：
Exception in thread "main" java.lang.IllegalArgumentException: Path must not end with / character
	at org.apache.zookeeper.common.PathUtils.validatePath(PathUtils.java:58)
	at org.apache.zookeeper.ZooKeeper.delete(ZooKeeper.java:851)
	at com.zoo.base.ZookeeperBase.main(ZookeeperBase.java:83)

//异常删除
zk.delete("/node", -1);

打印信息：
Exception in thread "main" org.apache.zookeeper.KeeperException$NotEmptyException: KeeperErrorCode = Directory not empty for /node
	at org.apache.zookeeper.KeeperException.create(KeeperException.java:125)
	at org.apache.zookeeper.KeeperException.create(KeeperException.java:51)
	at org.apache.zookeeper.ZooKeeper.delete(ZooKeeper.java:873)
	at com.zoo.base.ZookeeperBase.main(ZookeeperBase.java:83)
```