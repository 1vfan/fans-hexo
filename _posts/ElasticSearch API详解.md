---
title: ElasticSearch API详解
date: 2017-05-08 21:22:42
tags:
- ElasticSearch
- API
categories: 
- ELK
---
记录ElasticSearch5.4.0 API的详细使用介绍

<!--more-->

# Mapping 映射

Mapping映射一旦创建无法修改，只能删除对应索引重新制定（除了keyword类型的ignore_above属性可修改），可以新增.

```bash
#ignore_above只适用于keyword类型
PUT /school/_mapping/student
{
  "properties": {
    "sex": {"type": "keyword", "ignore_above": 10}
  }
}
```

```bash
GET /school/_mapping

GET /school/_settings
```


## 静态映射

可以添加mappings中预先未定义的字段，如下``"sex": "male"``；注意规定``"format": "epoch_millis"``日期格式不匹配会报错，可以添加多种日期格式以``||``隔开；``"settings"``中分片与副本数不设定默认为5和1.

```bash
DELETE /school

PUT /school
{
  "settings": {
    "number_of_shards": 3,
    "number_of_replicas": 1
  },
  "mappings": {
    "student": {
      "properties": {
        "name": {"type": "keyword"},
        "age": {"type": "long"},
        "brithday": {"type": "date", "format": "yyyy-MM-dd||epoch_millis"}
      }
    }
  }
}

PUT /school/student/2
{
  "name": "李四",
  "age": 24,
  "brithday": 1582938098478,
  "sex": "male"
}

GET /school/student/2
GET /school/student/2/_source
```

通过在根对象上将``date_detection``设置为false来关闭日期检测.

```bash
PUT /school/_mapping/student
{
  "date_detection": false
}
```

## 动态映射

在预定义Mapping中可以设置``dynamic``属性的值：

* "dynamic": "strict"  若输入陌生字段（即Mappings预先未定义）则无法保存并报错
* "dynamic": false  若输入陌生字段，该字段会被忽略
* "dynamic": true  默认为true，同静态映射，可以添加陌生字段

如下，``student``对象中``"dynamic": "strict"``，则不能添加陌生字段否则报错；而``others``同样是一个对象，其中规定``"dynamic": true``，所以在``others``中可以添加陌生字段.

```bash
DELETE /school

PUT /school
{
  "settings": {
    "number_of_shards": 3,
    "number_of_replicas": 1
  },
  "mappings": {
    "student": {
      "dynamic": "strict",
      "properties": {
        "name": {"type": "keyword"},
        "age": {"type": "long"},
        "brithday": {"type": "date", "format": "epoch_millis"},
        "others": {
          "type": "object",
          "dynamic": true,
          "properties": {
            "height": {"type": "long"},
            "weight": {"type": "float"}
          }
        }
      }
    }
  }
}

PUT /school/student/2
{
  "name": "lisi",
  "age": 13,
  "brithday": 1582938098478,
  "others": {
    "height": 175,
    "weight": 55.5,
    "blood": "AB"
  }
}
```

Mapping虽然不能修改字段的类型，但是可以新增字段类型（注意: 同一索引不同type下，相同的字段名的类型要保持一致）.

```bash
#在已建立索引的mapping中添加字段类型
PUT /school/_mapping/student
{
  "properties": {
    "sex": {"type": "keyword"}
  }
}

#在object类型字段下添加子字段类型
PUT /school/_mapping/student
{
  "properties": {
    "others": {
      "properties": {
        "sex": {"type": "keyword"}
      }
    }
  }
}

#在已建立索引的Mapping中添加object对象
PUT /school/_mapping/student
{
  "properties": {
    "parents": {
      "properties": {
        "father": {"type": "text"},
        "mother": {"type": "text"}
      }
    }
  }
}
```

# Template 模板

模板的存在避免一些映射相同的索引重复的创建映射，只需要建立一个模板，所有索引共享这一个模板中设置的映射（多出现在以时间为单位的索引，如每天的日志）.

