

# 何为shuffle

Spark并不是完全基于内存计算，因为shuffle的存在；作为Spark计算中最消耗性能的部分，因为shuffle过程中伴随着大量的磁盘IO、网络IO操作；将一个Application作业提交到Spark集群中执行，通过DAGScheduler划分成不同的job，同时每个job根据RDD间宽依赖将作业从前往后划分成不同的stage，stage中所有任务提交给底层调度器TaskScheduler接口，作为接口的好处就是与具体的任务调度器解耦，可以运行在不同的调度模式上，包括Standalong、Yarn、Mesos；stage中的task通过具体的任务调度器分发到集群中不同节点的Executor中并行执行，并行计算的逻辑完全相同只是处理的数据不同，上一个stage（Mapper）计算结果先存储在内存中（数据在网络传输前要存储在内存中），超过buffer限制后写入本地磁盘（旧版本无buffer限制,待内存区域满了才写入本地会导致OOM）；在发挥分布式并行计算获取数据的能力后，下一个stage（Reducer）需要将上一个stage在各节点上的计算结果汇聚成最终的结果，那么stage之间发生的 ``Mapper write`` + ``网络传输`` + ``Reducer Read`` 就是一次shuffle的全过程，目的就是尽量把一组无规则的数据转换成一组具有一定规则的数据；Shuffle是分布式不可避免的命运，同时也是分布式的性能杀手.

以groupBykey算子为例，因为RDD是分布式的，所以每一个key对应的value不一定都在一个partition中或都在同一个worker节点上，极有可能分布在各个节点上，因此在聚合过程中会发生分区、网络数据传输，就发生了shuffle.

会发生shuffle的聚合类算子包括: reduceByKey、groupByKey、countByKey、sortByKey、join、distinct...

# 如何shuffle

Spark中stage之间是宽依赖就会发生shuffle，前一个stage中的task作为map task（负责shuffle write），后一个stage中的task作为reduce task（负责shuffle read），Hadoop和Spark中的shuffle都分为以下两部分：

Shuffle Write: 上一个stage的每个map task就必须保证将自己处理 的当前分区中的数据相同的key写入一个分区文件中，可能会写入多个不同的分区文件中.

Shuffle Read: reduce task就会从上一个stage的所有task所在的机器上寻找属于自己的那些分区文件，这样就可以保证每一个key所对应的value都会汇聚到同一个节点上去处理和聚合.

# 自定义分区器

一般发生在shuffle write阶段，决定map端的数据结果写入哪一个shuffle小文件中，就是重分区过程

```java
val list = List(80,200,101,40,30,130,63)
val rdd = sc.parallelize(list,2)
val mapRDD = rdd.map((_,1))

mapRDD.mapPartitionsWithIndex((x, iterator)=> {
    println("----Before partitioner:" + x)
    while(iterator.hasNext) {
        println(iterator.next())
    }
    iterator
}).count()

//自定义逻辑: 分区的RDD必须是KV格式RDD,根据RDD的key值分组
val partitionRDD = mapRDD.partitionBy(new Partitioner() {
    override def numPartitions: Int = 2
    override def getPartition(key: Any): Int = {
        if(Integer.parseInt(key.toString) < 100) 0 else 1
    }
})

partitionRDD.mapPartitionsWithIndex((x, iterator)=> {
    println("----After partitioner:" + x)
    while(iterator.hasNext) {
        println(iterator.next())
    }
    iterator
}).count()


打印结果
----Before partitioner:0
(80,1)(200,1)(101,1)
----Before partitioner:1
(40,1)(30,1)(130,1)(63,1)

----After partitioner:0
(80,1)(40,1)(30,1)(63,1)
----After partitioner:1
(200,1)(101,1)(130,1)
```

# shuffle类别

在Hadooop中默认强制shuffle过程会排序，如果当前的操作并不需要排序，则会影响执行的效率；在Spark中可以通过配置使用``HashShuffleManager``不排序，也可以使用``SortShuffleManager``排序.

