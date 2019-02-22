
# 特性

RDD（Resilient Distributed Dataset 弹性的分布式数据集）

```
-A list of partitions

RDD是由一系列的partition组成的（默认情况partition的个数=split数）

-A function for computing each partitions

每一个算子或者说函数实质上是作用在每一个partition上

-A list of dependencies on other RDDs

RDD是有一系列的依赖关系：有利于计算的容错（宽依赖、窄依赖）

-Optionally, a Partitioner for key-value RDDs

可选项：分区器作用在KV格式的RDD上（分区器：决定每一条结果写入到哪一个分区中，在shuffle的时候分区；KV格式的RDD：RDD中的数据是二元组对象）

-Optionally, a list of preferred locations to compute each split on

可选项：RDD会提供一系列的最佳计算位置，用于分发task，有利于task计算的数据本地化，符合大数据的计算原则（计算通过task移动，数据不移动）
```

![png1](/img/Spark/Spark_RDD.png)

注意：RDD中不存储数据，只存储指向HDFS中block块数据的指针

RDD虽然叫分布式数据集（但只是一个抽象概念），RDD内部并不存储数据，实际储存的是计算逻辑.


# SparkConf

SparkConf是设置Spark运行时的环境变量，还可以设置Spark运行时所需要的资源情况.

```java
val conf = new SparkConf()
            .setMaster("local")
            .setAppName("Name")
```

# SparkContext

通过传入SparkConf创建一个SparkCotext，SparkContext是通往集群的唯一通道（发送task、接收运行时信息和计算结果），同时在SparkContext初始化的时候会创建任务调度器DAGScheduler、TaskScheduler.

> 注意：RDD中不可以嵌套RDD

通过源码发现action类算子执行的底层都是由SparkContext上下文对象调用runJob()方法，因为SparkContext对象存在与Driver端，当外部RDD计算逻辑被发送到Executor端执行时，内部嵌套的RDD由于Executor端缺少sc对象无法被触发执行.

```java
def count(): Long = sc.runJob(this, Utils.getIteratorSize _).sum
```
但是在本地开发的eclipse环境中可以实现，因为本地环境Driver与Executor进程存在于同一JVM进程中，可以获取sc对象；在集群中就会出错.

# 转换算子

Transformations类算子返回值类型是一个RDD，属于延迟执行算子，当它遇到Actions类算子才会真正执行.

## textFile、makeRDD、parallelize

如果是从HDFS上读数据:block<2，默认partition=2；block>=2，partition=block.


## map、flatMap

map: 输入一条数据则输出一条数据
（Java API 中也有map算子: 如果返回非KV格式RDD使用map算子，如果返回KV格式RDD使用mapToPair算子）

flatMap: 输入一条数据可输出N条数据（N>=0）

## mapValues

对KV型RDD的value做map操作.

```java
val rdd: RDD[(String,Int)] = sc.makeRDD(List(("stefan1",20),("stefan2",24)))
rdd.mapValues(_+2).foreach(println)
```

## filter

filter一个过滤算子（input:一条记录；output:boolean），通过我们传进去的匿名函数来判断每一条记录是否满足我们的要求，返回true就是满足那么他不会被过滤掉，返回false则该条记录会被过滤掉.

## distinct

distinct算子是一个去重算子（map+reduceByKey+map）

```java
val rdd: RDD[(String,String)] = sc.makeRDD(List[(1,"stefan1"),(2,"stefan2"),(2,"stefan2")]) 
rdd.distinct().foreach(println)
```

## groupByKey

```java
val arr = Array((1,"stefan1"),(1,"stefan2"),(2,"stefan3"))
val rdd = sc.parallelize(arr)
val result = rdd.groupByKey()
result.foreach(x => {
    print(x._1 + " : ")
    x._2.foreach(y => print(y + " "))
    println()
})
```

## reduceByKey

根据key分组，每一个key对应的所有value根据用户传入的聚合逻辑进行聚合成一个value.

