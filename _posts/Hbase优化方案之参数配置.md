
基于hbase-0.98.12.1\hbase-common\src\main\resources\hbase-default.xml

Hbase性能优化方案

# 表设计优化 

## Rowkey

使用rowkey查询数据的3种方式：1. 单个rowkey（get 'table','rowkey'） 2. range scan（scan.setStartRow,scan.setEndRow）3. limit scan（scan 'table',{LIMIT=>10}）

rowkey最大长度可以设置64KB，实际一般设置定长（10-100字节），在满足业务需求下越小越好；rowkey是按字典序存储.

如：最近存入的数据最可能被访问到，可以将Long.MAX_VALUE - timestamp的结果作为rowkey，能保证新写入的数据在读取时被快速命中.

## 




# hbase-site.xml

## 服务器内存

1. hbase.regionserver.handler.count

参数定义: regionserver上监听RPC请求的线程数
配置误区: 越大越好吗？ 当单个请求数据量较大时（scan/put MB数据），同时该配置线程数量也很大导致请求并发量很高，内存压力过大，频繁的GC，甚至出现内存溢出.
检测方式: 查看rpc.logging（regionserver打开DEBUG日志级别），根据在排队的线程数量消耗的内存大小来设置.
配置规则: 平均请求数据量较大，配置值较小；反之.
实际场景: 网站后端的HBase集群，这种场景下大多数为读请求，很少写请求，因此这种场景可以把该值配置到最大也较安全.


```bash
###默认30，生产建议100
<property>
    <name>hbase.regionserver.handler.count</name>
    <value>100</value>
</property>
```

2. hbase.client.write.buffer

参数定义: HTable客户端写缓冲区大小，用于临时存放写数据；
配置误区: 设置大了，浪费客户端和服务端的内存；设置小了，如果写数据大，RPC数量增多又带来网络开销；
检测方式: 评估服务器端内存使用情况，参照 hbase.client.write.buffer * hbase.regionserver.handler.count；
配置规则: 默认为2M，推荐5M，越大占用的内存越多，另测试过10M的入库性能反而没有5M好；

```bash
###默认2097152字节2M，建议5M
<property>
    <name>hbase.client.write.buffer</name>
    <value>5242880</value>
</property>
```

## hstore


1. hbase.hstore.blockingWaitTime

官方：
如果任何一个Store中存储的文件数量超过此数量（每次刷新MemStore时会写入一个StoreFile），则会阻止此HRegion的更新，直到压缩完成，或者直到超出hbase.hstore.blockingWaitTime。

一个更强力的配置，配合上一个参数，当HStore阻塞update时，超过这个时间限制，阻塞取消，就算compaction没有完成，update也不会再被阻塞，默认是90000毫秒；

```bash
###默认90000
<property>
    <name>hbase.hstore.blockingWaitTime</name>
    <value>90000</value>
</property>
```

2. hbase.hstore.blockingStoreFiles

官方：
在达到hbase.hstore.blockingStoreFiles定义的StoreFile限制后，HRegion将阻止更新的时间。经过这段时间后，即使压缩尚未完成，HRegion也会停止阻止更新。


如果任何一个store(非.META.表里的store)的storefile的文件数大于该值，则在flush memstore前先进行split或者compact，
同时把该region添加到flushQueue，延时刷新，这期间会阻塞写操作直到compact完成或者超过hbase.hstore.blockingWaitTime(默认90s)配置的时间，可以设置为30，
避免memstore不及时flush。当regionserver运行日志中出现大量的“Region has too many store files; delaying flush up to 90000ms”时，说明这个值需要调整了

一个HStore存储HStoreFile阻塞update的阈值，超过这个阈值，HStore就进行compaction，直到做完才允许update，默认是10；


```bash
###默认10，生产建议30
<property>
    <name>hbase.hstore.blockingStoreFiles</name>
    <value>30</value>
</property>
```

## hfile & regionserver

1. hfile.block.cache.size

一个配置比例，允许最大堆的对应比例的内存作为HFile和HStoreFile的block cache，默认是0.4，即40%，设置为0则disable这个比例，不推荐这么做；

默认值0.25，regionserver的block cache的内存大小限制，在偏向读的业务中，可以适当调大该值，
需要注意的是hbase.regionserver.global.memstore.upperLimit的值和hfile.block.cache.size的值之和必须小于0.8。

