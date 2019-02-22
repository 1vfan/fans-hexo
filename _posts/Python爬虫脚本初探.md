---
title: Python爬虫脚本初探
date: 2018-05-23 19:43:01
tags:
- Python
- Mac
categories: 
- Python
---

记录Mac环境下安装爬虫环境及使用Pycharm + Scrapy爬取网站数据

<!--more-->

## python版本

1. mac系统自带python 2.x

```bash
stefan-mac:~ stefan$ python
Python 2.7.10 (default, Oct  6 2017, 22:29:07)
[GCC 4.2.1 Compatible ...] on darwin
Type "help", "copyright", "credits" or "license" for more information.

stefan-mac:~ stefan$ which python
/usr/bin/python
```

2. 使用Homebrew下载管理python 3.x

```bash
stefan-mac:~ stefan$ brew info python
stefan-mac:~ stefan$ brew install python3

stefan-mac:3.7.0 stefan$ pwd
/usr/local/Cellar/python/3.7.0

stefan-mac:~ stefan$ which python3
/usr/local/bin/python3
```


## virtualenv/wrapper

```bash
###安装virtualenv
stefan-mac:~ stefan$ pip3 install virtualenv
Collecting virtualenv
  100% |████████████████████████████████| 1.9MB 4.7MB/s
Installing collected packages: virtualenv
Successfully installed virtualenv-16.1.0
Cache entry deserialization failed, entry ignored

stefan-mac:～ stefan$ virtualenv --version
16.1.0

###安装virtualenvwrapper
stefan-mac:usr stefan$ pip3 install virtualenvwrapper
export GIT_HOME=/usr/local
Collecting virtualenvwrapper
export GIT_HOME=/usr/local
Requirement already satisfied: virtualenv in ./local/lib/python3.7/site-packages (from virtualenvwrapper) (16.1.0)
Collecting stevedore (from virtualenvwrapper)
  100% |████████████████████████████████| 51kB 61kB/s
Installing collected packages: six, pbr, stevedore, virtualenv-clone, virtualenvwrapper
Successfully installed pbr-5.1.0 six-1.11.0 stevedore-1.30.0 virtualenv-clone-0.4.0 virtualenvwrapper-4.8.2
```

## ~/.bash_profile

```bash
stefan-mac:~ stefan$ which virtualenvwrapper.sh
/usr/local/bin/virtualenvwrapper.sh
stefan-mac:~ stefan$ which python3
/usr/local/bin/python3

stefan-mac:~ stefan$ vim ~/.bash_profile
1	export GIT_HOME=/usr/local
2	export MVN_HOME=/usr/local
3	export JAVA_HOME=/usr/local/java7
4	export PATH=$JAVA_HOME/bin:$GIT_HOME/bin/git:$MVN_HOME/bin/mvn:$PATH
5	export CLASSPATH=.:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar

###所有的虚拟环境都存放在新建的~/.virtualenvs目录中
6	export WORKON_HOME='~/.virtualenvs'
7	export VIRTUALENVWRAPPER_PYTHON='/usr/local/bin/python3'
8	source /usr/local/bin/virtualenvwrapper.sh

stefan-mac:~ stefan$ source ~/.bash_profile
virtualenvwrapper.user_scripts creating /Users/stefan/.virtualenvs/premkproject
virtualenvwrapper.user_scripts creating /Users/stefan/.virtualenvs/postmkproject
virtualenvwrapper.user_scripts creating /Users/stefan/.virtualenvs/initialize
virtualenvwrapper.user_scripts creating /Users/stefan/.virtualenvs/premkvirtualenv
virtualenvwrapper.user_scripts creating /Users/stefan/.virtualenvs/postmkvirtualenv
virtualenvwrapper.user_scripts creating /Users/stefan/.virtualenvs/prermvirtualenv
virtualenvwrapper.user_scripts creating /Users/stefan/.virtualenvs/postrmvirtualenv
virtualenvwrapper.user_scripts creating /Users/stefan/.virtualenvs/predeactivate
virtualenvwrapper.user_scripts creating /Users/stefan/.virtualenvs/postdeactivate
virtualenvwrapper.user_scripts creating /Users/stefan/.virtualenvs/preactivate
virtualenvwrapper.user_scripts creating /Users/stefan/.virtualenvs/postactivate
virtualenvwrapper.user_scripts creating /Users/stefan/.virtualenvs/get_env_details

stefan-mac:~ stefan$ cd .virtualenvs/
stefan-mac:.virtualenvs stefan$ ls
get_env_details		postactivate		postmkproject		postrmvirtualenv	predeactivate		premkvirtualenv
initialize		postdeactivate		postmkvirtualenv	preactivate		premkproject		prermvirtualenv
```

