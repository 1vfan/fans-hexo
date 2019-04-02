|名词|关键字|
|---|---|
|DML数据操纵语言|select、insert、update、delete、merge|
|DDL数据定义语言|create、alter、drop、truncate|
|DCL数据控制语言|grant、revoke|
|TCL事务控制语言|commit、rollback、savepoint|

|data type|description|
|---|---|
|区别|var:固定长和可变长的区别；n:占字节数是否受字符集编码影响的区别|
|所有字符|insert values('') = insert values(null) 搜索都须用where xx is null|
|char|max200字节(200字母数字；GBK汉字/2；UTF8汉字/3)|
|varchar|Oracle不建议使用|
|varchar2|max200字节(200字母数字；GBK汉字/2；UTF8汉字/3)|
|nvarchar2|max200字节=200字符（汉字字母数字），不受字符集编码影响|
|数值型|number(2)、number(38,8)|
|日期型|date、timestamp|
|大对象|clob单字节数据(文本)、blob二进制数据(音频视频)|

固定长度char和可变长度varchar都是SQL标准；主要体现在存储空间层面的差别：
char按设定的最大字节数分配空间，缺点在于可能浪费存储空间；varchar则按实际存储字符长度分配磁盘空间，但不能因此就将最大字节数设置得过大，因为内存分配是按设定的最大字节分配，varchar的缺点就是面对更新时，需要进行额外的计算等操作；所以固定字段、短信息字段、频繁更新的字段使用char较合适；定长类型字段值为NULL会占用存储空间，其他类型则不占用，所以多NULL的字段不适合用char。

## 常用数据类型转换

```sql
select to_char(SYSDATE,'yyyy-MM-dd') as today_string from dual;
select to_date('2016-10-28', 'yyyy-MM-dd') as today_date from dual;
select to_number(replace(to_char(SYSDATE,'yyyy-MM-dd'),'-')) as today_number from dual;
```

## null

```sql
###aaa字段为空的记录不会被查询出来
select * from T_A where aaa != 'bbb';
```

## 常用函数

```sql
###coalesce 所有类型要一致，输出第一个不为空的元素
select coalesce(null, 0) from dual;  //0
select coalesce('', null, 'aaa') from dual; //aaa

###TRUNC
select SYSDATE from dual; //2016/2/14 18:30:02
select trunc(SYSDATE) from dual; //2016/2/14
select trunc(188.03, 0) from dual; //188

###CONCAT
select to_date(concat('2016-', '2-' || 14), 'yyyy-MM-dd') from dual; //2016/2/14

###ABS
select abs(-100) from dual; //100
```

```sql
select t.username, 
    case when t.salary < 1000 then '吃土'
         when t.salary < 2000 then '小康'
         else '土豪'
    end as type
from money_tbl t;

##简化版case when
select t.pid, decode(t.pid, 1001, '开发端口', 1002, '运维端口', '网络端口') from pid_tbl t;

##decode配合sign实现case when的判断
select t.name, 
    decode(sign(t.age-16), -1, '少年', 0, '少年', 1,
        decode(sign(t.age-30), -1, '青年', 0, '青年', 1,
            decode(sign(t.age-50), -1, '壮年', 0, '壮年', 1, '老年')
        )
    )
    as age_type
from age_tbl t;
```

## 分组

组函数：count、avg、max、min、sum
分组特性：group by ... having

```sql
#每个部门薪水>2000的员工按部门分组，显示部门平均薪水>3000的部门号及平均薪水值。
select partment_id, avg(salary) as avg_sal from money_tbl where salary > 2000 group by partment_id having avg_sal > 3000;  
```

## 集合运算

```sql
union 合集 重复记录保留一条
union all 合集 保留全部
intersect 交集 保留公共部分
minus 差集 集合相减 以前面表为主

select * from A intersect select * from B;
select * from A minus select * from B;
```

## 子查询

非关联子查询就是子查询语句可以独立运行。

in 全表扫描

```sql
###关于null in
select t.* from T_A t where t.type in ('A', 'B', null); //并不会查询出type为空的记录
###底层执行计划
filter ("type"='A' or "type"='B' or "type"=TO_NUMBER(NULL))

###关于null not in
select t.* from T_A t where t.type not in ('C', 'D', null); //永远查询不到记录
###底层执行计划
filter ("type"<>'C' and "type"<>'D' and "type"<>TO_NUMBER(NULL))
等价于"type"!='C' and "type"!='D' and "type"!=null，而NULL与其他值做=或!=比较结果都是UNKNOWN，所以整个条件为flase，查不出数据

总结：使用in做条件时始终查不到目标列包含NULL值的行；使用not in条件目标列包含NULL值的行，则永远查不到结果。
```

exists 非全表扫描


## 删除禁忌

不规范示例: ``DELETE FROM a WHERE id in (SELECT id FROM b)``
如果b表恰好有数据，且b表没有id字段，那么子查询中的id就是a表的id字段，条件就相当于``WHERE a.id=a.id``，则a表中的数据就全被删除。 
SQL规范需要指定字段归属表: ``DELETE FROM a WHERE a.id in (SELECT b.id FROM b)``


