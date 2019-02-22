---
title: ElasticSearch集群及相关插件配置
date: 2017-05-05 20:37:05
tags:
- ElasticSearch
- Kibana
- 集群
categories: 
- ELK
---
记录ElasticSearch5.4.0集群在CentOS7.2中的安装配置以及相关插件的安装配置

<!--more-->

# 前期准备

* 点击下载-->[<font face="Times New Roman" color=#0099ff>ElasticSearch5.4.0</font>](http://download.csdn.net/download/weixin_37479489/9897585)
* 点击下载-->[<font face="Times New Roman" color=#0099ff>elasticsearch-head插件</font>](http://download.csdn.net/download/weixin_37479489/9897557)
* 更多安装包请参考-->[<font color=#0099ff>官网</font>](https://www.elastic.co/cn/downloads)
* 继承传送门-->[<font face="Times New Roman" color=#0099ff>Linux环境搭建指南</font>](https://1vfan.github.io/2017/04/02/VMware安装CentOS以及NAT网络配置/)

elasticsearch5.4集群概览（笔者受限于电脑性能，只能搭两台节点组成集群）

|Hostname|IP|OS|plugin|
|---|---|---|---|
|elastic1|192.168.154.10|CentOS7.2|elasticsearch-head|
|elastic2|192.168.154.11|CentOS7.2|kibana|

使用[<font face="Times New Roman" color=#0099ff>FileZilla</font>](http://download.csdn.net/detail/weixin_37479489/9863014)上传下载包到/usr/local/software/目录下

# 安装配置ElasticSearch

先检查jdk的版本，安装jdk1.8，配置环境变量

```bash
检查当前系统是否有jdk
# java -version
#rpm -qa | grep java
移除当前系统安装的jdk
# rpm -e xxx
解压jdk8
# cd /usr/local/software
# tar -zxvf jdk-8u112-linux-x64.tar.gz -C /usr/local/
# ln -s /usr/local/jdk1.8.0_112 jdk1.8
在profile文件中添加环境变量
# vim /etc/profile
添加
JAVA_HOME=/usr/local/jdk1.8
JRE_HOME=$JAVA_HOME/jre
CLASS_PATH=.:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar:$JRE_HOME/lib
PATH=$PATH:$JAVA_HOME/bin:$JRE_HOME/bin
export JAVA_HOME JRE_HOME CLASS_PATH PATH
# source /etc/profile
# which java
# java -version
```

解压安装elasticsearch5.4.0

```bash
# cd /usr/local/software
# tar -zxvf elasticsearch-5.4.0.tar.gz -C /usr/local/
```

新增用户赋权限

```bash
# cd
# groupadd devs
# useradd -g devs -m elsearch
# passwd elsearch

在root下给elsearch用户赋权限
# cd /usr/local
# chown -R elsearch:devs /elasticsearch-5.4.0
```

配置elasticsearch.yml，在对应的属性下添加以下信息 （注意：大小写敏感,使用缩进表示层级关系,缩进时不允许使用Tab键，只允许使用空格；缩进的空格数目不重要，只要相同层级的元素左侧对齐即可# 表示注释，从这个字符一直到行尾，都会被解析器忽略）

```bash
# vim /elasticsearch-5.4.0/config/elasticsearch.yml
一个集群中保证节点间的集群名字相同，节点名字不同
cluster.name: es-stefan
node.name: node-154-10
bootstrap.memory_lock: true
#旧版本叫bootstrap.mlockall: true
bootstrap.system_call_filter: false
network.host: 192.168.154.10
http.port: 9200
http.cors.enabled: true
http.cors.allow-origin: "*"
discovery.zen.ping.unicast.hosts: ["192.168.154.10:9300", "192.168.154.11:9300"]
discovery.zen.minimum_master_nodes: 2
gateway.recover_after_nodes: 2
```

禁用swap

```bash
# swapoff -a
```

修改linux内核参数

```bash
# vim /etc/security/limits.conf
添加
* soft nofile 65536
* hard nofile 131072
* soft memlock unlimited
* hard memlock unlimited
```

修改虚拟内存空间及swap使用率

```bash
# vim /etc/sysctl.conf
添加
vm.max_map_count=655360
vm.swappiness=1
# sysctl -p
```

修改创建本地线程数

```bash
# vim /etc/security/limits.d/20-nproc.conf
修改
* soft nproc 2048
```


关闭防火墙

```bash
# systemctl stop firewalld.service
# firewall-cmd --state
not running
# systemctl disable firewalld.service
```

# 启动集群并查询节点信息

启动集群

```bash
# su elsearch
$ cd /elasticsearch-5.4.0/
$ ./bin/elasticsearch
or

后台启动
$ ./bin/elasticsearch -d
```

curl验证集群和节点状态信息

```bash
[root@elastic1 local]# curl 'http://192.168.154.10:9200?pretty'
{
  "name" : "node-154-10",
  "cluster_name" : "es-stefan",
  "cluster_uuid" : "25rzWV2qS4KBLsaOlffNSQ",
  "version" : {
    "number" : "5.4.0",
    "build_hash" : "780f8c4",
    "build_date" : "2017-04-28T17:43:27.229Z",
    "build_snapshot" : false,
    "lucene_version" : "6.5.0"
  },
  "tagline" : "You Know, for Search"
}

[root@elastic1 local]# curl 'http://192.168.154.10:9200/_cluster/health?pretty'
{
  "cluster_name" : "es-stefan",
  "status" : "green",
  "timed_out" : false,
  "number_of_nodes" : 2,
  "number_of_data_nodes" : 2,
  "active_primary_shards" : 12,
  "active_shards" : 24,
  "relocating_shards" : 0,
  "initializing_shards" : 0,
  "unassigned_shards" : 0,
  "delayed_unassigned_shards" : 0,
  "number_of_pending_tasks" : 0,
  "number_of_in_flight_fetch" : 0,
  "task_max_waiting_in_queue_millis" : 0,
  "active_shards_percent_as_number" : 100.0
}

[root@elastic1 local]# curl 'http://192.168.154.10:9200/_cat/nodes?pretty'
192.168.154.10 25 96 5 0.22 0.39 0.26 mdi * node-154-10
192.168.154.11 23 96 4 0.08 0.16 0.14 mdi - node-154-11
```

浏览器中验证集群和节点信息

```bash
浏览器地址栏输入
http://192.168.0.200:9200/
```

启动head

```bash
[root@elastic1 elasticsearch-head]# npm run start

> elasticsearch-head@0.0.0 start /usr/local/elasticsearch-head
> grunt server

>> Local Npm module "grunt-contrib-jasmine" not found. Is it installed?

Running "connect:server" (connect) task
Waiting forever...
Started connect web server on http://192.168.154.10:9100
```
## 关闭ES

```bash
[elsearch@es-master elasticsearch5.1]$ ps aux | grep elastic
[elsearch@es-master elasticsearch5.1]$ kill -9 <pid>
```

