---
title: ES基础API
date: 
tags:
- ES
- API
---

ElasticSearch 6.3.1 basic Api.

<!--more-->

## 健康状态

```json
GET _cluster/health

{
  "cluster_name": "es-arcgis",
  "status": "green",
  "timed_out": false,
  "number_of_nodes": 3,
  "number_of_data_nodes": 3,
  "active_primary_shards": 6,
  "active_shards": 12,
  "relocating_shards": 0,
  "initializing_shards": 0,
  "unassigned_shards": 0,
  "delayed_unassigned_shards": 0,
  "number_of_pending_tasks": 0,
  "number_of_in_flight_fetch": 0,
  "task_max_waiting_in_queue_millis": 0,
  "active_shards_percent_as_number": 100
}

GET _cat/health?v
```

status|desc
---|---
green|all index's primary shard and replica shard is active
yellow|all index's primary shard is active, but part replica shard isn't active
red|not all index's primary shard is active, so ES can't use

## 磁盘限制

可以通过如下API动态修改ES节点对磁盘剩余空间的限制(要求``low > high``)：

```json
PUT _cluster/settings
{
  "transient": {
    "cluster.routing.allocation.disk.watermark.low": "80%",
    "cluster.routing.allocation.disk.watermark.high": "90%"
  }
}

GET _cluster/settings
```

disk|desc|default|result
---|---|---|---
low|磁盘容量最小使用率|85%|停止分配 replica shard
high|磁盘容量最大使用率|90%|停止分配 all shard


## 索引分片

创建索引时可以设置分片(6.x版本默认5 primary、1 replica)；索引创建后主分片数禁止修改，副本分片可以修改；ES的内置算法保证索引的主分片均匀分布在多个节点上，同时副本分片不与对应的主分片分配在同一节点上。

```json
GET _cat/indices?v
GET _cat/shards?v

PUT /index201801
{
  "settings": {
    "number_of_shards": 3,
    "number_of_replicas": 1
  }
}

GET /index201801/_settings

PUT /index201801/_settings
{
  "number_of_replicas": 2
}
```

## 倒排索引

ES的索引不可变是因为倒排索引不可变，写入磁盘后再也不能修改。

|索引不可变的好处|索引不可变的坏处|
|---|---|
|不需要锁，因为不存在并发修改数据|倒排索引不可变，导致索引不可变|
|提高读性能，索引被内核文件系统做了缓存，可直接从内存中读|索引结构发生任何变化都需要重新构建整个索引|
|提升其他缓存性能，如filter缓存在索引生命周期内一直驻留内存||
|通过压缩，节省cpu计算和磁盘io开销||

## 自动识别

### 文档识别

新增document时，对应的index或type不存在，都会自动创建。

```json
{
  "_index": "index201801",
  "_type": "type201801",
  "_id": "2", //不指定会自动分配
  "_version": 1,
  "result": "created",
  "_shards": {
    "total": 3, //只提示主分片
    "successful": 3, //文档在主分片存储状态
    "failed": 0
  },
  "_seq_no": 0, //执行的序列号
  "_primary_term": 1 //词条对比
}
```

### 字段数据类型识别

|类型|默认映射|
---|---
|数字|long|
|浮点|double|
|文本|text|
|日期|date|
|true/false|boolean|
|文本默认子类型|keyword|
|分词器|standard|


## 元数据

元数据记录着ES的核心数据，一般``_``开头

```json
{
  "_index": "index201801",
  "_type": "type201801",
  "_id": "1",
  "_version": 1,
  "_source": {
    "name": "stefan"
  }
}
```

|元数据|desc|
---|---
|_index|名称必须是小写的，且不能以_、-、+开头|
|_type|6.x一个index只能定义一个type，大小写无要求，不能_开头；6.x前可以定义多个|
|_id|同一个索引中不可重复|
|_version|从1开始，任何对document的修改删除操作都会+1|
|_score|搜索评分|
|_source|document中的field数据|
|_alias|_index的别名|
|_all|代表所有的索引，较少使用|
|_shards|操作时返回的分片信息|

## 索引别名

一个索引别名可以指向多个索引，一个索引可以被多个索引别名指向。

