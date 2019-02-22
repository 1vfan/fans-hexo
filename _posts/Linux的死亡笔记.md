---
title: Linux的死亡笔记
date: 2017-04-15 16:23:28
tags:
- Linux
- DeathNote
categories: 
- Linux
---

记录CentOS6~7 常用命令

<!--more-->

# 基本操作

## cd

```bash
###返回到上一次路径
# cd -

# cd
# cd ../..
```

## ls/ll

```bash
###显示文件大小
# ll -h
###按文件大小排序
# ll -hS

###按文件字典序反向排序显示
# ll -r

###按时间正向排序
# ll -t

# ls -lrt 或 ls -lrth  或 ll -rth
```

## cat/more/head/tail/less

```bash
###-s不显示多行空行  -b非空行编号
# cat -sb
###将两个文件一起查看
# cat -sb a.txt b.txt | more

###创建文件并输入内容,输入STOP时会退出
# cat > c.txt << STOP

###将多个文件内容输入到新文件中 >是覆盖 >>追加
# cat a.txt b.txt c.txt >> e.txt
```

```bash
###终端顶部开始显示
# more -dc a.txt

###从第2行还是显示没屏显示4行，空格下一屏，ctrl+b 返回上一屏
# more +2 -4 a.txt

###从文件中第一个单词sb的前两行开始输出
# more +/sb a.txt

###目录中文件太多可以通过more分页查看
# ll /test | more
```

```bash
###显示文件的前几行
# head -n 4 a.txt

###显示文件的后几行
# tail -n 10 a.txt

###显示文后10行内容并在文件内容增加后自动显示新增内容; 尤其在监控日志文件时，可以在屏幕上一直显示新增的日志信息
# tail -f a.txt
```

```bash
###-N显示行号
# less -N /tets/a.txt
###搜索单词sb
# /sb
###v切换到vi编辑器
###q退出less
###g跳到第一行
###G跳到最后一行
```

## cp

```bash
###将匹配文件拷贝到上一级目录，如果原先存在一样的文件，会先备份然后替换
# cp -b 2018*.del ../

###将/opt/test/路径下的文件及其子目录文件 拷贝到另一个目录下
# cp -r /opt/test/ /opt/test1/

###拷贝到另一路径，并更改名称
# cp test.del /opt/test/test1.del 

###修改时间和访问权限也复制到新文件
# cp -p test.txt /test2/
```

## mv

```bash
###移动到当前路径
# mv /test/2018* .

# mv /test/2018.del /test/2017.del
```

## mkdir

```bash
###-m赋权限  -p多级新建
# mkdir -m 750 -p /test/test1/test2
```

## iconv

```bash
###字符集转换命令 utf-8 -> gbk
# iconv -f utf8 -t gbk test_utf8.del > test_gbk.del
```

## grep

```bash
###查询日志文件中包含关键词记录的行号2000
# grep -n '2016-12-11 15:00:03' hbase-20161211.log
2000:2016-12-11 15:00:03
###查询出日志文件总行号
# cat hbase-20161211.log | wc -l
4000
###截取需要的部分内容追加到新文件中
# sed -n '2000, 4000p' hbase-20161211.log >> new.log
```

```bash
## 查看配置文件生效属性
# grep '^[a-z]' elasticsearch.yml

# grep -n '^[0-9]' new.log
```

## yum/rpm

```bash
###安装
# rpm -ivh ..
# yum install -y docker-io

###查看已安装rpm及依赖
# rpm -qa | grep docker
# yum list installed | grep docker

###卸载
# rpm -e ...
# rpm -e --nodeps ...
```

# 常用命令

## 软链接

安装到/home下的was空间不足，将安装目录转移到空间足够的挂载盘/root，然后软链接到原始目录

```bash
# cd /
# mv /home/IBM /root
# ln -s /root/IBM /home/IBM
```

/home/IBM 中的IBM就变成了一个软链接，链接到真实存储资源的/root/IBM.

```bash
###删除软链接
# cd /home
###注意删除软链接是rm -rf XXX  而不是删除文件 rm -rf XXX/
# rm -rf IBM
```

