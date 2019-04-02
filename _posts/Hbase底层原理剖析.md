## 简述

Hbase是一个高可靠、高性能、可扩展、面向列、实时读写、海量结构化与半结构化存储的开源分布式数据库。

其原型是Google Bigtable（基于GFS和Chubby）；常见的分布式存储系统分为两种结构（单层和双层结构），大部分系统属于单层结构，对系统中每个分片维护多个副本，只有类Bigtable系统属于``双层结构``，底层使用GFS作为持久化存储层，对每个数据分片维护多个副本，上层服务层每个数据分片同一时刻只有一个副本对外提供服务。


## 面向列

行与列的差别主要体现在**存储**与**检索** :

以下两份数据代表Hbase表中一行数据分别物理存储在一个region的不同store中，不同于RDBMS连续存储整行，Hbase列式存储则是基于三维排序按列顺序的存储。

|rowkey|ts|cf1|
|---|---|---|
|aaa.bbb.ccc|t2|cf1:column1-1 = "01001"|
|aaa.bbb.ccc|t3|cf1:column1-2 = "0110011011"|
|aaa.bbb.ccc|t2|cf1:column1-2 = "11100100"|
|aaa.bbb.ccc|t1|cf1:column1-2 = "1110010011111111"|

|rowkey|ts|cf2|
|---|---|---|
|aaa.bbb.ccc|t2|cf2:column2-1 = "011110011"|
|aaa.bbb.ccc|t1|cf2:column2-1 = "0000111110011"|
|aaa.bbb.ccc|t1|cf2:column2-2 = "011011101111001"|

当只查询表中部分字段时，RDBMS会读取整行，而Hbase只会读取涉及到的列，有效减少I/O；列式储存的数据更利于压缩，有效减少在返回结果时网络带宽的消耗提高读效率。

## 表描述

```bash
'bgis_track',{NAME=>'track_info',VERSIONS=>'1',MIN_VERSIONS=>'0',TTL=>'FOREVER',
BLOOMFILTER=>'ROW',COMPRESSION=>'NONE',KEEP_DELETED_CELLS=>'FALSE',REPLICATION_SCOPE=>'0',
DATA_BLOCK_ENCODING=>'NONE',BLOCKSIZE=>'65536',BLOCKCACHE=>'TRUE',IN_MEMORY=>'FALSE'}
```

|属性|默认|描述|实践|
|---|---|---|---|
|NAME||列族，建议不超过1个且名字尽可能短|flushing和compaction都基于region，其中一个store需要flush或compaction，该region中所有store都必须陪着一起，有些当前根本不需要就会产生许多不必要的I/O；因为列族名会带入每个列的存储中，所以尽量短|
|VERSIONS|1|版本号，不建议设置过大|System.currentTimeMillis()，降序存储；除非业务需要，设置过大会增加StoreFile存储的压力；并发写入同一版本只有最后写入生效|
|MIN_VERSIONS|0|0代表不使用该属性特性|当列族启用TTL时，才可以设置该属性，且必须小于VERSIONS|
|TTL|FOREVER|TimeToLive，行过期时间|过期的行会在minor compaction时被删除，``hbase.store.delete.expired.storefile``=false屏蔽该特性；除非业务需要，数据永久保存会消耗存储空间，也会降低查询效率|
|BLOOMFILTER|ROW|布隆过滤器，可选NONE、ROW、ROWCOL|启用后在get和部分scan操作时会过滤掉用不到的存储文件，减少实际IO次数，优化随机读性能；ROWCOL适用于ROWKEY+COLUMN|
|COMPRESSION|NONE|数据压缩方式，GZ可直接用，其他LZ0、LZ4、Snappy需要安装，默认NONE不压缩|减少数据存储空间，同时降低数据网络传输量提高读效率；Snappy的压缩率最低，但编解码速率最高，对CPU的消耗也最小，一般建议Snappy|
|KEEP_DELETED_CELLS||||
|BLOCKCACHE|true|读缓存||
|IN_MEMORY|false|数据是否常驻内存|Hbase为访问频繁的数据提供一块缓存区域（hbase:meta表数据常驻），大小=JVMheap*0.2*0.25，若设置true则业务数据会挤占meta表数据空间，导致集群性能下降；若常驻业务元数据可以考虑|

