---
title: rocketMQ集群部署之双主模式配置
date: 2017-06-17 20:04:21
tags:
- rocketMQ
- 集群
- Linux
categories: 
- rocketMQ
---
记录rocketMQ的几种Broker集群部署方式，重点记录如何配置双主模式

<!--more-->

# 集群方式

Broker集群部署的几种方式，这里的Slave不可写，但可读，类似于Mysql主备方式；Master(Broker)与Slave配对是通过指定相同的BrokerName参数来配对，Master的BrokerId必须是0，Slave的BrokerId必须是>0的数；且Master下面可以挂载多个Slave，同一Master下的多个Slave通过指定不同的BrokerId来区分

## 单Master模式

这种方式风险较大，一旦Broker重启或者宕机时，会导致整个服务不可用，不建议线上环境使用

## 多Master模式

一个集群无Slave，全是Master，例如 2个Master 或者 3个Master

* 优点：配置简单，单个Master 宕机或重启维护对应用无影响，在磁盘配置为RAID10时，即使机器宕机不可恢复情况下，由于RAID10磁盘非常可靠，消息也不会丢（异步刷盘丢失少量消息，同步刷盘一条不丢）；性能最高

* 缺点：单台机器宕机期间，这台机器上未被消费的消息在机器恢复之前不可订阅，消息实时性会受到受到影响

```bash
先启动 NameServer
在机器 A，启动第一个 Master
在机器 B，启动第二个 Master
...
```

## 多Master 多Slave模式之异步复制

每个Master配置一个对应的Slave，有多对Master-Slave，HA采用异步复制方式，主备有短暂消息延迟（毫秒级）

* 优点：即使磁盘损坏，消息丢失的非常少，且消息实时性不会受影响，因为Master 宕机后，消费者仍然可以从 Slave消费，此过程对应用透明。不需要人工干预。性能同多 Master 模式几乎一样。

* 缺点：Master 宕机，磁盘损坏情况，会丢失少量消息

```bash
先启动 NameServer
在机器 A，启动第一个 Master
在机器 B，启动第二个 Master
在机器 C，启动第一个 Slave
在机器 D，启动第二个 Slave
```

## 多Master 多Slave模式之同步双写

每个 Master 配置一个 Slave，有多对Master-Slave，HA采用同步双写方式，主备都写成功，向应用返回成功

* 优点：数据与服务都无单点，Master宕机情况下，消息无延迟，服务可用性与数据，可用性都非常高
* 缺点：性能比异步复制模式略低，大约低10%左右，发送单个消息的RT会略高；目前主宕机后，备机不能自动切换为主机，后续会支持自动切换功能

```bash
先启动 NameServer
在机器 A，启动第一个 Master
在机器 B，启动第二个 Master
在机器 C，启动第一个 Slave
在机器 D，启动第二个 Slave
```

# 双主同步双写模式

配置JDK环境后，上传alibaba-rocketmq-3.2.6.tar.gz文件至/usr/local/software/，开始解压安装

```bash
# tar -zxvf alibaba-rocketmq-3.2.6.tar.gz -C /usr/local
# mv alibaba-rocketmq alibaba-rocketmq-3.2.6
# ln -s alibaba-rocketmq-3.2.6 rocketmq
# ll /usr/local

# mkdir /usr/local/rocketmq/store
# mkdir /usr/local/rocketmq/store/commitlog
# mkdir /usr/local/rocketmq/store/consumequeue
# mkdir /usr/local/rocketmq/store/index
```

系统初始会提供如下三种模式的配置模板，当然也可以自己自定义添加文件配置 如3主3从同步双写模式 --> 3m-3s-sync

```bash
# ll /usr/local/rocketmq/conf
drwxr-xr-x. 2 52583 users 4096 3月  28 2015 2m-2s-async
drwxr-xr-x. 2 52583 users 4096 3月  28 2015 2m-2s-sync
drwxr-xr-x. 2 52583 users   58 3月  28 2015 2m-noslave
-rw-r--r--. 1 52583 users 7786 3月  28 2015 logback_broker.xml
-rw-r--r--. 1 52583 users 2331 3月  28 2015 logback_filtersrv.xml
-rw-r--r--. 1 52583 users 2313 3月  28 2015 logback_namesrv.xml
-rw-r--r--. 1 52583 users 2435 3月  28 2015 logback_tools.xml

系统初始提供的默认配置模板
2m-2s-async  --> 双主双从异步复制模式
2m-2s-sync   --> 双主双从同步双写模式
2m-noslave   --> 双主模式
```

