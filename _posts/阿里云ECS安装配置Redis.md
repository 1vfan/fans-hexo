---
title: 阿里云ECS安装配置Redis
date: 
tags:
- redis
- 阿里云
---

记录redis在阿里云服务器上的简单安装连接.

<!--more-->

## ECS

通过免费套餐或购买阿里云服务器ECS（购买其他特定产品时，如果需要通过ECS访问这些产品的实例，要选择与ECS相同的专有网络VPC，实例的VPC一经确定无法更改，也可以先选择经典网络，之后改成VPC）；

管理控制台查看ECS实例（实例ID、公网IP、状态、配置），``ssh root@公网IP`` 密码可以通过``更多 - 密码 - 修改远程连接密码``重新获得。


## Redis安装配置

[<font color=#0099ff size=4>redis</font>](https://github.com/1vfan/Install/tree/master/redis)

### 系统依赖

redis编译依赖插件gcc

```bash
yum install -y gcc-c++
```

### 用户

```bash
### -m 自动建立用户的登入目录stefan
groupadd stefan
useradd -g stefan -m stefan
passwd ******
```

### 下载安装

```bash
su stefan
cd /home/stefan//Downloads
wget http://download.redis.io/releases/redis-3.2.9.tar.gz
tar -xf redis-3.2.9.tar.gz -C ../
cd /home/stefan/redis-3.2.9 && make
cd /home/stefan/redis-3.2.9/src && make PREFIX=/home/stefan/redis-stefan install
ls /home/stefan/redis-stefan/bin
# redis-benchmark redis-cli  redis-server  redis-sentinel->redis-server redis-check-aof  redis-check-rdb
```

### 重构目录

```bash
cd /home/stefan/redis-stefan
mkdir etc pid data logs
cp /home/stefan/redis-3.2.9/redis.conf /home/stefan/redis-stefan/etc/
vim /home/stefan/redis-stefan/etc/redis.conf
```

### 配置文件

```bash
#bind 127.0.0.1
requirepass ******
protected-mode yes
daemonize yes
pidfile /home/stefan/redis-stefan/pid/redis_6379.pid
port 6379
logfile /home/stefan/redis-stefan/logs/redis.log
dbfilename dump-6379.rdb
dir /home/stefan/redis-stefan/data/
maxmemory 500MB
appendonly yes
```

### 启关

```bash
###启动
/home/stefan/redis-stefan/bin/redis-server /home/stefan/redis-stefan/etc/redis.conf
###连接
/home/stefan/redis-stefan/bin/redis-cli
###关闭
/home/stefan/redis-stefan/bin/redis-cli shutdown

ps -ef | grep redis
```

## ECS端口

此时，公网客户端还连不上ECS中的redis实例，因为ECS没有对外开放连接所需的``6379``端口。

添加规则开放连接端口：``管理控制台 - ECS - 网络与安全/安全组 - 配置规则 - (入方向)添加安全组规则 - TCP、6379/6379、0.0.0.0/0``

## 客户端连接

```java
/**
 * single redis client
 */
public class SingleJedisTest {

    private static Jedis jedis;

    @BeforeClass
    public static void init() {
        jedis = new Jedis("Aliyun-ECS",6379);
    }

    @AfterClass
    public static void close() {
        jedis.close();
    }

    @Test
    public void single_set() {
        jedis.auth("******");
        jedis.select(4);
        jedis.set("name", "Stefan");
    }
}
```