主要应用于重建索引和索引分组：建议在应用中使用别名而非索引名，在运行的集群中可以无缝的从一个索引切换到另一个索引；也可以给多个索引分组，如电商搜索（华为手机索引、小米手机索引），使用国产手机作为两个索引的别名来实现分组，下次搜索国产手机就可以在以上两个索引中搜索数据。

```json
//建别名
PUT phone_xiaomi/_alias/phone_cn
PUT phone_huawei/_alias/phone_cn

//别名指向哪些索引
GET */_alias/phone_cn

//索引被哪些别名指向
GET phone_xiaomi/_alias/*
```

一个别名可以指向多个索引，所以为新索引添加别名的同时，必须从旧的索引中删除它，这个操作需要原子化，使用``_aliases``操作。

```json
POST _aliases
{
  "actions": [
    {
      "remove": {
        "index": "old_index",
        "alias": "alias_index"
      }
    },
    {
      "add": {
        "index": "new_index",
        "alias": "alias_index"
      }
    }
  ]
}
```


## CURD文档

### 新增文档

ES手动指定``_id``新增document用``PUT``，如果从RDBMS中读取数据到ES中，可以手动指定PK作为id，但建议不要将多个表新增到同一个inde可能出现id冲突；

ES自动生成``_id``新增document用``POST``，否则报错``Incorrect HTTP method for uri [/index201801/type201801] and method [PUT], allowed: [POST]"``，自动分配的id是一串长度20、经过base64安全编码、支持分布式高并发的字符串，该方式适合手工输入保存的数据，通过系统分配避免id冲突。

```json
PUT index201801/type201801/2
{
  "age": 24,
  "name": "stefan",
  "datetime": "2018-01-02"
}

POST index201801/type201801
{
  "age": 24,
  "name": "stefan",
  "datetime": "2018-01-02"
}
```

使用PUT手动指定``_id``时，可能出现``_id``已经存在，执行后相当于替换之前的数据，如果不希望在新增时误替换可以使用``_create``，会提示``error: version conflict, document already exists``。

```json
PUT index201801/type201801/2/_create
{
  "age": 24,
  "name": "stefan",
  "datetime": "2018-01-02"
}
```

### 查询文档

批量查询相较于单个查询能显著提高查询效率，推荐使用。

```json
HEAD index201801/type201801/3 //200 or 404
GET index201801/type201801/3
GET index201801/type201801/5/_source
GET index201801/type201801/5?_source=name,age

GET index201801/type201801/_mget
{
  "docs": [{
    "_id": 1
  },{
    "_id": 2
  },{
    "_id": 5
  }]
}

GET _mget
{
  "docs": [
    {
      "_index": "index201801",
      "_type": "type201801",
      "_id": 3
    },{
      "_index": "index201802",
      "_type": "type201802",
      "_id": "NzB35GcBv55NNTbZVsZ1"
    }]
}
```

### 修改文档

ES中的文档是不可改变的，只能替换或重建索引；与新增类似，修改同样分成PUT、POST两种方式。

|修改方式|相同点|不同点|具体不同操作|
---|---|---|---
|PUT|不会真的修改document数据，先标记ES中原document为deleted|全量覆盖|只存储提交的新数据|
|POST|然后创建新document存储新数据，两者底层执行没有大差别|增量替换|新数据与未更新的原数据组成最终存储数据|

```json
PUT index201801/type201801/2
{
  "age": 30,
  "name": "mary",
  "datetime": "2018-02-01"
}

POST index201801/type201801/2/_update
{
  "doc": {
    "name": "stefan"
  }
}
```

### 删除文档

ES删除索引和文档，都是先将其标记为deleted状态（为了NRT近实时），并不是立即进行物理删除，deleted状态并不会被查询搜索到；等到ES存储空间不足或工作空闲时，进行物理删除。

```json
DELETE index201801/type201801/1
```

``delete by query``在1.x中原生支持，2.x中提取为插件，5.x后重新回归原生支持。

```json
POST　index201801/type201801/_delete_by_query
{
  "query": {
    "match": {
      "sex": "boy"
    }
  }
}

POST index201801/type201801/_delete_by_query
{
  "query": {
    "terms": {
      "age": [18,19]
    }
  }
}

POST　index201801/type201801/_delete_by_query?conflicts=proceed
{
  "query": {
    "match_all": {}
  }
}
```

