---
title: zookeeper之理解watch与watcher
date: 2017-04-15 19:43:01
tags:
- zookeeper
- API
categories: 
- zookeeper
---

记录zookeeper原生API中watch事件和watcher监听程序的深刻理解

<!--more-->

## 概念理解 

有一个节点/node，监听node节点的动作叫watch，监听node节点的程序叫watcher；

当我们给node节点的操作设置watch=true，就说明当前上下文的watcher对象需要对node节点的watch事件进行监听；

## watch的特性

一次性：zookeeper的watch事件被一次触发后就消失了（为了减小节点的负担，提高性能），如果有多个client监听程序watcher监听同一node节点，那么一次性触发watch事件，zookeeper会同时给所有监听node节点的client发送节点变更信息；

轻量：watch触发只会通知client监听程序watcher发生了事件数据变更，返回信息（节点事件类型、通知状态、节点路径）但不会返回更新的具体数据，具体数据需要我们自己去获取；

## 类型

KeeperState：通知状态类型，与客户端实例相关

EventType：事件类型，与监听节点相关

```bash
if(keeperState == KeeperState.SyncConnected) {
    //与zk服务器正常连接
    if(eventType == EventType.None) {
    //无事件
    }else if(eventType == EventType.NodeCreated) {
    //节点创建
    }else if(eventType == EventType.NodeDataChanged) {
    //节点数据更新
    }else if(eventType == EventType.NodeChildrenChanged) {
    //子节点更新
    }else if(eventType == EventType.NodeDeleted) {
    //节点被删除
    }else ;		
}else if(keeperState == KeeperState.Disconnected) {
    //与ZK服务器断开连接
}else if(keeperState == KeeperState.AuthFailed) {
    //权限检查失败
}else if(keeperState == KeeperState.Expired) {
    //会话失效
}else ;
```

## 代码实现

