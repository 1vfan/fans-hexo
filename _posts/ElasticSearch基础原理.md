---
title: ElasticSearch基础原理深入理解
date: 2017-04-02 19:43:01
tags:
- ElasticSearch
categories: 
- ELK
---
记录深入理解ElasticSearch基础运作及内部机理

<!--more-->


* 传输客户端（transport client）:
轻量级的传输客户端，本身不加入集群，将请求转发到远程集群中的某个节点上

* 节点客户端（node client）：
cluster.node: false
data.node: false
它作为一个非数据节点加入到本地集群中，也就是说，本身不保存数据，但是它知道请求的数据在集群的哪个节点上，并将通过传输客户端将请求转发到正确的节点上

> restful API with JSON over HTTP
所有其他语言都可以使用restful API通过9200端口和ElasticSearch进行通信，可以用web客户端（浏览器、Kibana、head）、curl命令（linux）等方式与ElasticSearch交互


> 关于文档更新
* 在 Elasticsearch 中文档是 不可改变 的，不能修改它们； 相反，如果想要更新现有的文档，需要 重建索引 或者 进行替换
* 在内部，Elasticsearch 已将旧文档标记为已删除，并增加一个全新的文档 
* 尽管你不能再对旧版本的文档进行访问，但它并不会立即消失；当继续索引更多的数据，Elasticsearch 会在后台清理这些已删除文档

待完善补充


	