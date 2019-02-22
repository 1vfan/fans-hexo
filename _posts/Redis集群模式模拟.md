---
title: Redis集群模式模拟
date: 2017-06-11 20:37:48
tags:
- Redis
- Linux
- 集群
categories:
- Redis
---

记录下在一台虚拟机上模拟6台服务器的redis集群，3主3从

<!--more-->

# 配置

创建一个文件夹redis-cluster，并在此文件夹下新建6的子文件夹

```bash
# mkdir -p /usr/local/redis-cluster
# cd /usr/local/redis-cluster
# mkdir 7001
# ...
# mkdir  7006
```

将redis.conf配置文件分别copy到7001-7006文件夹下 

```bash
# cd /usr/local/redis/etc
# cp redis.conf /usr/local/redis-cluster/7001
# ...
# cp redis.conf /usr/local/redis-cluster/7006
```

修改各自的redis.conf文件

```bash
bind 192.168.154.132  ##必须绑定当前虚拟机的ip，不绑定会出现很大问题

port 7001    ##修改各自端口号

deamonize yes   ##后台启动

dir /usr/local/redis-cluster/7001/     ##必须保存在各自的目录位置，否则会丢失数据

appendonly yes ##开启aof

cluster-enabled yes  ##启动集群模式

cluster-config-file nodes-7001.conf   ##名字最好对应port，有此文件才能知道集群中其他的节点

cluster-node-timeout 5000  ##失效时间 5s
```

由于redis集群需要使用ruby命令，安装ruby 

```bash
# yum install ruby
# yum install rubygems
redis继承ruby的接口
# gem install redis
Fetching: redis-3.3.3.gem (100%)
Successfully installed redis-3.3.3
Parsing documentation for redis-3.3.3
Installing ri documentation for redis-3.3.3
1 gem installed
```

分别启动6个redis实例

```bash
# /usr/local/redis/bin/redis-server /usr/local/redis-cluster/7001/redis.conf
# ...
# /usr/local/redis/bin/redis-server /usr/local/redis-cluster/7006/redis.conf
# netstat -tunpl | grep redis
tcp        0      0 192.168.154.132:7001    0.0.0.0:*               LISTEN      3027/redis-server 1 
tcp        0      0 192.168.154.132:7002    0.0.0.0:*               LISTEN      3031/redis-server 1 
tcp        0      0 192.168.154.132:7003    0.0.0.0:*               LISTEN      3035/redis-server 1 
tcp        0      0 192.168.154.132:7004    0.0.0.0:*               LISTEN      3039/redis-server 1 
tcp        0      0 192.168.154.132:7005    0.0.0.0:*               LISTEN      3043/redis-server 1 
tcp        0      0 192.168.154.132:7006    0.0.0.0:*               LISTEN      3047/redis-server 1 
```

进入redis原始安装目录/usr/local/redis-3.2.9/src找到redis集群操作的脚本redis-trib.rb，运行脚本建立集群系统

* --replicas 1 后的数字代表主从数量的比例

* slots就是redis集群中主节点被分配的槽，从节点中没有槽所以不支持写入