默认Spark中使用的是``SortShuffleManager``，如果想换成``HashShuffleManager``可以通过以下3种方式切换（优先级依次递减，第一种最常用）：

1. Application提交时添加命令行参数：--conf spark.shuffle.manager=hash

2. Application程序中添加SparkConf配置：new SparkConf().set("spark.shuffle.manager","hash")

3. 在集群中Spark安装包的conf目录下，spark-default.conf.template改成spark-default.conf，然后添加配置

## HashShuffleManager

### HashShuffleManager-普通机制

![png1](/img/Spark/Spark_shuffle1.png)

map task计算的数据先取模，然后写入对应默认大小32k的buffer缓存中，buffer满了后写入到对应磁盘小文件中（加速写磁盘的速度），每个map task产生的磁盘小文件数与reduce task个数一致（所以在hash shuffle普通机制中，总共产生的磁盘小文件个数 = map task个数 * reduce task个数）.

> 如何确定map task的处理结果写入哪一个磁盘小文件中？

将每一个map task计算后的处理结果result的key的hashcode值与reduce task的个数取模，并将这条数据写入对应的磁盘小文件中.

> 在shuffle write节点如何得知reduce task的个数？

默认reduce task与map task个数一致，除非如: reduceByKey(_+_,3)中指定了reduce task个数为3.

> HashShuffleManager普通机制存在的问题？

当map task和reduce task个数较多时，意味着产生的磁盘小文件的个数也很多：在shuffle write和read阶段JVM进程会产生大量的读写文件的对象以及大量的buffer缓存，造成MinorGC、fullGC、OOM等问题；读写文件过多也会造成IO操作耗时；同时reduce task会跨节点向map task拉取数据，因此会造成建立通信连接频繁，对性能有影响；

> reduce task怎么知道去哪个节点拉取数据？

map task计算完毕后会将计算状态和磁盘小文件的位置信息封装到MapStatus对象中，然后由本进程的MapOutputTrackerWorker对象将MapStatus对象发送给Driver进程的MapOutputTrackerMaster对象；当所有的map Task执行完毕后，Driver进程中的MapOutputTrackerMaster就掌握了所有的磁盘小文件的位置信息；在reduce task开始执行之前，会先让当前进程中的MapOutputTrackerWorker向Driver中的MapOutputTrackerMaster发送请求，请求磁盘小文件的位置信息.

### HashShuffleManager-consolidate合并机制

![png2](/img/Spark/Spark_shuffle2.png)

合并机制作为HashShuffleManager的优化方案：执行一个Application时，在同一个Executor中后执行的task可以复用之前已经结束task的磁盘小文件（注意当多core的Executor并行执行的task互相不会复用），可以有效的减少产生的总磁盘文件个数（所以在hash shuffle合并机制中，总共产生的磁盘小文件个数 = 所有Executor中core总个数 * reduce task个数）.

``spark.shuffle.consolidateFiles``设置为true，就会开启consolidate机制（默认false），会大幅度合并shuffle write的输出文件，对于shuffle read task数量特别多的情况下，这种方法可以极大地减少磁盘IO开销，提升性能；常用开启consolidate机制的方案：

1. --conf spark.shuffle.manager=hash --conf spark.shuffle.consolidateFiles=true

2. new SparkConf().set("spark.shuffle.manager","hash").set("spark.shuffle.consolidateFiles","true")

若的确不需要SortShuffleManager的排序机制，除了使用bypass机制，在数据量计算相对较少时，还可以使用HashShuffleManager的consolidate机制（实践中发现开启consolidate机制的HashShuffleManager的性能比开启bypass机制的SortShuffleManager要高出10%~30%，因为sortShuffleManager机制需要建立和解析索引文件）.

## sort shuffle

### SortShuffleManager-普通机制

![png3](/img/Spark/Spark_shuffle3.png)

SortShuffleManager-普通机制默认会排序，Map task产生的磁盘文件个数 = map task的个数 * 2个（数据文件与索引文件）.

