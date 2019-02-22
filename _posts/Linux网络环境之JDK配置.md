---
title: Linux网络环境之JDK安装配置
date: 2017-03-02 19:43:26
tags:
- VirtualBox
- CentOS
- Linux
categories: Linux
---
记录开源虚拟机软件VirtualBox安装CentOS以及网络和JDK的相关环境配置

<!--more-->

# 安装包

* 点击下载-->[<font face="Times New Roman" color=#0099ff>VirtualBox5.1.18</font>](http://download.virtualbox.org/virtualbox/5.1.18/VirtualBox-5.1.18-114002-Win.exe)

* 点击下载-->[<font face="Times New Roman" color=#0099ff>Xshell5.0</font>](http://download.csdn.net/detail/weixin_37479489/9864277)

* 点击下载-->[<font face="Times New Roman" color=#0099ff>CentOS7.2</font>](http://isoredirect.centos.org/centos/7/isos/x86_64/CentOS-7-x86_64-DVD-1611.iso)

* 点击下载-->[<font face="Times New Roman" color=#0099ff>JDK1.8_Linux</font>](http://download.oracle.com/otn-pub/java/jdk/8u121-b13/e9e7ea248e2c4826b92b3f075a80e441/jdk-8u121-linux-x64.rpm)

# 网络环境设置

## 虚拟机网络

* 设定VirtualBox虚拟网卡的IP地址 如：192.168.0.1
* 设置VirtualBox虚拟机网络连接方式：host-only网络

## 网络配置

> 修改主机名

```bash
# hostnamectl set-hostname testmaster
# hostname
```

> network配置

```bash
# vim /etc/sysconfig/network
清空network配置文件，添加
NETWORKING=yes
GATEWAY=192.168.0.1
```

> inet配置

```bash
# vim /etc/sysconfig/network-scripts/ifcfg-enp0s3
清空ifcfg-enp0s3配置文件，添加
TYPE=Ethernet
IPADDR=192.168.0.2
NETMASK=255.255.255.0
```

> 关闭防火墙

```bash
# systemctl stop firewalld
# system disable firewalld
```

## 相关信息

> 检测网络

```bash
# service network restart
# ifconfig
# ping 192.168.0.1
```

> 检测ssh服务状态

```bash
# service sshsd status
# systemctl status sshd
```

> 系统信息

```bash
# cat /etc/redhat-release 
CentOS Linux release 7.2.1511 (Core) 
```

|Hostname|IP|OS|
|---|---|---|
|testmaster|192.168.0.2|CentOS7.2|

# JDK安装配置

## 解压安装

> 使用[<font face="Times New Roman" color=#0099ff>FileZilla</font>](http://download.csdn.net/detail/weixin_37479489/9863014)或者Xftp工具将JDK的安装包上传到testmaster的/usr/local/目录下

```bash
# cd /usr/local
# rpm -ivh jdk-8u91-linux-x64.rpm
```

> jdk默认安装在/usr/java目录下,验证

```bash
# cd /usr/java/default
# rpm -qa | grep jdk
# java
```

## 配置环境变量

> 先备份profile文件

```bash
# cp /etc/profile /etc/profile.bak
```

> 配置环境变量

```bash
# vim /etc/profile
在最后添加以下内容 
export JAVA_HOME=/usr/java/default
export JRE_HOME=${JAVA_HOME}/jre  
export CLASSPATH=.:${JAVA_HOME}/lib:${JRE_HOME}/lib  
export PATH=${JAVA_HOME}/bin:$PATH
使配置文件立即生效
# source /etc/profile
```

> 验证

```bash
# java -version
```