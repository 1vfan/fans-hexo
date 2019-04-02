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
        <td>元数据块</td>
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

### HFile读写

数据从memstore flushing到HFile的同时，在内存中记录数据索引及Bloom等信息，待数据完全刷盘完成后，索引等信息也在内存中建立完毕并追加写入HFile；从HFile读取数据时（索引等在文件尾部，如何快速定位数据），原来加载文件后是从后往前读，首先根据具体Version获取固定长度``Trailer``，然后解析``Trailer``并加载到内存，最后加载``Load-on-open``区域的数据，具体如下：

1. 首先读取``Trailer``中的Version信息，根据不同的版本(V1/V2/V3)决定使用不同的Reader对象读取解析HFile；

2. 然后根据Version信息获取Trailer的长度（不同version的Trailer长度不同），根据Trailer长度加载整个Trailer；

3. 最后加载``Load-on-open``部分到内存中，起始偏移地址是Trailer中的``LoadOnOpenDataOffset``字段，``Load-on-open``部分的结束偏移量=HFile总长度-Trailer长度，``Load-on-open``部分主要包括Root Index和FileInfo。


### Bloom Filter

布隆过滤器由布隆1970年提出的用于检索一个元素是否在一个集合内，该算法优化了时间和空间，但是存在一定的错误率（可能将不属于某集合的元素判断为属于）；HBase中Bloom Filter通过快速判断Rowkey是否在某个HFile中可以避免扫描大部分的Block，减少实际IO次数，提高随机读效率。

Bloom Block中存储着位数组，KeyValue写入HFile时经过几个Hash函数映射到位数组中将对应位置0改成1，随机请求时同样进行Hash映射，如果对应位数组存在0，说明请求的数据不在该HFile中；当``HFile ⬆ - Data Block ⬆ - KeyValue ⬆ - 映射入位数组的Rowkey ⬆ - 位数组 ⬆ - Bloom Block ⬆``，因此一个HFile需要多个Bloom Block和一个Bloom index，根据Rowkey拆分，一段连续Rowkey对应一个位数组，并将对应信息保存在Bloom index中，下次随机查询时根据Rowkey查询内存中的Bloom index定位到Bloom Block，再将该Bloom Block加载进内存进行过滤。



### 配置参数

hfile.data.block.size（默认64K）:同样的数据量，数据块越小，数据块越多，索引块相应的也就越多，索引层级就越深

hfile.index.block.max.size(默认128K)：控制索引块的大小，索引块越小，需要的索引块越多，索引的层级越深



### 索引

HFile中根据索引层级分成两种: 单层索引``single-level``（如:Bloom index）和多级索引``mutil-level``；V2中引入多级索引，因为随着HFile中Data Block越来越多，无法将随之增大的索引数据全部加载进内存，多级索引确保加载部分索引节省内存使用空间，

随着数据量增多，Data Block index由开始的一层（``Root index -> 实际数据块``）变成两层（``Root index -> Leaf index -> 实际数据块``）；数据持续增多，又变成三层（``Root index -> Intermediate index -> Leaf index -> 实际数据块``）。