### 批量增删改

|action_type|desc|
---|---
|index|普通新增或全量覆盖 PUT /index/type/id|
|create|强制新增 PUT /index/type/id/_create|
|update|增量替换 POST /index/type/id/_update|
|delete|删除 DELETE /index/type/id|

``_bulk``语法要求一个完整的json串不能换行，不同json串必须换行分隔，批量中多个操作互不影响，某个操作有错误不影响其他操作成功执行，每个操作都有各自的执行返回信息；

``_bulk``语法如果不对json格式做特殊限制，那么当数据量很大时，对json解释处理、对象转换所需的内存占用量将非常大，加上java GC进程频繁回收，会极大的影响ES效率；

``_bulk``操作语法执行时，会将所有的request一次性加载到内存中，如果数据量太大，反而会增加内存压力使性能下降，需要反复尝试出合适的``bulk request size``；

在实际应用中，会使用``_bulk``语法的java api代替循环操作，如批量插入10000条数据。

```json
POST _bulk
{"index":{"_index":"index201803","_type":"type201803","_id":"3"}}
{"name":"stefan1","age":20}
{"create":{"_index":"index201803","_type":"type201803","_id":"3"}}
{"name":"stefan2"}

"index" successful  --  "create" error：document already exists 可见批量执行上面执行后的结果会影响下面的执行

POST _bulk
{"update":{"_index":"index201803","_type":"type201803","_id":"3"}}
{"doc":{"name":"stefan3","date":"2018-01-03"}}
{"delete":{"_index":"index201803","_type": "type201803","_id":"1"}}
```

###  通过脚本更新

可以通过ES的内置脚本或插件安装脚本更新document中某个字段，如默认的``painless``、``Groovy``，也可以安装``sudo bin/elasticsearch-plugin install lang-javascript`` 、``sudo bin/elasticsearch-plugin install lang-python``。

6.x中建议用``source``替换5.x中的元字段名``inline``，``Deprecated field [inline] used, expected [source] instead``。

```json
POST index201802/type201802/1/_update
{
  "script": {
    "lang": "painless",
    "inline": "ctx._source.age+=1"
  }
}

POST index201802/type201802/1/_update
{
  "script": {
    "lang": "painless",
    "source": "ctx._source.sex='girl'"
  }
}

POST index201802/type201802/1/_update
{
  "script": "ctx._source.remove('age')"
}

POST index201802/type201802/1/_update
{
  "script": {
    "lang": "painless",
    "source": "ctx._source.name=params.new_name",
    "params": {
      "new_name": "mary"
    }
  }
}
```

### 匹配更新

``_update_by_query``结合脚本实现批量更新。

```json
###使用该conflicts选项来防止reindex在版本冲突中进程中止
POST index201801/_update_by_query?conflicts=proceed
{
  "script": {
    "source": "ctx._source.name = params.new_name; ctx._source.sex = params.new_sex",
    "params": {
      "new_name": "stefan",
      "new_sex": "boy"
    }
  },
  "query": {
    "bool": {
      "should": [
        {
          "match": {
            "sex": "BOY"
          }
        },{
          "term": {
            "name.keyword": "Mary"
          }
        },{
          "range": {
            "age": {
              "gte": 10,
              "lte": 30
            }
          }
        }
      ]
    }
  }
}

###逐个查询是使用批处理实现的，任何故障都会导致整个进程中止，但当前批处理中的所有故障都会被收集到数组中
{
  "took": 22, //整个操作毫秒数
  "timed_out": false, 
  "total": 1,
  "updated": 1,
  "deleted": 0,
  "batches": 1, //查询更新拉回的滚动响应数
  "version_conflicts": 0, //查询更新的版本冲突数
  "noops": 0, //按查询更新的脚本返回的noop值
  "retries": { //重试的搜索操作的数量
    "bulk": 0,
    "search": 0
  },
  "throttled_millis": 0, //请求睡眠符合的毫秒数
  "requests_per_second": -1, //查询更新期间有效执行的每秒请求数
  "throttled_until_millis": 0,
  "failures": []
}
```