```bash
/**
 * Zookeeper Wathcher 
 * 本类就是一个Watcher类（实现了org.apache.zookeeper.Watcher类）
 * @author lf
 *
 */
public class ZooKeeperWatcher implements Watcher {

	/** 定义原子变量 */
	AtomicInteger seq = new AtomicInteger();
	/** 定义session失效时间 */
	private static final int SESSION_TIMEOUT = 10000;
	/** zookeeper服务器地址 */
	private static final String CONNECTION_ADDR = "192.168.154.40:2181,192.168.154.41:2181,192.168.154.42:2181";
	/** zk父路径设置 */
	private static final String PARENT_PATH = "/p";
	/** zk子路径设置 */
	private static final String CHILDREN_PATH = "/p/c";
	/** 进入标识 */
	private static final String LOG_PREFIX_OF_MAIN = "【Main】";
	/** zk变量 */
	private ZooKeeper zk = null;
	/**用于等待zookeeper连接建立之后 通知阻塞程序继续向下执行 */
	private CountDownLatch connectedSemaphore = new CountDownLatch(1);

//--------------------封装zookeeper--------------------

	/**
	 * 创建ZK连接
	 * @param connectAddr ZK服务器地址列表
	 * @param sessionTimeout Session超时时间
	 */
	public void createConnection(String connectAddr, int sessionTimeout) {
		this.releaseConnection();
		try {
			//this表示把当前对象进行传递到其中去（也就是在主函数里实例化的new ZooKeeperWatcher()实例对象）
			zk = new ZooKeeper(connectAddr, sessionTimeout, this);
			System.out.println(LOG_PREFIX_OF_MAIN + "开始连接ZK服务器");
			connectedSemaphore.await();
		} catch (Exception e) {
			e.printStackTrace();
		}
	}

	/**
	 * 关闭ZK连接
	 */
	public void releaseConnection() {
		if (this.zk != null) {
			try {
				this.zk.close();
			} catch (InterruptedException e) {
				e.printStackTrace();
			}
		}
	}

//--------------------------简单封装zookeeperAPI------------------------------

	/**
	 * 创建节点
	 * @param path 节点路径
	 * @param data 数据内容
	 * @return 
	 */
	public boolean createPath(String path, String data, boolean needWatch) {
		try {
			//设置监控(由于zookeeper的监控都是一次性的所以 每次必须设置监控)
			this.zk.exists(path, needWatch);
			System.out.println(LOG_PREFIX_OF_MAIN + "节点创建成功, Path: " + 
			    this.zk.create(path, data.getBytes(), Ids.OPEN_ACL_UNSAFE /**所有可见*/, CreateMode.PERSISTENT ) + 	
			    ", content: " + data);
		} catch (Exception e) {
			e.printStackTrace();
			return false;
		}
		return true;
	}

	/**
	 * 读取指定节点数据内容
	 * @param path 节点路径
	 * @return
	 */
	public String readData(String path, boolean needWatch) {
		try {
			System.out.println("读取数据操作...");
			return new String(this.zk.getData(path, needWatch, null));
		} catch (Exception e) {
			e.printStackTrace();
			return "";
		}
	}

	/**
	 * 更新指定节点数据内容
	 * @param path 节点路径
	 * @param data 数据内容
	 * @return
	 */
	public boolean writeData(String path, String data) {
		try {
			System.out.println(LOG_PREFIX_OF_MAIN + "更新数据成功，path：" + path + ", stat: " +
			    this.zk.setData(path, data.getBytes(), -1));
		} catch (Exception e) {
			e.printStackTrace();
			return false;
		}
		return true;
	}

	/**
	 * 删除指定节点
	 * @param path 节点path
	 */
	public void deleteNode(String path) {
		try {
			this.zk.delete(path, -1);
			System.out.println(LOG_PREFIX_OF_MAIN + "删除节点成功，path：" + path);
		} catch (Exception e) {
			e.printStackTrace();
		}
	}

	/**
	 * 判断指定节点是否存在
	 * @param path 节点路径
	 */
	public Stat exists(String path, boolean needWatch) {
		try {
			return this.zk.exists(path, needWatch);
		} catch (Exception e) {
			e.printStackTrace();
			return null;
		}
	}

	/**
	 * 获取子节点
	 * @param path 节点路径
	 */
	private List<String> getChildren(String path, boolean needWatch) {
		try {
			System.out.println("读取子节点操作...");
			return this.zk.getChildren(path, needWatch);
		} catch (Exception e) {
			e.printStackTrace();
			return null;
		}
	}

	/**
	 * 删除所有节点
	 */
	public void deleteAllTestPath(boolean needWatch) {
		if(this.exists(CHILDREN_PATH, needWatch) != null){
			this.deleteNode(CHILDREN_PATH);
		}
		if(this.exists(PARENT_PATH, needWatch) != null){
			this.deleteNode(PARENT_PATH);
		}		
	}
	
//---------------接收zookeeper Server端watch事件触发后，watcher回调信息处理-----------------------

	/**
	 * 收到来自Server的Watcher通知后的处理。
	 */
	@Override
	public void process(WatchedEvent event) {
		
		System.out.println("进入 process 。。。。。event = " + event);
		
		try {
			Thread.sleep(200);
		} catch (InterruptedException e) {
			e.printStackTrace();
		}
		
		if (event == null) {
			return;
		}
		
		// 连接状态
		KeeperState keeperState = event.getState();
		// 事件类型
		EventType eventType = event.getType();
		// 受影响的path
		String path = event.getPath();
		//原子对象seq 记录进入process的次数
		String logPrefix = "【Watcher-" + this.seq.incrementAndGet() + "】";

		System.out.println(logPrefix + "收到Watcher通知");
		System.out.println(logPrefix + "连接状态:\t" + keeperState.toString());
		System.out.println(logPrefix + "事件类型:\t" + eventType.toString());

		if (KeeperState.SyncConnected == keeperState) {
			// 成功连接上ZK服务器
			if (EventType.None == eventType) {
				System.out.println(logPrefix + "成功连接上ZK服务器");
				connectedSemaphore.countDown();
			} 
			//创建节点
			else if (EventType.NodeCreated == eventType) {
				System.out.println(logPrefix + "节点创建");
				try {
					Thread.sleep(100);
				} catch (InterruptedException e) {
					e.printStackTrace();
				}
			} 
			//更新节点
			else if (EventType.NodeDataChanged == eventType) {
				System.out.println(logPrefix + "节点数据更新");
				try {
					Thread.sleep(100);
				} catch (InterruptedException e) {
					e.printStackTrace();
				}
			} 
			//更新子节点
			else if (EventType.NodeChildrenChanged == eventType) {
				System.out.println(logPrefix + "子节点变更");
				try {
					Thread.sleep(3000);
				} catch (InterruptedException e) {
					e.printStackTrace();
				}
			} 
			//删除节点
			else if (EventType.NodeDeleted == eventType) {
				System.out.println(logPrefix + "节点 " + path + " 被删除");
			}
			else ;
		} 
		else if (KeeperState.Disconnected == keeperState) {
			System.out.println(logPrefix + "与ZK服务器断开连接");
		} 
		else if (KeeperState.AuthFailed == keeperState) {
			System.out.println(logPrefix + "权限检查失败");
		} 
		else if (KeeperState.Expired == keeperState) {
			System.out.println(logPrefix + "会话失效");
		}
		else ;

		System.out.println("--------------------------------------------");

	}

//--------------------------Main创建Client调用API触发watch事件------------------------------

	/**
	 * <B>方法名称：</B>测试zookeeper监控<BR>
	 * <B>概要说明：</B>主要测试watch功能<BR>
	 * @param args
	 * @throws Exception
	 */
	public static void main(String[] args) throws Exception {

		//建立watcher //当前客户端可以称为一个watcher 观察者角色
		ZooKeeperWatcher zkWatch = new ZooKeeperWatcher();
		//创建连接 
		zkWatch.createConnection(CONNECTION_ADDR, SESSION_TIMEOUT);
		//System.out.println(zkWatch.zk.toString());
		
		Thread.sleep(1000);
		
		// 清理节点
		zkWatch.deleteAllTestPath(false);
		
		//-----------------第一步: 创建父节点 /p ------------------------//
		if (zkWatch.createPath(PARENT_PATH, System.currentTimeMillis() + "", true)) {
			
			Thread.sleep(1000);
			
			//-----------------第二步: 读取节点 /p 和    读取/p节点下的子节点(getChildren)的区别 --------------//
			// 读取数据
			zkWatch.readData(PARENT_PATH, true);
		
			// 读取子节点(监控childNodeChange事件)
			zkWatch.getChildren(PARENT_PATH, true);

			// 更新数据
			zkWatch.writeData(PARENT_PATH, System.currentTimeMillis() + "");
			
			Thread.sleep(1000);
			// 创建子节点
			zkWatch.createPath(CHILDREN_PATH, System.currentTimeMillis() + "", true);
			
			
			//-----------------第三步: 建立子节点的触发 --------------//
			//zkWatch.createPath(CHILDREN_PATH + "/c1", System.currentTimeMillis() + "", true);
			//zkWatch.createPath(CHILDREN_PATH + "/c1/c2", System.currentTimeMillis() + "", true);
			
			//-----------------第四步: 更新子节点数据的触发 --------------//
			//在进行修改之前，我们需要watch一下这个节点：
			Thread.sleep(1000);
			zkWatch.readData(CHILDREN_PATH, true);
			zkWatch.writeData(CHILDREN_PATH, System.currentTimeMillis() + "");
			
		}
		
		Thread.sleep(10000);
		// 清理节点
		zkWatch.deleteAllTestPath(false);
	
		Thread.sleep(10000);
		zkWatch.releaseConnection();	
	}
}
```