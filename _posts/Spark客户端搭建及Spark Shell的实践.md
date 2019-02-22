
# 客户端搭建

搭建Spark集群的客户端的目的在于：防止Spark集群节点间性能产生差异引起木桶效应，和负载均衡无关.

## 执行流程

在sparkcli客户端执行 ``./spark-submit --master spark://spark1:7077 ../lib/FilterCount.jar`` 命令后，Spark客户端与集群的运行流程如下：

![png1](/img/Spark/Spark_client.png)

1. 在客户端提交 ``spark-submit`` 命令后，首先客户端将application ``FilterCount.jar`` 上传到Spark集群中的FTP服务器上，包含执行的Jar包和执行所依赖的Jar包.

2. 然后客户端在本地创建一个Driver进程，并发送申请资源的请求到spark1所在的Master节点.

3. Master在接收到请求后，寻找集群中资源充足的Worker节点，并在这些Worker节点上启动Executor进程（Executor是JVM进程，其中包含一个ThreadPool，这个线程池中每个Thread都可以执行task）.

4. 启动了Executor进程的Worker节点会将Executor进程反向注册给客户端中的Driver进程.

5. 这样在Driver进程中就拥有了多个Executor的列表，Driver会分发task到列表中的每个Executor中的ThreadPool中执行.

6. 当task在执行过程中需要依赖Jar包时，就会到集群中FTP服务器上下载.

7. 最后task执行的结果会被拉回到客户端的Driver进程的JVM内存中，如果结果数据较大，可能会造成OOM.


## 搭建及测试

将spark1节点上配置好的的spark集群安装包复制到sparkcli客户端节点上，然后配置sparkcli节点.

1. 配置spark的环境变量SPARK_HOME.

2. 配置hosts. ``vim /etc/hosts`` 添加 ``192.168.154.63 sparkcli``

3. 配置免密钥. 确保sparkcli与spark1节点之间网络连接通畅，可以免密钥访问.

4. 启动spark集群中的HDFS和Spark. ``start-dfs.sh`` 、 ``start-spark.sh``

5. 将FilterCount.jar 上传到sparkcli客户端节点 ``/usr/local/spark/lib/`` 路径下.

6. 在sparkcli节点 ``/usr/local/spark/bin/`` 中执行 ``./spark-submit --master spark://spark1:7077 ../lib/FilterCount.jar``

FilterCount.jar在打包时指定了Main Class，所以在spark-submit时无需添加 ``--class com.stefan.spark.FilterCount``



# Spark shell

spark shell同样遵循repl模式，一般用作调试使用；可以看出spark-shell底层封装的是spark-submit，那么启动spark-shell就是将应用程序提交到spark集群中去.

```bash
# cd /usr/local/spark/bin/
# vim spark-shell
"${SPARK_HOME}"/bin/spark-submit --class org.apache.spark.repl.Main --name "Spark shell"
```

Spark集群和HDFS集群保持正常启动状态，在spark客户端节点上启动测试：

```bash
# cd /usr/local/spark/bin/
# ./spark-shell --master spark://spark1:7077
scala> 
```

在Spark的webUI界面 http://192.168.154.60:8888 发现Running Applications下有个``Spark shell``处于running.

注意当spark-shell启动后，控制台显示``Spark context available as sc.``，因此会自动``val sc = new SparkContext()``创建SparkContext对象，我们只需要操作``sc``创建RDD即可.

```bash
scala> sc
res0: org.apache.spark.SparkContext = org.apache.spark.SparkContext@351ff4e3

scala> val lineRDD = sc.textFile("hdfs://spark1:9000/input/log.txt")

--30行记录
scala> lineRDD.count()
res0：Long = 22

--foreach算子不会拉回计算结果，需要在webUI中依次点击Running Application -> Spark shell -> Executors -> stdout
scala> lineRDD.flatMapp(_.split(" ")).map((_,1)).reduceByKey(_+_).foreach(println)

--collect算子会拉回计算结果
scala>  lineRDD.flatMapp(_.split(" ")).map((_,1)).reduceByKey(_+_).collect()
res1: Array[(String, Int)] = Array((3304,1), (3308,1), (3302,2), (3306,2), 
(2017-10-23,1), (浙江舟山,1), (浙江衢州,2), (2017-10-14,1), (2017-10-16,1), 
(2017-10-18,1), (2017-10-25,1), (2017-10-27,1), (浙江台州,2), (2017-11-02,1), 
(2017-10-30,1), (2017-10-12,1), (2017-10-21,1), (2017-10-29,1), (3311,1), (3307,2), 
(2017-10-26,1), (3310,1), (浙江丽水,1), (2017-10-17,1), (2017-10-13,1), (2017-10-11,1), 
(浙江宁波,2), (3312,5), (3301,1), (浙江金华,2), (浙江临安,2), (3309,2), (3303,2), 
(2017-10-24,1), (2017-10-19,1), (2017-10-28,1), (浙江温州,2), (2017-10-22,1), 
(2017-10-20,1), (2017-11-01,1), (3305,2), (2017-10-15,1), (浙江杭州,8))
```



