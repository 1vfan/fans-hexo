---
title: Spring的终极奥义一：IOC
date: 2018-02-11 19:00:41
tags:
- Spring
categories: 
- SSM
---

记录深入Spring源码底层之探索IOC容器

<!--more-->

## Spring架构

Spring是一个分层框架，包含以下多层功能模块.

![png1](/img/SSM/Spring/Spring_framework.png)

核心容器包含Core、Beans、Contexts、Expression Language模块，其中Core和Beans是Spring框架的最基础部分，提供IOC相关功能.

* Core主要包含Spring框架的核心工具类
* Beans主要包含访问配置文件、创建和管理bean以及DI的相关类，核心功能就是对Bean对象生命周期的管理，包含Bean的定义、解析和创建等
* Contexts基于Core和Beans模块之上，为Spring提供大量扩展，提供了国际化，资源加载等
* Expression即SpringEL与JSP的EL表达式类似，可以方便的获取属性的值，属性的分配，方法的调用，访问数组上下文等

通俗地说：将Spring应用比作一场表演，Beans是演员，Core是道具，Contexts是舞台.


## IOC

IOC最大的好处就是 [解耦].

```bash
This chapter covers the Spring Framework implementation of the Inversion of Control (IoC) [1] principle. 
IoC is also known as dependency injection (DI). 
控制反转IOC 又称为 依赖注入DI.
It is a process whereby objects define their dependencies, that is, the other objects they work with, 
only through constructor arguments, arguments to a factory method, or properties that are set on the
object instance after it is constructed or returned from a factory method. 
这是一个定义对象依赖的过程，对象只和构造参数，工厂方法参数，对象实例属性或工厂方法返回相关.
The container then injects those dependencies when it creates the bean.
容器在创建这些 bean 的时候注入这些依赖.
This process is fundamentally the inverse, hence the name Inversion of Control (IoC),
这是一个反向的过程，所以命名为依赖反转.
of the bean itself controlling the instantiation or location of its dependencies by using direct construction of classes, 
or a mechanism such as the Service Locator pattern.
对象实例的创建由其提供的构造方法或服务定位机制来实现.
```


