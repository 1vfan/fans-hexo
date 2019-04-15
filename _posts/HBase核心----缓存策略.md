## HBase缓存

作为数据库系统，HBase提供缓存策略以减少IO，进而提升读写性能；不能也不需要缓存全部海量数据，允许缓存部分热点数据以减少大部分IO操作。


HBase提供了两种数据缓存结构，``MemStore``和``BlockCache``。


## MemStore

每个Store由1个MemStore和n个StoreFile组成，HBase的所有写操作都是先将数据写入缓存MemStore，同时顺序写入日志HLog，当触发MemStore刷盘时，先对MemStore中的数据排序（有利于检索）然后批量刷入磁盘HFile；同时读取新写入的数据时，先从MemStore中查找，没有再去BlockCache中查找，都没有最后再去HFile中查找。

### 触发flush

MemStore flush和Compaction操作都是以Region作为最小单元，一张表设计的CF越多，对应Region中的Store(MemStore)也越多，每次flush操作的开销就越大，所以尽可能缩减CF数量。

- MemStore：Region中任意一个MemStore大小达到``hbase.hregion.memstore.flush.size``（默认128M，有特定的线程定期检查），会触发该Region中所有MemStore的flush操作；

- Region：当Region中MemStore大小总和大于``hbase.hregion.memstore.flush.size`` * ``hbase.hregion.memstore.block.multiplier``(乘积因子)，则当前Region会进行一次Flush，期间阻塞更新，直到Flush结束；

- RegionServer：当RegionServer中MemStore的总和达到``JVM Heap`` * ``hbase.regionserver.global.memstore.upperLimit``（默认0.4，JVM Heap的40%），按MemStore大小由大到小顺序Flush Region，期间整个RegionServer的更新都被阻塞，直到降至``hbase.regionserver.global.memstore.lowerLimit``(默认0.38)；

- HLog：当RegionServer中WAL数量达到``hbase.regionserver.max.logs``，按时间降序Flush MemStore以减少WAL日志数（保证宕机恢复时时间可控），从具有最早MemStore的Region开始Flush，直到降至``hbase.regionserver.max.logs``以下；

- 自动定期Flush：HBase会定期Flush MemStore防止长时间未持久化（默认1小时），使用随机延时避免所有MemStore同时Flush；

- 手动执行Flush：通过Shell命令，flush 'tablename' 或 flush 'regionname'。 

Region级别的Flush大部分对读写影响不大，阻塞对应的Region只是毫秒级别，以上唯一例外是RegionServer整体Flush，会阻塞分配到该RegionServer上的所有更新操作，阻塞时间可能达分钟级别，虽然很少出现但还是必要的优化一下；

RegionServer是否超过Flush阈值取决于``单个MemStore阈值、单个RegionServer容纳Region数、表的列族数``，所以CF越少越好，Region一般线上控制在50-80。

### flush流程

```java

```



## BlockCache

HBase会将磁盘HFile中查询到的Block块保存在读缓存BlockCache中，便于下次查询该Block块数据时，直接从内存中获取，提高读性能。

BlockCache是Region Server级别的，一个Region Server只有一个Block Cache，在Region Server启动的时候完成Block Cache的初始化工作。


### BlockCache缓存机制

HBase先后实现了3种BlockCache的缓存机制: ``LRUBlockCache``（默认）、``SlabCache``（0.92-0.98不建议使用）、``BucketCache``（0.96）；

默认的LRUBlockCache将数据全部存放在JVM堆中进行管理，但JVM的full GC常导致程序长时间暂停；便诞生了后面两种方案，将部分数据存放在堆外内存中，交由HBase自身进行管理。

实际应用中一般使用策略为: ``LRUBlockCache``（默认）、``DoubleBlockCache = LRUBlockCache + SlabCache``（1.0废弃）、``CombinedBlockCache = LRUBlockCache + BucketCache``。


#### LRUBlockCache

默认``LRUBlockCache``将整块BlockCache内存按``1:2:1``划分成``single-access、mutil-access、in-memory``三部分，整块BlockCache内存数据都严格遵从LRU算法，当容量达到阈值后最近最少被使用的Block会被淘汰；