异步复制和同步双写

```bash
#- ASYNC_MASTER 异步复制Master
#- SYNC_MASTER 同步双写Master

异步复制：
有两个主A和B，producer将消息发送到A后，A会起一个新的线程
（使用netty的NIO，异步的传输将A上的消息复制到B上）
然后立刻返回消息告知producer已经发送成功，并不等待copy完成

同步双写：
就是等待A上的消息copy到B上完成以后，由B发消息告知producer复制完成，同步双写的稳定性较好，
但是性能比异步复制低10%，是可以接受的
```

刷盘方式

```bash
#- ASYNC_FLUSH 异步刷盘
#- SYNC_FLUSH 同步刷盘

异步刷盘：消息数据落到A上的磁盘上是异步方式
同步刷盘：消息数据落到A上的磁盘上是同步方式
```

Broker配置文件介绍，同一集群所有brokerClusterName要一致，同一Master及对应Slave的brokerName相同，不同Master通过不同的brokerName进行区分；以双主模式为例，先修改154.30上/usr/local/rocketmq/conf/2m-noslave/目录下的broker-a.properties和broker-b.properties

```bash
#vim /usr/local/rocketmq/conf/2m-noslave/broker-a.properties
#vim /usr/local/rocketmq/conf/2m-noslave/broker-b.properties

------------------------------------------------------------

#所属集群名字，同一集群填写一致
brokerClusterName=rocketmq-cluster
#broker名字，注意此处不同的配置文件填写的不一样
brokerName=broker-a / broker-b
#0 表示 Master，>0 表示 Slave，若一个Master对应多个Slave则brokerId不能重复
brokerId=0
#nameServer地址，分号分割
namesrvAddr=rocketmq-m1:9876;rocketmq-m2:9876
#在发送消息时，自动创建服务器不存在的topic，默认创建的队列数
defaultTopicQueueNums=4
#是否允许 Broker 自动创建Topic，建议线下开启，线上关闭
autoCreateTopicEnable=true
#是否允许 Broker 自动创建订阅组，建议线下开启，线上关闭
autoCreateSubscriptionGroup=true
#Broker 对外服务的监听端口
listenPort=10911
#删除文件时间点，默认凌晨 4点
deleteWhen=04
#文件保留时间，默认 48 小时
fileReservedTime=120
#commitLog每个文件的大小默认1G
mapedFileSizeCommitLog=1073741824
#ConsumeQueue每个文件默认存30W条，根据业务情况调整
mapedFileSizeConsumeQueue=300000
#destroyMapedFileIntervalForcibly=120000
#redeleteHangedFileInterval=120000
#检测物理文件磁盘空间
diskMaxUsedSpaceRatio=88
#存储路径
storePathRootDir=/usr/local/rocketmq/store
#commitLog 存储路径
storePathCommitLog=/usr/local/rocketmq/store/commitlog
#消费队列存储路径存储路径
storePathConsumeQueue=/usr/local/rocketmq/store/consumequeue
#消息索引存储路径
storePathIndex=/usr/local/rocketmq/store/index
#checkpoint 文件存储路径  自动创建
storeCheckpoint=/usr/local/rocketmq/store/checkpoint
#abort 文件存储路径  自动创建
abortFile=/usr/local/rocketmq/store/abort
#限制的消息大小
maxMessageSize=65536
#flushCommitLogLeastPages=4
#flushConsumeQueueLeastPages=2
#flushCommitLogThoroughInterval=10000
#flushConsumeQueueThoroughInterval=60000
#Broker 的角色
#- ASYNC_MASTER 异步复制Master
#- SYNC_MASTER 同步双写Master
#- SLAVE
brokerRole=SYNC_MASTER
#刷盘方式
#- ASYNC_FLUSH 异步刷盘
#- SYNC_FLUSH 同步刷盘
flushDiskType=SYNC_FLUSH
#checkTransactionMessageEnable=false
#发消息线程池数量
#sendMessageThreadPoolNums=128
#拉消息线程池数量
#pullMessageThreadPoolNums=128
```

然后把154.30上配置好的2m-noslave覆盖154.31上的2m-noslave中

```bash
# cd /usr/local/rocketmq/conf/
# scp -r 2m-noslave/ 192.168.154.31:/usr/local/rocketmq/conf/
```

