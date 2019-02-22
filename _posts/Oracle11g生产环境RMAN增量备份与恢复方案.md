---
title: Oracle11g生产环境RMAN增量备份与恢复方案
date: 2017-05-22 19:43:01
tags:
- Oracle
- RMAN
categories: 
- 数据库
---

记录生产环境中使用RMAN在nocatalog方式下定时全量+增量备份数据库方案

<!--more-->

# 前期准备

生产环境Oracle安装路径是D:\product\11.2.0\dbhome_1\

## 需要备份的文件

我们需要备份的文件包括：参数文件、数据文件、控制文件、归档日志文件

口令文件：没有必要备份（可以通过命令重新创建口令文件）

redo日志文件：RMAN方式无法备份


## 更改用户密码
```bash
SQL> conn sys/tiger as sysdba;
已连接。
SQL> alter user sys identified by system;
用户已更改。
SQL> conn sys/tiger as sysdba;
ERROR:
ORA-01031: insufficient privileges
警告: 您不再连接到 ORACLE。

SQL> conn sys/system as sysdba;
已连接。
```

## 用户权限

如果system不是sysdba，可以授权

```bash
C:\Users\lf>sqlplus /nolog

SQL*Plus: Release 11.2.0.1.0 Production on 星期一 8月 28 10:33:05 2017
Copyright (c) 1982, 2010, Oracle.  All rights reserved.

SQL> conn system/system as sysdba;
ERROR:
ORA-01031: insufficient privileges
警告: 您不再连接到 ORACLE。

SQL> conn sys/system as sysdba;
已连接。

SQL> grant sysdba to system;
授权成功。

SQL> conn system/system as sysdba;
已连接。
```

## RMAN连接

```bash
C:\Users\lf>rman nocatalog
恢复管理器: Release 11.2.0.1.0 - Production on 星期日 8月 27 17:27:11 2017
Copyright (c) 1982, 2009, Oracle and/or its affiliates.  All rights reserved.

RMAN> connect target /
RMAN-00571: ===========================================================
RMAN-00569: =============== ERROR MESSAGE STACK FOLLOWS ===============
RMAN-00571: ===========================================================
ORA-01031: insufficient privileges

RMAN> connect target system/system@orcl
连接到目标数据库: ORCL (DBID=1448509947)
使用目标数据库控制文件替代恢复目录
```

如果报异常：connected to target database (not started)；说明数据库没有启动，那么我们可以在RMAN中直接启动数据库

```bash
RMAN> startup
Oracle instance started 
database mounted
database opened
.......

OK启动完成之后启动listener
RMAN> lsnrctl start
没有错误信息就可以通过RMAN> connect target system/system@orcl连接orcl了
```

show all的内容代表backup database命令的缺省参数，可以带如下参数，若缺省则使用如下default.

```bash
RMAN> show all;
db_unique_name 为 ORCL 的数据库的 RMAN 配置参数为:
CONFIGURE RETENTION POLICY TO REDUNDANCY 1; # default
CONFIGURE BACKUP OPTIMIZATION OFF; # default
CONFIGURE DEFAULT DEVICE TYPE TO DISK; # default
CONFIGURE CONTROLFILE AUTOBACKUP OFF; # default
CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '%F'; # default
CONFIGURE DEVICE TYPE DISK PARALLELISM 1 BACKUP TYPE TO BACKUPSET; # default
CONFIGURE DATAFILE BACKUP COPIES FOR DEVICE TYPE DISK TO 1; # default
CONFIGURE ARCHIVELOG BACKUP COPIES FOR DEVICE TYPE DISK TO 1; # default
CONFIGURE MAXSETSIZE TO UNLIMITED; # default
CONFIGURE ENCRYPTION FOR DATABASE OFF; # default
CONFIGURE ENCRYPTION ALGORITHM 'AES128'; # default
CONFIGURE COMPRESSION ALGORITHM 'BASIC' AS OF RELEASE 'DEFAULT' OPTIMIZE FOR LOAD TRUE ; # default
CONFIGURE ARCHIVELOG DELETION POLICY TO NONE; # default
CONFIGURE SNAPSHOT CONTROLFILE NAME TO 'D:\PRODUCT\11.2.0\DBHOME_1\DATABASE\SNCFORCL.ORA'; # default
```