```java
val arr = Array((1,30),(1,40),(2,50),(3,20),(3,10))
val rdd = sc.parallelize(arr)
val result = rdd.reduceByKey(_+_)
result.foreach(x => {
    println(x._1 + " : " + x._2)
})
```

## sortBy

sortBy: 可以指定按某一个字段进行排序

sortByKey: 根据key值大小进行排序，默认升序

```java
val arr = Array((10,"s1"),(20,"s2"),(30,"s3"))
val rdd = sc.parallelize(arr)
rdd.sortBy(_._1, false).foreach(println)
```

## join

> 内连接

注意：join算子只适用于KV格式的RDD之间的join，附带的信息可以以元组的格式存储在value中.

```java
object Join {
  def main(args: Array[String]): Unit = {
    val conf = new SparkConf().setAppName("Join").setMaster("local[1]")
    val sc = new SparkContext(conf)

    val nameList: List[(Int,(String,Int))] = List((1,("stefan1",21)),(2,("stefan2",19)),(3,("stefan3",21)),(4,("stefan4",20)))
    val scoreList: List[(Int,(String,Int))] = List((1,("English",98)),(2,("math",100)),(3,("Chinese",60)),(3,("math",80)),(5,("English",0)))

    val nameRDD = sc.makeRDD(nameList, 3)
    val scoreRDD = sc.parallelize(scoreList, 3)

    val joinRDD = nameRDD.join(scoreRDD)

    joinRDD.foreach(x=> {
      println("编号:" + x._1 + 
              ", 学生:" + x._2._1._1 + 
              ", 年龄:" + x._2._1._2 + 
              ", 学科:" + x._2._2._1 + 
              "，成绩:" + x._2._2._2)
    })
  }
}
```

结果打印：

```bash
编号:1, 学生:stefan1, 年龄:21, 学科:English，成绩:98
编号:2, 学生:stefan2, 年龄:19, 学科:math，成绩:100
编号:3, 学生:stefan3, 年龄:21, 学科:Chinese，成绩:60
编号:3, 学生:stefan3, 年龄:21, 学科:math，成绩:80
```

> 外连接

包括外连接fullOuterJoin、左外连接leftOuterJoin、右外连接rightOuterJoin，注意外连接中返回Option[(String,Int)]类型对应的Some("xxx",1)数据需要通过get转换再取值.

```java
//左外连接
val leftOuterJoinRDD: RDD[(Int,((String,Int),Option[(String,Int)]))] = nameRDD.leftOuterJoin(scoreRDD)

leftOuterJoinRDD.foreach(x=>{
    val prefix = "编号:" + x._1 + ", 学生:" + x._2._1._1 + ", 年龄:" + x._2._1._2
    if(x._2._2 != None){
        println(prefix + 
                ", 学科:" + x._2._2.get._1 + "，成绩:" + x._2._2.get._2)
    }else{
        println(prefix + "，无成绩")
    }
})
```

结果打印：

```bash
编号:1, 学生:stefan1, 年龄:21, 学科:English，成绩:98
编号:2, 学生:stefan2, 年龄:19, 学科:math，成绩:100
编号:3, 学生:stefan3, 年龄:21, 学科:Chinese，成绩:60
编号:3, 学生:stefan3, 年龄:21, 学科:math，成绩:80
编号:4, 学生:stefan4, 年龄:20，无成绩
```

## union

union的RDD类型必须一致.

```java
val rdd1: RDD[String] = sc.makeRDD(Array("a","b","c"))
val rdd2: RDD[String] = sc.makeRDD(Array("d","e","f"))

val unionRDD = rdd1.union(rdd2)
val result: String = unionRDD.reduce(_+_)
println(result)  //abcdef
```

## sample

1. 传入boolean参数，代表抽样方式

2. 抽样的比例

3. 随机算法的初始值