## 分页from+size

``from+size``适合少量数据分页查询，简单易用，大量数据场景中不仅速度慢且会极大的增加内存CPU的压力，JVM老年代被迅速占满导致full GC存在OOM风险。

```json
GET index201801/_search?pretty
{
  "size": 2, //默认10
  "from": 2  //默认0
}

GET index201801/type201801/_search?size=100000&from=2

//size大小不能超过【index.max_result_window】，默认10000
ERROR: Result window is too large, from + size must be less than or equal to: [10000]
```

查询场景：客户端向协调节点请求1000页（每页10条），协调节点会将请求分发到所有主分片（假设5个），每个主分片上取前10010条返回给A节点，协调节点会将50050条数据全部加载到内存，然后根据默认排序条件（_score）对这些数据做排序，将前10条返回给客户端，丢弃剩下50040条数据，每次执行都重复整个过程。在分布式系统中，排序的花费随着分页的深入成倍增加。

## 滚动scroll

``scroll``并不是替代``from+size``的高效分页方案，一般为系统内部处理进行按顺序分批提供数据（如重建索引）；因为scroll在大量数据场景中按顺序分批查询性能是很好的，但如果无规则的翻页对性能的消耗也是极大的。

scroll会在第一次搜索后保存一个快照（保存的时长自定义），后续查询会基于此快照再次查询，搜索过程中如果ES的document发生变化，不会影响原搜索结果；可以使用``_doc``实现排序，性能较高；
自第一次搜索后，再次发起搜索需在第一次快照存活时间内有效，且需指定快照存活时间及``_scroll_id``。

```json
GET /t_index/_search?scroll=1m
{
  "query": {
    "match_all": {}
  },
  "sort": [ "_doc" ],
  "size" : 1
}

GET /_search/scroll
{
  "scroll" : "1m", //距下一次scroll的有效时间
  "scroll_id" : "根据具体返回结果替换"
}
```


## Mapping

``Mapping``即自动或手动的为index的type建立一种数据结构和相关配置；Mapping决定了index中的field的特征(存储数据格式、分词器、子字段、是否copy to其他字段)。

### dynamic mapping

``dynamic mapping``即ES会自动为我们创建index、type、mapping、field类型、文本子字段、文本分词器等。

```json
GET index201801/_mapping

{
  "index201801": {
    "mappings": {
      "type201801": {
        "properties": {
          "name": { //字段名称，包括字段类型、子字段列表、类型、分词器等
            "type": "text", //默认文本类型
            "fields": { //子字段列表
              "keyword": { //ES默认为文本字段提供一个子字段名称keyword
                "type": "keyword", //不做分词的文本类型
                "ignore_above": 256 //默认最长存储字符
              }
            }
          }
        }
      }
    }
  }
}
```

通过自定义配置mapping中``dynamic``参数，管理不在mapping范围的新增陌生字段；一般使用在索引的数据结构固定不变的业务情景。

|dynamic|desc|
---|---
|true|默认值，可以添加陌生字段，自动dynamic mapping|
|false|可以添加陌生字段，会保存数据，但是不会dynamic mapping，不做倒排索引无法搜索|
|"strict"|添加陌生字段直接报错 error: mapping set to strict|

```json
PUT index201801/_mapping/type201801
{
  "dynamic": "strict"
}

PUT index201802
{
  "mappings": {
    "type201802": {
      "dynamic": "strict",
        "properties": {
          "name": {
            "type": "keyword"
          },
          "others": {
            "type": "object",
            "dynamic":  true,
            "properties": {
            	 "like": {
            	   "type": "text"
            	 }
            }
          }
        }
    }
  }
}
```

### custom mapping

``custom mapping``即在创建index和type时，手工定义field类型与text的分词器等；只能追加mapping，一旦生效不可修改。

