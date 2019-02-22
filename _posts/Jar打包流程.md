---
title: 可执行Jar包打包流程
date: 2017-09-11 19:43:01
tags:
- Java
categories: 
- Java
---

记录引用第三方jar包的Java小程序打包流程

<!--more-->

## Eclipse手动打包

### 自定义MANIFEST.MF文件

``MANIFEST.MF``文件作为java项目执行时应用的配置文件，需要添加引用的第三方jar包以及程序入口（如果项目中没有该文件，需要在项目中手动创建）.

```bash
Manifest-Version: 1.0
Class-Path: lib/zookeeper.jar lib/guava-14.0.1.jar lib/commons-io-2.4.jar
Main-Class: main.TotalMileage
```

如果引入的第三方jar包非常多时，``Class-Path`` 需要按如下规则添加（前后需要空格）；``Main-Class`` 作为程序的主入口main函数的路径需完整.

```bash
Manifest-Version: 1.0
Class-Path: . lib/zookeeper.jar 
 lib/guava-14.0.1.jar 
 lib/commons-io-2.4.jar 
 lib/hadoop-common-2.5.2.jar 
 lib/hbase-client-0.98.6.jar 
Main-Class: com.bgis.track.main.TotalMileage
```

### export

* 右击Java工程选择Export --> JAR file --> Next
* 选择打入包的文件并选择jar包存放路径（应与第三方jar包文件夹lib在同一级目录中）
* Use existing manifest from workspace --> 选择项目中对应的自定义MANIFEST.MF文件
* finish完成打包

### 运行

保证运行jdk环境与项目开发时jdk版本一致，在打包jar目录下运行 ``jar -jar TotalMileage.jar > log.txt`` .

运行项目的同时可以将``System.out.pritnln(xxx)``中的信息输出到log.txt中.

### 系统可执行程序

新建 ``.bat`` 文件.

```bash
@echo off
java -jar TotalMileage.jar > log.txt
```