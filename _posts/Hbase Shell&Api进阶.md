
# Java api

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

## create

```bash
###create table, {family}, {family}, ...
hbase(main)> create 'bgis_track', {NAME=>'track_info', VERSIONS=>1} 
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

## scan

```bash
hbase(main)> scan 'bgis_track'
###LIMIT必须大写
hbase(main)> scan 'bgis_track', {LIMIT => 10}
```