---
title: ES进阶搜索API
date: 
tags:
- ES
- API
---

ElasticSearch 6.3.1 search Api.

<!--more-->

## 全数据检索

多索引或全索引检索``_all``一般很少使用，效率低且资源占用大；如电商搜索框中都会添加默认值或默认类别，避免无条件搜索。

```json
//每个节点上的每个分片搜索时最多耗时，只返回该时间段内查询到的数据，未查询完不影响正常返回
GET _all/_search?timeout=1ms
//多索引搜索,或通配符
GET index2016,index2017,index2018/_search 
GET index201*/_search

{
  "took": 6, //请求耗时（毫秒）
  "timed_out": false, //默认没有超时机制，等待ES搜索结束
  "_shards": {
    "total": 11, //请求发送到几个分片
    "successful": 11, //成功返回结果的分片数
    "skipped": 0, //停止服务的分片
    "failed": 0 //返回失败的分片
  },
  "hits": {
    "total": 30, //搜索到的总数
    "max_score": 1, //最大相关度评分
    "hits": [ //默认返回前10条
      {...},
      {...}
    ]
  }
}
```

全字段检索即不提供搜索字段名只提供一个关键字（如商品名、商品卖点、商品详情中都包含关键字【手机】），ES在保存document的同时会将所有的field值拼接，保存到一个``_all``的字段中；如上情况，则默认使用``_all``字段中的数据匹配搜索的关键字【手机】。

```json
PUT phone/xiaomi/1
{
  "sp_name": "小米手机MIX",
  "sp_sell": "全网5折优惠",
  "sp_desc": "MIX是全球第一款全面屏概念手机"
}

PUT phone/xiaomi/2
{
  "sp_name": "小米手机5",
  "sp_sell": "全网6折优惠",
  "sp_desc": "小米5使用当前性能性能最好的骁龙825"
}

//搜索关键字【概念】1条
GET phone/xiaomi/_search?q=%e6%a6%82%e5%bf%b5
//搜索关键字【骁龙】1条
GET phone/xiaomi/_search?q=%e9%aa%81%e9%be%99
//搜索关键字【优惠】2条
GET phone/xiaomi/_search?q=%e4%bc%98%e6%83%a0

//ES底层存储
{
  "sp_name": "小米手机MIX",
  "sp_sell": "全网5折优惠",
  "sp_desc": "MIX是全球第一款全面屏概念手机",
  "_all": "小米手机MIX 全网5折优惠 MIX是全球第一款全面屏概念手机"
}
```

但生产环境不推荐使用这种方式检索，因为数据越复杂，搜索效率越低。


## Query string

``_search?q=``此类型操作只适用于快速检索，若查询条件复杂，极难构建string查询条件，所以生产环境很少使用。

```json
GET index201801/type201801/_search?q=+name:stefan

GET index201802/type201802/_search?q=-name:mary&sort=age:desc
```

## Query DSL

此搜索操作适合构建复杂查询条件，生产环境常用。

```json
GET index201802/type201802/_search
{
  "query": {
    "match_all": {
    }
  }
}

//查询最近10天的记录
GET index201803/type201803/_search
{
  "query": {
    "range": {
      "sp_date": {
        "gte": "2018-02-19||-10d"
      }
    }
  }
}

GET index201802/type201802/_search
{
  "query": {
    "bool": {
      "must_not": [
        {
          "match": {
            "name": "stefan1"
          }
        },{
          "term": {
            "name.keyword": "stefan2"  
          }
        }
      ] 
    }
  },
  "sort": [
    {
      "age": "desc"
    }
  ],
  "from": 1,
  "size": 2,
  "_source": ["name","age","sex"]
}
```

## query与filter

query会计算搜索匹配相关度分数；filter不进行任何的匹配分数计算；filter效率相对高一些，query更适合复杂的条件搜索。