## 压缩与解压

```bash
yum install -y zip unzip
zip -r test.zip ./* 当前目录中的所有文件递归压缩成zip包
zip -r test.zip a.txt b.txt c.txt /usr/local 目录文件一并压缩
zip -d test.zip a.txt 删除压缩文件test.zip中的a.txt文件
zip -m test.zip b.txt 向压缩文件test.zip中添加b.txt文件
unzip test.zip -d /var/local/ 解压到指定目录

tar -cf test.tar ./*.jpg
tar -xf test.tar

tar -zcf /usr/local/test.tar.gz ./*.jpg
tar -zxf /usr/local/test.tar.gz -C /var/  

rar a test.rar ./*.jpg
unrar e test.rar

gzip test.del -> test.del.gz
gunzip test.del.gz -> test.del
```


## 定时执行任务

cron服务是Linux的内置服务，但它不会开机自动启动，要把cron设为在开机的时候自动启动，在 ``/etc/rc.d/rc.local`` 脚本中加入 ``/sbin/service crond start`` 即可.

```bash
###启动、停止、重启服务和重新加载服务
# /sbin/service crond start
# /sbin/service crond stop
# /sbin/service crond restart
# /sbin/service crond reload

###查看用户拥有的定时任务 
#crontab -l -u root

###编辑定时任务 可添加删除 
# crontab -e

###每天3点每隔一分钟执行一次，共60次到3点结束不再执行
* 3 * * * /test/test.sh
###每2个小时执行一次
* */2 * * * /test/test.sh
###每周六周日3点整执行一次
0 3 * * 6,0 /test/test.sh
###每个工作日3点整执行一次
0 3 * * 1-5 /test/test.sh
###每个月1号的3点
0 3 1 * * /test/test.sh
###每天1点整执行一次
0 1 * * * /test/test.sh >> /test/test.log 2>&1
```

cron文件位置``/var/spool/cron/root``，cron日志位置``/var/log/cron-xxxxxxxx``.

## 定时任务日志输出

```bash
30 2 * * * /test/test.sh >> /test/test.log 2>&1
```

``1``代表标准输出，``2``代表标准错误，``2>&1``代表将标准错误重定向到标准输出，即脚本执行时出现的异常信息同样会保存到log日志文件中，如果不添加则出现异常不会被记录，日志文件中只会有正常信息。

## 远程执行命令

```bash
# ssh root@192.168.1.1 "rm -rf /test1/test2"
# ssh root@192.168.1.1 "mkdir -p /test1/test2"
```

## 服务器间文件copy

```bash
# scp /usr/local/*.tar.gz root@192.168.1.1:/usr/local/software
```

## pscp上传下载

利用pscp.exe上传文件到linux服务器中的特定目录下

```bash
###上传
D:\Users> pscp D:\DATA\index.zip root@158.222.14.14:/home/bgis/indexs/
root@158.222.14.14‘s password:123456

###下载
D:\Users> pscp root@158.222.14.14:/home/bgis/indexs/index.zip D:\DATA\
root@158.222.14.14‘s password:123456
```

## 快速增加文件内容

```bash 
# echo "vm.max_map_count=655360" >> /etc/sysctl.conf
```

## 关闭防火墙

firewall
```bash
# firewall-cmd --state
# systemctl stop firewalld.service
# systemctl disable firewalld.service
```

iptables
```bash
# iptables -F   --清空所有防火墙规则
# service iptables status
# service iptables start
# service iptables stop    --重启后会恢复
# chkconfig iptables off   --永久生效
# chkconfig iptables on
```

## 关闭selinux

临时关闭

```bash
# getenforce
Enforcing

# setenforce 0
# getenforce
Permissive
```

永久关闭：
```bash
# vim /etc/sysconfig/selinux
SELINUX=enforcing --> SELINUX=disabled

# init 6
```

## 文件命令

```bash
# view xxx （或 vim 查看文件）
# :set nu （或 :set number 显示行号）
# :1000 (跳转到哪一行)
# /关键词   （查找关键字，n下一个，N前一个）
# q! （不保存退出）
```

