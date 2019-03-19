# Hbase

## 简介

Hadoop Database 是一个高可靠、高性能、可伸缩、实时读写、面向列的开源分布式数据库，适用于存储海量结构化和半结构化的松散数据，这些数据存在以下特性: 数据量大、属性不固定且支持动态增加、没有数据类型rowkey和cell都以字节数组形式存储、null列不占存储空间、插入多不频繁更新、多历史版本。

其原型是Google Bigtable（基于GFS和Chubby的分布式表格系统）；常见的分布式存储系统分为两种结构（单层和双层结构），大部分系统属于单层结构，对系统中每个分片维护多个副本，只有类Bigtable系统属于``双层结构``，底层使用GFS作为持久化存储层，对每个数据分片维护多个副本，上层服务层每个数据分片同一时刻只有一个副本对外提供服务。

## 数据模型

### Rowkey

Hbase的行通过一个主键Rowkey唯一标识（行必须要有Rowkey）；表根据主键Rowkey按字典序排序；在Hbase中以字节数组存储。

### Column family

列名由两部分组成（column family : qualifier），列族需要在建表时预定义，一般限制在1-2个，列必须属于某一列族，qualifier不需要预定义，可以按需动态添加任意多个（一行包括n列），同一个表中不同的行可以有不同列。

```java
//根据实体类中新增字段可以实现动态向Hbase中添加列
List<Put> puts = new ArrayList<Put>();
for(Object obj : Objects) {
    Put put = new Put(Bytes.toBytes(obj.getRowkey()));
    Field[] fields = Object.class.getDeclaredFields();
    for(Field field : fields) {
        String fieldName = field.getName();
        String indexFieldName = field.subString(0,1).toUpperCase();
        String method = "get" + indexFieldName + fieldName.subString(1);
        String fieldValue = (String)method.invoke(Object, null);
        if(fieldValue == null || "".equals(fieldValue)) continue;
        put.add(Bytes.toBytes("family"), Bytes.toBytes(fieldName), Bytes.toBytes(fieldValue));
    }
    puts.add(put);
}
(HTableInterface)htable.put(puts);
htable.close();
```

Hbase的访问权限控制、存储、调优都是以列族为基本单位进行设置的；Hbase把同一列族下的数据存储在同一目录下，由几个文件保存，便于管理优化。

### Cell

由 ``rowkey, column family : qualifier, version`` 三个维度确定唯一的Cell；Hbase没有数据类型，所有列值都被转换成不可分割的字节数组存储（包括rowkey和cell）。


### Versions

为了简化不同版本的数据管理，Hbase提供两种设置：1.保留最近的N个不同版本；2.保留限定时间内的不同版本。

```java
HTableDescriptor htd = new HTableDescriptor("T_track");
HColumnDescriptor hcd = new HColumnDescriptor("track_info");
hcd.setMaxVersions(3);//hbase.column.max.version 默认=1
hcd.setTimeToLive(2*24*60*60);//默认forever
htd.addFamily(hcd);
```

update不是把原先的数据替换掉，而是通过时间戳维护Cell的版本号，将更新数据以最新版本插入，并采用倒排排在最前面方便读取；与RDBMS中的Delete不同，Hbase中可以指定删除某列、某列族，或指定某个时间戳（删除比这个时间早的版本）。

Hbase执行Delete命令并不会立即将数据从磁盘删除，而是通过创建名为``tombstone``的新标记（防止数据被查询出来），在大合并``major compact``后数据才真正被清除，同时标记也从``StoreFile``中被移除；如果是由于TTL过期的数据不会创建tombstore标记，但过期数据会被过滤掉，不会写入大合并后的StoreFile中。

### Key/Value

KeyValue是Hbase的基础类型；但建议HBase应用程序和用户使用Cell接口，避免直接使用KeyValue和Cell中未定义的成员变量。

```java
//An HBase Key/Value, This is the fundamental HBase Type.
public class KeyValue implements Cell, HeapSize, Cloneable {
    private byte[] bytes = null;//存储实际内容
    private int offset = 0;//某字段内容在byte[]数组中的开始位置
    private int length = 0;//自开始位置的长度
        
    public byte[] getRowArray(){return bytes;}
    public int getRowOffset(){...}
    public int getRowLength(){...}
}
```

```json
//KeyValue内部存储结构
{
    keylength,
    valuelength,
    key: {
        rowLength,
        row (i.e., the rowkey),
        columnfamilylength,
        columnfamily,
        columnqualifier,
        timestamp,
        keytype (e.g., Put, Delete, DeleteColumn, DeleteFamily)
    }
    value
｝
```

### 三维排序

hbase按照rowkey、column、ts三维对数据进行排序，rowkey和column升序，ts降序；

