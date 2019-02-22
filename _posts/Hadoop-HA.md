# 架构

|IP|HOSTNAME|NN1|NN2|DN|ZK|ZKFC|JN|
|--|--|--|--|--|--|--|--|
|172.16.114.130|Master|*||||*|*|
|172.16.114.131|Slave1||*|||*|*|
|172.16.114.132|Slave2|||*|*||*|
|172.16.114.133|Slave3|||*|*|||
|172.16.114.134|Slave4|||*|*|||

# 基础 

## firewall

```bash
[root@Master ~]# firewall-cmd --state
running
[root@Master ~]# systemctl stop firewalld.service
[root@Master ~]# firewall-cmd --state
not running
[root@Master ~]# systemctl disable firewalld.service
Removed symlink /etc/systemd/system/multi-user.target.wants/firewalld.service.
Removed symlink /etc/systemd/system/dbus-org.fedoraproject.FirewallD1.service.
```

## hosts

```bash
[root@Master ~]# cat /etc/hosts
127.0.0.1   localhost Master localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
172.16.114.130	Master
172.16.114.131	Slave1
172.16.114.132	Slave2
172.16.114.133	Slave3
172.16.114.134	Slave4
```

## ssh

使用以下方式：Active NN对所有免密包括自己、Standby NN对所有免密包括自己.

```bash
### dsa or rsa
[root@Master .ssh]# ssh-keygen -t dsa -P `` -f ./id_dsa
### 只适用于第一次添加pub，否则之前的其他pub会被覆盖
[root@Master .ssh]# ssh-copy-id Master
###分发pub到Slave1上当前路径
[root@Master .ssh]# scp ./id_dsa.pub root@Slave1:`pwd`/Master.pub
```

```bash
[root@Slave1 .ssh]# ls
known_hosts  Master.pub
[root@Slave1 .ssh]# cat Master.pub >> authorized.keys
```

## tar.gz

```bash
stefan-mac:Downloads stefan$ scp ./zookeeper-3.4.6.tar root@172.16.114.132:/usr/local/software/

[root@Slave2 software]# ls
hadoop-2.6.5.tar.gz  jdk-8u181-linux-x64.tar.gz  zookeeper-3.4.6.tar
[root@Slave2 software]# gzip zookeeper-3.4.6.tar
[root@Slave2 software]# ls
hadoop-2.6.5.tar.gz  jdk-8u181-linux-x64.tar.gz  zookeeper-3.4.6.tar.gz

[root@Slave2 software]# tar xf zookeeper-3.4.6.tar.gz -C /opt/stefan/
[root@Slave2 software]# ls /opt/stefan
hadoop-2.6.5  zookeeper-3.4.6
```

## path

```bash
###非ZK集群节点PATH
[root@Master ~]# tail -n 10 /etc/profile
...
unset i
unset -f pathmunge

export JAVA_HOME=/usr/java/jdk1.8.0_181
export HADOOP_HOME=/opt/stefan/hadoop-2.6.5
export PATH=$PATH:$JAVA_HOME/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin
```

```bash
###ZK集群节点PATH
[root@Slave2 ~]# tail -n 10 /etc/profile
...
unset i
unset -f pathmunge

export JAVA_HOME=/usr/java/jdk1.8.0_181
export HADOOP_HOME=/opt/stefan/hadoop-2.6.5
export ZOOKEEPER_HOME=/opt/stefan/zookeeper-3.4.6
export PATH=$PATH:$JAVA_HOME/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$ZOOKEEPER_HOME/bin
```

# Hadoop

## core-site.xml

```bash
<!-- 设置fs.defaultFS为Nameservices的逻辑主机名 -->
<property>
    <name>fs.defaultFS</name>
    <value>hdfs://mycluster</value>
</property>
<!-- 设置数据存放目录，不能放在tmp目录下 -->
<property>
    <name>hadoop.tmp.dir</name>
    <value>/var/stefan/hadoop/ha</value>
</property>
<!-- 设置zookeeper位置信息 -->
<property>
    <name>ha.zookeeper.quorum</name>
    <value>Slave2:2181,Slave3:2181,Slave4:2181</value>
</property>
```


