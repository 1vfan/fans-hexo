---
title: Oracle的死亡笔记
date: 2017-02-18 10:20:30
tags:
- PostgreSQL
- DeathNote
categories: 
- 数据库
---
记录PostgreSQL 常用开发技能

<!--more-->


```sql
select version();
#PostgreSQL 9.5.1 on x86_64-pc-linux-gnu, compiled by gcc (GCC) 4.1.2 20080704 (Red Hat 4.1.2-55), 64-bit
```

## 分页

```sql
select * from T limit 3;
#前3条
select * from T limit 5 offset 0;
#从第0位开始 取5条
```




```bash
jdbc.driverClassName=org.postgresql.Driver
jdbc.url=jdbc:postgresql://192.168.30.49:5432/postgres
jdbc.username=postgres
jdbc.password=postgres
```