由于nocatalog方式下，备份信息都在controlfile文件中，一旦controlfile丢失，将无法进行RMAN恢复.

show all之后发现CONFIGURE CONTROLFILE AUTOBACKUP OFF; 缺省是off（不会自动备份控制文件和spfile），通过命令修改成on之后会自动备份controlfile和spfile

```bash
RMAN> configure controlfile autobackup on;
新的 RMAN 配置参数:
CONFIGURE CONTROLFILE AUTOBACKUP ON;
已成功存储新的 RMAN 配置参数

RMAN> show all;
db_unique_name 为 ORCL 的数据库的 RMAN 配置参数为:
......
CONFIGURE CONTROLFILE AUTOBACKUP ON;
......
```

## 归档日志文件

如果只是单纯的backup database命令，备份文件中包括：参数文件、数据文件、控制文件，没有备份归档日志文件（archivelog）.

我们需要添加一些属性以完成归档日志的备份，delete input 可加可不加，加上的作用是在备份完成之后将归档日志文件删除，释放存储空间.

```bash
backup database plus archivelog delete input；
```

在加上备份archivelog的时候发现异常（ORA-19602: 无法按 NOARCHIVELOG 模式备份或复制活动文件），所以我们需要先启用数据库服务器自动归档

```bash
SQL> connect system/system as sysdba;
已连接。

SQL> shutdown immediate;
数据库已经关闭。
已经卸载数据库。
ORACLE 例程已经关闭。

SQL> startup mount;
ORACLE 例程已经启动。
Total System Global Area 3390558208 bytes
Fixed Size                  2180464 bytes
Variable Size            1728055952 bytes
Database Buffers         1644167168 bytes
Redo Buffers               16154624 bytes
数据库装载完毕。

SQL> alter database archivelog;
数据库已更改。

SQL> alter database open;
数据库已更改。

SQL> alter system archive log start;
系统已更改。
```

# 备份

## 备份方案

优势在于：1.占用存储空间少；2.做RMAN恢复时用到的备份集少.

```bash
备份1次全量 - level 0 backup performed
每月1号增量 - level 1 backup performed
```

## 归档后全量备份

