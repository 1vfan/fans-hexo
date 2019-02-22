---
title: Hadoop集群之HA环境搭建
date: 2017-07-26 20:43:01
tags:
- Hadoop
- HDFS
- Zookeeper
- Linux
- Cluster
categories: 
- Hadoop栈
---

记录HDFS+Zookeeper搭建一套高可用的Hadoop运行环境

<!--more-->

## 前期准备

网络配置（互相能ping通）、JDK环境配置、免密钥配置、防火墙、hosts等.

注意：两台主备的NameNode之间需要互相免密钥，否则无法进行active和standby的正常切换.

1. node1

```bash
[root@node1 .ssh]# ssh-keygen -t rsa

[root@node1 .ssh]# ssh-copy-id node1
[root@node1 .ssh]# ssh-copy-id node2
[root@node1 .ssh]# ssh-copy-id node3
[root@node1 .ssh]# ssh-copy-id node4
```

2. node2

```bash
[root@node2 .ssh]# ssh-keygen -t rsa

[root@node2 .ssh]# ssh-copy-id node1
[root@node2 .ssh]# ssh-copy-id node2
```

## 节点规划

|IP|Hostname|NN1|NN2|DN|ZK|ZKFC|JNN|
|---|---|---|---|---|---|---|---|
|158.222.154.65|node1| * |   |   |   | * | * |
|158.222.154.66|node2|   | * | * | * | * | * |
|158.222.154.67|node3|   |   | * | * |   | * |
|158.222.154.68|node4|   |   | * | * |   |   |


## 上传解压

1. 解压

```bash
# tar -zxvf hadoop-2.6.5.tar.gz
# mv hadoop-2.6.5 hadoop
# mkdir -p /opt/stefan/
# mv hadoop /opt/stefan/

# tar -zxvf zookeeper-3.4.6.tar.gz
# mv zookeeper-3.4.6 zookeeper
# mv zookeeper /opt/stefan/
```

2. 配置PATH

```bash
# vim /etc/profile
JAVA_HOME=/usr/local/jdk1.8/
JRE_HOME=${JAVA_HOME}/jre       
HADOOP_HOME=/opt/stefan/hadoop/
ZOOKEEPER_HOME=/opt/stefan/zookeeper/ 
export CLASSPATH=.:${JAVA_HOME}/lib:${JRE_HOME}/lib
export PATH=${JAVA_HOME}/bin:${JRE_HOME}/bin:${HADOOP_HOME}/bin:${HADOOP_HOME}/sbin:${ZOOKEEPER_HOME}/bin:$PATH

# source /etc/profile
```

## hadoop

1. hdfs-site.xml

```bash
# cd /opt/stefan/hadoop/etc/hadoop
# vim hdfs-site.xml
```

添加以下配置

```bash
<!--自定义NameServices逻辑名称：mycluster -->
<property>
  <name>dfs.nameservices</name>
  <value>mycluster</value>
</property>
<!--映射nameservices逻辑名称到namenode逻辑名称 -->
<property>
  <name>dfs.ha.namenodes.mycluster</name>
  <value>nn1,nn2</value>
</property>
<!--映射namenode逻辑名称到真实主机名称（RPC） -->
<property>
  <name>dfs.namenode.rpc-address.mycluster.nn1</name>
  <value>node1:8020</value>
</property>
<!--映射namenode逻辑名称到真实主机名称（RPC） -->
<property>
  <name>dfs.namenode.rpc-address.mycluster.nn2</name>
  <value>node2:8020</value>
</property>
<!--映射namenode逻辑名称到真实主机名称（HTTP） -->
<property>
  <name>dfs.namenode.http-address.mycluster.nn1</name>
  <value>node1:50070</value>
</property>
<!--映射namenode逻辑名称到真实主机名称（HTTP） -->
<property>
  <name>dfs.namenode.http-address.mycluster.nn2</name>
  <value>node2:50070</value>
</property>

<!--配置JN集群位置信息及目录 -->
<property>
  <name>dfs.namenode.shared.edits.dir</name>
<value>qjournal://node1:8485;node2:8485;node3:8485/mycluster</value>
</property>
<!--配置journalnode edits文件位置 -->
<property>
  <name>dfs.journalnode.edits.dir</name>
  <value>/var/stefan/hadoop/jn</value>
</property>

<!--配置故障迁移实现类 -->
<property>
  <name>dfs.client.failover.proxy.provider.mycluster</name>
<value>org.apache.hadoop.hdfs.server.namenode.ha.ConfiguredFailoverProxyProvider</value>
</property>
<!--指定故障时主备切换方式为SSH免密钥方式 -->
<property>
  <name>dfs.ha.fencing.methods</name>
  <value>sshfence</value>
</property>
<!--使用rsa算法生成的密钥就要用id_rsa -->
<property>
  <name>dfs.ha.fencing.ssh.private-key-files</name>
  <value>/root/.ssh/id_rsa</value>
</property>
<!--设置自动切换 -->
<property>
   <name>dfs.ha.automatic-failover.enabled</name>
   <value>true</value>
 </property>

<property>
   <name>dfs.webhdfs.enabled</name>
   <value>true</value>
</property>
<!--用户组和权限，staff是默认 -->
<property>
   <name>dfs.permissions.superusergroup</name>
   <value>staff</value>
</property>
<!--是否要开启权限 -->
<property>
   <name>dfs.permissions.enabled</name>
   <value>false</value>
</property>
```

