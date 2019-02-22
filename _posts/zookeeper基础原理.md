---
title: zookeeper基础原理
date: 2017-04-14 22:43:01
tags:
- zookeeper
- API
categories: 
- zookeeper
---

记录zookeeper的基础概念以及内部机制

<!--more-->

## 什么是zookeeper

zookeeper是一个高可用的分布式管理与协调框架.

![png2](/img/zookeeper/20170414_2.png)

Zookeeper整体由Client和Server构成，一个Client连接一个Server，Server可以被多Client连接；它们之间通过定时发送心跳维持连接，一旦超时就断开释放连接，Client会去尝试连接其他Server.

Server端提供了一致性复制、存储服务；Client端提供一些具体的语义（如Cache事件监听、选举、分布式锁、分布式计数器、分布式Barrier等）.

## 存储服务

Although znodes have not been designed for general data storage, ZooKeeper does allow clients to store some information that can be used for meta-data or configuration in a distributed computation.

主要用于存储对一致性要求高的元数据（而非数据内容本身）以及配置信息，每个znode默认提供1M的存储空间，因此zookeeper一般作为小文件系统使用，不适合做分布式存储系统（可做但不适合）.

由于数据存储量相对不大，所以zookeeper的数据存储在内存中，极大地消除通信延迟；但是特殊情况：Server在Crash后重启，考虑到容错性，Server必须记住之前的数据状态，因此数据需要持久化，但吞吐量很高时，磁盘的IO成为系统瓶颈，其解决办法是使用缓存.

## 数据结构

zookeeper基于节点进行数据储存，每个节点在内存中都被构造成一个DataNode对象，称为znode.

DataNode是ZKDatabase存储的最小单元,包含该节点的父引用，数据的字节数组，访问控制列表，子节点信息，持久化到磁盘上的统计信息.

```bash
public class DataNode implements Record {
    /** the parent of this datanode */
    DataNode parent;

    /** the data for this datanode */
    byte data[];

    /**
     * the acl map long for this datanode. the datatree has the map
     */
    Long acl;

    /**
     * the stat for this node that is persisted to disk.
     */
    public StatPersisted stat;

    /**
     * the list of children for this node. note that the list of children string
     * does not contain the parent path -- just the last part of the path. This
     * should be synchronized on except deserializing (for speed up issues).
     */
    private Set<String> children = null;
}
```

znode节点会频繁的进行读写操作，为了提升数据的访问效率，ZooKeeper提供一个三层的数据缓冲层用于存放节点数据.

第一层（内存中）outstandingChanges位于zookeeperServer中，用于存放刚进行更改还未同步到ZKDatabase中的节点信息.

```bash
public class ZooKeeperServer implements SessionExpirer, ServerStats.Provider {
    final List<ChangeRecord> outstandingChanges = new ArrayList<ChangeRecord>();
    // this data structure must be accessed under the outstandingChanges lock
    final HashMap<String, ChangeRecord> outstandingChangesForPath =
        new HashMap<String, ChangeRecord>();

    /**
    * This structure is used to facilitate information sharing between PrepRP
    * and FinalRP.
    */
    static class ChangeRecord {
        ChangeRecord(long zxid, String path, StatPersisted stat, int childCount,
                List<ACL> acl) {
            this.zxid = zxid;
            this.path = path;
            this.stat = stat;
            this.childCount = childCount;
            this.acl = acl;
        }

        long zxid;

        String path;

        StatPersisted stat; /* Make sure to create a new object when changing */

        int childCount;

        List<ACL> acl; /* Make sure to create a new object when changing */

        @SuppressWarnings("unchecked")
        ChangeRecord duplicate(long zxid) {
            StatPersisted stat = new StatPersisted();
            if (this.stat != null) {
                DataTree.copyStatPersisted(this.stat, stat);
            }
            return new ChangeRecord(zxid, path, stat, childCount,
                    acl == null ? new ArrayList<ACL>() : new ArrayList(acl));
        }
    }
}
```