```bash
新建目录 D:\BACKUP\ 

RMAN> run {
allocate channel c1 type disk;
backup
incremental level 0
format "D:\BACKUP\full0_%T_%u.dmp"
tag full_backup0
database
plus archivelog delete input;
release channel c1;
}

分配的通道: c1
通道 c1: SID=71 设备类型=DISK

启动 backup 于 27-8月 -17
当前日志已存档
通道 c1: 正在启动归档日志备份集
通道 c1: 正在指定备份集内的归档日志
输入归档日志线程=1 序列=1733 RECID=1 STAMP=953149873
通道 c1: 正在启动段 1 于 27-8月 -17
通道 c1: 已完成段 1 于 27-8月 -17
段句柄=D:\BACKUP\FULL0_0BSCVQDH_20170827.DMP 标记=MONDAY_INC0 注释=NONE
通道 c1: 备份集已完成, 经过时间:00:00:01
通道 c1: 正在删除归档日志
归档日志文件名=D:\FLASH_RECOVERY_AREA\ORCL\ARCHIVELOG\2017_08_27\O1_MF_1_1733_DT5DKJHR_.ARC RECID=1 STAMP=953149873
完成 backup 于 27-8月 -17

启动 backup 于 27-8月 -17
通道 c1: 正在启动增量级别 0 数据文件备份集
通道 c1: 正在指定备份集内的数据文件
输入数据文件: 文件号=00006 名称=D:\ORADATA\ORCL\BGIS_SDE.DBF
输入数据文件: 文件号=00003 名称=D:\ORADATA\ORCL\UNDOTBS01.DBF
输入数据文件: 文件号=00001 名称=D:\ORADATA\ORCL\SYSTEM01.DBF
输入数据文件: 文件号=00002 名称=D:\ORADATA\ORCL\SYSAUX01.DBF
输入数据文件: 文件号=00005 名称=D:\ORADATA\ORCL\EXAMPLE01.DBF
输入数据文件: 文件号=00004 名称=D:\ORADATA\ORCL\USERS01.DBF
通道 c1: 正在启动段 1 于 27-8月 -17
通道 c1: 已完成段 1 于 27-8月 -17
段句柄=D:\BACKUP\FULL0_0CSCVQDJ_20170827.DMP 标记=MONDAY_INC0 注释=NONE
通道 c1: 备份集已完成, 经过时间:00:21:55
通道 c1: 正在启动增量级别 0 数据文件备份集
通道 c1: 正在指定备份集内的数据文件
备份集内包括当前控制文件
备份集内包括当前的 SPFILE
通道 c1: 正在启动段 1 于 27-8月 -17
通道 c1: 已完成段 1 于 27-8月 -17
段句柄=D:\BACKUP\FULL0_0DSCVRMN_20170827.DMP 标记=MONDAY_INC0 注释=NONE
通道 c1: 备份集已完成, 经过时间:00:00:01
完成 backup 于 27-8月 -17

启动 backup 于 27-8月 -17
当前日志已存档
通道 c1: 正在启动归档日志备份集
通道 c1: 正在指定备份集内的归档日志
输入归档日志线程=1 序列=1734 RECID=2 STAMP=953151194
通道 c1: 正在启动段 1 于 27-8月 -17
通道 c1: 已完成段 1 于 27-8月 -17
段句柄=D:\BACKUP\FULL0_0ESCVRMQ_20170827.DMP 标记=MONDAY_INC0 注释=NONE
通道 c1: 备份集已完成, 经过时间:00:00:01
通道 c1: 正在删除归档日志
归档日志文件名=D:\FLASH_RECOVERY_AREA\ORCL\ARCHIVELOG\2017_08_27\O1_MF_1_1734_DT5FTST4_.ARC RECID=2 STAMP=953151194
完成 backup 于 27-8月 -17

释放的通道: c1
```

## 归档后增量备份

```bash
run {
allocate channel c1 type disk;
backup
incremental level 1
format "D:\BACKUP\incr1_%T_%u.dmp"
tag incr_backup1
database
plus archivelog delete input;
release channel c1;
}

分配的通道: c1
通道 c1: SID=71 设备类型=DISK

启动 backup 于 27-8月 -17
通道 c1: 正在启动增量级别 1 数据文件备份集
通道 c1: 正在指定备份集内的数据文件
输入数据文件: 文件号=00006 名称=D:\ORADATA\ORCL\BGIS_SDE.DBF
输入数据文件: 文件号=00003 名称=D:\ORADATA\ORCL\UNDOTBS01.DBF
输入数据文件: 文件号=00001 名称=D:\ORADATA\ORCL\SYSTEM01.DBF
输入数据文件: 文件号=00002 名称=D:\ORADATA\ORCL\SYSAUX01.DBF
输入数据文件: 文件号=00005 名称=D:\ORADATA\ORCL\EXAMPLE01.DBF
输入数据文件: 文件号=00004 名称=D:\ORADATA\ORCL\USERS01.DBF
通道 c1: 正在启动段 1 于 27-8月 -17
通道 c1: 已完成段 1 于 27-8月 -17
段句柄=D:\BACKUP\INCR1_0FSCVTAD_20170827.DMP 标记=MONDAY_INC1 注释=NONE
通道 c1: 备份集已完成, 经过时间:00:07:25
通道 c1: 正在启动增量级别 1 数据文件备份集
通道 c1: 正在指定备份集内的数据文件
备份集内包括当前控制文件
备份集内包括当前的 SPFILE
通道 c1: 正在启动段 1 于 27-8月 -17
通道 c1: 已完成段 1 于 27-8月 -17
段句柄=D:\BACKUP\INCR1_0GSCVTOA_20170827.DMP 标记=MONDAY_INC1 注释=NONE
通道 c1: 备份集已完成, 经过时间:00:00:01
完成 backup 于 27-8月 -17

释放的通道: c1
```

