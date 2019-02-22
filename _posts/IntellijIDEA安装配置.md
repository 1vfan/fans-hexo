---
title: Intellij IDEA基础配置
date: 2017-06-03 12:37:08
tags:
- IDEA
categories: 
- Tool
---

记录下Intellij IDEA的基础配置

<!--more-->

## 科学永久使用

### Win版

1. 下载破解jar包``JetbrainsCrack-2.10-release-enc.jar``，拷贝到IDEA安装目录的bin路径下；

2. 修改bin路径下的``idea.exe.vmoptions``和``idea64.exe.vmoptions``，末尾都添加``-javaagent:D:\IntelliJ IDEA 2017.3.1\bin\JetbrainsCrack-2.10-release-enc.jar``；

3. 重启IDEA，打开注册界面，将如下数据拷贝到``Activation code``后再次重启IDEA；

```json
{"licenseId":"1337",
"licenseeName":"stefan",
"assigneeName":"",
"assigneeEmail":"",
"licenseRestriction":"Unlimited license till end of the century.",
"checkConcurrentUse":false,
"products":[
{"code":"II","paidUpTo":"2099-12-31"},
{"code":"DM","paidUpTo":"2099-12-31"},
{"code":"AC","paidUpTo":"2099-12-31"},
{"code":"RS0","paidUpTo":"2099-12-31"},
{"code":"WS","paidUpTo":"2099-12-31"},
{"code":"DPN","paidUpTo":"2099-12-31"},
{"code":"RC","paidUpTo":"2099-12-31"},
{"code":"PS","paidUpTo":"2099-12-31"},
{"code":"DC","paidUpTo":"2099-12-31"},
{"code":"RM","paidUpTo":"2099-12-31"},
{"code":"CL","paidUpTo":"2099-12-31"},
{"code":"PC","paidUpTo":"2099-12-31"},
{"code":"DB","paidUpTo":"2099-12-31"},
{"code":"GO","paidUpTo":"2099-12-31"},
{"code":"RD","paidUpTo":"2099-12-31"}
],
"hash":"2911276/0",
"gracePeriodDays":7,
"autoProlongated":false}
```

### Mac版

1. 下载破解jar包``JetbrainsCrack-2.10-release-enc.jar``，拷贝到IDEA安装目录的bin路径下``/Applications/IntelliJ IDEA.app/Contents/bin/``；

2. 上述路径中找到``idea.vmoptions``，末尾添加``-javaagent:/Applications/IntelliJ IDEA.app/Contents/bin/JetbrainsCrack-2.10-release-enc.jar``;

3. 在``~/Library/Preferences/IntelliJIdea2018.2/``目录下找到``idea.vmoptions``，末尾添加``-javaagent:/Applications/IntelliJ IDEA.app/Contents/bin/JetbrainsCrack-2.10-release-enc.jar``;

4. 重复上面``Win版``的第3步。


## 与eclipse的区别

|工具|工程|项目|
|---|---|---|
|Intellij IDEA|workspace|project|
|eclipse|project|module|

## export jar

```bash
File
Project Structure
Artifacts
+
JAR
From modules with dependencies...
Main Class
Name
Output directory
- Extracted '*.jar/' (...)
only '*' compile output
Apply
OK

Build
Artifacts...
Build
```

在``From modules with dependencies...``的时候报错时``manifest.mf already exists in vfs``代表IDEA之前对这个module打过jar包，所以module中会有一个MANIFEST.MF文件夹，提示的错误即时这个文件夹及其中的文件已经存在，所以把这个文件夹删除掉，再``Build`` -> ``Rebuild project``打包即可.


## Maven
当加完一次依赖后，会有一个提示框
maven projects need to be import
点击Auto-import（自动导入）
它会自动从网上下载所需要的包到你的本地仓库（默认是用户文件夹下面的 .m2/repository下面）

## 主题

