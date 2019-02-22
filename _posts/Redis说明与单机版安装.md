---
title: Redis说明与单机版安装
date: 2017-06-09 21:07:22
tags:
- Redis
- Linux
categories:
- Redis
---

记录下Redis的简述以以及单机版的安装操作

<!--more-->

下载安装-->[<font color=#0099ff>Redis</font>](https://redis.io/download)
redis3.0版本才支持集群服务

## NOSQL简介

NOSQL，泛指非关系型数据库，数据一般存储在内存中效率很高，分为4大类：

* 键值存储数据库：使用哈希表，表中包含一个特定的键（String、hash、list、set、zset）和一个指针指向特定的数据，如Redis

* 列存储数据库：用于应对分布式存储的海量数据，键仍存在，但可指向多个列，如HBase

* 文档型数据库：半结构化的文档以特定的格式存储，如JSON；可看作是键值数据库的升级，允许之间嵌套键值，且比键值数据库的查询效率更高，如MongoDb

* 图形数据库：用到不多，略 

## redis持久化

由于redis中数据是基于内存的，如果服务器异常掉电，下次恢复后数据就没了，所以为了高可靠性，可以在redis的配置文件中选中RDB或者AOF，但是RDB不太适用实时的系统，一般都会选择实时的AOF作为数据持久化的选择 

* RDB : 周期性的把内存里的更新数据同步写入到指定服务器的硬盘上

* AOF ：(相当于Oracle的undo) 会实时的将DML操作记录一个持久化日志*.aof文件里，假如说服务器掉电后恢复的时候会直接从日志文件里读取之前的操作.

## 集群策略

* 主从形式：1 主（写），n 从（读），弊端就是主服务器挂了整个集群就挂了

* 2.x哨兵形式：增加一台哨兵节点去监控其他服务器，当主节点挂了的时候，哨兵节点启动在N个从节点中进行投票选举将某台性能较好的服务器升级成主节点，下次挂了的主节点恢复后会作为从节点加入进来

* 3.0后集群形式：2.x哨兵形式的弊端就是每台主从节点上的数据都是一样的相当于备份，前两种都无法实现数据的分布式，3.0后实现了数据的分布水平扩展以及单节点的高可用

## 高可靠优化

由于要考虑数据的高可靠性，在高并发的时候还是需要记录aof日志，虽然读的性能很高但是写性能很低

* 2.x的时候可以调虚拟机的一些参数

* 3.0集群后参数就不可调了，一方面可以多加几台主节点分担高并发写的压力，另一方面可以使用redis+ssdb组合在高并发写的性能很快

## 数据一致性

* 缓存中一般不会涉及到很重要的数据，所以不是太要求缓存数据一定要与关系型数据库中数据高度的一致

* 如果真的需要高度的一致，可以的程序中设计保存关系型数据库中的同时同步到缓存中，当然两步需要做事物的控制.

## 前期环境搭建

安装ruby插件gcc

```bash
[root@redis ~]# yum install -y gcc-c++
已加载插件：fastestmirror, langpacks
base                                                                                                                                                                    | 3.6 kB  00:00:00     
extras                                                                                                                                                                  | 3.4 kB  00:00:00     
updates                                                                                                                                                                 | 3.4 kB  00:00:00     
(1/4): base/7/x86_64/group_gz                                                                                                                                           | 155 kB  00:00:02     
(2/4): extras/7/x86_64/primary_db                                                                                                                                       | 168 kB  00:00:04     
(3/4): base/7/x86_64/primary_db                                                                                                                                         | 5.6 MB  00:00:07     
(4/4): updates/7/x86_64/primary_db                                                                                                                                      | 5.7 MB  00:00:10     
.......                                                                                                                                              19/19 

已安装:
  gcc-c++.x86_64 0:4.8.5-11.el7                                                                                                                                                                

作为依赖被安装:
  cpp.x86_64 0:4.8.5-11.el7   gcc.x86_64 0:4.8.5-11.el7             glibc-devel.x86_64 0:2.17-157.el7_3.2 glibc-headers.x86_64 0:2.17-157.el7_3.2 kernel-headers.x86_64 0:3.10.0-514.21.1.el7
  libmpc.x86_64 0:1.0.1-3.el7 libstdc++-devel.x86_64 0:4.8.5-11.el7 mpfr.x86_64 0:3.1.1-4.el7            

作为依赖被升级:
  glibc.x86_64 0:2.17-157.el7_3.2      glibc-common.x86_64 0:2.17-157.el7_3.2      libgcc.x86_64 0:4.8.5-11.el7      libgomp.x86_64 0:4.8.5-11.el7      libstdc++.x86_64 0:4.8.5-11.el7     

完毕！
```

解压redis-3.2.9.tar.gz，进入redis-3.2.9目录，执行make

![png1](/img/20170609_1.png)

进入redis-3.2.9/src目录执行make install

```bash
[root@localhost src]# pwd
/usr/local/redis-3.2.9/src
[root@localhost src]# make install

Hint: It's a good idea to run 'make test' ;)

    INSTALL install
    INSTALL install
    INSTALL install
    INSTALL install
    INSTALL install
```

文件迁移，便于启动

* 建立俩个文件夹存放redis命令和配置文件

```bash
mkdir -p /usr/local/redis/etc
mkdir -p /usr/local/redis/bin
```

* 把redis-3.2.9下的redis.conf 移动到/usr/local/redis/etc下，

```bash
# cd /usr/local/redis-3.2.9
# cp redis.conf /usr/local/redis/etc/
```

* 把redis-3.2.9/src里的mkreleasehdr.sh、redis-benchmark、redis-check-aof、redis-check-rdb、redis-cli、redis-server 
进入src,文件移动到bin下，命令：

```bash
# cd /usr/local/redis-3.2.9/src
# mv mkreleasehdr.sh redis-benchmark redis-check-aof redis-check-rdb redis-cli redis-server /usr/local/redis/bin
```

注意在3.0.0版本中，redis-check-rdb --> redis-check-dump

## 前台启动

启动脚本 + 配置文件，ctrl+c 退出

```bash
[root@redis local]# /usr/local/redis/bin/redis-server /usr/local/redis/etc/redis.conf 
8696:M 19 Jun 20:54:18.130 * Increased maximum number of open files to 10032 (it was originally set to 1024).
                _._                                                  
           _.-``__ ''-._                                             
      _.-``    `.  `_.  ''-._           Redis 3.2.9 (00000000/0) 64 bit
  .-`` .-```.  ```\/    _.,_ ''-._                                   
 (    '      ,       .-`  | `,    )     Running in standalone mode
 |`-._`-...-` __...-.``-._|'` _.-'|     Port: 6379
 |    `-._   `._    /     _.-'    |     PID: 8696
  `-._    `-._  `-./  _.-'    _.-'                                   
 |`-._`-._    `-.__.-'    _.-'_.-'|                                  
 |    `-._`-._        _.-'_.-'    |           http://redis.io        
  `-._    `-._`-.__.-'_.-'    _.-'                                   
 |`-._`-._    `-.__.-'    _.-'_.-'|                                  
 |    `-._`-._        _.-'_.-'    |                                  
  `-._    `-._`-.__.-'_.-'    _.-'                                   
      `-._    `-.__.-'    _.-'                                       
          `-._        _.-'                                           
              `-.__.-'                                               

8696:M 19 Jun 20:54:18.218 # WARNING: The TCP backlog setting of 511 cannot be enforced because /proc/sys/net/core/somaxconn is set to the lower value of 128.
8696:M 19 Jun 20:54:18.218 # Server started, Redis version 3.2.9
8696:M 19 Jun 20:54:18.219 # WARNING overcommit_memory is set to 0! Background save may fail under low memory condition. To fix this issue add 'vm.overcommit_memory = 1' to /etc/sysctl.conf and then reboot or run the command 'sysctl vm.overcommit_memory=1' for this to take effect.
8696:M 19 Jun 20:54:18.222 # WARNING you have Transparent Huge Pages (THP) support enabled in your kernel. This will create latency and memory usage issues with Redis. To fix this issue run the command 'echo never > /sys/kernel/mm/transparent_hugepage/enabled' as root, and add it to your /etc/rc.local in order to retain the setting after a reboot. Redis must be restarted after THP is disabled.
8696:M 19 Jun 20:54:18.224 * The server is now ready to accept connections on port 6379
```

## 验证

验证启动是否成功：查看是否有redis服务 或者 查看端口

```bash
ps -ef | grep redis 
或 
ps -ef | grep 6379

netstat -tunpl | grep redis
或
netstat -tunpl | grep 6379
```

## 后台启动

* 修改配置文件redis.conf中的属性daemonize 由默认的no（前台启动）改为yes（后台启动）

* redis.conf中的dir（数据日志文件路径）属性由./改为/usr/local/redis/etc/

* 注意：由于第一次启动redis时dir目录还是./，所以会在redis同级目录下生成一个dump.rdb文件，在修改了dir路径后则会在/usr/local/redis/etc/下重新生成dump.rdb，原来的在服务器重启后会消失，也可手动删除

```bash
[root@redis local]# vim /usr/local/redis/etc/redis.conf 
[root@redis local]# /usr/local/redis/bin/redis-server /usr/local/redis/etc/redis.conf 
[root@redis local]# netstat -tunpl | grep 6379
tcp        0      0 127.0.0.1:6379          0.0.0.0:*               LISTEN      8870/redis-server 1 
[root@redis local]# netstat -tunpl | grep redis
tcp        0      0 127.0.0.1:6379          0.0.0.0:*               LISTEN      8870/redis-server 1 
[root@redis local]# ps -ef | grep 6379
root      8870     1  3 21:20 ?        00:00:00 /usr/local/redis/bin/redis-server 127.0.0.1:6379
root      8878  8556  0 21:21 pts/0    00:00:00 grep --color=auto 6379
[root@redis local]# ps -ef | grep redis
root      8870     1  2 21:20 ?        00:00:00 /usr/local/redis/bin/redis-server 127.0.0.1:6379
root      8880  8556  2 21:21 pts/0    00:00:00 grep --color=auto redis


[root@redis local]# /usr/local/redis/bin/redis-server /usr/local/redis/etc/redis.conf 
[root@redis local]# /usr/local/redis/bin/redis-cli
127.0.0.1:6379> set name Stefan
OK
127.0.0.1:6379> get name
"Stefan"
127.0.0.1:6379> quit
[root@redis local]# /usr/local/redis/bin/redis-cli shutdown
[root@redis local]# ps -ef | grep 6379
root      8928  8556  0 21:33 pts/0    00:00:00 grep --color=auto 6379

```

## 退出

* 进入redis客户端 ./redis-cli 退出客户端quit

* 退出redis服务 

```bash
pkill redis-server 
kill 进程号
/usr/local/redis/bin/redis-cli shutdown 
```

