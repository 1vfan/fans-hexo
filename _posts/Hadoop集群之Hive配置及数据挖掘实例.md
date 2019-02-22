---
title: Hadoop集群之Hive配置及数据挖掘实例
date: 2017-05-27 13:34:03
tags:
- Hadoop
- Linux
- Hive
categories:
- Hadoop栈
---
记录Hadoop集群中Hive的配置以及使用Hive内嵌的数据库derby模拟搜索引擎关键词搜索结果排行榜

<!--more-->

# 前期准备

> 点击下载-->[<font face="Times New Roman" color=#0099ff>Hive</font>](http://apache.fayea.com/hive/hive-2.1.1/)

> 继承传送门-->[<font face="Times New Roman" color=#0099ff>HDFS配置</font>](https://1vfan.github.io/2017/05/14/Hadoop%E9%9B%86%E7%BE%A4%E4%B9%8BHDFS%E5%8D%8F%E8%AE%AE%E9%85%8D%E7%BD%AE/)

> 继承传送门-->[<font face="Times New Roman" color=#0099ff>Yarn配置</font>](https://1vfan.github.io/2017/05/22/Hadoop%E9%9B%86%E7%BE%A4%E4%B9%8BYarn%E8%B0%83%E5%BA%A6+MapReduce%E8%AE%A1%E7%AE%97/)

# Hive配置

## 解压安装

> 使用[<font face="Times New Roman" color=#0099ff>FileZilla</font>](http://download.csdn.net/detail/weixin_37479489/9863014)或者Xftp工具将Hive安装包分别上传到master的/usr/local/目录下

```bash
# cd /usr/local
# tar -xvf apache-hive-2.1.1-bin.tar.gz
# mv apache-hive-2.1.1-bin hive
```

## 环境变量

> 设定环境变量HADOOP_HOME，HIVE_HOME，将bin目录加入到PATH中

```bash
# vim /etc/profile
添加
export HADOOP_HOME=/usr/local/hadoop
export HIVE_HOME=/usr/local/hive
export PATH=$PATH:/usr/local/hadoop/bin:/usr/local/hadoop/sbin
export PATH=$PATH:$HIVE_HOME/bin

# source /etc/profile
```

> 验证

```bash
# echo $HIVE_HOME
/usr/local/hive
# cd /usr/local/hive
# hive
报错，很正常因为还没有配置，但是hive目录下会产生一个metastore_db文件，需要删除
# rm -rf metastore_db
或者
# rm -rf m*_db
```


## hive-site.xml

> hive-site.xml文件本来是没有的，需要copy

```bash
# cd /usr/local/hive/conf
# cp hive-default.xml.template hive-site.xml
```

> 使用[<font face="Times New Roman" color=#0099ff>FileZilla</font>](http://download.csdn.net/detail/weixin_37479489/9863014) 把hive-site.xml下载到本地环境修改

```bash
hive.metastore.schema.verification
属性原为true，修改为false

# cd /usr/local/hive
# mkdir tmp  
装一些计算时候的临时文件

${system:java.io.tmpdir}全部替换成新建的 /usr/local/hive/tmp目录（4处）
${system:user.name}全部替换成当前用户 root（3处）
保存后使用工具将下载编辑的覆盖原先的hive-site.xml，完成修改
```

## 关于metastore

* 执行 schematool -initSchema -dbType derby 命令会在当前目录下建立metastore_db的数据库

* 遇到问题，如果以后启动hive的时候出现任何问题，把metastore_db删掉，重新执行命令，笔者在经历两次不同的异常删除两次后终于成功

* 实际工作环境中，经常使用mysql作为metastore的数据，将mysql的JDBC驱动下载放到hive的library目录下面，配置文件改过来就可以了

<font face="Times New Roman" color=#ff0000>warning：</font>下次应该还在同一目录执行hive，默认到当前目录下寻找metastore；因为单进程不支持多用户的简单内嵌数据库derby的源数据保存在这，在别的地方执行hive命令，会导致在别的目录下重新生成新的metastore_db文件，原来数据就读不出来了

```bash
# cd /usr/local/hive 
执行schematool 命令
[root@master hive]# schematool -initSchema -dbType derby
which: no hbase in (/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/usr/local/hadoop/bin:/usr/local/hadoop/sbin:/root/bin:/usr/local/hadoop/bin:/usr/local/hadoop/sbin:/usr/local/hive/bin)
SLF4J: Class path contains multiple SLF4J bindings.
SLF4J: Found binding in [jar:file:/usr/local/hive/lib/log4j-slf4j-impl-2.4.1.jar!/org/slf4j/impl/StaticLoggerBinder.class]
SLF4J: Found binding in [jar:file:/usr/local/hadoop/share/hadoop/common/lib/slf4j-log4j12-1.7.10.jar!/org/slf4j/impl/StaticLoggerBinder.class]
SLF4J: See http://www.slf4j.org/codes.html#multiple_bindings for an explanation.
SLF4J: Actual binding is of type [org.apache.logging.slf4j.Log4jLoggerFactory]
Metastore connection URL:	 jdbc:derby:;databaseName=metastore_db;create=true
Metastore Connection Driver :	 org.apache.derby.jdbc.EmbeddedDriver
Metastore connection User:	 APP
Starting metastore schema initialization to 2.1.0
Initialization script hive-schema-2.1.0.derby.sql
Initialization script completed
schemaTool completed
[root@master hive]# ls
bin  conf  derby.log  examples  hcatalog  jdbc  lib  LICENSE  metastore_db  NOTICE  README.txt  RELEASE_NOTES.txt  scripts
```

发现多了一个metastore_db，这就是derby创建的数据库，这个数据库存储着hive的源数据

# 启动hive

> hive只能建表、查询，真正数据是位于HDFS里，而他的源数据是位于另外一个数据库里面 如derby、mysql，所以他只相当于一个翻译器

```bash
在启动hive之前需要先启动hdfs和yarn，不然会报错，报错后的处理方案：
删除metastore_db，重新建立数据库
# rm -rf metastore_db
[root@master hive]# schematool -initSchema -dbType derby

# start-dfs.sh
# start-yarn.sh
[root@master hive]# hive
which: no hbase in (/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/usr/local/hadoop/bin:/usr/local/hadoop/sbin:/root/bin:/usr/local/hadoop/bin:/usr/local/hadoop/sbin:/usr/local/hive/bin)
SLF4J: Class path contains multiple SLF4J bindings.
SLF4J: Found binding in [jar:file:/usr/local/hive/lib/log4j-slf4j-impl-2.4.1.jar!/org/slf4j/impl/StaticLoggerBinder.class]
SLF4J: Found binding in [jar:file:/usr/local/hadoop/share/hadoop/common/lib/slf4j-log4j12-1.7.10.jar!/org/slf4j/impl/StaticLoggerBinder.class]
SLF4J: See http://www.slf4j.org/codes.html#multiple_bindings for an explanation.
SLF4J: Actual binding is of type [org.apache.logging.slf4j.Log4jLoggerFactory]

Logging initialized using configuration in jar:file:/usr/local/hive/lib/hive-common-2.1.1.jar!/hive-log4j2.properties Async: true
Hive-on-MR is deprecated in Hive 2 and may not be available in the future versions. Consider using a different execution engine (i.e. spark, tez) or using Hive 1.X releases.
hive> 
成功
```

# 数据挖掘

> 使用Hive内嵌的数据库derby模拟搜索引擎关键词搜索结果排行榜，将一堆搜索引擎的日志文件清洗后上传到/usr/local

## 建表

```bash
# cd /usr/local
[root@master local]# hadoop fs -put baidu.dic /
[root@master local]# cd hive
[root@master hive]# hive
hive> create table bdr(querytime string, queryip string, queryword string, queryurl string) row format delimited fields terminated by ',';
OK
Time taken: 10.263 seconds
hive> desc bdr;
OK
querytime           	string              	                    
queryip             	string              	                    
queryword           	string              	                    
queryurl            	string              	                    
Time taken: 1.705 seconds, Fetched: 4 row(s)
```

## 建立映射

> hdfs和derby数据库间建立映射，而不是把HDFS中的数据导入到表中

```bash
hive> load data inpath '/baidu.dic' into table bdr;
Loading data to table default.bdr
OK
Time taken: 4.5 seconds
```

## 通过表访问数据

> 总记录数

```bash
hive> select count(*) from bdr;
WARNING: Hive-on-MR is deprecated in Hive 2 and may not be available in the future versions. Consider using a different execution engine (i.e. spark, tez) or using Hive 1.X releases.
Query ID = root_20170612030532_9be372c5-3af0-4b20-b435-dd4052d6bc17
Total jobs = 1
Launching Job 1 out of 1
Number of reduce tasks determined at compile time: 1
In order to change the average load for a reducer (in bytes):
  set hive.exec.reducers.bytes.per.reducer=<number>
In order to limit the maximum number of reducers:
  set hive.exec.reducers.max=<number>
In order to set a constant number of reducers:
  set mapreduce.job.reduces=<number>
Starting Job = job_1497204507742_0002, Tracking URL = http://master:8088/proxy/application_1497204507742_0002/
Kill Command = /usr/local/hadoop/bin/hadoop job  -kill job_1497204507742_0002
Hadoop job information for Stage-1: number of mappers: 1; number of reducers: 1
2017-05-27 03:06:17,314 Stage-1 map = 0%,  reduce = 0%
2017-05-27 03:07:17,410 Stage-1 map = 0%,  reduce = 0%
2017-05-27 03:08:18,584 Stage-1 map = 0%,  reduce = 0%
2017-05-27 03:09:19,517 Stage-1 map = 0%,  reduce = 0%
2017-05-27 03:10:19,724 Stage-1 map = 0%,  reduce = 0%
2017-05-27 03:11:20,417 Stage-1 map = 0%,  reduce = 0%
2017-05-27 03:12:21,279 Stage-1 map = 0%,  reduce = 0%
2017-05-27 03:13:22,052 Stage-1 map = 0%,  reduce = 0%
2017-05-27 03:14:23,084 Stage-1 map = 0%,  reduce = 0%
2017-05-27 03:15:23,258 Stage-1 map = 0%,  reduce = 0%
2017-05-27 03:16:23,564 Stage-1 map = 0%,  reduce = 0%
2017-05-27 03:17:24,021 Stage-1 map = 0%,  reduce = 0%
2017-05-27 03:18:24,734 Stage-1 map = 0%,  reduce = 0%
2017-05-27 03:18:55,494 Stage-1 map = 100%,  reduce = 0%, Cumulative CPU 18.96 sec
2017-05-27 03:19:25,970 Stage-1 map = 100%,  reduce = 67%, Cumulative CPU 23.93 sec
2017-05-27 03:19:28,584 Stage-1 map = 100%,  reduce = 100%, Cumulative CPU 26.45 sec
MapReduce Total cumulative CPU time: 26 seconds 450 msec
Ended Job = job_1497204507742_0002
MapReduce Jobs Launched: 
Stage-Stage-1: Map: 1  Reduce: 1   Cumulative CPU: 26.45 sec   HDFS Read: 153364215 HDFS Write: 107 SUCCESS
Total MapReduce CPU Time Spent: 26 seconds 450 msec
OK
1724264
Time taken: 838.761 seconds, Fetched: 1 row(s)
```

> 将所有记录的关键词字段分组缩减统计汇总导入新表中

```bash
[root@master hive]# hive
which: no hbase in (/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/usr/local/hadoop/bin:/usr/local/hadoop/sbin:/usr/local/hive/bin:/root/bin)
SLF4J: Class path contains multiple SLF4J bindings.
SLF4J: Found binding in [jar:file:/usr/local/hive/lib/log4j-slf4j-impl-2.4.1.jar!/org/slf4j/impl/StaticLoggerBinder.class]
SLF4J: Found binding in [jar:file:/usr/local/hadoop/share/hadoop/common/lib/slf4j-log4j12-1.7.10.jar!/org/slf4j/impl/StaticLoggerBinder.class]
SLF4J: See http://www.slf4j.org/codes.html#multiple_bindings for an explanation.
SLF4J: Actual binding is of type [org.apache.logging.slf4j.Log4jLoggerFactory]

Logging initialized using configuration in jar:file:/usr/local/hive/lib/hive-common-2.1.1.jar!/hive-log4j2.properties Async: true
Hive-on-MR is deprecated in Hive 2 and may not be available in the future versions. Consider using a different execution engine (i.e. spark, tez) or using Hive 1.X releases.
hive> show databases;
OK
default
Time taken: 6.386 seconds, Fetched: 1 row(s)
hive> use default;
OK
Time taken: 0.21 seconds
hive> show tables;
OK
bdr
Time taken: 0.342 seconds, Fetched: 1 row(s)
hive> desc bdr;
OK
querytime           	string              	                    
queryip             	string              	                    
queryword           	string              	                    
queryurl            	string              	                    
Time taken: 2.544 seconds, Fetched: 4 row(s)
hive> create table baidu_results as select keyword, count(1) as count from (select queryword as keyword from bdr) t group by keyword order by count desc;
WARNING: Hive-on-MR is deprecated in Hive 2 and may not be available in the future versions. Consider using a different execution engine (i.e. spark, tez) or using Hive 1.X releases.
Query ID = root_20170612092740_bedd4431-b5ad-4d35-8dbf-2951087392a7
Total jobs = 2
Launching Job 1 out of 2
Number of reduce tasks not specified. Estimated from input data size: 1
In order to change the average load for a reducer (in bytes):
  set hive.exec.reducers.bytes.per.reducer=<number>
In order to limit the maximum number of reducers:
  set hive.exec.reducers.max=<number>
In order to set a constant number of reducers:
  set mapreduce.job.reduces=<number>
Starting Job = job_1497230205272_0001, Tracking URL = http://master:8088/proxy/application_1497230205272_0001/
Kill Command = /usr/local/hadoop/bin/hadoop job  -kill job_1497230205272_0001
Hadoop job information for Stage-1: number of mappers: 0; number of reducers: 0
2017-05-27 09:53:27,379 Stage-1 map = 0%,  reduce = 0%
Ended Job = job_1497230205272_0001 with errors
Error during job, obtaining debugging information...
FAILED: Execution Error, return code 2 from org.apache.hadoop.hive.ql.exec.mr.MapRedTask
MapReduce Jobs Launched: 
Stage-Stage-1:  HDFS Read: 0 HDFS Write: 0 FAIL
Total MapReduce CPU Time Spent: 0 msec
hive> create table baidu_results as select keyword, count(1) as count from (select queryword as keyword from bdr) t group by keyword order by count desc;
WARNING: Hive-on-MR is deprecated in Hive 2 and may not be available in the future versions. Consider using a different execution engine (i.e. spark, tez) or using Hive 1.X releases.
Query ID = root_20170612095906_5c00a2da-2a19-4e66-8599-c7376d3dec33
Total jobs = 2
Launching Job 1 out of 2
Number of reduce tasks not specified. Estimated from input data size: 1
In order to change the average load for a reducer (in bytes):
  set hive.exec.reducers.bytes.per.reducer=<number>
In order to limit the maximum number of reducers:
  set hive.exec.reducers.max=<number>
In order to set a constant number of reducers:
  set mapreduce.job.reduces=<number>
Starting Job = job_1497230205272_0002, Tracking URL = http://master:8088/proxy/application_1497230205272_0002/
Kill Command = /usr/local/hadoop/bin/hadoop job  -kill job_1497230205272_0002
Hadoop job information for Stage-1: number of mappers: 1; number of reducers: 1
2017-05-27 10:00:15,392 Stage-1 map = 0%,  reduce = 0%
2017-05-27 10:01:08,666 Stage-1 map = 58%,  reduce = 0%, Cumulative CPU 24.58 sec
2017-05-27 10:01:21,626 Stage-1 map = 67%,  reduce = 0%, Cumulative CPU 35.8 sec
2017-05-27 10:01:28,499 Stage-1 map = 100%,  reduce = 0%, Cumulative CPU 42.31 sec
2017-05-27 10:01:59,691 Stage-1 map = 100%,  reduce = 37%, Cumulative CPU 45.66 sec
2017-05-27 10:02:03,222 Stage-1 map = 100%,  reduce = 67%, Cumulative CPU 48.99 sec
2017-05-27 10:02:09,508 Stage-1 map = 100%,  reduce = 68%, Cumulative CPU 55.3 sec
2017-05-27 10:02:12,206 Stage-1 map = 100%,  reduce = 70%, Cumulative CPU 58.43 sec
2017-05-27 10:02:15,871 Stage-1 map = 100%,  reduce = 73%, Cumulative CPU 61.29 sec
2017-05-27 10:02:19,527 Stage-1 map = 100%,  reduce = 76%, Cumulative CPU 63.73 sec
2017-05-27 10:02:22,062 Stage-1 map = 100%,  reduce = 81%, Cumulative CPU 65.94 sec
2017-05-27 10:02:25,823 Stage-1 map = 100%,  reduce = 85%, Cumulative CPU 68.37 sec
2017-05-27 10:02:28,578 Stage-1 map = 100%,  reduce = 91%, Cumulative CPU 71.21 sec
2017-05-27 10:02:31,305 Stage-1 map = 100%,  reduce = 100%, Cumulative CPU 73.83 sec
MapReduce Total cumulative CPU time: 1 minutes 14 seconds 270 msec
Ended Job = job_1497230205272_0002
Launching Job 2 out of 2
Number of reduce tasks determined at compile time: 1
In order to change the average load for a reducer (in bytes):
  set hive.exec.reducers.bytes.per.reducer=<number>
In order to limit the maximum number of reducers:
  set hive.exec.reducers.max=<number>
In order to set a constant number of reducers:
  set mapreduce.job.reduces=<number>
Starting Job = job_1497230205272_0003, Tracking URL = http://master:8088/proxy/application_1497230205272_0003/
Kill Command = /usr/local/hadoop/bin/hadoop job  -kill job_1497230205272_0003
Hadoop job information for Stage-2: number of mappers: 1; number of reducers: 1
2017-05-27 10:03:35,369 Stage-2 map = 0%,  reduce = 0%
2017-05-27 10:04:29,803 Stage-2 map = 67%,  reduce = 0%, Cumulative CPU 20.71 sec
2017-05-27 10:04:31,116 Stage-2 map = 100%,  reduce = 0%, Cumulative CPU 22.18 sec
2017-05-27 10:05:02,786 Stage-2 map = 100%,  reduce = 64%, Cumulative CPU 26.26 sec
2017-05-27 10:05:05,145 Stage-2 map = 100%,  reduce = 67%, Cumulative CPU 28.23 sec
2017-05-27 10:05:14,814 Stage-2 map = 100%,  reduce = 69%, Cumulative CPU 36.22 sec
2017-05-27 10:05:18,459 Stage-2 map = 100%,  reduce = 73%, Cumulative CPU 39.26 sec
2017-05-27 10:05:21,043 Stage-2 map = 100%,  reduce = 76%, Cumulative CPU 39.26 sec
2017-05-27 10:05:24,507 Stage-2 map = 100%,  reduce = 87%, Cumulative CPU 45.15 sec
2017-05-27 10:05:26,873 Stage-2 map = 100%,  reduce = 100%, Cumulative CPU 46.67 sec
MapReduce Total cumulative CPU time: 46 seconds 670 msec
Ended Job = job_1497230205272_0003
Moving data to directory hdfs://master:9000/user/hive/warehouse/baidu_results
MapReduce Jobs Launched: 
Stage-Stage-1: Map: 1  Reduce: 1   Cumulative CPU: 74.27 sec   HDFS Read: 153363858 HDFS Write: 12654950 SUCCESS
Stage-Stage-2: Map: 1  Reduce: 1   Cumulative CPU: 46.67 sec   HDFS Read: 12659892 HDFS Write: 7454467 SUCCESS
Total MapReduce CPU Time Spent: 2 minutes 0 seconds 940 msec
OK
Time taken: 384.562 seconds
```

* 该任务被分块，分成了两个job

![png1](/img/20170527_1.png)

![png2](/img/20170527_2.png)

![png3](/img/20170527_3.png)


> 查询十大热搜排行榜

```bash
hive> select * from baidu_results limit 10;
OK
[哄抢救灾物资]	66906
[汶川地震原因]	58766
[封杀莎朗斯通]	12649
[广州军区司令员]	8661
[百度]	4958
[尼泊尔地图]	4886
[现役解放军中将名单]	4721
[公安部警卫局]	4275
[公安部通缉令名单]	3226
[吕秀莲到大陆]	3172
Time taken: 0.75 seconds, Fetched: 10 row(s)
```
