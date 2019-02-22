# 架构

|IP|HOSTNAME|NN|DN|ZK|ZKFC|JN|RM|NM|HM|HR|MetaStore|HiveServer2|
|---|---|---|---|---|---|---|---|---|---|---|---|---|
|172.16.114.130|Master|*|||*|*|||*||||
|172.16.114.131|Slave1|*|||*|*|||*||||
|172.16.114.132|Slave2||*|*||*||*||*|*||
|172.16.114.133|Slave3||*|*|||*|*||*||*|
|172.16.114.134|Slave4||*|*|||*|*||*||*|

# 安装配置

## MetaStore

记录MySQL-Server的安装、启动、授权。

```bash
###安装启动
[root@Slave2 ~]# yum install -y mysql-server
No package mysql-server available.
Error: Nothing to do
[root@Slave2 ~]# wget http://repo.mysql.com/mysql57-community-release-el7.rpm
[root@Slave2 ~]# rpm -ivh mysql57-community-release-el7.rpm
[root@Slave2 ~]# yum install -y mysql-server

###进程检测
[root@Slave2 ~]# service mysqld start
[root@Slave2 ~]# netstat -tulpn
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name
tcp6       0      0 :::3306                 :::*                    LISTEN      3022/mysqld                 
[root@Slave2 ~]# ps aux | grep mysql
mysql      3022  0.0  4.8 1120732 185660 ?      Sl   15:31   0:01 /usr/sbin/mysqld --daemonize --pid-file=/var/run/mysqld/mysqld.pid
root       3181  0.0  0.0 112704   972 pts/0    S+   16:19   0:00 grep --color=auto mysql

###mysql5.7在centOS7中好像默认开机自启动
[root@Slave2 ~]# systemctl list-unit-files | grep mysqld
mysqld.service                                enabled
mysqld@.service                               disabled
###设置或取消开机自启动的方式
[root@Slave2 ~]# systemctl  enable mysqld
[root@Slave2 ~]# systemctl  disable mysqld

###登陆出错或初始密码未知
[root@Slave2 ~]# mysql
ERROR 1045 (28000): Access denied for user 'root'@'localhost' (using password: NO)
ERROR 1045 (28000): Access denied for user 'root'@'localhost' (using password: YES)

###先允许免密码登陆,修改root用户密码
[root@Slave2 ~]# echo 'skip-grant-tables' >> /etc/my.cnf
[root@Slave2 ~]# mysql
mysql> use mysql
mysql> select host, user, authentication_string from user;
mysql> update user set authentication_string = password('centOS7/') where user = 'root';
mysql> exit

###去除免密码设置并重启mysql服务
[root@Slave2 ~]# vim /etc/my.cnf
GG dd
[root@Slave2 ~]# service mysqld stop
[root@Slave2 ~]# service mysqld start
```


```bash
###系统要求你重设密码并密码包含大小写、数字、特殊字符
mysql> show databases;
ERROR 1820 (HY000): You must reset your password using ALTER USER statement before executing this statement.
mysql> set password = password('root');
ERROR 1819 (HY000): Your password does not satisfy the current policy requirements
mysql> set password = password('centOS7/');
Query OK, 0 rows affected, 1 warning (0.01 sec)
```

```bash
###设置允许任意远程主机登陆
mysql> use mysql
mysql> grant all privileges on *.* to 'root'@'%' identified by 'centOS7/' with grant option;

mysql> flush privileges;
Query OK, 0 rows affected (0.00 sec)

mysql> select host,user,authentication_string from user;
+-----------+---------------+-------------------------------------------+
| host      | user          | authentication_string                     |
+-----------+---------------+-------------------------------------------+
| localhost | root          | *3EACF99850E716125A4463F6ED573D1FA115243D |
| localhost | mysql.session | *THISISNOTAVALIDPASSWORDTHATCANBEUSEDHERE |
| localhost | mysql.sys     | *THISISNOTAVALIDPASSWORDTHATCANBEUSEDHERE |
| %         | root          | *3EACF99850E716125A4463F6ED573D1FA115243D |
+-----------+---------------+-------------------------------------------+

mysql> delete from  user where host != '%';
Query OK, 3 rows affected (0.00 sec)

mysql> select host,user,authentication_string from user;
+------+------+-------------------------------------------+
| host | user | authentication_string                     |
+------+------+-------------------------------------------+
| %    | root | *3EACF99850E716125A4463F6ED573D1FA115243D |
+------+------+-------------------------------------------+
```


## HiveServer2

### 基础操作

