
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
    // 1.0 ⬇
    RegionServerCallable<Result> callable =
        new RegionServerCallable<Result>(this.connection, getName(), get.getRow()) {
          public Result call() throws IOException {
            // 1.1 ⬇
            return ProtobufUtil.get(getStub(), getLocation().getRegionInfo().getRegionName(), get,
              controller);
          }
        };
    //xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
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
    // 1.1 ⬇
    public static Result get(ClientService.BlockingInterface client, regionName, Get get, controller) {
        GetRequest request =
            RequestConverter.buildGetRequest(regionName, get);
        try {
            // 1.2 ⬇
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
      // 1.2 => 1.3 ⬇ RPC调用远程RegionSever定义的函数
      public org.apache.hadoop.hbase.protobuf.generated.ClientProtos.GetResponse get(
          com.google.protobuf.RpcController controller,
          org.apache.hadoop.hbase.protobuf.generated.ClientProtos.GetRequest request)
          throws com.google.protobuf.ServiceException;
    }
}
```

## Server处理请求

RegionServer 接收到客户端的get/scan请求，开始构建Scanner基础体系，然后按行检索.

### 构建Scanner

- RSRPCService.get

```java
package org.apache.hadoop.hbase.regionserver;

public class HRegionServer implements ClientProtos.ClientService.BlockingInterface,
  AdminProtos.AdminService.BlockingInterface, Runnable, RegionServerServices,
  HBaseRPCErrorHandler, LastSequenceId {

  // 1.3 ⬇
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
          // 1.4 ⬇
          r = region.get(clientGet);
        }
      }
      ...
  }
}
```

- get RegionScanner

```java
package org.apache.hadoop.hbase.regionserver;

public class HRegion implements HeapSize {
  // 1.4 ⬇
  public Result get(final Get get) throws IOException {
    //检测get请求的rowkey是否在region范围内
    checkRow(get.getRow(), "Get");
    //检测请求中带的CF，没带则加入所有CF
    if (get.hasFamilies()) {
      checkFamily(family);
    } else {
      get.addFamily(family);
    }
    // 1.5 ⬇
    List<Cell> results = get(get, true);
    return results;
  }

  // 1.5 ⬇
  public List<Cell> get(Get get, boolean withCoprocessor)
    throws IOException {
    List<Cell> results = new ArrayList<Cell>();
    //前后各一个钩子，可以自实现Coprocessor
    if (withCoprocessor && (coprocessorHost != null)) {
       if (coprocessorHost.preGet(get, results)) {
         return results;
       }
    }
    //get其实也是scan
    Scan scan = new Scan(get);
    RegionScanner scanner = null;
    try {
      // 1.6 ⬇  构造Scanner和KVHeap 
      scanner = getScanner(scan);
      // 3.3 ⬇  Scanner检索
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

  // 1.6 ⬇
  public RegionScanner getScanner(Scan scan) throws IOException {
   // 1.7 ⬇
   return getScanner(scan, null);
  }

  // 1.7 ⬇
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
      // 1.8 ⬇
      return instantiateRegionScanner(scan, additionalScanners);
    } finally {
      closeRegionOperation(Operation.SCAN);
    }
  }

  // 1.8 ⬇
  protected RegionScanner instantiateRegionScanner(Scan scan,
      List<KeyValueScanner> additionalScanners) throws IOException {
    if (scan.isReversed()) {
      if (scan.getFilter() != null) {
        scan.getFilter().setReversed(true);
      }
      return new ReversedRegionScannerImpl(scan, additionalScanners, this);
    }
    // 1.9 ⬇
    return new RegionScannerImpl(scan, additionalScanners, this);
  }
}
```

- get StoreScanner

```java
package org.apache.hadoop.hbase.regionserver;

