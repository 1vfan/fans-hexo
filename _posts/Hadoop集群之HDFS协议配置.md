---
title: Hadoop集群之HDFS协议配置
date: 2017-05-14 21:22:26
tags:
- Hadoop
- Linux
- HDFS
- Cluster
categories:
- Hadoop栈
---
记录Hadoop2.7.3版本在CentOS7.2中的集群配置以及基于HDFS协议的文件操作

<!--more-->

# 安装包

* 点击下载-->[<font face="Times New Roman" color=#0099ff>Xshell5.0</font>](http://download.csdn.net/detail/weixin_37479489/9864277)

* 点击下载-->[<font face="Times New Roman" color=#0099ff>Hadoop2.7.3</font>](http://mirror.bit.edu.cn/apache/hadoop/common/hadoop-2.7.3/hadoop-2.7.3.tar.gz)

# 集群网络环境

> 继承传送门-->[<font face="Times New Roman" color=#0099ff>Linux环境搭建指南</font>](https://1vfan.github.io/2017/05/02/Linux%E7%BD%91%E7%BB%9C%E7%8E%AF%E5%A2%83%E4%B9%8BJDK%E9%85%8D%E7%BD%AE/) ，新建4台虚拟机，用于搭建Hadoop集群

```bash
# hostnamectl set-hostname master
# vim /etc/sysconfig/network-scripts/ifcfg-enp0s3
IPADDR=192.168.0.100
NETMASK=255.255.255.0

# hostnamectl set-hostname slave1
# vim /etc/sysconfig/network-scripts/ifcfg-enp0s3
IPADDR=192.168.0.101
NETMASK=255.255.255.0

# hostnamectl set-hostname slave2
# vim /etc/sysconfig/network-scripts/ifcfg-enp0s3
IPADDR=192.168.0.102
NETMASK=255.255.255.0

# hostnamectl set-hostname slave3
# vim /etc/sysconfig/network-scripts/ifcfg-enp0s3
IPADDR=192.168.0.103
NETMASK=255.255.255.0
```

> Hadoop集群网络环境

|Hostname|NODE|IP|OS|
|---|---|---|---|
|master|NameNode|192.168.0.100|CentOS7.2|
|slave1|Datanode|192.168.0.101|CentOS7.2|
|slave2|Datanode|192.168.0.102|CentOS7.2|
|slave3|Datanode|192.168.0.103|CentOS7.2|

# Hadoop集群

## 安装Hadoop

> 使用[<font face="Times New Roman" color=#0099ff>FileZilla</font>](http://download.csdn.net/detail/weixin_37479489/9863014)或者Xftp工具将Hadoop的安装包分别上传到master、slave1、slave2、slave3的/usr/local/目录下

```bash
# cd /usr/local
# tar –xvf ./hadoop-2.7.3.tar.gz
# mv hadoop-2.7.3 hadoop
```

## 配置Hadoop

> 若Linux中没有设置JDK的环境变量,需要修改hadoop-env.sh文件中的JAVA_HOME

```bash
# vi /usr/local/hadoop/etc/hadoop/hadoop-env.sh
修改
export JAVA_HOME=/usr/java/default
```

> 添加Hadoop的环境变量

```bash
# vi /etc/profile
末尾添加
export PATH=$PATH:/usr/hadoop/bin:/usr/hadoop/sbin
# source etc/profile
验证
# hadoop
```

## 测试网络

> 确认互相IP能够ping通，使用ssh登陆，同时修改所有虚拟机的/etc/hosts，确认使用hostname可以ping通

```bash
# vim /etc/hosts
清空后添加
192.168.0.100 master
192.168.0.101 slave1
192.168.0.102 slave2
192.168.0.103 slave3

[root@master ~]# ping slave1
[root@master ~]# ping slave2
[root@master ~]# ping slave3
```

## 配置NameNode

> 修改所有集群虚拟机上hadoop的core-site.xml，配置master作为NameNode和slave作为DataNode

```bash
# cd /usr/local/hadoop/etc/hadoop
# vim core-site.xml

新增属性
<configuration>
  <property>
    <name>fs.defaultFS</name>
    <value>hdfs://master:9000</value>
  </property>
</configuration>
```

> 格式化集群系统

```bash
# hadoop-daemon.sh start namenode
# hdfs namenode -format
```

## 单点管理集群

### 单点启动集群

> 启动master

```bash
[root@master hadoop]# hadoop-daemon.sh start namenode
starting namenode, logging to /usr/local/hadoop/logs/hadoop-root-namenode-master.out
[root@master hadoop]# jps
4656 NameNode
4696 Jps
```

> 启动slave

```bash
[root@slave3 hadoop]# hadoop-daemon.sh start datanode
starting datanode, logging to /usr/local/hadoop/logs/hadoop-root-datanode-slave3.out
[root@slave3 hadoop]# jps
3186 Jps
3151 DataNode
```

> 查看集群

```bash
[root@master hadoop]# hdfs dfsadmin -report | more
Configured Capacity: 21447573504 (19.97 GB)
Present Capacity: 14252560384 (13.27 GB)
DFS Remaining: 13605167104 (12.67 GB)
DFS Used: 647393280 (617.40 MB)
DFS Used%: 4.54%
Under replicated blocks: 0
Blocks with corrupt replicas: 0
Missing blocks: 0
Missing blocks (with replication factor 1): 0

-------------------------------------------------
Live datanodes (3):
```

> 图形界面查看

```bash
浏览器地址栏中输入
http://192.168.0.100:50070/
```

### 单点关闭集群

> 关闭master

```bash
[root@master hadoop]# hadoop-daemon.sh stop namenode
stopping namenode
[root@master hadoop]# jps
4882 Jps
```

> 关闭slave

```bash
[root@slave1 hadoop]# hadoop-daemon.sh stop datanode
stopping datanode
[root@slave1 hadoop]# jps
3281 Jps
```

## 集中管理集群

### 配置slaves

> 配置master上hadoop的slaves文件，添加所有datanode的hostname，以后在namenode上统一启动集群时，系统读取slaves文件然后统一启动所有的datanode

```bash
# cd /usr/local/hadoop/etc/hadoop
# vim slaves

清空后添加
slave1
slave2
slave3
```

### 免密SSH远程登陆

> 常规情况下，远程登陆需要输入密码

```bash
[root@master hadoop]# ssh slave1
[root@master hadoop]# ******
[root@master hadoop]# exit
```
							
> 但在大规模集群环境中要输入上千台datanode的密码肯定不现实，我们需要做免密登陆配置，在master上使用rsa算法生成一组私钥id_rsa和公钥id_rsa.pub，将公钥复制到master和所有的slave中，以后登陆时系统会自动使用.ssh目录中的公钥去适配master上的私钥，不再需要输入密码

```bash
# cd
# ls -la
# cd .ssh
# ssh-keygen -t rsa
敲四个回车

# ssh-copy-id master
# ssh-copy-id slave1
# ssh-copy-id slave2
# ssh-copy-id slave3
```

### 集中启动集群

> 使用start-dfs.sh命令在master上统一启动集群

```bash
[root@master hadoop]# start-dfs.sh
Starting namenodes on [master]
master: starting namenode, logging to /usr/local/hadoop/logs/hadoop-root-namenode-master.out
slave1: starting datanode, logging to /usr/local/hadoop/logs/hadoop-root-datanode-slave1.out
slave3: starting datanode, logging to /usr/local/hadoop/logs/hadoop-root-datanode-slave3.out
slave2: starting datanode, logging to /usr/local/hadoop/logs/hadoop-root-datanode-slave2.out
Starting secondary namenodes [0.0.0.0]
0.0.0.0: starting secondarynamenode, logging to /usr/local/hadoop/logs/hadoop-root-secondarynamenode-master.out
[root@master hadoop]# jps
5362 Jps
5058 NameNode
5224 SecondaryNameNode
```

### 集中关闭集群

> 使用stop-dfs.sh命令在master上统一关闭集群

```bash
[root@master hadoop]# stop-dfs.sh
Stopping namenodes on [master]
master: stopping namenode
slave1: stopping datanode
slave3: stopping datanode
slave2: stopping datanode
Stopping secondary namenodes [0.0.0.0]
0.0.0.0: stopping secondarynamenode
[root@master hadoop]# jps
5686 Jps
```

## 修改HDFS数据存储位置

> hdfs系统会把用到的数据存储在core-site.xml中由hadoop.tmp.dir指定，而这个值默认位于/tmp/hadoop-${user.name}下面， 由于/tmp目录在系统重启时候会被删除，所以应该在所有站点上修改core-site.xml中的目录位置

```bash
# cd /usr/local/hadoop/etc/hadoop
# vim core-site.xml

新增属性
<configuration>
  <property>
    <name>fs.defaultFS</name>
    <value>hdfs://master:9000</value>
  </property>
  <property>
    <name>hadoop.tmp.dir</name>
    <value>/var/hadoop</value>
  </property>
</configuration>
```

> 重启所有站点虚拟机，然后在master上格式化集群系统，再次重启所有虚拟机，执行start-dfs.sh启动集群查看集群情况

```bash
# hdfs namenode -format
```

## 大功告成

> 到此整个Hadoop集群已经配置完成

![png1](/img/20170514_1.png)
