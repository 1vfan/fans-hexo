---
title: ArcGIS10.2 for Windows单机版安装配置
date: 2017-08-12 17:13:45
tags:
- ArcGIS
categories: 
- GIS
---

记录Esri ArcGIS10.2全套在Windows2008 R2中单机版安装部署说明

<!--more-->

# 安装包准备

放在一个统一文件夹中 如（D:\ArcGisSoftware\）

```bash
Desktop : ArcGIS_Desktop_102_134924.iso 
Server  : ArcGIS_Server_Ent_Windows_102_134934.iso
.net3.5 : dotNetFx35setup.exe
Desktop破解文件 : ARCGIS.exe 、service.txt
Servers授权许可 : arcgisproduct.ecp
```

# 安装Desktop并破解ArcGIS

解压 ``ArcGIS_Desktop_102_134924.iso`` 到固定路径 如（D:\ArcGisSoftware\Desktop\），双击 ``ESRI.exe``.

## 检测历史版本

``Run Utility`` 卸载历史版本.

## 安装LicenseManager

安装LicenseManager后暂停License Service.

```bash
ArcGIS for Desktop -->  ArcGIS License Manager --> Setup
默认安装路径
finish successfully installed
开始菜单 ArcGIS --> License Manager --> License Server Administrator
start/stop License Service --> Stop
```

下一步安装Desktop.

## 配置.net framework 3.5

点击Setup安装Desktop时，可能会提示安装ArcGIS需要最低 .net framework 3.5 的支持.

```bash
计算机 --> 管理 --> 功能 --> 添加功能 --> 安装.net framework 3.5
```

下一步安装Desktop.

## 安装Desktop

finish安装Desktop后会弹出一个界面，放着先不用管.

```bash
ArcGIS for Desktop --> Setup
Complete
自定义安装路径 如（D:\ArcGIS\）（会自动生成一个Desktop10.2的根目录）
python安装路径默认
Install之前将之后更新选项的勾去掉
finish successfully installed
```

下一步破解ArcGIS.

## 破解ArcGIS

复制（D:\ArcGisSoftware\）中准备的  ``ARCGIS.exe 、service.txt`` 替换（C:\Program Files (x86)\ArcGIS\License10.2\bin\）中的相应文件.

打开 ``service.txt`` ，将开头的 ``SERVER xxx ANY 27000`` 中 ``xxx`` 部分替换成本机计算机名.

```bash
开始菜单 --> ArcGIS --> Licenseanager --> License ServerAdministrator
启动/停止许可服务 --> 启动 --> 重新读取许可

开始菜单 --> ArcGIS --> ArcGIS Administrator
选择产品 --> Advanced(ArcInfo)浮动版
许可管理器 --> localhost
```

破解完成后，点击 ``可用性`` 可以看到 ``过期:永久`` 的列表，代表ArcGIS完美破解.

## 问题解决

安装过程中可能出现问题的解决方案：

* 关闭防火墙
* 重新启动License服务，重新读取许可
* 最后实在没办法，重新安装License后再次破解

# 安装Server和Adaptor

安装ArcGIS Server 10.2 的前提是预先已经安装了 ArcGIS Desktop 10.2.

## 检测系统

ArcGIS Server 10.2 必须安装在用户名为Administrator账户下，首先需要激活win系统中该账户.

```bash
开始菜单 --> 右键cmd命令提示符 --> 以管理员身份运行
输入：net user administrator /active:yes
命令成功完成
```

保证administrator用户存在，并设有密码，否则无法安装ArcGIS Server 10.2.

```bash
计算机 --> 管理 --> 本地用户和组 --> 用户
Administrator  右键设置密码
```

## 安装Server

解压 ``ArcGIS_Server_Ent_Windows_102_134934.iso`` 到固定路径 如（D:\ArcGisSoftware\Server\），双击 ``ESRI.exe`` , ``Run Utility`` 卸载历史版本.

```bash
ArcGIS for Server --> Setup
自定义安装路径 如（D:\ArcGIS\Server\）
name: arcgis   password:尽量复杂与管理员密码一致好记 如（GIS123456）
python安装路径默认
选择 Do not export configure file
添加授权许可 arcgisproduct.ecp 完成授权
```

授权完成后浏览器会跳转到ArcGIS Server Manager页面，选择创建一个新站点.

```bash
设置主站点管理员密码 (admin GIS123456)
自定义服务器目录存储路径（D:\ArcGIS\arcgisserver\directories）
自定义服务器配置存储路径（D:\ArcGIS\arcgisserver\config-store）
```

完成创建站点，登陆ArcGIS Server管理器 http://localhost:6080/arcgis/manager/

## 安装Adaptor

```bash
ArcGIS for Server --> ArcGIS Web Adaptor(IIS) --> Setup
选择自动安装，下一步
name of ArcGIS for Adaptor : arcgis
```

安装后会跳转到Web Adaptor配置页面（http://localhost/arcgis/webadaptor/server）.

```bash
GIS 服务器 URL: http://localhost:6080
管理员用户名：admin
密码：GIS123456

勾选（通过 Web Adaptor 启用对站点的管理访问） 完成配置
```

配置成功后显示，GIS服务器已注册到Web Adaptor中.

浏览器访问 http://localhost/arcgis/rest/services 查看已发布的服务，使用admin登陆.




