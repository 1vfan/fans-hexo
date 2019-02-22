# 简介

Hadoop是由Lucene的鼻祖Doug Cutting主导开发的，参考了Google的三篇论文：GFS、Map-Reduce、Bigtable，而后被纳入Apache基金会成为顶级项目 ``hadoop.apache.org``.

hadoop框架分为以下四部分：

* hadoop Common 支持其他模块的公共部分
* HDFS 分布式文件系统（对分布式计算起到很好的支撑作用）
* YARN 分布式资源管理平台（作业调度、集群资源管理）
* MapReduce 分布式计算框架（并行计算、计算向数据移动）


# Hadoop-HDFS

## 存储模型

> 文件线性切割成Block块，每一个Block块都会有一个偏移量offset.

文件在计算机底层是使用0、1二进制位存储的，但是访问文件的最小单位是字节Byte，所以文件可以当成是一个字节数组，当我们把文件线性切割成固定大小的Block块，每个Block块的第一个字节在整个文件字节数组的下标，就是该Block块的偏移量offset（如一个文件Block大小为4个字节，那么Block的偏移量依次为0 4 8 ..），散落在各节点上的Block块可以通过offset知道该Block在原文件中的位置.

> Block与副本位置

Block块分散存储在集群的各个节点上，在同一节点上也是可以的；但是Block块的副本必须存储在不同的节点上，且副本数不超过节点数.

> Block与副本大小

文件上传时可以设置Block块大小和副本数；同一个文件中的Block大小一致，不同文件可不同独立设置；已上传的文件Block块大小不可改变，副本数可以调整.

> 一次写入多次读取

HDFS只支持一次写入多次读取，同一时刻只有一个写入者，也就是不支持修改，但可以append追加数据.

为什么文件系统不支持修改但可以追加数据，这也就是HDFS产生的原因：当对某一个Block块中的数据做修改操作，必然会导致该Block块大小与其他不一致，引发的蝴蝶效应就是之后的所有Block块的偏移量全部失效；但如果将已修改的及之后的Block块们重新切割划分，势必会造成分布在不同节点上的Block块之间进行或大或小的网络数据传输，如果一个文件同时被多人修改，集群中所有的资源都会被网络传输消耗殆尽，不进行修改操作就可以节省硬件资源留给上层的计算使用；而append只会在文件的末尾追加数据，对文件中的其他Block块的偏移量没有影响.


## 架构模型
 
一个HDFS集群中包含唯一的一个NameNode主节点、多个DataNode从节点、HdfsClient客户端.

NameNode就是一个JVM进程，在这个进程的内存中会维护一个虚拟的目录树，用于保存文件的元数据，记录Block块保存在DataNode中的位置、Block偏移量等；而DataNode节点保存文件Block块数据本身.

DataNode与NameNode之间会保持心跳，也就是DataNode会周期性的向NameNode发送数据包，可以通过该网络行为判断节点健康状况，同时NameNode中存储的部分元数据（Block存储位置等）也是DataNode通过心跳传输提交的.

HdfsClient与NameNode交互元数据信息，HdfsClient与DataNode交互文件Block数据.

HdfsClient存取文件的流程大致如下：hdfsClient存文件时先与NameNode交互，获知Block块可以存放到哪些对应的DataNode上，此时NameNode并没有记录文件存储最终的元数据，而是记录临时的日志，然后HdfsClient会与DataNode交互，将Block块存储到对应的DataNode，最后DataNode在与NameNode发送心跳数据包时会将位置信息提交给NameNode，此时NameNode上才会真正在内存目录树中记录元数据，所有Block块全都存储完成后该文件才在HDFS集群中可用；读取的时候同样HdfsClient先与NameNode交互获取文件元数据信息，然后去对应的DataNode中读取.

Block在原文件中的偏移量offset 和 Block在DataNode中的位置信息location 支撑起了上层计算向数据移动的理念，实现数据本地化处理.

### NameNode

NameNode是基于内存存储元数据信息的，不会和磁盘发生交换，所以整个集群存储文件的数量取决于NameNode的内存大小.

NameNode主要接受客户端的读写服务，接收DataNode汇报的Block列表信息.

NameNode保存的元数据metadata包括：文件大小和时间、owership和permissions、offset和location、Block块及副本位置信息（由DataNode上报）.