官方：要分配给HFile / StoreFile使用的块缓存的最大堆（-Xmx设置）的百分比。 默认值为0.4表示分配40％。设置为0表示禁用但不建议使用; 您至少需要足够的缓存来保存storefile索引。

```bash
###默认0.4，生产0.1
<property>
    <name>hfile.block.cache.size</name>
    <value>0.4</value>
</property>
```

2. hbase.regionserver.global.memstore.upperLimit

```bash
###默认0.4，生产0.3
<property>
    <name>hbase.regionserver.global.memstore.upperLimit</name>
    <value>0.4</value>
</property>
```

官方：在阻止新更新并强制刷新之前，区域服务器中所有存储库的最大大小。 默认为heap.Updates的40％被阻止，并且强制刷新，直到区域服务器中所有存储库的大小达到hbase.regionserver.global.memstore.lowerLimit。

memstore在regionserver内存中的上限，届时新的update被阻塞并且flush被强制写，默认是0.4就是堆内存的40%；阻塞状态持续到regionserver的所有memstore的容量到达hbase.regionserver.global.memstore.lowerLimit；


3. hbase.regions.slop

0.98：如果任何regionserver具有平均+（平均* slop）区域，则重新平衡。

2.0.0 ：如果任何regionserver具有平均+（平均* slop）区域，则重新平衡。此参数的默认值在StochasticLoadBalancer（默认负载均衡器）中为0.001，而在其他负载均衡器（即SimpleLoadBalancer）中默认值为0.2。

```bash
###0.98.12.1默认0.2；2.0.0默认0.001；生产0
<property>
    <name>hbase.regions.slop</name>
    <value>0</value>
</property>
```

4. hbase.regionserver.global.memstore.lowerLimit

官方：强制刷新之前区域服务器中所有存储库的最大大小。 默认为堆的38％。此值等于hbase.regionserver.global.memstore.upperLimit会导致在由于memstore限制而阻止更新时发生最小可能的刷新。

```bash
<property>
    <name>hbase.regionserver.global.memstore.lowerLimit</name>
    <value>0.38</value>
</property>
```

2.0.0版本没有该配置属性，官方说明 hbase.regionserver.global.memstore.size.lower.limit

Maximum size of all memstores in a region server before flushes
      are forced. Defaults to 95% of hbase.regionserver.global.memstore.size
      (0.95). A 100% value for this value causes the minimum possible flushing
      to occur when updates are blocked due to memstore limiting. The default
      value in this configuration has been intentionally left empty in order to
      honor the old hbase.regionserver.global.memstore.lowerLimit property if
      present.


## hbase.hregion

2. hbase.hregion.max.filesize

HStoreFile的最大尺寸，换句话说，当一个region里的列族的任意一个HStoreFile超过这个大小，那么region进行split，默认是10737418240；

默认是10G， 如果任何一个column familiy里的StoreFile超过这个值, 那么这个Region会一分为二，
因为region分裂会有短暂的region下线时间(通常在5s以内)，为减少对业务端的影响，建议手动定时分裂，可以设置为60G。

官方：
最大HStoreFile大小。 如果任何一个列族的HStoreFiles已经增长到超过此值，则托管HRegion将分为两部分。

```bash
###默认10737418240（10G），生产建议3758096384（3.5G）
<property>
    <name>hbase.hregion.max.filesize</name>
    <value>3758096384</value>
</property>
```

3. hbase.hregion.memstore.flush.size

Memstore写磁盘的flush阈值，超过这个大小就flush

默认值128M，单位字节，一旦有memstore超过该值将被flush，如果regionserver的jvm内存比较充足(16G以上)，可以调整为256M。

官方：如果memstore的大小超过此字节数，则Memstore将刷新到磁盘。 值由每个hbase.server.thread.wakefrequency运行的线程检查。

```bash
###默认134217728，生产67108864
<property>
    <name>hbase.hregion.memstore.flush.size</name>
    <value>67108864</value>
</property>
```

7. hbase.client.scanner.caching

scan缓存，默认为1，避免占用过多的client和rs的内存，一般1000以内合理，如果一条数据太大，则应该设置一个较小的值，通常是设置业务需求的一次查询的数据条数；

做scanner的next操作时（如果再本地client没找到）缓存的数据行数，这个值的设置也需要权衡，缓存的多则快，但吃内存，缓存的少则需要多的拉数据， 需要注意的事项是如果两次调用的时间差大于scanner的timeout，则不要设置该值，默认是100；

