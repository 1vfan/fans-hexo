# docker

## 基础命令

1.  镜像image(静态的只读文件)

    ```bash
    ###查找
    $ dcoker search ubuntu
    $ docker search --filter=is-official=true ubuntu
    $ docker search --filter=stars=200 ubuntu
    $ docker search --limit 3 ubuntu
    
    ###拉取
    $ docker pull centos
    $ docker pull ubuntu:18.04
    
    ###镜像详细信息：作者、适应架构、各层数字摘要
    $ docker inspect centos
    ###镜像创建历史过程
    $ docker history ubuntu
    ###删除镜像(先删除依赖此镜像的容器)
    $ docker rmi centos
    ###清理临时的遗留镜像文件或未被使用的镜像，释放存储空间
    $ docker image prune
    
    ###新建镜像别名，与之前的image ID相同，指向同一个镜像文件
    $ docker tag centos:latest cs:latest
    $ docker images
    REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
    centos              latest              1e1148e4cc2c        7 days ago          202MB
    cs                  latest              1e1148e4cc2c        7 days ago          202MB
    ```

2. 容器container(是镜像的一个运行实例，包含运行时所需的可写文件层)
    
    ```bash
    $ docker run -itd --name centos_container centos /bin/bash
    
    $ docker ps
    $ docker ps -l
    $ docker ps -a
    
    ###可以使用容器NAME或ID操作容器
    $ docker stop  centos_container
    $ docker start centos_container
    
    ###ctrl+q+p不关闭容器退出
    $ docker attach centos_container
    
    ###关闭容器后删除容器
    $ docker rm centos_container
    ```

3. 创建镜像image(commit、build、import)

    ```bash
    ###commit:基于已有容器创建
    $ docker commit -a 'stefan' -m 'add bash: ifconfig' centos_container centos:1.0.0
sha256:cd691faefd5c0542d0c5159f8203f48e39a913ceeb90f39f81f6c559be58ceaf
$ docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
centos              1.0.0               cd691faefd5c        8 seconds ago       272MB
centos              latest              1e1148e4cc2c        7 days ago          202MB
$ docker history centos:1.0.0
IMAGE               CREATED             CREATED BY                                      SIZE                COMMENT
cd691faefd5c        59 seconds ago      /bin/bash                                       70.7MB              add bash: ifconfig
1e1148e4cc2c        7 days ago          /bin/sh -c #(nop)  CMD ["/bin/bash"]            0B
<missing>           7 days ago          /bin/sh -c #(nop)  LABEL org.label-schema.sc…   0B
<missing>           7 days ago          /bin/sh -c #(nop) ADD file:6f877549795f4798a…   202MB
    ```
    
    ```bash
    ###build:基于Dockerfile创建
    $ touch Dockerfile
    $ cat Dockerfile
    FROM centos:latest
    MAINTAINER Stefan
    RUN yum search ifconfig && \
        yum install -y net-tools.x86_64
        
    $ docker build -t centos:1.0.1 .
    $ docker run -itd --name centos_dockerfile centos:1.0.1 /bin/bash
    ```

4. 传输镜像

    ```bash
    ###导出
    $ docker save -o centos-1.0.1.zip centos:1.0.1
    
    ###删除后测试
    $ docker rmi centos:1.0.1
    
    ###导入
    $ docker load -i centos-1.0.1.zip
285eba0c1b7a: Loading layer [==================================================>]  70.78MB/70.78MB
Loaded image: centos:1.0.1
    ```

5. 上传到远程Docker hub个人仓库

    ```bash
    $ docker tag centos:1.0.1 1vfan/mycentos:1.0.1
    
    $ docker push 1vfan/mycentos:1.0.1
    ```

## 镜像代理

镜像代理服务加速Docker镜像获取过程

```bash
###--registry-mirror
http://f1361db2.m.daocloud.io
```

## SSH Dockerfile

```bash
$ mkdir centos-ssh
$ cd centos-ssh
$ vim run.sh
#!/bin/bash
/usr/sbin/sshd -D

$ ssh-keygen -t rsa -P '' -f ./ssh_host_rsa_key
$ cat ssh_host_rsa_key.pub > authorized_keys

$ vim Dockerfile
#生成的新镜像以centos镜像为基础
FROM centos:7.2.1511
MAINTAINER by stefan
#升级系统
#RUN yum -y update
#安装openssh-server
RUN yum -y install openssh-server
#修改/etc/ssh/sshd_config
RUN sed -i 's/UsePAM yes/UsePAM no/g' /etc/ssh/sshd_config
#将密钥文件复制到/etc/ssh/目录中
ADD ssh_host_rsa_key /etc/ssh/ssh_host_rsa_key
ADD ssh_host_rsa_key.pub /etc/ssh/ssh_host_rsa_key.pub
RUN mkdir -p /root/.ssh
ADD authorized_keys /root/.ssh/authorized_keys
#将ssh服务启动脚本复制到/usr/local/sbin目录中，并改变权限为755
ADD run.sh /usr/local/sbin/run.sh
RUN chmod 755 /usr/local/sbin/run.sh
#变更root密码为root
RUN echo "root:root"|chpasswd
#开放窗口的22端口
EXPOSE 22
#运行脚本，启动sshd服务
CMD ["/usr/local/sbin/run.sh"]

$ docker build -t centos:1.0.1 .
Successfully built 7d5a2c5f5daf
Successfully tagged centos:1.0.1

$ docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
centos              1.0.1               7d5a2c5f5daf        56 seconds ago      264MB

$ docker run -itd --name centos_ssh -p 4444:22 centos:1.0.1 /usr/local/sbin/run.sh

$ docker ps -a
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS                  NAMES
946a2d3e16e2        centos:1.0.1        "/usr/local/sbin/run…"   19 minutes ago      Up 19 minutes       0.0.0.0:4444->22/tcp   centos_ssh

$ ssh root@0.0.0.0 -p 4444
The authenticity of host '[0.0.0.0]:4444 ([0.0.0.0]:4444)' can't be established.
RSA key fingerprint is SHA256:Pua8xdglnqah7+Q57zmwgh9y7ppaFD+U5YngvI+7f0c.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added '[0.0.0.0]:4444' (RSA) to the list of known hosts.
root@0.0.0.0's password: root

###确认连接后宿主机MAC中该文件新增了ssh_host_rsa_key.pub
$ cat ~/.ssh/known_hosts
[0.0.0.0]:4444 ssh-rsa AAAAB3NzaC1yc......L7Dmuz6AeYl
```