```bash
DELETE /_template/log_template
DELETE /log_*

#设置模板
PUT /_template/log_template
{
  "template": "log_*",
  "settings": {
    "number_of_shards": "2",
    "number_of_replicas": "2"
  },
  "mappings": {
    "day_logs": {
      "_source": {
        "enabled": true
      },
      "properties": {
        "time": {"type": "date", "format": "yyyy-MM-dd||epoch_millis"},
        "level": {"type": "keyword"},
        "info": {"type": "keyword"}
      }
    }
  }
}

#新增数据（索引名要符合设置的模板格式: log_）
PUT /log_20180301/day_logs/1
{
  "time": "2018-03-01",
  "level": "error",
  "info": "runtimeException..."
}

PUT /log_20180302/day_logs/1
{
  "time": "2018-03-02",
  "level": "warning",
  "info": "can be integer..."
}

GET /log_20180301/day_logs/1/_source
GET /log_*/_mapping,_settings
GET /_template/log_template
```

可以设定模板的优先级，``order``越大，则优先级越高.

```bash
PUT /_template/log_template
{
  "template": "*",
  "order": 0,
  "settings": {
    "number_of_shards": 3,
    "number_of_replicas": 1
  },
  "mappings": {
    "day_logs": {
      "_source": {
        "enabled": false 
      }
    }
  }
}


PUT /_template/log_template
{
  "template": "log_*",
  "order": 1,
  "settings": {
    "number_of_shards": 2,
    "number_of_replicas": 1
  },
  "mappings": {
    "day_logs": {
      "_source": {
        "enabled": true 
      }
    }
  }
}
```


# 地理位置

ES中采用``geo_point``类型保存地理位置信息.

```bash
DELETE /building

PUT /building
{
  "mappings": {
    "info": {
      "properties": {
        "name": {"type": "keyword"},
        "address": {"type": "text"},
        "location": {"type": "geo_point"}
      }
    }
  }
}

#object类型添加经纬度
PUT /building/info/1
{
  "name": "zhangsan",
  "address": "浙江省江干区彭埠镇1号",
  "location": {
    "lon": 120.33333333,
    "lat": 30.33333333
  }
}

#String类型添加经纬度（注意纬度在前、经度在后）
PUT /building/info/2
{
  "name": "lisi",
  "address": "浙江省西湖区三墩镇129号",
  "location": "30.99999999, 120.444444444" 
}

#[]格式添加经纬度（经度在前、纬度在后）
PUT /building/info/3
{
  "name": "wangwu",
  "address": "浙江省下城区三河镇48号",
  "location": [121.99999999, 30.22222222] 
}
```

矩形范围查询（top_left:lon小lat大、bottom_right:lon大lat小）.

```bash
GET /building/_search
{
  "query": {
    "geo_bounding_box": {
      "location": {
        "top_left": {
          "lon": 120.0000,
          "lat": 31.0000
        },
        "bottom_right": {
          "lon": 121.0000,
          "lat": 30.0000
        }
      }
    }
  }
}
```

以经纬度为圆心，在以指定距离为半径的圆形范围内查询.

```bash
GET /building/_search
{
  "query": {
    "bool": {
      "must": {
        "match_all": {}
      },
      "filter": {
        "geo_distance": {
          "distance": "100km",
          "location": {
            "lon": 120.0000,
            "lat": 30.0000
          }
        }
      }
    }
  }
}
```

在以多点围成的特殊多边形区域内查询.

```bash
GET /house/_search
{
  "query": {
    "bool": {
      "must": {
        "match_all": {}
      },
      "filter": {
        "geo_polygon": {
          "location": {
            "points": [
              {"lat": 30.0000, "lon": 120.0000},
              {"lat": 31.0000, "lon": 120.3333},
              {"lat": 31.0000, "lon": 121.0000}
            ]
          }
        }
      }
    }
  }
}
```


# 创建

创建索引时不设置分片副本，默认会产生5个分片，1个副本；一旦索引创建就不允许修改分片和副本的数量，报400
```bash
创建索引前先删除，如果原先有就正常删除，原先没有会报错404
DELETE /school
返回结果：
{
  "error": {
    "root_cause": [
      {
        "type": "index_not_found_exception",
        "reason": "no such index",
        "index_uuid": "_na_",
        "resource.type": "index_or_alias",
        "resource.id": "school",
        "index": "school"
      }
    ],
    "type": "index_not_found_exception",
    "reason": "no such index",
    "index_uuid": "_na_",
    "resource.type": "index_or_alias",
    "resource.id": "school",
    "index": "school"
  },
  "status": 404
}

设置索引分片和副本
PUT  /school
{
    "settings": {
        "index": {
                "number_of_shards": 5,
                "number_of_replicas": 1
        }
    }
}
返回结果：
{
  "acknowledged": true,
  "shards_acknowledged": true
}

在head插件中查看school索引
```

