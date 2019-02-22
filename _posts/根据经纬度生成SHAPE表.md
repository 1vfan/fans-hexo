---
title: 根据经纬度生成SHAPE表
date: 2017-04-24 15:26:04
tags:
- ArcMap
- ArcCatalog
- Oracle
categories: 
- GIS
---
记录使用Oracle、ArcMap、ArcCatalog工具将带有经纬度字段的普通表生成GIS系统所使用的shape表

<!--more-->

# 连接数据库

```bash
Database Connection
Add Database Connection
Database Platform: Oracle
Instance: datasourceIP/orcl
```

# 新建ST_SHAPE表

```bash
SHAPE表目录SDE.SHAPE下右键New Feature Class...
Name:  ST_SHAPE
Alias: ST_SHAPE 
Type:  Point Features
Import...    导入TMP_POI表结构
```

# 生成SHAPE数据

```bash
选中ST_SHAPE表
打开ArcMap
File -> Add Data -> Add XY Data
Browse 导入T_SHAPE(包含oldlon、oldlat、newlon、newlat)
X Field:对应newlon、Y field:对应newlat
右键Layers中新生成的SDE.T_SHAPE Events
Data -> Export Data
Browse 选择路径保存ST_SHAPE.shp
```

# 导入数据

```bash
ArcCatalog中右键SDE.ST_SHAPE
load -> load data
Input data  之前保存ST_SHAPE.shp的路径
macth fields
load all data
```