---
title: API文档团队化管理工具ShowDoc应用实践
date: 2017-07-19 21:43:01
tags:
- ShowDoc
- Apache
- Linux
- php
categories: 
- Tool
---

记录一款由php编写、支持md（Makedown）语法的API文档编辑、生成、展示工具

<!--more-->

# 关闭防火墙

1. centOS6

```bash
# service iptables status
# service iptables stop
# chkconfig iptables off
```

2. centOS7

```bash
# firewall-cmd --state
# systemctl stop firewalld.service
# systemctl disable firewalld.service
``` 

# php

## 联网集成

```bash
# yum install php php-gd php-mcrypt php-mbstring php-mysql php-pdo
```

若无php-mcrypt可安装，可以通过第三方源安装

```bash
--安装第三方yum源
# wget http://www.atomicorp.com/installers/atomic
# sudo sh ./atomic
--使用yum命令安装
# sudo yum install php-mcrypt
# sudo yum install libmcrypt
# sudo yum install libmcrypt-devel
```


## 内网集成

> 在无法使用yum的内网中，需要将使用到的rpm镜像包上传到服务器上/usr/local/software/路径下

1. centOS6中运行安装以下依赖的rpm镜像包

```bash
libmcrypt-2.5.7-5.el6.art.x86_64.rpm
libtool-ltdl-2.2.6-15.5.el6.x86_64.rpm
php-5.4.45-56.el6.art.x86_64.rpm
php-cli-5.4.45-56.el6.art.x86_64.rpm
php-common-5.4.45-56.el6.art.x86_64.rpm
php-gd-5.4.45-56.el6.art.x86_64.rpm
php-mbstring-5.4.45-56.el6.art.x86_64.rpm
php-mcrypt-5.4.45-56.el6.art.x86_64.rpm
php-mysql-5.4.45-56.el6.art.x86_64.rpm
php-pdo-5.4.45-56.el6.art.x86_64.rpm
```

```bash
# cd /usr/local/software/
# rpm -ivh libmcrypt-2.5.7-5.el6.art.x86_64.rpm libtool-ltdl-2.2.6-15.5.el6.x86_64.rpm php-5.4.45-56.el6.art.x86_64.rpm php-cli-5.4.45-56.el6.art.x86_64.rpm php-common-5.4.45-56.el6.art.x86_64.rpm php-gd-5.4.45-56.el6.art.x86_64.rpm php-mbstring-5.4.45-56.el6.art.x86_64.rpm php-mcrypt-5.4.45-56.el6.art.x86_64.rpm php-mysql-5.4.45-56.el6.art.x86_64.rpm php-pdo-5.4.45-56.el6.art.x86_64.rpm
```

2. centOS7进行同样操作

```bash
libmcrypt-2.5.8-4.el7.art.x86_64.rpm
libtool-ltdl-2.4.2-22.el7_3.x86_64.rpm
php-5.4.45-56.el7.art.x86_64.rpm
php-cli-5.4.45-56.el7.art.x86_64.rpm
php-common-5.4.45-56.el7.art.x86_64.rpm
php-gd-5.4.45-56.el7.art.x86_64.rpm
php-mbstring-5.4.45-56.el7.art.x86_64.rpm
php-mcrypt-5.4.45-56.el7.art.x86_64.rpm
php-mysql-5.4.45-56.el7.art.x86_64.rpm
php-pdo-5.4.45-56.el7.art.x86_64.rpm
```

```bash
# cd /usr/local/software/
# rpm -ivh libmcrypt-2.5.8-4.el7.art.x86_64.rpm libtool-ltdl-2.4.2-22.el7_3.x86_64.rpm php-5.4.45-56.el7.art.x86_64.rpm php-cli-5.4.45-56.el7.art.x86_64.rpm php-common-5.4.45-56.el7.art.x86_64.rpm php-gd-5.4.45-56.el7.art.x86_64.rpm php-mbstring-5.4.45-56.el7.art.x86_64.rpm php-mcrypt-5.4.45-56.el7.art.x86_64.rpm php-mysql-5.4.45-56.el7.art.x86_64.rpm php-pdo-5.4.45-56.el7.art.x86_64.rpm
```

# Apache

## 联网集成

启动操作参考下面Apache内网集成中

```bash
# httpd -v
Server version: Apache/2.2.15 (Unix)

--若有版本号则无需安装，否则执行该步骤
# yum install httpd
```

## 内网集成

1. centOS6中将httpd的rpm镜像包httpd-2.2.15-59.el6.centos.x86_64.rpm上传到/usr/local/software/路径下

```bash
# httpd -v
Server version: Apache/2.2.15 (Unix)

--若有版本号则无需安装，否则执行该步骤
# rpm -ivh httpd-2.2.15-59.el6.centos.x86_64.rpm

--启动httpd
# service httpd start
--启动服务
# httpd -k start
```

2. centOS7进行相同操作

```bash
# httpd -v
# rpm -ivh httpd-2.4.6-67.el7.centos.6.x86_64.rpm

# service httpd start
# chkconfig httpd on
```

# ShowDoc安装部署

点击[github](https://github.com/star7th/showdoc)下载showdoc-master.zip安装包上传到/usr/local/software/路径下，解压到/var/www/html/路径下

```bash
# cd /usr/local/software/
# unzip showdoc-master.zip -d /var/www/html/
# cd /var/www/html/
# mv showdoc-master showdoc
# chmod -R 777 showdoc/
```

在浏览器中运行 http://serverIP/showdoc/install/ ，若出现以下提示，需关闭selinux

```bash
请赋予 install 目录以可写权限！
请赋予 Public/Uploads/ 目录以可写权限！
请赋予 Application/Runtime 目录以可写权限！
请赋予 server/Application/Runtime 目录以可写权限！
请赋予 Application/Common/Conf/config.php 文件以可写权限！
请赋予 Application/Home/Conf/config.php 文件以可写权限！
(如果你确定赋予了文件权限但却一直看到此信息，则可考虑关闭selinux试试)
```

## 关闭selinux

```bash
# getenforce
Enforcing

--假设selinux是正在运行的，可临时关闭，不用重启生效
# setenforce 0
# getenforce
Permissive
```

重新install，若仍然出线以上提示，需要编辑文件以永久关闭，并且重启服务器

```bash
# vim /etc/sysconfig/selinux
--修改
SELINUX=disabled
--保存后重启
# init 6
--重启后查看
# getenforce
Disabled
```

# 使用ShowDoc

安装成功后，可删除/var/www/html/showdoc/下的install目录，以防错误重复安装；默认用户密码为：showdoc/123456；可自行注册用户账号并登陆. 

# 同类产品

[rap2 for ali](http://rap2.taobao.org/)

[eolinker for free](https://www.eolinker.com/)

[apiDoc for documentation](http://apidocjs.com/)