## HFile

### HFile逻辑划分

HFile V1在使用中会占用很多内存，``HFile V3（0.98）``相较于``HFile V2（0.92）``，更改不大。

<table>
    <tr>
        <th>HFile Sections</th>
        <th>Section Desc</th>
        <th>Section Parts</th>
        <th>Section Parts Desc</th>
    </tr>
    <tr>
        <th rowspan="3">Scanned Block Sections</th>
        <th rowspan="3">scan顺序扫描HFile时</br>包含的数据块都会被读取</th>
        <td>Data Block</td>
        <td>数据块</td>
    </tr>
    <tr>
        <td>Bloom Block</td>
        <td>BloomFilter相关数据块</td>
    </tr>
    <tr>
        <td>Leaf Index Block</td>
        <td>DataBlock的三级索引</td>
    </tr>
    <tr>
        <th rowspan="2">Non-scanned Block Sections</th>
        <th rowspan="2">scan顺序扫描HFile时</br>包含的数据块不会被读取</th>
        <td>Meta Block</td>
        <td>元数据块</td>
    </tr>
    <tr>
        <td>Intermediate Level Data Index Block</td>
        <td>DataBlock的二级索引</td>
    </tr>
    <tr>
        <th rowspan="4">Load-on-open Sections</th>
        <th rowspan="4">RegionServer启动时</br>包含的数据块被加载到内存中</th>
        <td>Data Index</td>
        <td>DataBlock的根索引</td>
    </tr>
    <tr>
        <td>Meta Index</td>
        <td>元数据索引</td>
    </tr>
    <tr>
        <td>Bloom Index</td>
        <td>BloomFilter相关数据的索引</td>
    </tr>
    <tr>
        <td>FileInfo</td>
        <td>元数据键值对（定长）：AVG_KEY_LEN, AVG_VALUE_LEN, LAST_KEY, COMPARATOR, MAX_SEQ_ID_KEY</td>
    </tr>
    <tr>
        <th rowspan="1">Trailer</th>
        <th rowspan="1">HFile的基本信息、各部分的偏移值和寻址信息</th>
        <td>Trailer Block</td>
        <td>不属于HFile V2的Block，而是固定大小的数据结构</td>
    </tr>
</table>

### HFile的BlockType

HFile V2 定义了8种block type : ``DATA``、``LEAF_INDEX``、``BLOOM_CHUNK``、``META``、``INTERMEDIATE_INDEX``、``ROOT_INDEX``、``FILE_INFO``、``BLOOM_META``.

block type包括``BlockHeader``和``BlockData``；BlockHeader主要存储block元数据（其中的BlockType字段用来标识以上其中一种），8钟类型的BlockHeader结构都相同；但是BlockData的结构各不相同，BlockData用来存储具体数据，有的存储具体业务数据，有的存储索引/元数据。

HFile中这些Block的大小在建表时描述列族时指定，默认``BLOCKSIZE=>65536``，大号Block有利于顺序Scan，小号的Block有利于随机get。

### HFile读写

数据从memstore flushing到HFile的同时，在内存中记录数据索引及Bloom等信息，待数据完全刷盘完成后，索引等信息也在内存中建立完毕并追加写入HFile；从HFile读取数据时（索引等在文件尾部，如何快速定位数据），原来加载文件后是从后往前读，首先根据具体Version获取固定长度``Trailer``，然后解析``Trailer``并加载到内存，最后加载``Load-on-open``区域的数据，具体如下：

1. 首先读取``Trailer``中的Version信息，根据不同的版本(V1/V2/V3)决定使用不同的Reader对象读取解析HFile；

2. 然后根据Version信息获取Trailer的长度（不同version的Trailer长度不同），根据Trailer长度加载整个Trailer；

3. 最后加载``Load-on-open``部分到内存中，起始偏移地址是Trailer中的``LoadOnOpenDataOffset``字段，``Load-on-open``部分的结束偏移量=HFile总长度-Trailer长度，``Load-on-open``部分主要包括Root Index和FileInfo。






## 三维

> 数十亿行 x 数百万列 x 数千版本 = PB级储存

通过 ``rowkey`` 、``column family : column`` 、``version`` 可以确定一个Cell的唯一值。
> A {row, column, version} tuple exactly specifies a cell in HBase.

