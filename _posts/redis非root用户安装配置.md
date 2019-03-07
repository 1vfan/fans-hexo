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
###当重写AOF文件时，以递增方式每生成32MB数据fsync到磁盘文件中，并避免大延迟峰值
aof-rewrite-incremental-fsync yes
----------------------------------------------------------------------
###lua脚本最长执行时间(毫秒)，达到最大允许时间后，脚本仍可执行，但会返回错误提示
###脚本运行超过设置时间时，如果脚本没有执行过写操作，通过script kill可终止运行；
###如果已执行写命令但不想等待脚本自然结束只能通过关闭redis服务器终止运行
###该值设置0或负数，则脚本可无时间限制执行，且没有警告提示
lua-time-limit 5000
----------------------------------------------------------------------
###普通redis实例不能作为集群的一部分，需要启用以下配置，redis实例才能作为集群节点
# cluster-enabled yes
###只需配置，由redis集群节点自己创建维护，最好对应各自实例的端口，各节点通过各自该文件获知集群中其他节点
# cluster-config-file nodes-6379.conf
###集群节点故障判定超时时间(默认15s)，任何节点在超过该时间后仍与集群中大部分主节点失联，则该节点停止接收任何请求
###若是主节点故障，则它的从节点将启动故障迁移升级成新的主节点，若不做时间限制，如机房中的网络抖动可能导致频繁的主从切换(数据的重新复制)
# cluster-node-timeout 15000
###cluster-node-timeout * cluster-slave-validity-factor（倍乘系数）放大超时时间，若该系数设为0，则从服务器不会做超时时间等待，会立刻尝试升级为主服务器
# cluster-slave-validity-factor 10
###如果某个主节点没有从节点，当它故障时(负责的槽丢失)，集群将完全处于不可用状态，但可以设置下面参数为no保证其它节点还可以继续对外提供访问
# cluster-require-full-coverage yes
----------------------------------------------------------------------
###slow log用来记录超过指定执行时间(不包括I/O计算如连接客户端，返回结果等，只是命令执行时间)的命令
###该参数代表超过多少微秒会被记录，负数代表关闭该功能不记录，0代表所有超时执行都记录
slowlog-log-slower-than 10000
###slow log大小，新命令被记录时会移除命令队列中最旧的命令，使用SLOWLOG RESET可以回收被slow log消耗的内存
slowlog-max-len 128
----------------------------------------------------------------------
###0代表关闭延迟监视器
latency-monitor-threshold 0
----------------------------------------------------------------------
###hash 的元素个数超过512个改用标准结构存储；否则使用ziplist（紧凑的字节数组结构）
hash-max-ziplist-entries 512(hash-max-zipmap-entries for Redis < 2.6)
###hash 的任意元素的key/value长度超过64改用标准结构存储；否则使用ziplist
hash-max-ziplist-value 64(hash-max-zipmap-value for Redis < 2.6)
###list 的元素个数超过512个改用标准结构存储；否则使用ziplist
list-max-ziplist-entries 512
###list 的任意元素的key/value长度超过64改用标准结构存储；否则使用ziplist
list-max-ziplist-value 64
###quicklist内部默认单个ziplist长度为8字节（-2），超出会新起一个ziplist
list-max-ziplist-size -2
###quicklist默认不压缩ziplist（0）；为了支持快速push/pop操作，quicklist的首尾两个ziplist不压缩（设置为1）；首尾第一、第二的ziplist都不压缩（设置2）；以此类推...
list-compress-depth 0
###zset 的元素个数超过128个改用标准结构存储；否则使用ziplist
zset-max-ziplist-entries 128
###zset 的任意元素的key/value长度超过64改用标准结构存储；否则使用ziplist
zset-max-ziplist-value 64
###set 的整数元素个数超过512改用标准结构存储
set-max-intset-entries 512
###普通客户端不需要输出缓冲区限制，因为普通客户端不主动请求不会接收到数据
client-output-buffer-limit normal 0 0 0
###类同下
client-output-buffer-limit slave 256mb 64mb 60
###客户端订阅了一个pub/sub，消费消息的速度赶不上发布者生成消息的速度，当客户端输出缓冲区达到32MB或持续60s达到8MB，客户端会立即断开连接
client-output-buffer-limit pubsub 32mb 8mb 60
###redis调用内部函数执行后台任务（如关闭超时客户端连接、清除过期keys等）
###hz值设置越大，占用CPU越多，执行任务越高效准确；默认10，只有在低延迟要求非常严格的环境才会增加到100
hz 10
###yes代表每100毫秒redis会使用1毫秒的CPU时间对hash表进行rehash，以尽可能快的释放内存
###（如果是非常严格的实时性场景，不能接受Redis对请求时不时有2毫秒延迟的话，改为no）
activerehashing yes
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
