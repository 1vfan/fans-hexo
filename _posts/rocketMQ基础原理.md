---
title: rocketMQ之深入理解底层实现
date: 2017-06-17 22:13:45
tags:
- rocketMQ
categories: 
- rocketMQ
---

记录rocketMQ入门基础以及底层原理实现

<!--more-->

## 模块介绍

```bash
rocket-client：客户端，包含producer和consumer端，发送和接收消息的过程；

rocket-store：存储服务，包括消息、索引、commitlog存储；

rocket-broker：对于producer和consumer来说是服务端，接收producer发送的数据并存储，consumer来此拉取数据；

rocket-namesrv：NameServer，保存着消息的TopicName、队列等运行时的meta信息；
               （一般系统会分Namenode和dataNode，这里NameServer属于NameNode）
               
rocket-remoting：用Netty4写的客户端和服务端，fastjson做的序列化，自定义二进制协议；

rocket-srvutil：只有ServerUtil类，只提供server程序依赖，为了拆解以减少client的依赖；

rocket-filtersrv：消息过滤器server，使用一个独立的模块对数据进行过滤；

rocket-common：通用的常量枚举、基类方法、数据结构等；

rocket-tools：命令行工具；
```

## 拓扑图

![png1](/img/20170617_1.png)

NameServer：不做任何消息的位置储存；可集群部署，节点间无任何信息同步

```bash
在2.x版本使用zookeeper做分布式协调和服务发现，后来发现添加队列时注册机制不太好，加一个队列必须要到zookeeper上注册（频繁操作zookeeper的位置储存数据会影响整体集群性能）；
所以在3.x后使用轻量级的NameServer代替zookeeper（activeMQ和kafka都是用的zookeeper），做高可用的路由（注册Client服务和Broker中间的请求路由工作）；
producer连接的是NameServer，消息数据通过NameServer路由到某一个Broker上存储，所以每次启动rocketmq先启动所有的NameServer再启动Broker
```

Broker：真正储存消息数据的地方

```bash
Broker分为Master和Slave，一对多的对应关系，通过指定相同的BrokerName和不同的BrokerId来对应；
BrokerId=0表示Master，!=0表示Slave；Master同样可以部署多个；
每个Broker同NameServer集群中的所有节点建立长连接，定时注册Topic信息到所有的NameServer上
```

Produser和Consumer

```bash
Producer（可集群部署）和NameServer集群中的其中一个节点（随机选择）建立长连接，定期从NameServer中获取Topic路由信息，
与提供Topic服务的Master建立长连接，定时向Master发送心跳；

Consumer和NameServer集群中的其中一个节点（随机选择）建立长连接，定期从NameServer中获取Topic路由信息，
与提供Topic服务的Master、Slave 建立长连接，定时向Master、Slave 发送心跳；
（Consumer既可以从Master订阅消息，也可以从Slave订阅消息，订阅规则由Broker配置决定）
```

## 存储特点

### zero copy

```bash
磁盘先缓存到操作系统底层的缓冲区buffer；
然后通过io流读到应用程序的buffer中；
应用程序与远程建立tcp连接实现网络通信，将程序内存中的buffer缓存到socket buffer中，然后outputstream到目标客户端
```

```
将文件拷贝到kernel buffer中；
向socket buffer中追加当前要发生的数据在kernel buffer中的位置和偏移量；
根据socket buffer中的位置和偏移量直接将kernel buffer的数据copy到网卡设备（protocol engine）中；
经过上述过程，数据只经过了2次copy就从磁盘传送出去了
```

zero-copy省去了操作系统的read buffer拷贝到程序的buffer和程序的buffer拷贝到socket buffer这两个步骤，直接将read buffer拷贝到socket buffer（直接通过socket操作系统底层的buffer）；

java NIO中FileChannel.transferTo()就是这样的实现，该实现是依赖操作系统底层的sendFile()

Zero-Copy技术的使用场景有很多，比如Kafka、Netty、rocketMQ等，可以大大提升程序的性能。

### 存储结构

在搭建环境的时候会新建commitlog、consumerQueue、index这些文件夹（在配置文件里也可配置生成位置）；
正常producer发消息通过nameserver路由到某一broker上，通过topic和tag在树形结构consumerQueue中保存该数据在commitlog中的偏移量offset，真正数据是保存在commitlog中的
消费拉取消息的时候就可以通过topic和tag找到对应的consumerQueue中保存的偏移量，然后通过index快速查询出commitlog中偏移量对应的数据

## 刷盘方式

