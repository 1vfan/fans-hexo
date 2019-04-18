> 源代码基于HBase 0.98


## HFile

### 物理存储

HBase数据以HFile形式存储在HDFS上，假设HDFS中根路径为``/hbase/data``，则HFile具体路径为: ``/hbase/data/namespace/tablename/encoded_regionname/columnfamily/HFilename``。

```bash
###查看HFile内容，encoded_regionname为hbase:meta中HFile所属region的加密结果
hbase org.apache.hadoop.hbase.io.hfile.HFile -f /hbase/data/bgis/bgis_track/4a8d99f5ejg2j243h4k3j43h4j/track_info/2fc0159fa0ce44kso990elaa184 -p

K: 8010020_1496449840000/track_info:recipientUserId/1496449840000/Put/vlen=7/mvcc=0  V: 8010020
K: 8010020_1496449840000/track_info:recipientOrgId/1496449840000/Put/vlen=6/mvcc=0  V: 801000
K: 8010020_1496449840000/track_info:recipientRealName/1496449840000/Put/vlen=6/mvcc=0  V: \xE5\xBC\xA0\xE4\xB8\x89
...
```


### HFile逻辑划分

HFile V1在使用中会占用很多内存，``HFile V3（0.98）``相较于``HFile V2（0.92）``，更改不大。

<table>
    <tr>
        <th>HFile Sections</th>
        <th>Section Desc</th>
        <th>Section Parts</th>
        <th>Section Parts Desc</th>
    </tr>
    <tr>
        <th rowspan="3">Scanned Block Sections</th>
        <th rowspan="3">顺序扫描HFile时</br>包含的数据块都会被读取</th>
        <td>Data Block</td>
        <td>保存实际数据，多个KeyValue组成，默认64K</td>
    </tr>
    <tr>
        <td>Bloom Block</td>
        <td>BloomFilter相关数据块</td>
    </tr>
    <tr>
        <td>Leaf Index Block</td>
        <td>DataBlock的三级索引</td>
    </tr>
    <tr>
        <th rowspan="2">Non-scanned Block Sections</th>
        <th rowspan="2">顺序扫描HFile时</br>包含的数据块不会被读取</th>
        <td>Meta Block</td>
        <td>整个HFile的元数据</td>
    </tr>
    <tr>
        <td>Intermediate Level Data Index Block</td>
        <td>DataBlock的二级索引</td>
    </tr>
    <tr>
        <th rowspan="4">Load-on-open Sections</th>
        <th rowspan="4">RegionServer启动时</br>包含的数据块被加载到内存中</th>
        <td>Data Index</td>
        <td>DataBlock的根索引</td>
    </tr>
    <tr>
        <td>Meta Index</td>
        <td>元数据索引</td>
    </tr>
    <tr>
        <td>Bloom Meta</td>
        <td>Bloom块的元数据信息，包含Bloom索引</td>
    </tr>
    <tr>
        <td>FileInfo</td>
        <td>元数据键值对（定长）：AVG_KEY_LEN, AVG_VALUE_LEN, LAST_KEY, COMPARATOR, MAX_SEQ_ID_KEY</td>
    </tr>
    <tr>
        <th rowspan="1">Trailer</th>
        <th rowspan="1">HFile版本信息，各部分的偏移量和寻址信息</th>
        <td>Trailer Block</td>
        <td>不属于HFile V2的Block，而是固定大小的数据结构，最先加载到内存</td>
    </tr>
</table>

### HFile的BlockType

HFile V2 定义了8种block type : ``DATA``、``LEAF_INDEX``、``BLOOM``、``META``、``INTERMEDIATE_INDEX``、``ROOT_INDEX``、``FILE_INFO``、``BLOOM_META``.

block type包括``BlockHeader``和``BlockData``；BlockHeader主要存储block元数据（其中的BlockType字段用来标识以上其中一种），8钟类型的BlockHeader结构都相同；但是BlockData的结构各不相同，BlockData用来存储具体数据，有的存储具体业务数据，有的存储索引/元数据。

HFile中Block大小在建表描述列族时指定，Data Block默认``BLOCKSIZE=>65536``，大号Data Block有利于顺序Scan，小号Data Block有利于随机get。

### HFile读

数据从memstore flushing到HFile的同时，在内存中记录数据索引及Bloom等信息，待数据完全刷盘完成后，索引等信息也在内存中建立完毕并append写入HFile尾部；

