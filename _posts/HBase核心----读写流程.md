
# 读

一次客户端发起的读请求可分成两个阶段: 客户端如何将请求发送给正确的RegionServer、被请求的RegionServer如何处理读请求。

## Client精准请求

为什么访问HBase集群的客户端程序配置文件中只需要配置HMaster、ZK地址和根目录，不配置RegionServer的地址列表，如何将请求发送给正确的RegionServer？

1. 元数据表hbase:meta的元信息保存在ZK中，RPC请求ZK获取Meta表所在RegionServer
2. 请求Meta表所在RegionservServer，将meta数据表缓存在客户端本地
(第一次客户端请求需要执行 1 2步，之后该客户端只需要查询本地缓存中的meta表数据；)
查询meta表获取请求rowkey所在Regionserver并发起请求


```java
package org.apache.hadoop.hbase.client;

public class HTable implements HTableInterface {

  @Override
  public Result get(final Get get) throws IOException {
    final PayloadCarryingRpcController controller = rpcControllerFactory.newController();
    controller.setPriority(tableName);
    //1.0
    RegionServerCallable<Result> callable =
        new RegionServerCallable<Result>(this.connection, getName(), get.getRow()) {
          public Result call() throws IOException {
            //1.1
            return ProtobufUtil.get(getStub(), getLocation().getRegionInfo().getRegionName(), get,
              controller);
          }
        };
    //9.0
    return rpcCallerFactory.<Result> newCaller().callWithRetries(callable, this.operationTimeout);
  }

  @Override
  public Result[] get(List<Get> gets) throws IOException {
    ...
  }
}
```

```java
package org.apache.hadoop.hbase.protobuf;

public final class ProtobufUtil {
    //1.1
    public static Result get(ClientService.BlockingInterface client, regionName, Get get, controller) {
        GetRequest request =
            RequestConverter.buildGetRequest(regionName, get);
        try {
            //1.2
            GetResponse response = client.get(controller, request);
            if (response == null) return null;
            return toResult(response.getResult());
        } catch (ServiceException se) {
            throw getRemoteException(se);
        }
    }
}



package org.apache.hadoop.hbase.protobuf.generated;

public final class ClientProtos {
    public interface BlockingInterface {
      //1.2 => 1.3 RPC调用远程RegionSever定义的函数
      public org.apache.hadoop.hbase.protobuf.generated.ClientProtos.GetResponse get(
          com.google.protobuf.RpcController controller,
          org.apache.hadoop.hbase.protobuf.generated.ClientProtos.GetRequest request)
          throws com.google.protobuf.ServiceException;
    }
}
```

## Server处理请求


```java
package org.apache.hadoop.hbase.regionserver;

public class HRegionServer implements ClientProtos.ClientService.BlockingInterface,
  AdminProtos.AdminService.BlockingInterface, Runnable, RegionServerServices,
  HBaseRPCErrorHandler, LastSequenceId {

  //1.3
  @Override
  public GetResponse get(final RpcController controller,
      final GetRequest request) throws ServiceException {
    long before = EnvironmentEdgeManager.currentTimeMillis();
    try {
      checkOpen();
      requestCount.increment();
      HRegion region = getRegion(request.getRegion());

      if (get.hasClosestRowBefore() && get.getClosestRowBefore()) {
       ...
      } else {
        Get clientGet = ProtobufUtil.toGet(get);
        if (get.getExistenceOnly() && region.getCoprocessorHost() != null) {
          existence = region.getCoprocessorHost().preExists(clientGet);
        }
        if (existence == null) {
          //1.4
          r = region.get(clientGet);
        }
      }
      ...
  }
}
```

