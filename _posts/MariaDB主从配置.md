---
title: MariaDB主从安装配置
date: 2017-06-07 12:22:41
tags:
- MariaDB
- MySQL
categories: 
- 数据库
---
记录MariaDB在Linux中的主从配置

<!--more-->

## 卸载原装mariadb

如果系统自带mariadb，最好将其删除后重新安装，防止不必要的错误

```bash
停止服务
# systemctl stop mariadb
查询安装包
# rpm -qa | grep mariadb
mariadb-libs-5.5.44-2.el7.centos.x86_64
卸载安装包
# rpm -e mariadb-libs
错误：依赖检测失败：
	libmysqlclient.so.18()(64bit) 被 (已安裝) postfix-2:2.10.1-6.el7.x86_64 需要
	libmysqlclient.so.18(libmysqlclient_18)(64bit) 被 (已安裝) postfix-2:2.10.1-6.el7.x86_64 需要
# rpm -e postfix-2:2.10.1-6.el7.x86_64
# rpm -e mariadb-libs-5.5.44-2.el7.centos.x86_64
```

## 开始安装

```bash
下载安装
# yum -y install mariadb mariadb-server
拷贝文件
# cp /usr/share/mysql/my-huge.cnf /etc/my.cnf
root帐号
# vim /etc/my.cnf
在[mysqld]后添加
lower_case_table_names=1 （不区分表名的大小写）

查看防火墙状态
# systemctl status firewalld
停止防火墙
# systemctl stop firewalld
设置开机不启用防火墙
# systemctl disable firewalld

启动
# systemctl start mariadb
开机自启动
# systemctl enable mariadb
Created symlink from /etc/systemd/system/multi-user.target.wants/mariadb.service to /usr/lib/systemd/system/mariadb.service.


问题：
[root@mariadb-slave run]# systemctl start mariadb
Job for mariadb.service failed because the control process exited with error code. See "systemctl status mariadb.service" and "journalctl -xe" for details.

解决方案：
# vim /etc/hosts
修改
ip FQDN hostname
```

## 设置mariadb数据库

```bash 
执行脚本
# /usr/bin/mysql_secure_installation

Enter current password for root (enter for none): 安装后默认没有root密码，直接回车

Set root password? [Y/n] Y
New password: 输入root的新密码
Re-enter new password: 新密码确认

Remove anonymous users? [Y/n] 删除匿名用户 Y

Disallow root login remotely? [Y/n] 关闭root远程登录 Y

Remove test database and access to it? [Y/n] 删除test数据库 n

Reload privilege tables now? [Y/n] 确定以上所有操作 Y

All done!  If you've completed all of the above steps, your MariaDB
installation should now be secure.
Thanks for using MariaDB!
```

## 设置主从

单独有一个进程进行主从之间的同步，负责在主、从服务器传输各种修改动作的媒介是主服务器的二进制变更日志（binary log），这个日志记载着需要传输给从服务器的各种修改动作，进程中的特定用户将binary log从主服务器刷到从服务器中，从服务器将日志解析成SQL执行实现主从同步。

### 配置主节点

在主节点建立主从复制用户slave并授权，这个用户就是为了创建一个进程，进行主从同步的；避免其他资源占用，所以该用户既不能是root，也不能是java连接数据库的用户

```bash
#语法：GRANT REPLICATION SLAVE ON *.*{所有权限} TO 'slave'@'%'{用户名为slave，%为任意地址} identified by 'slave'{密码为slave};
登陆主节点
# mysql -uroot -proot
> GRANT REPLICATION SLAVE ON *.* TO 'slave'@'%' identified by 'slave';
Query OK, 0 rows affected (0.08 sec)

查看master状态
> show master status;
+------------------+----------+--------------+------------------+
| File             | Position | Binlog_Do_DB | Binlog_Ignore_DB |
+------------------+----------+--------------+------------------+
| mysql-bin.000005 |     1292 |              |                  |
+------------------+----------+--------------+------------------+
1 row in set (0.00 sec)
```

### 配置从节点

当Slave_IO_Running: Yes 和 Slave_SQL_Running: Yes 都显示为Yes，则主从配置成功