在元数据持久化的过程中会保存有哪些Block块以及Bolck块在原文件的偏移量等信息，但不会保存Block块以及副本在节点的位置信息，原因：当NameNode重启加载持久化数据时，如果之前持久化了Block所在节点位置信息，且对应的节点没有启动则无法提供服务，所以避免这种情况发生，不会对位置信息持久化，而是节点启动后通过心跳数据包将位置信息同步给NameNode，以保证真实服务的数据一致性（就是说真正能提供服务的Block数据块与NameNode中元数据记录一致）.

### DataNode

DataNode则是基于本地硬盘目录以文件形式存储Block数据，同时会存储Block自身的元数据信息文件（这里的元数据文件并不是NameNode中的元数据，而是存Block的数据校验和，当HdfsClient将Block数据存储到DataNode后，DataNode会计算该Block块的校验和并存储在文件中，当以后客户端拉取Block时会先计算其检验和与文件中的值比对，确认数据文件在磁盘中没有损坏，若已损坏则通过NameNode拉取别的DataNode中对应的未损坏的副本）.

当DataNode启动后会向NameNode汇报Block信息，DataNode会向NameNode发送心跳以保持联系（3秒1次），如果NameNode超过10分钟没有收到DataNode的心跳，则认为该DataNode挂了，会将该DataNode上的Block复制到其他DataNode上以保证副本数（为什么要等待10分钟？结合服务器的成本与集群数据冗余的特性考虑，因为挂了的DataNode中的数据在集群其他节点上都存在副本，所以短时间不会影响集群提供服务，如果10分钟内运维人员修复并启动完成，集群就可以正常工作，同时可以避免副本数据拷贝到其他节点）.

### HDFS优点

* 高容错性和恢复机制：数据自动保存多个副本，且副本丢失后自动恢复.
* 适合批处理：移动计算而非数据，数据位置会暴露给计算框架实现本地化处理.
* 适合大数据处理：TB PB级数据，百万规模的文件，5K+节点.
* 节省成本：可以构建在廉价的机器上.

### HDFS缺点

不能说是真正意义上的缺点，因为HDFS本身就不是为了以下应用场景而设计的.

* 无法满足低延迟数据访问.
* 不适用于小文件的存取，会占用NameNode大量内存，寻道时间也会超过读取的时间.
* 不支持并发写入与文件随机修改，会占用大部分资源用于IO网络传输.


## NameNode持久化方案

内存储存的系统持久化方案一般分两种：镜像快照或日志文件，而NameNode持久化的策略是两者的综合fsimage + edits log.

快照的优点：

* 适用于备份，可随时将数据还原到不同版本.
* 只有一个文件，内容紧凑，传输方便.
* 恢复大数据集时速度相对较快.

快照的缺点：

* 可能丢失故障前最后一次保存快照和发生故障中间的数据.
* 当数据集很庞大时，保存快照会很耗时.

日志的优点：

* 每次写入时追加日志或每秒一次，所以一般不会丢失数据或最多丢失一秒，且每次追加的.
* 当日志文件体积过大时，会进行重写，重写后的日志文件包含了恢复当前数据的最小命令集合.

日志的缺点：

* 相同的数据集，日志文件的体积会大于快照.
* 恢复速度比快照慢.

中和两种方式的优缺点，HDFS采用定期合并快照与日志的策略.

### SecondaryNameNode

SecondaryNameNode并不是NameNode的备份.

> 主要职责

1. 定期合并fsimage与edits文件并推送给NameNode防止edits文件过大
2. 存储最新的检查点以辅助恢复NameNode

这两个过程同时进行，统称为：检查点checkpoint.

> 存在原因

NameNode会将修改文件系统的操作日志追加到本地edits中，当NameNode启动时，先从fsimage里读取HDFS状态，然后读取应用edits，将新的HDFS状态写入fsimage并创建新的空edits文件开始正常操作.

由于NameNode仅在启动期间合并fsimage和edits，edits一般在繁忙的群集中会越变越大，所以体积大的edits会导致下次重启NameNode时花费大量时间.

> SNN进程

SNN进程并不是一直处于开启状态的，SNN进程启动是由以下两个配置参数控制的，只有满足了这两个条件之一才会启动，但SNN的守护进程是一直开启的.

```bash
### 指定两个连续检查点之间的最大延迟时间，默认1小时
dfs.namenode.checkpoint.period = 3600

### NameNode上未检查的事务数量达到设置值，强制开启SNN进程开始检查，默认一百万
dfs.namenode.checkpoint.txns = 1000000

### 限制edits的大小，默认64M
```

