---
title: Mac基础环境配置
date: 2017-09-11 19:43:01
tags:
- Mac
categories: 
- Mac
---

记录Mac中的基础环境配置

<!--more-->

## 基础

### 访达

```bash
shift+command+p 去除访达右侧
```



## 终端

### 创建环境变量文件

打开iTerm2终端，创建.bash_profile文件，防止后面安装homebrew时报错.

```bash
cd ~
ls -al
若不存在 .bash_profile文件则创建
touch .bash_profile
```

```bash
###ROOT PATH
export GIT_HOME=/usr/local/opt/git
export MVN_HOME=/usr/local/opt/maven
export TOMCAT_HOME=/usr/local/opt/tomcat@8
export PY_HOME=/usr/local/opt/python3

###JDK VERSION
# export JAVA_HOME=/usr/local/jdk7
export JAVA_HOME=/usr/local/jdk8

###EXPORT PATH
export PATH=$JAVA_HOME/bin:$GIT_HOME/bin:$MVN_HOME/bin:$TOMCAT_HOME/bin:$PY_HOME/bin:$PATH
export CLASSPATH=.:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar

###PY Virtual Env Config
export WORKON_HOME='~/.virtualenvs'
export VIRTUALENVWRAPPER_PYTHON='/usr/local/bin/python3'
#export VIRTUALENVWRAPPER_PYTHON=PY_HOME/bin/python3
source /usr/local/bin/virtualenvwrapper.sh
```

## iTerm2

