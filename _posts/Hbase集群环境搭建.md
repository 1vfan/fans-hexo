---
title: Hbase集群环境搭建
date: 2017-07-23 21:43:01
tags:
- Hbase
- HDFS
- zookeeper
categories: 
- Hadoop栈
---

记录HDFS+Hbase+Zookeeper整合搭建Hbase集群运行环境

<!--more-->

## 前期准备

网络配置（互相能ping通）、JDK环境配置、免密钥配置

```bash
[root@hbase1 ~]# cd .ssh
[root@hbase1 .ssh]# ssh-keygen -t rsa (四个回车)
Generating public/private rsa key pair.
Enter file in which to save the key (/root/.ssh/id_rsa): 
Enter passphrase (empty for no passphrase): 
Enter same passphrase again: 
Your identification has been saved in /root/.ssh/id_rsa.
Your public key has been saved in /root/.ssh/id_rsa.pub.
The key fingerprint is:
6c:57:85:f4:75:bf:da:11:4f:bf:e4:16:94:2e:f5:40 root@hbase1
The key's randomart image is:
+--[ RSA 2048]----+
|           ...E o|
|            .+ .+|
|            . o=o|
|       .   .  +o*|
|        S .  . *+|
|       . .    * +|
|             . = |
|              .  |
|                 |
+-----------------+
[root@hbase1 .ssh]# ls
id_rsa  id_rsa.pub  known_hosts
[root@hbase1 .ssh]# ssh-copy-id hbase2

将rsa算法生成的公钥id_rsa.pub拷贝到其他服务器上
# ssh-copy-id hbase1
# ssh-copy-id hbase2
# ssh-copy-id hbase3
```

## zookeeper解压配置

配置zookeeper环境变量

```bash
JAVA_HOME=/usr/local/jdk1.8
JRE_HOME=$JAVA_HOME/jre
ZOOKEEPER_HOME=/usr/local/zookeeper
CLASS_PATH=.:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar:$JRE_HOME/lib
PATH=$PATH:$ZOOKEEPER_HOME/bin:$JAVA_HOME/bin:$JRE_HOME/bin
export ZOOKEEPER_HOME JAVA_HOME JRE_HOME CLASS_PATH PATH

# source /etc/profile
```

修改zookeeper配置文件

```bash
# mv zoo_sample.cfg zoo.cfg
# vim zoo.cfg
按照下面配置操作

# grep '^[a-z]' zoo.cfg 
tickTime=2000
initLimit=10
syncLimit=5
dataDir=/usr/local/zookeeper/data
clientPort=2181
server.0=192.168.154.60:2888:3888
server.1=192.168.154.61:2888:3888
server.2=192.168.154.62:2888:3888
```

创建conf配置文件中指定的data文件

```bash
# cd /usr/local/zookeeper/
# mkdir data
# cd data
# vim myid
三台分别添加 0、1、2
（对应配置文件中的server.0、server.1、server.2）
```

## hadoop解压配置

配置hadoop环境变量

```bash
# cd /usr/local/hadoop/etc/hadoop/
（将配置文件放置在/etc/hadoop中的目的是以便多版本保存在ect目录下可以自由切换）

hadoop-env.sh中添加Java环境变量
# vim hadoop-env.sh
export JAVA_HOME=/usr/local/jdk1.8

etc/profile中path添加hadoop环境变量
# vim /etc/profile

JAVA_HOME=/usr/local/jdk1.8
JRE_HOME=$JAVA_HOME/jre
ZOOKEEPER_HOME=/usr/local/zookeeper
HADOOP_HOME=/usr/local/hadoop
CLASS_PATH=.:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar:$JRE_HOME/lib
PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$ZOOKEEPER_HOME/bin:$JAVA_HOME/bin:$JRE_HOME/bin
export ZOOKEEPER_HOME JAVA_HOME JRE_HOME CLASS_PATH PATH

# source /etc/profile
```

所有服务器修改core-site.xml（无论namenode或datanode：必须都指定namenode-->hdfs://hbase1:9000，否则格式化后无法启动其他datanode）；指定hadoop.tmp.dir是为了保证所有的数据保存在/var/hadoop下