## hdfs-site.xml


```bash
<!-- 自定义NameServices逻辑名称：mycluster -->
<property>
  <name>dfs.nameservices</name>
  <value>mycluster</value>
</property>
<!-- 映射nameservices逻辑名称到namenode逻辑名称 -->
<property>
  <name>dfs.ha.namenodes.mycluster</name>
  <value>nn1,nn2</value>
</property>
<!-- 映射namenode逻辑名称到真实主机名称（RPC） -->
<property>
  <name>dfs.namenode.rpc-address.mycluster.nn1</name>
  <value>Master:8020</value>
</property>
<!-- 映射namenode逻辑名称到真实主机名称（RPC） -->
<property>
  <name>dfs.namenode.rpc-address.mycluster.nn2</name>
  <value>Slave1:8020</value>
</property>
<!-- 映射namenode逻辑名称到真实主机名称（HTTP） -->
<property>
  <name>dfs.namenode.http-address.mycluster.nn1</name>
  <value>Master:50070</value>
</property>
<!-- 映射namenode逻辑名称到真实主机名称（HTTP） -->
<property>
  <name>dfs.namenode.http-address.mycluster.nn2</name>
  <value>Slave1:50070</value>
</property>
<!-- 配置JN集群位置信息及目录 -->
<property>
  <name>dfs.namenode.shared.edits.dir</name>
<value>qjournal://Master:8485;Slave1:8485;Slave2:8485/mycluster</value>
</property>
<!-- 配置journalnode edits文件位置 -->
<property>
  <name>dfs.journalnode.edits.dir</name>
  <value>/var/stefan/hadoop/jn</value>
</property>
<!-- 副本数 -->
<property>
    <name>dfs.replication</name>
    <value>3</value>
</property>
<!-- 配置故障迁移实现类 -->
<property>
  <name>dfs.client.failover.proxy.provider.mycluster</name>
<value>org.apache.hadoop.hdfs.server.namenode.ha.ConfiguredFailoverProxyProvider</value>
</property>
<!-- 指定故障时主备切换方式为SSH免密钥方式 -->
<property>
  <name>dfs.ha.fencing.methods</name>
  <value>sshfence</value>
</property>
<!-- 使用rsa算法生成的密钥就要用id_dsa -->
<property>
  <name>dfs.ha.fencing.ssh.private-key-files</name>
  <value>/root/.ssh/id_dsa</value>
</property>
<!-- 设置自动切换 -->
<property>
   <name>dfs.ha.automatic-failover.enabled</name>
   <value>true</value>
 </property>
<!-- web页面 -->
<property>
   <name>dfs.webhdfs.enabled</name>
   <value>true</value>
</property>
<!-- 用户组和权限，staff是默认 -->
<property>
   <name>dfs.permissions.superusergroup</name>
   <value>staff</value>
</property>
<!-- 是否要开启权限 -->
<property>
   <name>dfs.permissions.enabled</name>
   <value>false</value>
</property>
```

## hadoop-env.sh

```bash
export JAVA_HOME=${JAVA_HOME}
改成
export JAVA_HOME=/usr/java/jdk1.8.0_181
```

## slaves

```bash
[root@Master hadoop]# cat slaves
Slave2
Slave3
Slave4
```

## 分发其他节点

```bash
###先在其他节点新建目标目录
[root@Slave1 ~]# mkdir -p /opt/stefan
[root@Slave2 ~]# mkdir -p /opt/stefan
[root@Slave3 ~]# mkdir -p /opt/stefan
[root@Slave4 ~]# mkdir -p /opt/stefan

###分发配置好的Hadoop包
[root@Master ~]# cd /opt/stefan
[root@Master stefan]# scp -r ./hadoop-2.6.5/ root@Slave1:`pwd`
[root@Master stefan]# scp -r ./hadoop-2.6.5/ root@Slave2:`pwd`
[root@Master stefan]# scp -r ./hadoop-2.6.5/ root@Slave3:`pwd`
[root@Master stefan]# scp -r ./hadoop-2.6.5/ root@Slave4:`pwd`
```

