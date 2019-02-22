---
title: 轻量级文本标记语言之md与rst实践
date: 2017-07-19 21:43:01
tags:
- Makedown
- reStructuredText
- Python
categories: 
- reST
---

记录轻量级文本标记语言reStructuredText的常用语法

<!--more-->

``Markdown``是一种可以使用普通文本编辑器编写的轻量级标记语言，通过简单的标记语法便可以使普通文本内容具有一定的格式，语法简单易用，大多博客平台都对Makedown提供了很好的支持，写技术类文章一般优先考虑它.

``reST``最初是为编写Python语言的官方文档而生的轻量级标记语言，所以依赖python环境，它所提供的语法和功能都比Markdown丰富，因此语法相较复杂，很多开源项目的文档就是用sphinx+reST做的，对文章排版有较高要求一般会优先考虑它。


## reStructuredText

在线编辑链接：[在线](http://rst.ninjs.org/)

英文语法文档：[文档](http://docutils.sourceforge.net/docs/ref/rst/directives.html)

``Markdown``语法相较简单，不做赘述；``reST``的语法较丰富，分享本人最常使用的语法：

> 样式

```bash
*Stefan*    斜体 
`Stefan`    斜体 

**Stefan**  加粗
``Stefan``  等宽
```

> 章节

```bash
文章标题
=====================

一级标题
---------------------

二级标题
+++++++++++++++++++++

三级标题
"""""""""""""""""""""
```

> 列表

```bash
* 列表一

* 列表二

* 列表三
```

> 代码块

配合默认代码高亮显示器[pygments](http://pygments.org/languages/)可以使得特定代码高亮显示，官网查看支持高亮显示语言.

```bash
.. code-block:: bash

.. code-block:: Java

.. code-block:: JavaScript

.. code-block:: Json
```

> 强调

```bash
.. note::

    这是一条警告提示.

```

> 表格

主要介绍 ``list-table``.

```bash
.. list-table:: TableName
   :widths: 15 10 1
   :header-rows: 1

   * - id
     - name
     - address
   * - 1
     - Stefan
     - hangzhou
   * - 2
     - Jack
     - alibaba
```

```bash
.. list-table:: TableName
   :widths: 15 10 30 1
   :header-rows: 1

   * - id
     - name
     - address
     - age
   * - 1
     - Stefan
     - hangzhou
     - 24
   * - 2
     - Jack
     - alibaba
     - 50
```

> 分隔符

```bash
上部分

---------------

下部分
```

> 内部链接跳转

设置引用注脚（顶格）

```bash
位置一

.. _refAddress:

位置二
```

引用注脚（空格尤为注意）

```bash
在此处点击 :ref:`链接名 <refAddress>` 可以跳转到位置一与位置二中间处
```

通过如上设置可以方便的在同一rst文件或者不同rst文件中切换，当然还有其他实现方式.

> 外部链接跳转

```bash
`name <http://www.baidu.com>`_
```