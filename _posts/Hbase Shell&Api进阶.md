
# Java api

## Version

获取多版本

```java
public static final byte[] CF = "cf".getBytes();
public static final byte[] ATTR = "attr".getBytes();
...
Get get = new Get(Bytes.toBytes("row1"));
get.setMaxVersions(3);  // will return last 3 versions of row
Result r = table.get(get);
byte[] b = r.getValue(CF, ATTR);  // returns current version of value
List<KeyValue> kv = r.getColumn(CF, ATTR);  // returns all versions of this column
```

手工指定版本号（不推荐）

```java
public static final byte[] CF = "cf".getBytes();
public static final byte[] ATTR = "attr".getBytes();
...
Put put = new Put( Bytes.toBytes(row));
long explicitTimeInMs = 555;  // just an example
put.add(CF, ATTR, explicitTimeInMs, Bytes.toBytes(data));
table.put(put);
```


## Filter

### SingleColumnValueFilter

以下代码需求是过滤获得``family:columnName.value = columnValue``的最新数据，且保留表中不存在该列的行数据.

```java
Scan scan = new Scan();
SingleColumnValueFilter filter = 
    new SingleColumnValueFilter(Bytes.toBytes("family"), "columnName".getBytes(), CompareFilter.CompareOp.EQUAL, "columnValue".getBytes());
//false:某行不存在该过滤列，则通过该行，就是过滤后数据中保留该行，默认false；设置为true则会跳过该行，就是过滤后数据中不保留该行
filter.setFilterIfMissing(false);
//true:只检查该过滤列的最新版本，默认true；设置false则会在过滤检查中包含之前版本
filter.setLatestVersionOnly(true);
scan.setFilter(filter);
```

# Hbase shell

## help

```bash
hbase(main)> help 'scan'
```

## namespace

```bash
###hbase - system namespace, used to contain HBase internal tables
###default - tables with no explicit specified namespace will automatically fall into this namespace
hbase(main)> create 'bgis:bgis_track', 'track_info'
hbase(main)> create 'bgis_track', 'track_info'
```

## create

The maximum number of versions to store for a given column is part of the column schema and is specified at table creation, or via an alter command, via HColumnDescriptor.DEFAULT_VERSIONS. 
Prior to HBase 0.96-> 3, but in 0.96 and newer has been changed to 1.
Starting with 0.98.2, you can setting ``hbase.column.max.version`` in hbase-site.xml. 

```bash
###create table, {family}, {family}, ...
hbase(main)> create 'bgis_track', {NAME=>'track_info', VERSIONS=>1} 

hbase(main)> alter 'bgis_track', NAME=>'mileage_info', VERSIONS=>3
```

## alter

取决于Hbase参数 ``hbase.online.schema.update.enable``，false需先disable table才能alter，true则不需要

```bash
hbase(main)> disable 'bgis_track'

###add or update family
hbase(main)> alter 'bgis_track', NAME=>'mileage_info', VERSIONS=>3

###delete family 任选一种
hbase(main)> alter 'bgis_track', 'delete'=>'mileage_info'
hbase(main)> alter 'bgis_track', NAME=>'mileage_info', METHOD=>'delete'

hbase(main)> enable 'bgis_track'
```

## describe

```bash
hbase(main)> describe 'bgis_track'
```

## drop

```bash
hbase(main)> disable 'bgis_track'
hbase(main)> drop 'bgis_track'
```

##delete

```bash
###delete cloumn 删除该行该列的所有版本
hbase(main)> delete 'bgis_track', '999000_1500000000000', 'track_info:pinId' 

###delete row 删除整行
hbase(main)> deleteall 'bgis_track', '999000_1500000000000'

###delete all 删除整表数据(历经disable、drop、create table)
hbase(main)> truncate 'bgis_track'
```

## put

添加一行数据只能逐列添加

```bash
###put table, rowkey, family:column, value
hbase(main)> put 'bgis_track', '999000_1500000000001', 'track_info:recipientUserId', '9990001'
hbase(main)> put 'bgis_track', '999000_1500000000001', 'track_info:recipientOrgId', '999000'
hbase(main)> put 'bgis_track', '999000_1500000000001', 'track_info:recipientRealName', 'Stefan'
```

## get

```bash
hbase(main)> get 'bgis_track', '999000_1500000000001'

hbase(main)> get 'bgis_track', '999000_1500000000001', 'track_info:recipientUserId'
```

## count

```bash
hbase(main)> count 'bgis_track'

hbase(main)> count 'bgis_track', CACHE=>1000

###It’s quite fast when configured with the right CACHE. Default is to fetch one row at a time.
###The above count fetches 1000 rows at a time. Set CACHE lower if your rows are big.
```

## scan

```bash
hbase(main)> scan 'bgis_track'
###LIMIT必须大写
hbase(main)> scan 'bgis_track', {LIMIT => 10}
```

