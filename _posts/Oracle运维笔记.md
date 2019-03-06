

## 01034

```bash
ERROR:
ORA-01034: ORACLE not available
Process ID: 0
Session ID: 0 Serial number: 0


ORA-00119: invalid specification for system parameter LOCAL_LISTENER
ORA-00132: syntax error or unresolved network name 'LISTENER_ORCL'
```

```bash
# lsnrctl status
运行以上命令查看监听参数文件位置 $path\listener.ora 
及监听端点概要 (ADDRESS = (PROTOCOL = TCP)(HOST = xxx)(PORT = 1521))

根据报错提示，在$path\tnsnames.ora文件中添加以下内容：
LISTENER_ORCL =
  (ADDRESS = (PROTOCOL = TCP)(HOST = xxx)(PORT = 1521))

最后重启数据库实例及监听程序
```

## 12516

```bash
plsql客户端工具无法连接报以下错，需要重启数据库实例及监听

ORA-12516: TNS: 监听程序无法找到匹配协议栈的可用句柄
```

可能是数据库连接数被占满，导致无可用连接，尝试增大连接数。

```bash
##当前进程连接数、当前会话连接数
select count(*) from v$process; select count(*) from v$session;
##查看当前数据库允许最大连接数
select value from v$parameter where name = 'processes';
##查看当前数据库建立的会话情况
select sid,serial#,username,program,machine,status from v$session;

##修改数据库最大连接数
sqlplus /nolog
SQL> conn / as sysdba
SQL> show parameter processes
SQL> show parameter session
SQL> alter system set processes = 300 scope = spfile;
SQL> alter system set sessions = 335 scope = spfile;

##修改后需要重启数据库才生效
SQL> shutdown immediate
SQL> startup
```


