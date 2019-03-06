---
title: ES底层案例剖析
date: 
tags:
- ES
---

ElasticSearch 6.3.1 Analysis of the underlying principle.

<!--more-->

## ES特性

ES不支持事务。

ES属于近实时搜索：写入的数据默认1s后才能被搜索到；但是GET请求读取内存中还未持久化到磁盘的translog，通过_id可以实现实时查询（但也不能实现实时的条件查询）。

合理分配副本数：ES文档写入主要是写主分片和同步副本分片，副本数多会影响写入性能；ES读取文档是根据算法随机读取某一个分片，副本数多有利于负载均衡，提高并发读性能。

translog和副本分片保障segment的安全性：写入buffer后立即写translog，写入buffer后1s刷入segment，立即刷入os cache 打开segment清除buffer，同时发送请求同步副本分片，所以当主分片挂了，主副本分片间存在1s的数据丢失可能（translog需要5s刷入磁盘）。

## Filter

由于Filter不会计算搜索条件相关度分数，也不会根据相关度分数进行排序，且filter内置cache，自动缓存常用的filter bitset数据以提升过滤速度，所以Filter的效率相对较高。


```json
POST /_bulk
{ "create" : { "_index" : "college_student" , "_type" : "computer_major", "_id" : "1" } }
{"years" : "2011 2012 2013 2014"}
{ "create" : { "_index" : "college_student" , "_type" : "computer_major", "_id" : "2" } }
{"years" : "2010 2011 2012 2013"}
{ "create" : { "_index" : "college_student" , "_type" : "computer_major", "_id" : "3" } }
{"years" : "2012 2013 2014 2015"}
{ "create" : { "_index" : "college_student" , "_type" : "computer_major", "_id" : "4" } }
{"years" : "2009 2010 2011 2012"}
{ "create" : { "_index" : "college_student" , "_type" : "computer_major", "_id" : "5" } }
{"years" : "2013 2014 2015 2016"}

GET college_student/computer_major/_search
{
  "query": {
    "bool": {
      "should": [{
        "constant_score": {
          "filter": {
            "term": {
              "years": "2009"
            }
          },
        "boost": 10
        }
      },{
        "constant_score": {
          "filter": {
            "term": {
              "years": "2010"
            }
          },
        "boost": 20
        }
      }]
    }
  }
}

//大致结果 A matching pool clause would add a score of 2, while the other clauses would add a score of only 1 each.
{
  ...
  },
  "hits": {
    "total": 2,
    "max_score": 30,
    "hits": [
      {
        "_id": "4",
        "_score": 30,
        "_source": {
          "years": "2009 2010 2011 2012"
        }
      },
      {
        "_id": "2",
        "_score": 20,
        "_source": {
          "years": "2010 2011 2012 2013"
        }
      }
    ]
  }
}
```

|模拟倒排索引|term word|document list|
---|---|---
||2009|4|
||2010|2，4|
||2011|1，2，4|
||2012|1，2，3，4|
||2013|1，2，3，5|
||2014|1，3，5|
||2015|3，5|
||2016|5|

ES会为每个filter在倒排索引中搜索到的结果构建一个bitset(二进制的数组,0不符合1符合,为了用最简单的数据结构来描述搜索结果以节省内存开销)，所以ES会为上述2个filter分别构建2个``bitset``，ES的存储顺序(不是_id或其他字段的排序)可以通过_search全搜索查看，当前索引文档的存储顺序为【5，2，4，1，3】，

|filter.term|document.list|存储顺序|bitset|
---|---|---|---
|2009|4|5,2,4,1,3|0,0,1,0,0|
|2010|2,4|5,2,4,1,3|0,1,1,0,0|

如上一个search中存在多个filter时，会按1的稀疏程度的顺序遍历多个bitset，尽可能一次性过滤掉最多不符合条件的document。

ES在返回搜索结果的同时会将部分bitset数据缓存到内存中（并发操作），后续有相同filter条件搜索时直接使用内存中的bitset过滤数据提高查询效率，正是由于bitset的缓存filter的执行效率比query高；

