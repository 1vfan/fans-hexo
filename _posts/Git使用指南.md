---
title: Git分布式版本控制工具使用指南
date: 2017-11-27 10:43:01
tags:
- Git
categories: 
- Tool
---

记录Git的基础知识与GitBucket的使用

<!--more-->

# 版本控制类型

## 集中式版本控制工具 (CVCS -> SVN)

早期集中化的版本控制系统有助于不同系统上的开发者协同工作，这类系统使用单一的集中管理的服务器保存所有文件的修订版本，协同工作的人们都通过客户端连接到该服务器，获取最新的文件或提交更新；集中化的版本控制系统，最显而易见的缺点就是中央服务器的单点故障问题。

## 分布式版本控制工具 (DVCS -> Git)

在分布式版本控制系统中，客户端不仅仅是只提取最新版本的文件快照，而是镜像完整的代码仓库，所以每一次提取都是对代码仓库的完整备份，就再不必担心服务器发生故障了；在Git中的绝大多数操作都只需要访问本地文件和资源，因为Git在本地磁盘上就保留着所有当前项目的历史更新，在没有网络或VPN的情况下，同样可以愉快的频繁提交更新，等有了网络再提交到远程仓库。

Git和其他版本控制系统的主要差别在于：Git只关心文件数据的整体是否发生了变化，而多数的其他系统则只关心文件内容的具体差异，它们在每个版本中记录着各个文件的具体差异。


# Github使用指南

## IDEA提交新项目到Github

创建Github个人账号，安装Git，Git Bash设置全局用户名和邮箱.

```bash
$ git config --global user.name "xxx"
$ git config --global user.email "xxx@xx.com"
```

IDEA中 ``Settings`` ：Git配置指定本机安装git.exe路径，Github配置输入Github个人账号密码生成Token；创建新项目后在IDEA中执行以下步骤.

```bash
VCS --> Import into Version Control --> Create Git Repository...  #项目文件变红#
右键项目 Git --> Add  #提交到暂存区，项目文件变绿#
右键项目 Git --> Commit Directory --> Commit  #提交到版本库，项目文件变白#
VCS --> Import into Version Control --> Share Project on GitHub --> 输入仓库名和描述 --> Share  #提交到Github，首次需输入GitHub用户名密码#
上传成功后IDEA右下角会给出提示
```


# gitBucket使用指南

## 用户设置

登陆后点击界面右上角 ‘头像’ 下拉框选项

* Your prifile ：可以看到个人所属工作团队、个人创建的Repository、个人日常操作记录

* Account settings ：修改个人资料，可修改密码

## 创建Repository

后点击界面右上角 ‘+’ 下拉框选项

* new repository ：可设置public创建公有库，也可以设置private私有库，最好新repository选择创建'README'

* new group : 创建工作组

## 个人仓库Settings

注意：只有本人账号创建的Repository才能进行Settings设置

* Options : 修改Repository原始设置

* Collaborators : 添加对该Repository可操作权限的用户和用户组

* Branches : 修改Repository分支

* 删除Repository ：选择需要删除的个人Repository -> Settings -> Danger Zone -> Delete this repository


# 异常关注

## win环境第一次会报错

```bash
错误提示：SSL certificate problem: self signed certificate

错误分析：windows下出现频率高，应该是Git本身是基于linux开发的，在windows上使用容易缺失一些环境 

解决方案（直接不管SSL）：
$ git config --global http.sslVerify false
```


## 重新输入保存的提交凭证

第一次输入提交凭证后会默认保存之后不用重复输入，但是修改凭证后需要重新输入，就需要执行以下命令：

```bash
$ git config --list #可查看总配置#
$ git config --global credential.helper ''
```

# windows环境操作

``Git Bash``打开命令窗口.

```bash
$ mkdir GitWorkSpaces #新建文件夹#
$ cd GitWorkSpaces
$ git clone https://serverip:port/gitbucket/git/root/xxx.git #第一次下载远程仓库到本地#
$ cd xxx
$ git pull --rebase origin master #代码合并使本地和远程同步#
$ git add . #将代码从工作区提交到暂存区#
$ git commit -m "注释" #将代码从暂存区提交到版本库#
$ git remote add origin https://serverip:port/gitbucket/git/root/xxx.git #指定当前远程分支#
$ git push -u origin master #将版本库中的代码提交到远程分支#
```

辅助命令

```bash
$ git init 初始化本地仓库
$ git status 查看状态
$ git branch 查看本地所有分支
$ git reflog 查看所有版本号
$ git reset --hard [head] 回退到指定版本 
$ git log 查看提交日志
$ git diff 查看代码修改
$ git merge 分支合并
```