在一次随机读中，从HDFS加载Block数据存放入``single-access``，当该Block块被请求访问频率提升后，会被转移到``mutil-access``；而``in-memory``中数据常驻内存，主要存储请求频繁且数据量小的数据（如meta表数据、元数据），可以对业务表的某个CF进行``IN-MEMORY=true``修饰，使该CF麾下数据常驻内存（但慎用，确保不会压榨hbase:meta数据缓存空间）。

淘汰的Block由CMS收集器回收，但是CMS的弊端就是会产生大量内存碎片，触发Full GC，Full GC过程会暂停整个应用进程，在大内存时暂停时间可能持续分钟级，严重影响业务的正常读写。

```java
package org.apache.hadoop.hbase.io.hfile;

public class LruBlockCache implements BlockCache, HeapSize {

  private final Map<BlockCacheKey,LruCachedBlock> map;

  // ConcurrentHashMap
  public LruBlockCache(...) {
    ...
    map = new ConcurrentHashMap<BlockCacheKey,LruCachedBlock>(mapInitialSize,
        mapLoadFactor, mapConcurrencyLevel);
  }

  // BlockCache implementation
  @Override
  public void cacheBlock(BlockCacheKey cacheKey, Cacheable buf, boolean inMemory) {
    LruCachedBlock cb = map.get(cacheKey);
    ...
    cb = new LruCachedBlock(cacheKey, buf, count.incrementAndGet(), inMemory);
    long newSize = updateSizeMetrics(cb, false);
    // ConcurrentHashMap<BlockCacheKey,LruCachedBlock>
    map.put(cacheKey, cb);
    long val = elements.incrementAndGet();
    if (newSize > acceptableSize() && !evictionInProgress) {
      // 超过阈值，触发evict
      runEviction();
    }
  }

  private void runEviction() {
    if(evictionThread == null) {
      evict();
    } else {
      evictionThread.evict();
    }
  }

  // LRU实现
  void evict() {
    if(!evictionLock.tryLock()) return;
    try {
      evictionInProgress = true;
      long currentSize = this.size.get();
      long bytesToFree = currentSize - minSize();
      if(bytesToFree <= 0) return;

      //Instantiate priority buckets
      BlockBucket bucketSingle = new BlockBucket("single", bytesToFree, blockSize, singleSize());
      BlockBucket bucketMulti = new BlockBucket("multi", bytesToFree, blockSize, multiSize());
      BlockBucket bucketMemory = new BlockBucket("memory", bytesToFree, blockSize, memorySize());

      for(LruCachedBlock cachedBlock : map.values()) {
        switch(cachedBlock.getPriority()) {
          case SINGLE: {
            bucketSingle.add(cachedBlock);
            break;
          }
          case MULTI: {
            bucketMulti.add(cachedBlock);
            break;
          }
          case MEMORY: {
            bucketMemory.add(cachedBlock);
            break;
          }
        }
      }

      long bytesFreed = 0;
      if (forceInMemory || memoryFactor > 0.999f) {
        long s = bucketSingle.totalSize();
        long m = bucketMulti.totalSize();
        if (bytesToFree > (s + m)) {
          // make single and multi buckets empty
          bytesFreed = bucketSingle.free(s);
          bytesFreed += bucketMulti.free(m);
          // evict memory bucket
          bytesFreed += bucketMemory.free(bytesToFree - bytesFreed);
        } else {
          // no need to evict memory bucket, make single:multi = 1:2
          long bytesRemain = s + m - bytesToFree;
          if (3 * s <= bytesRemain) {
            bytesFreed = bucketMulti.free(bytesToFree);
          } else if (3 * m <= 2 * bytesRemain) {
            bytesFreed = bucketSingle.free(bytesToFree);
          } else {
            bytesFreed = bucketSingle.free(s - bytesRemain / 3);
            if (bytesFreed < bytesToFree) {
              bytesFreed += bucketMulti.free(bytesToFree - bytesFreed);
            }
          }
        }
      } else {
        PriorityQueue<BlockBucket> bucketQueue = new PriorityQueue<BlockBucket>(3);
        bucketQueue.add(bucketSingle);
        bucketQueue.add(bucketMulti);
        bucketQueue.add(bucketMemory);

        int remainingBuckets = 3;
        BlockBucket bucket;
        while((bucket = bucketQueue.poll()) != null) {
          long overflow = bucket.overflow();
          if(overflow > 0) {
            long bucketBytesToFree = Math.min(overflow,
                (bytesToFree - bytesFreed) / remainingBuckets);
            bytesFreed += bucket.free(bucketBytesToFree);
          }
          remainingBuckets--;
        }
      }
    } finally {
      stats.evict();
      evictionInProgress = false;
      evictionLock.unlock();
    }
  }
}
```