hbase表中每个列族对应独立的Store存储，column使用key/value结构存储，当一个列族中包含的column比较多时，column有序能提高查询效率；

ts即versions，ts有序保证取到column的最大版本数据，且有利于指定了版本范围的查询。

## 数据结构

Hbase0.96版本后废弃了root表(之前需要通过连接zk -> root表中meta-region-server -> meta表地址；0.96之后只需连接zk获得meta表地址)，新增了``hbase:namespace``表。

```bash
[zk: localhost:2181(CONNECTED) 1] ls /hbase
[replication, meta-region-server, rs, splitWAL, backup-masters, table-lock, region-in-transition, online-snapshot, master, running, recovering-regions, draining, namespace, hbaseid, table]
```

### namespace

* hbase: 系统内建，名下meta和namespace表，list命令无法查询到；
* default: 系统内建，用户建表时未指定namespace则默认属于default命令空间；
* bgis: 用户自建，通过create_namespace 'bgis'创建； 

```bash
[zk: localhost:2181(CONNECTED) 3] ls /hbase/namespace
[bgis, default, hbase]

[zk: localhost:2181(CONNECTED) 1] ls /hbase/table
[bgis_track, hbase:meta, hbase:namespace, bgis:bgis_mileage]
```

### hbase:meta

``hbase:meta``表就是namespace = hbase下的一张元数据表，记录着其他所有表（用户表+namespace表+snapshot表）的region元数据信息，表中一行记录就是一个region（起始rowkey和regionserver）；但meta自身表的元数据信息存储在zookeeper的``/hbase/meta-region-server``中。

#### 查询数据过程

Client通过Rowkey查询到数据的过程: 

1. 首先Client通过RPC与ZK建立连接，获知/hbase/meta_region_server节点上记录的hbase:meta表所属RegionServer地址及region位置(简称metaRS、metaRigon)；

2. 然后Client通过RPC连接metaRS，在对应的metaRegion中查询Client提交的Rowkey所属的RegionServer地址及region位置(简称RowkeyRS、RowkeyRegion)；

3. 最后Client通过RPC连接RowkeyRS，在对应的RowkeyRegion中查出数据。



这次查询结果会缓存在Client，下次再查询时会根据缓存直接访问region；

#### 表结构

表的最开始和最结束都用空键标识；有空开始键的是表的第一个region；有空结束键的是表的最后一个region；开始和结束都是空键说明该表只有一个region。

```bash
###每个存放region的文件夹名 = region的rowkey的hash值
- RowKey:
    ###region id = 创建region时间戳 + . + encode(作为底层hdfs存储的子目录名)
    - Region Key 格式（[tablename],[region start rowkey],[region id]）
- Values:
    - info:regionInfo (.META.的HRegionInfo实例的序列化)
    - info:server（.META.的RegionServer的server:port）
    - info:serverStartCode（.META.的RegionServer进程的启动时间戳）
```

#### 存储数据

案列: meta表中会有namespace表的region分布信息。

```bash
hbase(main):024:0> scan 'hbase:meta'
ROW                               COLUMN+CELL
hbase:namespace,,xxx.yyy             column=info:regioninfo, timestamp=yyy, value={ENCODED => xxx, NAME => 'hbase:namespace,,yyy.xxx.', STARTKEY =>'', ENDKEY => ''}
hbase:namespace,,xxx.yyy             column=info:seqnumDuringOpen, timestamp=yyy, value=\x00\x00\x00\x00\x00\x00\x00\x08
hbase:namespace,,xxx.yyy             column=info:server, timestamp=yyy, value=Slave3:60020
hbase:namespace,,xxx.yyy             column=info:serverstartcode, timestamp=yyy, value=1523457000590
```




## 架构

### Client 

包含访问Hbase的接口，以及维护缓存加快对Hbase的访问。

在Client需要定位到所需的Region时，会先通过RPC连接ZK，通过查询存储在ZK上的.META.表找到Region的位置，然后RPC连接该Region的HRegionServer（而并不通过HMaster），最后发出读写请求。

这次查询结果会缓存在Client(cachedRegionLocations)，下次通过缓存省去查询元数据表的过程；但若HMaster的负载均衡器重新分配了region分布，或者RegionServer宕机，则对应的缓存就无效了，需要重新查询ZK中的.META.表以确定Region的新位置。

### ZK
 
zk的Master Election选举机制保证任何时刻集群中只有一个HMaster运行，当ZK不可用，Hbase系统整体不可用；
实时监控Hregionserver的状态（上线下线宕机等），并实时通知HMaster（HMaster会负载均衡重新分配region）；
存储``hbase:meta``表的元数据。

### HMaster

主要管理维护HRegionServer。

负责HRegionServer的负载均衡，负载均衡器``LoadBalancer``移动region以平衡集群负载；
故障转移，发现失效的HRegionServer，重新分配其上的region；
``Catalogjanitor``定期检查并清理.META.表。

