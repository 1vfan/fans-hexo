---
title: Hadoop集群之datanode启动后自动关闭异常
date: 2017-05-16 21:11:20
tags:
- Hadoop
- Linux
- 集群
categories: 
- Hadoop栈
---
记录Hadoop集群中datanode启动后过一会又自动关闭的异常情况

<!--more-->

# 异常描述

> 分别启动Hadoop的namenode和datanode后,过一会datanode会自动关闭

# 原因查找
 
 > 查看日志后发现，namenode clusterID 和 datanode clusterID不一致，分别进入namenode 和 datanode的VERSION中检查确实是clusterID不一致

* namenode服务器

```
# cd /tmp/hadoop-root/dfs/name/current
# vim VERSION
```

* datanode服务器

```
# cd /tmp/hadoop-root/dfs/data/current
# vim VERSION
```

 # 原因分析

 > 每次格式化hadoop namenode -format时会重新创建一个namenodeId,而/tmp/hadoop-root/dfs/data下包含了上次format下的id,hadoop namenode -format清空了namenode下的数据,但是没有清空datanode下的数据,所以重新格式化后会造成namenode节点上的clusterID与datanode节点上的clusterID不一致，启动后会自动关闭

 # 解决方案

 > 修改namenode clusterID

在namenode和datanode服务器的/tmp/hadoop-root/dfs目录下，分别有name和data，里面有个VERSION存着clusterID,因为datanode有时数量庞大，修改datanode中的clusterID太过繁琐，所以修改namenode的clusterID

* 修改前

![png1](/img/20170602_1.png)

* 修改后

![png2](/img/20170602_2.png)

# 运行测试

* datanode服务器

```
# hadoop-daemon.sh start datanode
# jps
```

* namenode服务器

```
# hadoop-daemon.sh start namenode
# jps
# hdfs dfsadmin -report | more
```

* 运行成功

![png3](/img/20170602_3.png)

# 结论

> 每次在重新格式化hadoop namenode -fotmat前，需要清空datanode服务器中的/tmp/hadoop-root/dfs/data所有目录的数据，但是由于hadoop默认存储数据的tmp目录是linux的垃圾数据存储位置，所以后期需要我们手动的在core-site.xml修改配置数据存储位置