```bash
# cat xxx （一次性输出）
# more xxx （分批次输出）
# more +1000 xxx （从xxx第1000行开始输出）
# tail -n1000 xxx （输出xxx倒数1000行内容）
# head -10 xxx （查看前10行）
```

```bash
# 0   (移动到行首)
# $   (移动到行尾)
# gg  (移动到开头)
# GG  (移动到结尾)
```

```bash
# yy (复制当前行)
# yw (复制当前一个单词)
# p (粘贴)
# dd (删除当前行)
# :.,$-1d (从光标行删除到倒数第一行)
```

## 同步系统时间

```bash
# yum install ntp
# ntpdate time.nuri.net
 4 Jul 21:59:02 ntpdate[3503]: step time server 211.115.194.21 offset 9360.438555 sec
# date

时间服务器
time.nist.gov
time.nuri.net
0.asia.pool.ntp.org
1.asia.pool.ntp.org
2.asia.pool.ntp.org
3.asia.pool.ntp.org
```

## 下载安装open JDK

* Oraclejdk：官网下载
* openjdk:使用yum install

java-1.8.0-openjdk.x86_64 只是JRE，开发还需要 java-1.8.0-openjdk-devel.x86_64

```bash
# yum list all | grep jdk
# yum install java-1.8.0-openjdk.x86_64
# which java
/usr/bin/java
# ls -l /usr/bin/java
lrwxrwxrwx. 1 root root 22 5月   3 21:18 /usr/bin/java -> /etc/alternatives/java
# ls -l /etc/alternatives/java
lrwxrwxrwx. 1 root root 73 5月   3 21:18 /etc/alternatives/java -> /usr/lib/jvm/java-1.8.0-openjdk-1.8.0.131-3.b12.el7_3.x86_64/jre/bin/java
# vim /etc/profile.d/java.sh
添加
export JAVA_HOME=/usr

# yum install java-1.8.0-openjdk-devel.x86_64
# java -version
openjdk version "1.8.0_131"
OpenJDK Runtime Environment (build 1.8.0_131-b12)
OpenJDK 64-Bit Server VM (build 25.131-b12, mixed mode)
```

## hostname和FQDN

FQDN是Fully Qualified Domain Name的缩写, 含义是完整的域名；hostname就是主机名

```bash
###查询
# hostname
# hostname -f

###临时修改重启后不生效
# hostname ES

###修改后永久生效，其实命令是修改/etc/hostname文件
# hostnamectl set-hostname ES
###但是ES会变成小写的es，需要修改以下文件然后重启才生效
# echo "ES" > /ect/hostname

修改FQDN，es.git.cn为FQDN，ES为hostname
# echo "NETWORK=yes" >> /etc/sysconfig/network
# echo "HOSTNAME=ES" >> /etc/sysconfig/network
# echo "192.168.1.1 es.git.cn ES" >> /etc/hosts

重启后查看结果
# hostname
ES
# hostname -f
es.git.cn
```

## 使用yum下载RPM包

centos下执行yum install命令，系统会从yum源下载rpm，将rpm放置到缓存目录 /var/cache/yum/下，（yum源不同，下载后存放路径也有所不同，通常都/var/cache/yum/***/packages下）

### 只下载RPM包不安装和升级

若想通过yum命令只下载RPM包而不安装，需要如下操作：

```bash
安装yum-downloadonly插件：
# yum install yum-downloadonly

安装后yum就多了两个命令参数:
--downloadonly
--downloaddir=/usr/local/rpm

示例：
# yum install httpd-2.4.6-67.rpm --downloadonly --downloaddir=/usr/local/rpm

若系统已安装httpd-2.4.6-67.rpm，则不会下载成功，可以先移除在下载
# yum  remove httpd-2.4.6-67.rpm
# yum install httpd-2.4.6-67.rpm --downloadonly --downloaddir=/usr/local/rpm
```


### 自动安装或升级同时保留RPM包

yum 默认情况下升级或者安装后会删除下载的rpm包；可以通过如下设置，升级后不删除下载的rpm包