# Zookeeper

## zoo.cfg

```bash
[root@Slave2 conf]# pwd
/opt/stefan/zookeeper-3.4.6/conf
[root@Slave2 conf]# cp zoo_sample.cfg zoo.cfg
[root@Slave2 conf]# ll
总用量 16
-rw-rw-r--. 1 1000 1000  535 2月  20 2014 configuration.xsl
-rw-rw-r--. 1 1000 1000 2161 2月  20 2014 log4j.properties
-rw-r--r--. 1 root root  922 2月 17 23:33 zoo.cfg
-rw-rw-r--. 1 1000 1000  922 2月  20 2014 zoo_sample.cfg
###添加配置
[root@Slave2 conf]# vim zoo.cfg
dataDir=/var/stefan/zk
server.1=172.16.114.132:2888:3888
server.2=172.16.114.133:2888:3888
server.3=172.16.114.134:2888:3888
```

## myid

```bash
[root@Slave2 ~]# mkdir -p /var/stefan/zk
[root@Slave2 ~]# echo 1 > /var/stefan/zk/myid

[root@Slave3 ~]# mkdir -p /var/stefan/zk
[root@Slave3 ~]# echo 2 > /var/stefan/zk/myid

[root@Slave4 ~]# mkdir -p /var/stefan/zk
[root@Slave4 ~]# echo 3 > /var/stefan/zk/myid
```

## 分发其他节点

```bash
[root@Slave2 stefan]# scp -r ./zookeeper-3.4.6/ Slave3:`pwd`
[root@Slave2 stefan]# scp -r ./zookeeper-3.4.6/ Slave4:`pwd`
```

# 格式化

## 启动ZK集群

```bash
[root@Slave2 ~]# zkServer.sh start
[root@Slave3 ~]# zkServer.sh start
[root@Slave4 ~]# zkServer.sh start

[root@Slave2 ~]# zkServer.sh status
###刚开始只有一个[zookeeper]
[root@Slave2 ~]# zkCli.sh
[zk: localhost:2181(CONNECTED) 0] ls /
[zookeeper]
```

## 启动JN集群

```bash
[root@Master ~]# hadoop-daemon.sh start journalnode
starting journalnode, logging to /opt/stefan/hadoop-2.6.5/logs/hadoop-root-journalnode-Master.out
[root@Master ~]# jps
2801 Jps
2755 JournalNode

[root@Slave1 ~]# hadoop-daemon.sh start journalnode
starting journalnode, logging to /opt/stefan/hadoop-2.6.5/logs/hadoop-root-journalnode-Slave1.out
[root@Slave1 ~]# jps
2571 Jps
2525 JournalNode

[root@Slave2 ~]# hadoop-daemon.sh start journalnode
starting journalnode, logging to /opt/stefan/hadoop-2.6.5/logs/hadoop-root-journalnode-Slave2.out
[root@Slave2 ~]# jps
2617 Jps
2571 JournalNode
2377 QuorumPeerMain
```

## NN格式化

