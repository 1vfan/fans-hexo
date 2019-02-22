---
title: Maven自动化构建工具深入使用
date: 2017-02-27 19:43:01
tags:
- Maven
categories: 
- Tool
---

记录Maven的基础使用和深入实践

<!--more-->

## Maven

Maven是一款服务于Java平台的自动化构建工具；所谓构建就是以Java源文件、配置文件、JSP/HTML/JS/CSS、图片等原材料去生产一个可以运行的项目的过程；借助Maven可以将庞大的项目拆分成多个工程；使用统一的规范下载、保存、引用、管理jar包；同时自动导入依赖的jar包.

![png1](/img/20170227_1.png)

如上图，编译后的项目目录结构与开发时不同，所以所有的路径配置（包括配置文件中配置的类路径）都要以编译后的目录结果为标准；而诸如JRE System Library和Apache Tomcat v7.0这些jar包的引用，并没有将jar包本身复制到工程中，所以并不是目录.

构建的过程：
```bash
清理mvn clean：将之前编译的旧class字节码文件删除，为下一次编译腾地方
编译mvn compile：将Java源程序编译成class程序
测试mvn test-compile：自动调用junit测试
报告mvn test：测试程序执行的结果
打包mvn package：动态Web工程打成war包，Java工程打成Jar包
安装mvn install：将打包的文件复制到仓库中的指定位置
部署：将打包后的war包部署到tomcat或其他服务器上运行
```

## Maven的核心

> 约定的目录结构

Maven要实现自动化构建项目，比如自动进行编译，那么必须知道Java源文件的位置，所以要遵循约定的目录结构.

自定义的东西想要让框架或工具知道，有两种方法：

```bash
以配置的方式明确告诉框架，如下：
<param-value>classpath:spring-context.xml</param-value>

或遵循框架内部的约定，如
log4j.properties就是日志的配置文件名
```

> POM

POM（Project Object Model 项目对象模型）与 JS的DOM有些类似（Document Object Model 文档对象模型）

pom.xml是Maven工程的核心配置文件，所有与构建相关的配置都在此文件中；当我们执行Maven命令需要使用插件时，会先到配置的本地仓库中查找，若找不到则会联网到中央仓库中下载，无法连接外网则构建失败.

仓库分为本地仓库、私服（局域网中）、中央仓库（互联网上）、中央仓库镜像（减轻中央仓库的压力）

> 坐标

相当于数组中的空间坐标，根据三个向量可以定位一个唯一的点；Maven则通过groupid、artifactid、version这三个属性在仓库中定位一个唯一的Maven工程.

这三个属性简称gav

```bash
groupid：公司或组织的域名+项目名
<groupid>com.zjrc.bgis</groupid>

artifactid：模块名
<artifactid>bgis-parent</artifactid>

version：版本
<version>0.0.1-SNAPSHOT</version>
```

Maven工程的坐标与仓库中路径的对应关系

```bash
<groupid>com.zjrc.bgis</groupid>
<artifactid>bgis-parent</artifactid>
<version>4.0.0.RELEASE</version>

对应的仓库中的路径
com/zjrc/bgis/bgis-parent/4.0.0.RELEASE/bgis-parent-4.0.0.RELEASE.jar
```

> 依赖

## pom.xml

