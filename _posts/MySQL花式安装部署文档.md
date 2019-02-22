---
title: MySQL花式安装部署文档
date: 
tags:
- MySQL
- Docker
- Linux
---

记录Linux环境中多种方式安装部署MySQL数据库服务。

<!--more-->

## rpm安装

### 安装

```bash
###卸载原装
# rpm -qa | grep mysql
# rpm -e ...

###安装启动
[root@Slave2 ~]# yum install -y mysql-server
No package mysql-server available.
Error: Nothing to do
[root@Slave2 ~]# wget http://repo.mysql.com/mysql57-community-release-el7.rpm
[root@Slave2 ~]# rpm -ivh mysql57-community-release-el7.rpm
[root@Slave2 ~]# yum install -y mysql-server
```

### 启动

```bash
###进程检测
[root@Slave2 ~]# service mysqld start
[root@Slave2 ~]# netstat -tulpn
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name
tcp6       0      0 :::3306                 :::*                    LISTEN      3022/mysqld                 
[root@Slave2 ~]# ps aux | grep mysql
mysql      3022  0.0  4.8 1120732 185660 ?      Sl   15:31   0:01 /usr/sbin/mysqld --daemonize --pid-file=/var/run/mysqld/mysqld.pid
root       3181  0.0  0.0 112704   972 pts/0    S+   16:19   0:00 grep --color=auto mysql

###mysql5.7在centOS7中好像默认开机自启动
[root@Slave2 ~]# systemctl list-unit-files | grep mysqld
mysqld.service                                enabled
mysqld@.service                               disabled
###设置或取消开机自启动的方式
[root@Slave2 ~]# systemctl  enable mysqld
[root@Slave2 ~]# systemctl  disable mysqld

###登陆出错或初始密码未知
[root@Slave2 ~]# mysql
ERROR 1045 (28000): Access denied for user 'root'@'localhost' (using password: NO)
ERROR 1045 (28000): Access denied for user 'root'@'localhost' (using password: YES)

###先允许免密码登陆,修改root用户密码
[root@Slave2 ~]# echo 'skip-grant-tables' >> /etc/my.cnf
[root@Slave2 ~]# mysql
mysql> use mysql
mysql> select host, user, authentication_string from user;
mysql> update user set authentication_string = password('centOS7/') where user = 'root';
mysql> exit

###去除免密码设置并重启mysql服务
[root@Slave2 ~]# vim /etc/my.cnf
GG dd
[root@Slave2 ~]# service mysqld stop
[root@Slave2 ~]# service mysqld start
```

### 授权

```bash
###系统要求你重设密码并密码包含大小写、数字、特殊字符
mysql> show databases;
ERROR 1820 (HY000): You must reset your password using ALTER USER statement before executing this statement.
mysql> set password = password('root');
ERROR 1819 (HY000): Your password does not satisfy the current policy requirements
mysql> set password = password('centOS7/');
Query OK, 0 rows affected, 1 warning (0.01 sec)
```

```bash
###设置允许任意远程主机登陆
mysql> use mysql
mysql> grant all privileges on *.* to 'root'@'%' identified by 'centOS7/' with grant option;

mysql> flush privileges;
Query OK, 0 rows affected (0.00 sec)

mysql> select host,user,authentication_string from user;
+-----------+---------------+-------------------------------------------+
| host      | user          | authentication_string                     |
+-----------+---------------+-------------------------------------------+
| localhost | root          | *3EACF99850E716125A4463F6ED573D1FA115243D |
| localhost | mysql.session | *THISISNOTAVALIDPASSWORDTHATCANBEUSEDHERE |
| localhost | mysql.sys     | *THISISNOTAVALIDPASSWORDTHATCANBEUSEDHERE |
| %         | root          | *3EACF99850E716125A4463F6ED573D1FA115243D |
+-----------+---------------+-------------------------------------------+

mysql> delete from  user where host != '%';
Query OK, 3 rows affected (0.00 sec)

mysql> select host,user,authentication_string from user;
+------+------+-------------------------------------------+
| host | user | authentication_string                     |
+------+------+-------------------------------------------+
| %    | root | *3EACF99850E716125A4463F6ED573D1FA115243D |
+------+------+-------------------------------------------+
```



## 二进制通用版安装

[<font color=#00999ff size=4>参照网上教程</font>](https://www.linuxidc.com/Linux/2016-03/129187.htm)


## Docker镜像安装

### 拉取镜像

```bash
# rpm -qa | grep docker
# rpm -e ...
# yum install -y docker-io
# vi /etc/docker/daemon.json
{

  "registry-mirrors": ["http://f1361db2.m.daocloud.io"]

}
# systemctl start docker

# docker pull mysql:5.6
```

### 设置挂载

```bash
###首先启动容器
# docker run --name mysql_docker1 -p 3307:3306 -e MYSQL_ROOT_PASSWORD=123456 -d mysql:5.6

###将容器中mysql的数据与配置依赖文件下载到本地(本地路径自动创建)
# docker cp mysql_docker1:/var/lib/mysql /mysql/data
# docker cp mysql_docker1:/etc/mysql /mysql/conf

###最后另起一个容器挂载本地
# docker run --name mysql_docker2 -p 3306:3306 --privileged=true -v /mysql/data:/var/lib/mysql -v /mysql/conf:/etc/mysql -e MYSQL_ROOT_PASSWORD=123456 -d mysql:5.6

###进入容器登陆mysql数据库
# docker exec -it mysql_docker2 /bin/bash
/ mysql -uroot -p123456
```

注意: Centos7安全Selinux禁止了一些安全权限，需使用参数``--privileged=true``保证正常挂载(通过docker volume ls查看)；或禁用selinux.

### 登陆测试

使用数据库客户端工具登陆(宿主机IP:3306 root:123456)，在数据库中创建新的库、表，数据会立刻保存到宿主机中/mysql/data路径下；

第一次设置密码运行容器后，密码会存储在本地挂载文件中，之后使用相同挂载运行的容器无需设置密码，系统会自动加载本地挂载文件中记录的密码(因此就算标注了也无效)。

```bash
# docker run --name mysql_docker3 -p 3308:3306 --privileged=true -v /mysql/data:/var/lib/mysql -v /mysql/conf:/etc/mysql -d mysql:5.6
```

注意: 使用相同本地volume挂载运行的不同容器，有且只有一个容器可以处于正常服务状态，但所有容器在正常状态下可以共享本地文件中的数据。