创建文档，注意时间格式默认是ISO_8601日期格式标准，也可使用从1970年到现在的毫秒数，也可使用yyyy-MM-dd HH:mm:ss，支持20多种时间格式

```bash
PUT创建文档，给定ID
PUT /school/student/1
{
   "name": "zhangsan",
   "age": 25,
   "course": "elasticsearch",
   "study_date": "2017-06-15T20:30:50+0800"
}
返回结果：
{
  "_index": "school",
  "_type": "student",
  "_id": "1",
  "_version": 1,
  "result": "created",
  "_shards": {
    "total": 2,
    "successful": 2,
    "failed": 0
  },
  "created": true
}

POST创建文档，自动生成ID（20位的GUID）
POST /school/student/
{
   "name": "lisi",
   "age": 26,
   "course": "springboot",
   "study_date": "2017-06-17T20:30:50+0800"
}
返回结果：
{
  "_index": "school",
  "_type": "student",
  "_id": "AV06rACDC-QEShWIFVS1",
  "_version": 1,
  "result": "created",
  "_shards": {
    "total": 2,
    "successful": 2,
    "failed": 0
  },
  "created": true
}

在head插件中‘数据浏览’查看索引school的数据信息
```

创建一个完全新的文档，如果文档存在，则更新索引，_version会自增；PUT或POST都可以

```bash
PUT /school/student/1
{
   "name": "zhangsan",
   "age": 25,
   "course": "elasticsearch",
   "study_date": "2017-06-15T20:30:50+0800"
}
返回结果：
{
  "_index": "school",
  "_type": "student",
  "_id": "1",
  "_version": 2,
  "result": "updated",
  "_shards": {
    "total": 2,
    "successful": 2,
    "failed": 0
  },
  "created": false
}
```

强制创建一个完全新的文档，如果文档存在，则报错，需要更改ID；PUT或POST都可以

```bash
PUT /school/student/1/_create
{
   "name": "zhangsan",
   "age": 25,
   "course": "elasticsearch",
   "study_date": "2017-06-15T20:30:50+0800"
}
返回结果：
{
  "error": {
    "root_cause": [
      {
        "type": "version_conflict_engine_exception",
        "reason": "[student][2]: version conflict, document already exists (current version [1])",
        "index_uuid": "6HCSHO59RN-qvm5np2S3Xg",
        "shard": "2",
        "index": "school"
      }
    ],
    "type": "version_conflict_engine_exception",
    "reason": "[student][2]: version conflict, document already exists (current version [1])",
    "index_uuid": "6HCSHO59RN-qvm5np2S3Xg",
    "shard": "2",
    "index": "school"
  },
  "status": 409
}
```

获取文档信息

```bash
有对应ID的文档，found=true，返回文档信息
GET /school/student/2
返回结果：
{
  "_index": "school",
  "_type": "student",
  "_id": "2",
  "_version": 1,
  "found": true,
  "_source": {
    "name": "zhangsan",
    "age": 25,
    "course": "elasticsearch",
    "study_date": "2017-06-15T20:30:50+0800"
  }
}

没有对应ID的文档，found=false
GET /school/student/3
返回结果：
{
  "_index": "school",
  "_type": "student",
  "_id": "3",
  "found": false
}

也可以通过POST自动生成的ID获取文档信息
GET /school/student/AV06rACDC-QEShWIFVS1
返回结果：
{
  "_index": "school",
  "_type": "student",
  "_id": "AV06rACDC-QEShWIFVS1",
  "_version": 1,
  "found": true,
  "_source": {
    "name": "lisi",
    "age": 26,
    "course": "springboot",
    "study_date": "2017-06-17T20:30:50+0800"
  }
}
```

检查文档是否存在，有返回200，没有返回404

```bash
HEAD /school/student/2
返回结果：
200 - OK

HEAD /school/student/3
返回结果：
404 - Not Found
```

获取文档，指定字段，逗号分隔