```json
GET index201802/type201802/_search
{
 "query": {
   "bool": {
     "must": [
       {
          "match": {
            "sex": "boy"
          }
       },{
         "range": {
           "age": {
             "gt": 10,
             "lte": 20
           }
         }
       }
     ]
   }
 } 
}

//性别、年龄都计入评分查询结果
{
  ...
  "hits": {
    "max_score": 1.1823215,
    "hits": [
      {
        ...
        "_score": 1.1823215,
      }
    ]
  }
}
```

```json
GET index201802/type201802/_search
{
 "query": {
   "bool": {
     "must": [
       {
          "match": {
            "sex": "boy"
          }
        }
      ],
      "filter": [
        {
          "range": {
            "age": {
              "gte": 10,
              "lte": 20
            }
          }
        }
      ]
    }
  } 
}

//性别计入、年龄不计入评分查询结果
{
  ...
  "hits": {
    "max_score": 0.18232156,
    "hits": [
      {
        ...
        "_score": 0.18232156,
      }
    ]
  }
}
```

```json
//只进行单纯的过滤数据，不做额外的搜索匹配（默认score=1）
GET phone1/huawei/_search
{
  "query": {
    "constant_score": {
      "filter": {
        "match" : {
          "sp_desc": "p9"
        }
      },
      "boost": 2
    }
  }
}
```

## match

``match``会根据搜索字段分词器分词，每个词条挨个匹配；``match_phrase``条件相当于keyword，词条不做分词必须完全匹配；``match_phrase_prefix``同样不做分词，匹配以搜索条件开头的词条。

```json
PUT phone
{
  "settings": {
    "number_of_shards": 3,
    "number_of_replicas": 1
  },
  "mappings": {
    "huawei": {
      "properties": {
        "sp_name": {
          "type": "keyword"
        },
        "sp_sell": {
          "type": "text"
        },
        "sp_desc": {
          "type": "text",
          "analyzer": "ik_max_word"
        }
      }
    }
  }
}


POST _bulk
{"index":{"_index":"phone","_type":"huawei","_id":1}}
{"sp_name":"华为p9","sp_sell":"20000","sp_desc":"华为p9属于商务旗舰机"}
{"index":{"_index":"phone","_type":"huawei","_id":2}}
{"sp_name":"荣耀2","sp_sell":"300","sp_desc":"荣耀2是一款便宜的低端价位手机"}
{"index":{"_index":"phone","_type":"huawei","_id":3}}
{"sp_name":"META1","sp_sell":"5000","sp_desc":"最大的卖点是机身超薄透亮"}


//匹配以该条件开头的词，匹配到【机 机身】
GET phone/huawei/_search
{
  "query": {
    "match_phrase_prefix": {
      "sp_desc": "机"
    }
  }
}
//必须完全匹配【旗舰机】
GET phone/huawei/_search
{
  "query": {
    "match_phrase": {
      "sp_desc": "旗舰机"
    }
  }
}
//条件分词后为【商务 低端 机】只要匹配其中一个词
GET phone/huawei/_search
{
  "query": {
    "match": {
      "sp_desc": "商务低端机"
    }
  }
}
```

```json
//multi match多字段匹配查询，搜索条件同样会根据不同字段分词器进行分词
GET phone/huawei/_search
{
  "query": {
    "multi_match": {
      "query": "华为荣耀",
      "fields": ["sp_desc","sp_name"]
    }
  }
}
```

## term

搜索条件不做分词，对搜索条件进行精确匹配。

```json
//terms 对一个字段进行多个条件匹配
GET phone1/huawei/_search
{
  "query": {
    "terms": {
      "sp_desc": [
        "华为",
        "荣耀"
      ]
    }
  }
}
```

## sort

ES默认使用相关度评分实现排序，（如果使用可分词的text类型字段排序会有问题，因为分词后先使用哪一个单词做排序是不固定的）；可以使用不分词的数字、日期、keyword等类型进行排序。

```json
GET phone/xiaomi/_search
{
  "query": {
    "match_all": {}
  },
  "sort": [
    {
      "sp.name": {
        "order": "desc"
      },
      "sp.date": "asc"
    }
  ]
}


{
 ...
  },
  "hits": {
    ...
      {
        ...
        "_source": {
          "sp.name": "xiaomi5",
          "sp.date": "2016-02-12"
        },
        "sort": [
          "xiaomi5",
          1455235200000
        ]
      },
      {
        ...
        "sort": [
          "xiaomi2s",
          1392163200000
        ]
      }
    ]
  }
}
```