```java
val arr = Array("s1","s2","s3","s4","s5","s6","s7","s8","s9")
val rdd = sc.parallelize(arr)
rdd.sample(false,0.5,100).foreach(println)
```

## 分区

在重分区的过程中：如果想要增加RDD的分区数，那么必须发生shuffle，使用repartition算子或者coalesce(partitions, true)算子；如果减少RDD的分区数，可产生也可不产生shuffle（一般增加分区直接使用repartition算子，减少使用coalesce(partitions,false)）.

### repartition

repartition算子可以改变RDD的分区数，因此可以提高并行度（task数）. ``getNumPartitions``与``partitions.size``作用一致，都是获取当前RDD的分区数.

```java
val lineRDD = sc.textFile("log.txt", 2)
println("partitions: " + lineRDD.getNumPartitions)  //2
val repartitionRDD = lineRDD.repartition(3)
println("partitions: " + repartitionRDD.partitions.size)  //3
```

### coalesce

repartition算子底层就是封装的coalesce算子，``coalesce(3,true)``就相当于``repartition(3)``.

```java
//true代表在重分区的过程中产生shuffle
val repartitionRDD = lineRDD.coalesce(3, true)
```

注意：如果使用coalesce(partitions,false)以增加分区数，那么新产生的RDD不会增加分区，分区数及每个分区中的数据与原RDD中保持一直，因为不产生shuffle.

### mapPartitionWithIndex

在遍历每一个partition的时候，可以获取到该partition的ID，主要用于测试.

```java
repartitionRDD.mapPartitionsWithIndex((index, iterator) => {
    println("repartitionID: " + index)
    while(iterator.hasNext){
        val value = iterator.next
        println("iteratorValue: " + value)
    }
    iterator
}, false).count()
```

```bash
repartitionID: 0
iteratorValue: 2017-10-16 浙江金华 3306
iteratorValue: 2017-10-24 浙江杭州 3312
iteratorValue: 2017-10-30 浙江金华 3306

repartitionID: 1
iteratorValue: 2017-10-24 浙江杭州 3312

repartitionID: 2
iteratorValue: 2017-10-16 浙江金华 3306
iteratorValue: 2017-10-30 浙江金华 3306
```

### mapPartitions

1. map与mapPartitions同作为遍历算子，map能够遍历一个RDD中每一个元素，遍历的单位是每条记录；而mapPartitions遍历的单位是一个RDD的其中一个partition，在遍历之前它会将当前partition的数据加载到内存中，因此mapPartitions遍历RDD的效率更高.

2. mapPartitions算子占用内存多，如果一个partition的计算结果非常非常大可能会造成OOM，此时需要使用repartition算子来提高这个RDD的分区数，那么每一个partition的计算结果就减少了很多.

3. mapPartitions算子的使用场景: 一般在将一个RDD的计算结果写入到数据库中（redis mysql oracle），会使用mapPartition这个算子；而在map中需要每次都创建数据库连接所以不适用.

```java
repartitionRDD.mapPartitions((iterator) => {
    //创建一个数据库连接
    while(iterator.hasNext) {
    val value = iterator.next()
        //拼接SQL语句
    }
    //批量插入
    iterator
}, false)  //false代表新产成的RDD不继承当前RDD的分区信息
```

# 行动算子

Actions类算子返回值类型是非RDD，会立即触发执行；Application程序中存在多少Action类算子，就需要执行相应数量的job.

## count    

统计RDD中的记录数

## foreach

会将传入的函数``foreach(println)``推到Worker节点的Executor进程中执行，并不会将结果拉回到客户端的Driver进程中，因此不会在spark-shell的窗口中查看到打印结果.

## foreachPartition

与foreach的区别：遍历的单位为position，会先将当前的position数据缓存到内存中.

## reduce

```java
val arr = Array(1,2,3,4,5)
val rdd = sc.parallelize(arr)
val sum: Int = rdd.reduce(_+_)
println(sum)
```

