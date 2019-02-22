---
title: ElasticSearch之调用Java API实现索引检索
date: 2017-05-06 22:01:23
tags:
- ElasticSearch
- java
categories:
- ELK
---
<font color=#ff0000>warning：</font>ElasticSearch5.X版本需要JDK1.8的支持，而且Linux服务器端安装的JDK版本需要和Java IDE中使用的JDK版本同步，否则会报错.

<!--more-->

# 创建Maven项目添加依赖 

> Eclipse中创建Maven项目并在pom.xml中添加依赖，Maven会自动导入所有需要的Jar包

```bash
  <dependencies>
        <dependency>
            <groupId>org.elasticsearch.client</groupId>
            <artifactId>transport</artifactId>
            <version>5.1.1</version>
        </dependency>
        <dependency>
            <groupId>org.apache.logging.log4j</groupId>
            <artifactId>log4j-api</artifactId>
            <version>2.7</version>
        </dependency>
        <dependency>
            <groupId>org.apache.logging.log4j</groupId>
            <artifactId>log4j-core</artifactId>
            <version>2.7</version>
        </dependency>
    </dependencies>
```

# 配置log4j

> 配置log4j，用于console控制台打印出日志信息

```bash
appender.console.type = Console
appender.console.name = console
appender.console.layout.type = PatternLayout

rootLogger.level = info
rootLogger.appenderRef.console.ref = console
```

# ElasticSearch创建索引

* 服务器上启动ElasticSearch

```bash
[root@es-master ~]# su elsearch
[elsearch@es-master root]$ cd /elasticsearch5.1/
[elsearch@es-master elasticsearch5.1]$ ./bin/elasticsearch -d
[elsearch@es-master elasticsearch5.1]$ ps aux | grep elastic
```

* 创建索引

```bash
[elsearch@es-master elasticsearch5.1]$ curl -XPUT "http://192.168.0.200:9200/index"
```

* 添加文档

```bash
[elsearch@es-master elasticsearch5.1]$ curl -XPUT "http://192.168.0.200:9200/index/document/1" -d '{ "name":"stefan", "like":"foliage", "blog":"https://1vfan.github.io/" }'
```

* 创建成功

```bash
[elsearch@es-master elasticsearch5.1]$ curl -XPUT "http://192.168.0.200:9200/index"
{"acknowledged":true,"shards_acknowledged":true}
[elsearch@es-master elasticsearch5.1]$ curl -XPUT "http://192.168.0.200:9200/index/document/1" -d '{ "name":"stefan", "like":"foliage", "blog":"https://1vfan.github.io/" }'
{"_index":"index","_type":"document","_id":"1","_version":1,"result":"created","_shards":{"total":2,"successful":1,"failed":0},"created":true}
```

# 程序代码

```bash
package com.zjnx.es;

import java.net.InetAddress;
import org.elasticsearch.action.get.GetResponse;
import org.elasticsearch.client.transport.TransportClient;
import org.elasticsearch.common.settings.Settings;
import org.elasticsearch.common.transport.InetSocketTransportAddress;
import org.elasticsearch.transport.client.PreBuiltTransportClient;

public class TestEsClient {
	public static void main(String[] args) {
        try {
            //添加集群名称、节点名称等信息
            Settings settings = Settings.builder().put("cluster.name", "es-test").put("node.name", "es-test-node").put("client.transport.sniff",true).build();
            //创建client
            TransportClient client = new PreBuiltTransportClient(settings)
			        .addTransportAddress(new InetSocketTransportAddress(InetAddress.getByName("192.168.0.200"), 9300));
            //检索索引数据
            GetResponse response = client.prepareGet("index", "document", "1").execute().actionGet();
            System.out.println(response.getSourceAsString());
            //关闭client
            client.close();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
```

# 打印结果

```bash
no modules loaded
loaded plugin [org.elasticsearch.index.reindex.ReindexPlugin]
loaded plugin [org.elasticsearch.percolator.PercolatorPlugin]
loaded plugin [org.elasticsearch.script.mustache.MustachePlugin]
loaded plugin [org.elasticsearch.transport.Netty3Plugin]
loaded plugin [org.elasticsearch.transport.Netty4Plugin]
{ "name":"stefan", "like":"foliage", "blog":"https://1vfan.github.io/" }
```