1. Map task计算的结果会逐条写入内存的数据结构中（是Map还是Array取决于shuffle算子的返回类型，初始大小5M），定时器会定时去查看是否超过5M（如当前内存达到5.01M，就会申请5.01*2-5=5.02M的内存，如果还能申请到5.02M的内存就不会溢写，否则发生溢写），在溢写之前会将内存数据结构中的数据进行排序，排序完成之后分批写入到磁盘（每批1W条数据），写入磁盘时先使用buffer（加速写磁盘的速度)，待map task 执行完成后，溢写到磁盘上的磁盘小文件会合并成一个大的文件，同时还会为该大文件创建一个目录索引文件.

2. Reduce task拉数据之前，首先解析这个索引文件，然后拉取大文件中对应位置的数据.

### SortShuffleManager-bypass机制

SortShuffleManager-bypass机制不会排序，Map task产生的磁盘文件个数同样 = map task的个数 * 2个.

![png4](/img/Spark/Spark_shuffle4.png)

如果Reduce task个数小于``spark.shuffle.sort.bypassMergeThreshold``这个阈值（默认200），则SortShuffleManager触发bypass机制，shuffle write过程中不会进行排序，直接按照未经优化的HashShuffleManager普通机制去写数据，最后将每个task产生的所有临时磁盘文件合并成一个文件以及配套的索引文件.

所以当使用SortShuffleManager方式时，如果不需要排序操作，那么建议将``spark.shuffle.sort.bypassMergeThreshold``参数调至大于Reduce task个数，启用bypass机制减少了排序带来的性能开销（但bypass机制依然会产生大量的磁盘文件，因此shuffle write性能有待提高）.

# 总结

Spark1.5后有三种shuffle方式：hash、sort、tungsten-sort；Spark 1.2以前默认为HashShuffleManager，Spark 1.2以及之后版本默认SortShuffleManager；tungsten-sort与sort类似，不同的是使用了tungsten计划中的堆外内存管理机制，内存使用效率更高（但注意：tungsten-sort要慎用，因为之前发现了一些相应的bug）.

由于SortShuffleManager默认会对数据进行排序，因此如果业务逻辑中需要该排序机制的话，则使用默认的SortShuffleManager即可；但如果业务逻辑不需要对数据进行排序，那么建议通过bypass机制或优化的HashShuffleManager来避免排序操作，同时提供较好的磁盘读写性能以达到调优的目的.

# shuffle优化

调优的时候一般会将调优的值成倍的增加或者减少

> spark.shuffle.file.buffer=32k

参数说明: 该参数用于设置shuffle write task的BufferedOutputStream的buffer缓冲大小。将数据写到磁盘文件之前，会先写入buffer缓冲中，待缓冲写满之后，才会溢写到磁盘。

调优建议: 如果作业可用的内存资源较为充足的话，可以适当增加这个参数的大小（比如64k），从而减少shuffle write过程中溢写磁盘文件的次数，也就可以减少磁盘IO次数，进而提升性能。在实践中发现，合理调节该参数，性能会有1%~5%的提升。

> spark.shuffle.memoryFraction=0.2

参数说明: 该参数代表了Executor内存中，分配给shuffle read task进行聚合操作的内存比例，默认是20%（默认Executor中内存分配为:60%RDD缓存和广播变量、20%task计算、20%shuffle聚合）。

调优建议: 在资源参数调优中讲解过这个参数。如果内存充足，而且很少使用持久化操作，建议调高这个比例，给shuffle read的聚合操作更多内存，以避免由于内存不足导致聚合过程中频繁读写磁盘。在实践中发现，合理调节该参数可以将性能提升10%左右。

> spark.reducer.maxSizeInFlight=48M

参数说明: 该参数用于设置shuffle read task的buffer缓冲大小，而这个buffer缓冲决定了每次能够拉取多少数据。

调优建议: 如果作业可用的内存资源较为充足的话，可以适当增加这个参数的大小（比如96m），从而减少拉取数据的次数，也就可以减少网络传输的次数，进而提升性能。在实践中发现，合理调节该参数，性能会有1%~5%的提升。