## collect
使用collect算子触发job的执行，会将task计算的结果从Executor端拉回到客户端的Driver进程中的（即JVM内存中），所以collect算子要慎用避免OOM，一般测试使用.

## countByKey

与reduceByKey不同，countByKey不需要传入聚合逻辑，直接对组内的数据进行统计结果

## saveAsTextFile

将RDD计算结果写入到HDFS或本地磁盘中

## take

取出前4位的元素

```java
val rdd = sc.makeRDD(Array("a","b","c","d","e","f"))
val results = rdd.take(4)
for(result <- results) {
    println(result)
}
```


# 控制类算子

> cache

cache算子是一个懒执行算子，需要由action类算子触发执行；

执行完cache算子后返回值必须复制给一个变量，在接下来的job中使用该变量执行算子，那么就读取到内存中的缓存数据了；

如果想释放内存中的缓存数据，可以使用unpersist方法，这是一个立即执行的算子；

注意在cache执行的当前job中，其他算子计算的数据依然来自HDFS磁盘读取，当action类算子执行（即当前job执行完成），数据才真正缓存在内存中；

同时cache算子后不能紧跟action类算子（如rdd.cache().count()），这样返回值就是非rdd类型的对象，在接下来的job中使用该对象就无法读取内存中的缓存数据了.

```java
package com.stefan.spark

import org.apache.spark.SparkConf
import org.apache.spark.SparkContext

object CacheCount {

  def main(args: Array[String]): Unit = {

    //创建Spark运行时的配置对象，可配置应用名、集群URL及运行时各种资源需求
    val conf = new SparkConf().setAppName("CacheCountApp")
    //通过传入配置对象，实例化一个Spark上下文环境对象
    val sc = new SparkContext(conf)
    var cacheRDD = sc.textFile("hdfs://spark1:9000/input/log.txt")

    val startTime1 = System.currentTimeMillis()
    val count1 = cacheRDD.count()
    val endTime1 = System.currentTimeMillis()
    println("count1: " + count1 + " ----> time: " + (endTime1 - startTime1))

    val startTime2 = System.currentTimeMillis()
    cacheRDD = cacheRDD.cache()
    val count2 = cacheRDD.count()
    val endTime2 = System.currentTimeMillis()
    println("count2: " + count2 + " ----> time: " + (endTime2 - startTime2))

    val startTime3 = System.currentTimeMillis()
    val count3 = cacheRDD.count()
    val endTime3 = System.currentTimeMillis()
    println("count3: " + count3 + " ----> time: " + (endTime3 - startTime3))

    cacheRDD = cacheRDD.unpersist()

    val startTime4 = System.currentTimeMillis()
    val count4 = cacheRDD.count()
    val endTime4 = System.currentTimeMillis()
    println("count4: " + count4 + " ----> time: " + (endTime4 - startTime4))
  }
}
```

每个actionl类算子就等同于一个job，而RDD中是不存储数据的. job0会根据RDD依赖关系从HDFS磁盘中load数据；job1中虽然使用cache算子，但cache算子只能通过action类算子触发才能执行，所以job1中依然是从HDFS中load数据；在job1执行后，数据就真正缓存到了内存中，因此job2只需要计算内存中数据即可，可通过webUI界面查；job3是执行了unpersist算子后释放了在集群内存中的缓存，因此还是从HDFS磁盘中取数据.


