---
title: org.apache.ibatis.binding.BindingException
date: 2017-04-09 15:12:30
tags:
- Mybatis
- Maven
categories: 
- SSM
---
记录Mybatis的BindingException异常解决方案

<!--more-->

# 背景

Maven工具下的Spring整合Mybatis

# 报错

org.apache.ibatis.binding.BindingException: Invalid bound statement (not found)

# 原因

Mybatis的Mapper接口，被Spring注入后，无法正常使用mapper.xml的sql，就是你的接口已经成功的被扫描到，但是当Spring尝试注入一个代理的实现类后，却无法正常使用。

> 报错原因多种多样，但报错结果一样，所以需要具体排查：

```bash
接口已经被扫描到，但是代理对象没有找到，即使尝试注入，也是注入一个错误的对象（可能就是null）
接口已经被扫描到，代理对象找到了，也注入到接口上了，但是调用某个具体方法时，却无法使用（可能别的方法是正常的）
```

# 排查

## 命名规范

> mapper接口和mapper.xml是否在同一个package下？名字是否一样（仅后缀不同）？

```bash
比如，接口名是NameMapper.java;对应的xml就应该是NameMapper.xml
```

> mapper.xml的命名空间（namespace）是否跟mapper接口的包名一致？

```bash
比如，你接口的包名是com.abc.interfaces,接口名是NameMapper.java，那么你的mapper.xml的namespace应该是com.abc.interfaces.NameMapper
```

> 接口的方法名，与xml中的一条sql标签的id是否一致？

```bash
比如，接口的方法List<User> findAll();那么，对应的xml里面一定有一条是
<select id="findAll" resultMap="**">........</select>
如果接口中的返回值List集合，那么xml里面的配置，尽量用resultMap,不要用resultType
```
> 字段类型jdbcType是否正确对应

```bash
注意Long对应的类型是BIGINT
一般会报错：
No enum constant org.apache.ibatis.type.JdbcType.*****
```

## Maven项目小程序

如果你的小程序是使用Maven管理工具，在运行Java Application时编译很可能没有生产对应的xml文件（以及其他配置文件），因为Maven默认是不编译的，因此，需要在项目的pom.xml的<build></build>里，加如下代码片段：

```bash
<resources>
    <resource>
        <directory>src/main/java</directory>
        <includes>
            <include>**/*.xml</include>
        </includes>
        <filtering>true</filtering>
    </resource>
    <resource>
        <directory>src/main/resources</directory>
        <includes>
            <include>**/*.xml</include>
            <include>**/*.properties</include>
        </includes>
        <filtering>true</filtering>
    </resource>
</resources>
```