- sort
> All data model operations HBase return data in sorted order. 
> First by row, then by ColumnFamily, followed by column qualifier, and finally timestamp

- 字节存储
> so anything that can be converted to an array of bytes can be stored as a value.
- 表定义
> Column families must be declared up front at schema definition time whereas columns do not need to be defined at schema time but can be conjured on the fly while the table is up and running.
> Physically, all column family members are stored together on the filesystem. Because tunings and storage specifications are done at the column family level, it is advised that all column family members have the same general access pattern and size characteristics.


- 松散表结构  null

- update schema
> When changes are made to either Tables or ColumnFamilies (e.g. region size, block size), these changes take effect the next time there is a major compaction and the StoreFiles get re-written.

- 字典排序

- 列族 单位

- rowkey  随机 范围查询

- LSM树（写>读） 而不是B tree（读写对等）



- 跨系统支持导入导出CSV格式

- 同系统支持distcp直接拷贝底层存储文件，快速导入

- 使用sqoop在不同数据库系统间迁移数据




- delete/update
> HBase does not modify data in place, and so deletes are handled by creating new markers called tombstones. These tombstones, along with the dead values, are cleaned up on major compactions.

如果hbase-site.xml中``hbase.hstore.time.to.purge.deletes``未设置或值为0，则下次major compactions清除所有带删除标记的数据，否则延迟设置值的时间后在下一次major compactions清除。



## rules of thumb

### table schema

- regions size 10 ~ 50 GB.

- cells < 10 MB, or 50 MB if use mob.

- 50 ~ 100 regions for a table with 1 ~ 2 column families. 


> maximum disk space per machine around 6T. In that case the Java heap should be 32GB (20G regions, 128M memstores, the rest defaults).



### feature

> HBase lacks many of the features in RDBMS, such as typed columns, secondary indexes, triggers, and advanced query languages, etc.

- 强一致并非最终一致，适用于高速的计数聚合等任务

- 自动region分区

- 自动regionserver故障转移

- 集成HDFS，HDFS并不是通用的文件系统，并不提供文件内单个记录的快速查找，Hbase将文件构建的索引storefile存储在HDFS中

- 支持作为MapReduce/Spark大规模并行计算的数据源与结果接收器

- 支持块缓存、布隆过滤器，实现该容量查询优化

- 提供内置管控web界面方便运维，60010


### meta

> The hbase:meta table (previously called .META.) keeps a list of all regions in the system, 
> and the location of hbase:meta is stored in ZooKeeper.

hbase:meta数据常驻内存，meta表无法split。
hbase:meta表被强制加入block cache，且具有内存优先级，很难被驱逐。
hbase:meta表多大取决于region的数量。


### client

> The HBase client finds the RegionServers that are serving the particular row range of interest. 
> It does this by querying the hbase:meta table. See hbase:meta for details. 
> After locating the required region(s), the client contacts the RegionServer serving that region, 
> rather than going through the master, and issues the read or write request. 
> This information is cached in the client so that subsequent requests need not go through the lookup process. 
> Should a region be reassigned either by the master load balancer or because a RegionServer has died, 
> the client will requery the catalog tables to determine the new location of the user region.

```java
//including the hbase-shaded-client module is the recommended dependency when connecting to a cluster:
/**
<dependency>
  <groupId>org.apache.hbase</groupId>
  <artifactId>hbase-shaded-client</artifactId>
  <version>2.0.0</version>
</dependency>
*/

Configuration config = HBaseConfiguration.create();
config.set("hbase.zookeeper.quorum", "localhost");

/*
【API as of HBase 1.0.0】
In HBase 1.0, obtain a Connection object from ConnectionFactory and thereafter, 
get from it instances of Table, Admin, and RegionLocator on an as-need basis. 
When done, close the obtained instances. Finally, be sure to cleanup your Connection instance before exiting. 
Connections are heavyweight objects but thread-safe so you can create one for your application and keep the instance around.
Table, Admin and RegionLocator instances are lightweight. Create as you go and then let go as soon as you are done by closing them.
/*

/*
【API before HBase 1.0.0】
Instances of HTable to interact with cluster earlier than 1.0.0, not thread-safe. 
Only one thread can use an instance of Table at any given time. 
When creating Table instances, it is advisable to use the same HBaseConfiguration instance. 
*/

HBaseConfiguration conf = HBaseConfiguration.create();
HTable table1 = new HTable(conf, "myTable");
HTable table2 = new HTable(conf, "myTable");

/*
HTablePool is removed in 0.98.1.
HConnection is deprecated in HBase 1.0 by Connection.
*/
Configuration conf = HBaseConfiguration.create();
try (Connection connection = ConnectionFactory.createConnection(conf);
     Table table = connection.getTable(TableName.valueOf(tablename))) {
         ...
}

//In HBase 1.0 and later, HTable is deprecated in favor of Table. Table does not use autoflush. 
//In HBase 2.0 and later, HTable does not use BufferedMutator to execute the Put operation.

//Asynchronous Client
//Asynchronous Admin
```