```bash
[root@sparkcli bin]# ./spark-submit --master spark://spark1:7077 ../lib/CacheCount.jar
Using Spark's default log4j profile: org/apache/spark/log4j-defaults.properties
17/12/15 15:22:03 INFO SparkContext: Starting job: count at CacheCount.scala:21
17/12/15 15:22:04 INFO DAGScheduler: Got job 0 (count at CacheCount.scala:21) with 2 output partitions
17/12/15 15:22:04 INFO DAGScheduler: Final stage: ResultStage 0 (count at CacheCount.scala:21) 
17/12/15 15:22:58 INFO DAGScheduler: ResultStage 0 (count at CacheCount.scala:21) finished in 53.943 s
17/12/15 15:22:58 INFO DAGScheduler: Job 0 finished: count at CacheCount.scala:21, took 54.752578 s
count1: 22 ----> time: 60600
17/12/15 15:22:58 INFO SparkContext: Starting job: count at CacheCount.scala:28
17/12/15 15:22:58 INFO DAGScheduler: Got job 1 (count at CacheCount.scala:28) with 2 output partitions
17/12/15 15:22:58 INFO DAGScheduler: Final stage: ResultStage 1 (count at CacheCount.scala:28)
17/12/15 15:23:08 INFO DAGScheduler: ResultStage 1 (count at CacheCount.scala:28) finished in 9.461 s
17/12/15 15:23:08 INFO DAGScheduler: Job 1 finished: count at CacheCount.scala:28, took 9.561521 s
count2: 22 ----> time: 9572
17/12/15 15:23:08 INFO SparkContext: Starting job: count at CacheCount.scala:33
17/12/15 15:23:08 INFO DAGScheduler: Got job 2 (count at CacheCount.scala:33) with 2 output partitions
17/12/15 15:23:08 INFO DAGScheduler: Final stage: ResultStage 2 (count at CacheCount.scala:33)
17/12/15 15:23:12 INFO DAGScheduler: ResultStage 2 (count at CacheCount.scala:33) finished in 4.754 s
17/12/15 15:23:12 INFO TaskSchedulerImpl: Removed TaskSet 2.0, whose tasks have all completed, from pool 
17/12/15 15:23:12 INFO DAGScheduler: Job 2 finished: count at CacheCount.scala:33, took 4.815121 s
count3: 22 ----> time: 4821 
17/12/15 15:23:12 INFO MapPartitionsRDD: Removing RDD 1 from persistence list
17/12/15 15:23:13 INFO BlockManager: Removing RDD 1
17/12/15 15:23:13 INFO SparkContext: Starting job: count at CacheCount.scala:41
17/12/15 15:23:13 INFO DAGScheduler: Got job 3 (count at CacheCount.scala:41) with 2 output partitions
17/12/15 15:23:13 INFO DAGScheduler: Final stage: ResultStage 3 (count at CacheCount.scala:41) 
17/12/15 15:23:13 INFO DAGScheduler: ResultStage 3 (count at CacheCount.scala:41) finished in 0.245 s
17/12/15 15:23:13 INFO DAGScheduler: Job 3 finished: count at CacheCount.scala:41, took 0.310364 s
count4: 22 ----> time: 316
```

在spark源码包``package org.apache.spark.rdd``中发现cache算子等同于无参构造的persist算子，默认``StorageLevel=MEMORY_ONLY``.

```java
/** Persist this RDD with the default storage level (`MEMORY_ONLY`). */
def cache(): this.type = persist()
def persist(): this.type = persist(StorageLevel.MEMORY_ONLY)
```

> persist

在Spark中持久化的单位是partition，所以计算结果要么在内存中，要么在磁盘中（不会出现数据比较大，内存空间不足，导致内存和磁盘各存一部分的情况）.

