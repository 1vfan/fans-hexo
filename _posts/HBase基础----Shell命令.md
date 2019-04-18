### namespace

对表资源实现逻辑和物理文件目录的隔离，实现便捷安全管理；``namespace``同时也是一张``hbase``层级下的系统内部表。

```bash
hbase(main)> list_namespace
# hbase: 系统层级，存放hbase内部表
# default: 用户默认层级

hbase(main)> list_namespace_tables 'hbase'
# meta、namespace、snapshot

hbase(main)> create_namespace 'bgis'

hbase(main)> scan 'hbase:namespace'
# /hbase/data/hbase
# /hbase/data/default
# /hbase/data/bgis

hbase(main)> drop_namespace 'bgis'
# ERROR: Only empty namespace can be removed !
```

### table

```bash
hbase(main)> create 'bgis_test', {NAME => 'data_info', VERSIONS => 2}
# /hbase/data/default/bgis_test
hbase(main)> create 'bgis:bgis_test', {NAME => 'data_info'}, {NAME => 'meta_info', VERSIONS => 4}
# /hbase/data/bgis/bgis_test

hbase(main)> desc 'bgis:bgis_test'
# /hbase/data/bgis/bgis_test/.tabledesc/.tableinfo.0000000002

# When [hbase.online.schema.update.enable] == false, should disable -> alter -> enable.
hbase(main)> disable 'bgis:bgis_test'
# Updating all Regions with new schema !
hbase(main)> alter 'bgis:bgis_test', 'delete' => 'meta_info'
hbase(main)> alter 'bgis:bgis_test', {NAME => 'data_info', VERSIONS => 2}
hbase(main)> enable 'bgis:bgis_test'

# Table 'bgis:bgis_test' is enabled, disable it first !
hbase(main)> disable 'bgis:bgis_test'
hbase(main)> drop 'bgis:bgis_test'
```

### data

```bash
# Put table, rowkey, family:column, value
hbase(main)> put 'bgis:bgis_track', '9990002_1500000000001', 'track_info:recipientUserId', '9990002'
hbase(main)> put 'bgis:bgis_track', '9990002_1500000000001', 'track_info:recipientOrgId', '999000'
hbase(main)> put 'bgis:bgis_track', '9990002_1500000000001', 'track_info:recipientRealName', 'Stefan'

# Default fetch 1 row at a time !
hbase(main)> count 'bgis:bgis_track'
# Count fast when use right CACHE, Set CACHE lower if rows are big.
hbase(main)> count 'bgis:bgis_track', CACHE=>1000

hbase(main)> get 'bgis:bgis_track', '9990002_1500000000001'
hbase(main)> get 'bgis:bgis_track', '9990002_1500000000001', 'track_info:recipientUserId'

hbase(main)> scan 'bgis:bgis_track'
hbase(main)> scan 'bgis:bgis_track', {COLUMNS => 'track_info:recipientUserId'}
hbase(main)> scan 'bgis:bgis_track', {LIMIT => 10}

# Delete all versions value for this column
hbase(main)> delete 'bgis:bgis_track', '9990001_1500000000000', 'track_info:pinId' 
# Delete this row
hbase(main)> deleteall 'bgis:bgis_track', '9990001_1500000000000'
# Delete all table data (disable、drop、create table)
hbase(main)> truncate 'bgis:bgis_track'
```

### filter

```bash
# Rowkey which prefix = [801]
hbase(main)> scan 'bgis:bgis_test', FILTER => "PrefixFilter('801')"

# Rowkey <= [8010020_1500000000000]
hbase(main)> scan 'bgis:bgis_test', FILTER => "RowkeyFilter(<=, 'binary:8010020_1500000000000')"

# Rowkey include [8010020_]
hbase(main)> scan 'bgis:bgis_test', FILTER => "RowkeyFilter(=, 'substring:8010020_')"

# column value which include [huawei-imei-]
hbase(main)> scan 'bgis:bgis_test', FILTER => "ValueFilter(=, 'substring:huawei-imei-')"

# Column family which include [info]
hbase(main)> scan 'bgis:bgis_test', FILTER => "FamilyFilter(=, 'substring:info')"

# Scan from StartRowkey
hbase(main)> scan 'bgis:bgis_test', {STARTROW => '8010020_1500000000000', LIMIT => 100}
hbase(main)> scan 'bgis:bgis_test', {STARTROW => '8010020_1500000000000', LIMIT => 100, COLUMNS => ['track_info:lon', 'track_info:lat']}

# Scan with TimeRange, not include StopTime' data
hbase(main)> scan 'bgis:bgis_test', {TIMERANGE => [1500000000000, 1550000000001], LIMIT => 100}
hbase(main)> scan 'bgis:bgis_test', {TIMERANGE => [1500000000000, 1550000000001], LIMIT => 100, COLUMNS => ['track_info:lon', 'track_info:lat']}
```


