---
title: Oracle数据库实现定时备份
date: 2017-03-15 13:56:23
tags:
- Oracle
categories: 
- 数据库
---

记录在Windows环境中实现Oracle数据库及表的定时备份方案

<!--more-->

首先写好EXP语句封装到bat文件中，使用windows计划任务去定时执行

# 创建脚本

创建一个.bat后缀的脚本文件，待研究（在真实测试时发现time参数不起作用，log也无法生成）

* 单用户部分表备份

```bash
@echo off
echo 开始备份Oracle数据库用户sde下的部分表，请稍等.....

set "filename=backup_sde_%date:~0,4%%date:~5,2%%date:~8,2%_%time:~0,2%%time:~3,2%%time:~6,2%.dmp"
set "logname=backup_user_%date:~0,4%%date:~5,2%%date:~8,2%_%time:~0,2%%time:~3,2%%time:~6,2%.log"
EXP system/system@orcl BUFFER=64000 file=D:/OracleBackup/%filename% TABLES=(sde.ST_ATM,sde.ST_NODE)
log=D:/OracleBackup/%logname% FULL=Y buffer=65535

echo 任务完成！
```

* 多用户部分表备份

```bash
@echo off
echo 开始备份Oracle数据库用户sde和gis下的部分表，请稍等.....

set "filename_sde=backup_sde_%date:~0,4%%date:~5,2%%date:~8,2%_%time:~0,2%%time:~3,2%%time:~6,2%.dmp"
set "filename_gis=backup_gis_%date:~0,4%%date:~5,2%%date:~8,2%_%time:~0,2%%time:~3,2%%time:~6,2%.dmp"
set "logname=backup_users_%date:~0,4%%date:~5,2%%date:~8,2%_%time:~0,2%%time:~3,2%%time:~6,2%.log"
EXP system/system@orcl BUFFER=64000 file=D:/OracleBackup/%filename_sde% TABLES=(sde.ST_ATM,sde.ST_NODE)
EXP system/system@orcl BUFFER=64000 file=D:/OracleBackup/%filename_gis% TABLES=(gis.ST_XZQ,gis.ST_ZJNX)
log=D:/OracleBackup/%logname% FULL=Y buffer=65535

echo 任务完成！
```

* 用户全备份

```bash
@echo off
echo 开始备份Oracle数据库的用户sde下的表，请稍等.....

set "filename=backup_sde_%date:~0,4%%date:~5,2%%date:~8,2%_%time:~0,2%%time:~3,2%%time:~6,2%.dmp"
set "logname=backup_sde_%date:~0,4%%date:~5,2%%date:~8,2%_%time:~0,2%%time:~3,2%%time:~6,2%.log"
EXP system/system@orcl BUFFER=64000 file=D:/OracleBackup/%filename% OWNER=(sde)
log=D:/OracleBackup/%logname% FULL=Y buffer=65535

echo 任务完成！
```

* 完全备份

```bash
@echo off
echo 开始备份整个Oracle数据库orcl，请稍等.....

set "filename=backup_orcl_%date:~0,4%%date:~5,2%%date:~8,2%_%time:~0,2%%time:~3,2%%time:~6,2%.dmp"
set "logname=backup_orcl_%date:~0,4%%date:~5,2%%date:~8,2%_%time:~0,2%%time:~3,2%%time:~6,2%.log"
EXP system/system@orcl BUFFER=64000 file=D:/OracleBackup/%filename% FULL=Y
log=D:/OracleBackup/%logname% FULL=Y buffer=65535

echo 任务完成！
```

# 创建计划任务

与之前的windows版本存在较大区别，之前在控制面板中打开；笔者介绍的是windows2008 - win10的环境，是在管理工具中配置，依次打开管理、任务计划程序、创建任务，开始常规设置

![png1](/img/20170315_1.png)

触发器设置，设置执行时间和重复任务间隔

![png2](/img/20170315_2.png)

操作设置，添加执行脚本目录，注意起始于的执行目录一定要填

![png3](/img/20170315_3.png)

设置完成之后，可以在计划任务列表栏查看到

![png4](/img/20170315_4.png)

最后在配置的文件生成目录中，可以查看到每隔1分钟生成的DMP备份文件以及日志文件