```java
package org.apache.hadoop.hbase.regionserver;

public class HRegion implements HeapSize {
  //1.4
  public Result get(final Get get) throws IOException {
    //检测get请求的rowkey是否在region范围内
    checkRow(get.getRow(), "Get");
    //检测请求中带的CF，没带则加入所有CF
    if (get.hasFamilies()) {
      checkFamily(family);
    } else {
      get.addFamily(family);
    }
    //1.5
    List<Cell> results = get(get, true);
    return results;
  }

  //1.5
  public List<Cell> get(Get get, boolean withCoprocessor)
    throws IOException {
    List<Cell> results = new ArrayList<Cell>();
    // pre-get CP hook
    if (withCoprocessor && (coprocessorHost != null)) {
       if (coprocessorHost.preGet(get, results)) {
         return results;
       }
    }
    //get其实也是scan
    Scan scan = new Scan(get);
    RegionScanner scanner = null;
    try {
      //1.6  实例化RegionScanner
      scanner = getScanner(scan);
      //2.0
      scanner.next(results);
    } finally {
      if (scanner != null)
        scanner.close();
    }
    // post-get CP hook
    if (withCoprocessor && (coprocessorHost != null)) {
      coprocessorHost.postGet(get, results);
    }
    ...
    return results;
  }

  //1.6
  public RegionScanner getScanner(Scan scan) throws IOException {
   //1.7
   return getScanner(scan, null);
  }

  //1.7
  protected RegionScanner getScanner(Scan scan,
      List<KeyValueScanner> additionalScanners) throws IOException {
    startRegionOperation(Operation.SCAN);
    try {
      //scan请求检测CF,没有则添加所有
      prepareScanner(scan);
      if(scan.hasFamilies()) {
        for(byte [] family : scan.getFamilyMap().keySet()) {
          checkFamily(family);
        }
      }
      //1.8
      return instantiateRegionScanner(scan, additionalScanners);
    } finally {
      closeRegionOperation(Operation.SCAN);
    }
  }

  //1.8
  protected RegionScanner instantiateRegionScanner(Scan scan,
      List<KeyValueScanner> additionalScanners) throws IOException {
    if (scan.isReversed()) {
      if (scan.getFilter() != null) {
        scan.getFilter().setReversed(true);
      }
      return new ReversedRegionScannerImpl(scan, additionalScanners, this);
    }
    //1.9
    return new RegionScannerImpl(scan, additionalScanners, this);
  }
}
```


```java
package org.apache.hadoop.hbase.regionserver;

public class HRegion implements HeapSize {
  class RegionScannerImpl implements RegionScanner {
    //1.9 构建多个StoreScanner
    RegionScannerImpl(Scan scan, List<KeyValueScanner> additionalScanners, HRegion region)
            throws IOException {
        ...
        List<KeyValueScanner> scanners = new ArrayList<KeyValueScanner>();
        List<KeyValueScanner> joinedScanners = new ArrayList<KeyValueScanner>();

        for (Map.Entry<byte[], NavigableSet<byte[]>> entry :
            scan.getFamilyMap().entrySet()) {
            //为每个CF创建对应的Store对象，进而创建各自的StoreScanner
            Store store = stores.get(entry.getKey());
            //2.0 
            KeyValueScanner scanner = store.getScanner(scan, entry.getValue(), this.readPt);
            if (this.filter == null || !scan.doLoadColumnFamiliesOnDemand()
            || this.filter.isFamilyEssential(entry.getKey())) {
            scanners.add(scanner);
            } else {
            joinedScanners.add(scanner);
            }
        }
        initializeKVHeap(scanners, joinedScanners, region);
    }
  }
}
```

```java
package org.apache.hadoop.hbase.regionserver;

public class HStore implements Store {
  
  //2.0
  @Override
  public KeyValueScanner getScanner(Scan scan,
      final NavigableSet<byte []> targetCols, long readPt) throws IOException {
    lock.readLock().lock();
    try {
      KeyValueScanner scanner = null;
      if (this.getCoprocessorHost() != null) {
        scanner = this.getCoprocessorHost().preStoreScannerOpen(this, scan, targetCols);
      }
      if (scanner == null) {
        //2.1
        scanner = scan.isReversed() ? new ReversedStoreScanner(this,
            getScanInfo(), scan, targetCols, readPt) : new StoreScanner(this,
            getScanInfo(), scan, targetCols, readPt);
      }
      return scanner;
    } finally {
      lock.readLock().unlock();
    }
  }
}
```