```bash
GET /school/student/1?_source=name,age
返回结果：
{
  "_index": "school",
  "_type": "student",
  "_id": "1",
  "_version": 7,
  "found": true,
  "_source": {
    "name": "zhangsan",
    "age": 25
  }
}

仅获取source字段内容，不指定字段，/_source
GET /school/student/1/_source
返回结果：
{
  "name": "zhangsan",
  "age": 25,
  "course": "elasticsearch",
  "study_date": "2017-06-15T20:30:50+0800"
}

?_source 与 /_source的区别
GET /school/student/1?_source
返回结果：
{
  "_index": "school",
  "_type": "student",
  "_id": "1",
  "_version": 8,
  "found": true,
  "_source": {
    "name": "zhangsan",
    "age": 100,
    "course": "elasticsearch",
    "study_date": "2017-06-15T20:30:50+0800"
  }
}
```

# 更新

在Elasticsearch中文档是不可改变和修改的；如果想要更新现有的文档，需要重建索引或者进行替换；Elasticsearch在内部将旧文档标记为已删除，并增加一个全新的文档；尽管不能再对旧版本的文档进行访问，但它并不会立即消失；当继续索引更多的数据时，Elasticsearch会在后台清理这些已删除文档

```bash
更新文档
PUT /school/student/1
{
   "name": "zhangsan",
   "age": 100,
   "course": "elasticsearch",
   "study_date": "2017-06-15T20:30:50+0800"
}
返回结果：
{
  "_index": "school",
  "_type": "student",
  "_id": "1",
  "_version": 8,
  "result": "updated",
  "_shards": {
    "total": 2,
    "successful": 2,
    "failed": 0
  },
  "created": false
}

注意version的变化
GET /school/student/1
返回结果：
{
  "_index": "school",
  "_type": "student",
  "_id": "1",
  "_version": 8,
  "found": true,
  "_source": {
    "name": "zhangsan",
    "age": 100,
    "course": "elasticsearch",
    "study_date": "2017-06-15T20:30:50+0800"
  }
}
```

使用_update API的方式更新部分字段

```bash
POST /school/student/1/_update
{
  "doc": {
    "age": 23,
    "sex": "men",
    "name": "Stefan"
  }
}
返回结果：
{
  "_index": "school",
  "_type": "student",
  "_id": "1",
  "_version": 12,
  "result": "updated",
  "_shards": {
    "total": 2,
    "successful": 2,
    "failed": 0
  }
}

GET /school/student/1
返回结果：
{
  "_index": "school",
  "_type": "student",
  "_id": "1",
  "_version": 12,
  "found": true,
  "_source": {
    "name": "Stefan",
    "age": 23,
    "course": "elasticsearch",
    "study_date": "2017-06-15T20:30:50+0800",
    "sex": "men"
  }
}
```

下图显示在更新文档后，新增字段 ‘sex’ 会自动添加到文档中

![png1](/img/20170508_1.png)

使用脚本更新，脚本语言可以是painless（默认），Groovy，类似javascript

```bash
POST /school/student/1/_update
{
   "script" : {
      "lang": "painless",
      "inline":"ctx._source.age+=1"
   }
}
返回结果：
{
  "_index": "school",
  "_type": "student",
  "_id": "1",
  "_version": 13,
  "result": "updated",
  "_shards": {
    "total": 2,
    "successful": 2,
    "failed": 0
  }
}

可以看到更新后age结果+1
GET /school/student/1/_source
返回结果：
{
  "name": "Stefan",
  "age": 24,
  "course": "elasticsearch",
  "study_date": "2017-06-15T20:30:50+0800",
  "sex": "men"
}
```

通过脚本添加或修改某个字段，内置支持的语言：painless、groovy

```bash
javascript插件安装
# bin/elasticsearch-plugin install lang-javascript
python插件安装
# bin/elasticsearch-plugin install lang-python
```

```bash
POST /school/student/1/_update
{
   "script" : {
      "lang": "painless",
      "inline":"ctx._source.sex='male'"
   }
}

通过脚本移除某个字段
POST /school/student/1/_update
{
   "script" : "ctx._source.remove('sex')"
}

传参数params
POST /school/student/1/_update
{
  "script": {
    "lang": "painless",
    "inline": "ctx._source.name = params.name ",
    "params": {
      "name": "zhangsan"
    }
  }
}
```

# 并发控制