2. core-site.xml

```bash
# cd /opt/stefan/hadoop/etc/hadoop
# vim core-site.xml
```

添加以下配置

```bash
<!--设置fs.defaultFS为Nameservices的逻辑主机名 -->
<property>
    <name>fs.defaultFS</name>
    <value>hdfs://mycluster</value>
</property>
<!--设置数据存放目录，不能放在tmp目录下 -->
<property>
    <name>hadoop.tmp.dir</name>
    <value>/var/stefan/hadoop/ha</value>
</property>
<!--设置zookeeper位置信息 -->
<property>
    <name>ha.zookeeper.quorum</name>
    <value>node2:2181,node3:2181,node4:2181</value>
</property>
```

3. slaves

规定启动DataNode进程的节点，在start-dfs.sh 、stop-dfs.sh时一起启动或关闭.

```bash
# cd /opt/stefan/hadoop/etc/hadoop
# vim slaves

node2
node3
node4
```

4. hadoop-env.sh

```bash
# cd /opt/stefan/hadoop/etc/hadoop
# vim hadoop-env.sh

export JAVA_HOME=${JAVA_HOME}
改成
export JAVA_HOME=/usr/local/jdk1.8/
```

防止出现如下错误

```bash
Starting namenodes on [node1 node2]
node2: Error: JAVA_HOME is not set and could not be found.
node1: Error: JAVA_HOME is not set and could not be found.
```

## zookeeper

1. node2、node3、node4上配置

```bash
# cd /opt/stefan/zookeeper/conf
# cp zoo_sample.cfg zoo.cfg
# vi zoo.cfg
dataDir=/var/stefan/zk/
server.1=192.168.154.66:2888:3888
server.2=192.168.154.67:2888:3888
server.3=192.168.154.68:2888:3888
# cd /var/stefan/
# mkdir zk
# cd zk
[root@node2 zk]# echo 1 > myid
[root@node3 zk]# echo 2 > myid
[root@node4 zk]# echo 3 > myid

# zkServer.sh start
# zkServer.sh status
# zkCli.sh
> ls /
[zookeeper]
```

注意：格式化之前zookeeper集群处于开启状态.

## 格式化同步HDFS

1. node 1、2、3

```bash
# hadoop-daemon.sh start journalnode
```

2. node 1、2、3、4

```bash
# jps
```

3. node 1

```bash
# hdfs namenode -format
# hadoop-daemon.sh start namenode
```

4. node 2

```bash
# hdfs namenode -bootstrapStandby
```

5. node 1

```bash
# hdfs zkfc -formatZK
```

6. node 4

成功后根目录会新增一个hadoop-ha目录

```bash
# zkCli.sh
# ls /
[zookeeper, hadoop-ha]
```

7. node 1

