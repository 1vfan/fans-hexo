---
title: Spark集群环境搭建与测试
date: 2017-10-12 19:43:01
tags:
- Spark
- Hadoop
- HDFS
- Linux
categories: 
- Spark
---

记录搭建一套1台Master2台Worker节点的Spark集群环境并测试

<!--more-->

基础配置参考之前的Hadoop的配置

## 节点规划

|HostName|Spark Node|IP|HDFS Node|
|---|---|---|---|
|spark1|Master|158.222.154.60|NameNode/DataNode|
|spark2|Worker|158.222.154.61|DataNode|
|spark3|Worker|158.222.154.62|DataNode|


## 解压

将Spark安装包 `spark-1.6.0-bin-hadoop2.6.tgz` 上传到spark1节点 `/usr/local/software/` 路径下

```bash
# cd /usr/local/software/
# tar -zxvf spark-1.6.0-bin-hadoop2.6.tgz
# mv spark-1.6.0-bin-hadoop2.6.tgz ..
# cd ..
# mv spark-1.6.0-bin-hadoop2.6.tgz spark
```

## PATH

在 `.bashrc` 或 `/etc/profile` 中添加spark的环境变量

```bash
# cd
# vim .bashrc

or

# vim /etc/profile
JAVA_HOME=/usr/local/jdk1.8
JRE_HOME=$JAVA_HOME/jre
ZOOKEEPER_HOME=/usr/local/zookeeper
HADOOP_HOME=/usr/local/hadoop
HBASE_HOME=/usr/local/hbase
SPARK_HOME=/usr/local/spark
CLASS_PATH=.:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar:$JRE_HOME/lib
PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin:$HBASE_HOME/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$ZOOKEEPER_HOME/bin:$JAVA_HOME/bin:$JRE_HOME/bin
export SPARK_HOME HBASE_HOME HADOOP_HOME ZOOKEEPER_HOME JAVA_HOME JRE_HOME CLASS_PATH PATH

# source /etc/profile
```

## 配置

1. slaves: 配置从节点的ip或hostname

```bash
# cd /usr/local/spark/conf/
# mv slaves.template slaves
# vim slaves
spark2
spark3
```

2. spark-env.sh: 配置环境参数

```bash
# cd /usr/local/spark/conf/
# mv spark-env.sh.template spark-env.sh
# vim spark-env.sh

#声明spark1是Master节点
export SPARK_MASTER_IP=spark1
#声明提交Application的端口
export SPARK_MASTER_PORT=7077
#默认WebUI端口是8080可能会与tomcat冲突，修改为8888
export SPARK_MASTER_WEBUI_PORT=8888
#每一个Worker节点管理2G内存，不是指每一个Worker进程使用2G内存
export SPARK_WORKER_MEMORY=2g
#每一个Worker节点管理3个core，不是指每一个Worker进程使用3个core
export SPARK_WORKER_CORES=3
```

3. start-spark.sh: 改名start-all.sh

由于Hadoop和Spark都配置了Path，都有start-all.sh命令会冲突，改成start-spark.sh也更有辨识度.

```bash
# cd /usr/local/spark/sbin/
# mv start-all.sh start-spark.sh
# mv stop-all.sh stop-spark.sh
```

## 同步其他节点
 
将配置好的spark安装包同步到其他的节点上

```bash
# cd /usr/local/
# scp spark root@spark2:/usr/local/
# scp spark root@spark3:/usr/local/
```

## 启动测试

在安装Spark之前，HDFS已经配置完成，在spark1节点上启动整个HDFS集群和Spark集群.

### 启动

```bash
[root@spark1 /]# start-dfs.sh
Starting namenodes on [spark1]
spark1: starting namenode, logging to /usr/local/hadoop/logs/hadoop-root-namenode-spark1.out
spark1: starting datanode, logging to /usr/local/hadoop/logs/hadoop-root-datanode-spark1.out
spark2: starting datanode, logging to /usr/local/hadoop/logs/hadoop-root-datanode-spark2.out
spark3: starting datanode, logging to /usr/local/hadoop/logs/hadoop-root-datanode-spark3.out
Starting secondary namenodes [0.0.0.0]
0.0.0.0: starting secondarynamenode, logging to /usr/local/hadoop/logs/hadoop-root-secondarynamenode-spark1.out

[root@spark1 /]# start-spark.sh
starting org.apache.spark.deploy.master.Master, logging to /usr/local/spark/logs/spark-root-org.apache.spark.deploy.master.Master-1-spark1.out
spark2: starting org.apache.spark.deploy.worker.Worker, logging to /usr/local/spark/logs/spark-root-org.apache.spark.deploy.worker.Worker-1-spark2.out
spark3: starting org.apache.spark.deploy.worker.Worker, logging to /usr/local/spark/logs/spark-root-org.apache.spark.deploy.worker.Worker-1-spark3.out
```

### jps

```bash
[root@spark1 /]# jps
8870 Jps
7769 Master
8407 NameNode
8712 SecondaryNameNode
8527 DataNode

[root@spark2 /]# jps
4113 Jps
3855 Worker
4025 DataNode

[root@spark3 /]# jps
4104 Jps
3862 Worker
4018 DataNode
```