第二层（内存中）ZKDatabase中有一个DataTree对象，DataTree维护2个并行的数据结构ConcurrentHashMap，一个是哈希表（全路径到数据节点的映射），一个是由DataNode构成的Tree（在序列化到磁盘的时候才会遍历），所有的访问通过哈希表快速映射到数据节点.

```bash
public class DataTree {
    /**
     * This hashtable provides a fast lookup to the datanodes.
     */
    private final ConcurrentHashMap<String, DataNode> nodes =
        new ConcurrentHashMap<String, DataNode>();
}
```

server启动后ZKDataBase核心功能就是通过ZKDatabase.loadDatabase()将序列化在磁盘中存放的节点信息从snapshot和log文件中恢复到内存的datatree中.

```bash
public class ZKDatabase {
    protected DataTree dataTree;
    protected ConcurrentHashMap<Long, Integer> sessionsWithTimeouts;
    protected FileTxnSnapLog snapLog;
    protected LinkedList<Proposal> committedLog = new LinkedList<Proposal>();
    protected ReentrantReadWriteLock logLock = new ReentrantReadWriteLock();
    volatile private boolean initialized = false;

    public long loadDataBase() throws IOException {
        PlayBackListener listener=new PlayBackListener(){
            public void onTxnLoaded(TxnHeader hdr,Record txn){
                Request r = new Request(null, 0, hdr.getCxid(),hdr.getType(),
                        null, null);
                r.txn = txn;
                r.hdr = hdr;
                r.zxid = hdr.getZxid();
                addCommittedProposal(r);
            }
        };

        long zxid = snapLog.restore(dataTree,sessionsWithTimeouts,listener);
        initialized = true;
        return zxid;
    }
}
```

第三层（持久化）Disk file由两部分组成，FileSnap（Snapshot）用于存放基于某个时间点状态的zooKeeper节点信息快照；FileTxnLog（Transaction）用于存放数据对节点信息的具体更改操作.

```bash
/**
 * This is a helper class above the implementations 
 * of txnlog and snapshot classes.
 */
public class FileTxnSnapLog {
    //the direcotry containing the the transaction logs.
    File dataDir; 
    //the directory containing the the snapshot directory.
    File snapDir;
    TxnLog txnLog;
    SnapShot snapLog;
    
    /**
     * the constructor which takes the datadir and snapdir.
     * @param dataDir the trasaction directory
     * @param snapDir the snapshot directory
     */
    public FileTxnSnapLog(File dataDir, File snapDir) throws IOException {
        this.dataDir = new File(dataDir, version + VERSION);
        this.snapDir = new File(snapDir, version + VERSION);
        if (!this.dataDir.exists()) {
            if (!this.dataDir.mkdirs()) {
                throw new IOException("Unable to create data directory "
                        + this.dataDir);
            }
        }
        if (!this.snapDir.exists()) {
            if (!this.snapDir.mkdirs()) {
                throw new IOException("Unable to create snap directory "
                        + this.snapDir);
            }
        }
        txnLog = new FileTxnLog(this.dataDir);
        snapLog = new FileSnap(this.snapDir);
    }
}
```

zookeeper会定期将内存中的datatree进行Snapshot到磁盘上，对应某个时间点数据的完整状态；同时在执行Transaction时，zookeeper会先写WAL（Write-Ahead-Log），再更新内存中的数据.

主要目的：一是数据的持久化，二是加快重启之后的恢复速度，如果全部通过Replay ALL WAL的形式恢复的话，会很慢.

还原方案：当服务端异常退出或重启时，还原数据节点到指定状态有两种方案：1.再次执行每一条Transaction（Replay ALL WAL）；2.先将数据节点还原到一个正确的Snapshot，再执行从这个Snapshot之后的每一条Transaction（Snapshot1.0 + Transaction = Snapshot2.0）.

总结：第一种方案需要保存从首次启动开始的每一条指令，同时运行时间随指令条数线性增长，还原效率低；通常都采用第二种方案snapshot + transaction进行数据还原，类似HDFS中的fsimage + edits log.

## 事务处理方式