```java
class StorageLevel private(
    private var _useDisk: Boolean,       //磁盘
    private var _useMemory: Boolean,     //内存
    private var _useOffHeap: Boolean,    //堆外内存
    private var _deserialized: Boolean,  //不序列化
    private var _replication: Int = 1)   //备份的数量
}

//静态
object StorageLevel {
    //只序列化
    val NONE = new StorageLevel(false, false, false, false)
    //RDD计算结果写入磁盘中
    val DISK_ONLY = new StorageLevel(true, false, false, false)
    val DISK_ONLY_2 = new StorageLevel(true, false, false, false, 2)
    //RDD计算结果写入内存中
    val MEMORY_ONLY = new StorageLevel(false, true, false, true)
    val MEMORY_ONLY_2 = new StorageLevel(false, true, false, true, 2)
    //先序列化再存到内存
    val MEMORY_ONLY_SER = new StorageLevel(false, true, false, false)
    val MEMORY_ONLY_SER_2 = new StorageLevel(false, true, false, false, 2)
    //RDD计算结果先放入内存中，若内存中放不下则写入磁盘中
    val MEMORY_AND_DISK = new StorageLevel(true, true, false, true)
    val MEMORY_AND_DISK_2 = new StorageLevel(true, true, false, true, 2)
    val MEMORY_AND_DISK_SER = new StorageLevel(true, true, false, false)
    val MEMORY_AND_DISK_SER_2 = new StorageLevel(true, true, false, false, 2)
    val OFF_HEAP = new StorageLevel(false, false, true, false)
}
```

> checkpoint

控制算子
    cache
    persist
    checkpoint
执行流程
    1、当RDD的job（由action类算子触发的job）执行完成后，会从finalRDD从后往前回溯
    2、当回溯到某一个RDD的时候，发现这个RDD调用了checkpoint方法，那么会将这个RDD做一个标记
    3、标记做完后，Spark会重新启动一个新的job(重新计算这个RDD的结果，然后将计算结果持久化到HDFS上)
    4、优化方案：对哪一个RDD调用checkpoint之前，最好先cache一下
使用方法
    1、设置checkpoint的目录  sc.setCheckpointDir("d:/checkpoint")
    2、哪一个RDD要进行checkpoint，直接调用checkpoint()方法就可以   rdd.checkpoint()



# 高性能算子

Shuffle 分开两部份，一个是 Mapper 端的Shuffle，另外一个就是 Reducer端的 Shuffle，
性能调优有一个很重要的总结就是尽量不使用 Shuffle 类的算子，我们能避免就尽量避免，因为一般进行 Shuffle 的时候，它会把集群中多个节点上的同一个 Key 汇聚在同一个节点上，
例如 reduceByKey。然后会优先把结果数据放在内存中，但如果内存不够的话会放到磁盘上。
Shuffle 在进行数据抓取之前，为了整个集群的稳定性，它的 Mapper 端会把数据写到本地文件系统。这可能会导致大量磁盘文件的操作。

如何避免Shuffle可以考虑以下：

1. 采用 Map 端的 Join (RDD1 + RDD2 )先把一个 RDD1的数据收集过来，然后再通过 sc.broadcast( ) 把数据广播到 Executor 上；

2. 如果无法避免Shuffle，退而求其次就是需要更多的机器参与 Shuffle 的过程，这个时候就需要充份地利用 Mapper 端和 Reducer 端机制的计算资源，尽量使用 Mapper 端的 Aggregrate 功能，e.g. aggregrateByKey 操作。相对于 groupByKey而言，更倾向于使用 reduceByKey( ) 和 aggregrateByKey( ) 来取代 groupByKey，因为 groupByKey 不会进行 Mapper 端的操作，aggregrateByKey 可以给予更多的控制。

3. 如果一批一批地处理数据来说，可以使用 mapPartitions( )，但这个算子有可能会出现 OOM 机会，它会进行 JVM 的 GC 操作！

4. 如果进行批量插入数据到数据库的话，建义采用foreachPartition( ) 。

5. 因为我们不希望有太多的数据碎片，所以能批量处理就尽量批量处理，你可以调用 coalesce( ) ，把一个更多的并行度的分片变得更少，假设有一万个数据分片，想把它变得一百个，就可以使用 coalesce( )方法，一般在 filter( ) 算子之后就会用 coalesce( )，这样可以节省资源。

6. 官方建义使用 repartitionAndSortWithPartitions( )；

7. 数据进行复用时一般都会进行持久化 persisit( )；

8. 建义使用 mapPartitionWithIndex( )；

9. 也建义使用 tree 开头的算子，比如说 treeReduce( ) 和 treeAggregrate( )；