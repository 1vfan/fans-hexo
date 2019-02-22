---
title: zookeeper集群搭建
date: 2017-04-14 19:43:01
tags:
- zookeeper
- Linux
- 集群
categories: 
- zookeeper
---

记录如何快速搭建一个高可用的zookeeper集群环境以及在客户端执行简单数据操作

<!--more-->

以下配置在三台机器上都要操作，以一台为例

|Hostname|IP|Port|
|---|---|---|
|zoo1|192.168.154.40|2181|
|zoo2|192.168.154.41|2181|
|zoo3|192.168.154.42|2181|

## 解压

```bash
# cd /usr/local/software
# tar -zxvf zookeeper-3.4.6.tar.gz -C /usr/local
```

## 配置环境变量

```bash
# vim /etc/profile

JAVA_HOME=/usr/local/jdk1.8
JRE_HOME=$JAVA_HOME/jre
ZOOKEEPER_HOME=/usr/local/zookeeper-3.4.6
CLASS_PATH=.:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar:$JRE_HOME/lib
PATH=$PATH:$ZOOKEEPER_HOME/bin:$JAVA_HOME/bin:$JRE_HOME/bin
export ZOOKEEPER_HOME JAVA_HOME JRE_HOME CLASS_PATH PATH

# source /etc/profile
```

## 配置文件操作

```bash
# cd /usr/local/zookeeper-3.4.6/conf
# ll
总用量 12
-rw-rw-r--. 1 1000 1000  535 2月  20 2014 configuration.xsl
-rw-rw-r--. 1 1000 1000 2161 2月  20 2014 log4j.properties
-rw-rw-r--. 1 1000 1000  922 2月  20 2014 zoo_sample.cfg
# mv zoo_sample.cfg zoo.cfg
# ll
总用量 12
-rw-rw-r--. 1 1000 1000  535 2月  20 2014 configuration.xsl
-rw-rw-r--. 1 1000 1000 2161 2月  20 2014 log4j.properties
-rw-rw-r--. 1 1000 1000  922 2月  20 2014 zoo.cfg
# vim zoo.cfg
按照下面配置操作

# grep '^[a-z]' zoo.cfg 
tickTime=2000
initLimit=10
syncLimit=5
dataDir=/usr/local/zookeeper-3.4.6/data
clientPort=2181
server.0=192.168.154.40:2888:3888
server.1=192.168.154.41:2888:3888
server.2=192.168.154.42:2888:3888
```

zoo.cfg配置文件详解

```bash
tickTime：基本事件单元，以毫秒为单位。这个时间是作为 Zookeeper 服务器之间或客户端与服务器之间维持心跳的时间间隔，
          也就是每隔 tickTime时间就会发送一个心跳（客户端与服务器之间通过tcp每隔几秒发送心跳，一旦心跳没有了就超时，断开客户端释放连接）。
			
dataDir：存储内存中数据库快照的位置，顾名思义就是 Zookeeper 保存数据的目录，默认情况下，Zookeeper 将写数据的日志文件也保存在这个目录里。

clientPort：这个端口就是客户端连接 Zookeeper 服务器的端口，Zookeeper 会监听这个端口，接受客户端的访问请求。

initLimit：这个配置项是用来配置 Zookeeper 接受客户端初始化连接时最长能忍受多少个心跳时间间隔数，
           当已经超过 10 个心跳的时间（也就是 tickTime）长度后 Zookeeper 服务器还没有收到客户端的返回信息，
           那么表明这个客户端连接失败。总的时间长度就是 10*2000=20 秒。

syncLimit：这个配置项标识 Leader 与 Follower 之间发送消息，请求和应答时间长度，
           最长不能超过多少个 tickTime 的时间长度，总的时间长度就是 5*2000=10 秒

server.A = B:C:D : 
	A表示这个是第几号服务器,
	B 是这个服务器的 ip 地址；
	C 表示的是这个服务器与集群中的 Leader 服务器交换信息的端口；
	D 表示的是万一集群中的 Leader 服务器挂了，需要一个端口来重新进行选举，选出一个新的 Leader
```


