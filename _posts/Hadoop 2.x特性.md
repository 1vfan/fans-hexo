# 2.x诞生背景

由于Hadoop 1.x中HDFS、MapReduce在高可用、扩展性等方面存在问题.

在Hadoop 1.x中存在SecondaryNameNode角色，但它并不是NameNode的备份，而是一个助理，协助完成fsimage和EditLog文件的合并并推送给NameNode，防止EditLog文件过大导致NameNode重启过慢.

## HDFS的问题

1. NameNode单点故障，不具备高可用性

2. NameNode压力过大，且内存受限，影响系统扩展性

## MapReduce的问题

1. JobTracker访问压力大，影响系统扩展性

2. 难以支持MapReduce以外的计算框架，如Spark、Strom


# HDFS 2.x

虽然高可用和联邦的优化方案都是通过增加NameNode数量的机制，但是本质上存在区别.

## NameNode高可用

在Hadoop 1.x中NameNode有且只能有一台，NameNode挂了整个集群就挂了；Hadoop 2.x为了解决这个问题匆忙上线，实现了一主一备模型的两台NameNode，备用状态的NameNode无法对外提供服务，当主NameNode挂了会自动切换到备用NameNode上；而在Hadoop 3.x的时候实现了一主多备的模型，理论可以达到5~7台，推荐一主三备.

新配置的设计使得集群中的所有节点可以具有相同的配置，而无需根据节点的类型将不同的配置文件部署到不同的机器上.


### 元数据同步

主备NN这两个角色是两个独立的jvm进程存在在两个异地的不同操作系统中，当Active NN挂了，能立刻切换到Standby NN对外提供元数据服务，而保证快速切换的前提是备机内存中存储的元数据尽量与主机内存存储的元数据同步.

> 元数据来源

刚搭建完的HDFS集群，NN中只有一个空的根目录，没有元数据文件；NN的元数据来源于两部分：客户端交互操作写入、DN心跳汇报；每个DN都配置了两个NN的位置，可以通过心跳汇报同时向两者发送块位置信息，所以这部分元数据很容易实现同步；但客户端只能和Active NN通信，因此Standby NN上就会缺失客户端交互产生的元数据，所有关键在于同步这部分的数据.

> 同步方式

同步阻塞方式：客户端操作元数据传给Active NN完成后，由Active NN传给Standby NN，Active NN要等Standby NN返回响应后才向客户端返回响应，保证元数据的强一致性；但是同步阻塞的问题在于，当回传响应时NN之间网络延迟或者中断超时会导致NN不可用，为了实现NN高可用反而增加了不可用的风险，所以不能用同步阻塞方式.

异步非阻塞方式：客户端操作元数据传给Active NN完成后，由Active NN传给Standby NN，但是Active NN不再等Standby NN返回响应，而是直接向客户端返回响应；异步出现的问题是一旦Standby NN没有成功保存数据，NN之间就会出现数据不一致，当然也可以通过之后Standby NN周期性询问与Active NN不一致的数据进行同步，但是在同步之前Active NN就挂了的话就失去了参照同样会丢失数据，所以异步只能保证数据的弱一致性.

> NFS

NFS（Network File System 网络文件系统）作为官方支持的一种在HA两台NN之间传递EditLog日志元数据的方式，在集群外找一台服务器NFS，将主备NN存储EditLog日志的目录都挂载到NFS这台服务器，客户端操作指令会追加到Active NN的EditLog文件，实质是保存到了NFS中，同时异步的方式将数据传递到Standby NN中，只要客户端的操作日志成功写入到了Active NN，即使它挂了Standby NN没有及时同步数据，之后Standby NN也可以从NFS的路径中获取EditLog写入同步到Active NN挂之前的元数据状态，保证了数据的最终一致性.

优点：省去了数据传输的过程；又保证了数据的一致；同时日志数据出主机相当于异地的备份不会随着NN的宕机而丢失.

缺点：NFS作为集群外的一项Linux技术，配置难度高属于第三方技术成本；且存在单点故障.

> QJM

Quorum Journal Manager

HA中两台独立的NN节点之间为了保持状态同步，他们都与一组称为JournalNodes的单独守护进程JN通信，
当Active节点执行任何客户端操作使得命名空间改变时，它会将修改记录持久化到大多数JN中，Standby节点会监控JN中编辑日志的更改，并将它们应用到自己的命名空间，确保发生故障切换前达到命名空间完全同步状态.

JN守护进程相对轻量级，可以和其他守护进程并存；

Standby NN也会执行命名空间状态的检查点checkpoint操作，所以不用在HA集群中运行Secondary NameNode、CheckpointNode、BackupNode角色，如果配置会报错.

> 同步过程：

Active NN通过RPC异步方式将EditLog日志写入所有JN，每条EditLog日志都有一个编号txid，NN写日志要保证txid是连续的，JN在接收写日志时，会检查txid是否与上次连续，否则写失败，
每条日志只要半数以上JN返回成功，即认定写成功，写失败的JN下次不再写，直到调用滚动日志操作，若此时JN恢复正常，则继续向其写日志.
Standby定期从JN读取一批EditLog，并应用到内存中的FsImage中。