使用一个单一的主进程（全局唯一的服务器：Leader）来接收并处理客户端的所有事务请求，Leader负责将一个客户端事务请求转换成一个事务Proposal（提议），并采用Zab协议将该Proposal广播到集群中所有的Follower中（副本进程：Leader会为每一个Follower建立单独的队列），Follower会首先将Prpposal以事务日志的形式写入到本地磁盘中，写入成功后反馈给Leader一个Ack响应，Leader等待获得超过半数的Ack后，Leader再次向所有的Follower分发Commit消息，所有Follower将这一个proposal提交持久化，同时Leader自身也会完成对事务的提交.
 
这种事务处理方式与2PC（两阶段提交协议）区别在于：两阶段提交协议的第二阶段中，需要等到所有参与者的"YES"回复才会提交事务，只要有一个参与者反馈为"NO"或超时无反馈，都需要中断和回滚事务.

## 顺序一致性

从一个客户端发起的事务请求，最终都会按照严格的发起顺序被应用到zookeeper中，严格遵循FIFO顺序（先进先出原则）；考虑到Zookeeper主要操作数据的状态，为了保证状态的一致性，Zookeeper提出了两个安全属性.

全序：在一台服务器上消息A在消息B前发布，那么所有服务器上的消息A都将在消息B前被发布.

实现方案：通过使用TCP协议保证了消息的全序特性（先发先到）；ZooKeeper Client与Server之间的网络通信是基于TCP，TCP保证了Client/Server之间传输包的顺序.

因果顺序：在同一客户端消息A在消息B之前发布（A导致了B），并被一起发送，则A始终在B之前被串行执行（如：P的事务A创建节点/a，事务B创建节点/a/b，只有先创建了父节点/a，才能创建子节点/a/b）.

实现方案：ZooKeeper Server执行客户端请求也是严格按照FIFO顺序的；先到Leader的先执行.

## 什么是zxid

election epoch是分布式系统的重要概念，由于分布式系统无法使用精准的时钟来维护事件的先后顺序；分布式系统中以消息标记事件，因此Lampert提出的Logical Clock（为每个消息添加一个逻辑时间戳）就成为了界定事件顺序的最主要方式，在zookeeper中zxid就相当于Logical Clock.

在ZAB协议中，每一个Proposal都在被提出时赋予了一个全局唯一的zxid，消息的编号只能由Leader节点来分配，这样的好处可以通过zxid来准确判断分布式系统中任意事件发生的先后顺序.

64位的zxid由两部分组成：高32位是epoch（纪元编号：每经过一次Leader选举产生一个新的Leader，epoch+1），低32位是消息计数器（自增id：新Leader选举后置为0，从0开始，每接收到一条消息+1）.

epoch+1的目的是即使旧的Leader挂了后重启，它也不会被选举为Leader，因为旧Leader的zxid肯定小于当前新Leader的zxid.

总结：每次选出新Leader，zxid高32位递增，低32位清0.

## 什么是Zab

zookeeper内部基于Zab算法（zookeeper atomic broadcast），Zab不同于Paxos算法（通用的分布式一致性算法），Zab是特别为ZooKeeper设计的一套分布式环境中崩溃可恢复、数据事务一致性的原子消息广播算法.

Zab协议提供恢复模式（Leader选举）和广播模式（Server间数据同步：Leader负责写操作，然后通过Zab协议实现follower的同步，Leader和follower都可以处理读操作），服务启动、Leader崩溃或由于网络原因导致Leader服务器失去了与过半Follower的联系后，Zab就会进入了恢复模式，当Leader被选举出来，且大多数Server完成了和Leader的状态同步以后，恢复模式就结束了；状态同步保证了Leader和Follower具有相同的系统状态.

一般非大型项目3或5台足够使用，server越多，性能越差，因为zookeeper集群每次接收客户端请求都要Leader通过Zab协议分发到follower上，半数以上完成存储才会给客户端ack，那么当集群规模越大，会有越多的follower需要同步，存储的耗时也就越长.

## 选举策略

