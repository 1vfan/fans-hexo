---
title: Spark RDD
date: 2017-08-19 21:43:01
tags:
- Spark
categories: 
- Spark
---

记录

<!--more-->

# Spark

```
Apache Spark™ is a fast and general engine for large-scale data processing.
Apache Spark is an open source cluster computing system that aims to make data analytics fast 
both fast to run and fast to wrtie
```

## 与MR对比

Spark比MR快的原因：

1. Spark基于内存迭代，MR基于磁盘迭代
2. Spark是粗粒度的资源调度 MR是细粒度的资源调度


## Spark的运行模式
local
standalone
yarn
mesos


## Spark任务执行流程

![png2](/img/Spark/Spark_task.png)

### Driver进程

Driver是一个JVM进程，其主要作用:

1. 分发任务task之前，调用RDD的一个方法获取每个partition的位置（最佳计算位置）
2. 将任务tasks分发到有数据的Worker节点上去（任务分发）
3. 将每个任务计算后的结果results拉回到Driver节点上（结果收集）

注意：在做大数据处理时，Driver进程中所有tasks的计算结果都会被拉取到JVM内存中，可能会造成OOM

### Worker进程

在集群中的这个节点上启动一个Worker进程，那么这个节点就是Worker节点，Worker节点所管理的资源是由集群中的配置文件中配置的.

启动Spark集群，只需要在Master节点上启动``start-all.sh``，会通过ssh协议连接其他节点，并在其他节点上各启动Worker进程，这些节点就成为了Worker节点；如果没有配置免密登陆，在启动的时候手动输入连接密码也是可以启动整个集群的.

如果原有Worker节点资源变更，需要重启该节点；而如果动态添加新的Worker节点，不需要更改配置文件，只需要在新的节点上执行以下命令:

```bash
# cd /usr/local/spark/sbin/
# ./start-slave.sh spark://spark1:7077
```

## Spark任务代码流程

先从分布式文件系统中加载RDD，然后通过一系列Transformations算子针对RDD的延迟操作，最后触发Actions算子执行tasks得到计算后的results.



## shuffle


shuffle过程中会有分区、排序、数据传输。

在shuffle的过程中，