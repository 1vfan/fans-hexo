---
title: 关于XML的ParserConfigurationException
date: 2018-03-27 14:43:01
tags:
- WebSphere
categories: 
- SSM
---

记录在传统SSM项目中解析XML引发的jar包冲突问题

<!--more-->

# 背景

连接Hbase数据源的SSM项目原本运行正常，但在ApplicationContext.xml中加入RDBMS数据源，同时pom.xml文件中添加 ``commons-dbcp.jar、commons-pool-1.2.jar`` 后，war包部署到was后接口莫名报错.


# 报错

需要连接Hbase和RDBMS的数据源的接口在was上运行报错：

```bash
javax.xml.parsers.ParserConfigurationException: Feature 'http://apache.org/xml/features/xinclude' is not recognized.
```

相同的war包部署到tomcat上运行正常，且部署到was上只是连接RDBMS数据源的接口同样运行正常.


# 原因

报错信息中发现与 ``xercesImpl`` 有关，查看war包中lib目录发现确实存在jar包 ``xercesImpl-2.0.2.jar`` ，通过pom.xml的Dependency Hierarchy发现新加入的 ``commons-dbcp.jar、commons-pool-1.2.jar`` 都会附带xercesImpl的引用jar包，而xercesImpl与J2EE的``xml-apis-1.0.b2.jar``存在冲突.

# 解决方案

保留 ``commons-dbcp.jar、commons-pool-1.2.jar`` 这两个包，在Maven配置中去除 ``xercesImpl-2.0.2.jar`` 的引用，部署到was上运行正常.

```bash
<dependency>
    <groupId>commons-dbcp</groupId>
    <artifactId>commons-dbcp</artifactId>
    <exclusions>
        <exclusion>
            <groupId>xerces</groupId>
            <artifactId>xercesImpl</artifactId>
        </exclusion>
    </exclusions>  
</dependency>
<dependency>
    <groupId>commons-pool</groupId>
    <artifactId>commons-pool</artifactId>
    <exclusions>
        <exclusion>
            <groupId>xerces</groupId>
            <artifactId>xercesImpl</artifactId>
        </exclusion>
    </exclusions>  
</dependency>
```
