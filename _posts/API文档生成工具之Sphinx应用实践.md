---
title: API文档生成工具之Sphinx应用实践
date: 2017-07-19 21:43:01
tags:
- Sphinx
- python
categories: 
- Tool
---

记录一款由python编写、支持reST（reStructuredText）语法的API文档编辑、生成、展示工具

<!--more-->

# python环境

1. 进入 [官网](https://www.python.org/downloads/) 下载，本文使用python 3.6.3在windows环境中自定义安装

2. 安装时可勾选 add path 选项自动添加环境变量，也可以手动添加 ./python/ 和./python/Scripts/ 到path中

3. python --version

# 安装方式

## 联网安装

1. 安装sphinx并创建文档

```bat
D:\> pip install sphinx 
D:\> sphinx-build -h
D:\> sphinx-quickstart D:\demo\
```

2. 自定义装配主题（发现在使用官方提供的主题时，无法展示table of contents，故使用官网推荐的第三方主题）

```bat
D:\> pip install sphinx_rtd_theme

编辑D:\demo\source\conf.py

html_theme ="" 替换成 html_theme = "sphinx_rtd_theme"

（若出错，添加如下：
import sphinx_rtd_theme
html_theme = "sphinx_rtd_theme"
html_theme_path = [sphinx_rtd_theme.get_html_theme_path()]
）
```

3. 编译成html浏览器中查看

```bash
在D:\demo\ 路径下
D:\demo\> make html
到D:\demo\build\html\ 中找到对应生成的html
```

## 离线安装

> 有时候需要在内网或是离线安装以上环境，而python在离线安装Sphinx时会需要一系列的whl模块，无法通过pip下载，需要通过pip进行离线安装whl，具体步骤如下：

1. 在正常联网的电脑上使用pip安装成功Sphinx，如此得到安装所需的whl模块清单

```bash
D:\> pip install sphinx
```

2. 建立模块清单并下载

```bat
D:\> mkdir D:\python3\packages
D:\> cd D:\python3\packages
D:\python3\packages\> pip freeze >requirements.txt
D:\python3\packages\> pip install --download . -r requirements.txt
```

3. 将上面的packages包整体拷贝到离线安装电脑的python安装根目录下（如 D:\python3\）

```bat
D:\> cd D:\python3\packages
D:\python3\packages\> python -m pip install --no-index --find-links=. -r requirements.txt
```

4. 获取[Sphinx](http://www.sphinx-doc.org/en/1.5.3/index.html) 和 [sphinx_rtd_theme](https://github.com/rtfd/sphinx_rtd_theme.git) 的离线安装包，解压后分别为sphinx-master和sphinx_rtd_theme-master

```bat
D:\> cd D:\sphinx-master
D:\sphinx-master\> python setup.py install

D:\> cd D:\sphinx_rtd_theme-master
D:\sphinx_rtd_theme-master\> python setup.py install
```

5. 同样新建文档，将 D:\demo\source\conf.py 中修改为html_theme = "sphinx_rtd_theme" ，然后make html查看效果