## 全量与增量备份比较

全量：
```bash
    数据文件：>28G
    归档日志文件：20M
    控制文件、spfile：10M
    花费时间：约30分钟
```

增量：
```bash
    数据文件：<10M
    归档日志文件：<3M 
    控制文件、spfile：10M
    花费时间：<10分钟
```

## 备份列表查看与删除

```bash
查看所有：
list backup;
list backupset;

查看归档日志文件：
RMAN> list backup of archivelog all;

查看spfile：
RMAN> list backup of spfile;

查看控制文件：
RMAN> list backup of controlfile;

查看数据文件：
RMAN> list backup of database;

可以根据list的BS对应的ID删除备份：
delete backupset 3;
delete backupset 5;
```

# RMAN恢复

## 恢复一之口令文件

口令文件丢失不属于RMAN备份与恢复的范畴，只需通过命令重建口令文件就行

```bash
orapwd file=PWDorcl.ora password=pass123456 entries=5（代表最多可以创建5个DBA）
```

测试环境路径下（D:\product\11.2.0\dbhome_1\database\PWDorcl.ora），生产环境安装路径可能不同.

## 恢复二之spfile文件 

如果spfile文件丢失损坏，需要database处在nomount状态下执行restore操作

```bash
先在nomount模式下启动实例
RMAN> startup nomount;
RMAN> set dbid 1448509947;（之前连接时记住）
RMAN> restore spfile from autobackup;
```

如果报错，则需要指定spfile备份的绝对路径

```bash
查看原始spfile路径：
SQL> show parameter spfile;
NAME                                 TYPE                   VALUE
------------------------------------ ---------------------- ------------------------------
spfile                               string                 D:\PRODUCT\11.2.0\DBHOME_1\DATABASE\SPFILEORCL.ORA

查看备份的spfile文件路径：
RMAN> list backup of spfile;
BS 关键字  类型 LV 大小       设备类型 经过时间 完成时间
------- ---- -- ---------- ----------- ------------ ----------
10      Full    9.64M      DISK        00:00:01     28-8月 -17
        BP 关键字: 10   状态: AVAILABLE  已压缩: NO  标记: TAG20170828T093102
段名:D:\FLASH_RECOVERY_AREA\ORCL\AUTOBACKUP\2017_08_28\O1_MF_S_953199062_DT6WLQ2G_.BKP
  包含的 SPFILE: 修改时间: 27-8月 -17
  SPFILE db_unique_name: ORCL

恢复：
RMAN> restore spfile to 'D:\PRODUCT\11.2.0\DBHOME_1\DATABASE\SPFILEORCL.ORA' 
from 'D:\FLASH_RECOVERY_AREA\ORCL\AUTOBACKUP\2017_08_28\O1_MF_S_953199062_DT6WLQ2G_.BKP';
```

然后重启
```bash
RMAN> shutdown immediate;
RMAN> startup;
（若无法启动执行以下命令再启动:
RMAN> set dbid 1448509947;
RMAN> startup;
）
```

## 恢复三之controlfile文件 

controlfile控制文件丢失损坏，同样需要database处在nomount状态下执行restore操作

