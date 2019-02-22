# 架构

|IP|HOSTNAME|NN1|NN2|DN|ZK|ZKFC|JN|RM|NM|
|---|---|---|---|---|---|---|---|---|---|
|172.16.114.130|Master|*||||*|*|||
|172.16.114.131|Slave1||*|||*|*|||
|172.16.114.132|Slave2|||*|*||*||*|
|172.16.114.133|Slave3|||*|*|||*|*|
|172.16.114.134|Slave4|||*|*|||*|*|

注：RM不应该跟NN在一台服务器上，两个进程都是相当耗费资源的；NM和DN最好装在同一服务器上，如果不在一起，计算时拉取数据是相当笨重的过程，就算不在一台服务器上，也应该在同一机架上。

# Yarn

## slaves

```bash
###NM与DN保持一致，无需变动
[root@Master hadoop]# cat slaves
Slave2
Slave3
Slave4
```

## yarn-env.sh

```bash
export JAVA_HOME=${JAVA_HOME}
改成
export JAVA_HOME=/usr/java/jdk1.8.0_181
```

## mapred-site.xml

```bash
[root@Master hadoop]# cp mapred-site.xml.template mapred-site.xml
[root@Master hadoop]# vim mapred-site.xml
```

```bash
<property>
    <name>mapreduce.framework.name</name>
    <value>yarn</value>
</property>
```

## yarn-site.xml

```bash
<property>
    <name>yarn.nodemanager.aux-services</name>
    <value>mapreduce_shuffle</value>
</property>
<property>
   <name>yarn.resourcemanager.ha.enabled</name>
   <value>true</value>
 </property>
 <property>
   <name>yarn.resourcemanager.cluster-id</name>
   <value>cluster1</value>
 </property>
 <property>
   <name>yarn.resourcemanager.ha.rm-ids</name>
   <value>rm1,rm2</value>
 </property>
 <property>
   <name>yarn.resourcemanager.hostname.rm1</name>
   <value>Slave3</value>
 </property>
 <property>
   <name>yarn.resourcemanager.hostname.rm2</name>
   <value>Slave4</value>
 </property>
 <property>
   <name>yarn.resourcemanager.zk-address</name>
   <value>Slave2:2181,Slave3:2181,Slave4:2181</value>
 </property>
```

## 分发其他节点

```bash
[root@Master hadoop]# scp yarn-env.sh mapred-site.xml yarn-site.xml Slave1:`pwd`
[root@Master hadoop]# scp yarn-env.sh mapred-site.xml yarn-site.xml Slave2:`pwd`
[root@Master hadoop]# scp yarn-env.sh mapred-site.xml yarn-site.xml Slave3:`pwd`
[root@Master hadoop]# scp yarn-env.sh mapred-site.xml yarn-site.xml Slave4:`pwd`
```

# 启动

```bash
[root@Slave2 ~]# zkServer.sh start
[root@Slave3 ~]# zkServer.sh start
[root@Slave4 ~]# zkServer.sh start

[root@Master ~]# start-dfs.sh
Starting namenodes on [Master Slave1]
Slave1: starting namenode, logging to /opt/stefan/hadoop-2.6.5/logs/hadoop-root-namenode-Slave1.out
Master: starting namenode, logging to /opt/stefan/hadoop-2.6.5/logs/hadoop-root-namenode-Master.out
Slave3: starting datanode, logging to /opt/stefan/hadoop-2.6.5/logs/hadoop-root-datanode-Slave3.out
Slave4: starting datanode, logging to /opt/stefan/hadoop-2.6.5/logs/hadoop-root-datanode-Slave4.out
Slave2: starting datanode, logging to /opt/stefan/hadoop-2.6.5/logs/hadoop-root-datanode-Slave2.out
Starting journal nodes [Master Slave1 Slave2]
Slave1: starting journalnode, logging to /opt/stefan/hadoop-2.6.5/logs/hadoop-root-journalnode-Slave1.out
Master: starting journalnode, logging to /opt/stefan/hadoop-2.6.5/logs/hadoop-root-journalnode-Master.out
Slave2: starting journalnode, logging to /opt/stefan/hadoop-2.6.5/logs/hadoop-root-journalnode-Slave2.out
Starting ZK Failover Controllers on NN hosts [Master Slave1]
Master: starting zkfc, logging to /opt/stefan/hadoop-2.6.5/logs/hadoop-root-zkfc-Master.out
Slave1: starting zkfc, logging to /opt/stefan/hadoop-2.6.5/logs/hadoop-root-zkfc-Slave1.out
```

```bash
[root@Master ~]# start-yarn.sh
starting yarn daemons
starting resourcemanager, logging to /opt/stefan/hadoop-2.6.5/logs/yarn-root-resourcemanager-Master.out
Slave3: starting nodemanager, logging to /opt/stefan/hadoop-2.6.5/logs/yarn-root-nodemanager-Slave3.out
Slave2: starting nodemanager, logging to /opt/stefan/hadoop-2.6.5/logs/yarn-root-nodemanager-Slave2.out
Slave4: starting nodemanager, logging to /opt/stefan/hadoop-2.6.5/logs/yarn-root-nodemanager-Slave4.out
###发现并没有在Master或Slave3、Slave4节点上启动RM，而且我们规定是在Slave3、Slave4上启动RM
###start-yarn.sh这个脚本有问题，只能启动NM，RM需要手动在Slave3、Slave4上启动

[root@Slave3 ~]# yarn-daemon.sh start resourcemanager
starting resourcemanager, logging to /opt/stefan/hadoop-2.6.5/logs/yarn-root-resourcemanager-Slave3.out
[root@Slave3 ~]# jps
1796 DataNode
1944 NodeManager
2297 Jps
1690 QuorumPeerMain
2074 ResourceManager

[root@Slave4 ~]# yarn-daemon.sh start resourcemanager
starting resourcemanager, logging to /opt/stefan/hadoop-2.6.5/logs/yarn-root-resourcemanager-Slave4.out
[root@Slave4 ~]# jps
2000 ResourceManager
1762 DataNode
2038 Jps
1870 NodeManager
1663 QuorumPeerMain
```

```bash
[zk: localhost:2181(CONNECTED) 0] ls /
[zookeeper, yarn-leader-election, hadoop-ha]
[zk: localhost:2181(CONNECTED) 1] get /yarn-leader-election/cluster1/ActiveStandbyElectorLock

cluster1rm1
cZxid = 0x20000000b
ctime = Mon Nov 19 22:14:00 CST 2018
mZxid = 0x20000000b
mtime = Mon Nov 19 22:14:00 CST 2018
pZxid = 0x20000000b
cversion = 0
dataVersion = 0
aclVersion = 0
ephemeralOwner = 0x2672c47319c0002
dataLength = 15
numChildren = 0
```

```bash
> http://Slave3:8088/cluster/cluster
ResourceManager HA state:	active

> http://Slave4:8088/cluster/cluster
ResourceManager HA state:	standby
```

# 关闭

```bash
[root@Master ~]# stop-yarn.sh
stopping yarn daemons
no resourcemanager to stop
Slave3: stopping nodemanager
Slave2: stopping nodemanager
Slave4: stopping nodemanager
no proxyserver to stop

[root@Slave3 ~]# yarn-daemon.sh stop resourcemanager
stopping resourcemanager
[root@Slave4 ~]# yarn-daemon.sh stop resourcemanager
stopping resourcemanager

```