```bash
# vim /usr/local/hadoop/etc/hadoop/core-site.xml

新增属性
<configuration>
  <property>
    <name>fs.defaultFS</name>
    <value>hdfs://hbase1:9000</value>
  </property>
  <property>
    <name>hadoop.tmp.dir</name>
    <value>/var/hadoop</value>
  </property>
</configuration>
```

修改/usr/local/hadoop/etc/hadoop/slaves（注意：配置主机名就等于在该主机上启用datanode，hbase1在作为namenode的同时也可作为datanode，但是一般namenode会单独在一台服务器上）
```bash
hbase1
hbase2
hbase3
```

格式化后查看指定数据保存路径

```bash
# hadoop namenode -format

[root@hbase1 dfs]# cd /var/hadoop/dfs
[root@hbase1 dfs]# ls
data  name  namesecondary
data保存着作为datanode的数据信息，name保存着作为namenode的数据信息

[root@hbase2 dfs]# cd /var/hadoop/dfs
[root@hbase2 dfs]# ls
data

[root@hbase3 dfs]# cd /var/hadoop/dfs
[root@hbase3 dfs]# ls
data
```

必须保证dfs/name/current/Version和dfs/data/current/Version中的clusterID相同，否则无法正常启动所有的datanode

* 154.60 name
```bash
[root@hbase1 current]# vim VERSION 
#Sun Sep 17 14:26:55 CST 2017
namespaceID=1492230118
clusterID=CID-93fc1122-41bc-4889-8f1f-144937002e81
cTime=0
storageType=NAME_NODE
blockpoolID=BP-1567179858-192.168.154.60-1505629615292
layoutVersion=-63
```

* 154.60 data
```bash
[root@hbase1 current]# vim VERSION 
#Sun Sep 17 14:29:36 CST 2017
storageID=DS-f5dbfa69-c967-45ac-a106-595192629da6
clusterID=CID-93fc1122-41bc-4889-8f1f-144937002e81
cTime=0
datanodeUuid=5c335e18-4ccc-4960-95d2-c16b70375930
storageType=DATA_NODE
layoutVersion=-56
```

* 154.61 data
```bash
[root@hbase2 current]# vim VERSION 
#Sun Sep 17 14:29:40 CST 2017
storageID=DS-6f5482b1-a7f5-456c-9035-835b2675dcf2
clusterID=CID-93fc1122-41bc-4889-8f1f-144937002e81
cTime=0
datanodeUuid=0a434f7e-1a4f-42ce-9b8e-fa019e65c5fa
storageType=DATA_NODE
layoutVersion=-56
```

* 154.62 data
```bash
[root@hbase3 current]# vim VERSION 
#Sun Sep 17 14:29:41 CST 2017
storageID=DS-79eedeeb-66ef-44f3-a94a-d39cea32e965
clusterID=CID-93fc1122-41bc-4889-8f1f-144937002e81
cTime=0
datanodeUuid=596995f4-d903-47ba-88b1-b6f5c23ab863
storageType=DATA_NODE
layoutVersion=-56
```

## Hbase解压配置

