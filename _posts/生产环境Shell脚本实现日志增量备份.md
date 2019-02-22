---
title: Shell脚本实现日志增量备份
date: 2017-04-15 19:43:01
tags:
- Linux
- Shell
categories: 
- Shell
---

记录在生产环境中使用Shell脚本实现日志的增量备份

<!--more-->

## 创建测试目录

```bash
# cd /
# mkdir -p /home/bgis/logs
# cd /home/bgis/logs
# touch bgis-poi.log
# touch bgis-poi.log.2016-11-01
# touch bgis-poi.log.2016-11-02
# touch bgis-poi.log.2016-11-03
# touch bgis-poi.log.2016-11-04

# mkdir -p /data/backup/
# mkdir -p /data/sh/
# cd /data/sh/
# vim auto_backup_logs.sh
```

## 编辑Shell脚本

在每个星期日全量压缩备份logs后，清除带日期的log；除去星期日以外增量备份logs，依靠快照snapshot实现

```bash
#!/bin/bash
#backup logs
SOURCE_DIR=(
	$*
)
TARGET_DIR=/data/backup
YEAR=`date +%Y`
MONTH=`date +%m`
DAY=`date +%d`
WEEK=`date +%u`
A_NAME=`date +%H%M`
FILES=${A_NAME}_bgislogs_backup.tgz
CODE=$?
if
	[ -z "$*" ]; then
	echo -e "\033[32mUsage:\nPlease Enter Your Backup Files or Directories\n-----------------------------\n\nUsage: { $0 /home/bgis/logs}\033[0m"
	exit
fi
#Determine whether the Target Directory Exists
if
	[ ! -d $TARGET_DIR/$YEAR-$MONTH-$DAY ];then
	mkdir -p $TARGET_DIR/$YEAR-$MONTH-$DAY
	echo -e "\033[32mThe $TARGET_DIR Created Successfully!\033[0m"
fi
#EXEC Full_Backup Funtion Command
Full_Backup()
{
if
	[ "$WEEK" -eq "7" ];then
	rm -rf $TARGET_DIR/snapshot
	cd $TARGET_DIR/$YEAR-$MONTH-$DAY ;tar -g $TARGET_DIR/snapshot -czvf $FILES ${SOURCE_DIR[@]}
	rm -rf ${SOURCE_DIR[@]}/*.log.* ;
	[ "$CODE" == "0" ]&&echo -e "-----------------------------\n\033[32mThese Full_Backup System Files Backup successfully!\033[0m"
fi
}
#Perform incremental BACKUP Function Command
Add_Backup()
{
	if [ "$WEEK" -ne "7" ];then
	cd $TARGET_DIR/$YEAR-$MONTH-$DAY ;tar -g $TARGET_DIR/snapshot -czvf $FILES ${SOURCE_DIR[@]}
	[ "$CODE" == "0" ]&&echo -e "------------------------------\n\033[32mThese Add_Backup System Files $TARGET_DIR/$YEAR-$MONTH-$DAY/${YEAR}_$FILES Backup Successfully!\033[0m"
	fi
}
sleep 3
Full_Backup;Add_Backup
```

## 运行测试

主要测试星期日的备份，将服务器日期改成星期日测试

```bash
# cd /data/sh
# date -s 2016-11-06
2016年 11月 06日 星期日 00:00:00 CST

# sh auto_backup_logs.sh
Usage:
Please Enter Your Backup Files or Directories
-----------------------------

Usage: { auto_backup_logs.sh /home/bgis/logs}

# sh auto_backup_logs.sh /home/bgis/logs/
tar: /home/bgis/logs：目录是新的
tar: 从成员名中删除开头的“/”
/home/bgis/logs/
/home/bgis/logs/bgis-poi.log
/home/bgis/logs/bgis-poi.log.2016-11-01
/home/bgis/logs/bgis-poi.log.2016-11-02
/home/bgis/logs/bgis-poi.log.2016-11-03
/home/bgis/logs/bgis-poi.log.2016-11-04
-----------------------------
These Full_Backup System Files Backup successfully!
```

进入备份目录查看备份文件，发现特定日期的文件夹中有刚备份的时间为00:00的压缩包；同时进入日志目录，发现带有日期的日志已被清空

```bash
# ls /data/backup/
2016-11-06  snapshot
# ls 2016-11-06/
0000_bgislogs_backup.tgz

# ls /home/bgis/logs/
bgis-poi.log
```