官方：
如果未从（本地，客户端）内存提供服务器，则在扫描器上下一次调用时将获取的行数。 较高的缓存值将使扫描程序更快，但会占用更多内存，而当缓存为空时，下一次调用可能会花费更长时间。
请勿将此值设置为调用之间的时间大于扫描程序超时; 即hbase.client.scanner.timeout.period

```bash
###默认100，生产200
<property>
    <name>hbase.client.scanner.caching</name>
    <value>200</value>
  </property>
```

8. hbase.client.operation.timeout

注：0.98.12.1中无，2.0.0中存在

操作超时是一个顶级限制（毫秒），可确保表中的阻塞操作不会被阻止超过此限制。 
在每个操作中，如果rpc请求因超时或其他原因而失败，它将重试直到成功或抛出RetriesExhaustedException。 
但是如果阻塞的总时间在重试耗尽之前达到操作超时，它将提前中断并抛出SocketTimeoutException。

```bash
###默认1200000，生产建议60000
<property>
    <name>hbase.client.operation.timeout</name>
    <value>60000</value>
</property>
```

## zookeeper配置

1. zookeeper.znode.parent

更改Hbase在zookeeper存储元数据znode树的根目录名称，默认/hbase

```bash
<property>
    <name>zookeeper.znode.parent</name>
    <value>/hbase</value>
</property>
```

1. hbase.zookeeper.property.maxClientCnxns

来自ZooKeeper的配置zoo.cfg.Limit的属性，用于通过IP地址标识的单个客户端可以对ZooKeeper集合的单个成员进行的并发连接数（在套接字级别）。 
设置为高以避免运行独立和伪分布的zk连接问题。

允许接入zk的最大并发连接数的限制，按ip分配，默认300；

```bash
###默认300，生产2000
<property>
    <name>hbase.zookeeper.property.maxClientCnxns</name>
    <value>300</value>
</property>
```

2. zookeeper.session.timeout

ZooKeeper会话超时（以毫秒为单位）。 它以两种不同的方式使用。
首先，该值用于HBase用于连接集合的ZK客户端。
HBase在启动ZK服务器时也会使用它，并将其作为'maxSessionTimeout'传递。
例如，如果HBase区域服务器连接到也由HBase管理的ZK集合，则会话超时将是此配置指定的超时。 
但是，连接到使用不同配置管理的集合的区域服务器将受到该集合的maxSessionTimeout。 
因此，即使HBase可能建议使用90秒，但是整体可以具有低于此的最大超时，并且它将优先。 ZK附带的当前默认值是40秒，低于HBase。

```bash
###默认90000，生产180000
<property>
    <name>zookeeper.session.timeout</name>
    <value>90000</value>
</property>
```

## rpc

1. hbase.rpc.timeout

这是为了让RPC层定义HBase客户端应用程序为远程调用超时所需的时间。 它使用ping来检查连接，但最终会抛出TimeoutException。

Hbase client发起远程调用时的超时时限，使用ping来确认连接，但是最终会抛出一个TimeoutException，

```bash
###默认60000，生产120000
<property>
    <name>hbase.rpc.timeout</name>
    <value>60000</value>
</property>
```



## 自定义


1. hbase.coprocessor.region.classes

<property>
    <name>hbase.coprocessor.region.classes</name>
    <value></value>
    <description>A comma-separated list of Coprocessors that are loaded by
    default on all tables. For any override coprocessor method, these classes
    will be called in order. After implementing your own Coprocessor, just put
    it in HBase's classpath and add the fully qualified class name here.
    A coprocessor can also be loaded on demand by setting HTableDescriptor.</description>
  </property>


  
2. hbase.coprocessor.master.classes

由HMaster进程加载的coprocessors，逗号分隔，全部实现org.apache.hadoop.hbase.coprocessor.MasterObserver，同coprocessor类似，加入classpath及全限定名；

官方：
以逗号分隔的org.apache.hadoop.hbase.coprocessor.MasterObserver协处理器列表，默认情况下在活动的HMaster进程上加载。 
对于任何实现的协处理器方法，将按顺序调用列出的类。 在实现自己的MasterObserver之后，只需将其放在HBase的类路径中，并在此处添加完全限定的类名。

```bash
###生产：org.apache.hadoop.hbase.master.TransactionMasterObserver（自实现）
<property>
    <name>hbase.coprocessor.master.classes</name>
    <value></value>
  </property>
```