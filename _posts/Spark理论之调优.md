## shuffle案列

![png1](/img/Spark/Spark_shuffle5.png)

```java
val fileRDD = sc.textFile("hdfs://spark1:9000/log.txt")
val filterRDD = fileRDD.filter(x => true)
val map1RDD = filterRDD.map(x => (x.split("\t"), 1))
val groupRDD = map1RDD.groupByKey(3)

val map2RDD = groupRDD.map(x => (x._1,1))
val reduceRDD = map2RDD.reduceByKey(_+_)

val result = reduceRDD.collect()
```

1. 一般考虑性能的话，会将shuffle过程中产生的磁盘小文件保存到SSD上
2. 根据计算结果的Key的hashcode值与ReduceTask的个数取模决定数据写入哪一个磁盘文件中
3. 如果使用shuffle类算子时未指定分区数，那么新RDD的分区数与父RDD一致
4. ReduceTask每次最多从MapTask中拉取48M数据，将拉来的数据存储在Executor的20%内存中
5. 该Application总共的Task个数是:2+3+3=8
6. 这三个stage的执行顺序是阻塞按顺序执行的
7. 


## BlockManager

BlockManager管理整个Spark集群运行时的数据读写，当然也包含数据存储本身，在这个基础之上进行读写操作，
由于 Spark 本身是分布式的，所以 BlockManager 也是分布式的.
