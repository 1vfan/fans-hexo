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