点击 [<font face="Times New Roman" color=#0099ff size=4>iTerm2官网</font>](https://www.iterm2.com/downloads.html) 下载，双击下载后的文件，拖到Applications目录中即可打开使用.

### lrzsz插件

在iTerm2中安装lrzsz插件，使用 ``rz sz`` 命令可以完成FTP的上传下载功能.

```bash
Stefan-Mac:/ stefan$ mkdir /usr/local/Repository
Stefan-Mac:/ stefan$ cd /usr/local/Repository
###下载iterm2-zmodem
Stefan-Mac:Repository stefan$ git clone https://github.com/mmastrac/iterm2-zmodem.git
###查看使用说明
Stefan-Mac:Repository stefan$ more iterm2-zmodem/README.md
0. Install lrzsz on OSX: `brew install lrzsz`
1. Save the `iterm2-send-zmodem.sh` and `iterm2-recv-zmodem.sh` scripts in `/usr/local/bin/`
2. Set up Triggers in iTerm2

###安装lrzsz
Stefan-Mac:/ stefan$ brew install lrzsz
Stefan-Mac:/ stefan$ sudo mv /usr/local/Repository/iterm2-zmodem/iterm2-recv-zmodem.sh /usr/local/bin/
Stefan-Mac:/ stefan$ sudo mv /usr/local/Repository/iterm2-zmodem/iterm2-send-zmodem.sh /usr/local/bin/

###与iTerm2集成
iTerm2 --> Preferences --> Profiles --> Advanced --> Triggers --> Edit

\*\*B0100             Run Silent Coprocess  /usr/local/bin/iterm2-send-zmodem.sh  √
\*\*B00000000000000   Run Silent Coprocess  /usr/local/bin/iterm2-recv-zmodem.sh  √

###上传下载交互的远程服务器中也要安装lrzsz，然后iTerm2登陆远程，使用rz命令弹出文件夹框就可以选择本地文件上传了
# sudo yum install -y lrzsz
# rz
```

## Homebrew

### 安装Homebrew

进入 [<font face="Times New Roman" color=#0099ff size=4>homebrew官网</font>](https://brew.sh/) 复制如下官网最新的下载命令，打开iTerm2终端粘贴运行该命令.

```bash
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
```

输入以上命令后可能会报如下错误：

```bash
xcode-select: error: invalid developer directory '/Library/Developer/CommandLineTools'
Failed during: /usr/bin/sudo /usr/bin/xcode-select --switch /Library/Developer/CommandLineTools
```

因为Homebrew的安装依赖Xcode的编译器，需要正确指定路径，然后重新下载安装.

```bash
###验证xcode的命令行工具CommandLineTools安装路径
Stefan-Mac:~ stefan$ xcode-select -p
/Applications/Xcode.app/Contents/Developer

###指定正确路径
Stefan-Mac:~ stefan$ sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer

###重新安装Homebrew
Stefan-Mac:~ stefan$ /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
==> This script will install:
/usr/local/bin/brew
/usr/local/share/doc/homebrew
/usr/local/share/man/man1/brew.1
/usr/local/share/zsh/site-functions/_brew
/usr/local/etc/bash_completion.d/brew
/usr/local/Homebrew

Press RETURN to continue or any other key to abort
==> /usr/bin/sudo /bin/mkdir -p /Library/Caches/Homebrew
Password:
==> /usr/bin/sudo /bin/chmod g+rwx /Library/Caches/Homebrew
==> /usr/bin/sudo /usr/sbin/chown stefan /Library/Caches/Homebrew
==> Downloading and installing Homebrew...
HEAD is now at 3c3b05d45 Merge pull request #4564 from reitermarkus/not-a-cask-file-error
==> Cleaning up /Library/Caches/Homebrew...
==> Migrating /Library/Caches/Homebrew to /Users/stefan/Library/Caches/Homebrew...
==> Deleting /Library/Caches/Homebrew...
Already up-to-date.
==> Installation successful!

==> Homebrew has enabled anonymous aggregate user behaviour analytics.
Read the analytics documentation (and how to opt-out) here:
  https://docs.brew.sh/Analytics.html

==> Next steps:
- Run `brew help` to get started
- Further documentation:
    https://docs.brew.sh

###安装成功验证
Stefan-Mac:~ stefan$ brew --version
Homebrew 1.7.1
Homebrew/homebrew-core (git revision 4d46; last commit 2018-07-29)
```

安装过程中有可能出现如下错误，是因为网络访问原因，重新多试几次总会成功的.

```bash
HEAD is now at 3c3b05d45 Merge pull request #4564 from reitermarkus/not-a-cask-file-error

fatal: unable to access 'https://github.com/Homebrew/brew/': LibreSSL SSL_read: SSL_ERROR_SYSCALL, errno 54
Error: Fetching /usr/local/Homebrew failed!
==> Tapping homebrew/core
Cloning into '/usr/local/Homebrew/Library/Taps/homebrew/homebrew-core'...
fatal: unable to access 'https://github.com/Homebrew/homebrew-core/': LibreSSL SSL_read: SSL_ERROR_SYSCALL, errno 54
Error: Failure while executing; `git clone https://github.com/Homebrew/homebrew-core /usr/local/Homebrew/Library/Taps/homebrew/homebrew-core --depth=1` exited with 128.
Error: Failure while executing; `/usr/local/bin/brew tap homebrew/core` exited with 1.
Failed during: /usr/local/bin/brew update --force
```

* Homebrew的安装路径: /usr/local/
* brew install软件安装路径: /usr/local/Cellar/
* brew install软件安装路径软链接: /usr/local/opt/
* brew install软件执行命令软链接: /usr/local/bin/


### 替换国内镜像源

以下镜像是Homebrew的formula索引的镜像（即``brew update``时所更新内容），镜像源来自清华大学开源软件镜像站。

```bash
cd "$(brew --repo)"
git remote set-url origin https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git

cd "$(brew --repo)/Library/Taps/homebrew/homebrew-core"
git remote set-url origin https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git

brew update
```


### Homebrew使用命令

* brew list            查看安装软件列表
* brew tap             查看安装的扩展列表
* brew tap xxx         安装扩展
* brew search xxx      搜索软件
* brew install xxx     安装软件，安装时会自动执行link操作
* brew install xxx --overwrite  会先删除旧的symlink，再进行新的link操作
* brew uninstall xxx   卸载软件
* brew upgrade xxx     更新指定软件
* brew update          更新所有软件 
* brew cache clean     清楚缓存
* brew cleanup         删除所有程序
* brew cleanup xxx     删除指定软件
* brew options xxx     查看软件安装选项
* brew info xxx        显示软件信息
* brew home xxx        用浏览器打开官方网站
* brew deps xxx        查看软件依赖
* brew outdated        查看哪些需要更新
* brew doctor      检测异常
* brew prune xxx   清理无用的symlink，且清理与之相关的位于/Applications和~/Applications中的无用App链接
* brew link xxx    将指定软件的安装文件symlink linking到Homebrew上，自定义安装的需要手动执行link操作

### 卸载Homebrew

卸载只需要将安装命令中的install 改成 uninstall.

```bash
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/uninstall)"
```

### Homebrew-cask

Homebrew主要用于下载一些不带界面的命令行工具和第三方库来进行二次开发.

Homebrew-cask主要用来下载一些带界面的应用软件，下载好后会自动安装，并能在mac中直接运行使用，是基于Homebrew的一个增强工具.

如：

* brew install curl 安装curl第三方库进行开发
* brew cask install google-chrome 安装谷歌浏览器应用

``brew cask`` 用做对官方AppStore的补充，是一个众多贡献者们维护的非苹果官方软件商店，可以在这里下载没有在AppStore商店上架的Mac软件，我们就可以在brew cask中下载.

```bash
###Homebrew安装Homebrew-cask
brew install brew-cask-completion

###下载
brew cask install xxx
###列出所有可以被安装的软件
brew cask search
###卸载
brew cask uninstall xxx
```

### tree

```bash
brew install tree

###使用tree命令查看文件层级关系
tree
```


## Git

Mac系统自带原生安装Git，默认安装在 ``/usr/bin/git`` 中，因为Mac防止恶意入侵，加入了Rootless机制，禁止操作/usr/bin/目录中文件，会出现Operation not permitted错误不易卸载，通过下面其他方式安装覆盖原生的Git版本就行.

```bash
Stefan-Mac:~ stefan$ git --version
git version 2.15.1 (Apple Git-101)
```

### dmg镜像安装Git

从官网下载 ``git-2.15.1-intel-universal-mavericks.dmg`` 镜像安装包，打开后双击 ``git-2.15.1-intel-universal-mavericks.pkg`` 进行界面安装，然后添加PATH.

```bash
###验证Git
Stefan-Mac:~ stefan$ git --version
git version 2.15.1
###查看Mac中所有Git
which -a git
###一个命令卸载Git
/usr/local/git/uninstall.sh
```

### Homebrew安装Git

同样也可以使用Homebrew软件管理工具下载管理或卸载Git.

```bash
###发现安装前会自动更新Homebrew，ControlC后不影响Git下载
Stefan-Mac:~ stefan$ brew install git
Updating Homebrew...

^C
==> Downloading https://homebrew.bintray.com/bottles/git-2.18.0.high_sierra.bottle.tar.gz
######################################################################## 100.0%
==> Pouring git-2.18.0.high_sierra.bottle.tar.gz
Error: An unexpected error occurred during the `brew link` step
The formula built, but is not symlinked into /usr/local
Permission denied @ unlink_internal - /usr/local/share/man/man5/gitattributes.5
Error: Permission denied @ unlink_internal - /usr/local/share/man/man5/gitattributes.5

###执行一下命令在当前窗口会禁止自动更新Homebrew
Stefan-Mac:~ stefan$ export HOMEBREW_NO_AUTO_UPDATE=true
Stefan-Mac:~ stefan$ brew install git
==> Downloading https://homebrew.bintray.com/bottles/git-2.18.0.high_sierra.bottle.tar.gz
Already downloaded: /Users/stefan/Library/Caches/Homebrew/git-2.18.0.high_sierra.bottle.tar.gz
==> Pouring git-2.18.0.high_sierra.bottle.tar.gz
Error: An unexpected error occurred during the `brew link` step
The formula built, but is not symlinked into /usr/local
Permission denied @ unlink_internal - /usr/local/share/man/man5/gitattributes.5
Error: Permission denied @ unlink_internal - /usr/local/share/man/man5/gitattributes.5
```

但是又出现了新问题，使用doctor查看解决方案.

```bash
Stefan-Mac:~ stefan$ brew doctor
Please note that these warnings are just used to help the Homebrew maintainers
with debugging if you file an issue. If everything you use Homebrew for is
working fine: please don not worry or file an issue; just ignore this. Thanks!

Warning: You have unlinked kegs in your Cellar
Leaving kegs unlinked can lead to build-trouble and cause brews that depend on
those kegs to fail to run properly once built. Run `brew link` on these:
  git

Warning: Broken symlinks were found. Remove them with `brew prune`:
  /usr/local/share/man/man3/Git.3pm
  /usr/local/share/man/man3/Git::I18N.3pm
  /usr/local/share/man/man3/Git::SVN::Editor.3pm
  /usr/local/share/man/man3/Git::SVN::Fetcher.3pm
  /usr/local/share/man/man3/Git::SVN::Memoize::YAML.3pm
  /usr/local/share/man/man3/Git::SVN::Prompt.3pm
  /usr/local/share/man/man3/Git::SVN::Ra.3pm
  /usr/local/share/man/man3/Git::SVN::Utils.3pm
  /usr/local/share/man/man5/gitattributes.5
  /usr/local/share/man/man5/githooks.5
  /usr/local/share/man/man5/gitignore.5
  /usr/local/share/man/man5/gitmodules.5
  /usr/local/share/man/man5/gitrepository-layout.5
  /usr/local/share/man/man5/gitweb.conf.5
  /usr/local/share/man/man7/gitcli.7
  /usr/local/share/man/man7/gitcore-tutorial.7
  /usr/local/share/man/man7/gitcredentials.7
  /usr/local/share/man/man7/gitcvs-migration.7
  /usr/local/share/man/man7/gitdiffcore.7
  /usr/local/share/man/man7/giteveryday.7
  /usr/local/share/man/man7/gitglossary.7
  /usr/local/share/man/man7/gitnamespaces.7
  /usr/local/share/man/man7/gitrevisions.7
  /usr/local/share/man/man7/gitsubmodules.7
  /usr/local/share/man/man7/gittutorial-2.7
  /usr/local/share/man/man7/gittutorial.7
  /usr/local/share/man/man7/gitworkflows.7

###先清理无用symlink
Stefan-Mac:~ stefan$ brew prune git
Pruned 27 symbolic links and 3 directories from /usr/local
###然后创建新的软链
Stefan-Mac:~ stefan$ brew link git
Linking /usr/local/Cellar/git/2.18.0... 1110 symlinks created

Stefan-Mac:~ stefan$ brew doctor
Your system is ready to brew.
```

Homebrew 先将下载并已编译好的二进制包 ``git`` 存到缓存目录  ``/Users/stefan/Library/Caches/Homebrew/git-2.18.0.high_sierra.bottle.tar.gz`` ；然后解压 ``git-2.18.0.high_sierra.bottle.tar.gz`` 到 ``/usr/local/Cellar/git/`` 目录，根据版本存放到文件夹 ``2.18.0`` 下；最后将 ``/usr/local/Cellar/git/2.18.0/bin/git`` 软链到 ``/usr/local/bin/git`` ，环境变量中存后者，执行git命令时，真正调用的是其在 ``Cellar`` 中的真身.

```bash
###查看
Stefan-Mac:~ stefan$ brew list
git
###卸载
Stefan-Mac:~ stefan$ brew uninstall git
Uninstalling /usr/local/Cellar/git/2.18.0...
```

## JDK

官网下载对应版本的jdk的dmg文件，双击运行安装.

### 配置Path

```bash
###默认安装路径太长，新建软连接
Stefan-Mac:Home stefan$ ln -s /Library/Java/JavaVirtualMachines/jdk1.7.0_80.jdk/Contents/Home /usr/local/jdk7
ln: /usr/local/java7: Permission denied
Stefan-Mac:Home stefan$ sudo ln -s /Library/Java/JavaVirtualMachines/jdk1.7.0_80.jdk/Contents/Home /usr/local/jdk7
```

## Maven

### Homebrew下载指定版本

以Maven为例，介绍如何使用Homebrew安装指定版本的软件，因为Homebrew在 ``brew install`` 时是默认安装最新的软件版本.

```bash
###使用brew info查看maven的最新版本信息
Stefan-Mac:/ stefan$ brew info maven
maven: stable 3.5.4
Java-based project management
https://maven.apache.org/
Conflicts with:
  mvnvm (because also installs a 'mvn' executable)
/usr/local/Cellar/maven/3.3.9 (95 files, 9.6MB) *
  Built from source on 2018-08-05 at 15:22:12
From: https://github.com/Homebrew/homebrew-core/blob/master/Formula/maven.rb
==> Requirements
Required: java >= 1.7 ✔

###下载From后的源完整项目到本地
Stefan-Mac:/ stefan$ cd /usr/local/Repository
Stefan-Mac:Repository stefan$ git clone https://github.com/Homebrew/homebrew-core.git

###在当前路径下有个maven.rb的ruby文件，里面关联的是最新的maven版本
Stefan-Mac:Formula stefan$ pwd
/usr/local/Repository/homebrew-core/Formula

###查看Maven的历史提交版本信息，找到需要下载的版本对应commit码的前7位（9a34db5）
Stefan-Mac:Formula stefan$ git log ./maven.rb | less
commit 9a34db5b01bb2535525c6aa676d90a89ba97d416
Author: Jason Tedor <jason@tedor.me>
Date:   Wed Nov 18 08:06:28 2015 -0500

    maven 3.3.9

    Closes Homebrew/homebrew#46113.

    Signed-off-by: Dominyk Tiller <dominyktiller@gmail.com>

###切换到对应的commit版本
Stefan-Mac:Formula stefan$ git checkout 9a34db5

###再次查看maven.rb文件，发现已经修改成了需要下载的版本（3.5.4-->3.3.9）
Stefan-Mac:Formula stefan$ more ./maven.rb
class Maven < Formula
  desc "Java-based project management"
  homepage "https://maven.apache.org/"
  url "https://www.apache.org/dyn/closer.cgi?path=maven/maven-3/3.3.9/binaries/apache-maven-3.3.9-bin.tar.gz"
  mirror "https://archive.apache.org/dist/maven/maven-3/3.3.9/binaries/apache-maven-3.3.9-bin.tar.gz"
  sha256 "6e3e9c949ab4695a204f74038717aa7b2689b1be94875899ac1b3fe42800ff82"

###最后就可以使用更改后的ruby文件下载
Stefan-Mac:Formula stefan$ brew install ./maven.rb
```

### 配置Maven

修改仓库路径及镜像源地址.





