---
title: Nginx安装与使用
date: 2017-05-12 19:43:01
tags:
- Nginx
- Linux
categories: 
- Nginx
---

记录VMware虚拟机中安装CentOS 7.0版本以及使用NAT模式实现虚拟机联网

<!--more-->

地址：http://nginx.org/download

```bash
解压
# cd /usr/local/software
# tar -zxvf nginx-1.6.2.tar.gz -C /usr/local/

下载依赖库文件
# yum install pcre
# yum install pcre-devel
# yum install zlib
# yum install zlib-devel

configure配置检查
# cd /usr/local/nginx-1.6.2 && ./configure --prefix=/usr/local/nginx
checking for OS
 + Linux 3.10.0-327.el7.x86_64 x86_64
checking for C compiler ... not found
./configure: error: C compiler cc is not found

报错原因（缺少gcc依赖）
# whereis gcc
gcc:

下载gcc
# yum install gcc
# whereis gcc
gcc: /usr/bin/gcc /usr/lib/gcc /usr/libexec/gcc /usr/share/man/man1/gcc.1.gz

重新检查
# cd /usr/local/nginx-1.6.2 && ./configure --prefix=/usr/local/nginx
Configuration summary
  + using system PCRE library
  + OpenSSL library is not used
  + using builtin md5 code
  + sha1 library is not found
  + using system zlib library

  nginx path prefix: "/usr/local/nginx"
  nginx binary file: "/usr/local/nginx/sbin/nginx"
  nginx configuration prefix: "/usr/local/nginx/conf"
  nginx configuration file: "/usr/local/nginx/conf/nginx.conf"
  nginx pid file: "/usr/local/nginx/logs/nginx.pid"
  nginx error log file: "/usr/local/nginx/logs/error.log"
  nginx http access log file: "/usr/local/nginx/logs/access.log"
  nginx http client request body temporary files: "client_body_temp"
  nginx http proxy temporary files: "proxy_temp"
  nginx http fastcgi temporary files: "fastcgi_temp"
  nginx http uwsgi temporary files: "uwsgi_temp"
  nginx http scgi temporary files: "scgi_temp"

如上检查成功后编译安装
# cd /usr/local/nginx-1.6.2
# make install
# ls /usr/local/nginx
conf 配置文件
html 网页文件
logs 日志文件
sbin 主要二进制程序

启动
# /usr/local/nginx/sbin/nginx
# ps -ef | grep nginx
root      6165     1  0 17:49 ?        00:00:00 nginx: master process /usr/local/nginx/sbin/nginx
nobody    6166  6165  0 17:49 ?        00:00:00 nginx: worker process
root      6168  5241  0 17:50 pts/1    00:00:00 grep --color=auto nginx
   

检测
# netstat -ano | grep 80
失败可能是80端口被占用

浏览器访问地址
http://192.168.154.50:80

关闭
# /usr/local/nginx/sbin/nginx -s stop
重启
# /usr/local/nginx/sbin/nginx -s reload
```