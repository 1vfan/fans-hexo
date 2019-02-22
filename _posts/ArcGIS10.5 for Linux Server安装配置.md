---
title: ArcGIS for Server10.4安装配置
date: 2017-08-11 15:13:45
tags:
- ArcGIS
- Linux
categories: 
- GIS
---

记录Esri ArcGIS for Server 10.4 在Linux 7.2中安装部署说明

<!--more-->

## 安装包准备

将安装包和授权许可拷贝到/home/arcgis/

```bash
Server安装包：
ArcGI_for_Server_Linux_104_149446.tar.gz

授权许可：
authorization_5044A57A.ecp
```

## 开始安装

### 关闭防火墙

```bash
# systemctl stop firewalld.service
# systemctl disable firewalld.service
# firewall-cmd --state
```

### 新建用户

```bash
# groupadd esrichina
# useradd -g esrichina -m arcgis
# passwd arcgis

password：zjrc1324 
```

### 修改域名和主机名

修改hostname

```bash
# hostnamectl set-hostname zjrc
# echo "HOSTNAME=zjrc" >> /etc/sysconfig/network
```

修改FQDN

```bash
# echo "158.222.166.89 zjrc.arcgiscloud.com zjrc" >> /etc/hosts
```

init 6 重启后

```bash
# hostname
# hostname -f
```

### 解压授权

```bash
# cd /home/arcgis
# tar -zxvf ArcGI_for_Server_Linux_104_149446.tar.gz
# cd /home
# chown -R arcgis:esrichina /home/arcgis/
# chmod -R 755 /home/arcgis/ArcGISServer/
```

### 修改内核参数

```bash
# vi /etc/security/limits.conf
末尾添加

arcgis soft nofile 65535
arcgis hard nofile 65535
arcgis soft nproc 25059
arcgis hard nproc 25059
root soft nofile 65535
root hard nofile 65535
root soft nproc 25059
root hard nproc 25059
```

### 切换用户安装

```bash
验证：
# su - arcgis
# cd /home/arcgis
-bash-4.2$ ./ArcGISServer/serverdiag/serverdiag
.....
.....
There were 0 failure(s) and 0 warning(s) found:

安装：
-bash-4.2$ cd ArcGISServer/
-bash-4.2$ ./Setup -m console

.....
一直ENTER YES
.....

Where Would you like to install?
ENTER AN ABSOLUTE PATH, OR PRESS <ENTER> TO ACCCEPT THE DAFAULT
: /home/arcgis

INTSALL FOLDER IS: /home/arcgis

Pre-Installation Summary

Install Folder:
    /home/arcgis/server

Installing....

authorization File

Path: (Default: /path/to/file/ecp): /home/arcgis/authorization_5044A57A.ecp

Installation Complete

successfully installed to : /home/arcgis/server

you will be able to acccess AcrsGIS Server Manager by navigating to 
http://zjrc/arcgiscloud.com:6080/arcgis/manager.
```