```bash
[root@Master ~]# hdfs namenode -format
18/11/18 02:21:33 INFO namenode.NameNode: STARTUP_MSG:
/************************************************************
STARTUP_MSG: Starting NameNode
STARTUP_MSG:   host = Master/172.16.114.130
STARTUP_MSG:   args = [-format]
STARTUP_MSG:   version = 2.6.5
STARTUP_MSG:   classpath = /opt/stefan/hadoop-2.6.5/etc/hadoop:/opt/stefan/hadoop-2.6.5/etc/hadoop:/opt/stefan/hadoop-2.6.5/share/hadoop/common/lib/activation-1.1.jar:/opt/stefan/hadoop-2.6.5/share/hadoop/common/lib/jackson-mapper-asl-1.9.13.jar:
......

STARTUP_MSG:   build = https://github.com/apache/hadoop.git -r e8c9fe0b4c252caf2ebf1464220599650f119997; compiled by 'sjlee' on 2016-10-02T23:43Z
STARTUP_MSG:   java = 1.8.0_181
************************************************************/
18/11/18 02:21:33 INFO namenode.NameNode: registered UNIX signal handlers for [TERM, HUP, INT]
18/11/18 02:21:33 INFO namenode.NameNode: createNameNode [-format]
Formatting using clusterid: CID-194e87f9-860c-486a-9e52-e6d2b7f0161e
18/11/18 02:21:33 INFO namenode.FSNamesystem: No KeyProvider found.
18/11/18 02:21:33 INFO namenode.FSNamesystem: fsLock is fair:true
18/11/18 02:21:33 INFO blockmanagement.DatanodeManager: dfs.block.invalidate.limit=1000
18/11/18 02:21:33 INFO blockmanagement.DatanodeManager: dfs.namenode.datanode.registration.ip-hostname-check=true
18/11/18 02:21:33 INFO blockmanagement.BlockManager: dfs.namenode.startup.delay.block.deletion.sec is set to 000:00:00:00.000
18/11/18 02:21:33 INFO blockmanagement.BlockManager: The block deletion will start around 2018 十一月 18 02:21:33
18/11/18 02:21:33 INFO util.GSet: Computing capacity for map BlocksMap
18/11/18 02:21:33 INFO util.GSet: VM type       = 64-bit
18/11/18 02:21:33 INFO util.GSet: 2.0% max memory 966.7 MB = 19.3 MB
18/11/18 02:21:33 INFO util.GSet: capacity      = 2^21 = 2097152 entries
18/11/18 02:21:33 INFO blockmanagement.BlockManager: dfs.block.access.token.enable=false
18/11/18 02:21:33 INFO blockmanagement.BlockManager: defaultReplication         = 3
18/11/18 02:21:33 INFO blockmanagement.BlockManager: maxReplication             = 512
18/11/18 02:21:33 INFO blockmanagement.BlockManager: minReplication             = 1
18/11/18 02:21:33 INFO blockmanagement.BlockManager: maxReplicationStreams      = 2
18/11/18 02:21:33 INFO blockmanagement.BlockManager: replicationRecheckInterval = 3000
18/11/18 02:21:33 INFO blockmanagement.BlockManager: encryptDataTransfer        = false
18/11/18 02:21:33 INFO blockmanagement.BlockManager: maxNumBlocksToLog          = 1000
18/11/18 02:21:33 INFO namenode.FSNamesystem: fsOwner             = root (auth:SIMPLE)
18/11/18 02:21:33 INFO namenode.FSNamesystem: supergroup          = staff
18/11/18 02:21:33 INFO namenode.FSNamesystem: isPermissionEnabled = false
18/11/18 02:21:33 INFO namenode.FSNamesystem: Determined nameservice ID: mycluster
18/11/18 02:21:33 INFO namenode.FSNamesystem: HA Enabled: true
18/11/18 02:21:33 INFO namenode.FSNamesystem: Append Enabled: true
18/11/18 02:21:34 INFO util.GSet: Computing capacity for map INodeMap
18/11/18 02:21:34 INFO util.GSet: VM type       = 64-bit
18/11/18 02:21:34 INFO util.GSet: 1.0% max memory 966.7 MB = 9.7 MB
18/11/18 02:21:34 INFO util.GSet: capacity      = 2^20 = 1048576 entries
18/11/18 02:21:34 INFO namenode.NameNode: Caching file names occuring more than 10 times
18/11/18 02:21:34 INFO util.GSet: Computing capacity for map cachedBlocks
18/11/18 02:21:34 INFO util.GSet: VM type       = 64-bit
18/11/18 02:21:34 INFO util.GSet: 0.25% max memory 966.7 MB = 2.4 MB
18/11/18 02:21:34 INFO util.GSet: capacity      = 2^18 = 262144 entries
18/11/18 02:21:34 INFO namenode.FSNamesystem: dfs.namenode.safemode.threshold-pct = 0.9990000128746033
18/11/18 02:21:34 INFO namenode.FSNamesystem: dfs.namenode.safemode.min.datanodes = 0
18/11/18 02:21:34 INFO namenode.FSNamesystem: dfs.namenode.safemode.extension     = 30000
18/11/18 02:21:34 INFO namenode.FSNamesystem: Retry cache on namenode is enabled
18/11/18 02:21:34 INFO namenode.FSNamesystem: Retry cache will use 0.03 of total heap and retry cache entry expiry time is 600000 millis
18/11/18 02:21:34 INFO util.GSet: Computing capacity for map NameNodeRetryCache
18/11/18 02:21:34 INFO util.GSet: VM type       = 64-bit
18/11/18 02:21:34 INFO util.GSet: 0.029999999329447746% max memory 966.7 MB = 297.0 KB
18/11/18 02:21:34 INFO util.GSet: capacity      = 2^15 = 32768 entries
18/11/18 02:21:34 INFO namenode.NNConf: ACLs enabled? false
18/11/18 02:21:34 INFO namenode.NNConf: XAttrs enabled? true
18/11/18 02:21:34 INFO namenode.NNConf: Maximum size of an xattr: 16384
18/11/18 02:21:34 INFO namenode.FSImage: Allocated new BlockPoolId: BP-1532046409-172.16.114.130-1542478894908
18/11/18 02:21:34 INFO common.Storage: Storage directory /var/stefan/hadoop/ha/dfs/name has been successfully formatted.
18/11/18 02:21:35 INFO namenode.FSImageFormatProtobuf: Saving image file /var/stefan/hadoop/ha/dfs/name/current/fsimage.ckpt_0000000000000000000 using no compression
18/11/18 02:21:35 INFO namenode.FSImageFormatProtobuf: Image file /var/stefan/hadoop/ha/dfs/name/current/fsimage.ckpt_0000000000000000000 of size 316 bytes saved in 0 seconds.
18/11/18 02:21:35 INFO namenode.NNStorageRetentionManager: Going to retain 1 images with txid >= 0
18/11/18 02:21:35 INFO util.ExitUtil: Exiting with status 0
18/11/18 02:21:35 INFO namenode.NameNode: SHUTDOWN_MSG:
/************************************************************
SHUTDOWN_MSG: Shutting down NameNode at Master/172.16.114.130
************************************************************/
```