通过指定版本号进行更新，只更新指定版本的文档
```bash
PUT /school/student/1?version=1
{
   "name": "zhangsan",
   "age": 26,
   "course": "elasticsearch",
   "study_date": "2017-06-15T20:30:50+0800"
}

#采用外部版本号，可以更新比当前版本号大的文档
#外部版本号，必须是大于0的long型整数
#external or external_gte
PUT /school/student/1?version=10&version_type=external
{
   "name": "zhangsan",
   "age": 26,
   "course": "elasticsearch",
   "study_date": "2017-06-15T20:30:50+0800"
}


#新版本增加update by query,默认是1000条
POST /school/_update_by_query?scroll_size=1000&conflicts=proceed
{
  "script": {
    "inline": "ctx._source.name6='abc'",
    "lang": "painless"
  },
  "query": {
    "term": {
      "name": "zhangsan"
    }
  }
}

```

# 删除

注意delete也有version字段，即使文档不存在，version也会增加，这样的好处就是跨多个分布式节点时，保证结果的正确性

```bash
DELETE /school/student/1
#不可以删除一个type，下面的命令是错误的
DELETE /school/student
#可以直接删除一个索引
DELETE /school
GET /school/student/1

#新版本重新加入了delete by query
POST school/student/_delete_by_query?conflicts=proceed
{
  "query": {
    "match_all": {}
  }
}
```

# 搜索

```bash
空搜索
GET /_search

获取所有文档，默认返回前10条
GET /school/student/_search
```

分页查询

```bash
第1页
GET /school/student/_search?size=2

第2页
GET /school/student/_search?size=2&from=2
```

轻量搜索

```bash
查询结果集中去除给定字段值的结果：如去除name=wangwu或lisi的结果
GET /school/student/_search?q=-name:wangwu,lisi
或
GET /school/student/_search?q=-name:(wangwu lisi)
返回结果：
{
  "took": 15,
  "timed_out": false,
  "_shards": {
    "total": 5,
    "successful": 5,
    "failed": 0
  },
  "hits": {
    "total": 1,
    "max_score": 1,
    "hits": [
      {
        "_index": "school",
        "_type": "student",
        "_id": "1",
        "_score": 1,
        "_source": {
          "name": "Stefan",
          "age": 24,
          "course": "elasticsearch",
          "study_date": "2017-06-15T20:30:50+0800",
          "sex": "men"
        }
      }
    ]
  }
}

查询结果集中包含给定字段，不区分大小写
GET /school/student/_search?q=springBOOT
返回结果：
{
  "took": 11,
  "timed_out": false,
  "_shards": {
    "total": 5,
    "successful": 5,
    "failed": 0
  },
  "hits": {
    "total": 1,
    "max_score": 0.27233246,
    "hits": [
      {
        "_index": "school",
        "_type": "student",
        "_id": "AV06rACDC-QEShWIFVS1",
        "_score": 0.27233246,
        "_source": {
          "name": "lisi",
          "age": 26,
          "course": "springboot",
          "study_date": "2017-06-17T20:30:50+0800"
        }
      }
    ]
  }
}


GET /school/student/_search?q=%2Bstudy_date:<2018-06-17+%2Bname:(zhangsan lisi)
返回结果：
{
  "took": 21,
  "timed_out": false,
  "_shards": {
    "total": 5,
    "successful": 5,
    "failed": 0
  },
  "hits": {
    "total": 1,
    "max_score": 1.287682,
    "hits": [
      {
        "_index": "school",
        "_type": "student",
        "_id": "AV06rACDC-QEShWIFVS1",
        "_score": 1.287682,
        "_source": {
          "name": "lisi",
          "age": 26,
          "course": "springboot",
          "study_date": "2017-06-17T20:30:50+0800"
        }
      }
    ]
  }
}
```

批量获取scoll scan

