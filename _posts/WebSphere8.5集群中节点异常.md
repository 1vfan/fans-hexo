---
title: WebSphere8.5集群中节点异常
date: 2017-06-23 08:41:23
tags:
- WebSphere
- 集群
categories: 
- WebSphere
---

记录下测试环境WebSphere集群其中一台节点服务器异常情况解决方案

<!--more-->

# 集群

Node Agent 进程担当节点和Deployment Manager上的应用程序服务器之间的中介.

|Hostname|NODE|IP|SOAP Port|Enable|
|---|---|---|---|---|
|giswebserver1|Deployment Manager|158.222.166.91|8879|ture|
|giswebserver1|Node Agent1|158.222.166.91|8880|ture|
|giswebserver2|Node Agent2|158.222.177.53|8880|false|
|giswebserver1|Node Agent3|158.222.166.91|8881|ture|

# 异常描述

使用was上发布的服务，产生如下错误，登陆was控制台发现giswebserver2上的Node Agent挂了

```bash
com.ibm.ws.jsp.translator.JspTranslationException: JSPG0227E:
java.lang.reflect.InvocationTargetException   捕获时异常
...
```

另一台giswebserver1上的Node Agent启动、关闭都正常；尝试root用户下命令行启动giswebserver2挂了的Node Agent，产生如下错误；

```bash
[root@giswebserver2 bin]# ./startNode.sh
runConfigActions script execution failed. Exit code: 1
Exception caught while waiting for runConfigActions script to complete: /opt/IBM/WebSphere/AppServer/profiles/AppSrv01/bin/runConfigActions.sh
[root@giswebserver2 bin]# ./runConfigActions.sh
java.io.IOException：Couldn't get lock for ...
Exception in thread "main" java.lang.NullPointerException
...
```

# 问题排除

