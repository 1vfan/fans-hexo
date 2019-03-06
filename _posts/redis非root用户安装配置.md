## 下载

[<font color=#0099ff size=4>redis</font>](https://github.com/1vfan/Install/tree/master/redis)

单进程多线程  可以根据不同端口的redis.conf启动不同的实例。

## 系统依赖

redis编译依赖插件gcc

```bash
yum install -y gcc-c++
```

## 用户

```bash
### -m 自动建立用户的登入目录redis
groupadd redis
useradd -g redis -m redis
passwd xxxxxx
```

## 上传解压编译安装

```bash
scp redis-3.2.9.tar.gz redis@x.x.x.x:/home/redis/Downloads

su redis
tar -xf /home/redis/Downloads/redis-3.2.9.tar.gz -C /home/redis/
cd /home/redis/redis-3.2.9 && make
cd /home/redis/redis-3.2.9/src && make PREFIX=/home/redis/redis-6379 install
ls /home/redis/redis-6379/bin
# redis-benchmark  redis-check-aof  redis-check-rdb  redis-cli  redis-server  redis-sentinel->redis-server
```

## 重构目录

```bash
cd /home/redis/redis-6379
mkdir etc pid data logs
cp /home/redis/redis-3.2.9/redis.conf /home/redis/redis-6379/etc/
vim /home/redis/redis-6379/etc/redis.conf
```

## 配置文件

```bash
----------------------------------------------------------------------
###指定redis只接收来自于这些IP地址的请求，不设置将处理所有请求，生产环境中最好设置
bind 127.0.0.1 192.168.10.2 192.168.10.3 192.168.10.4
###是否作为后台守护进程运行
daemonize yes
###当运行多个redis实例，需要指定不同的pid文件和端口
###.pid文件里保存当前运行redis实例的进程号，redis关闭则文件消失
pidfile /home/redis/redis-6379/pid/redis_6379.pid
port 6379
###在每秒高请求的环境中，需要高积压以避免客户端连接速度缓慢
tcp-backlog 511
###客户端连接保活检测，server端每隔多长时间向连接空闲客户端发起ack请求，关闭无响应的客户端连接，设置0则不检测
tcp-keepalive 300
###客户端空闲超时时间，客户端在这段闲置时间内没有发出任何指令server端则关闭该连接，默认值0则永不关闭
timeout 0
###日志（debug、varbose、notice常用于生产环境、warning非常重要或严重的信息）
loglevel notice
###也可指定标准输出 stdout
logfile /home/redis/redis-6379/logs/redis.log
###可用数据库数量（0-15）可用select n 切换数据库
databases 16
----------------------------------------------------------------------
###当持久化数据到磁盘失败，redis会停止接收写请求；直到下一次rdb持久化成功，redis会自动恢复接收写请求
stop-writes-on-bgsave-error yes
###保存快照的频率（n秒内执行了m条数量的写操作，就会触发一次持久化；可设置多组）
save 900 1
save 300 10
save 60 10000
###持久化rdb文件中的数据对象是否进行LZF算法压缩，快照变小但耗CPU资源
rdbcompression yes
###持久化rdb文件时是否使用CRC64算法校验数据，消耗10%性能
rdbchecksum yes
###持久化文件默认名dump.rdb
dbfilename dump-6379.rdb
###第一次启动redis时dir默认./，会在同级目录下生成dump.rdb
###自定义dir路径后则在新路径中生成新dump.rdb，旧dump.rdb会在服务器重启后会消失，也可手动删除；AOF文件也存在该路径
dir /home/redis/redis-6379/data/
----------------------------------------------------------------------
###哨兵模式支持给slave设置权重值，当master异常权重值小的slave会升级成新master，但设置0表示无法升级成master，默认100
slave-priority 100
###redis提供主从同步功能，设置当前节点为slave，自动从master同步数据
# slaveof <masterip> <masterport>
###若master设置密码，则需要在slave配置，否则master拒绝slave的访问请求
# masterauth <master-password>
###当slave与master断开连接或者正在同步状态时，yes则slave会保持客户端的读写响应，no则除了info、slaveof之外客户端的请求一律返回'SYNC with master in progress'
slave-serve-stale-data yes
###redis2.6后slave默认只读，因为写入slave的数据在主从同步后就会被清除，意义不大
slave-read-only yes
###新增或重新连接的slave无法继续复制过程只是接收主从差异，需要执行所谓的'完全同步'; RDB文件从主服务器传输到从服务器使用磁盘或diskless方式
repl-diskless-sync no
###diskless方式传输前等待时间，设置0则立即传输；3.2.9版本diskless模式处于实验阶段
repl-diskless-sync-delay 5
----------------------------------------------------------------------
###设置Redis连接密码，客户端要通过AUTH <password>命令连接，默认关闭
# requirepass <password>
###安全保护模式，如未设置密码且未bind地址时，可以阻绝陌生连接
protected-mode yes
###防止客户端执行一些危险命令，如下：可以更改<CONFIG>命令名或直接删除该命令
# rename-command CONFIG b840fc02d524045429941cc15f59e41cb7be6c52
# rename-command CONFIG ""
----------------------------------------------------------------------
###redis同时最大客户端连接数（默认10000），当设置值>当前redis进程可使用最大文件描述符数n，则maxclients=n-32
maxclients 10000
###设置redis可用内存容量，一旦达到上限，redis会使用maxmemory-policy中规定的规则移除内存中的数据
###如果无法通过规则移除数据或者设置了'不移除数据'，则需要使用内存的指令无法正常工作（set等），无需内存的指令可正常使用（如get）
###如果是master，需要在系统中留一部分内存空间给同步队列缓存，设置了'不移除数据'则无需考虑这点
maxmemory <bytes>
###内存数据移除规则（无论采用以下哪种，如果没有合适的key可以移除，redis会针对写操作返回错误）：
# volatile-lru：LRU算法移除过期key
# allkeys-lru：LRU算法移除所有key
# volatile-random：随机删除过期key
# allkeys-random：随机删除所有key
# volatile-ttl：移除即将过期的key（最小TTL算法）
# noeviction：不移除数据，对写操作返回错误（默认）
maxmemory-policy noeviction
###LRU和最小TTL都是近似算法，默认redis会检查5个key并选择最近使用的key，可以更改样本大小
###默认值5效果已经够好，10接近真实的LRU但花费更多CPU，3非常快但不太准确
maxmemory-samples 5
----------------------------------------------------------------------
###默认redis异步持久化数据集，但是redis进程挂了或者服务器宕机会导致未持久化的这部分数据丢失
###开启AOF通过fsync将每一次写操作追加到appendonly.aof文件，在服务器宕机时只会丢1秒写入数据
###在单单redis进程挂时只会丢1次写入数据，当redis重启后会加载aof文件恢复之前状态
###但是这样会造成appendonly.aof文件过大，所以redis还支持了BGREWRITEAOF指令，对appendonly.aof进行重新整理
appendonly no
appendfilename "appendonly.aof"
###追加模式（调用fsync()告诉操作系统立即将数据写入磁盘而不使用buffer，一些OS会'立即'进行，一些OS则会'尽快'进行）
### no：不调用fsync()，让OS自行决定何时刷入磁盘，性能最快；
### always：每次写请求都调用fsync()，相对较慢，但数据最安全；
### everysec：每秒钟调用一次fsync()，性能和安全的折衷；
appendfsync everysec
###若AOF追加策略设置always或everysec时，若后台持久化进程(BGSAVE/BGREWRITEAOF)正在执行大量的磁盘IO操作，
###在某些Linux配置中会阻塞redis的fsync()请求，即使执行fsync请求处于不同的线程，
###为缓解这个问题（3.2.9还未修复），设置no相当于appendsync no，当后台持久化进程执行时，主进程不再调用fsync()
no-appendfsync-on-rewrite no
###redis可以自动重写AOF文件，百分比设置0禁用AOF自动重写功能
###当AOF文件较上一次重写增长百分比达到100%，且当前AOF文件大小超过64MB，会触发重写（redis会隐式调用BGREWRITEAOF）
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb


----------------------------------------------------------------------
###指定包含其它的配置文件，如在同一主机上多个Redis实例使用同一份配置文件，同时各实例引用各自特定配置文件
###为保证自定义文件中的配置生效，必须将include这行放在最后一行
include /path/to/6379.conf
```



## 启动

```bash
###启动
/home/redis/redis-6379/bin/redis-server /home/redis/redis-6379/etc/redis.conf
###连接
/home/redis/redis-6379/bin/redis-cli
/home/redis/redis-6379/bin/redis-cli -h 192.168.10.3
###关闭
/home/redis/redis-6379/bin/redis-cli shutdown 
/home/redis/redis-6379/bin/redis-cli -h 192.168.10.2 shutdown 

ps -ef | grep redis
netstat -tunpl | grep 6379
```