Leader选举保证当前主进程Leader出现异常情况Crash的时候，整个集群依旧能够正常工作.

每个Server在工作过程中有四种状态：
```bash
LOOKING：当前Server不知道Leader是谁，正在搜寻
LEADING：当前Server即为选举出来的Leader
FOLLOWING：Leader已经选举出来，当前Server与之同步
OBSERVING：不选举，只从Leader同步状态
```

选举过程：集群启动或宕机重启时由一个主线程将选举任务分发给各节点，在任务开始前，所有节点都处于LOOKING状态，都不知道谁是Leader，当选举算法开始执行后，最终在集群中拥有proposal最大值（即 zxid 最大）的一个唯一节点作为任务Leader（保证新选举Leader拥有集群中最高编号的事务Proposal，即zxid最大，就可以保证新选举Leader一定具有所有已经提交的提案，同时可以省去Leader服务器检查Proposal的提交和丢弃工作的这一步操作）.

zab协议需要设计的选举算法应该满足：确保提交已经被Leader提交的事务Proposal，同时丢弃已经被跳过的事务Proposal.

Zab协议需要保证同一个Leader的发起的事务要按顺序被apply，同时还要保证只有先前的Leader的所有事务都被apply之后，新选的Leader才能在发起事务.

> 保证已经被处理的消息不会丢

Zab协议需要确保那些已经在Leader服务器上提交的事务最终被所有服务器都提交.

场景：假设一个事务在Leader服务器上被提交了，并且已经得到过半Follower服务器的Ack，但在Leader将COMMIT消息发送给所有Follower之前，Leader挂了，针对这种情况，ZAB协议就需要确保该事务最终能够在所有的服务器上都被提交成功，否则将出现不一致.

由于所有proposal被COMMIT之前必须有过半的Follower ACK，即大多数Server已将该proposal写入日志文件，又由于新选举的Leader是这大多数节点中zxid最大的，那么它必然存有所有被COMMIT消息的proposal；然后，新Leader与Follower建立FIFO的队列，Leader将自身有而Follower缺失的proposal发送给Follower，再将对应proposal的COMMIT命令发送给Follower，保证所有Follower与新Leader同步，已经被处理的消息不会丢.

> 被丢弃的消息不能再次出现

Zab协议需要确保丢弃那些只在Leader服务器上被提出的事务

场景：假设初始的Leader服务器在提出了一个事务之后就崩溃退出了，导致集群中的其他服务器都没有收到这个事务，当该服务器恢复过来再次加入到集群中的时候 ，ZAB协议需要确保丢弃这个事务.

当Leader接收到消息请求生成proposal后就挂了，其他Follower并没有收到此proposal，因此新选出的Leader中必然不含这条消息，那么当之前挂了的Leader重启并注册成了Follower，它要与新Leader保持一致，就必须清除自身旧的proposal（旧Leader作为Follower提供服务，新Leader会让它将所有多余未被COMMIT的proposal清除）.

## 什么是ACL

ACL（Access Control List）访问控制列表，ZK的节点有5种操作权限：CREATE、READ、WRITE、DELETE、ADMIN 也就是 增、删、改、查、管理权限（delete是指对子节点的删除权限，其它4种权限指对自身节点的操作权限）.

身份的认证有4种方式：
```bash
world：默认方式，相当于全世界都能访问
auth：代表已经认证通过的用户(cli中可以通过addauth digest user:pwd 来添加当前上下文中的授权用户)
digest：即用户名:密码这种方式认证，这也是业务系统中最常用的
ip：使用Ip地址认证
```

设置访问控制：
```bash
方式一：（推荐）
1）增加一个认证用户
addauth digest 用户名:密码明文
如：addauth digest stefan:12345678
2）设置权限
setAcl /path auth:用户名:密码明文:权限
如：setAcl /test auth:user1:password1:cdrwa
3）查看Acl设置
getAcl /path

方式二：
setAcl /path digest:用户名:密码密文:权限
（这里的加密规则是SHA1加密，然后base64编码）
```





