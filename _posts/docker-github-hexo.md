---
title: Docker+Github+Hexo
date: 
tags:
- Docker
- Github
- Git
---

Docker + Github + Hexo for personal blogs.

<!--more-->


## Docker image

使用Dockerfile构建Hexo基础运行环境的镜像

```bash
###镜像文件目录
$ cd /Users/stefan/Docker/Hexo/image

$ vim Dockerfile

FROM node:10-alpine

LABEL maintainer="Stefan" \
      version="latest"

ENV TZ=Asia/Shanghai

ENV GIT_USERNAME \
    GIT_USEREMAIL

WORKDIR /srv/hexo

COPY package.json package.json

RUN apk add --no-cache \
         tzdata \
         git \
         openssh-client \
         openssl \
      && npm install \
      && mkdir -p ~/.ssh \
      && echo -e "StrictHostKeyChecking no\nUserKnownHostsFile /dev/null" > ~/.ssh/config \
      && tar -zcvf node_modules.tar.gz node_modules > /dev/null 2>&1 \
      && rm -rf node_modules /root/.npm /tmp/*

VOLUME /srv/hexo-src

EXPOSE 4000

WORKDIR /srv/hexo-src

COPY docker-entrypoint.sh /usr/local/bin

RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]

CMD build
```

```json
$ cat package.json
{
  "name": "Hexo_Docker",
  "version": "0.0.1",
  "author": "khs1994.com",
  "private": true,
  "hexo": {
    "version": "3.7.1"
  },
  "scripts": {
    "generate": "./node_modules/hexo/bin/hexo g",
    "deploy": "./node_modules/hexo/bin/hexo d",
    "version": "./node_modules/hexo/bin/hexo version"
  },
  "dependencies": {
    "hexo": "3.7.1",
    "hexo-deployer-git": "0.3.1",
    "hexo-generator-archive": "0.1.5",
    "hexo-generator-category": "0.1.3",
    "hexo-generator-index": "0.2.1",
    "hexo-generator-searchdb": "1.0.8",
    "hexo-generator-sitemap": "1.2.0",
    "hexo-generator-tag": "0.2.0",
    "hexo-renderer-ejs": "0.3.1",
    "hexo-renderer-marked": "0.3.2",
    "hexo-renderer-stylus": "0.3.3",
    "hexo-server": "0.2.2"
  }
}
```

```bash
$ cat docker-entrypoint.sh

#!/bin/sh

START=`date "+%F %T"`

if [ $1 = "sh" ];then sh; exit 0; fi

if [ $1 = "version" ];then
  cd ../hexo
  tar -zxvf node_modules.tar.gz > /dev/null 2>&1
  exec ./node_modules/hexo/bin/hexo version
fi

git config --global user.name ${GIT_USERNAME:-none}

git config --global user.email ${GIT_USEREMAIL:-none@none.com}

rm -rf public
cp -a source themes _config.yml ../hexo/
cd ../hexo
tar -zxvf node_modules.tar.gz > /dev/null 2>&1

# echo "registry=https://registry.npm.taobao.org" > /root/.npmrc

main(){
  ./node_modules/hexo/bin/hexo version
  ./node_modules/hexo/bin/hexo g
  cp -a public ../hexo-src/
  case $1 in
    deploy )
      ./node_modules/hexo/bin/hexo d
      ;;
    server )
      exec ./node_modules/hexo/bin/hexo server
      ;;
  esac
  echo $START
  date "+%F %T"
}

main $@
```

## Docker image build

```bash
$ ls /Users/stefan/Docker/Hexo/image
Dockerfile		docker-entrypoint.sh	package.json

$ docker build -t stefan/hexo .

$ docker images
stefan/hexo         latest              808f3f6dd023        5 hours ago         101MB
```

## SSH keys

在宿主机Mac中生成密钥，并将公钥``id_rsa.pub``添加到Github账号的``SSH keys``.

```bash
$ ssh-keygen -t rsa -P '' -C useremail -f ~/.ssh/id_rsa

$ ssh-agent -s

###最后测试
$ ssh -T git@github.com
Hi 1vfan! You've successfully authenticated...
```

## hexo themes

``git clone``已有的theme，或使用自己的旧hexo目录，必须包含``_config.yml source	 themes``.

```bash
$ ls /Users/stefan/Docker/Hexo/data
_config.yml	 db.json  node_modules  package.json  scaffolds  source	 themes
```

## 运行命令

提交部署到远程Github服务器上``hexo d``

```bash
$ cd /Users/stefan/Docker/Hexo/data

$ docker run -it --rm -v $PWD:/srv/hexo-src -v ~/.ssh:/root/.ssh  -e GIT_USERNAME=1***n -e GIT_USEREMAIL=1******7@**.com stefan/hexo  deploy
```

运行本地服务，浏览器中打开``0.0.0.0:4444``实现本地预览

```bash
$ docker run -it --rm  --name MyHexo  -p 4444:4000  -v $PWD:/srv/hexo-src stefan/hexo  server
```

## 提交远程镜像仓库

```bash
$ docker tag stefan/hexo 1vfan/hexo
$ docker push 1vfan/hexo
```