```bash
[root@Master ~]# hadoop-daemon.sh start namenode
starting namenode, logging to /opt/stefan/hadoop-2.6.5/logs/hadoop-root-namenode-Master.out
[root@Master ~]# jps
1607 NameNode
1483 JournalNode
1677 Jps
```

```bash
[root@Slave1 ~]# hdfs namenode -bootstrapStandby
18/11/18 02:22:40 INFO namenode.NameNode: STARTUP_MSG:
/************************************************************
STARTUP_MSG: Starting NameNode
STARTUP_MSG:   host = Slave1/172.16.114.131
STARTUP_MSG:   args = [-bootstrapStandby]
STARTUP_MSG:   version = 2.6.5
STARTUP_MSG:   classpath = /opt/stefan/hadoop-2.6.5/
....

STARTUP_MSG:   build = https://github.com/apache/hadoop.git -r e8c9fe0b4c252caf2ebf1464220599650f119997; compiled by 'sjlee' on 2016-10-02T23:43Z
STARTUP_MSG:   java = 1.8.0_181
************************************************************/
18/11/18 02:22:40 INFO namenode.NameNode: registered UNIX signal handlers for [TERM, HUP, INT]
18/11/18 02:22:40 INFO namenode.NameNode: createNameNode [-bootstrapStandby]
=====================================================
About to bootstrap Standby ID nn2 from:
           Nameservice ID: mycluster
        Other Namenode ID: nn1
  Other NN's HTTP address: http://Master:50070
  Other NN's IPC  address: Master/172.16.114.130:8020
             Namespace ID: 1142115627
            Block pool ID: BP-1532046409-172.16.114.130-1542478894908
               Cluster ID: CID-194e87f9-860c-486a-9e52-e6d2b7f0161e
           Layout version: -60
       isUpgradeFinalized: true
=====================================================
18/11/18 02:22:41 INFO common.Storage: Storage directory /var/stefan/hadoop/ha/dfs/name has been successfully formatted.
18/11/18 02:22:42 INFO namenode.TransferFsImage: Opening connection to http://Master:50070/imagetransfer?getimage=1&txid=0&storageInfo=-60:1142115627:0:CID-194e87f9-860c-486a-9e52-e6d2b7f0161e
18/11/18 02:22:42 INFO namenode.TransferFsImage: Image Transfer timeout configured to 60000 milliseconds
18/11/18 02:22:42 INFO namenode.TransferFsImage: Transfer took 0.00s at 0.00 KB/s
18/11/18 02:22:42 INFO namenode.TransferFsImage: Downloaded file fsimage.ckpt_0000000000000000000 size 316 bytes.
18/11/18 02:22:42 INFO util.ExitUtil: Exiting with status 0
18/11/18 02:22:42 INFO namenode.NameNode: SHUTDOWN_MSG:
/************************************************************
SHUTDOWN_MSG: Shutting down NameNode at Slave1/172.16.114.131
************************************************************/
```