```bash
可以改变size来制定返回的结果集数量
GET school/_search?scroll=1m
{
  "query": {
    "match_all": {}
  },
  "sort": [
    "_doc"
  ],
  "size": 2
}
返回结果：
{
  "_scroll_id": "DnF1ZXJ5VGhlbkZldGNoBQAAAAAAAA4RFmVCY0Zhc2hnUnZpbFN6bmQ0LVFxWVEAAAAAAAAOERZrOWJhbjRFWVJ5bVhBSGNETUVZYWZnAAAAAAAADg8WazliYW40RVlSeW1YQUhjRE1FWWFmZwAAAAAAAA4SFmVCY0Zhc2hnUnZpbFN6bmQ0LVFxWVEAAAAAAAAOEBZrOWJhbjRFWVJ5bVhBSGNETUVZYWZn",
  "took": 8,
  "timed_out": false,
  "_shards": {
    "total": 5,
    "successful": 5,
    "failed": 0
  },
  "hits": {
    "total": 3,
    "max_score": null,
    "hits": [
      {
        "_index": "school",
        "_type": "student",
        "_id": "2",
        "_score": null,
        "_source": {
          "name": "wangwu",
          "age": 23,
          "course": "elasticsearch",
          "study_date": "2017-06-15T20:30:50+0800",
          "sex": "men"
        },
        "sort": [
          0
        ]
      },
      {
        "_index": "school",
        "_type": "student",
        "_id": "1",
        "_score": null,
        "_source": {
          "name": "Stefan",
          "age": 24,
          "course": "elasticsearch",
          "study_date": "2017-06-15T20:30:50+0800",
          "sex": "men"
        },
        "sort": [
          0
        ]
      }
    ]
  }
}


GET /_search/scroll
{
    "scroll" : "1m", 
    "scroll_id" : "DnF1ZXJ5VGhlbkZldGNoBQAAAAAAAA3yFmVCY0Zhc2hnUnZpbFN6bmQ0LVFxWVEAAAAAAAAN8RZrOWJhbjRFWVJ5bVhBSGNETUVZYWZnAAAAAAAADfAWazliYW40RVlSeW1YQUhjRE1FWWFmZwAAAAAAAA3zFmVCY0Zhc2hnUnZpbFN6bmQ0LVFxWVEAAAAAAAAN8hZrOWJhbjRFWVJ5bVhBSGNETUVZYWZn" 
}
返回结果：
{
  "_scroll_id": "DnF1ZXJ5VGhlbkZldGNoBQAAAAAAAA3yFmVCY0Zhc2hnUnZpbFN6bmQ0LVFxWVEAAAAAAAAN8RZrOWJhbjRFWVJ5bVhBSGNETUVZYWZnAAAAAAAADfAWazliYW40RVlSeW1YQUhjRE1FWWFmZwAAAAAAAA3zFmVCY0Zhc2hnUnZpbFN6bmQ0LVFxWVEAAAAAAAAN8hZrOWJhbjRFWVJ5bVhBSGNETUVZYWZn",
  "took": 107,
  "timed_out": false,
  "terminated_early": false,
  "_shards": {
    "total": 5,
    "successful": 5,
    "failed": 0
  },
  "hits": {
    "total": 3,
    "max_score": null,
    "hits": []
  }
}
```

搜索某一个特定字段

```bash
搜索某一个字段存在值
GET school/_search
{
    "query": {
        "exists" : { "field" : "name" }
    }
}
返回结果：
{
  "took": 185,
  "timed_out": false,
  "_shards": {
    "total": 5,
    "successful": 5,
    "failed": 0
  },
  "hits": {
    "total": 3,
    "max_score": 1,
    "hits": [
      {
        "_index": "school",
        "_type": "student",
        "_id": "2",
        "_score": 1,
        "_source": {
          "name": "zhangsan",
          "age": 25,
          "course": "elasticsearch",
          "study_date": "2017-06-15T20:30:50+0800"
        }
      },
      {
        "_index": "school",
        "_type": "student",
        "_id": "1",
        "_score": 1,
        "_source": {
          "name": "Stefan",
          "age": 24,
          "course": "elasticsearch",
          "study_date": "2017-06-15T20:30:50+0800",
          "sex": "men"
        }
      },
      {
        "_index": "school",
        "_type": "student",
        "_id": "AV06rACDC-QEShWIFVS1",
        "_score": 1,
        "_source": {
          "name": "lisi",
          "age": 26,
          "course": "springboot",
          "study_date": "2017-06-17T20:30:50+0800"
        }
      }
    ]
  }
}

搜索某一个字段不存在值
GET school/_search
{
    "query": {
        "bool": {
            "must_not": {
                "exists": {
                    "field": "sex"
                }
            }
        }
    }
}
返回结果：
{
  "took": 27,
  "timed_out": false,
  "_shards": {
    "total": 5,
    "successful": 5,
    "failed": 0
  },
  "hits": {
    "total": 1,
    "max_score": 1,
    "hits": [
      {
        "_index": "school",
        "_type": "student",
        "_id": "AV06rACDC-QEShWIFVS1",
        "_score": 1,
        "_source": {
          "name": "lisi",
          "age": 26,
          "course": "springboot",
          "study_date": "2017-06-17T20:30:50+0800"
        }
      }
    ]
  }
}
```