当集群中的所有Master都不能正常工作会出现什么情况: 因为Client与ZK、RegionServer直接通信，另外``hbase:meta``表并不驻留在Master中，所以集群短时间内仍可以在“稳定状态”下运行；但是关键性功能仍需要Master控制，所以需要尽快恢复上线。 

Master会将管理操作、服务器运行状态记录到Master WAL文件中，该文件存储在MasterProcWALs目录下，WAL文件允许当建表或其他操作过程中出现Master故障，当备用Master顶上时可以继续之前未完成的操作；在Hbase2.0.0中开始引入新的AssignmentManager（AKA AMv2）而非1.X中依靠ZK。 

暴露``HMasterInterface``提供对元数据（table、CF、region）的DML操作方法:

```bash
Table (createTable, modifyTable, removeTable, enable, disable)

ColumnFamily (addColumn, modifyColumn, removeColumn)

Region (move, assign, unassign) 
```

### HRegionServer

主要管理和维护region。

``CompactSplitThread``检查Split和minor compaction；

``MajorCompactionChecker``检查major compaction；
 
``MemStoreFlusher``定期将MemStore中的写缓存刷入StoreFile；

暴露``HRegionServerInterface``提供对操作具体数据和维护region的方法 :

```bash
Data (get, put, delete, next, etc.)
    
Region (splitRegion, compactRegion, etc.) 
```


### HRegion

Hbase自动把表按行的方向水平划分成多个区域（region），每个region会保存一个表里某段连续的数据；
每个表一开始只有一个region，随着数据不断插入表，region不断增大，当增大到一个阀指，region会等分成两个新的region（裂变）；
当表的行不断增多，会有越来越多的region，这样一张完整的表会被保存到多个region上，这些region的元数据会保存在meta表中(记录着每个region对应分布在哪个regionserver上)；

region是hbase中分布式存储和负载均衡的最小单元，但不是存储的最小单元，单个region只属于某一个regionserver，除非裂变否则不可分割

memstore(内存空间 写缓存) storefile(具体的数据文件): 

### Store

每个Store对应一个表的一个列族的集中存储，所以根据业务可以将相同IO特性的列划分在同一列族内，实现高效的读写。



### MemStore

### StoreFile

### HFile


## 流程

客户端写入请求由RegionServer处理，写入数据会累积在Memstore中，然后从内存flush到StoreFile中，随着Store中StoreFile的累积，RegionServer会将这些StoreFile合并成数量更少、体积更大的StoreFile，每次flush、compact完成后，region中大量的StoreFile被改变；RegionServer会查询region的split策略以确定region是否过大，若需要split则将region split请求添加到队列。

### compact

#### minor compaction

通常选择少量小的、相邻的StoreFile进行小规模合并，重写成单个StoreFile；

但minor campaction 不会过滤掉那些已删除或过期的版本；

最终合并结果是每个store中会剩下较少、并且较大的StoreFile。

#### major compaction

合并过程会处理带删除标记过期的版本；

最终合并结果是每个store只包含一个StoreFile。


### split

![Hbase_region_split](/Users/stefan/Pictures/Hbase/Hbase_region_split.png)

虽然RegionServer在本地split region，但是split是一个多任务流程，需要其他角色参与共同协调完成；

RegionServer会在split前后通知Master更新，以便Client能查询到新的子region；并重新排列HDFS中的目录结构和数据文件。

#### split流程

1. 本地RegionServer在split的表上创建一个共享读锁(防止拆分过程中修改schema)，然后在ZK中创建一个当前拆分的region名(parentRegionName)的节点，并设置状态为SPLITING（``/hbase/region-in-transition/parentRegionName:SPLITING``）；

2. Master有一个watcher程序监听着ZK的``/hbase/region-in-transition``节点；

3. 本地RegionServer在HDFS的parentRegionName目录下创建一个``.splits``的子目录；

4. 本地RegionServer关闭当前拆分的parentRegion``closeRegion()``，在本地数据结构中将该region标记为离线不可用，访问该region的客户端请求将抛NotServingRegionException异常；

5. 在HDFS中，本地RegionServer在``.splits``目录下为拆分后的两个子region创建子目录，并创建必要的数据结构；然后拆分parentRegion中的所有Store（为parentRegion中的每一个Store都创建两个引用文件存储在各自的子目录中，所有引用文件全都指向parentRegion中的文件）

    ```bash
    .../parentRegionName/column_family/hfiles
        ||
        \/
    .../parentRegionName/column_family/hfiles
    .../parentRegionName/.splits/
        ||
        \/
    .../parentRegionName/column_family/hfiles
    .../parentRegionName/.splits/daughterA/
    .../parentRegionName/.splits/daughterB/
        ||
        \/
    .../parentRegionName/column_family/hfiles
    .../parentRegionName/.splits/daughterA/column_family/reference_files
    .../parentRegionName/.splits/daughterB/column_family/reference_files
    ```