```java
package org.apache.hadoop.hbase.regionserver;

public class StoreScanner extends NonReversedNonLazyKeyValueScanner
    implements KeyValueScanner, InternalScanner, ChangedReadersObserver {
  /**
   * Opens a scanner across memstore, snapshot, and all StoreFiles. Assumes we
   * are not in a compaction.
   *
   * @param store who we scan
   * @param scan the spec
   * @param columns which columns we are scanning
   * @throws IOException
   */
  
  //2.1
  public StoreScanner(Store store, ScanInfo scanInfo, Scan scan, final NavigableSet<byte[]> columns,
      long readPt) throws IOException {
    this(store, scan.getCacheBlocks(), scan, columns, scanInfo.getTtl(),
        scanInfo.getMinVersions(), readPt);
    if (columns != null && scan.isRaw()) {
      throw new DoNotRetryIOException(
          "Cannot specify any column for a raw scan");
    }
    matcher = new ScanQueryMatcher(scan, scanInfo, columns,
        ScanType.USER_SCAN, Long.MAX_VALUE, HConstants.LATEST_TIMESTAMP,
        oldestUnexpiredTS, now, store.getCoprocessorHost());

    this.store.addChangedReaderObserver(this);

    //2.2
    // Pass columns to try to filter out unnecessary StoreFiles.
    List<KeyValueScanner> scanners = getScannersNoCompaction();

    // Seek all scanners to the start of the Row (or if the exact matching row
    // key does not exist, then to the start of the next matching Row).
    // Always check bloom filter to optimize the top row seek for delete
    // family marker.
    seekScanners(scanners, matcher.getStartKey(), explicitColumnQuery
        && lazySeekEnabledGlobally, isParallelSeekEnabled);

    // set storeLimit
    this.storeLimit = scan.getMaxResultsPerColumnFamily();

    // set rowOffset
    this.storeOffset = scan.getRowOffsetPerColumnFamily();

    // Combine all seeked scanners with a heap
    resetKVHeap(scanners, store.getComparator());
  }
}
```


```java
  /**
   * Get a filtered list of scanners. Assumes we are not in a compaction.
   * @return list of scanners to seek
   */
   //2.2
  protected List<KeyValueScanner> getScannersNoCompaction() throws IOException {
    final boolean isCompaction = false;
    boolean usePread = isGet || scanUsePread;
    //2.3
    return selectScannersFrom(store.getScanners(cacheBlocks, isGet, usePread,
        isCompaction, matcher, scan.getStartRow(), scan.getStopRow(), this.readPt));
  }
```

```java
//2.3
/**
   * Filters the given list of scanners using Bloom filter, time range, and
   * TTL.
   */
  protected List<KeyValueScanner> selectScannersFrom(
      final List<? extends KeyValueScanner> allScanners) {
    boolean memOnly;
    boolean filesOnly;
    if (scan instanceof InternalScan) {
      InternalScan iscan = (InternalScan)scan;
      memOnly = iscan.isCheckOnlyMemStore();
      filesOnly = iscan.isCheckOnlyStoreFiles();
    } else {
      memOnly = false;
      filesOnly = false;
    }

    List<KeyValueScanner> scanners =
        new ArrayList<KeyValueScanner>(allScanners.size());

    // We can only exclude store files based on TTL if minVersions is set to 0.
    // Otherwise, we might have to return KVs that have technically expired.
    long expiredTimestampCutoff = minVersions == 0 ? oldestUnexpiredTS :
        Long.MIN_VALUE;

    // include only those scan files which pass all filters
    for (KeyValueScanner kvs : allScanners) {
      boolean isFile = kvs.isFileScanner();
      if ((!isFile && filesOnly) || (isFile && memOnly)) {
        continue;
      }

      //2.4
      if (kvs.shouldUseScanner(scan, columns, expiredTimestampCutoff)) {
        scanners.add(kvs);
      }
    }
    return scanners;
  }
```