### webUI界面查看

在浏览器中打开 `spark1:8888` 页面查看Spark集群的运行情况

http://192.168.154.60:8888

修改webUI端口的两种方法：

1. 在 ``spark/conf/spark-env.sh`` 中添加 ``export SPARK_MASTER_WEBUI_PORT=8888`` 定义新端口.

2. 在 ``spark/sbin/start-master.sh`` 中修改 ``SPARK_MASTER_WEBUI_PORT=8080`` 为8888.

## Spark集群运行jar包

案例: 将一堆log数据中地名重复最高的所有记录去除

### 代码逻辑

```java
package com.stefan.spark

import org.apache.spark.SparkConf
import org.apache.spark.SparkContext

object FilterCount {
    def main(args: Array[String]): Unit = {
        val conf = new SparkConf().setAppName("FilterCountApp")
        val sc = new SparkContext(conf)

        val lineRDD = sc.textFile("hdfs://hbase1:9000/input/log.txt")
        val mapRDD = lineRDD.map(x => x.split(" ")(1))
        val countRDD = mapRDD.map((word=>(word, 1)))
        val reduceRDD = countRDD.reduceByKey((x,y) => x+y)
        val swapRDD = reduceRDD.map(x => x.swap)
        val sortRDD = swapRDD.sortByKey(false)

        val arr = sortRDD.take(1)
        val name = arr(0)._2

        val filterRDD = lineRDD.filter(x => {
            !name.equals(x.split(" ")(1))
        })
        filterRDD.foreach(x => println(x))
        filterRDD.saveAsTextFile("hdfs://hbase1:9000/output/result")

        sc.stop()   
    }
}
```

### 日志数据

```txt
2017-10-11 浙江杭州 3301
2017-10-12 浙江宁波 3302
2017-10-13 浙江衢州 3303
2017-10-14 浙江丽水 3304
2017-10-15 浙江台州 3305
2017-10-16 浙江金华 3306
2017-10-17 浙江温州 3307
2017-10-18 浙江舟山 3308
2017-10-19 浙江临安 3309
2017-10-20 浙江杭州 3310
2017-10-21 浙江临安 3309
2017-10-22 浙江杭州 3311
2017-10-23 浙江台州 3305
2017-10-24 浙江杭州 3312
2017-10-25 浙江杭州 3312
2017-10-26 浙江衢州 3303
2017-10-27 浙江杭州 3312
2017-10-28 浙江宁波 3302
2017-10-29 浙江杭州 3312
2017-10-30 浙江金华 3306
2017-11-01 浙江杭州 3312
2017-11-02 浙江温州 3307
```

### 集群运行

将log.txt上传到spark1节点 /usr/local/software/ ，存储到HDFS集群中.

```bash
# cd /usr/local/software/
# hdfs dfs -mkdir /input
# hdfs dfs -put log.txt /input/
# hdfs dfs -mkdir /output
```

将scala代码打成jar包 ``fc.jar`` 上传到spark1节点的 ``/usr/local/spark/lib/`` 目录下，在spark1节点上提交Application的命令，利用Spark集群运行代码逻辑处理日志数据.

```bash
# cd /usr/local/bin/
# ./spark-submit --master spark://spark1:7077 --class com.stefan.spark.FilterCount ../lib/fc.jar
```

Spark webUI界面 http://192.168.154.60:8888 查看job执行情况；执行完成之后在HDFS中查看处理结果.

```bash
# hdfs dfs -ls /output/result/
Found 3 items
-rw-r--r--   3 root supergroup     0 2017-10-12 21:52 /output/result/_SUCCESS
-rw-r--r--   3 root supergroup   261 2017-10-12 21:52 /output/result/part-00000
-rw-r--r--   3 root supergroup   145 2017-10-12 21:52 /output/result/part-00001

# hdfs dfs -cat /output/result/part-00000
2017-10-12 浙江宁波 3302
2017-10-13 浙江衢州 3303
2017-10-14 浙江丽水 3304
2017-10-15 浙江台州 3305
2017-10-16 浙江金华 3306
2017-10-17 浙江温州 3307
2017-10-18 浙江舟山 3308
2017-10-19 浙江临安 3309
2017-10-21 浙江临安 3309

# hdfs dfs -cat /output/result/part-00001
2017-10-23 浙江台州 3305
2017-10-26 浙江衢州 3303
2017-10-28 浙江宁波 3302
2017-10-30 浙江金华 3306
2017-11-02 浙江温州 3307
```

对比可以发现：在log.txt中地名重复最高的 ``浙江杭州`` 的所有记录都已经被清除了.

### 存在的问题

上面的测试中，是在spark1节点提交application ``fc.jar`` 到spark集群中运行的，即把spark1节点当作了spark客户端.

这样做的问题在于：以后使用spark1作为客户端频繁地提交application，在提交的过程中会对spark1节点的磁盘IO造成压力，导致spark1节点的服务器性能下降，与集群中其他节点的性能产生差异，而application的执行时间是由集群中性能最差的服务器节点决定的，因此有必要搭建一个spark客户端.