bitset缓存机制：最近的256个filter中执行次数达到一定量（如固定时间内搜索超过多少次）；若索引中document少于1k则不缓存，索引分段数据不足索引整体数据的3%也不缓存。

filter执行特性：ES会先执行filter（ES先检查内存中是否有该filter的bitset缓存）后执行query，首先filter执行效率高，能快速过滤掉不符合搜索条件的数据，其次这些被filter过滤掉的数据也避免了在query时进行的相关度分数计算和排序，又提高了效率；同时ES实现bitset cache auto_update以解决缓存与存储数据更改后不一致的问题，当document数据被更改后，ES会自动更新缓存的bitset以保证有效性。


## reindex + 0停机

1. what

重建索引就是将现有索引中的文档复制到包含新设置的新索引中。

系统停机包括：前端系统、服务系统、数据缓存系统、数据文件存储系统等，设计系统时要考虑0停机避免生产环境出现。

2. why

当现有索引的设置已经不满足需求，尽管索引可以增加新类型（5.x及以下），或增加新字段到类型中，但是不能添加新的分析器或者修改已有字段，否则索引数据错误无法提供正常搜索，所以需要重建索引。

客户端应用程序中如果是直接访问索引名，在重建索引后就需要修改代码，所以需要实现0停机。

3. how

先用``scroll``从现有索引中批量检索文档，后用``bulk API``将文档插入新索引中，以实现reindex。

引入索引别名``_alias``，索引别名同时指向现有索引名和新索引名，在应用程序中访问索引别名，以解决重建索引后更改应用代码问题，实现0停机。


## Document路由机制

ES使用routing算法管理Document，决定Document存放在哪一个主分片上。

如果是写操作：计算routing结果后，决定本次写操作定位到哪一个主分片上，主分片写成功后，自动同步到对应replica shard上。
如果是读操作：计算routing结果后，决定本次读操作定位到哪一个主分片或其对应的replica shard上；实现读负载均衡，replica shard数量越多，并发读能力越强。

```bash
//routing field默认为Document的_id
primary shard = hash(routing field) % number_of_primary_shards

//自定义routing field
PUT /index_name/type_name/id?routing=xxx
```

手工指定routing field在操作海量数据情景中非常有用，自定义的routing field可以将相关联的Document存储在同一个shard中，方便后期进行应用级别的负载均衡并可以提高数据检索的效率。
如：将商品类型的编号作为routing field，等同于将同一类型的商品document数据，存入同一shard中；在一个shard上查询同一类型的商品效率最高。


## Document写入原理

ES为了实现NRT近实时搜索，结合了内存buffer、系统缓存、磁盘三种存储方式。

在lucene中一个index是分为若干个segment（分段），每个segment都会存放index中的部分数据；ES的底层基于lucene，ES将一个index先分解成若干shard，每个shard中使用若干segment存储具体数据。

1. 客户端发起增删改请求，将请求发送到ES中（随机请求一台作为协调节点，根据路由规则判断在主分片的节点上操作）。

2. ES将本次请求中要操作的document写入到buffer中（然后发送同步数据的请求到副本分片的其他节点）。ES为了保证搜索的近实时NRT，设置默认每秒刷新一次buffer。

```json
//通过命令触发buffer刷新
POST /test_index/_refresh

//修改buffer的自动刷新时间
PUT test_index
{
  "settings": {
    "number_of_shards": 5,
    "number_of_replicas": 1,
    "refresh_interval": "30s" //默认1s
  }
}
```

3. ES在将document写入到buffer后，将本次操作写入内存中的translog file中（数据库则相反是先写日志后数据写入内存）。

4. ES每秒刷新buffer中的数据保存到index segment中（刚创建时存储在内存中的file文件）。