先去比较活跃的社区 [<font color=#0099ff>WebSphere中国</font>](http://www.webspherechina.net/) 找类似问题解决办法

## 防火墙

在集群节点间网络畅通的前提下，关闭防火墙；查看防火墙本身就是关闭的，跳过

```bash
# service iptables status
iptables：未运行防火墙
```

## 证书过期或参数错误

* 查看后台SystemOut.log日志，并没有发现包含SSLHandshakeException：certificates expire的错误记录，跳过

* 查看Node Agent中的native_stderr.log和native_stdout.log日志，没有发现关于JVM参数设置错误导致JVM启动不了的错误记录，且JVM设置了初始堆2G，最大堆4G，跳过

* 查看was工作目录空间，跳过

## 时间同步

查看节点的系统时间是否同步；发现两台节点服务器的系统时间相差1分钟左右，开始同步

```bash
局域网内只能将其中一台服务器giswebserver1作为ntp服务器，开启或重启ntpd
# service ntpd start
# service ntpd restart
关闭另一台服务器giswebserver2的ntpd后，同步已开启ntp的服务器giswebserver1上的时间
# service ntpd stop
# ntpdate xxx.xxx.xxx.xxx
xxx.xxx.xxx.xxx为开启ntp的服务器giswebserver1的ip或hostname
使用date查看是否已同步
```

时间同步后命令行启动giswebserver2的Node Agent依然报错；重启服务器后再次启动Node Agent发现不报错了，显示正常启动，但是was控制台依然无法启动，而且过了一段时间命令行启动节点时又开始报错

## 只读文件系统

然后发现服务器总报无法运行或更改“只读文件系统”，尝试 [<font color=#0099ff>修复方案</font>](http://www.tuicool.com/articles/JfmAJf) 修复系统根分区

```bash
# mount
# fsck.ext4 -y /dev/mapper/vg_giswebserver-lv_root
```

修复成功，命令行启动giswebserver2的Node Agent果然显示正常启动了，但是控制台依然无法启动

# 添加新节点

## giswebserver2上添加

既然无法修复了，那就只能放弃它，尝试向集群中添加一个新节点Node Agent3

* 删除挂了的Node Agent2以及对应的server

```bash
# ./stopNode.sh
# ./stopServer.sh
# ./removeNode.sh
# ps aux | grep IBM
```

* 创建新节点的Application Server profile应用程序服务器概要文件

```bash
# cd /opt/IBM/WebSphere/AppServer/bin
[root@giswebserver2 bin]# pwd
/opt/IBM/WebSphere/AppServer/bin
[root@giswebserver2 bin]# ./manageprofiles.sh -create -profileName AppSrv02 -profilePath /opt/IBM/WebSphere/AppServer/profiles/AppSrv02 -templatePath /opt/IBM/WebSphere/AppServer/profileTemplates/default -nodeName AppNode02 -hostName bgiswebserver2 -enableAdminiSecurity false
INSTCONFSUCCESS：Success：Profile AppSrv02 now exists. .............
# more /opt/IBM/WebSphere/AppServer/profiles/AppSrv02/logs/AboutThisProfile.txt
创建概要文件会自动分配一个SOAP connector port: 8881  默认从8880开始依次递增
```

* 添加新创建的概要节点到部署管理器节点下，这样才能在控制台统一管理所有节点

```bash
添加前确保控制台节点已经启动
[root@giswebserver1 bin]# pwd
/opt/IBM/WebSphere/AppServer/profiles/Dmgr01/bin
[root@giswebserver1 bin]# ./startManager.sh
# ps aux | grep IBM
添加
# cd /opt/IBM/WebSphere/AppServer/profiles/AppSrv02/bin
[root@giswebserver2 bin]# pwd
/opt/IBM/WebSphere/AppServer/profiles/AppSrv02/bin
[root@giswebserver2 bin]# ./addNode.sh bgiswebserver1 8879 -username admin -password admin
bgiswebserver1为dmgr所在的hostname、8879为dmgr的默认port
```

* 添加应用服务器到集群中

```bash
was控制台-服务器-集群-WebSphere Application Server集群
点击集群名-集群成员-新建-添加成员-选择新建的节点
服务器-所有服务器-启动server
```

* 到此添加完毕，然后做节点同步，重启所有的dmgr和Node，由于新节点Node Agent3在控制台依然无法启动，同步重启过程在此就不赘述了

## giswebserver1上添加

最后尝试在一台服务器bgiswebserver1上做多节点的伪集群，说明一下Node、Profile和Server的概念

* Node等同于Profile，Node是管理上使用的概念，Profile是实际的概要文件，它们代表同一事物；Server就是我们实际要部署项目的地方

* 在IBM WAS ND产品中：Deployment Manager透过下属的Node Agent来管理Node（Profile）中的Server，一个Node（Profile）中可以有多个Server

* 在非ND产品中：则属于Single Server版本，一个Node（Profile）中只能有一个Server，如果希望在一台机器上有多个Server，只能通过创建多个Node（Profile）即Node Agent来实现，这些Node Agent彼此独立，只要使用的Port不冲突即可，一般来说默认创建分配的Port不会冲突

创建并添加节点的步骤同上，完成后需要做节点的同步，同步后部署项目测试成功

```bash
-- 停止集群
# ./stopServer servername
或 was控制台-服务器-集群-WebSphere Application Server集群-停止集群
# ./stopNode.sh
# ./stopManager.sh
# ps aux | grep IBM

-- 备份并删除dmgr概要文件下的临时文件
# cd /opt/IBM/WebSphere/App Server/profiles/Dmgr01
# rm -rf temp
# rm -rf wstemp
# cd config
# rm -rf temp

-- 启动dmgr进程
# cd /Dmgr01/bin
# ./startManager.sh
-- 手工同步AppSrv01、AppSrv02与dmgr（bgiswebserver1 8879）同步
# cd /AppSrv01/bin
# ./syncNode.sh bgiswebserver1 8879 -user admin -password admin
# cd /AppSrv02/bin
# ./syncNode.sh bgiswebserver1 8879 -user admin -password admin

-- 启动Node Agent和Server进程
# ./startNode.sh
was控制台-服务器-集群-WebSphere Application Server集群-启动集群
然后-服务器-服务器类型-WebSphere Application Server-启动node的其他server

-- 查看同步状态
was控制台-系统管理-节点-查看状态一栏的同步状态
```

# 最后结论

此结论纯属推测：估计是bgiswenserver2这台服务器系统没有正常关机，导致虚拟磁盘出现文件系统错误，变成只读系统，was的某些系统文件也受影响，Node Agent在控制台无法正常启动，只能重新安装试试了.