6. 本地RegionServer在HDFS中创建实际的region子目录，然后将引用文件移动到对应的region子目录中；

    ```bash
    .../parentRegionName/column_family/hfiles
    .../parentRegionName/.splits/daughterA/column_family/reference_files
    .../parentRegionName/.splits/daughterB/column_family/reference_files
        ||
        \/
    .../parentRegionName/column_family/hfiles
    .../parentRegionName/.splits/daughterA/
    .../parentRegionName/.splits/daughterB/
    .../daughterA/column_family/reference_files
    .../daughterB/column_family/reference_files
    ```

7. 本地RegionServer向hbase:meta表发送一个put请求，设置parentRegion的offline=true，并添加子region的信息（此时hbase:meta表中还没有子region的记录，Client查询meta表只知道parentRegion处于split状态，并不知道子region的信息；一旦put请求未响应成功本地RegionServer就挂了，Master和下一个RegionServer会清除该parentRegion的split脏状态，当请求完成meta表完成了更新后本地RegionServer挂了，则由Master故障转移继续split）；

    Region Name|Location|split|offline|splitA|splitB
    ---|---|---|---|---|---
    parentRegion|local server|true|true|daughterA|daughterB

8. 本地RegionServer同时打开两个子region``openRegion()``；

9. 本地RegionServer将两个子region添加到hbase:meta表中，此时Client就可以请求查询新region了（之前的Client缓存将失效，会重新缓存meta表中的新region查询结果）；

    Region Name|Location|split|offline|splitA|splitB
    ---|---|---|---|---|---
    parentRegion|local server|true|true|daughterA|daughterB
    parentRegion|local server|false|false||
    parentRegion|local server|false|false||    

10. 本地RegionServer修改ZK中状态``/hbase/region-in-transition/parentRegionName:SPLIT``，出发Master中的watcher监听；如有必要，Master的负载均衡器也可以将子region转移到其他RegionServer上；

11. 当split完成后，hbase:meta和HDFS中子region仍然包含对parentRegion的引用，当子region中发生合并数据文件发生覆盖改变时，这些引用会被移除；Master中的GC任务会定期检查子region中是否还包含对parentRegion的引用，如果没有了GC就会彻底清除parentRegion。


##  读写


storefile 与 Hfile这两种文件存储的数据是一样的，前者hbase中的数据文件名称，后者是落地到HDFS中的数据名称。

```bash

在存储表数据时，有唯一行键rowkey将表分成很多块进行存储，每一块称为一个HRegion。
每个HRegion由一个或多个Store组成，每个Store保存表中一个列族的数据，
每个Store由一个MemStore和若干个StoreFile组成，
MemStore保存在内存中，默认配置是128M，
StoreFile的底层实现则是以HFile的形式存储在HDFS上。

1. HRegionServer对HRegion的管理：负责管理本服务器上的HRegion，处理对HRegion的I/O请求。
一台服务器上一般只运行一个HRegionServer，每个HRegionServer管理多个HRegion。
每台HRegionServer上有一个HLog文件，记录该HRegionServer上所有HRegion的数据更新备份。
2. Table的HRegion存储机制：每个table先只有一个HRegion，HRegion是HBase表数据存储分配的最小单位，
一张table的所有HRegion会分布在不同的HRegionServer上，但一个HRegion内的数据只会存储在一个HRegionServer上。
当客户端进行数据更新操作时，先连接有关的HRegionServer，由其向HRegion提交变更，
提交的数据会首先写入HLog和MemStore中的数据累计到设定的阈值时，HRegionServer会启动一个单独的线程，
将MemStore中的内容保存到磁盘上，生成一个新的StoreFile。当StoreFile文件的数量增长到设定值后，
就会将多个StoreFile合并成一个StoreFile，合并时会进行版本合并和数据删除。
说明一下，HBase平时一直在增加数据，所有的更新和删除操作都是在后续的合并过程中进行的。
当HRegion中单个StoreFile大小超过设定的阈值，HRegionServer会将该HRegion拆分为两个新的HRegion，
并且报告给主服务器，由HMaster来分配由哪些HRegionServer来存放新产生的两个HRgion，最后旧的HRegion不再需要时会被删除。
反过来，当两个HRegion足够小时，HBase也会将他们合并。


```

### 写过程

1. HLog

HLog(WAL log )作为预写日志，与一般的日志记录操作不同，它还会记录数据，类似MySQL中的binlog


### 读过程

数据读取顺序：
memstore(内存写缓存) -> blockcache（内存读缓存） -> hfile（hdfs 磁盘）