修改两台机器的日志配置文件

```bash
# mkdir -p /usr/local/rocketmq/logs
# cd /usr/local/rocketmq/conf && sed -i 's#${user.home}#/usr/local/rocketmq#g' *.xml
```

修改两台机器的启动脚本参数（启动最小内存）

```bash
# vim /usr/local/rocketmq/bin/runbroker.sh
JAVA_OPT="${JAVA_OPT} -server -Xms1g -Xmx1g -Xmn512m -XX:PermSize=128m -XX:MaxPermSize=320m"

# vim /usr/local/rocketmq/bin/runserver.sh
JAVA_OPT="${JAVA_OPT} -server -Xms1g -Xmx1g -Xmn512m -XX:PermSize=128m -XX:MaxPermSize=320m"
```

启动两台机器的NameServer，3.x中NameServer代替了2.x版本的zookeeper（activeMQ和kafka都是用的zookeeper），因为mq注册机制不太好，加一个队列必须要到zookeeper上注册，所以换成了NameServer做高可用的路由；producer连接的是Name Server，消息数据通过NameServer路由到某一个Broker上存储，所以每次启动rocketmq先启动NameServer再启动Broker

```bash
# cd /usr/local/rocketmq/bin
# nohup sh mqnamesrv &

# jps
2962 Jps
2937 NamesrvStartup
```

启动154.30上的BrokerServer a

```bash
# cd /usr/local/rocketmq/bin
# nohup sh mqbroker -c /usr/local/rocketmq/conf/2m-noslave/broker-a.properties >/dev/null 2>&1 &

# netstat -ntpl
# jps
2937 NamesrvStartup
2986 BrokerStartup
3003 Jps
# tail -f -n 500 /usr/local/rocketmq/logs/rocketmqlogs/broker.log
# tail -f -n 500 /usr/local/rocketmq/logs/rocketmqlogs/namesrv.log
```

启动154.31上的BrokerServer b

```bash
# cd /usr/local/rocketmq/bin
# nohup sh mqbroker -c /usr/local/rocketmq/conf/2m-noslave/broker-b.properties >/dev/null 2>&1 &

# netstat -ntpl
# jps
# tail -f -n 500 /usr/local/rocketmq/logs/rocketmqlogs/broker.log
# tail -f -n 500 /usr/local/rocketmq/logs/rocketmqlogs/namesrv.log
```

异常分析处理

```bash
# tail -f -n 500 /usr/local/rocketmq/logs/rocketmqlogs/broker.log
com.alibaba.rocketmq.remoting.exception.RemotingConnectException: connect to <192.168.154.31:9876> failed
.....

问题描述：30和31都能互相ping通，但是启动nameserver和broker后显示两台机器无法连接
问题原因：防火墙为关闭
问题解决：
# firewall-cmd --state
# systemctl stop firewalld.service
# systemctl disable firewalld.service
```

暂停服务nameserver和broker，数据清理

```bash
# cd /usr/local/rocketmq/bin
# sh mqshutdown broker
# sh mqshutdown namesrv

# --等待停止
# rm -rf /usr/local/rocketmq/store
# mkdir /usr/local/rocketmq/store
# mkdir /usr/local/rocketmq/store/commitlog
# mkdir /usr/local/rocketmq/store/consumequeue
# mkdir /usr/local/rocketmq/store/index
# --按照上面步骤重启NameServer与BrokerServer
```


# 控制台查看集群

同一集群在一台机器上配置即可，使用192.168.154.30:8080/rocketmq-console-3.2.6查看

```bash
首先安装tomcat
# tar -zxvf apache-tomcat-7.0.72.tar.gz -C /usr/local/
# cd apache-tomcat-7.0.72/webapps/
# mv rocketmq-console-3.2.6.war /usr/local/apache-tomcat-7.0.72/webapps/
# unzip rocketmq-console-3.2.6.war -d rocketmq-console-3.2.6
# rm -rf rocketmq-console-3.2.6.war
# cd /rocketmq-console-3.2.6/WEB-INF/classes/
# vim conf.properties
添加master的ip或hostname,用分号隔开
# /usr/local/apache-tomcat-7.0.72/bin/startup.sh
# tail -f -n 500 /usr/local/apache-tomcat-7.0.72/logs/catalina.out

关闭
# /usr/local/apache-tomcat-7.0.72/bin/shutdown.sh
```

![png1](/img/rocketmq/20170617_1.png)