```bash
###上传
Stefan-Mac:Downloads stefan$ scp ./apache-hive-1.2.1-bin.tar.gz  root@Slave3:/usr/local/software/
Stefan-Mac:Downloads stefan$ scp ./mysql-connector-java-5.1.32-bin.jar root@Slave3:/usr/local/software/

##解压
[root@Slave3 software]# tar xf apache-hive-1.2.1-bin.tar.gz -C /opt/stefan/
[root@Slave3 stefan]# ls
apache-hive-1.2.1-bin  hadoop-2.6.5  hbase-0.98.12.1-hadoop2  zookeeper-3.4.6

###配置PATH （Slave4一样）
[root@Slave3 ~]# tail -n 6 /etc/profile
export JAVA_HOME=/usr/java/jdk1.8.0_181
export HADOOP_HOME=/opt/stefan/hadoop-2.6.5
export ZOOKEEPER_HOME=/opt/stefan/zookeeper-3.4.6
export HBASE_HOME=/opt/stefan/hbase-0.98.12.1-hadoop2
export HIVE_HOME=/opt/stefan/apache-hive-1.2.1-bin
export PATH=$PATH:$JAVA_HOME/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$ZOOKEEPER_HOME/bin:$HBASE_HOME/bin:$HIVE_HOME/bin
```

### 添加MetaStore连接驱动

```bash
[root@Slave3 lib]# pwd
/opt/stefan/apache-hive-1.2.1-bin/lib
[root@Slave3 lib]# cp /usr/local/software/mysql-connector-java-5.1.32-bin.jar .
```

### hive-site.xml

```bash
###删除</configuration>中所有属性
[root@Slave3 conf]# cp hive-default.xml.template hive-site.xml
[root@Slave3 conf]# vim hive-site.xml
:.,$-1d
```

```bash
###Slave3
<!-- hive表在HDFS中的存储路径 -->
<property>  
    <name>hive.metastore.warehouse.dir</name>  
    <value>/stefan/hive2</value>  
</property>
<!-- MetaStore连接配置 -->
<property>  
    <name>javax.jdo.option.ConnectionURL</name>  
    <value>jdbc:mysql://Slave2:3306/hive2?createDatabaseIfNotExist=true</value>  
</property>  
<property>  
    <name>javax.jdo.option.ConnectionDriverName</name>  
    <value>com.mysql.jdbc.Driver</value>  
</property>     
<property>  
    <name>javax.jdo.option.ConnectionUserName</name>  
    <value>root</value>  
</property>  
<property>  
    <name>javax.jdo.option.ConnectionPassword</name>  
    <value>centOS7/</value>  
</property>
<!-- hiveserver2动态分配客户端 -->
<property>
    <name>hive.server2.support.dynamic.service.discovery</name>
    <value>true</value>
</property>
<property>
    <name>hive.server2.zookeeper.namespace</name>
    <value>hiveserver2-ha</value>
</property>
<property>
    <name>hive.zookeeper.quorum</name>
    <value>Slave2:2181,Slave3:2181,Slave4:2181</value>
</property>
<property>
    <name>hive.zookeeper.client.port</name>
    <value>2181</value>
</property>
<property>
    <name>hive.server2.thrift.bind.host</name>
    <value>Slave3</value>
</property>
<property>
    <name>hive.server2.thrift.port</name>
    <value>10001</value> 
</property>
```


### 分发另一台HiveServer2节点

```bash
[root@Slave3 stefan]# pwd
/opt/stefan
[root@Slave3 stefan]# scp -r ./apache-hive-1.2.1-bin/ Slave4:`pwd`
```

Slave4节点上配置PATH，然后更改hive-site.xml

```bash
###Slave4
<!-- 与Slave3配置中唯一的不同 -->
<property>
    <name>hive.server2.thrift.bind.host</name>
    <value>Slave4</value>
</property>
```


## 启动连接

```bash
[root@Slave2 ~]# zkServer.sh start
[root@Slave3 ~]# zkServer.sh start
[root@Slave4 ~]# zkServer.sh start

[root@Master ~]# start-dfs.sh

[root@Master ~]# start-yarn.sh
[root@Slave3 ~]# yarn-daemon.sh start resourcemanager
[root@Slave4 ~]# yarn-daemon.sh start resourcemanager

[root@Slave2 ~]# service mysqld start
[root@Slave3 ~]# nohup hive --service hiveserver2 &
[root@Slave4 ~]# nohup hive --service hiveserver2 &
```

```bash
[root@Slave3 ~]# beeline
Beeline version 1.2.1 by Apache Hive
###!connect URL user password
beeline> !connect jdbc:hive2://Slave2,Slave3,Slave4/;serviceDiscoveryMode=zooKeeper;zooKeeperNamespace=hiveserver2-ha root centOS7/

###退出
0: jdbc:hive2://Slave2,Slave3,Slave4/> !q
```

## 测试

1. ZK

    ```bash
    [zk: localhost:2181(CONNECTED) 0] ls /
    [hiveserver2-ha, zookeeper, yarn-leader-election, hadoop-ha, hbase]
    [zk: localhost:2181(CONNECTED) 1] ls /hiveserver2-ha
    [serverUri=Slave3:10001;version=1.2.1;sequence=0000000000, serverUri=Slave4:10001;version=1.2.1;sequence=0000000001]
    ```

