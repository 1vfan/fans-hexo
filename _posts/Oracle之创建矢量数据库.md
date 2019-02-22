---
title: Oracle创建矢量数据库
date: 2017-03-24 16:20:30
tags:
- Oracle
- ArcCatalog
categories: 
- GIS
---
Oracle11g 中创建矢量数据库及需要注意的问题

<!--more-->

# sde数据库创建

无需提前创建用户sde，使用ArcCatalog工具

```
Catalog Tree
Toolboxes
System Toolboxes
Data Management Tools.tbx
Geodatabase Administration
Create Enterprise Geodatabase

Database Platform : Oracle
Instance          : Oracle Server IP/orcl
Database Administrator : sys
Database Administrator Password : system
Geodatabase Administrator : sde
Geodatabase Administrator Password : sde
Tablespace Name   : 不用填，系统会创建默认表空间名
Autorization File : .../arcgisproduct.ecp
```

在创建的过程中若出现以下错误，需要重启ArcCatalog和ArcMap等工具

```bash
Error (-51) DBMS error code : 4043
ORA-04043: 对象 INSTANCES_UTIL不存在
```

# ArcCatalog工具直连Oracle

```
打开ArcCatalog工具，双击Add Database Connection

Database Platform : Oracle
Instance          : Oracle Server IP/orcl
User name         : sde
Password          : sde
```

# ST_Geometry配置监听

## 拷贝st_shapelib.dll

```
拷贝文件st_shapelib.dll 到 oraclehome\bin 和 oraclehome\lib 目录下
st_shapelib.dll目录 : arcgis\desktop10.2\DatabaseSupport\Oracle\Window64\st_shapelib.dll
oracle bin home : D:\app\Administrator\product\11.2.0\dbhome_1\BIN
oracle lib home : D:\app\Administrator\product\11.2.0\dbhome_1\LIB
```
## 配置extproc.ora

```
extproc.ora home : D:\app\Administrator\product\11.2.0\dbhome_1\hs\admin\extproc.ora
将其中的 SET EXTPROC_DLLS= 修改成 SETPROC_DLLS=ANY
```

## 数据库配置st_shapelib.dll

```
login PL\SQL developer
Username : sde
Password : sde

create or replace library st_shapelib as
'D:\app\Administrator\product\11.2.0\dbhome_1\BIN\st_shapelib.dll';
alter package sde.st_geometry_shapelib_pkg compile reuse setting;

重启Oracle监听
```

# 修改表空间

> 防止出现表空间不足的问题

```
login PL\SQL developer
Username : system
Password : system
Connect as : sysdba

alter database datafile 'D:\APP\ADMINISTRATOR\PRODUCT\11.2.0\DBHOME_1\DATABASE\SDE_TBS'
autoextend on next 50M maxsize unlimited
```

# ArcGIS的Oracle空间数据库如何释放表锁定

> 创建存储过程，然后双击执行

```
CREATE OR REPLACE PROCEDURE P_UNLOCK_SDE_TABLES(OPMSG OUT VARCHAR2) IS
SYS_REF_CUR SYS_REFCURSOR;
DEL_SDE_ID NUMBER;
BEGIN
	OPMSG:='DELETE SDE IDS:';
	OPEN SYS_REF_CUR FOR SELECT DISTINCT SDE_ID FROM TABLE_LOCKS;
	LOOP
		FETCH SYS_REF_CUR INTO DEL_SDE_ID;
		EXIT WHEN SYS_REF_CUR%NOTFOUND;
		OPMSG:=OPMSG || TO_CHAR(DEL_SDE_ID);
		BEGIN
			LOCK_UTIL.DELETE_TABLE_LOCKS_BY_SDE_ID(DEL_SDE_ID);
		END;
	END LOOP;
EXCEPTION
	WHEN OTHERS THEN
		OPMSG:= 'P_UNLOCK_SDE_TABLES ERROR:' || SUBSTR(SQLERRM,1,500);

END P_UNLOCK_SDE_TABLES;
```