```bash
# start-dfs.sh
Starting namenodes on [node1 node2]
node1: namenode running as process 6918. Stop it first.
node2: starting namenode, logging to /opt/stefan/hadoop/logs/hadoop-root-namenode-node2.out
node3: starting datanode, logging to /opt/stefan/hadoop/logs/hadoop-root-datanode-node3.out
node2: starting datanode, logging to /opt/stefan/hadoop/logs/hadoop-root-datanode-node2.out
node4: starting datanode, logging to /opt/stefan/hadoop/logs/hadoop-root-datanode-node4.out
Starting journal nodes [node1 node2 node3]
node1: starting journalnode, logging to /opt/stefan/hadoop/logs/hadoop-root-journalnode-node1.out
node3: starting journalnode, logging to /opt/stefan/hadoop/logs/hadoop-root-journalnode-node3.out
node2: starting journalnode, logging to /opt/stefan/hadoop/logs/hadoop-root-journalnode-node2.out
Starting ZK Failover Controllers on NN hosts [node1 node2]
node2: starting zkfc, logging to /opt/stefan/hadoop/logs/hadoop-root-zkfc-node2.out
node1: starting zkfc, logging to /opt/stefan/hadoop/logs/hadoop-root-zkfc-node1.out
```

8. node 1、2

浏览器中查看node1和node2的状态（active/standby），当前node1为active，node2为standby.

```bash
http://192.168.154.65:50070
Overview 'node1:8020' (active)

http://192.168.154.66:50070
Overview 'node2:8020' (standby)
```

9. node 1

使用kill -9 namenode进程号或关闭namenode的方式模拟宕机，查看主备是否切换

```bash
[root@node1 /]# hadoop-daemon.sh stop namenode
```

浏览器中node1已经无法访问，但node2依然处于standby状态，没有切换成active.


## 主备无法切换解决方案

查看日志发现切换时出现如下错误：

```bash
bash：fuser: 未找到命令
ERROR: Fencing method org.apache.hadoop.ha.SshFenceByTcpPort(null) was unsuccessful
Unable to fence service by any configured method
```

与hdfs-site.xml中的配置有关，sshfence方法是指通过ssh登陆到active namenode节点kill namenode进程，所以需要设置ssh无密码登陆，同时保证有kill namenode进程的权限.

```bash
<property>
     <name>dfs.ha.fencing.methods</name>
     <value>sshfence</value>
</property>
```

解决方案：在主备节点node1、node2上执行以下命令

```bash
[root@node1 /]# yum provides "*/fuser"
[root@node1 /]# yum -y install psmisc

[root@node2 /]# yum provides "*/fuser"
[root@node2 /]# yum -y install psmisc
```

## 测试主备切换

kill处于active的节点namenode（或zkfc）进程，或者通过命令hadoop-daemon.sh stop停止namenode（或zkfc），在浏览器中查看standby状态的节点是否会切换到active状态.

1. 一切正常状态

```bash
[root@node1 ~]# jps
8157 Jps
7517 NameNode
7241 JournalNode
7844 DFSZKFailoverController

[root@node2 ~]# jps
6956 Jps
5809 NameNode
5444 DataNode
5566 JournalNode
2376 QuorumPeerMain
6473 DFSZKFailoverController

[root@node3 ~]# jps
4656 Jps
4338 DataNode
4437 JournalNode
3071 QuorumPeerMain

[root@node4 ~]# jps
4166 Jps
3900 DataNode
3091 QuorumPeerMain
```

```bash
http://192.168.154.65:50070
Overview 'node1:8020' (active)

http://192.168.154.66:50070
Overview 'node2:8020' (standby)
```

2. 关闭node1 namenode进程

```bash
[root@node1 /]# hadoop-daemon.sh stop namenode


http://192.168.154.65:50070
无法访问

http://192.168.154.66:50070
Overview 'node2:8020' (active)
```

3. 恢复node1 namenode进程

```bash
[root@node1 /]# hadoop-daemon.sh start namenode


http://192.168.154.65:50070
Overview 'node1:8020' (standby)

http://192.168.154.66:50070
Overview 'node2:8020' (active)
```

4. 关闭node2 zkfc进程

```bash
[root@node2 /]# hadoop-daemon.sh stop zkfc


http://192.168.154.65:50070
Overview 'node1:8020' (active)

http://192.168.154.66:50070
无法访问
```

5. 恢复node2 zkfc进程

```bash
[root@node2 /]# hadoop-daemon.sh start zkfc


http://192.168.154.65:50070
Overview 'node1:8020' (active)

http://192.168.154.66:50070
Overview 'node2:8020' (standby)
```

测试成功，hadoop HA环境已经可以切换自如.