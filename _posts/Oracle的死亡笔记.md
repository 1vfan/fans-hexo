---
title: Oracle的死亡笔记
date: 2017-02-18 10:20:30
tags:
- Oracle
- DeathNote
categories: 
- 数据库
---
记录Oracle11g 常用开发技能

<!--more-->

# 数据库版本

```sql
select * from v$version;
```

# number类型主键实现序列自增长

seq_abc是自己定义的序列名称，maxvalue是序列增长的最大值，tri_abc是自己定义的触发器名称，T_abc是表名，ID是主键名

```sql
create sequence seq_abc start with 1 increment by 1 minvalue 1 maxvalue 10000 nocache;
create or replace trigger tri_abc before insert on T_abc for each row begin
select seq_abc.nextval into:new.ID from sys.dual;
end;
```

# 修改用户密码

```sql
alter user system（用户） identified by system（新密码）；
```

避免出现密码过期问题解决方案

```sql
select username,profile from dba_users;
select * from dba_profiles s where s.profile = 'DEFAULT' and resource_name = 'PASSWORD_LIFE_TIME';

alter profile default limit PASSWORD_LIFE_TIME unlimited;
alter user sde identified by sde;
```


# 查看触发器

查看某个表上的触发器

```sql
select * from all_triggers WHERE table_name='表名'
```

# oracle逻辑备份三种模式

## 表模式之EXP

```sql
EXP system/system BUFFER=64000 FILE=E:\DATA\T_TABLE.DMP OWNER=BGIS TABLES=(T_A,T_B,T_C)
IMP system/system BUFFER=64000 FILE=E:\DATA\T_TABLE.DMP FROMUSER=BGIS TOUSER=BGIS TABLES=(T_A,T_B,T_C)
```

报错信息

```sql
EXP-00026:指定了冲突模式
EXP-00000:导出终止失败
```

解决方法&nbsp;&nbsp;:&nbsp;&nbsp;这里只指定了三个参数，感觉应该是OWNER和TABLES参数有冲突，对EXP命令进行以下修改

```sql
EXP system/system BUFFER=64000 FILE=E:\DATA\BGISBSLOCATION_TABLE.DMP TABLES=(BGIS.T_A,BGIS.T_B,BGIS.T_C)
```

## 表模式之IMP

```sql
IMP system/system BUFFER=64000 FILE=E:\DATA\T_TABLE.DMP FROMUSER=BGIS TOUSER=BGIS TABLES=(T_A,T_B,T_C)
```

报错信息

```sql
IMP-00058:遇到ORACLE 错误 12560
ORA-12560:TNS：协议适配器错误
IMP-00000:未成功终止导入
```

解决方法&nbsp;&nbsp;:&nbsp;&nbsp;加了database的SID(user/pwd@SID)就解决了，对IMP命令进行以下修改

```sql
IMP system/system@ORCL BUFFER=64000 FILE=E:\DATA\T_TABLE.DMP FROMUSER=BGIS TOUSER=BGIS TABLES=(T_A,T_B,T_C)
```

## 用户模式

```sql
EXP system/system BUFFER=64000 FILE=E:\DATA\T_USER.DMP OWNER=(BGIS)
IMP system/system BUFFER=64000 FILE=E:\DATA\T_USER.DMP FROMUSER=BGIS TOUSER=BGIS
```

## 完全模式

```sql
EXP system/system BUFFER=64000 FILE=E:\DATA\T_FULL.DMP FULL=Y
IMP system/system BUFFER=64000 FILE=E:\DATA\T_FULL.DMP FULL=Y
```

# PL/sql导出存储过程

导出步骤

```bash
Tools
Export User Objects...
选择需要导出的package包、type自定义类型、procedure储存过程、function函数、trigger触发器、sequence序列
table表
Export
```

![png1](/img/20170314_1.png)

# PL/sql导入储存过程

导入步骤

```bash
Tools
Import Tables
选择标签页SQL Inserts
在Import File中选择Sql文件位置
Import
```