2. MetaStore

    ```bash
    mysql> use hive2
    
    mysql> select * from TBLS;
    +--------+-------------+-------+------------------+-------+-----------+-------+------------+---------------+--------------------+--------------------+
    | TBL_ID | CREATE_TIME | DB_ID | LAST_ACCESS_TIME | OWNER | RETENTION | SD_ID | TBL_NAME   | TBL_TYPE      | VIEW_EXPANDED_TEXT | VIEW_ORIGINAL_TEXT |
    +--------+-------------+-------+------------------+-------+-----------+-------+------------+---------------+--------------------+--------------------+
    |      1 |  1543889808 |     1 |                0 | root  |         0 |     1 | bgis_track | MANAGED_TABLE | NULL               | NULL               |
    +--------+-------------+-------+------------------+-------+-----------+-------+------------+---------------+--------------------+--------------------+
    1 row in set (0.00 sec)
    ```

3. HiveSever2

    ```bash
    0: jdbc:hive2://Slave2,Slave3,Slave4/> create table bgis_track(id int, name string, age int)
    0: jdbc:hive2://Slave2,Slave3,Slave4/> row format delimited
    0: jdbc:hive2://Slave2,Slave3,Slave4/> fields terminated by ',';
    No rows affected (0.301 seconds)
    0: jdbc:hive2://Slave2,Slave3,Slave4/> show tables;
    +-------------+--+
    |  tab_name   |
    +-------------+--+
    | bgis_track  |
    +-------------+--+
    1 row selected (0.099 seconds)
    0: jdbc:hive2://Slave2,Slave3,Slave4/> desc bgis_track;
    +-----------+------------+----------+--+
    | col_name  | data_type  | comment  |
    +-----------+------------+----------+--+
    | id        | int        |          |
    | name      | string     |          |
    | age       | int        |          |
    +-----------+------------+----------+--+
    3 rows selected (0.2 seconds)
    ```

4. Yarn-MR

    ```bash
    0: jdbc:hive2://Slave2,Slave3,Slave4/> insert into bgis_track values(10010,'tom',20);
    INFO  : Number of reduce tasks is set to 0 since there's no reduce operator
    INFO  : number of splits:1
    INFO  : Submitting tokens for job: job_1543890524784_0001
    INFO  : The url to track the job: http://Slave3:8088/proxy/application_1543890524784_0001/
    INFO  : Starting Job = job_1543890524784_0001, Tracking URL = http://Slave3:8088/proxy/application_1543890524784_0001/
    INFO  : Kill Command = /opt/stefan/hadoop-2.6.5/bin/hadoop job  -kill job_1543890524784_0001
    INFO  : Hadoop job information for Stage-1: number of mappers: 1; number of reducers: 0
    INFO  : 2018-12-04 10:32:32,345 Stage-1 map = 0%,  reduce = 0%
    INFO  : 2018-12-04 10:32:50,201 Stage-1 map = 100%,  reduce = 0%, Cumulative CPU 1.62 sec
    INFO  : MapReduce Total cumulative CPU time: 1 seconds 620 msec
    INFO  : Ended Job = job_1543890524784_0001
    INFO  : Stage-4 is selected by condition resolver.
    INFO  : Stage-3 is filtered out by condition resolver.
    INFO  : Stage-5 is filtered out by condition resolver.
    INFO  : Moving data to: hdfs://mycluster/stefan/hive2/bgis_track/.hive-staging_hive_2018-12-04_10-32-05_351_8494567251340651583-3/-ext-10000 from hdfs://mycluster/stefan/hive2/bgis_track/.hive-staging_hive_2018-12-04_10-32-05_351_8494567251340651583-3/-ext-10002
    INFO  : Loading data to table default.bgis_track from hdfs://mycluster/stefan/hive2/bgis_track/.hive-staging_hive_2018-12-04_10-32-05_351_8494567251340651583-3/-ext-10000
    INFO  : Table default.bgis_track stats: [numFiles=1, numRows=1, totalSize=13, rawDataSize=12]
    No rows affected (46.532 seconds)
    0: jdbc:hive2://Slave2,Slave3,Slave4/> select * from bgis_track;
    +----------------+------------------+-----------------+--+
    | bgis_track.id  | bgis_track.name  | bgis_track.age  |
    +----------------+------------------+-----------------+--+
    | 10010          | tom              | 20              |
    +----------------+------------------+-----------------+--+
    1 row selected (0.153 seconds)
    ```

5. HDFS

    ```bash
    [root@Master ~]# hdfs dfs -cat /stefan/hive2/bgis_track/*
    10010,tom,20
    ```

## 测试hiveserver2-HA

```bash
[zk: localhost:2181(CONNECTED) 8] ls /hiveserver2-ha
[serverUri=Slave4:10001;version=1.2.1;sequence=0000000004, serverUri=Slave3:10001;version=1.2.1;sequence=0000000005]
```