## 报错

```bash
INFO org.apache.hadoop.ipc.Client: Retrying connect to server: master/192.168.1.240:9000. Already tried 0 time(s).
```

/etc/hosts 前两行127/0/0/1  localhost 删除


## 格式化zkfc

```bash
[root@Master ~]# hdfs zkfc -formatZK
18/11/18 02:32:55 INFO tools.DFSZKFailoverController: Failover controller configured for NameNode NameNode at Master/172.16.114.130:8020
18/11/18 02:32:55 INFO zookeeper.ZooKeeper: Client environment:zookeeper.version=3.4.6-1569965, built on 02/20/2014 09:09 GMT
18/11/18 02:32:55 INFO zookeeper.ZooKeeper: Client environment:host.name=Master
18/11/18 02:32:55 INFO zookeeper.ZooKeeper: Client environment:java.version=1.8.0_181
18/11/18 02:32:55 INFO zookeeper.ZooKeeper: Client environment:java.vendor=Oracle Corporation
18/11/18 02:32:55 INFO zookeeper.ZooKeeper: Client environment:java.home=/usr/java/jdk1.8.0_181/jre
18/11/18 02:32:55 INFO zookeeper.ZooKeeper: Client environment:java.class.path=/opt/stefan/hadoop-2.6.5/etc/hadoop:/opt/stefan/hadoop-2.6.5/share/hadoop/common/lib/activation-1.1.jar:/opt/stefan/hadoop-2.6.5/share/hadoop/common/lib/jackson-mapper-asl-1.9.13.jar:/opt/stefan/hadoop-2.6.5/share/hadoop/common/lib/java-xmlbuilder-0.4.jar:
...

18/11/18 02:32:55 INFO zookeeper.ZooKeeper: Client environment:java.library.path=/opt/stefan/hadoop-2.6.5/lib/native
18/11/18 02:32:55 INFO zookeeper.ZooKeeper: Client environment:java.io.tmpdir=/tmp
18/11/18 02:32:55 INFO zookeeper.ZooKeeper: Client environment:java.compiler=<NA>
18/11/18 02:32:55 INFO zookeeper.ZooKeeper: Client environment:os.name=Linux
18/11/18 02:32:55 INFO zookeeper.ZooKeeper: Client environment:os.arch=amd64
18/11/18 02:32:55 INFO zookeeper.ZooKeeper: Client environment:os.version=3.10.0-862.el7.x86_64
18/11/18 02:32:55 INFO zookeeper.ZooKeeper: Client environment:user.name=root
18/11/18 02:32:55 INFO zookeeper.ZooKeeper: Client environment:user.home=/root
18/11/18 02:32:55 INFO zookeeper.ZooKeeper: Client environment:user.dir=/root
18/11/18 02:32:55 INFO zookeeper.ZooKeeper: Initiating client connection, connectString=Slave2:2181,Slave3:2181,Slave4:2181 sessionTimeout=5000 watcher=org.apache.hadoop.ha.ActiveStandbyElector$WatcherWithClientRef@6069db50
18/11/18 02:32:55 INFO zookeeper.ClientCnxn: Opening socket connection to server Slave2/172.16.114.132:2181. Will not attempt to authenticate using SASL (unknown error)
18/11/18 02:32:55 INFO zookeeper.ClientCnxn: Socket connection established to Slave2/172.16.114.132:2181, initiating session
18/11/18 02:32:55 INFO zookeeper.ClientCnxn: Session establishment complete on server Slave2/172.16.114.132:2181, sessionid = 0x16722e4de790001, negotiated timeout = 5000
18/11/18 02:32:55 INFO ha.ActiveStandbyElector: Successfully created /hadoop-ha/mycluster in ZK.
18/11/18 02:32:55 INFO zookeeper.ZooKeeper: Session: 0x16722e4de790001 closed
18/11/18 02:32:55 WARN ha.ActiveStandbyElector: Ignoring stale result from old client with sessionId 0x16722e4de790001
18/11/18 02:32:55 INFO zookeeper.ClientCnxn: EventThread shut down
```

