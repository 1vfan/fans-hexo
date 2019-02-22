---
title: Oracle11gRMAN定时全量增量备份方案及脚本
date: 2017-05-23 21:43:01
tags:
- Oracle
- RMAN
categories: 
- 数据库
---

记录使用RMAN脚本做定时任务全量、增量备份数据库方案

<!--more-->

## 前期准备

启用数据库服务器自动归档，打开SQL PLUS

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

新建Rman脚本存放目录：D:\RMAN 和 数据备份文件存放目录：D:\BACKUP

## 脚本

### 全量备份

将full_backup_orcl.bat 和 full_backup_orcl.rman脚本拷贝保存在D:/RMAN/下

full_backup_orcl.bat脚本

```bash
@echo off
echo 开始全量备份Oracle数据库，请稍等.....
rman nocatalog target system/system@orcl log D:\BACKUP\%date:~0,10%.log cmdfile=D:\BACKUP\full_back_orcl.rman
echo 任务完成！
```

full_backup_orcl.rman脚本

```bash
run {
delete noprompt obsolete;
allocate channel c1 type disk;
backup incremental level 0 
format "D:\BACKUP\full0_%T_%u.dmp" tag full_backup0
database plus archivelog delete input;
release channel c1;
}
```

### 增量备份

将incr_backup_orcl.bat 和 incr_backup_orcl.rman脚本拷贝保存在D:/RMAN/下

incr_backup_orcl.bat脚本

```bash
@echo off
echo 开始增量备份Oracle数据库，请稍等.....
rman nocatalog target system/system@orcl log D:\BACKUP\%date:~0,10%.log cmdfile=D:\BACKUP\incr_back_orcl.rman
echo 任务完成！
```

incr_backup_orcl.rman脚本

```bash
run {
delete noprompt obsolete;
allocate channel c1 type disk;
backup incremental level 1 
format "D:\BACKUP\incr1_%T_%u.dmp" tag incr_backup1
database plus archivelog delete input;
release channel c1;
}
```

## 定时备份方案

windows定时任务设置全量备份脚本 full_back_orcl.bat每月1号凌晨2点执行一次；

windows定时任务设置增量备份脚本 incr_back_orcl.bat每周日凌晨2点执行一次.
