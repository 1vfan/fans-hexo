# 架构

IP|HOSTNAME|NN|DN|ZK|ZKFC|JN|RM|NM|HM|HR
---|---|---|---|---|---|---|---|---|---|---|---
172.16.114.130|Master|*|||*|*|||*|
172.16.114.131|Slave1|*|||*|*|||*|
172.16.114.132|Slave2||*|*||*||*||*
172.16.114.133|Slave3||*|*|||*|*||*
172.16.114.134|Slave4||*|*|||*|*||*

# 基础

## tar.gz

```bash
stefan-mac:Downloads stefan$ scp ./hbase-0.98.12.1-hadoop2-bin.tar root@Master:/usr/local/software/

[root@Master software]# ls
hadoop-2.6.5.tar.gz  hbase-0.98.12.1-hadoop2-bin.tar.gz  jdk-8u181-linux-x64.tar.gz  zookeeper-3.4.6.tar.gz
[root@Master software]# tar xf hbase-0.98.12.1-hadoop2-bin.tar.gz -C /opt/stefan/
[root@Master software]# ls /opt/stefan
hadoop-2.6.5  hbase-0.98.12.1-hadoop2
```

## path

```bash
[root@Slave3 ~]# tail -n 10 /etc/profile
done

unset i
unset -f pathmunge

export JAVA_HOME=/usr/java/jdk1.8.0_181
export HADOOP_HOME=/opt/stefan/hadoop-2.6.5
export ZOOKEEPER_HOME=/opt/stefan/zookeeper-3.4.6
export HBASE_HOME=/opt/stefan/hbase-0.98.12.1-hadoop2
export PATH=$PATH:$JAVA_HOME/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$ZOOKEEPER_HOME/bin:$HBASE_HOME/bin
```


# Hbase

## hbase-env.sh 

```bash
[root@Master conf]# grep '^[a-z]' hbase-env.sh
export JAVA_HOME=/usr/java/jdk1.8.0_181
export HBASE_CLASSPATH=.:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar
export HBASE_OPTS="-XX:+UseConcMarkSweepGC"
export HBASE_MANAGES_ZK=false
```

## hbase-site.xml

```bash
<!-- hdfs的nameservice -->
<property>
  <name>hbase.rootdir</name>
  <value>hdfs://mycluster/hbase</value>
</property>
<property>
  <name>hbase.cluster.distributed</name>
  <value>true</value>
</property>
<property>
  <name>hbase.zookeeper.quorum</name>
  <value>Slave2,Slave3,Slave4</value>
</property>
```

## regionservers

```bash
[root@Master conf]# cat regionservers
Slave2
Slave3
Slave4
```

## backup-masters

```bash
###新建备份节点配置文件，添加备份节点
[root@Master conf]# vim backup-masters
Slave1
```

## 拷贝HDFS配置文件

```bash
[root@Master conf]# pwd
/opt/stefan/hbase-0.98.12.1-hadoop2/conf
[root@Master conf]# cp /opt/stefan/hadoop-2.6.5/etc/hadoop/hdfs-site.xml ./
[root@Master conf]# ls
backup-masters                    hbase-env.cmd  hbase-policy.xml  hdfs-site.xml     regionservers
hadoop-metrics2-hbase.properties  hbase-env.sh   hbase-site.xml    log4j.properties
```

## date

所有Hbase部署节点需要保证服务器时间相差不超过30秒，否则无法启动Hbase集群。

## 分发其他节点

```bash
[root@Master stefan]# scp -r ./hbase-0.98.12.1-hadoop2/ Slave1:`pwd`
###docs目录太大影响传输时间
[root@Slave1 hbase-0.98.12.1-hadoop2]# rm -rf docs
[root@Slave1 stefan]# scp -r ./hbase-0.98.12.1-hadoop2/ Slave2:`pwd`
[root@Slave1 stefan]# scp -r ./hbase-0.98.12.1-hadoop2/ Slave3:`pwd`
[root@Slave1 stefan]# scp -r ./hbase-0.98.12.1-hadoop2/ Slave4:`pwd`
```

# 启动

```bash
[root@Slave2 ~]# zkServer.sh start
[root@Slave3 ~]# zkServer.sh start
[root@Slave4 ~]# zkServer.sh start

[root@Master ~]# start-dfs.sh

[root@Master ~]# start-yarn.sh
[root@Slave3 ~]# yarn-daemon.sh start resourcemanager
[root@Slave4 ~]# yarn-daemon.sh start resourcemanager
```

```bash
[root@Master ~]# start-hbase.sh
starting master, logging to /opt/stefan/hbase-0.98.12.1-hadoop2/logs/hbase-root-master-Master.out
Slave4: starting regionserver, logging to /opt/stefan/hbase-0.98.12.1-hadoop2/bin/../logs/hbase-root-regionserver-Slave4.out
Slave2: starting regionserver, logging to /opt/stefan/hbase-0.98.12.1-hadoop2/bin/../logs/hbase-root-regionserver-Slave2.out
Slave3: starting regionserver, logging to /opt/stefan/hbase-0.98.12.1-hadoop2/bin/../logs/hbase-root-regionserver-Slave3.out
Slave1: starting master, logging to /opt/stefan/hbase-0.98.12.1-hadoop2/bin/../logs/hbase-root-master-Slave1.out
```

```bash
[zk: localhost:2181(CONNECTED) 1] ls /
[zookeeper, yarn-leader-election, hadoop-ha, hbase]
[zk: localhost:2181(CONNECTED) 2] ls /hbase
[replication, meta-region-server, rs, splitWAL, backup-masters, table-lock, region-in-transition, online-snapshot, master, running, recovering-regions, draining, namespace, hbaseid, table]
```

# hbase shell

```bash
[root@Master ~]# hbase shell

hbase(main):003:0> create 'bgis_track',{NAME=>'track_info',VERSIONS=>1}
0 row(s) in 0.5930 seconds

=> Hbase::Table - bgis_track
hbase(main):004:0> list
TABLE
bgis_track
1 row(s) in 0.0310 seconds

=> ["bgis_track"]
hbase(main):005:0> put 'bgis_track','8010020_1500000000000','track_info:recipientUserId','8010020'
0 row(s) in 0.2040 seconds

hbase(main):006:0> put 'bgis_track','8010020_1500000000000','track_info:updateTime','1500000000000'
0 row(s) in 0.0130 seconds

hbase(main):007:0> scan 'bgis_track'
ROW                            COLUMN+CELL
 8010020_1500000000000         column=track_info:recipientUserId, timestamp=1542728695926, value=8010020
 8010020_1500000000000         column=track_info:updateTime, timestamp=1542728720008, value=1500000000000
1 row(s) in 0.0300 seconds
```