```json
PUT index201801
{
  "settings": {
    "number_of_shards": 3,
    "number_of_replicas": 1
  },
  "mappings": {
    "type201801": {
      "properties": {
        "recipientUserId": {
          "type": "integer",
          "index": false //是否作为搜索索引
        },
        "recipientUserName": {
          "type": "text",
          "analyzer": "ik_smart"
        },
        "recipientContent": {
          "type": "text",
          "analyzer": "ik_max_word"
        },
        "recipientEnDesc": {
          "type": "text",
          "analyzer": "standard",
          "fields": {
            "keyword": {
              "type": "keyword",
              "ignore_above": 256
            }
          }
        },
        "updateTime": {
          "type": "date",
          "format": "yyyy-MM-dd"
        },
        "others": {
          "properties": {
            "name": {
              "type": "keyword"
            }
          }
        }
      }
    }
  }
}


PUT index201801/_mapping/type201801
{
  "properties": {
    "others": {
      "properties": {
        "age": { //mapping添加新字段
          "type": "byte"
        }
      }   
    }
  }
}
```

## 常用复杂类型field

### multi field

如果一个field包含多个值，如数组；但这种数据与普通数据类型并无区别，只是要求第一次创建索引时该field中的所有值类型必须一致。

```json
PUT index201801/type201801/1
{
  "name": "stefan",
  "like": ["sport","movie","eatting"]
}
```

### null field

ES为索引自动创建mapping时，陌生field的值为空（null、[]、[null]），虽然有保存数据为空，但是不会dynamic mapping；任何mapping定义过的field都可以保存空数据。

```json
PUT index201801/type201801/1
{
  "name": "stefan",
  "age": null
}
```

### object field

``object``类型底层存储``对象+数组``数据使用特定格式。

```json
PUT index201801/type201801/1
{
  "name": "stefan",
  "likes": {
    "sport": ["basketball", "football", "tennis"],
    "movie": ["love", "action"]
  }
}

"name": "stefan",
"likes.sport": ["basketball", "football", "tennis"],
"likes.movie": ["love", "action"]

PUT index201802/type201802/1
{
  "ops": "emp",
  "emps": [
    {"name": "stefan1", "age": 20},
    {"name": "stefan2", "age": 22},
    {"name": "stefan3", "age": 24}
  ]
}

"ops": "emp",
"emps.name": ["stefan1", "stefan2", "stefan3"],
"emps.age": [20, 22, 24]
```


## 注意点

6.x中一个index只能有一个type
Rejecting mapping update to [index201801] as the final mapping would have more than 1 type: [type201801, type201802]

在ES中，一个index中的所有type类型的Document是存储在一起的，如果index中的不同的type之间的field差别太大，也会影响到磁盘的存储结构和存储空间的占用。如：test_index中有test_type1和test_type2两个不同的类型，type1中的document结构为：{"_id":"1","f1":"v1","f2":"v2"}，type2中的document结构为：{"_id":"2","f3":"v3","f4":"v4"}，那么ES在存储的时候，统一的存储方式是{"_id":"1","f1":"v1","f2":"v2","f3":"","f4":""}, {"_id":"2","f1":"","f2":"","f3":"v3","f4","v4"}、建议，每个index中存储的document结构不要有太大的差别。尽量控制在总计字段数据的10%以内。


mapping的root object就是设置index的mapping时，一个type对应的json数据。包括的内容有：properties， metadata（_id, _source, _all）,  settings（分词器等）。其中字段配置include_in_all已在6.x版本中删除。_all配置将在7.x版本中删除。


```json
#! Deprecation: [_all] is deprecated in 6.0+ and will be removed in 7.0. As a replacement, you can use [copy_to] on mapping fields to create your own catch all field.

PUT /index201801
{
  "settings": {
    "number_of_replicas": 1,
    "number_of_shards": 3
  }, 
  "mappings": {
    "type201801": {
      "_all": {"enabled":false},
      "_source": { "enabled":false},
      "dynamic": "true",
      "properties": {
        "title": {
          "type": "text",
          "index": false
        },
        "name": {
          "type": "keyword"
        }
      }
    }
  }
}
```

## 日期


ES在6.x版本中，对date类型数据进行了搜索优化，会为同年数据创建一个默认搜索数据（如2018-01-01），而不是将2018-01-01分词为2018、01、01三个数据。
而这种搜索日期必须完全匹配，搜索文本可以模糊匹配的搜索方式也称为：exact value（精确匹配）、full text（全文搜索）。