public class HRegion implements HeapSize {
  class RegionScannerImpl implements RegionScanner {
    // 1.9 ⬇ 构建多个StoreScanner
    RegionScannerImpl(Scan scan, List<KeyValueScanner> additionalScanners, HRegion region)
            throws IOException {
        ...
        List<KeyValueScanner> scanners = new ArrayList<KeyValueScanner>();
        List<KeyValueScanner> joinedScanners = new ArrayList<KeyValueScanner>();

        for (Map.Entry<byte[], NavigableSet<byte[]>> entry :
            scan.getFamilyMap().entrySet()) {
            //为每个CF创建对应的Store对象，进而创建各自的StoreScanner
            Store store = stores.get(entry.getKey());
            // 2.0 ⬇
            KeyValueScanner scanner = store.getScanner(scan, entry.getValue(), this.readPt);
            if (this.filter == null || !scan.doLoadColumnFamiliesOnDemand()
            || this.filter.isFamilyEssential(entry.getKey())) {
              scanners.add(scanner);
            } else {
              joinedScanners.add(scanner);
            }
        }
        // 3.2 ↑
        initializeKVHeap(scanners, joinedScanners, region);
        //storeHeap:  new KeyValueHeap(scanners, Comparator) -> new PriorityQueue<KeyValueScanner>(scanners.size(), Comparator)
        //joinedHeap: new KeyValueHeap(joinedScanners, Comparator) -> new PriorityQueue<KeyValueScanner>(joinedScanners.size(), Comparator)
    }
  }
}
```

```java
package org.apache.hadoop.hbase.regionserver;

public class HStore implements Store {
  