SNN进程通常与NameNode进程在不同的机器上，因为它需要占用大量的CPU时间与namenode相同容量的内存才可以进行合并操作；SNN会保存最新的检查点（合并后的fsimage副本）存储在与NameNode的目录结构相同的目录中，便于NameNode在故障时可以读取.

> 辅助NameNode恢复元数据

NameNode进程挂了，且存放NameNode元数据信息目录下的数据丢失了，如下操作恢复:

```bash
删除SNN存放数据目录下in_use.lock文件 
hadoop namenode -importCheckpoint   ##执行恢复命令
hadoop-daemon.sh start namenode     ##启动namenode 
hadoop fsck /        ##进行校验检查根目录是否健康
hadoop fs -lsr /     ##查看数据 
```

至此NameNode元数据恢复成功.

> SecondaryNameNode工作流程

0. NameNode第一次产生空的fsimage和edits文件是在格式化HDFS集群时，当达到检查点触发条件，SNN进程开启.
1. SNN通知NameNode准备提交edits文件，此时主节点会将新的写操作数据记录到一个新的文件edits.new中
2. SNN通过HTTP GET方式获取NameNode的fsimage（第一次需要拉取之后SNN上会存储最新的fsimage就不需要拉取了）与edits文件（在SNN的current同级目录下可见到 temp.check-point或者previous-checkpoint目录，这些目录中存储着从NameNode拷贝来的镜像文件）
3. SNN开始合并获取的上述两个文件，产生一个新的fsimage文件fsimage.ckpt 
4. SNN用HTTP POST方式发送fsimage.ckpt至NameNode
5. NameNode将fsimage.ckpt与edits.new文件分别重命名为fsimage与edits，然后更新fstime，整个checkpoint过程到此结束 

### CheckPointNode

在Hadoop2.x之后新增的节点角色CheckPointNode可以替换掉SNN节点，但作用配置都与SNN一致，可以在集群配置文件中指定多个CheckPointNode.

启动方式：hdfs namenode -checkpoint

### BackupNode

BackupNode同样是Hadoop2.x引入的节点角色，它作为NameNode的完全备份.

备份节点不仅提供与检查点节点相同的checkpoint功能，同时在内存中始终维护与inactive NameNode状态同步的命名空间的最新副本.

* checkpoint: 备份节点不需要从inactive NameNode下载fsimage和edits文件来创建检查点，因为备份节点的内存中已经具有命名空间的最新状态，而且备份节点的检查点进程更高效，因为它只需要将命名空间保存到本地fsimage文件中并重置edits.

* backup: 备份节点除了接受来自NameNode的文件系统edits的日志流并将其持久化到磁盘外，还将这些edits应用到自己内存中命名空间的副本里，实现命名空间的备份.

启动方式：hdfs namenode -backup

因为在内存中维护命名空间的副本，所以备份节点与NameNode在相同内存的不同机器上；NameNode一次支持一个备份节点（未来支持同时使用多个备份节点），如果正在使用备份节点，则无法注册检查点节点.

检查点（或备份）节点及其随附Web界面的位置是通过dfs.namenode.backup.address和dfs.namenode.backup.http-address配置变量配置的.

## HDFS读写流程

### 写流程

1. 首先客户端与NameNode建立通信，在NameNode上预先建立一个临时元数据文件，同时NameNode根据副本放置策略向客户端返回一个sorted按就近原则排好序的清单

2. 根据返回的DataNode清单，客户端与这些DataNode通过socket连接组成一组Pipeline，同时客户端会将默认128M的block切割成一堆64kb的packet包依次传输

3. DataNode在数据传输完成后会通过心跳机制向NameNode汇报元数据信息，最终在NameNode中形成该文件的一个完整的元数据文件


### 读流程

由于HDFS分布式文件系统是只读的（一次写入多次读取），所以读相较于写更频繁，但读流程相对简单：

1. 客户端想从集群内下载回一个文件到本地，首先客户端需要与NameNode建立通信，因为NameNode中存储着该文件的元数据（各个块及副本的位置信息），客户端获取到元数据信息，根据距离优先原则依次选择每个block块距离客户端最近的一个副本下载回客户端

2. 将该文件所有block块依次下载回本地后，会进行一次校验，将每个块计算得到的校验和与写数据时存储在NameNode元数据中的校验和进行比较，校验无误后将所有块按顺序拼接成所需文件

注意：读流程可以读取返回整个文件，也可以读取返回文件的一部分块，这是HDFS为了更好的支撑计算层，因为计算要向数据移动，当同一个计算程序发送到不同的节点上去并行计算不同块的数据时，就需要HDFS具有读取文件其中一部分块的能力.


