---
title: Hexo3.0 + github搭建个人博客
date: 2017-02-15 11:09:31
tags:
- Hexo
- Github
categories: 
- Tool
---
windows10 环境搭建 Hexo3 + Github 完整教程

<!--more-->

# 系统环境配置
使用Hexo的前提是需要在系统环境中安装Git和Node.js.
## 安装Git
作用：将本地的Hexo内容提交到Github上.
下载地址：  [<font face="Times New Roman" color=#0099ff>Git</font>](http://download.csdn.net/download/weixin_37479489/9755827)
在任意位置点击鼠标右键，出现<font face="Times New Roman" color=#0099ff>Git Bash Here</font> 选项即为安装成功.
## 安装Node.js	
作用：生成静态网页.
下载地址：  [<font face="Times New Roman" color=#0099ff>Node.js</font>](http://www.runoob.com/nodejs/nodejs-install-setup.html)
建议安装完毕后重启电脑，否则后面安装Hexo时会提示无效的命令，或者等到后面遇到问题再重启也可以.
# Hexo
Hexo是一个简单地、轻量地、基于Node的一个静态博客框架，可以方便的生成静态网页托管在Github上.
## Hexo命令
介绍一些常用的hexo命令及常用简写（ps：#号后为注释部分）
``` bash
$ hexo g  #完整命令为hexo generate，用于生成静态文件，会在当前目录下生成一个新的叫public的文件夹
$ hexo s  #完整命令为hexo server，用于启动本地Web服务器，主要用来本地博客预览
$ hexo d  #完整命令为hexo deploy，用于将本地博客文件发布到github平台上
$ hexo n  #完整命令为hexo new "new name"，用于新建一篇文章
$ hexo new page pagename  #创建新页面，编码用UTF-8保存，否则会报错无法更新成功到github
$ hexo clean  #清除缓存，网页正常情况下可以忽略此条命令
```
## 安装Hexo
Node和Git都安装好后,鼠标右键任意地方，选择<font face="Times New Roman" color=#0099ff>Git Bash Here</font>，使用以下命令安装Hexo（ps：实际输入命令只需输入$ 后面的命令即可，-g是指全局安装Hexo）
``` bash
$ npm install hexo-cli -g
```
如果在之后的安装过程中报了如下错误
``` bash
ERROR Deployer not found : github
```
则运行以下命令,或者你直接先运行这个命令更好
``` bash
$ npm install hexo-deployer-git --save
$ hexo g
$ hexo d
```
接着创建放置博客文件的文件夹：hexo文件夹.在自己想要的位置创建文件夹，如我hexo文件夹的位置为<font face="Times New Roman" color=#0099ff>D:\hexo</font>，名字和地方可以自由选择，当然最好不要放在中文路径下.然后进入文件夹，即<font face="Times New Roman" color=#0099ff>D:\hexo</font>内，点击鼠标右键，选择<font face="Times New Roman" color=#0099ff>Git Bash Here</font>，执行以下命令，Hexo会自动在该文件夹下下载搭建网站所需的所有文件.
``` bash
$ hexo init
```
安装依赖包
``` bash
$ npm install
```
在<font face="Times New Roman" color=#0099ff>D:\hexo</font>内执行以下命令
``` bash
$ cd D:/hexo
$ hexo g
$ hexo s
```
然后在浏览器中访问[<font face="Times New Roman" color=#0099ff>http://localhost:4000/</font>](http://localhost:4000/) ，此时可以看到跟下图一样简洁优雅的博客主页了，当然这个只是提供本地预览使用.
![png1](/img/20170215_1.png)

# 注册Github账号
注册地址：  [<font face="Times New Roman" color=#0099ff>Github</font>](https://github.com/)
注册过程不多赘述，记好用户名、邮箱和密码.

# 创建Repository
Repository相当于一个仓库，用来放置你的项目文件.首先，登陆Github进入个人页面，按下图红框标识操作New一个Repository.创建时，只需要填写Repository name即可，当然这个名字的格式必须为<font face="Times New Roman" color=#0099ff>Owner</font>.github.io，例如我的为<font face="Times New Roman" color=#0099ff>1vfan.github.io</font>
![png2](/img/20170217_1.png)

# SSH keys
我们如何让本地Git项目文件与远程的Github建立联系呢？使用SSH keys这种配置方式在发布时不需要输入密码，也是我目前使用的方法.

## 检查SSH keys
首先我们需要检查系统环境中现有的ssh key，右键任意位置选择<font face="Times New Roman" color=#0099ff>Git Bash Here</font>，输入以下命令
``` bash
ls -al ~/.ssh
```
如果显示 <font face="Times New Roman" color=#ff0000>No such file or directory</font>. 说明你是第一次使用Git就没有关系；如果存在的话，直接删除.ssh文件夹里面所有文件.
![png3](/img/20170217_2.png)

## 配置config.yml
在<font face="Times New Roman" color=#0099ff>D:/hexo/</font>路径下的<font face="Times New Roman" color=#0099ff>_config.yml</font>文件的最下方修改deploy字段，命令中的第一个<font face="Times New Roman" color=#0099ff>1vfan</font>为Github的用户名，第二个<font face="Times New Roman" color=#0099ff>1vfan</font>为之前New的Repository的名字，记得改成自己的 (ps：Hexo的配置文件中任何冒号后面都是带一个空格的，如果配置以下命令出现<font face="Times New Roman" color=#ff0000>ERROR Deployer not found : github</font>，参考上文的解决方法)
``` bash
type: git
repository: git@github.com:1vfan/1vfan.github.io.git
branch: master
```

## 配置SSH keys
右键任意位置选择<font face="Times New Roman" color=#0099ff>Git Bash Here</font>
``` bash
$ ssh-keygen -t rsa -C "your_email@youremail.com"
```
后面的 your_email@youremail.com 改为你自己申请Github账号时的邮箱(ps：此处的「-C」的是大写的「C」)
``` bash
Generating public/private rsa key pair.
Enter file in which to save the key (/Users/your_user_directory/.ssh/id_rsa):
```
需要你输入地址，但是没有必要输入，敲回车键保存到默认路径就好
``` bash
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
```
需要你输入隐私密码，这个密码会在你提交项目文件时使用，防止别人往你的项目里提交内容，如果提交项目时不想输密码则同上敲回车键就好.
看到如下界面，同时在系统环境<font face="Times New Roman" color=#0099ff>C:\Users\Administrator\.ssh\</font>路径下有生成id_rsa和id_rsa.pub文件，证明配置成功了SSH keys
![png4](/img/20170217_3.png)
然后输入以下命令
``` bash
$ ssh-agent -s
$ ssh-add ~/.ssh/id_rsa
```
如果报了这样的错误 <font face="Times New Roman" color=#ff0000>Could not open a connection to your authentication agent.</font>，则需要执行下面的命令（ps：`是键盘～键上的那个`）
``` bash
$ eval `ssh-agent`
$ ssh-add
```

## 添加SSH Key到GitHub
在本机配置SSH Key成功之后，需要添加到GitHub上以完成SSH链接的设置，打开本地.ssh\id_rsa.pub文件，复制里面的全部内容 (若看不到此文件，需要设置显示隐藏文件)；
登陆Github，参照下图红框圈出部分，点击Settings，选择SSH and GPG Keys -> New SSH Key，title随便填，粘贴刚刚复制的key，点击Add SSH key确认添加，添加成功则如下图蓝框圈出部分所示
![png4](/img/20170217_4.png)

## 测试
输入下面的命令，看看配置是否成功，<font face="Times New Roman" color=#0099ff>git@github.com</font>的部分不要修改
``` bash
$ ssh -T git@github.com
```
如果是下面的这种反馈信息
``` bash
The authenticity of host 'github.com (207.97.227.239)' can't be established.
RSA key fingerprint is 16:27:ac:a5:76:28:2d:36:63:1b:56:4d:eb:df:a6:48.
Are you sure you want to continue connecting (yes/no)?
```
输入yes就好，看到下面的信息就表示已成功连上Github
``` bash
You’ve successfully authenticated， but GitHub does not provide shell access.
```

## 设置用户信息
现在已经可以通过SSH链接到GitHub了，还有一些个人信息需要完善.
Git会根据用户的名字和邮箱来记录提交，GitHub也是用这些信息来做权限的处理，输入下面的代码进行个人信息的设置，把名称和邮箱替换成你自己的（PS：名字必须是你的真名，而不是GitHub的昵称）
``` bash
$ git config --global user.name "real name"  #用户名
$ git config --global user.email  "your email"  #填写自己的邮箱
```

# 总结
至此，Hexo3.0 + Github搭建博客已经基本完成，可以用自己的账号在浏览器中测试，如：<font face="Times New Roman" color=#0099ff>https://1vfan.github.io</font>，如有疑问欢迎在评论中反馈.

