```bash
[zk: localhost:2181(CONNECTED) 0] ls /
[zookeeper]
###格式化之后
[zk: localhost:2181(CONNECTED) 1] ls /
[zookeeper, hadoop-ha]
[zk: localhost:2181(CONNECTED) 2] ls /hadoop-ha
[mycluster]
[zk: localhost:2181(CONNECTED) 3] ls /hadoop-ha/mycluster
[]
```

# 启动HA集群

```bash
[root@Master ~]# start-dfs.sh
Starting namenodes on [Master Slave1]
Master: Warning: Permanently added the ECDSA host key for IP address '172.16.114.130' to the list of known hosts.
Master: namenode running as process 1607. Stop it first.
Slave1: starting namenode, logging to /opt/stefan/hadoop-2.6.5/logs/hadoop-root-namenode-Slave1.out
Slave4: starting datanode, logging to /opt/stefan/hadoop-2.6.5/logs/hadoop-root-datanode-Slave4.out
Slave3: starting datanode, logging to /opt/stefan/hadoop-2.6.5/logs/hadoop-root-datanode-Slave3.out
Slave2: starting datanode, logging to /opt/stefan/hadoop-2.6.5/logs/hadoop-root-datanode-Slave2.out
Starting journal nodes [Master Slave1 Slave2]
Slave1: journalnode running as process 1473. Stop it first.
Slave2: journalnode running as process 1698. Stop it first.
Master: journalnode running as process 1483. Stop it first.
Starting ZK Failover Controllers on NN hosts [Master Slave1]
Slave1: starting zkfc, logging to /opt/stefan/hadoop-2.6.5/logs/hadoop-root-zkfc-Slave1.out
Master: starting zkfc, logging to /opt/stefan/hadoop-2.6.5/logs/hadoop-root-zkfc-Master.out
```

```bash
[root@Master ~]# jps
2229 Jps
1607 NameNode
2167 DFSZKFailoverController
1483 JournalNode
```

```bash
[root@Slave1 ~]# jps
1473 JournalNode
1603 NameNode
1763 Jps
1716 DFSZKFailoverController
```

```bash
[root@Slave2 ~]# jps
1698 JournalNode
1894 Jps
1479 QuorumPeerMain
1785 DataNode
```

```bash
[root@Slave3 ~]# jps
1536 QuorumPeerMain
1766 Jps
1673 DataNode
```

```bash
[root@Slave4 ~]# jps
1697 QuorumPeerMain
1923 Jps
1823 DataNode
```

```bash
[zk: localhost:2181(CONNECTED) 0] ls /
[zookeeper, hadoop-ha]
[zk: localhost:2181(CONNECTED) 1] get /hadoop-ha/mycluster/ActiveStandbyElectorLock

	myclusternn1Master �>(�>
cZxid = 0x10000000b
ctime = Sun Nov 18 02:36:27 CST 2018
mZxid = 0x10000000b
mtime = Sun Nov 18 02:36:27 CST 2018
pZxid = 0x10000000b
cversion = 0
dataVersion = 0
aclVersion = 0
ephemeralOwner = 0x26722e4de7f0001
dataLength = 30
numChildren = 0
```

