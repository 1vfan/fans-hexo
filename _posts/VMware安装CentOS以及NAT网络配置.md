---
title: VMware安装CentOS以及NAT网络配置
date: 2017-04-02 19:43:01
tags:
- CentOS
- VMware
- Linux
- NAT
categories: 
- Linux
---

记录VMware虚拟机中安装CentOS 7.0版本以及使用NAT模式实现虚拟机联网

<!--more-->

# 前期准备

* 已安装VMware Workstation

* 已下载CentOS的iso镜像，笔者安装版本是CentOS7.0 --> CentOS-7-x86_64-DVD-1511.iso

# NAT模式网络配置

三种网络连接方式：host-only、桥接、NAT

![png1](/img/20170402_1.png)

> host-only

* 使用VMnet1网卡，只能和主机相互通信，不能上网，不能访问其他主机
* 虚拟机连接到VMnet1上，但系统并不为其提供任何路由服务，因此虚拟机只能和宿主机进行通信，而不能连接到真正的网络上，用于建立与外部隔离的网络环境

> 桥接

* 使用VMnet0虚拟网卡，虚拟机和主机是处于同等地位的机器，所以网络功能也无异于主机，并且和主机处于同一网段
* vmnet0实际上就是一个虚拟的网桥(2层交换机)，这个网桥有若干个接口，一个端口用于连接你的Host主机，其余端口可以用于连接虚拟机，他们的位置是对等的，谁也不是谁的网关，所以桥接模式下，虚拟机和Host主机是同等地位的主机

> NAT

* 使用VMnet8网卡，网络地址转换类似于家庭路由器的方式工作；使用NAT模式，就是让虚拟系统借助NAT（网路地址转换）功能，通过宿主机器所在的网络来访问公网

虚拟机1和2能相互通信，主机A和虚拟机1和2能相互通信，虚拟机1和2能访问主机B和外网，主机B不能访问虚拟机1和2

![png2](/img/20170402_2.png)

## 配置VMware

依次打开VMware虚拟机 -> 编辑 -> 虚拟网络编辑器，选择VMnet8后根据图中标示开始配置

![png2](/img/20170402_3.png)

```bash
选择NAT模式
选择主机虚拟适配器连接到此网络，并使用本地DHCP服务将IP地址分配给虚拟机
配置子网：192.168.154.0 （以后所有的虚拟机ip都应该在这个网段上）
NAT设置
DHCP设置
```
NAT设置:配置好自己的网关即可（192.168.154.2）

![png2](/img/20170402_4.png)

设置DHCP（指定开始ip地址：192.168.154.10和结束ip地址：192.168.154.254）

![png2](/img/20170402_5.png)

## 配置本地Windows

打开本地网络适配器，选择VMware Virtual Ethernet Adapter for VMnet8（专用于NAT模式），更改其协议属性

![png2](/img/20170402_6.png)

# 安装配置CentOS

## 新建并配置虚拟机

```bash
新建虚拟机
标准类型配置，创建一个虚拟空白硬盘
操作系统选择Linux，版本选择CentOS 64-bit
自定义一个虚拟机名称（es154.10），位置最好手动选择（E:\VMware\es154.10）
最大磁盘空间默认20G即可，之后可以增加
定制硬件
内存：2048M/2G
处理器：数量1，核数4，勾选'虚拟化Intel VT-x/EPT 或 AMD-v/RVI(V)'
硬盘：20G
CD/DVD：勾选'打开电源时连接'，选择'使用ISO镜像文件'，浏览中选择本地下载好的CentOS7.0镜像文件
网络适配器：勾选'打开电源时连接'，选择自定义（指定的虚拟网络）--> 选择VMnet8（NAT）
其他保持默认即可，完成配置
```

## 启动配置

目前Inter和AMD生产的主流CPU都支持虚拟化技术，但很多电脑或主板BIOS出厂时默认禁用虚拟化技术，所以首次启动linux系统时报错就需要手动启用电脑的虚拟化，具体步骤如下：

```bash
重启电脑，按Fn+F2进入BIOS界面（不同主板型号进入BIOS所需按键不同，笔者电脑为lenovo ThinkPad E450）
Configuratio -> Intel Virtual Technology -> Enabled
F10保存BIOS设置并重启电脑
```