父工程：包括 ```<parent>、<modules>、<properties>、<dependencies>、<profiles>、<build><plugins>```

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <groupId>com.fan.springcloud</groupId>
    <artifactId>spring-cloud-parent</artifactId>
    <version>0.0.1-SNAPSHOT</version>
    <packaging>pom</packaging>
    <name>spring-cloud-parent</name>
    <description>Spring Cloud Parent</description>

    <parent> 
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>1.5.3.RELEASE</version>
        <relativePath/> <!-- lookup parent from repository -->
    </parent>
    
    <!-- 进行聚合的子项目 --> 
    <modules>
        <module>spring-cloud-eureka</module>
        <module>spring-cloud-provider</module>
        <module>spring-cloud-consumer</module>
    </modules>
      
    <properties>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
        <java.version>1.8</java.version>
        <httpclient.version>4.5.3</httpclient.version>
        <servlet-api.version>3.1.0</servlet-api.version> 
    </properties> 
    
    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-aop</artifactId>
        </dependency>           
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-autoconfigure</artifactId>
        </dependency>       
        <dependency>
            <groupId>javax.servlet</groupId>
            <artifactId>javax.servlet-api</artifactId>
            <scope>provided</scope> 
        </dependency>                   
        <dependency>
            <groupId>org.apache.httpcomponents</groupId>
            <artifactId>httpclient</artifactId>
            <version>${httpclient.version}</version>
        </dependency>                         
    </dependencies>

    <!-- profile 配置切换: mvn clean install -P dev/prod/local -->
    <profiles>
       <profile>
          <id>dev</id>
          <activation>
             <activeByDefault>true</activeByDefault>
          </activation>
          <dependencies>
             <dependency>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-starter-undertow</artifactId>
             </dependency>
          </dependencies>         
          <properties>
             <spring.profiles.active>dev</spring.profiles.active>
          </properties> 
       </profile>
    
       <profile>
          <id>prod</id>
          <dependencies>
             <dependency>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-starter-undertow</artifactId>
             </dependency>
          </dependencies>
          <properties>
             <spring.profiles.active>prod</spring.profiles.active>
          </properties>
       </profile>
       
       <profile>
          <id>local</id>
          <dependencies>
             <dependency>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-starter-undertow</artifactId>
             </dependency>
          </dependencies>
          <properties>
             <spring.profiles.active>local</spring.profiles.active>
          </properties>
       </profile>
    </profiles>

    <build>
        <finalName>spring-cloud-parent</finalName>
        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-war-plugin</artifactId>
            </plugin>

            <!-- 解决maven: update project 后版本降低为1.5的bug -->
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-compiler-plugin</artifactId>
                <configuration>
                    <source>1.8</source>
                    <target>1.8</target>
                </configuration>
            </plugin>
            
            <!-- MAVEN打包时动态切换: mvn clean package -P prod/dev/local -->
            <plugin>
               <groupId>org.apache.maven.plugins</groupId>
               <artifactId>maven-resources-plugin</artifactId>
               <executions>
                  <execution>
                     <id>default-resources</id>
                     <phase>validate</phase>
                     <goals>
                        <goal>copy-resources</goal>
                     </goals>
                     <configuration>
                        <outputDirectory>target/classes</outputDirectory>
                        <useDefaultDelimiters>false</useDefaultDelimiters>
                        <delimiters>
                           <delimiter>$</delimiter>
                        </delimiters>
                        <resources>
                           <!-- 打包时包含properties、xml --> 
                           <resource>  
                              <directory>src/main/java</directory>  
                              <includes>  
                                  <include>**/*.properties</include>  
                                  <include>**/*.xml</include>  
                              </includes>  
                              <!-- 是否替换资源中的属性-->  
                              <filtering>true</filtering>  
                           </resource>                          
                           <resource>
                              <directory>src/main/resources/</directory>
                              <filtering>true</filtering>
                              <includes>
                                 <include>**/*.xml</include>
                                 <include>**/*.yml</include>
                                 <include>**/*.properties</include>  
                              </includes>
                           </resource>
                           <resource>
                              <directory>src/main/resources/</directory>
                              <filtering>false</filtering>
                              <excludes>
                                 <exclude>**/*.xml</exclude>
                                 <exclude>**/*.yml</exclude>
                                 <include>**/*.properties</include>  
                              </excludes>
                           </resource>
                        </resources>
                     </configuration>
                  </execution>
               </executions>
            </plugin>

            <!-- 单元测试 -->
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-surefire-plugin</artifactId>
                <configuration>
                    <skip>true</skip>
                    <includes>
                        <include>**/*Test*.java</include>
                    </includes>
                    <testFailureIgnore>true</testFailureIgnore>
                </configuration>
            </plugin>

            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-source-plugin</artifactId>
                <executions>
                    <!-- 绑定到特定的生命周期之后，运行maven-source-pluin 运行目标为jar-no-fork -->
                    <execution>
                        <phase>package</phase>
                        <goals>
                            <goal>jar-no-fork</goal>
                        </goals>
                    </execution>
                </executions>
            </plugin>   
        </plugins>    
    </build>    
</project>
```

子工程：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <parent>
        <groupId>com.fan.springcloud</groupId>
        <artifactId>spring-cloud-parent</artifactId>
        <version>0.0.1-SNAPSHOT</version>
    </parent>
    <groupId>spring-cloud-eureka</groupId>
    <artifactId>spring-cloud-eureka</artifactId>
    <name>spring-cloud-eureka</name>
    <description>Spring Cloud Eureka</description>
  
    <dependencies>
        <dependency>
            <groupId>org.springframework.cloud</groupId>
            <artifactId>spring-cloud-starter-eureka-server</artifactId>
        </dependency>
    </dependencies>
	
    <dependencyManagement>
        <dependencies>
            <dependency>
                <groupId>org.springframework.cloud</groupId>
                <artifactId>spring-cloud-dependencies</artifactId>
                <version>Dalston.SR1</version>
                <type>pom</type>
                <scope>import</scope>
            </dependency>
        </dependencies>
    </dependencyManagement>  

    <build>
        <finalName>spring-cloud-eureka</finalName>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
                <configuration>
                    <!-- 主函数的入口 -->
                    <mainClass>com.fan.springcloud.EurekaApplication</mainClass>
                </configuration>
            </plugin>
        </plugins>
    </build>
</project>
```


## 手动导入jar

有一些中央仓库中没有的jar包（如Oracle 、db2 、SQLServer的数据源驱动）或者自定义的jar包，需要我们手动导入到本地仓库中.

```bash
mvn install:install-file -Dfile="D:\sqlserverJar\sqljdbc4.jar" -DgroupId=com.microsoft.sqlserver -DartifactId=sqljdbc4 -Dversion=4.0 -Dpackaging=jar
```