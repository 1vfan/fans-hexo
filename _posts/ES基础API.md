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