# 查询shape表(point,poly)不相交点

ST_INTERSECTS(point,poly) = 0的效率相当低 (= 0 代表不相交 = 1 代表相交) 

```sql
SELECT * FROM T_AAA WHERE OBJECTID NOT IN (SELECT T1.OBJECTID FROM T_AAA T1 JOIN T_BBB T2 ON SDE.ST_INTERSECTS(T1.SHAPE,T2.SHAPE) = 1)
``` 

# ORA错误

## ORA-12516

ORA-12516 : "TNS监听程序找不到符合协议堆栈要求的可用处理程序" 

```bash
session连接数限制 或 连接不稳定

重启数据库监听Listener和数据库ORCL
使用原密码登陆PL\SQL
在弹出框中输入新密码
```

## ORA-12514

ORA-12514 : "TNS监听程序当前无法识别连接描述符中请求的服务"

先检测监听服务的端口是否正确，然后重启监听和服务


# 函数

```sql
update T_AAA t set t.FEATUREGUID = sys_guid(); 
```

# 表空间用户权限

```sql
--表空间
create tablespace SDE_TBS datafile 'D:\OracleData\SDE__TBS.DBF'
size 1000M autoextend on next 50M maxsize unlimited;

--用户
create user sde identified by sde default tablespace SDE_TBS
temporary tablespace TEMP profile DEFAULT quota unlimited on SDE_TBS;

--权限
grant all privileges to sde;

--删除用户
drop user sde cascade;

--删除表空间
drop tablespace SDE_TBS including contents and datafiles;
```

# SQL语句

## NULL

``NULL``不接受运算符比较，只能使用``is null、is not null``.

```sql
//永久无数据
select * from T_AAA t where t.job = null;
//正常查询
select * from T_AAA t where t.job is null; 

//有些函数可使用null
select replace('aksakakakak','a',null) from dual;
select replace('aksakakakak','a','') from dual;
```

## rownum和rowid

rownum是一个伪列，依次对数据做标识，需要先将前面的数据取出来，才能获取后面的数据.

```sql
//因为缺少10之前的数据，所以无法过滤出数据
select a.* from T_AAA a where rownum = 10;
select a.* from T_AAA a where rownum between 10 and 20;


//过滤表中前几条数据，或先全部取出后再过滤都是可行的
select a.* from T_AAA a where rownum < 10;
select b.* from (select a.*, rownum rn from T_AAA a where rownum < 20) b where b.rn = 10;
select b.* from (select a.*, rownum rn from T_AAA a) b where b.rn between 10 and 20;
```

```sql
//常用分页
select a.* from 
    (select b.*, rownum as rn from T_AAA b where rownum <= 200) a 
where a.rn > 100;

//先排序，后分页
select a.* from 
    (select b.*, rownum as rn from
        (select c.id,c.name from T_AAA c where c.id is not null order by 1) b
    where rownum <= 200) a 
where a.rn > 100;
```

```sql
//高效率分页
select a.* from T_AAA a, (
    select rid from (
        select rownum rn, rowid rid from (
            select rowid from T_AAA
        ) where rownum <= 20)
    where rn > 10
) b where a.rowid = b.rid;
```

## dbms_random

使用``dbms_random``随机抽取表中数据.

```sql
//先取数后排序，这种方式无法实现（查出来的总是那10条数据）
select * from T_AAA where rownum < 10 order by dbms_random.value;

//先随机排序后取数
select * from (select * from T_AAA order by dbms_random.value) where rownum < 10; 
``` 

## 拼接

```sql
select t.name || ' 的工作是：' || t.job as 职业描述 from T_AAA t;

select owner || ':' || table_name as 所有表 from all_tables;
```

## 拆串

```sql
select t.*, substr(t.number, -4) from T_AAA t where rownum < 10 order by substr(t.id, 3);
```

## 条件逻辑

``case when``条件判断适应需求.

```sql
create or replace view V_AAA as
  select t.lon,
    case when t.lon < 120.00 then '市中心'
    else '郊区' end as 区域类型
  from T_AAA t where rownum < 200;

select * from V_AAA;
```