## workon命令

使用workon命令查询并进入虚拟环境.

```bash
stefan-mac:~ stefan$ mkvirtualenv zjxzq_spider
Using base prefix '/usr/local/Cellar/python/3.7.0/Frameworks/Python.framework/Versions/3.7'
New python executable in /Users/stefan/.virtualenvs/zjxzq_spider/bin/python3.7
Also creating executable in /Users/stefan/.virtualenvs/zjxzq_spider/bin/python
Installing setuptools, pip, wheel...
done.
virtualenvwrapper.user_scripts creating /Users/stefan/.virtualenvs/zjxzq_spider/bin/predeactivate
virtualenvwrapper.user_scripts creating /Users/stefan/.virtualenvs/zjxzq_spider/bin/postdeactivate
virtualenvwrapper.user_scripts creating /Users/stefan/.virtualenvs/zjxzq_spider/bin/preactivate
virtualenvwrapper.user_scripts creating /Users/stefan/.virtualenvs/zjxzq_spider/bin/postactivate
virtualenvwrapper.user_scripts creating /Users/stefan/.virtualenvs/zjxzq_spider/bin/get_env_details
(zjxzq_spider) stefan-mac:~ stefan$ lsvirtualenv -b
testenv1
zjxzq_spider
(zjxzq_spider) stefan-mac:~ stefan$ python
Python 3.7.0 (default, Jul 23 2018, 20:22:55)
[Clang 9.1.0 (clang-902.0.39.2)] on darwin
Type "help", "copyright", "credits" or "license" for more information.
>>>

ctrl + z
(zjxzq_spider) stefan-mac:~ stefan$ deactivate
stefan-mac:~ stefan$ workon
testenv1
zjxzq_spider
stefan-mac:~ stefan$ workon zjxzq_spider
(zjxzq_spider) stefan-mac:~ stefan$ 
```

## scrapy

```bash
(zjxzq_spider) stefan-mac:~ stefan$ pip3 install -i https://pypi.douban.com/simple scrapy
Looking in indexes: https://pypi.douban.com/simple
Collecting scrapy
  Downloading https://pypi.doubanio.com/packages/5d/12/a6197eaf97385e96fd8ec56627749a6229a9b3178ad73866a0b1fb377379/Scrapy-1.5.1-py2.py3-none-any.whl (249kB)
    100% |████████████████████████████████| 256kB 8.7MB/s
Collecting queuelib (from scrapy)
Building wheels for collected packages: Twisted, PyDispatcher, pycparser
  Running setup.py bdist_wheel for Twisted ... done
  Stored in directory: /Users/stefan/Library/Caches/pip/wheels/0d/55/3b/ad90bba345bc7b6d7f4b4a1683aae2d291fa541b6c189e6c7b
  Running setup.py bdist_wheel for PyDispatcher ... done
  Stored in directory: /Users/stefan/Library/Caches/pip/wheels/a4/bb/5b/62151ae4ace1811e779c41f59a3a7b1a2243fa9a5611be4a7d
  Running setup.py bdist_wheel for pycparser ... done
  Stored in directory: /Users/stefan/Library/Caches/pip/wheels/55/e4/8a/e2a0a544e625a9d55f17fdd50119736ae47f3ff32e0dfd2c26
Successfully built Twisted PyDispatcher pycparser
Installing collected packages: queuelib, lxml, six, w3lib, cssselect, parsel, zope.interface, constantly, incremental, attrs, Automat, idna, hyperlink, PyHamcrest, Twisted, PyDispatcher, asn1crypto, pycparser, cffi, cryptography, pyOpenSSL, pyasn1, pyasn1-modules, service-identity, scrapy
Successfully installed Automat-0.7.0 PyDispatcher-2.0.5 PyHamcrest-1.9.0 Twisted-18.9.0 asn1crypto-0.24.0 attrs-18.2.0 cffi-1.11.5 constantly-15.1.0 cryptography-2.3.1 cssselect-1.0.3 hyperlink-18.0.0 idna-2.7 incremental-17.5.0 lxml-4.2.5 parsel-1.5.1 pyOpenSSL-18.0.0 pyasn1-0.4.4 pyasn1-modules-0.2.2 pycparser-2.19 queuelib-1.5.0 scrapy-1.5.1 service-identity-17.0.0 six-1.11.0 w3lib-1.19.0 zope.interface-4.6.0
```

