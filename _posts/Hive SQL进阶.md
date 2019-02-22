## 新增空映射字段

status、reserve作为预留字段，对应Hbase表中并没有这两个字段，当以后Hbase中新增了这些字段，Hive表中便能通过映射查询到对应的数据.

```sql
beeline -u jdbc:hive2://hostname:10000/default  --maxWidth=10000
show tables;
show create table bgis_track;
drop table bgis_track;

create external table bgis_track(
    rowkey string,
    recipientUserId string,
    status string,
    reserve string
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.hbase.HBaseSerDe' STORED BY 'org.apache.hadoop.hive.hbase.HBaseStorageHandler'
WITH SERDEPROPERTIES(
    'hbase.columns.mapping'=':key,track_info:recipientUserId,track_info:status,track_info:reserve'
)
TBLPROPERTIES(
    'hbase.table.name'='bgis_track'
);

desc bgis_track;
!q
```

# Hive导出数据

如果取出的数据就存储在当前登陆的本地服务器上，可以使用 ``local directory`` 直接将数据导出到本地目录；但是使用 ``beeline -u jdbc:hive2://RemoteServer:10000/database -e`` 连接的是远程Hive库，则必须先将数据导入到HDFS，然后从HDFS导出到本地目录，因为此时的directory并不是本地路径而是远程server的文件路径.

理解错误可能会报如下错误：

```bash
Error: EXECUTION FAILED：Task MOVE error AccessControlException: Unable to copy to destination directory.
```


## 本地server导出数据

```bash
hive -e "insert overwrite local directory '/bgis/data/mileage' 
row format delimited
fields terminated by '\t'
select * from bgis_mileage;"
```


## beeline连接远程server导出数据

导出本地文件（先beeline 导入hdfs，然后hdfs dfs -get）.

注意：hadoop fs、hadoop dfs、hdfs dfs 都可以进行操作；hadoop fs 的使用面最广，可以操作所有的文件系统； hadoop dfs、hdfs dfs只能操作HDFS相关的文件.

```bash
#!/bin/bash
mkdir -p /bgis/data
###beeline将查询数据导入HDFS中，各字段以\t分隔
beeline -u jdbc:hive2://hostname:10000/database -e "insert overwrite directory '/tmp/database/mileage' row format delimited fields terminated by '\t' select * from bgis_mileage where dateTime = 20180310;"

###将数据从HDFS中取出，存入本地路径
hadoop fs -get /tmp/hive/track /bgis/data/
###将所有文件中数据重定向追加到del新文件中
cat /bgis/data/* >> /bgis/data/mileage_utf8.del
###可以修改需要的字符集格式utf8->gbk
iconv -f utf8 -t gbk /bgis/data/mileage_utf8.del > /bgis/data/mileage_gbk.del
```

```bash
# hadoop fs -ls /tmp/default/mileage
.. INFO util.KerberosUtil: Using principal pattern: HTTP/_HOST
Found 1 items
-777 3 hive hadoop 250944 ...  /tmp/default/mileage/000000_0

# hadoop fs -rm -f -r /tmp/default/mileage
```

