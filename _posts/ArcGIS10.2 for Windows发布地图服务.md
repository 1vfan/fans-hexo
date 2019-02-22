---
title: ArcGIS10.2 for Windows发布地图服务
date: 2017-08-12 21:13:45
tags:
- ArcGIS
categories: 
- GIS
---

记录Esri ArcGIS10.2在Windows2008 R2中发布地图服务

<!--more-->

# 数据文件夹注册

当ArcGIS Desktop 和 Server 都安装好之后，就可以按顺序开始以下步骤.

## 注册GISServer服务器管理

> ArcCatalog连接ArcGIS Server 

```bash
打开工具 : ArcGIS --> ArcCatalog 10.2
添加Server : GIS Servers --> Add ArcGIS Server --> Administer GIS Server
Server URL : http://localhost:6080/arcgis/
User Name : admin
Password : BGIS123456
```

获得连接：arcgis on localhost_6080(admin)

## 注册tiled文件夹

首先将切片数据中解压文件得到的 ``KHXZQ、KHMAP、KHMAPANNO、KHZT``三个文件导入到 ``D:\ArcGIS\arcgisserver\directories\arcgiscache\`` 路径下.

```bash
导入后arcgiscache文件夹列表呈现：

.site
KHXZQ
KHMAP
KHMAPANNO
KHZT
```

导完切片数据开始注册tiled文件夹.

```bash
打开ArcCatalog
右键arcgis on localhost_6080(admin)
Server Properties
Data Store
Registered Folders
+
Name：tiled
Add：D:\ArcGIS\arcgisserver\directories\arcgiscache\
ok
```

## 注册shp数据文件夹

首先D盘创建一个空文件夹 ``GisData``， 将矢量数据中的``KaiHuaMap``整个文件导入到 ``D:\GisData\`` 路径下；导完矢量数据开始注册shp数据文件夹.

```bash
打开ArcCatalog
右键arcgis on localhost_6080(admin)
Server Properties
Data Store
Registered Folders
+
Name：shp
Add：D:\GisData\
ok
```

到此为止，所有数据文件夹注册成功.


# 地图切片服务发布

先使用ArcCatalog打开文件夹切片数据连接.

```bash
打开ArcCatalog
Folder Connections
Connect To Folder
分别链接到D:\GisData\KaiHuaMap\ 和 D:\ArcGIS\arcgisserver\directories\arcgiscache\
```

然后使用ArcMap发布``KHMAP`` 和 ``KHMAPANNO``的切片服务.

```bash
ArcMap右边栏打开Folder Connections
D:\GisData\KaiHuaMap\ 路径下
将KHMAP.mxd 拖拽到左边栏（发现并没有数据显示）
接着在D:\ArcGIS\arcgisserver\directories\arcgiscache\路径下
将KHMAP文件夹中的Layers 拖拽到左边栏（出现数据）
然后将不显示数据的Layers勾去掉并右键remove
File
Share As
Service
Publish a service （默认）
Choose a connection：arcgis on localhost_6080(admin)
Service name：KHMAP （默认）
User existing folder （默认）
Continue --> Service Editor
Capabilities: KML选项勾去掉
Caching：Using tiles from  a cache 、 Update cache manually（默认）
Analyze测试
Publish
Ignore Warning
The Service has been published successfully
```

本机浏览器中打开 ``http://127.0.0.1/arcgis/rest/services/`` 查看刚发布的切片服务KHMAP，点击``KHMAP -> ArcGIS JavaScript``可以看到发布的地图.

另一个``KHMAPANNO``切片发布流程相同.

# 地图shp发布

## 建立索引

首先使用ArcCatalog打开``D:\GisData\KaiHuaMap\``，在``ST_YW``下有``ST_XWQY.shp 、ST_ZND.shp、ST_ZTC.shp、ST_ZTBOUNDARY.shp``4个文件，分别进行以下操作.

```bash
右键ST_ZND.shp
Properties
Indexes
Spatial Index
Add 应用 确定
```

``D:\GisData\KaiHuaMap\ST_XZQ``中的shp文件并不需要建立索引.

## 对应数据路径

然后打开ArcMap，解决路径对应错误问题.

```bash
ArcMap右边栏打开Folder Connections
D:\GisData\KaiHuaMap\ 路径下
找到ST_ZND.mxd 拖拽到左边栏（发现Layers存在红色叹号）
双击ST_ZND的Layers
Set Data Source
选择D:\GisData\KaiHuaMap\ST_YW\路径下对应的ST_ZND.shp
Add 应用 确定
红色叹号消失
```

``ST_XWQY``对应与之相同，``KHXZQ.mxd、KHZT.mxd``产生的红色叹号需要一个一个解除对应各自的shp文件.

## 发布地图服务

最后发布地图动态服务.

```bash
勾选Layers: ST_ZND
File
Share As
Service
Publish a service （默认）
Choose a connection：arcgis on localhost_6080(admin)
Service name：ST_ZND
User existing folder （默认）
Continue --> Service Editor
Capabilities: KML选项勾去掉
Caching：Dynamically from the data 、 build cache automatically the service is publlished
Analyze测试
Publish
The Service has been published successfully
```

``KHXZQ`` 、 ``KHZT`` 、 ``ST_XWQY`` 3个服务分布流程与之相同.

同样可以使用本机浏览器中打开 ``http://127.0.0.1/arcgis/rest/services/`` 查看刚发布的地图服务.