---
title: 小米5Root教程
date: 2017-02-24 13:59:18
tags:
- 手机
- root
categories: 
- Tool
---
小米手机5 亲测刷机教程

<!--more-->

# 前言

* root小米5并没有想象的那么简单，为了符合google的android安全规范，官方不仅锁定了bootlodaer(即后面提到的BL锁)，还锁定了system区

* 稳定版MIUI不支持官方root，开发版MIUI在解锁BL后可以进入“安全中心—授权管理”中，按提示开启root权限

* MIUI官方不允许修改system下的系统文件，如果解锁了BL，但是没有解锁system分区就刷入第三方REC强行root会导致手机卡米

* 笔者在解锁BL后便立即刷入第三方Rec，导致卡米且Rec界面也卡住了，无法进行点击操作，并且对后面开发版MIUI解锁system也有影响

* 正文部分是笔者亲测刷开发版MIUI8获取root的全过程

# 正文

## 解BL锁

> BL全称为bootloader，他是限制用户刷第三方ROM和第三方recovery以及限制root的“锁”.

* 解锁地址：  [<font face="Times New Roman" color=#0099ff>MIUI官网</font>](http://www.miui.com/)

* 进入MIUI官网后点击导航中的<font color=#0099ff>解锁</font>，然后按步骤：申请解锁权限-->下载解锁工具-->连接电脑按提示操作解锁

![png1](/img/20170224_1.png)

* 申请通过会收到一条短信提醒，申请理由中可尝试填写项目测试需要，笔者亲测等待1个小时左右便收到了短信，获得解锁资格之后就可以下载解锁工具了，下载后并安装

![png2](/img/20170224_2.png)

* 安装完成后如下图：双击运行解锁工具（MiFlashUnlock.exe），同意解锁协议，在需要解锁的手机设备中登录已经具备解锁权限的小米帐号

![png3](/img/20170224_3.png)

* 将手机关机，然后先按住“音量减键”再按“电源键”，直至进入FastBoot模式（也称Bootloader模式），在PC端的小米解锁工具上，登录相同的具备解锁权限的小米帐户，并通过USB连接手机

![png4](/img/20170224_4.png)

* 通过解锁验证后点击<font face="Times New Roman" color=#0099ff>解锁</font>，预计10秒钟左右完成解锁，解锁过程中请勿移除手机，直到界面显示解锁成功为止

![png5](/img/20170224_5.png)

## 线刷MIUI开发版

> 解BL锁成功后，下载开发版MIUI8完整刷机包和MIFlash刷机工具

* 下载地址：  [<font face="Times New Roman" color=#0099ff>MIUI8开发版</font>](http://www.miui.com/download-313.html)

* 工具地址：  [<font face="Times New Roman" color=#0099ff>MIFlash刷机工具</font>](http://download.csdn.net/detail/weixin_37479489/9763090)

* 下载完解压MIUI开发版刷机包，按步骤安装并运行MIFlash工具，点击<font face="Times New Roman" color=#0099ff>浏览</font>按钮选择解压后的刷机包文件

![png6](/img/20170224_6.png)

* 将小米5关机后，先按住“音量减键”再按“电源键”，直至进入FastBoot模式，并在此模式下通过USB与电脑相连

* 接下来在MiFlash工具界面中，先点击<font face="Times New Roman" color=#0099ff>刷新</font>按钮，以确保程序正常识别小米5，接着再点击<font face="Times New Roman" color=#0099ff>刷机</font>按钮，等待刷机进度条的完成

![png7](/img/20170224_7.png)

* 手机自动重启后授权管理中会多一项ROOT权限管理，设置-->授权管理-->ROOT权限管理-->开启ROOT，到这一步还没有真正取得ROOT权限，因为system分区是锁着的，需要解锁system

## 解锁system

* 注意：如果你的手机之前刷过第三方Rec的话，可能会因为关闭boot校验导致之前只读的system无法正常解锁，需要在手机上完成如下操作：设置-->更多设置-->备份和重置-->恢复出厂设置-->恢复手机出厂设置

* 下载并安装小米助手，下载地址：   [<font face="Times New Roman" color=#0099ff>小米助手</font>](http://zhushou.xiaomi.com/)

* 打开小米手机助手安装文件所在位置（默认是这个位置C:\Users\lf\AppData\Local\MiPhoneManager\main）其中lf是你的用户名，鼠标放到空白处，按住键盘的shift键不要放开，点击鼠标右键，如图，选择在此处打开命令窗口

![png8](/img/20170224_8.png)

* 然后将手机通过USB连接电脑，输入adb root 回车，测试手机root权限

``` 
C:\Users\lf\AppData\Local\MiPhoneManager\main>adb root
adbd is already running as root
```

* 再输入 adb disable-verity 回车，解锁system

``` 
C:\Users\lf\AppData\Local\MiPhoneManager\main>adb disable-verity
Verity disabled on /system
Now reboot your device for setting to take effect
```

* 若出现以上结果，说明system已经解锁成功，输入adb reboot重启手机

``` 
C:\Users\lf\AppData\Local\MiPhoneManager\main>adb reboot
```

* 解锁后的system还是只读的权限，需要输入以下命令获得读写的权限

```
mac$ adb shell
xiaomi$ su
xiaomi# busybox mount -o remount,rw /system
```

到此，小米5root全过程已全部完成.