## 服务器标识配置

创建conf配置文件中指定的data文件夹

```bash
# cd /usr/local/zookeeper-3.4.6/
# mkdir data
# cd data
# vim myid
三台分别添加 0、1、2
（对应配置文件中的server.0、server.1、server.2）
```


## 启动验证

因为配置了zookeeper的环境变量，所以在任意目录下都可以启动zookeeper

```bash
[root@zoo1 /]# zkServer.sh start
[root@zoo2 /]# zkServer.sh start
[root@zoo3 /]# zkServer.sh start

[root@zoo1 /]# zkCli.sh
客户端连接（连一台就行）
Connecting to localhost:2181
2017-06-17 02:46:51,362 [myid:] - INFO  [main:Environment@100] - Client environment:zookeeper.version=3.4.6-1569965, built on 02/20/2014 09:09 GMT
2017-06-17 02:46:51,378 [myid:] - INFO  [main:Environment@100] - Client environment:host.name=zoo1
2017-06-17 02:46:51,380 [myid:] - INFO  [main:Environment@100] - Client environment:java.version=1.8.0_111
2017-06-17 02:46:51,408 [myid:] - INFO  [main:Environment@100] - Client environment:java.vendor=Oracle Corporation
2017-06-17 02:46:51,408 [myid:] - INFO  [main:Environment@100] - Client environment:java.home=/usr/local/jdk1.8/jre
2017-06-17 02:46:51,412 [myid:] - INFO  [main:Environment@100] - Client environment:java.class.path=/usr/local/zookeeper-3.4.6/bin/../build/classes:/usr/local/zookeeper-3.4.6/bin/../build/lib/*.jar:/usr/local/zookeeper-3.4.6/bin/../lib/slf4j-log4j12-1.6.1.jar:/usr/local/zookeeper-3.4.6/bin/../lib/slf4j-api-1.6.1.jar:/usr/local/zookeeper-3.4.6/bin/../lib/netty-3.7.0.Final.jar:/usr/local/zookeeper-3.4.6/bin/../lib/log4j-1.2.16.jar:/usr/local/zookeeper-3.4.6/bin/../lib/jline-0.9.94.jar:/usr/local/zookeeper-3.4.6/bin/../zookeeper-3.4.6.jar:/usr/local/zookeeper-3.4.6/bin/../src/java/lib/*.jar:/usr/local/zookeeper-3.4.6/bin/../conf:
2017-06-17 02:46:51,412 [myid:] - INFO  [main:Environment@100] - Client environment:java.library.path=/usr/java/packages/lib/amd64:/usr/lib64:/lib64:/lib:/usr/lib
2017-06-17 02:46:51,414 [myid:] - INFO  [main:Environment@100] - Client environment:java.io.tmpdir=/tmp
2017-06-17 02:46:51,415 [myid:] - INFO  [main:Environment@100] - Client environment:java.compiler=<NA>
2017-06-17 02:46:51,415 [myid:] - INFO  [main:Environment@100] - Client environment:os.name=Linux
2017-06-17 02:46:51,416 [myid:] - INFO  [main:Environment@100] - Client environment:os.arch=amd64
2017-06-17 02:46:51,446 [myid:] - INFO  [main:Environment@100] - Client environment:os.version=3.10.0-327.el7.x86_64
2017-06-17 02:46:51,446 [myid:] - INFO  [main:Environment@100] - Client environment:user.name=root
2017-06-17 02:46:51,447 [myid:] - INFO  [main:Environment@100] - Client environment:user.home=/root
2017-06-17 02:46:51,447 [myid:] - INFO  [main:Environment@100] - Client environment:user.dir=/
2017-06-17 02:46:51,456 [myid:] - INFO  [main:ZooKeeper@438] - Initiating client connection, connectString=localhost:2181 sessionTimeout=30000 watcher=org.apache.zookeeper.ZooKeeperMain$MyWatcher@531d72ca
Welcome to ZooKeeper!
JLine support is enabled
[zk: localhost:2181(CONNECTING) 0] 2017-06-17 02:47:01,673 [myid:] - INFO  [main-SendThread(127.0.0.1:2181):ClientCnxn$SendThread@975] - Opening socket connection to server 127.0.0.1/127.0.0.1:2181. Will not attempt to authenticate using SASL (unknown error)
2017-06-17 02:47:01,699 [myid:] - INFO  [main-SendThread(127.0.0.1:2181):ClientCnxn$SendThread@852] - Socket connection established to 127.0.0.1/127.0.0.1:2181, initiating session
2017-06-17 02:47:01,775 [myid:] - INFO  [main-SendThread(127.0.0.1:2181):ClientCnxn$SendThread@1235] - Session establishment complete on server 127.0.0.1/127.0.0.1:2181, sessionid = 0x5de20d291a0000, negotiated timeout = 30000

WATCHER::

WatchedEvent state:SyncConnected type:None path:null

[zk: localhost:2181(CONNECTED) 0] quit
Quitting...
2017-06-17 02:48:30,851 [myid:] - INFO  [main:ZooKeeper@684] - Session: 0x5de20d291a0000 closed
2017-06-17 02:48:30,853 [myid:] - INFO  [main-EventThread:ClientCnxn$EventThread@512] - EventThread shut down
```