```bash
RMAN> startup nomount;
RMAN> restore controlfile from autobackup;
RMAN> alter database mount;
RMAN> recover database;
RMAN> alter database open resetlogs;
```

## 恢复四之redolog file文件 

在sqlplus /nolog中操作

```bash
sqlplus /nolog
SQL> conn system/system as sysdba
Connected.
SQL> shutdown immediate;
SQL> startup mount;
ORACLE instance started.
SQL> recover database until cancel;
Media recovery complte.
SQL> alter database open resetlogs;
Database altered.
```

alter database open resetlogs;执行之后会将连续的online redolog清空，需要立刻进行full database backup;否则在进行datafile恢复时会出错，可能导致数据丢失不完全恢复

## 恢复五之datafile文件 

数据文件丢失损坏

```bash
首先
RMAN> report schema;
db_unique_name 为 ORCL 的数据库的数据库方案报表
永久数据文件列表
===========================
文件大小 (MB) 表空间           回退段数据文件名称
---- -------- -------------------- ------- ------------------------
1    700      SYSTEM               ***     D:\ORADATA\ORCL\SYSTEM01.DBF
2    610      SYSAUX               ***     D:\ORADATA\ORCL\SYSAUX01.DBF
3    1635     UNDOTBS1             ***     D:\ORADATA\ORCL\UNDOTBS01.DBF
4    5        USERS                ***     D:\ORADATA\ORCL\USERS01.DBF
5    100      EXAMPLE              ***     D:\ORADATA\ORCL\EXAMPLE01.DBF
6    29696    BGIS_SDE             ***     D:\ORADATA\ORCL\BGIS_SDE.DBF

假设恢复File 6 BGIS_SDE：
RMAN> sql "alter database datafile 6 offline";
RMAN> restore datafile 6
RMAN> recover datafile 6
RMAN> sql "alter database datafile 6 online";
```

## 恢复六之database

当数据库出现问题，恢复所有库的时候不用带参数，直接恢复restore database就可以;

### 非catalog完全恢复

```bash
RMAN> start momount;
RMAN> restore controlfile from autobackup;
RMAN> alter database mount;
RMAN> restore database;
RMAN> recover database;
RMAN> alter database open resetlogs;
```

### 基于时间点的恢复

```bash
RMAN> run{
set until time "to_date('08/28/17 00:00:00','mm/dd/yy' hh24:mi:ss')"
restore database;
recover database;
alter database open resetlogs;
}
```

# linux实现典型增量备份方案

## 备份方案

```bash
星期日 - level 0 backup performed
星期一 - level 2 backup performed
星期二 - level 2 backup performed
星期三 - level 1 backup performed
星期四 - level 2 backup performed
星期五 - level 2 backup performed
星期六 - level 2 backup performed
```

## 备份脚本

bakl0.sh、bakl1.sh、bakl2.sh

```bash
bakl0：
# cd /u01/rmanbak/
# mkdir script
# cd script/
# vi bakl0.sh
run {
allocate channel cha1 type disk;
backup
incremental level 0
format "/rman/bakckup/full0_%T_%u"
tag backup_full0
database
plus archivelog delete input;
release channel cha1;
}

# vi bakl1.sh
run {
allocate channel cha1 type disk;
backup
incremental level 1
format "/rman/backup/incr1_%T_%u"
tag backup_incr1
database
plus archivelog delete input;
release channel cha1;
}

# vi bakl2.sh
run {
allocate channel cha1 type disk;
backup
incremental level 2
format "/rman/backup/incr2_%T_%u"
tag backup_incr2
database
plus archivelog delete input;
release channel cha1;
}
```

## 定时任务

一般使用corntab作为linux定时任务的

待完善

```bash
rman target / msglog=bakl0.log cmdfile=bakl0.sh
rman target / msglog=bakl1.log cmdfile=bakl1.sh
rman target / msglog=bakl2.log cmdfile=bakl2.sh
```