成功启动，进入CentOS可视化安装界面

```bash
软件选择：默认‘最小安装’ --> 改成‘基础设施服务器’（最小安装会导致很多系统命令无法使用）
安装位置：默认‘sda’，‘自动分区’
网络和主机名：以太网口默认关闭。若开启，会自动分配ip，如下图所示；若关闭，则需要手动在系统启动后配置ifcfg-ens33文件
用户名密码：安装过程中可以给root分配密码，也可创建普通用户
```
![png2](/img/20170402_7.png)

## 网络配置

### windows环境

本片介绍手动配置ip的过程，所以安装时不开启ens33网口，启动后ifconfig，发现网卡没有ip，暂时无法用Xshell远程连接，开始配置网络

```bash
# vim /etc/sysconfig/network-scripts/ifcfg-ens33
添加
IPADDR=192.168.154.10
NETMASK=255.255.255.0
GATEWAY=192.168.154.2
DNS1=8.8.8.8
DNS2=8.8.4.4
ONBOOT=yes

# cat /etc/sysconfig/network-scripts/ifcfg-ens33 
TYPE=Ethernet
NAME=ens33
UUID=ba522d42-4e37-4012-b9ed-743665e7a880
DEVICE=ens33
IPADDR=192.168.154.10
NETMASK=255.255.255.0
GATEWAY=192.168.154.2
DNS1=8.8.8.8
DNS2=8.8.4.4
ONBOOT=yes

# cat /etc/sysconfig/network
NETWORKING=yes
HOSTNAME=elastic1

# service network restart
Restarting network (via systemctl):                        [  确定  ]

以上配置后最好重启下

# ping www.baidu.com
PING www.a.shifen.com (115.239.210.27) 56(84) bytes of data.
64 bytes from 115.239.210.27: icmp_seq=1 ttl=128 time=19.5 ms
64 bytes from 115.239.210.27: icmp_seq=2 ttl=128 time=10.2 ms
```

### Mac环境

```bash
###查看虚拟机适配器
Stefan-Mac:/ stefan$ ifconfig
vmnet8: flags=8863<UP,BROADCAST,SMART,RUNNING,SIMPLEX,MULTICAST> mtu 1500
  ether 00:50:56:c0:00:08
  inet 172.16.114.1 netmask 0xffffff00 broadcast 172.16.114.255

###自定义IP地址，删除dhcp，防止ip变化
[root@Master ~]# cat /etc/sysconfig/network-scripts/ifcfg-ens33
TYPE=Ethernet
IPADDR=172.16.114.131
NETMASK=255.255.255.0
GATEWAY=172.16.114.2
DNS1=8.8.8.8
DNS2=8.8.4.4
NAME="ens33"
UUID="bd3d5adt-fd26-4e09-9744-32b377755900"
DEVICE="ens33"
ONBOOT="yes"

###新增网络设置
[root@Master ~]# cat /etc/sysconfig/network
NETWORKING=yes
HOSTNAME=Master

[root@Master ~]# service network restart
Restarting network (via systemctl):                        [  确定  ]
```

## 错误情况

网络不可达

```bash
# ping baidu.com
ping: unknown host baidu.com
# ping 115.239.211.112
connect: 网络不可达

解决方案（有可能是网卡中内容没有填写正确仔细检查，笔者就是网关名写错了，也可将网关添加到network中）：
# echo "GATEWAY=192.168.154.2" >> /etc/sysconfig/network
```

配置后ifconfig发现网卡ip与ifcfg-en333配置文件中配置的IPADDR不一致，由于笔者修改了ifcfg-en333文件中的UUID

解决方案：恢复原来的UUID，修改后3位不会出现类似问题


## 防火墙设置

CentOS7.0默认使用firewall做防火墙，而不是iptables，部分集群需要关闭防火墙

```bash
[root@elastic2 /]# firewall-cmd --state
running
[root@elastic2 /]# systemctl stop firewalld.service
[root@elastic2 /]# firewall-cmd --state
not running
[root@elastic2 /]# systemctl disable firewalld.service
Removed symlink /etc/systemd/system/dbus-org.fedoraproject.FirewallD1.service.
Removed symlink /etc/systemd/system/basic.target.wants/firewalld.service.
[root@elastic2 /]# firewall-cmd --state
not running
```