5. index segment完成数据保存后，会被立刻写入到系统缓存中，index segment在写入系统缓存后立刻被打开（不必等到segment写入磁盘后再打开segment，因为写入磁盘是一个相对较重的IO操作），以为满足近实时NRT的搜索请求，同时buffer中的数据被清空。

6. ES默认每5秒执行一次translog文件的持久化（保持长IO提高访问效率）；当持久化时刚好有document写入操作在执行，此次持久化操作会等待写操作彻底完成后才执行；如果允许部分数据丢失，可以通过修改translog的持久化方式为异步操作。

```json
PUT test_index
{
  "settings": {
    "number_of_shards": 5,
    "number_of_replicas": 1,
    "index.translog.durability" : "async",
    "index.translog.sync_interval" : "5s"
  }
}
```

7. 磁盘中translog文件会不断增大，当日志文件大到一定程度或默认每30分钟，ES执行一次完整的commit操作：（将buffer数据刷新到一个新的index segment中；将index segment写入到OS cache中并打开index segment提供搜索服务；清空buffer；将OS cache中所有的index segment标识记录到commit point中并持久化到磁盘；这些被记录在commit point中的index segment会被fsync持久化到磁盘；最后清空本次持久化的index segment在translog文件中对应的日志内容）。


## merge

1. why

每秒会生成一个segment文件，每30分钟都会将这些segment文件持久化到磁盘中，那么磁盘中的segment文件数量会非常多，每个segment都会占用文件句柄，内存资源，cpu资源；而且每个搜索请求的数据可能分布在多个segment中，ES会检索所有已打开的segment，所以segment越多会影响搜索的效率。

2. how

ES有一个后台进程专门负责segment的merge操作，选择一些大小相近的segment文件（可以是磁盘中已commit的，也可以是内存中还未commit的）merge成一个大segment文件，merge过程中搜索服务不会受影响，同时被标记为deleted状态的document会被物理删除；当执行一个commit操作，commit point除了记录OS cache中需要持久化的segment外，还记录了merge后的segment文件及merge前的原segment文件；commit完成后将merge后的segment打开提供搜索服务，并将merge前的旧segment关闭并删除。

3. setting

```bash
//单个分片上一次merge使用的最大线程数
index.merge.scheduler.max_thread_count
默认值 Math.max(1, Math.min(4, Runtime.getRuntime().availableProcessors() / 2)) 适用于良好的固态磁盘（SSD）

index.merge.policy.floor_segment 默认 2MB，小于这个大小的 segment，优先被归并。
index.merge.policy.max_merge_at_once 默认一次最多归并 10 个 segment
index.merge.policy.max_merge_at_once_explicit 默认 forcemerge 时一次最多归并 30 个 segment。
index.merge.policy.max_merged_segment 默认 5 GB，大于这个大小的 segment，不用参与归并。forcemerge 除外。

减少 segment 归并的消耗以及提高响应的办法：加大 flush 间隔，尽量让每次新生成的 segment 本身大小就比较大。

既然默认的最大 segment 大小是 5GB。那么一个比较庞大的数据索引，就必然会有为数不少的 segment 永远存在，这对文件句柄，内存等资源都是极大的浪费。
但是由于归并任务太消耗资源，所以一般不太选择加大 index.merge.policy.max_merged_segment 配置，而是在负载较低的时间段，通过 forcemerge 接口，强制归并 segment。

POST index20180412/_forcemerge?max_num_segments=1

由于 forcemerge 线程对资源的消耗比普通的归并线程大得多，所以，绝对不建议对还在写入数据的热索引执行这个操作。一般索引按天分割就比较好操作。
```


4. deleted

index中删除和更新操作都不是即时的物理删除，都是先标记document为deleted状态，当ES空闲时或存储空间不足时或merge时，一次性删除deleted状态的document。

在执行删除或更新操作的时候，同样将deleted状态的document写入buffer中，在buffer数据写入segment时，会生成一个.del文件（记录这些deleted document在哪个segment），执行search时如果同id不同版本的document在多个segment时，会依据.del文件来过滤查询结果，保证搜索结果正确性。