```java
package org.apache.hadoop.hbase.regionserver;

public class StoreFileScanner implements KeyValueScanner {

    @Override
    public boolean isFileScanner() {
        return true;
    }

    //2.4
    @Override
    public boolean shouldUseScanner(Scan scan, SortedSet<byte[]> columns, long oldestUnexpiredTS) {
        return reader.passesTimerangeFilter(scan, oldestUnexpiredTS)
            && reader.passesKeyRangeFilter(scan) && reader.passesBloomFilter(scan, columns);
    }
}
```


### 读

HBase读文件细粒度的过程？HBase随机读写快除了MemStore之外的原因？


0. 先找到对应的Region

1. 用MemStoreScanner搜索MemStore里是否有所查的rowKey（这一步在内存中，很快），

2. 同时也会用Bloom Block通过一定算法过滤掉大部分一定不包含所查rowKey的HFile，

3. 上面提到在RegionServer启动的时候就会把Trailer，和Load-on-open-section里的block先后加载到内存，

所以接下来会查Trailer，因为它记录了每个HFile的偏移量，可以快速排除掉剩下的部分HFile。

4.经过上面两步，剩下的就是很少一部分的HFile了，就需要根据Index Block索引数据（这部分的Block已经在内存）快速查找rowkey所在的block的位置；

5.找到block的位置后，检查这个block是否在blockCache中，在则直接去取，如果不在的话把这个block加载到blockCache进行缓存，

当下一次再定位到这个Block的时候就不需要再进行一次IO将整个block读取到内存中。

6.最后扫描这些读到内存中的Block（可能有多个，因为有多版本），找到对应rowKey返回需要的版本。


另外，关于blockCache很多人都理解错了，这里要注意的是：

blockCache并没有省去扫描定位block这一步，只是省去了最后将Block加载到内存的这一步而已。


这里又引出一个问题，如果BlockCache中有需要查找的rowKey，但是版本不是最新的，那会不会读到脏数据？

HBase是多版本共存的，有多个版本的rowKey那说明这个rowKey会存在多个Block中，其中一个已经在BlockCache中，则省去了一次IO，但是其他Block的IO是无法省去的，它们也需要加载到BlockCache，然后多版本合并，获得需要的版本返回。解决多版本的问题，也是rowKey需要先定位Block然后才去读BlockCache的原因。



上述流程中因为中间节点、叶子节点和数据块都需要加载到内存，所以io次数正常为3次。
但是实际上HBase为block提供了缓存机制，可以将频繁使用的block缓存在内存中，可以进一步加快实际读取过程。
所以，在HBase中，通常一次随机读请求最多会产生3次io，如果数据量小（只有一层索引），数据已经缓存到了内存，就不会产生io。



## 写流程

向zookeeper发起请求，从ROOT表中获得META所在的region，再根据table，namespace，rowkey，去meta表中找到目标数据对应的region信息以及regionserver
把数据分别写到HLog和MemStore上一份，若MemStore中的数据有丢失，则可在HLog上恢复
当memstore数据达到阈值（默认是64M），将数据刷到硬盘，将内存中的数据删除同时删除Hlog中的历史数据。
当多个StoreFile文件达到一定的大小后，会触发Compact合并操作，合并为一个StoreFile，这里同时进行版本的合并和数据删除。
当Compact后，逐步形成越来越大的StoreFIle后，会触发Split操作，把当前的StoreFile分成两个，这里相当于把一个大的region分割成两个region
当hregionser宕机后，将hregionserver上的hlog拆分，然后分配给不同的hregionserver加载，修改.META.