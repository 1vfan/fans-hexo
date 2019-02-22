## 累加器Accumulator

累加器只能在Driver端定义和读取，不能在Executor读取，但可以在Executor端操作累加（如accumulator.add(1)）.

1. Driver与Executor属于不同的JVM进程

```java
val conf = new SparkConf().setMaster("local").setAppName("Count")
val sc = new SparkContext(conf)
var count = 0
val rdd = sc.textFile("log.txt")
rdd.map(x => count += 1).count()
println(count)  //0
```

因为变量count是存在Driver的JVM进程中的，当执行task的Executor进程要用到变量count，Driver会将count值传到Executor端，而Driver端``println(count)``打印的count值依旧是0.

```java
val conf = new SparkConf().setMaster("local").setAppName("Accumulator")
val sc = new SparkContext(conf)
val accumulator = sc.accumulator(0)
rdd.map(x => accumulator.add(1)).count()
println(accumulator.value)   //22
```

Accumulator累加器就相当于Spark集群间共享的一个大变量，就可以解决以上count计数为0的问题.

2. 多次action操作会影响accumulator的准确性

```java
val accumulator = sc.accumulator(0)
val value = rdd.map(x => accumulator.add(1))
value.count
println(accumulator.value) //22

value.collect
println(accumulator.value) //44
```

如上，当进行了两次action操作后，累加器的值又新增了一轮，因为累加器同转换类算子一样，通过action类算子触发执行，两个action操作，累加器就会执行两轮，可通过缓存数据切断两轮之间的依赖解决上述问题

```java
val accumulator = sc.accumulator(0)
val value = rdd.map(x => accumulator.add(1))
value.cache.count //22
println(accumulator.value)

value.collect //22
println(accumulator.value)
```

所以使用累加器时，为了保证准确性，只使用一次action操作；如果需要使用多次则使用cache或persist算子切断依赖.


## 广播变量Broadcast

广播变量在Driver端定义，只能在Driver端修改，Executor端只能读取不能修改（避免维护多节点中数据一致性的问题）.

广播变量不是Driver主动发给Executor的，而是Task在执行的时候如果使用到了广播变量，它会先找本地管理广播变量的组件``BlockManager``去要，如果本地的BlockManager中没有该广播变量，BlockManager会去Driver端的``BlockManagerMaster``组件上拉取广播变量，避免资源浪费.

1. 使用广播变量优化程序减轻内存负担

```java
val conf = new SparkConf().setMaster("local").setAppName("Filter")
val sc = new SparkContext(conf)
val rdd = sc.textFile("log.txt")
val blackList = List("浙江杭州","浙江温州")
rdd.map(x => x.split(" ")(1)).filter(x => {
    !blackList.contains(x)
}).foreach(println)
sc.stop()
```

以上代码存在的隐患在于，当执行job的task足够多时，Executor进程中线程池的每个task都会存一份来自Driver进程的blackList变量副本，这样内存的负担比较大.

```java
val conf = new SparkConf().setMaster("local").setAppName("Filter")
val sc = new SparkContext(conf)
val rdd = sc.textFile("log.txt")
val blackList = List("浙江杭州","浙江温州")
val broadcastNames = sc.broadcast(blackList)
rdd.map(x => x.split(" ")(1)).filter(x => {
    !broadcastNames.value.contains(x)
}).foreach(println)
sc.stop()
```

一个Executor进程中所有tasks线程都属于同一个Application，每个Executor进程只保存一份广播变量，可以被线程池中所有task共享，避免每个task线程都新增一个变量副本，大大节省了内存空间.

2. 使用广播变量替代join避免shuffle

join算子会发生shuffle，shuffle过程会发生数据传输，IO读写会占用大量资源，所以尽量避免使用shuffle类算子.

```java
val nameList = List((1,"stefan1"),(2,"stefan2"),(3,"stefan3"),(4,"stefan4"))
val scoreList = List((1,60),(2,70),(3,80),(5,100))
val nameRDD = sc.parallelize(nameList)
val scoreRDD = sc.parallelize(scoreList)

//Broadcast并不能将RDD广播出去，因为RDD中并不存储数据，只能对一个RDD调用collect算子，
//将每个task的计算结果拉回到Driver端，再将RDD的计算结果广播出去.
val broadcastResult = sc.broadcast(scoreRDD.collect())

nameRDD.map(x => {
    val id = x._1
    val name = x._2
    var score = 0
    for(value <- broadcastResult.value) {
        if(id.equals(value._1)) {
            score = value._2
        }
    }
    println(id+ "-" + name+ "-" + score)
    new Tuple2(name,score)
}).collect()
```

```bash
1-stefan1-60
2-stefan2-70
3-stefan3-80
4-stefan4-0
```