问题解决: reduce端聚合的时候发生了OOM，内存不足？很有可能是reduce task去map端拉取的数据量太大，在内存聚合的时候，内存不足导致的问题.
1. 降低spark.reducer.maxSizeInFlight参数值 48M -> 24M
2. 提高Executor的内存 --executor-memory 2G -> 4G（适用于IO密集型Application）
3. 增加spark.shuffle.memoryFraction参数值  0.2 -> 0.4（适用于计算密集型Application,计算为主60%部分内存使用较少）
        
> spark.shuffle.io.maxRetries=3

参数说明: shuffle read task从shuffle write task所在节点拉取属于自己的数据时，如果因为网络异常导致拉取失败，是会自动进行重试的。该参数就代表了可以重试的最大次数。如果在指定次数之内拉取还是没有成功，就可能会导致作业执行失败。

调优建议: 对于那些包含了特别耗时的shuffle操作的作业，建议增加重试最大次数（比如60次），以避免由于JVM的full gc或者网络不稳定等因素导致的数据拉取失败。在实践中发现，对于针对超大数据量（数十亿~上百亿）的shuffle过程，调节该参数可以大幅度提升稳定性。
shuffle file not find    taskScheduler不负责重试task，由DAGScheduler负责重试stage

> spark.shuffle.io.retryWait=5s

参数说明: 具体解释同上，该参数代表了每次重试拉取数据的等待间隔，默认是5s。

调优建议: 建议加大间隔时长（比如60s），以增加shuffle操作的稳定性。

> spark.shuffle.manager=sort

参数说明: 该参数用于设置ShuffleManager的类型。Spark 1.5以后，有三个可选项：hash、sort和tungsten-sort。HashShuffleManager是Spark 1.2以前的默认选项，但是Spark 1.2以及之后的版本默认都是SortShuffleManager了。tungsten-sort与sort类似，但是使用了tungsten计划中的堆外内存管理机制，内存使用效率更高。

调优建议: 由于SortShuffleManager默认会对数据进行排序，因此如果你的业务逻辑中需要该排序机制的话，则使用默认的SortShuffleManager就可以；而如果你的业务逻辑不需要对数据进行排序，那么建议参考后面的几个参数调优，通过bypass机制或优化的HashShuffleManager来避免排序操作，同时提供较好的磁盘读写性能。这里要注意的是，tungsten-sort要慎用，因为之前发现了一些相应的bug。

> spark.shuffle.consolidateFiles=false

参数说明: 如果使用HashShuffleManager，该参数有效。如果设置为true，那么就会开启consolidate机制，会大幅度合并shuffle write的输出文件，对于shuffle read task数量特别多的情况下，这种方法可以极大地减少磁盘IO开销，提升性能。

调优建议: 如果的确不需要SortShuffleManager的排序机制，那么除了使用bypass机制，还可以尝试将spark.shffle.manager参数手动指定为hash，使用HashShuffleManager，同时开启consolidate机制。在实践中尝试过，发现其性能比开启了bypass机制的SortShuffleManager要高出10%~30%。

> spark.shuffle.sort.bypassMergeThreshold=200

参数说明: 当ShuffleManager为SortShuffleManager时，如果shuffle read task的数量小于这个阈值（默认是200），则shuffle write过程中不会进行排序操作，而是直接按照未经优化的HashShuffleManager的方式去写数据，但是最后会将每个task产生的所有临时磁盘文件都合并成一个文件，并会创建单独的索引文件。

调优建议: 当你使用SortShuffleManager时，如果的确不需要排序操作，那么建议将这个参数调大一些，大于shuffle read task的数量。那么此时就会自动启用bypass机制，map-side就不会进行排序了，减少了排序的性能开销。但是这种方式下，依然会产生大量的磁盘文件，因此shuffle write性能有待提高。


>  数据倾斜

Shuffle 时会导政数据分布不均衡，也就是数据倾斜