## scrapy project

运行命令会使用scrapy默认模版创建scrapy项目，也可以使用自定义模版.

```bash
stefan-mac:~ stefan$ ls
Applications			Documents			Library				Music				Public				Virtualenvs
Applications (Parallels)	Downloads			Maven				Parallels			PySpace				software
Desktop				IDEASpace			Movies				Pictures			VMware
stefan-mac:~ stefan$ cd PySpace/
stefan-mac:PySpace stefan$ mkdir SpiderSpace
stefan-mac:PySpace stefan$ ls
SpiderSpace
stefan-mac:PySpace stefan$ cd SpiderSpace/
stefan-mac:SpiderSpace stefan$ ls
stefan-mac:SpiderSpace stefan$ workon
testenv1
zjxzq_spider
stefan-mac:SpiderSpace stefan$ workon zjxzq_spider
(zjxzq_spider) stefan-mac:SpiderSpace stefan$ scrapy startproject ZjxzqSpider
New Scrapy project 'ZjxzqSpider', using template directory '/Users/stefan/.virtualenvs/zjxzq_spider/lib/python3.7/site-packages/scrapy/templates/project', created in:
    /Users/stefan/PySpace/SpiderSpace/ZjxzqSpider

You can start your first spider with:
    cd ZjxzqSpider
    scrapy genspider example example.com


(zjxzq_spider) stefan-mac:ZjxzqSpider stefan$ pwd
/Users/stefan/PySpace/SpiderSpace/ZjxzqSpider/

(zjxzq_spider) stefan-mac:ZjxzqSpider stefan$ scrapy genspider zjxzq www.stats.gov.cn
Created spider 'zjxzq' using template 'basic' in module:
  ZjxzqSpider.spiders.zjxzq

###导入项目后生成对应spider文件需要 双击spiders -> Synchronize 'spiders'
_init_.py
zjxzq.py
```

## 项目导入pycharm

```bash
###设置interpreter
Preferences -> project interpreter
设置 -> add -> virtualenv Environment -> existing Environment
/Users/stefan/.virtualenvs/zjxzq_spider/bin/python
```

```bash
###settings.py文件中修改参数
# Obey robots.txt rules,默认True会将不符合robot协议的URL过滤掉
ROBOTSTXT_OBEY = True
改成
ROBOTSTXT_OBEY = False
```


## data


```bash
###
response.css("tr.countytr a::text").extract()
['330102000000', '上城区', '330103000000', '下城区', '330104000000', '江干区', '330105000000', '拱墅区', '330106000000', '西湖区', '330108000000', '滨江区', '330109000000', '萧山区', '330110000000', '余杭区', '330111000000', '富阳区', '330112000000', '临安区', '330122000000', '桐庐县', '330127000000', '淳安县', '330182000000', '建德市']

```



```bash
###URL数组
response.css("tr.countytr a::attr(href)").extract()

['01/330102.html', '01/330102.html', '01/330103.html', '01/330103.html', '01/330104.html', '01/330104.html', '01/330105.html', '01/330105.html', '01/330106.html', '01/330106.html', '01/330108.html', '01/330108.html', '01/330109.html', '01/330109.html', '01/330110.html', '01/330110.html', '01/330111.html', '01/330111.html', '01/330112.html', '01/330112.html', '01/330122.html', '01/330122.html', '01/330127.html', '01/330127.html', '01/330182.html', '01/330182.html']
```

```bash
response.css("tr.villagetr td::text").extract()
['330102001051', '111', '清波门社区', '330102001052', '111', '劳动路社区', '330102001053', '111', '定安路社区', '330102001055', '111', '清河坊社区', '330102001057', '111', '柳翠井巷社区']
```