```bash
vim/etc/yum.conf
[main]
cachedir=/var/cache/yum
keepcache=0
```

将 keepcache=0 修改为 keepcache=1， 安装或者升级后，在对应 /var/cache/yum/***/packages 路径下就有了下载的rpm包.


## 配置本地yum源

当连接不上外网，yum无法安装软件时，使用iso做本地yum源，可以解决大部份的包安装

### 磁盘挂载

使用df-h查看磁盘挂载情况：如果没有则挂载系统盘，使用mount /dev/cdrom /media命令挂载；如果开机自动挂载到桌面上[带桌面的Linux系统]，那么需要先卸载：umount /dev/cdrom ，再重新挂载：mount /dev/cdrom /media

```bash
# df -h
文件系统                 容量  已用  可用 已用% 挂载点
/dev/mapper/centos-root   18G  1.1G   17G    6% /
devtmpfs                 485M     0  485M    0% /dev
tmpfs                    495M     0  495M    0% /dev/shm
tmpfs                    495M  6.8M  488M    2% /run
tmpfs                    495M     0  495M    0% /sys/fs/cgroup
/dev/sda1                497M  126M  371M   26% /boot
tmpfs                     99M     0   99M    0% /run/user/0
# mount /dev/cdrom /media
mount: /dev/sr0 写保护，将以只读方式挂载
# df -h
文件系统                 容量  已用  可用 已用% 挂载点
/dev/mapper/centos-root   18G  1.1G   17G    6% /
devtmpfs                 485M     0  485M    0% /dev
tmpfs                    495M     0  495M    0% /dev/shm
tmpfs                    495M  6.9M  488M    2% /run
tmpfs                    495M     0  495M    0% /sys/fs/cgroup
/dev/sda1                497M  126M  371M   26% /boot
tmpfs                     99M     0   99M    0% /run/user/0
/dev/sr0                 4.1G  4.1G     0  100% /media
```

### 配置本地yum源

```bash
# cd /etc/yum.repos.d/
创建一个以repo结尾的文件，如：yum.repo
# vim yum.repo
[base]
name=yum
enabled=1
baseurl=file:///media
gpgcheck=0

更新yum配置
# yum clean all
# yum makecache
就可以使用本地源下载安装软件包了
# yum install xxx
```

### 报错

```bash
no space left on device

解决办法：df -h 查看对应磁盘是否空间不足
```

```bash
bash: ./test.sh: /bin/bash!: bad interpreter: No such file or directory  

解决方法：vim test.sh后执行 :set fileformat=unix 保存修改后就可以运行改脚本了
```

## 系统状态

### 关机重启

```bash
###关机
# shutdown -h now
###重启
# reboot
###优雅重启
# init 6
```


### 内存

```bash
###内存信息总览
# cat /proc/meminfo

###总内存
# cat /proc/meminfo | grep MemTotal
###剩余内存
# cat /proc/meminfo | grep MemFree
```

### 硬盘

```bash
###系统磁盘挂载空间
# df -lh

# fdisk -l | grep Disk
```

### 系统版本

查看操作系统版本（el6）,CPU类型（x86_64）

```bash
# uname -a
Linux tdh01 2.6.32-431.el6.x86_64 #1 SMP ... GNU/Linux

# lsb_release -a
```

### CPU

```bash
# dmidecode | grep CPU
# cat /proc/cpuinfo
```

### 进程

```bash
# ps aux | grep IBM
# ps aux | grep java
# ps -ef | grep tomcat
```

### uptime

想知道系统上一次复位是什么时候或者系统运行了多长时间

```bash
# uptime
16:51:16 up 356 days, 2:52,  5 users,  load average: 0.08, 0.25, 0.46
###当前时间、已运行时间、用户登录数、（1分钟、5分钟、15分钟内系统的平均负载）
```

### who

查看哪些用户通过哪个ip登陆过该主机

```bash
# who
root  pts/1 2018-05-11 10:22 (158.222.63.103)

# who -a
```

### export

```bash
# export

# echo $PATH
```


# Shell

## 循环插入

```bash
for i in `seq 0 1000`; do echo $i:hello >> a.txt; done;
```