> 点击[<font color=#0099ff>主题</font>](http://www.riaway.com/theme.php?page=1)下载jar文件导入到IDEA中，重启.

```bash
下载jar文件
File 
import Settings...
import file location
reload IDEA
```

## 字符集

为了消除乱码问题与配置的简化，实际的项目中往往把所有的编码集都设置为 ``UTF-8``，setting -> Editor -> File Encodings.

1. Global Encoding：全局的编码集，默认就是 UTF-8，不需要改动.

2. Project Encoding：项目的编码集，默认是 GBK，修改为 UTF-8.

3. Default encoding for properties file：.properties 文件的专有编码集，默认为 GBK，修改为 UTF-8.

4. Transparent native-to-ascii conversion：勾选后可以在 .properties 文件的查看中文属性和注释.

## 显示行号

```bash
# Ctrl + Alt + S
# Editor
# General
# Appearance
# Show line numbers
```

## 文件与导航关联

> 项目导航栏工具介绍

* 红色：定位图标，定位当前打开的文件在左侧项目目录树中的位置

* 蓝色：勾选下拉浮层中的AutoScroll from/to Source，左侧项目文件目录树会自动同步所在位置

* 黄色：收起展开的项目目录树

* 黑色：关闭project导航

* 蓝色：打开project导航

![png1](/img/20170603_1.png)


## 手动保存与修改标记

> intellij默认会自动保存，并且修改了文件也没有星号标注，介绍下如何去掉默认保存以及出现修改星号标记

* 关闭自动保存

```bash
# Ctrl + Alt + S
# Appearance & Behavior
# System Settings
当前应用是intellij时，自动保存文件
# 去掉勾选synchronize files on frame or editor tab activation
从intellij切换到其他应用时，保存文件
# 去掉勾选save files on frame deactivation
```

* 恢复未保存文件的星号

```bash
# Ctrl + Alt + S
# Editor
# General
# Editor tabs
# 勾选 mark modified files as asterisk
```

## 使用Maven的tomcat插件

> 只需要在pom.xml中添加tomcat的插件，在Terminal窗口输入命令运行，不再需要在IDE中手动添加本地tomcat服务器.

* pom.xml基础配置如下：

```bash
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/maven-v4_0_0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.zjjzfy</groupId>
  <artifactId>tomcatMvnTest</artifactId>
  <packaging>war</packaging>
  <version>1.0-SNAPSHOT</version>
  <name>tomcatMvnTest Maven Webapp</name>
  <url>http://maven.apache.org</url>

  <dependencies>
    <dependency>
      <groupId>javax.servlet</groupId>
      <artifactId>javax.servlet-api</artifactId>
      <version>3.0.1</version>
      <scope>provided</scope>
    </dependency>
  </dependencies>

  <properties>
    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
  </properties>

  <build>
    <plugins>
      <plugin>
        <artifactId>maven-compiler-plugin</artifactId>
        <version>2.3.2</version>
        <configuration>
          <source>1.7</source>
          <target>1.7</target>
        </configuration>
      </plugin>

      <plugin>
        <groupId>org.apache.tomcat.maven</groupId>
        <artifactId>tomcat7-maven-plugin</artifactId>
        <version>2.2</version>
        <configuration>
          <port>9080</port>
          <path>/</path>
        </configuration>
      </plugin>
    </plugins>
  </build>
</project>
```

* build project and start server，在Terminal窗口输入以下命令：

```bash
# mvn clean install
# mvn tomcat7:run
```

![png2](/img/20170603_2.png)

## 热部署JRebel激活码

> JRebel有一个免费获得激活码的方法，点击进入[<font face="Times New Roman" color=#0099ff>JRebel</font>](https://my.jrebel.com)后用Twitter或者Facebook账号登录这个网站，就能获得免费的激活码，亲测有效.

```bash
# Ctrl + Alt + S
# Plugins
# Browse repositories...
# JRebl
# Install
```
![png5](/img/20170603_5.png)

![png3](/img/20170603_3.png)

## 右键新建选项没有Java class选项

> Ctrl+Shift+Alt+S 在Modules中指定项目的Source Folders

![png4](/img/20170603_4.png)


## 装B插件

1. Nyan Progress Bar

缺点在于JUnit测试没有颜色区别

2. activate-power-mode

取消抖动 window -> activate-power-mode -> shake

3. Background Image Plus

view -> set Background Image

## 实用插件

1. Maven Helper

2. Scala

3. Translate

4. JRebel for IntelliJ

5. Alibaba Java Conding Guidelines

6. PlantUML


## PlantUML安装

1. IDEA中install``Plant Integration``

2. win环境下载安装[graphviz-2.38.msi](https://graphviz.gitlab.io/_pages/Download/Download_windows.html)，添加dot环境变量``D:\Graphviz\bin``，使用``dot -version``验证

3. IDEA -> Settings -> PlantUML -> Graphviz dot executable: Browse -> D:\Graphviz\bin\dot.exe -> apply

4. IDEA -> File -> New -> UML Class

## 快捷键


|作用|快捷键|
|---|---|
|Settings|Ctrl Alt S|
|自定义全屏|Shift F5|
|切换到项目|Alt 1|
|页面切换|Alt right/left|
|操作查找|Ctrl Shift A|
|类查找|Ctrl N|
|文件内查找与替换|Ctrl R|
|文件或目录查找|Ctrl Shift N|
|符号查找|Ctrl Shift Alt N|
|全项目查找|Shift Shift|
|全局定位切换|Ctrl E|
|文件结构切换|Ctrl F12|
|类层次结构导航|Ctrl H|
|选择进入|Alt F1|
|快速创建|Alt Insert|
|定位定义位置|Ctrl B|
|UML结构图|Ctrl Alt U|
|类接口方法文档|Ctrl Q|
|版本控制工具窗口|Alt 9|
|控制台打印窗口|Alt F12|
|编译项目|Ctrl F9|
|debug|Alt 5 / Shift F9|
|选择debug进入的方法|Shift F7|
|run|Alt 4 / Shift F10|
|修正建议|Alt Enter|
|代码补全|Ctrl Space|
|类型补全|Ctrl Shift Space|
|自动补全|Ctrl Shift Enter|
|补全方法返回值类型|Ctrl Alt V|
|代码围绕|Ctrl Shift T|
|复制代码到下一行|Ctrl D|
|删除整行代码|Ctrl Y|
|行注释|Ctrl /|
|块注释|Ctrl Shift /|
|移动整块代码|Ctrl Shift up/down|


## 错误解决

1. Cannot start process, the working directory 'G:\JavaDemo\JavaDemo' does not exist.

Run -> Edit Configurations -> Working directory -> remove 'JavaDemo'

2. This inspection controls whether the Persistence QL Queries are error-checked.

setting -> inspectiongs -> JPA issues -> query language check 勾取消即可，不提示.

3. idea2018中plugins下载时报timeout，所有的插件都下载不了.

setting -> system settings -> updata -> Use secure Connetion  勾取消即可，因为使用了https协议下载导致的问题.



## 链接

> 更多设置[<font face="Times New Roman" color=#0099ff>查看</font>](http://www.phperz.com/article/15/0923/159043.html)