验证jps

```bash
[root@zoo1 /]# jps
3236 Jps
2994 QuorumPeerMain
2516 ZooKeeperMain

[root@zoo2 /]# jps
3266 Jps
3215 QuorumPeerMain

[root@zoo3 /]# jps
2432 Jps
2281 QuorumPeerMain
```

查看status

```bash
[root@zoo1 /]# zkServer.sh status
Mode: follower

[root@zoo2 /]# zkServer.sh status
Mode: leader
（主节点master）

[root@zoo3 /]# zkServer.sh status
Mode: follower
```

netstat -ntpl

```bash
[root@zoo1 /]# netstat -ntpl
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name
tcp6       0      0 :::46257                :::*                    LISTEN      2994/java                      
tcp6       0      0 :::2181                 :::*                    LISTEN      2994/java                
tcp6       0      0 192.168.154.40:3888     :::*                    LISTEN      2994/java           

[root@zoo2 /]# netstat -ntpl
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name  
tcp6       0      0 :::47386                :::*                    LISTEN      3215/java           
tcp6       0      0 :::2181                 :::*                    LISTEN      3215/java         
tcp6       0      0 192.168.154.41:2888     :::*                    LISTEN      3215/java           
tcp6       0      0 192.168.154.41:3888     :::*                    LISTEN      3215/java                    

[root@zoo3 /]# netstat -ntpl
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name              
tcp6       0      0 :::57449                :::*                    LISTEN      2281/java 
tcp6       0      0 :::2181                 :::*                    LISTEN      2281/java          
tcp6       0      0 192.168.154.42:3888     :::*                    LISTEN      2281/java                     
```


关闭

```bash
[root@zoo1 /]# zkServer.sh stop
[root@zoo2 /]# zkServer.sh stop
[root@zoo3 /]# zkServer.sh stop
```

## 工具使用

通过控制台界面操作树形数据 [<font face="Times New Roman" color=#0099ff size=5>zookeeper-dev-ZooInspector</font>](http://download.csdn.net/download/weixin_37479489/9934124)

```bash
进入jar包存储路径
shift + 右键 + w
java -jar zookeeper-dev-ZooInspector.jar &
Connect String：192.168.154.40:2181
```

![png1](/img/zookeeper/20170414_1.png)