读取HFile时，加载文件后从后往前读，首先根据具体Version创建对应Reader，具体如下：

```java
package org.apache.hadoop.hbase.regionserver;

import org.apache.hadoop.hbase.io.hfile.HFile;

public class StoreFile {

  /** Reader for a StoreFile. */
  public static class Reader {

    private final HFile.Reader reader;

    public Reader(FileSystem fs, Path path, CacheConfig cacheConf, Configuration conf)
        throws IOException {
      reader = HFile.createReader(fs, path, cacheConf, conf);
      bloomFilterType = BloomType.NONE;
    }

    public Reader(FileSystem fs, Path path, FSDataInputStreamWrapper in, long size,
        CacheConfig cacheConf, Configuration conf) throws IOException {
      reader = HFile.createReader(fs, path, in, size, cacheConf, conf);
      bloomFilterType = BloomType.NONE;
    }
  }
}
```

加载``Trailer``进内存，根据获取的HFile版本（``trailer.getMajorVersion()``）创建对应的Reader对象以解析HFile;

```java
package org.apache.hadoop.hbase.io.hfile;

public class HFile {

  /**
   * @param fs: A file system.
   * @param path: HFile path.
   * @param fsdis: a stream of path's file.
   * @param size: HFile size.
   * @param cacheConf: Cache configuation values, cannot be null.
   * @param conf
   * @return A specific version HFile Reader
   */
  public static Reader createReader(FileSystem fs, Path path,
      FSDataInputStreamWrapper fsdis, long size, CacheConfig cacheConf, Configuration conf)
      throws IOException {
    HFileSystem hfs = null;
    if (!(fs instanceof HFileSystem)) {
      hfs = new HFileSystem(fs);
    } else {
      hfs = (HFileSystem)fs;
    }
    return pickReaderVersion(path, fsdis, size, cacheConf, hfs, conf);
  }

  public static Reader createReader(
      FileSystem fs, Path path, CacheConfig cacheConf, Configuration conf) throws IOException {
    Preconditions.checkNotNull(cacheConf, "Cannot create Reader with null CacheConf");
    FSDataInputStreamWrapper stream = new FSDataInputStreamWrapper(fs, path);
    return pickReaderVersion(path, stream, fs.getFileStatus(path).getLen(),
      cacheConf, stream.getHfs(), conf);
  }

  /**
   * Method returns the reader given the specified arguments.
   */
  private static Reader pickReaderVersion(Path path, FSDataInputStreamWrapper fsdis,
      long size, CacheConfig cacheConf, HFileSystem hfs, Configuration conf) throws IOException {
    FixedFileTrailer trailer = null;
    try {
      boolean isHBaseChecksum = fsdis.shouldUseHBaseChecksum();
      assert !isHBaseChecksum;
      // 1. Reads Trailer file from the given file.
      trailer = FixedFileTrailer.readFromStream(fsdis.getStream(isHBaseChecksum), size);
      // 2. get HFile Version（V2 or V3） and use specific HFileReader to parse HFile.
      switch (trailer.getMajorVersion()) {
      case 2:
        return new HFileReaderV2(path, trailer, fsdis, size, cacheConf, hfs, conf);
      case 3 :
        return new HFileReaderV3(path, trailer, fsdis, size, cacheConf, hfs, conf);
      default:
        throw new IllegalArgumentException("Invalid HFile version " + trailer.getMajorVersion());
      }
    } catch (Throwable t) {
      try {
        fsdis.close();
      } catch (Throwable t2) {
        LOG.warn("Error closing fsdis FSDataInputStreamWrapper", t2);
      }
      throw new CorruptHFileException("Problem reading HFile Trailer from file " + path, t);
    }
  }
}
```

根据Trailer中起始偏移地址``LoadOnOpenDataOffset``和结束偏移量（fileSize - trailerSize）将``Load-on-open``加载进内存，读取其中的Root Index和FileInfo。