#### SlabCache/DoubleBlockCache

``SlabCache``方案采用``Java NIO DirectByteBuffer``技术实现了堆外内存存储，不再靠JVM管理；但是在实际应用中的``DoubleBlockCache``，既没有完全解决GC问题，同时还引入堆外内存使用率低的问题，所以在0.98后不推荐使用SlabCache，1.0后废弃了DoubleBlockCache。

#### BucketCache

``BucketCache``同样使用LRU算法，在SlabCache堆外内存存储实现的基础上做了优化，不再像SlabCache中只有2种固定大小的存储块，而是在初始化时会申请14种大小不同的存储块Bucket（``BucketSizeInfo.DEFAULT_BUCKET_SIZES[]``），且Bucket间可以互相借调内存，完美的解决了堆外内存使用率低的问题。

``BucketCache``提供的``heap、offheap、file``三种模式的内存模型以及缓存流程都是相同的，只是最终存储介质不同 （JVM堆内、堆外、类SSD高速存储文件）；``offheap``模式使用操作系统内存不使用CMS GC，因此不会因内存碎片化触发Full GC，同时不需要将操作系统的内存拷贝到JVM heap中，因此分配内存的效率高于``heap``模式；但读取缓存时，``offheap``需要从操作系统内存拷贝到JVM heap中再读取，比``heap``模式中直接从JVM heap读取更耗时；``file``模式则使用SSD等作为存储介质，可以提供更大的缓存存储容量，提升缓存命中率。

- 写入缓存BucketCache

```java
package org.apache.hadoop.hbase.io.hfile.bucket;

public class BucketCache implements BlockCache, HeapSize {

  public BucketCache(...) throws FileNotFoundException, IOException {
    // file:、heap、offheap
    this.ioEngine = getIOEngineFromName(ioEngineName, capacity);
    ...
    // 1.0 ⬇
    bucketAllocator = new BucketAllocator(capacity, bucketSizes);
    // BlockCacheKey 和 Block数据
    this.ramCache = new ConcurrentHashMap<BlockCacheKey, RAMQueueEntry>();
    // BlockCacheKey 和 物理偏移地址offset
    this.backingMap = new ConcurrentHashMap<BlockCacheKey, BucketEntry>((int) blockNumCapacity);
    // 并发异步将Block写入内存
    for (int i = 0; i < writerThreads.length; ++i) {
      writerThreads[i] = new WriterThread(writerQueues.get(i), i);
      writerThreads[i].setName(threadName + "-BucketCacheWriter-" + i);
      writerThreads[i].setDaemon(true);
    }
    startWriterThreads();
  }
}
```

```java
package org.apache.hadoop.hbase.io.hfile.bucket;

// BucketAllocator -> BucketSizeInfo[i]-> Bucket[i]
public final class BucketAllocator {
  // 1.0 ⬇ ⬆
  BucketAllocator(long availableSpace, int[] bucketSizes)
      throws BucketAllocatorException {
    // ⬇
    this.bucketSizes = bucketSizes == null ? DEFAULT_BUCKET_SIZES : bucketSizes;
    bucketSizeInfos = new BucketSizeInfo[this.bucketSizes.length];
    for (int i = 0; i < this.bucketSizes.length; ++i) {
      bucketSizeInfos[i] = new BucketSizeInfo(i);
    }
    for (int i = 0; i < buckets.length; ++i) {
      // baseOffset、sizeIndex
      buckets[i] = new Bucket(bucketCapacity * i);
      bucketSizeInfos[i < this.bucketSizes.length ? i : this.bucketSizes.length - 1]
          .instantiateBucket(buckets[i]);
    }
  }

  final class BucketSizeInfo {
    private static final int DEFAULT_BUCKET_SIZES[] = { 4 * 1024 + 1024, 8 * 1024 + 1024,
      16 * 1024 + 1024, 32 * 1024 + 1024, 40 * 1024 + 1024, 48 * 1024 + 1024,
      56 * 1024 + 1024, 64 * 1024 + 1024, 96 * 1024 + 1024, 128 * 1024 + 1024,
      192 * 1024 + 1024, 256 * 1024 + 1024, 384 * 1024 + 1024,
      512 * 1024 + 1024 };
  }
}
```