### Master

> The Master server is responsible for monitoring all RegionServer instances in the cluster, 
> and is the interface for all metadata changes. 
> In a distributed cluster, the Master typically runs on the NameNode.

> However, the Master controls critical functions such as RegionServer failover and completing region splits.
> So while the cluster can still run for a short time without the Master, the Master should be restarted as soon as possible.

The Master runs several background threads:

- LoadBalancer：Periodically, and when there are no regions in transition, a load balancer will run and move regions around to balance the cluster’s load.

- CatalogJanitor：Periodically checks and cleans up the hbase:meta table.

- 


WAL(Write-Ahead Logging)是一种高效的日志算法，几乎是所有非内存数据库提升写性能的不二法门，基本原理是在数据写入之前首先顺序写入日志，然后再写入缓存，等到缓存写满之后统一落盘。之所以能够提升写性能，是因为WAL将一次随机写转化为了一次顺序写加一次内存写。提升写性能的同时，WAL可以保证数据的可靠性，即在任何情况下数据不丢失。




### Compressed BlockCache
HBASE-11331 introduced lazy BlockCache decompression, more simply referred to as compressed BlockCache. When compressed BlockCache is enabled data and encoded data blocks are cached in the BlockCache in their on-disk format, rather than being decompressed and decrypted before caching.

For a RegionServer hosting more data than can fit into cache, enabling this feature with SNAPPY compression has been shown to result in 50% increase in throughput and 30% improvement in mean latency while, increasing garbage collection by 80% and increasing overall CPU load by 2%. See HBASE-11331 for more details about how performance was measured and achieved. For a RegionServer hosting data that can comfortably fit into cache, or if your workload is sensitive to extra CPU or garbage-collection load, you may receive less benefit.

The compressed BlockCache is disabled by default. To enable it, set hbase.block.data.cachecompressed to true in hbase-site.xml on all RegionServers.

###预分区

```bash
create 'NewsClickFeedback',{NAME=>'Toutiao',VERSIONS=>1,BLOCKCACHE=>true,BLOOMFILTER=>'ROW',COMPRESSION=>'SNAPPY',TTL => ' 259200 '},
{SPLITS => ['1','2','3','4','5','6','7','8','9','a','b','c','d','e','f']}
```
region预分配策略。通过region预分配，数据会被均衡到多台机器上，这样可以一定程度上解决热点应用数据量剧增导致系统自动split引起的性能问题。
HBase数据是按照rowkey按升序排列，为避免热点数据产生，一般采用hash + partition的方式预分配region，
比如示例中rowkey首先使用md5 hash，然后再按照首字母partition为16份，就可以预分配16个region。



# 优化

在保证系统稳定性、可用性的基础上使用最少的系统资源（CPU,IO等）获得最好的性能（吞吐量，读写延迟）。

## HDFS相关配置优化

## HBase服务器端优化
 1. GC优化
 2. Compaction优化
 3. 硬件配置优化

## rowkey设计


## 列族设计优化

Hbase中访问权限控制、存储、调优都是以列族作为基本单位的。

建表时设置列族的对应属性关乎表的读写性能，部分属性需要根据业务场景做特定设置。

1. BLOCKSIZE

StoreFiles are composed of blocks. StoreFiles由block组成
Compression happens at the block level within StoreFiles. 压缩发生在StoreFile的block级别


## 客户端优化
 1. 超时机制
 2. 重试机制