## 模糊匹配

``like``子句可以使用两个通配符``%``、``_``来替换一个或多个字符.

```sql
create or replace view V_AAA as
  select '_CCNA' as vname from dual
  union all
  select '\CCNP' as vname from dual
  union all
  select '\_CCIE' as vname from dual;

//如果只想取 _CCNA,就需要将通配符 _ 转义成正常符号 
select * from V_AAA where vname like '\_%' escape '\';
//转义 \和_，取出 \_CCIE
select * from V_AAA where vname like '\\\_%' escape '\';
```

## 对应位置替换

translate(Str,from_string,to_string)函数

```sql
//1243都选3
select translate('ACDC都选C','ABCD','1234') as str from dual;
//都选
select translate('ACDC都选C','1ABCD','1') as str from dual;
//可以通过translate去除字符串中的空格数字
select translate('711068  stefan','- 0123456789','-') from dual;
//to_String为空则返回null
select translate('ACDC都选C','ABCD','') as str from dual;
```

## 组合排序

```sql
select pid || ':' || pnum as uid, psal from T_AAA order by case when substr(psal, -3) > 600 then 1 else 2 end, 2;  
select pid || ':' || pnum as uid, psal, case when substr(psal, -3) > 600 then 1 else 2 end as uid from T_AAA order by 2, 3;
```


## 表数据复制

insert into select 要求目标表已经存在.

```sql
insert into T_A(a1,a2,a3) select (b1,b2,b3) from T_B;
insert into T_A select * from T_B;
```

select insert into 要求目标不存在.

```sql
select a1,a2 insert into T_B from T_A;
```


# 分析与聚合函数

## 分组统计

```sql
###group by + 聚合函数
select partment, sum(sal) as totalsal  from T_A  where group by partment;
```


## 字段重复

### over(partition by order by)

注意：重复字段可以为null，为null字段也视为重复！

```sql
###查询出T_A表中字段aaa值重复的除第一条外的其他数据
select t2.*  from (select t1.*, row_number() over(partition by t1.aaa, t1.bbb order by t1.ccc) as group_idx from T_A t1) t2 where t2.group_idx > 1;
```

```sql
###删除表T_A中字段重复记录，只保留第一条（报错）
delete from (select row_number() over(partition by aaa,bbb order by ccc asc, ddd desc) as group_idx from T_A t1) t2 where t2.group_idx > 1;
# ORA-01732: data manipulation operation not legal on this view（此视图的数据操纵操作非法）

###正确用法
delete from T_A t1 where t1.rowid in (
    select t2.rid from (
        select t3.rowid as rid, row_number() over(partition by t3.aaa, t3.bbb order by t3.ccc) as group_idx from T_A t3 
    ) t2
    where t2.group_idx > 1
);
```

### group by having count(*)

注意：重复字段不能为null，否则视为不重复！

```sql
###查询T_A表中aaa,bbb字段重复的数据的第一条
select t1.* from T_A t1 
    where t1.rowid in (select min(t2.rowid) from T_A t2 group by t2.aaa, t2.bbb having count(*) > 1); 
```

```sql
###查询T_A表中aaa,bbb字段重复的数据除了第一条(单字段或多字段重复同理)
select *　from　T_A t1 where
    (t1.aaa, t1.bbb) in (select t2.aaa, t2.bbb from T_A t2 group by t2.aaa, t2.bbb having count(*) > 1)
    and t1.rowid not in (select min(t3.rowid) from T_A t3 group by t3.aaa, t3.bbb having count(*) > 1);
```

```sql
###删除表T_A中字段重复记录，只保留第一条
delete from T_A t1 where
    (t1.aaa, t1.bbb) in (select t2.aaa, t2.bbb from T_A t2 group by t2.aaa, t2.bbb having count(*) > 1)
    and t1.rowid not in (select min(t3.rowid) from T_A t3 group by t3.aaa, t3.bbb having count(*) > 1);
```