Hbase[<font face="Times New Roman" color=#0099ff size=3>官网</font>](http://hbase.apache.org/)学习地址；[<font face="Times New Roman" color=#0099ff size=3>稳定版</font>](http://mirror.bit.edu.cn/apache/hbase/stable/)安装包下载地址.

配置Hbase环境变量

```bash
JAVA_HOME=/usr/local/jdk1.8
JRE_HOME=$JAVA_HOME/jre
ZOOKEEPER_HOME=/usr/local/zookeeper
HADOOP_HOME=/usr/local/hadoop
HBASE_HOME=/usr/local/hbase
CLASS_PATH=.:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar:$JRE_HOME/lib
PATH=$PATH:$HBASE_HOME/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$ZOOKEEPER_HOME/bin:$JAVA_HOME/bin:$JRE_HOME/bin
export HBASE_HOME HADOOP_HOME ZOOKEEPER_HOME JAVA_HOME JRE_HOME CLASS_PATH PATH

# source /etc/profile
```

配置hbase-env.sh

```bash
# java的jdk路径
export JAVA_HOME=/usr/local/jdk1.8/

# 缺少会使其他使用到hbase的大数据框架报错
export HBASE_CLASSPATH=.:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar

# hbase默认使用内置的单机版zookeeper，设置为false然后添加zookeeper集群
export HBASE_MANAGES_ZK=false
```

配置hbase-site.xml

```bash
# 指定HMaster的位置
<property>
  <name>hbase.master</name>
  <value>hbase1:6000</value>
</property>
# 两台服务器间发送心跳可接受的时间差
<property>
  <name>hbase.master.maxclockskew</name>
  <value>180000</value>
</property>
# 将hbase数据存在hdfs的/hbase目录下（若配置了HA，需要将hdfs-site.xml拷贝到Hbase里）
<property>
  <name>hbase.rootdir</name>
  <value>hdfs://hbase1:9000/hbase</value>
</property>

# 保存zookeeper数据目录（自动创建）
<property>
  <name>hbase.zookeeper.property.dataDir</name>
  <value>/var/data/hbase/zookeeper</value>
</property>
# 配置zookeeper集群节点
<property>
  <name>hbase.zookeeper.quorum</name>
  <value>hbase1,hbase2,hbase3</value>
</property>
# 是否集群模式
<property>
  <name>hbase.cluster.distributed</name>
  <value>true</value>
</property>
```

配置regionservers（hbase1服务器上既可以跑HMaster，也可以跑HRegionserver）

```bash
# vim regionservers
添加
hbase1
hbase2
hbase3
```

## 启动

注意：首先启动hdfs和zookeeper之后才能启动hbase

```bash
hbase1：start-dfs.sh
hbase1：zkServer.sh start
hbase2：zkServer.sh start
hbase3：zkServer.sh start
```

单节点启动hbase

```bash
# cd /usr/local/hbase/bin
//启动主节点
# ./hbase-daemon.sh start master
//启动从节点
# ./hbase-daemon.sh start regionserver
# jps
```

HMaster节点hbase1上批量启动停止hbase

```bash
# cd /usr/local/hbase/bin
# ./start-hbase.sh 
starting master, logging to /usr/local/hbase/logs/hbase-root-master-hbase1.out
Java HotSpot(TM) 64-Bit Server VM warning: ignoring option PermSize=128m; support was removed in 8.0
Java HotSpot(TM) 64-Bit Server VM warning: ignoring option MaxPermSize=128m; support was removed in 8.0
hbase3: starting regionserver, logging to /usr/local/hbase/bin/../logs/hbase-root-regionserver-hbase3.out
hbase2: starting regionserver, logging to /usr/local/hbase/bin/../logs/hbase-root-regionserver-hbase2.out
hbase1: starting regionserver, logging to /usr/local/hbase/bin/../logs/hbase-root-regionserver-hbase1.out
hbase3: Java HotSpot(TM) 64-Bit Server VM warning: ignoring option PermSize=128m; support was removed in 8.0
hbase3: Java HotSpot(TM) 64-Bit Server VM warning: ignoring option MaxPermSize=128m; support was removed in 8.0
hbase2: Java HotSpot(TM) 64-Bit Server VM warning: ignoring option PermSize=128m; support was removed in 8.0
hbase2: Java HotSpot(TM) 64-Bit Server VM warning: ignoring option MaxPermSize=128m; support was removed in 8.0
hbase1: Java HotSpot(TM) 64-Bit Server VM warning: ignoring option PermSize=128m; support was removed in 8.0
hbase1: Java HotSpot(TM) 64-Bit Server VM warning: ignoring option MaxPermSize=128m; support was removed in 8.0
# jps
2640 SecondaryNameNode
2932 HMaster
2457 DataNode
3065 HRegionServer
2171 QuorumPeerMain
2348 NameNode
3116 Jps

批量停止Hbase集群
# ./stop-hbase.sh

hbase2、hbase3上查看
# jps
2453 HRegionServer
2486 Jps
2247 QuorumPeerMain
2328 DataNode
```

浏览器查看：http://192.168.154.60:16010