```bash
从节点修改server-id，主节点无需修改
# vim /etc/my.cnf
server-id    = 2
修改后重启从节点mariadb
# systemctl restart mariadb

#语法：CHANGE MASTER TO MASTER_HOST='主节点的IP地址',MASTER_USER='主节点授权的用户',MASTER_PASSWORD='主节点授权的用户的密码',MASTER_LOG_FILE='主节点的file',MASTER_LOG_POS=主节点的position;
#PS：注意语法逗号前后不要用空格
# mysql -uroot -proot
> CHANGE MASTER TO MASTER_HOST='192.168.154.20',MASTER_USER='slave',MASTER_PASSWORD='slave',MASTER_LOG_FILE='mysql-bin.000005',MASTER_LOG_POS=1292;

> show slave status\G;
*************************** 1. row ***************************
               Slave_IO_State: 
                  Master_Host: 192.168.154.20
                  Master_User: slave
                  Master_Port: 3306
                Connect_Retry: 60
              Master_Log_File: mysql-bin.000005
          Read_Master_Log_Pos: 1292
               Relay_Log_File: mariadb-slave-relay-bin.000001
                Relay_Log_Pos: 4
        Relay_Master_Log_File: mysql-bin.000005
             Slave_IO_Running: No
            Slave_SQL_Running: No

解决方案：
> stop slave;
> start slave;
> show slave status\G;
*************************** 1. row ***************************
               Slave_IO_State: Waiting for master to send event
                  Master_Host: 192.168.154.20
                  Master_User: slave
                  Master_Port: 3306
                Connect_Retry: 60
              Master_Log_File: mysql-bin.000005
          Read_Master_Log_Pos: 1292
               Relay_Log_File: mariadb-slave-relay-bin.000002
                Relay_Log_Pos: 529
        Relay_Master_Log_File: mysql-bin.000005
             Slave_IO_Running: Yes
            Slave_SQL_Running: Yes
```

## 授权远程root登陆

主从节点都要进行授权设置

```bash
# mysql -uroot -proot
> GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY 'root' WITH GRANT OPTION;  
Query OK, 0 rows affected (0.06 sec)
> FLUSH PRIVILEGES;
Query OK, 0 rows affected (0.03 sec)
```

## 测试

在主节点上新建数据库表ST_USERS，然后刷新从节点，发现从节点上也自动新增了ST_USERS表；主节点上删除ST_USERS，同时从节点表ST_USERS也自动消失了；说明主从节点数据库已同步

## 异常解决方案

异常：Slave_SQL_Running: No

```bash
> show slave status\G;
*************************** 1. row ***************************
               Slave_IO_State: Waiting for master to send event
                  Master_Host: 192.168.154.20
                  Master_User: slave
                  Master_Port: 3306
                Connect_Retry: 60
              Master_Log_File: mysql-bin.000005
          Read_Master_Log_Pos: 1292
               Relay_Log_File: mariadb-slave-relay-bin.000002
                Relay_Log_Pos: 529
        Relay_Master_Log_File: mysql-bin.000005
             Slave_IO_Running: Yes
            Slave_SQL_Running: No
```

可能原因：

* 程序可能在slave上进行了写操作
* 也可能是slave机器重起后，事务回滚造成的，一般是事务回滚造成的

解决办法一：

```bash
mysql> stop slave ;
mysql> set GLOBAL SQL_SLAVE_SKIP_COUNTER=1;
mysql> start slave ;
```

解决方法二：

```bash
从节点停掉Slave服务
> stop slave;
主服务器上查看主机状态，记录File和Position对应的值
> show master status;
+------------------+----------+--------------+------------------+
| File             | Position | Binlog_Do_DB | Binlog_Ignore_DB |
+------------------+----------+--------------+------------------+
| mysql-bin.000005 |     5476 |              |                  |
+------------------+----------+--------------+------------------+
1 row in set (0.00 sec)

从节点上执行手动同步（手动同步需要停止master的写操作）：
> change master to 
> master_host='192.168.154.20',
> master_user='slave', 
> master_password='slave', 
> master_port=3306, 
> master_log_file='mysql-bin.000005', 
> master_log_pos=5476;
1 row in set (0.00 sec)

从节点启动Slave服务
> start slave ;
1 row in set (0.00 sec)

查看验证
> show slave status\G;
*************************** 1. row ***************************
               Slave_IO_State: Waiting for master to send event
                  Master_Host: 192.168.154.20
                  Master_User: slave
                  Master_Port: 3306
                Connect_Retry: 60
              Master_Log_File: mysql-bin.000005
          Read_Master_Log_Pos: 5476
               Relay_Log_File: mariadb-slave-relay-bin.000003
                Relay_Log_Pos: 529
        Relay_Master_Log_File: mysql-bin.000005
             Slave_IO_Running: Yes
            Slave_SQL_Running: Yes
```