  // 2.0 ⬇
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
        // 2.1 ⬇
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

- get StoreFileScanner and MemStoreScanner

```java
package org.apache.hadoop.hbase.regionserver;

public class StoreScanner extends NonReversedNonLazyKeyValueScanner
    implements KeyValueScanner, InternalScanner, ChangedReadersObserver {

  // 2.1 ⬇
  public StoreScanner(Store store, ScanInfo scanInfo, Scan scan, final NavigableSet<byte[]> columns,
      long readPt) throws IOException {
    this(store, scan.getCacheBlocks(), scan, columns, scanInfo.getTtl(),
        scanInfo.getMinVersions(), readPt);

    matcher = new ScanQueryMatcher(scan, scanInfo, columns,
        ScanType.USER_SCAN, Long.MAX_VALUE, HConstants.LATEST_TIMESTAMP,
        oldestUnexpiredTS, now, store.getCoprocessorHost());
    this.store.addChangedReaderObserver(this);

    // 2.2 ⬇
    List<KeyValueScanner> scanners = getScannersNoCompaction();

    // 3.1 ⬇ ⬆ seek StoreScanners by matcher.getStartKey()
    seekScanners(scanners, matcher.getStartKey(), explicitColumnQuery
        && lazySeekEnabledGlobally, isParallelSeekEnabled);
    // if (isLazy) { KeyValueScanner.requestSeek(seekKey); }
    // if (!isLazy && !isParallelSeek) { KeyValueScanner.seek(seekKey); }
    // if(!isLazy && isParallelSeek) { parallelSeek(KeyValueScanners, seekKey); }
     
    // set storeLimit
    this.storeLimit = scan.getMaxResultsPerColumnFamily();
    // set rowOffset
    this.storeOffset = scan.getRowOffsetPerColumnFamily();

    //KeyValueHeap.add(KeyValueScanners) -> new PriorityQueue<KeyValueScanner>(KeyValueScanners.size(), Comparator);
    resetKVHeap(scanners, store.getComparator());
  }
}
```

```java
package org.apache.hadoop.hbase.regionserver;

public class StoreScanner extends NonReversedNonLazyKeyValueScanner
    implements KeyValueScanner, InternalScanner, ChangedReadersObserver {

   // 2.2 ⬇
  protected List<KeyValueScanner> getScannersNoCompaction() throws IOException {
    final boolean isCompaction = false;
    boolean usePread = isGet || scanUsePread;
    // 2.8 ⬇
    return selectScannersFrom(
        // 2.3 ⬇
        store.getScanners(cacheBlocks, isGet, usePread,
        isCompaction, matcher, scan.getStartRow(), scan.getStopRow(), this.readPt)
    );
  }
}
```

```java
package org.apache.hadoop.hbase.regionserver;

public class HStore implements Store {
  // 2.3 ⬇
  @Override
  public List<KeyValueScanner> getScanners(boolean cacheBlocks, boolean isGet,
      boolean usePread, boolean isCompaction, ScanQueryMatcher matcher, byte[] startRow,
      byte[] stopRow, long readPt) throws IOException {
    Collection<StoreFile> storeFilesToScan;
    List<KeyValueScanner> memStoreScanners;
    this.lock.readLock().lock();
    try {
      storeFilesToScan =
          this.storeEngine.getStoreFileManager().getFilesForScanOrGet(isGet, startRow, stopRow);
      // 2.4 ⬇
      memStoreScanners = this.memstore.getScanners(readPt);
    } finally {
      this.lock.readLock().unlock();
    }
    // 2.6 ⬇
    List<StoreFileScanner> sfScanners = StoreFileScanner
      .getScannersForStoreFiles(storeFilesToScan, cacheBlocks, usePread, isCompaction, matcher,
        readPt);
    List<KeyValueScanner> scanners =
      new ArrayList<KeyValueScanner>(sfScanners.size()+1);
    scanners.addAll(sfScanners);
    scanners.addAll(memStoreScanners);
    return scanners;
  }
}
```

- get MemStoreScanner

```java
package org.apache.hadoop.hbase.regionserver;

public class MemStore implements HeapSize {

  // 2.4 ⬇
  List<KeyValueScanner> getScanners(long readPt) {
    return Collections.<KeyValueScanner>singletonList(
        // 2.5 ⬇
        new MemStoreScanner(readPt));
  }

  //NonLazyKeyValueScanner implements KeyValueScanner, which do real seek operation.
  //scan the contents of a memstore -- both current map and snapshot.
  protected class MemStoreScanner extends NonLazyKeyValueScanner {
    // 2.5 ⬆
    MemStoreScanner(long readPoint) {
      super();

      this.readPoint = readPoint;
      kvsetAtCreation = kvset;
      snapshotAtCreation = snapshot;
      if (allocator != null) {
        this.allocatorAtCreation = allocator;
        this.allocatorAtCreation.incScannerCount();
      }
      if (snapshotAllocator != null) {
        this.snapshotAllocatorAtCreation = snapshotAllocator;
        this.snapshotAllocatorAtCreation.incScannerCount();
      }
      if (Trace.isTracing() && Trace.currentSpan() != null) {
        Trace.currentSpan().addTimelineAnnotation("Creating MemStoreScanner");
      }
    }
  }
}
```

- get StoreFileScanner

```java
package org.apache.hadoop.hbase.regionserver;

public class StoreFileScanner implements KeyValueScanner {

  // 2.6 ⬇
  public static List<StoreFileScanner> getScannersForStoreFiles(
      Collection<StoreFile> files, boolean cacheBlocks, boolean usePread,
      boolean isCompaction, ScanQueryMatcher matcher, long readPt) throws IOException {
    List<StoreFileScanner> scanners = new ArrayList<StoreFileScanner>(
        files.size());
    //为每个StoreFile创建对应的StoreFileScanner
    for (StoreFile file : files) {
      StoreFile.Reader r = file.createReader();
      // 2.7 ⬆
      //StoreFile.getStoreFileScanner -> new StoreFileScanner
      StoreFileScanner scanner = r.getStoreFileScanner(cacheBlocks, usePread,
          isCompaction, readPt);
      //添加ScanQueryMatcher优化
      scanner.setScanQueryMatcher(matcher);
      scanners.add(scanner);
    }
    return scanners;
  }
}
```

- KeyRangeFilter、TimerangeFilter、BloomFilter

```java
package org.apache.hadoop.hbase.regionserver;

public class StoreScanner extends NonReversedNonLazyKeyValueScanner
    implements KeyValueScanner, InternalScanner, ChangedReadersObserver {
  
  // 2.8 ⬇
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
    
    //TTL
    long expiredTimestampCutoff = minVersions == 0 ? oldestUnexpiredTS :
        Long.MIN_VALUE;

    //filters for all scan files 
    for (KeyValueScanner kvs : allScanners) {
      boolean isFile = kvs.isFileScanner();
      if ((!isFile && filesOnly) || (isFile && memOnly)) {
        continue;
      }
      // 2.9 ⬇
      if (kvs.shouldUseScanner(scan, columns, expiredTimestampCutoff)) {
        scanners.add(kvs);
      }
    }
    return scanners;
  }
}
```

```java
package org.apache.hadoop.hbase.regionserver;

public class StoreFileScanner implements KeyValueScanner {

    @Override
    public boolean isFileScanner() {
        return true;
    }

    // 2.9 ⬇
    @Override
    public boolean shouldUseScanner(Scan scan, SortedSet<byte[]> columns, long oldestUnexpiredTS) {
        // 3.0 ⬇
        return reader.passesTimerangeFilter(scan, oldestUnexpiredTS)
            && reader.passesKeyRangeFilter(scan) && reader.passesBloomFilter(scan, columns);
    }
}
```

```java
package org.apache.hadoop.hbase.regionserver;

public class StoreFile {
  // 3.0 ⬆
  public static class Reader {

    boolean passesTimerangeFilter(Scan scan, long oldestUnexpiredTS) {
      if (timeRangeTracker == null) {
        return true;
      } else {
        return timeRangeTracker.includesTimeRange(scan.getTimeRange()) &&
            timeRangeTracker.getMaximumTimestamp() >= oldestUnexpiredTS;
      }
    }

    public boolean passesKeyRangeFilter(Scan scan) {
      if (this.getFirstKey() == null || this.getLastKey() == null) {
        // the file is empty
        return false;
      }
      if (Bytes.equals(scan.getStartRow(), HConstants.EMPTY_START_ROW)
          && Bytes.equals(scan.getStopRow(), HConstants.EMPTY_END_ROW)) {
        return true;
      }
      KeyValue smallestScanKeyValue = scan.isReversed() ? KeyValue
          .createFirstOnRow(scan.getStopRow()) : KeyValue.createFirstOnRow(scan
          .getStartRow());
      KeyValue largestScanKeyValue = scan.isReversed() ? KeyValue
          .createLastOnRow(scan.getStartRow()) : KeyValue.createLastOnRow(scan
          .getStopRow());
      boolean nonOverLapping = (getComparator().compareFlatKey(
          this.getFirstKey(), largestScanKeyValue.getKey()) > 0 && !Bytes
          .equals(scan.isReversed() ? scan.getStartRow() : scan.getStopRow(),
              HConstants.EMPTY_END_ROW))
          || getComparator().compareFlatKey(this.getLastKey(),
              smallestScanKeyValue.getKey()) < 0;
      return !nonOverLapping;
    }

     boolean passesBloomFilter(Scan scan, final SortedSet<byte[]> columns) {
      // Multi-column non-get scans will use Bloom filters through the
      // lower-level API function that this function calls.
      if (!scan.isGetScan()) { return true;}

      byte[] row = scan.getStartRow();
      switch (this.bloomFilterType) {
        case ROW:
          return passesGeneralBloomFilter(row, 0, row.length, null, 0, 0);

        case ROWCOL:
          if (columns != null && columns.size() == 1) {
            byte[] column = columns.first();
            return passesGeneralBloomFilter(row, 0, row.length, column, 0,
                column.length);
          }
          return true;

        default:
          return true;
      }
    }
  }
}
```

### Scanner检索

```java
package org.apache.hadoop.hbase.regionserver;

public class HRegion implements HeapSize {

  public List<Cell> get(Get get, boolean withCoprocessor)
    throws IOException {
    List<Cell> results = new ArrayList<Cell>();
    //前后各一个钩子，可以自实现Coprocessor
    if (withCoprocessor && (coprocessorHost != null)) {
       if (coprocessorHost.preGet(get, results)) {
         return results;
       }
    }
    Scan scan = new Scan(get);
    RegionScanner scanner = null;
    try {
      // 1.6 ⬇  构建Scanner和KVHeap
      scanner = getScanner(scan);
      // 3.3 ⬇  Scanner检索
      scanner.next(results);
    } finally {
      if (scanner != null)
        scanner.close();
    }
    if (withCoprocessor && (coprocessorHost != null)) {
      coprocessorHost.postGet(get, results);
    }
    ...
    return results;
  }
}
```

```java
package org.apache.hadoop.hbase.regionserver;

public class HRegion implements HeapSize {
  class RegionScannerImpl implements RegionScanner {
    // 3.3 ↓
    @Override
    public synchronized boolean next(List<Cell> outResults, int limit) throws IOException {
      startRegionOperation(Operation.SCAN);
      readRequestsCount.increment();
      try {
        // 3.4 ↓
        boolean returnResult = nextRaw(outResults, limit);
        ...
        return returnResult;
      } finally {
        closeRegionOperation(Operation.SCAN);
      }
    }

    @Override
    public boolean nextRaw(List<Cell> outResults, int limit) throws IOException {
      boolean returnResult;
      if (outResults.isEmpty()) {
        // 3.5 ↓
        returnResult = nextInternal(outResults, limit);
      } else {
        List<Cell> tmpList = new ArrayList<Cell>();
        returnResult = nextInternal(tmpList, limit);
        outResults.addAll(tmpList);
      }
      resetFilters();
      return returnResult;
    }

    private boolean nextInternal(List<Cell> results, int limit)
    throws IOException {
      
      while (true) {
        // Let's see what we have in the storeHeap.
        KeyValue current = this.storeHeap.peek();
        if (current != null) {
        byte[] currentRow = current.getBuffer();
        int  offset = current.getRowOffset();
        short length = current.getRowLength();
        }
        boolean stopRow = isStopRow(currentRow, offset, length);
        // getting results from storeHeap
        if (joinedContinuationRow == null) {
          // at stop row, no results
          if (stopRow) { return false; }
          KeyValue nextKv = populateResult(results, this.storeHeap, limit, currentRow, offset,
              length);
          // Ok, we are good, let's try to get some results from the main heap.
          if (nextKv == KV_LIMIT) {
            if (this.filter != null && filter.hasFilterRow()) {
              throw new IncompatibleFilterException(
                "Filter whose hasFilterRow() returns true is incompatible with scan with limit!");
            }
            return true; // We hit the limit.
          }

          stopRow = nextKv == null ||
              isStopRow(nextKv.getBuffer(), nextKv.getRowOffset(), nextKv.getRowLength());
          // save that the row was empty before filters applied to it.
          final boolean isEmptyRow = results.isEmpty();

          // We have the part of the row necessary for filtering (all of it, usually).
          // First filter with the filterRow(List).
          FilterWrapper.FilterRowRetCode ret = FilterWrapper.FilterRowRetCode.NOT_CALLED;
          if (filter != null && filter.hasFilterRow()) {
            ret = filter.filterRowCellsWithRet(results);
          }

          if ((isEmptyRow || ret == FilterWrapper.FilterRowRetCode.EXCLUDE) || filterRow()) {
            results.clear();
            boolean moreRows = nextRow(currentRow, offset, length);
            if (!moreRows) return false;

            // This row was totally filtered out, if this is NOT the last row,
            // we should continue on. Otherwise, nothing else to do.
            if (!stopRow) continue;
            return false;
          }

          // Ok, we are done with storeHeap for this row.
          // Now we may need to fetch additional, non-essential data into row.
          // These values are not needed for filter to work, so we postpone their
          // fetch to (possibly) reduce amount of data loads from disk.
          if (this.joinedHeap != null) {
            KeyValue nextJoinedKv = joinedHeap.peek();
            // If joinedHeap is pointing to some other row, try to seek to a correct one.
            boolean mayHaveData =
              (nextJoinedKv != null && nextJoinedKv.matchingRow(currentRow, offset, length))
              || (this.joinedHeap.requestSeek(KeyValue.createFirstOnRow(currentRow, offset, length),
                true, true)
                && joinedHeap.peek() != null
                && joinedHeap.peek().matchingRow(currentRow, offset, length));
            if (mayHaveData) {
              joinedContinuationRow = current;
              populateFromJoinedHeap(results, limit);
            }
          }
        } else {
          // Populating from the joined heap was stopped by limits, populate some more.
          populateFromJoinedHeap(results, limit);
        }

        // We may have just called populateFromJoinedMap and hit the limits. If that is
        // the case, we need to call it again on the next next() invocation.
        if (joinedContinuationRow != null) {
          return true;
        }

        // Finally, we are done with both joinedHeap and storeHeap.
        // Double check to prevent empty rows from appearing in result. It could be
        // the case when SingleColumnValueExcludeFilter is used.
        if (results.isEmpty()) {
          boolean moreRows = nextRow(currentRow, offset, length);
          if (!moreRows) return false;
          if (!stopRow) continue;
        }

        // We are done. Return the result.
        return !stopRow;
      }
    }
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