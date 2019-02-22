---
title: WebSphere8.5集群更换节点
date: 2018-04-11 15:40:22
tags:
- WebSphere
- 集群
categories: 
- WebSphere
---

记录下测试环境WebSphere集群删除节点临时文件后无法启动Server解决方案

<!--more-->

# 集群

Node Agent 进程担当节点和Deployment Manager上的应用程序服务器之间的中介.

|Hostname|NODE|IP|SOAP Port|Enable|
|---|---|---|---|---|
|giswebserver1|Deployment Manager|158.222.166.91|8879|ture|
|giswebserver1|Node Agent1|158.222.166.91|8880|ture|
|giswebserver2|Node Agent2|158.222.177.53|8880|false|

# 异常描述

运维给测试环境中was的挂载空间分配的太少，定期删除备份和临时文件，这次删除了节点中的temp和wstemp临时文件后，无法启动Server的集群，恢复文件后依然无法启动.

尝试更换新的Server，依旧无法启动，无奈只能更换节点.


# giswebserver1上更换新节点

giswebserver2操作一致.

* 关闭之前的Node Agent节点和Server

```bash
# ./stopNode.sh
# ./stopServer.sh
# ./removeNode.sh
# ps aux | grep IBM
```

* 创建新节点的Application Server profile应用程序服务器概要文件

```bash
# cd /opt/IBM/WebSphere/AppServer/bin
[root@giswebserver1 bin]# pwd
/opt/IBM/WebSphere/AppServer/bin
[root@giswebserver1 bin]# ./manageprofiles.sh -create -profileName AppSrv02 -profilePath /opt/IBM/WebSphere/AppServer/profiles/AppSrv02 -templatePath /opt/IBM/WebSphere/AppServer/profileTemplates/default -nodeName AppNode02 -hostName bgiswebserver1 -enableAdminSecurity false
INSTCONFSUCCESS：Success：Profile AppSrv02 now exists. .............
# more /opt/IBM/WebSphere/AppServer/profiles/AppSrv02/logs/AboutThisProfile.txt
创建概要文件会自动分配一个SOAP connector port: 8880  默认从8880开始依次递增
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
[root@giswebserver1 bin]# pwd
/opt/IBM/WebSphere/AppServer/profiles/AppSrv02/bin
[root@giswebserver1 bin]# ./addNode.sh bgiswebserver1 8879 -username admin -password admin
bgiswebserver1为dmgr所在的hostname、8879为dmgr的默认port
```

* 添加应用服务器到集群中

```bash
was控制台-服务器-集群-WebSphere Application Server集群
点击集群名-集群成员-新建-添加成员-选择新建的节点
服务器-所有服务器-启动节点的Server和集群的Server
```

* 到此添加完毕，然后做节点同步，重启所有的dmgr和Node

```bash
-- 停止集群
# ./stopServer servername

或 was控制台-服务器-集群-WebSphere Application Server集群-停止集群
# ./stopNode.sh
# ./stopManager.sh
# ps aux | grep IBM

-- 启动dmgr进程
# cd /opt/IBM/WebSphere/App Server/profiles/Dmgr01
# cd /Dmgr01/bin
# ./startManager.sh

-- 手工同步节点与dmgr（bgiswebserver1 8879）同步
# ./syncNode.sh bgiswebserver1 8879 -user admin -password admin

-- 启动Node Agent和Server进程
# ./startNode.sh

-- 控制台启动所有的Server
```

* 更改新节点默认端口

环境 --> 虚拟主机 --> default_host --> 主机别名 --> 已配置虚拟主机名对应web端口9080

服务器 --> 所有Server --> 端口 --> WC_defaulthost --> 9080