[geo sort](https://www.elastic.co/guide/en/elasticsearch/reference/6.3/search-request-sort.html)




## 高亮显示器

[<font face="Times New Roman" color=#0099ff size=5>highlight for official</font>](https://www.elastic.co/guide/en/elasticsearch/reference/6.3/search-request-highlighting.html#plain-highlighter)

使用通配符查询时只有text和keyword类型字段会高亮显示；如果是自定义的mapping，想要高亮显示某字段就需要明确指定字段名。

高亮显示需要字段的值必须有实际的内容，如果字段内容只是存储在内存中(即mapping中store=false)，则highlighter会加载``_source``中对应字段的值（但``_all``字段无法获取只能是store=true才能提取）。

```bash
Highlighters don’t reflect the boolean logic of a query when extracting terms to highlight.
Thus, for some complex boolean queries (e.g nested boolean queries, queries using minimum_should_match etc.), 
parts of documents may be highlighted that don’t correspond to query matches.
```

1. 自定义高亮可以通过pre_tags和post_tags设置

```json
GET phone/huawei/_search
{
  "query": {
    ...
  },
  "highlight": {
    "fields": {
      "sp_*": { 
        "pre_tags":["<customize>"],
        "post_tags":["</customize>"]
      }
    }
  }
}
```

2. 默认情况下，只有包含query匹配的字段才会突出显示，可以设置为false以突出显示所有字段。

```json
{
  "query": {
    "bool": {
      "should": [
        {
          "match": {
            "sp_desc": "华为"
          }
        }
      ]
    }
  },
  "highlight": {
    "require_field_match":false, //默认true
    "fields": {
      "sp_name": {},
      "sp_desc": {}
    }
  }
}

###结果
{
  ...
  "hits": {
    "hits": [
      {
        ...
        "_score": 0.2876821,
        "_source": {
          "sp_name": "华为p20和小米20",
          "sp_desc": "华为p20属于商务旗舰机,小米20属于年度旗舰机"
        },
        "highlight": {
          "sp_name": [
            "<em>华为</em>"
          ],
          "sp_desc": [
            "<em>华为</em>p20属于商务旗舰机,小米20属于年度旗舰机"
          ]
        }
      }
    ]
  }
}
```


### unified highlighter

ES默认高亮显示器，将文本切分成句子，并使用BM25算法对这些句子评分，支持完整字段名、模糊、正则、前缀形式的字段名匹配。

```json
GET phone/huawei/_search
{
  "query": {
    "bool": {
      "should": [
        {
          "term": {
            "sp_name": "华为p9"
          }
        },
        {
          "match": {
            "sp_desc": "透亮"
          }
        }
      ]
    }
  },
  "highlight": {
    "fields": {
      "sp_*": { //匹配以sp_前缀的需要高亮显示的字段名
        "number_of_fragments": 1, //高亮显示片段数量，为0高亮显示返回整个字段内容，默认5
        "fragment_size": 1, //高亮显示片段的字符大小，为0高亮显示返回整个字段内容，默认100
        "no_match_size": 0 //没有匹配到高亮片段，则该查询字段不返回内容，默认0
      }
    }
  }
}


//查询高亮现显示结果
{
  ...
  "hits": {
    "total": 2,
    "max_score": 0.73050237,
    "hits": [
      {
        "_id": "3",
        "_score": 0.73050237,
        ...
        },
        "highlight": {
          "sp_desc": [
            "最大的卖点是机身超薄<em>透亮</em>"
          ]
        },
        {
        "_id": "1",
        "_score": 0.6931472,
        ...
        "highlight": {
          "sp_name": [
            "<em>华为p9</em>"
          ]
        }
      }
    ]
  }
}
```

### plain highlighter

```json
GET phone3/xiaomi/_search
{
  "query": {
    ...
  },
  "highlight": {
    "fields": {
      "sp_name": {
        "type": "plain" //强制高亮器类型
      }
    }
  }
}
```

### fvh fast-vector-highlighter

此高亮器对大文件性能更高；只能用于在mapping中将``term_vector``设置为``with_positions_offsets``的字段，会导致索引变大。

可以用``boundary_scanner``进行自定义；可以利用``matched_fields``将来自多个字段的匹配组合成一个结果；可以为不同的位置上的匹配分配不同的权重。

```json
PUT phone3
{
  "mappings": {
    "xiaomi": {
      "properties": {
        "sp_name": {
          "type": "text",
          "analyzer": "ik_max_word",
          "term_vector": "with_positions_offsets"
        }
      }
    }
  }
}

GET phone3/xiaomi/_search
{
  "query": {
    "bool": {
      "should": [
        {
          "match": {
            "sp_name": "小米"
          }
        }
      ]
    }
  },
  "highlight": {
    "fields": {
      "sp_name": {
        "type": "fvh"
      }
    }
  }
}
```


## explain

```json
GET phone/huawei/_search
{
  "explain": true, //返回结果中显示score的计算过程
  "query": {
    "constant_score": {
      "filter": {
        "match" : {
          "sp_desc": "p9"
        }
      }
    }
  }
}

"hits": [
  {
    "_shard": "[phone][0]",
    "_node": "sVU-XRYhQ_Gm2MpCa-gtIw",
    "_index": "phone",
    "_type": "huawei",
    "_id": "5",
    "_score": 2,
    "_source": {
      ...
    },
    "_explanation": {
      "value": 2,
      "description": "ConstantScore(sp_desc:p9 sp_desc:p sp_desc:9)^2.0",
      "details": []
    }
  }
]
```

```json
//校验查询搜索语法正确性
GET phone/huawei/_validate/query?explain
{
  "query": {
    "constant_score": {
      "filter": {
        "match" : {
          "sp_desc": "p9"
        }
      },
      "boost": 2
    }
  }
}

{
  ...
  "valid": true,
  "explanations": [
    {
      "index": "phone",
      "valid": true,
      "explanation": "+(ConstantScore(sp_desc:p9 sp_desc:p sp_desc:9))^2.0 #*:*"
    }
  ]
}
```

## score

### boost

ES5.0之前的版本可以在定义index时为field设置boost，但由于mapping无法修改除非重建索引，另外定义index时设置boost会存储在norm中会影响计算效率；所以ES5.0后只能在查询条件中添加boost属性(无需重建索引便可更改boost值)。

```json
PUT my_index
{
  "mappings": {
    "my_type": {
      "properties": {
        "title": {
          "type": "text",
          "boost": 2
        },
        "content": {
          "type": "text"
        }
      }
    }
  }
}
```

boost用于增加或降低查询子句的相对权重，默认为1，理论上一个高的boost值会产生一个高的_score。

```json
GET college_student/computer_major/_search
{
  "query": {
    "bool": {
      "filter": {
        "bool": {
          "must": {
            "match": {
              "years": {
                "query": "2015"
              }
            }
          }
        }
      },
      "must": [{
        "match": {
          "years": {
            "query": "2016",
            "boost": 2
          }
        }
      }]
    }
  }
}
```




## 聚合

```json
ERROR
"reason": "Fielddata is disabled on text fields by default. 
Set fielddata=true on [sp_desc] in order to load fielddata in memory by uninverting the inverted index. 
Note that this can however use significant memory. Alternatively use a keyword field instead."


GET phone/huawei/_search
{
  "size": 0, //返回结果中显示几条记录，0代表不显示查询内容
  "aggs": {
    "sum_sell": {
      "sum": {"field": "sp_sell"}
    }
  }
}

{
  "took": 3,
  "timed_out": false,
  "_shards": {
    "total": 5,
    "successful": 5,
    "skipped": 0,
    "failed": 0
  },
  "hits": {
    "total": 5,
    "max_score": 0,
    "hits": []
  },
  "aggregations": {
    "sum_sell": {
      "value": 19500
    }
  }
}
```