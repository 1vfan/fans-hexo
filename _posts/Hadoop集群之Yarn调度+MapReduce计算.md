---
title: Hadoop集群之Yarn计算调度+Map/Reduce计算引擎
date: 2017-05-22 14:08:49
tags:
- Hadoop
- Linux
- Yarn
- MapReduce
- 集群
categories:
- Hadoop栈
---
记录Hadoop2.7.3集群中配置计算调度系统Yarn以及使用计算引擎Map/Reduce进行分布式计算 

<!--more-->

# 准备

* 点击下载-->[<font face="Times New Roman" color=#0099ff>Xshell5.0</font>](http://download.csdn.net/detail/weixin_37479489/9864277)

* 点击下载-->[<font face="Times New Roman" color=#0099ff>Hadoop2.7.3</font>](http://mirror.bit.edu.cn/apache/hadoop/common/hadoop-2.7.3/hadoop-2.7.3.tar.gz)

* 继承传送门-->[<font face="Times New Roman" color=#0099ff>Hadoop集群搭建指南</font>](https://1vfan.github.io/2017/05/14/Hadoop%E9%9B%86%E7%BE%A4%E4%B9%8BHDFS%E5%8D%8F%E8%AE%AE%E9%85%8D%E7%BD%AE/)

# 集群配置

## 配置计算调度系统Yarn

* Yarn作为Hadoop的计算调度系统，分为resourcemanager和nodemanager，resourcemanaegr管理调配nodemanager进行负载均衡计算
* resourcemanager和namenode类似可以不止一台，但resourcemanager不应该跟namenode在一台服务器上，两个都是相当耗费资源的，笔者是为了配置图方便
* nodemanager和datanode最好装在同一服务器上，如果不在一起，计算时拉取数据是相当笨重的过程，就算不在一台服务器上，也应该在同一机架上

> 配置yarn-env.sh

* 和hadoop-env.sh配置文件一样，如果虚拟机环境中未配置java环境变量，则所有站点虚拟机配置yarn-env.sh文件，修改JAVA_HOME值

```bash
# cd /usr/local/hadoop/etc/hadoop
# vim yarn-env.sh

修改
export JAVA_HOME=/usr/java/default
```

> 配置yarn-site.xml

* yarn-site如果是集中启动，其实只需要在管理机上配置一份即可；但是如果单独启动，需要每台机器一份，而且可以在网页上看到当前机器的配置，以及这个配置的来源


```bash
# cd /usr/local/hadoop/etc/hadoop
# vim yarn-site.xml 

添加
<configuration>
    <property>
        <name>yarn.resourcemanager.hostname</name>
        <value>master</value>
    </property>
 
    <property>  
        <name>yarn.nodemanager.aux-services</name>  
        <value>mapreduce_shuffle</value>  
    </property>  
 
    <property>
        <name>yarn.nodemanager.auxservices.mapreduce.shuffle.class</name>
        <value>org.apache.hadoop.mapred.ShuffleHandler</value>
    </property
</configuration>
```

> 集中启动验证

* 也可以使用yarn-daemon.sh单独启动resourcemanager和nodemanager

```bash
[root@master hadoop]# start-yarn.sh
starting yarn daemons
starting resourcemanager, logging to /usr/local/hadoop/logs/yarn-root-resourcemanager-master.out
slave2: starting nodemanager, logging to /usr/local/hadoop/logs/yarn-root-nodemanager-slave2.out
slave3: starting nodemanager, logging to /usr/local/hadoop/logs/yarn-root-nodemanager-slave3.out
slave1: starting nodemanager, logging to /usr/local/hadoop/logs/yarn-root-nodemanager-slave1.out
[root@master hadoop]# jps
2355 Jps
2287 ResourceManager

[root@slave1 hadoop]# jps
3775 Jps
3576 NodeManager
```

> 图形界面查看

* 可以通过hostname代替IP访问集群web界面

```bash
修改windows机上C:\Windows\System32\drivers\etc\hosts文件
新增
192.168.0.100 master
192.168.0.101 slave1
192.168.0.102 slave2
192.168.0.103 slave3

浏览器地址栏中输入
http://master:8088/ 观察yarn集群
```

![png1](/img/20170522_1.png)

## 配置计算引擎Map/Reduce

> 配置mapred-site.xml

* mapred-site.xml只需在管理机配置一份即可，但该文件本不存在，需要手动复制mapred-site.xml.template获得，注意：如果不使用mapred-site.xml，图形界面中job的计算情况并不会实时显示

```bash
[root@master ~]# cd /usr/local/hadoop/etc/hadoop
[root@master hadoop]# vim mapred-site.xml.template

添加
<configuration>
    <property>
        <name>mapreduce.framework.name</name>
        <value>yarn</value>
    </property>
</configuration>

[root@master hadoop]# cp mapred-site.xml.template mapred-site.xml
```

## Map/Reduce计算示例

> 使用Map/Reduce自带的案例程序wordcount计算并汇总测试文本中每个分词的数量

```bash
[root@master hadoop]# start-dfs.sh
[root@master hadoop]# start-yarn.sh
starting yarn daemons
starting resourcemanager, logging to /usr/local/hadoop/logs/yarn-root-resourcemanager-master.out
slave1: starting nodemanager, logging to /usr/local/hadoop/logs/yarn-root-nodemanager-slave1.out
slave3: starting nodemanager, logging to /usr/local/hadoop/logs/yarn-root-nodemanager-slave3.out
slave2: starting nodemanager, logging to /usr/local/hadoop/logs/yarn-root-nodemanager-slave2.out
[root@master hadoop]# jps
5766 Jps
5029 NameNode
5221 SecondaryNameNode
5695 ResourceManager
[root@master hadoop]# cd
[root@master ~]# vi input.txt
hello java
hello c
hello c++
hello java
hello java
hello node.js
hello js
hello python

[root@master ~]# hadoop fs -mkdir /mrinput
[root@master ~]# hadoop fs -put input.txt /mrinput/
[root@master ~]# hadoop fs -ls /mrinput
[root@master ~]# hadoop jar /usr/local/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-2.7.3.jar wordcount /mrinput/input.txt /mroutput
17/05/23 10:17:34 INFO client.RMProxy: Connecting to ResourceManager at master/192.168.0.100:8032
17/05/23 10:17:46 INFO input.FileInputFormat: Total input paths to process : 1
17/05/23 10:17:47 INFO mapreduce.JobSubmitter: number of splits:1
17/05/23 10:17:49 INFO mapreduce.JobSubmitter: Submitting tokens for job: job_1496974610444_0001
17/05/23 10:17:54 INFO impl.YarnClientImpl: Submitted application application_1496974610444_0001
17/05/23 10:17:55 INFO mapreduce.Job: The url to track the job: http://master:8088/proxy/application_1496974610444_0001/
17/05/23 10:17:55 INFO mapreduce.Job: Running job: job_1496974610444_0001
17/05/23 10:18:50 INFO mapreduce.Job: Job job_1496974610444_0001 running in uber mode : false
17/05/23 10:18:50 INFO mapreduce.Job:  map 0% reduce 0%
17/05/23 10:19:34 INFO mapreduce.Job:  map 100% reduce 0%
17/05/23 10:20:08 INFO mapreduce.Job:  map 100% reduce 100%
17/05/23 10:20:12 INFO mapreduce.Job: Job job_1496974610444_0001 completed successfully
17/05/23 10:20:14 INFO mapreduce.Job: Counters: 49
	File System Counters
		FILE: Number of bytes read=83
		FILE: Number of bytes written=237739
		FILE: Number of read operations=0
		FILE: Number of large read operations=0
		FILE: Number of write operations=0
		HDFS: Number of bytes read=188
		HDFS: Number of bytes written=49
		HDFS: Number of read operations=6
		HDFS: Number of large read operations=0
		HDFS: Number of write operations=2
	Job Counters 
		Launched map tasks=1
		Launched reduce tasks=1
		Data-local map tasks=1
		Total time spent by all maps in occupied slots (ms)=35447
		Total time spent by all reduces in occupied slots (ms)=31337
		Total time spent by all map tasks (ms)=35447
		Total time spent by all reduce tasks (ms)=31337
		Total vcore-milliseconds taken by all map tasks=35447
		Total vcore-milliseconds taken by all reduce tasks=31337
		Total megabyte-milliseconds taken by all map tasks=36297728
		Total megabyte-milliseconds taken by all reduce tasks=32089088
	Map-Reduce Framework
		Map input records=8
		Map output records=16
		Map output bytes=151
		Map output materialized bytes=83
		Input split bytes=101
		Combine input records=16
		Combine output records=7
		Reduce input groups=7
		Reduce shuffle bytes=83
		Reduce input records=7
		Reduce output records=7
		Spilled Records=14
		Shuffled Maps =1
		Failed Shuffles=0
		Merged Map outputs=1
		GC time elapsed (ms)=822
		CPU time spent (ms)=8030
		Physical memory (bytes) snapshot=301547520
		Virtual memory (bytes) snapshot=4157239296
		Total committed heap usage (bytes)=165810176
	Shuffle Errors
		BAD_ID=0
		CONNECTION=0
		IO_ERROR=0
		WRONG_LENGTH=0
		WRONG_MAP=0
		WRONG_REDUCE=0
	File Input Format Counters 
		Bytes Read=87
	File Output Format Counters 
		Bytes Written=49
```

> 计算过程中，可在web界面 http://master:8088 查看计算情况

* Running

![png2](/img/20170522_2.png)

* Finished

![png3](/img/20170522_3.png)

> 计算完成，打开web界面 http://master:50070 查看计算结果

![png4](/img/20170522_4.png)

```bash
[root@master ~]# hadoop fs -text /mroutput/part-r-00000
c	1
c++	1
hello	8
java	3
js	1
node.js	1
python	1
```

## 异常汇总

> 出现如下警告，是因为快速读取文件的时候文件被关闭引起，也可能是其他bug导致，之后再没出现，可忽略

```bash
17/05/23 00:42:35 WARN io.ReadaheadPool: Failed readahead on ifile
EBADF: Bad file descriptor
	at org.apache.hadoop.io.nativeio.NativeIO$POSIX.posix_fadvise(Native Method)
	at org.apache.hadoop.io.nativeio.NativeIO$POSIX.posixFadviseIfPossible(NativeIO.java:267)
	at org.apache.hadoop.io.nativeio.NativeIO$POSIX$CacheManipulator.posixFadviseIfPossible(NativeIO.java:146)
	at org.apache.hadoop.io.ReadaheadPool$ReadaheadRequestImpl.run(ReadaheadPool.java:206)
	at java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1142)
	at java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:617)
	at java.lang.Thread.run(Thread.java:745)

17/05/23 00:42:36 INFO mapreduce.Job:  map 100% reduce 100%
17/05/23 00:42:36 INFO mapreduce.Job: Job job_local2045328696_0001 completed successfully
```

> nodemanager自动关闭，笔者在正确完成对yarn的配置后便恢复正常

* 正确配置了yarn-env.sh中的JAVA_HOME
* 在每台站点虚拟机上都正确配置了yarn-site.xml

```bash
[root@master ~]# stop-yarn.sh
stopping yarn daemons
stopping resourcemanager
slave3: stopping nodemanager
slave2: no nodemanager to stop
slave1: no nodemanager to stop
slave3: nodemanager did not stop gracefully after 5 seconds: killing with kill -9
no proxyserver to stop
```