每次 NameNode 写 EditLog 的时候，除了向本地磁盘写入 EditLog 之外，也会并行地向 JournalNode 集群之中的每一个 JournalNode 发送写请求，
只要大多数 (majority) 的 JournalNode 节点返回成功就认为向 JournalNode 集群写入 EditLog 成功。
如果有 2N+1 台 JournalNode，那么根据大多数的原则，最多可以容忍有 N 台 JournalNode 节点挂掉。

如何避免“Split Brain”(脑裂)问题？

Split Brain 是指在同一时刻有两个认为自己处于 Active 状态的 NameNode。

when a NameNode sends any message (or remote procedure call) to a JournalNode, it includes its epoch number as part of the request. 
Whenever the JournalNode receives such a message, it compares the epoch number against a locally stored value called the promised epoch. 
If the request is coming from a newer epoch, then it records that new epoch as its promised epoch.
 If instead the request is coming from an older epoch, then it rejects the request. This simple policy avoids split-brain
简单地理解如下：每个NameNode 与 JournalNodes通信时，需要带一个 epoch numbers(epoch numbers 是唯一的且只增不减)。
而每个JournalNode 都有一个本地的promised epoch。
拥有值大的epoch numbers 的NameNode会使得JournalNode提升自己的 promised epoch，从而占大多数，而epoch numbers较小的那个NameNode就成了少数派(Paxos协议思想)。

从而epoch number值大的NameNode才是真正的Active NameNode，拥有写JournalNode的权限。注意：（任何时刻只允许一个NameNode拥有写JournalNode权限）

when using the Quorum Journal Manager, only one NameNode will ever be allowed to write to the JournalNodes,
so there is no potential for corrupting the file system metadata from a split-brain scenario.

> 安全规则

为了防止数据丢失、脑裂等问题，JN只允许一台NN向其写入，在故障切换期间，将要变成Active的NN会简单的接管写入JN的角色.

fencing规则: Active NN每次写EditLog日志都需要传递一个编号Epoch给JN，JN会与自己保存的Epoch对比，若新传入的较大或相同，则可以写入日志，JN更新自己的Epoch到最新，
否则拒绝写入操作。在切换时，Standby转换为Active时，会把Epoch+1，这样就防止即使之前的NameNode向JN写日志，也会失败。


(6) 切换时日志恢复机制

  (a) 主从切换时触发

  (b) 准备恢复（prepareRecovery），standby向JN发送RPC请求，获取txid信息，并对选出最好的JN。

  (c) 接受恢复（acceptRecovery），standby向JN发送RPC，JN之间同步Editlog日志。

  (d) Finalized日志。即关闭当前editlog输出流时或滚动日志时的操作。

  (e) Standby同步editlog到最新

(7) 如何选取最好的JN

  (a) 有Finalized的不用in-progress

  (b) 多个Finalized的需要判断txid是否相等

  (c) 没有Finalized的首先看谁的epoch更大

  (d) Epoch一样则选txid大的。





```bash
data/hbase/runtime/namespace
├── current
│ ├── VERSION
│ ├── EditLog_0000000003619794209-0000000003619813881
│ ├── EditLog_0000000003619813882-0000000003619831665
│ ├── EditLog_0000000003619831666-0000000003619852153
│ ├── EditLog_0000000003619852154-0000000003619871027
│ ├── EditLog_0000000003619871028-0000000003619880765
│ ├── EditLog_0000000003619880766-0000000003620060869
│ ├── EditLog_inprogress_0000000003620060870
│ ├── fsimage_0000000003618370058
│ ├── fsimage_0000000003618370058.md5
│ ├── fsimage_0000000003620060869
│ ├── fsimage_0000000003620060869.md5
│ └── seen_txid
└── in_use.lock

```




















































```bash
Journalnode超时

java.io.IOException: Timed out waiting 20000ms for a quorum of nodes to respond.

其实在实际的生产环境中，也很容易发生类似的这种超时情况，所以我们需要把默认的20s超时改成更大的值，比如60s.

我们可以在hadoop/etc/hadoop下的hdfs-site.xml中，加入一组配置:

<property>
        <name>dfs.qjournal.write-txns.timeout.ms</name>
        <value>60000</value>
</property>

在hadoop的官网中的关于hdfs-site.xml介绍中，居然找不到关于这个配置的说明
http://hadoop.apache.org/docs/r2.7.2/hadoop-project-dist/hadoop-hdfs/hdfs-default.xml

最后重启整个集群，这样配置才能生效；Flume的话也要重启Flume集群.
```









































优点：作为HDFS集群的一部分，只需简单配置即可启动；集群方式工作保证数据可靠性.

### 自动化切换

引入上一部分的ZK是提供主备NN的全自动化切换，使用机器代替人工


## NameNode联邦


## 总结

解决HDFS 1.0中单点故障和内存受限的问题：通过主备NameNode实现HDFS HA，主NameNode挂了则切换到备用NameNode上；通过水平扩展支持多个NameNode实现HDFS联邦解决内存受限的问题，所有NameNode共享所有DataNode存储资源，每个NameNode分管一部分目录.

相较于HDFS 1.x只是架构变化，使用方式不变，HDFS的变化对于用户是透明的，1.x的命令和APi仍可以使用.

# MapReduce 2.x