- 读取缓存BucketCache

```java
package org.apache.hadoop.hbase.io.hfile.bucket;

public class BucketCache implements BlockCache, HeapSize {

  @Override
  public Cacheable getBlock(BlockCacheKey key, boolean caching, ...) {
    if (!cacheEnabled) return null;
    // 没来及写入Bucket的Block在RAMCache中
    RAMQueueEntry re = ramCache.get(key);
    if (re != null) {
      if (updateCacheMetrics) cacheStats.hit(caching);
      re.access(accessCount.incrementAndGet());
      return re.getData();
    }
    // RAMCache中未找到，则通过BackingMap中offset查找到内存中对应Block
    BucketEntry bucketEntry = backingMap.get(key);
    if(bucketEntry!=null) {
      try {
        // offset + length
        lockEntry = offsetLock.getLockEntry(bucketEntry.offset());
        if (bucketEntry.equals(backingMap.get(key))) {
          int len = bucketEntry.getLength();
          ByteBuffer bb = ByteBuffer.allocate(len);
          int lenRead = ioEngine.read(bb, bucketEntry.offset());
          Cacheable cachedBlock = deserializer.deserialize(bb, true);
          ...
          return cachedBlock;
        }
      }
      ...
    }
  }
}
```

#### CombinedBlockCache

实际应用中，HBase将BucketCache和LRUBlockCache搭配使用（CombinedBlockCache）；系统在LRUBlockCache中主要存储Index Block和Bloom Block，在BucketCache中存储Data Block；因此一次随机读会首先去LRUBlockCache中查到对应的Index Block，然后再到BucketCache中查找对应Data Block。

```java
package org.apache.hadoop.hbase.io.hfile;

public class CombinedBlockCache implements BlockCache, HeapSize {

 @Override
  public void cacheBlock(BlockCacheKey cacheKey, Cacheable buf, boolean inMemory) {
    boolean isMetaBlock = buf.getBlockType().getCategory() != BlockCategory.DATA;
    if (isMetaBlock) {
      //smaller lruCache
      lruCache.cacheBlock(cacheKey, buf, inMemory);
    } else {
      //larger bucketCache 
      bucketCache.cacheBlock(cacheKey, buf, inMemory);
    }
  }

  @Override
  public Cacheable getBlock(BlockCacheKey cacheKey, boolean caching,
      boolean repeat, boolean updateCacheMetrics) {
    if (lruCache.containsBlock(cacheKey)) {
      return lruCache.getBlock(cacheKey, caching, repeat, updateCacheMetrics);
    }
    return bucketCache.getBlock(cacheKey, caching, repeat, updateCacheMetrics);
  }
}
```

CombinedBlockCache优化配置：

```bash
### offheap模式 或heap
<hbase.bucketcache.ioengine>offheap</hbase.bucketcache.ioengine>
### bucketcache占用整个jvm内存大小的比例 或 bucketcache缓存空间大小，单位为MB
<hbase.bucketcache.size>0.4</hbase.bucketcache.size>
### bucketcache在combinedcache中的占比
<hbase.bucketcache.combinedcache.percentage>0.9</hbase.bucketcache.combinedcache.percentage>

### file模式
<hbase.bucketcache.ioengine>file:/cache_path</hbase.bucketcache.ioengine>
<hbase.bucketcache.size>10 * 1024</hbase.bucketcache.size>
### 高速缓存路径
<hbase.bucketcache.persistent.path>file:/CachePath</hbase.bucketcache.persistent.path>
```

#### LRUBlockCache VS CombinedBlockCache

基于CPU、IO、吞吐量、读延迟这些指标，在缓存全部命中场景，LRUBlockCache各项表现优于CombinedBlockCache（基于offheap），GC时长也短，所以在缓存全部命中场景选择LRUBlockCache；其他存在未命中场景，各指标基本相当，但LRUBlockCache总GC时长3倍于CombinedBlockCache，所以其他存在缓存未命中的场景选择CombinedBlockCache。

因为缓存全命中场景，CombinedBlockCache需要将全部数据从堆外内存拷贝到JVM堆中，再返回客户端，比较耗时；而大量缓存未命中场景，则不需要过多内存拷贝操作，因此表现相当。