```java
package org.apache.hadoop.hbase.io.hfile;

/**
 * Reader for V2.
 * HFileReaderV2 extends AbstractHFileReader
 * HFileReaderV3 extends HFileReaderV2
 */
public class HFileReaderV2 extends AbstractHFileReader {
  
  /** Opens a HFile. Load the index .*/
  public HFileReaderV2(final Path path, final FixedFileTrailer trailer,
      final FSDataInputStreamWrapper fsdis, final long size, final CacheConfig cacheConf,
      final HFileSystem hfs, final Configuration conf) throws IOException {
    super(path, trailer, size, cacheConf, hfs, conf);
    ...

    // Comparator class name is stored in the trailer in version 2.
    comparator = trailer.createComparator();
    
    // 3. Parse load-on-open data.
    this.hfileContext = createHFileContext(fsdis, fileSize, hfs, path, trailer);
    HFileBlock.FSReaderV2 fsBlockReaderV2 = new HFileBlock.FSReaderV2(fsdis, fileSize, hfs, path,
        hfileContext);
    HFileBlock.BlockIterator blockIter = fsBlockReaderV2.blockRange(
        trailer.getLoadOnOpenDataOffset(),
        fileSize - trailer.getTrailerSize());

    // 3.1 Read Data index.
    dataBlockIndexReader = new HFileBlockIndex.BlockIndexReader(comparator,
        trailer.getNumDataIndexLevels(), this);
    dataBlockIndexReader.readMultiLevelIndexRoot(
        blockIter.nextBlockWithBlockType(BlockType.ROOT_INDEX),
        trailer.getDataIndexCount());

    // 3.2 Read Meta index.
    metaBlockIndexReader = new HFileBlockIndex.BlockIndexReader(
        KeyValue.RAW_COMPARATOR, 1);
    metaBlockIndexReader.readRootIndex(
        blockIter.nextBlockWithBlockType(BlockType.ROOT_INDEX),
        trailer.getMetaIndexCount());

    // 3.3 Read File info.
    fileInfo = new FileInfo();
    fileInfo.read(blockIter.nextBlockWithBlockType(BlockType.FILE_INFO).getByteStream());
    //fileInfo.get(lastKey, avgKeyLen, avgValueLen, keyValueFormatVersion)
    ...

    // 3.4 Read data block encoding algorithm name from file info.
    dataBlockEncoder = HFileDataBlockEncoderImpl.createFromFileInfo(fileInfo);
    fsBlockReaderV2.setDataBlockEncoder(dataBlockEncoder);
  }
}
```


### HFile 写










### Bloom Filter

布隆过滤器由布隆1970年提出的用于检索一个元素是否在一个集合内，该算法优化了时间和空间，但是存在一定的错误率（可能将不属于某集合的元素判断为属于）；HBase中Bloom Filter通过快速判断Rowkey是否在某个HFile中可以避免扫描大部分的Block，减少实际IO次数，提高随机读效率。

Bloom Block中存储着位数组，KeyValue写入HFile时经过几个Hash函数映射到位数组中将对应位置0改成1，随机请求时同样进行Hash映射，如果对应位数组存在0，说明请求的数据不在该HFile中；当``HFile ⬆ - Data Block ⬆ - KeyValue ⬆ - 映射入位数组的Rowkey ⬆ - 位数组 ⬆ - Bloom Block ⬆``，因此一个HFile需要多个Bloom Block和一个Bloom index，根据Rowkey拆分，一段连续Rowkey对应一个位数组，并将对应信息保存在Bloom index中，下次随机查询时根据Rowkey查询内存中的Bloom index定位到Bloom Block，再将该Bloom Block加载进内存进行过滤。



### 配置参数

hfile.data.block.size（默认64K）:同样的数据量，数据块越小，数据块越多，索引块相应的也就越多，索引层级就越深

hfile.index.block.max.size(默认128K)：控制索引块的大小，索引块越小，需要的索引块越多，索引的层级越深

## Versions
The maximum number of versions to store for a given column is part of the column schema and is specified at table creation, or via an alter command, via HColumnDescriptor.DEFAULT_VERSIONS. 
Prior to HBase 0.96-> 3, but in 0.96 and newer has been changed to 1.
Starting with 0.98.2, you can setting ``hbase.column.max.version`` in hbase-site.xml. 

### 索引

HFile中根据索引层级分成两种: 单层索引``single-level``（如:Bloom index）和多级索引``mutil-level``；V2中引入多级索引，因为随着HFile中Data Block越来越多，无法将随之增大的索引数据全部加载进内存，多级索引确保加载部分索引节省内存使用空间，

随着数据量增多，Data Block index由开始的一层（``Root index -> 实际数据块``）变成两层（``Root index -> Leaf index -> 实际数据块``）；数据持续增多，又变成三层（``Root index -> Intermediate index -> Leaf index -> 实际数据块``）。