```bash
# cd /usr/local/redis-3.2.9/src 
[root@redis src]# ./redis-trib.rb create --replicas 1 192.168.154.132:7001 192.168.154.132:7002 192.168.154.132:7003 192.168.154.132:7004 192.168.154.132:7005 192.168.154.132:7006
>>> Creating cluster
>>> Performing hash slots allocation on 6 nodes...
Using 3 masters:
192.168.154.132:7001
192.168.154.132:7002
192.168.154.132:7003
Adding replica 192.168.154.132:7004 to 192.168.154.132:7001
Adding replica 192.168.154.132:7005 to 192.168.154.132:7002
Adding replica 192.168.154.132:7006 to 192.168.154.132:7003
M: e8faff74549c6bdd8e3b7533bda8c40f2b4a4d2f 192.168.154.132:7001
   slots:0-5460 (5461 slots) master
M: c3a23d296392d0af33ee3bc1742bbea8c3098fc1 192.168.154.132:7002
   slots:5461-10922 (5462 slots) master
M: d761ad8547db461bc89c3ab90cfc53e6422baad5 192.168.154.132:7003
   slots:10923-16383 (5461 slots) master
S: c1ef3e6cd3cc1f766e5e70352b9e274dd1c2efc6 192.168.154.132:7004
   replicates e8faff74549c6bdd8e3b7533bda8c40f2b4a4d2f
S: aa1912f143bd06a632d32cbadce37859460b2fa4 192.168.154.132:7005
   replicates c3a23d296392d0af33ee3bc1742bbea8c3098fc1
S: 04783e23f6bdb54f425a4dd2c339745bb1edc381 192.168.154.132:7006
   replicates d761ad8547db461bc89c3ab90cfc53e6422baad5
Can I set the above configuration? (type 'yes' to accept): yes
>>> Nodes configuration updated
>>> Assign a different config epoch to each node
>>> Sending CLUSTER MEET messages to join the cluster
Waiting for the cluster to join...
>>> Performing Cluster Check (using node 192.168.154.132:7001)
M: e8faff74549c6bdd8e3b7533bda8c40f2b4a4d2f 192.168.154.132:7001
   slots:0-5460 (5461 slots) master
   1 additional replica(s)
M: d761ad8547db461bc89c3ab90cfc53e6422baad5 192.168.154.132:7003
   slots:10923-16383 (5461 slots) master
   1 additional replica(s)
S: 04783e23f6bdb54f425a4dd2c339745bb1edc381 192.168.154.132:7006
   slots: (0 slots) slave
   replicates d761ad8547db461bc89c3ab90cfc53e6422baad5
S: aa1912f143bd06a632d32cbadce37859460b2fa4 192.168.154.132:7005
   slots: (0 slots) slave
   replicates c3a23d296392d0af33ee3bc1742bbea8c3098fc1
S: c1ef3e6cd3cc1f766e5e70352b9e274dd1c2efc6 192.168.154.132:7004
   slots: (0 slots) slave
   replicates e8faff74549c6bdd8e3b7533bda8c40f2b4a4d2f
M: c3a23d296392d0af33ee3bc1742bbea8c3098fc1 192.168.154.132:7002
   slots:5461-10922 (5462 slots) master
   1 additional replica(s)
[OK] All nodes agree about slots configuration.
>>> Check for open slots...
>>> Check slots coverage...
[OK] All 16384 slots covered.
```

# 验证集群环境

* 连接任意一个客户端，查看集群信息和节点列表，关闭集群需要逐个进行关闭

* 当出现集群无法启动时，删除临时的数据文件，再次重新启动每个redis服务，然后重新构建集群环境.

