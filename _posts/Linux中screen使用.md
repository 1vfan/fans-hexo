---
title: Linux中screen的使用
date: 2017-04-03 10:23:01
tags:
- Linux
- screen
categories: 
- Linux
---

记录在linux中基于screen命令便捷的使用单Xhell窗口操作多桌面窗口

<!--more-->

# 基础操作

```bash
安装screen
# yum install screen

创建新桌面窗口
# screen -S test-one

退出当前窗口，后台运行
# Ctrl+a d
[detached from 3789.test-one]

查看当前服务器开启的桌面窗口
# screen -ls
There is a screen on:
	3789.test-one	(Detached)
1 Socket in /var/run/screen/S-root.

恢复桌面窗口
# screen -r 3789
or
# screen -r test-one

注销当前窗口，后台进程停止
# exit
or
# Ctrl+a k
[screen is terminating]
```

# 多窗口操作

[<font face="Times New Roman" color=#0099ff size=5>screenrc</font>](http://download.csdn.net/download/weixin_37479489/9897332)文件上传到服务器根目录~下

```bash
# mv screenrc ~
# cd
# mv screenrc .screenrc

新建窗口
# screen -S test-two
【0 bash】

单Xshell界面实现操作多窗口
# Ctrl+a c
【0 bash】 【1 bash】
# Ctrl+a c
【0 bash】 【1 bash】 【2 bash】
.....
# Ctrl+a c
【0 bash】 【1 bash】 【2 bash】 ... 【n bash】

切换
# Ctrl+a 1
# Ctrl+a 2
.....
# Ctrl+a n

退出当前总窗口，所有都在后台运行
# Ctrl+a d
[detached from 3789.test-two]

注销当前窗口
【0 bash】 【1 bash】 【2 bash】
# exit
【1 bash】 【2 bash】
# exit
【2 bash】
# exit
[screen is terminating]
```