```bash
[root@redis src]# /usr/local/redis/bin/redis-cli -c -h 192.168.154.132 -p 7001

192.168.154.132:7001> cluster nodes
aa1912f143bd06a632d32cbadce37859460b2fa4 192.168.154.132:7005 slave c3a23d296392d0af33ee3bc1742bbea8c3098fc1 0 1500859500934 5 connected
c3a23d296392d0af33ee3bc1742bbea8c3098fc1 192.168.154.132:7002 master - 0 1500859503158 2 connected 5461-10922
e8faff74549c6bdd8e3b7533bda8c40f2b4a4d2f 192.168.154.132:7001 myself,master - 0 0 8 connected 0-5460
04783e23f6bdb54f425a4dd2c339745bb1edc381 192.168.154.132:7006 slave d761ad8547db461bc89c3ab90cfc53e6422baad5 0 1500859502956 6 connected
d761ad8547db461bc89c3ab90cfc53e6422baad5 192.168.154.132:7003 master - 0 1500859501944 3 connected 10923-16383
c1ef3e6cd3cc1f766e5e70352b9e274dd1c2efc6 192.168.154.132:7004 slave e8faff74549c6bdd8e3b7533bda8c40f2b4a4d2f 0 1500859500932 8 connected

192.168.154.132:7001> cluster info
cluster_state:ok
cluster_slots_assigned:16384
cluster_slots_ok:16384
cluster_slots_pfail:0
cluster_slots_fail:0
cluster_known_nodes:6
cluster_size:3
cluster_current_epoch:6
cluster_my_epoch:1
cluster_stats_messages_sent:14782
cluster_stats_messages_received:14782
192.168.154.132:7001> cluster nodes
d761ad8547db461bc89c3ab90cfc53e6422baad5 192.168.154.132:7003 master - 0 1498145580128 3 connected 10923-16383
04783e23f6bdb54f425a4dd2c339745bb1edc381 192.168.154.132:7006 slave d761ad8547db461bc89c3ab90cfc53e6422baad5 0 1498145581679 6 connected
aa1912f143bd06a632d32cbadce37859460b2fa4 192.168.154.132:7005 slave c3a23d296392d0af33ee3bc1742bbea8c3098fc1 0 1498145581063 5 connected
e8faff74549c6bdd8e3b7533bda8c40f2b4a4d2f 192.168.154.132:7001 myself,master - 0 0 1 connected 0-5460
c1ef3e6cd3cc1f766e5e70352b9e274dd1c2efc6 192.168.154.132:7004 slave e8faff74549c6bdd8e3b7533bda8c40f2b4a4d2f 0 1498145580676 4 connected
c3a23d296392d0af33ee3bc1742bbea8c3098fc1 192.168.154.132:7002 master - 0 1498145579610 2 connected 5461-10922
192.168.154.132:7001> quit

[root@redis src]# /usr/local/redis/bin/redis-cli -c -h 192.168.154.132 -p 7001 shutdown
[root@redis src]# netstat -tunpl | grep redis
tcp        0      0 192.168.154.132:7002    0.0.0.0:*               LISTEN      3031/redis-server 1 
tcp        0      0 192.168.154.132:7003    0.0.0.0:*               LISTEN      3035/redis-server 1 
tcp        0      0 192.168.154.132:7004    0.0.0.0:*               LISTEN      3039/redis-server 1 
tcp        0      0 192.168.154.132:7005    0.0.0.0:*               LISTEN      3043/redis-server 1 
tcp        0      0 192.168.154.132:7006    0.0.0.0:*               LISTEN      3047/redis-server 1 
```

# 开机自启动

在rc.local中添加所有开机自启动节点的启动命令

```bash
# vim /etc/rc.d/rc.local
添加
/usr/local/redis/bin/redis-server /usr/local/redis-cluster/7001/redis.conf
/usr/local/redis/bin/redis-server /usr/local/redis-cluster/7002/redis.conf
/usr/local/redis/bin/redis-server /usr/local/redis-cluster/7003/redis.conf
/usr/local/redis/bin/redis-server /usr/local/redis-cluster/7004/redis.conf
/usr/local/redis/bin/redis-server /usr/local/redis-cluster/7005/redis.conf
/usr/local/redis/bin/redis-server /usr/local/redis-cluster/7006/redis.conf
```

注意：编辑完rc.local文件后，一定要给rc.local文件执行权限，否则开机时不会执行rc.local文件中脚本命令

```bash
# cd /etc/rc.d
# ll
drwxr-xr-x. 2 root root  66 6月  11 17:04 init.d
drwxr-xr-x. 2 root root  43 6月  11 17:04 rc0.d
drwxr-xr-x. 2 root root  43 6月  11 17:04 rc1.d
drwxr-xr-x. 2 root root  43 6月  11 17:04 rc2.d
drwxr-xr-x. 2 root root  43 6月  11 17:04 rc3.d
drwxr-xr-x. 2 root root  43 6月  11 17:04 rc4.d
drwxr-xr-x. 2 root root  43 6月  11 17:04 rc5.d
drwxr-xr-x. 2 root root  43 6月  11 17:04 rc6.d
-rw-r--r--. 1 root root 473 6月 11 2015 rc.local

# chmod +x /etc/rc.d/rc.local
[root@redis rc.d]# ll rc.local
-rwxr-xr-x. 1 root root 923 6月  11 17:23 rc.local
```


