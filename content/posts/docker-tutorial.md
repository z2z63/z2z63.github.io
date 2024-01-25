---
title: docker 使用方法
author: z2z63
date: 2023-12-16 18:21:19
tags: [Linux, docker]
---
这篇文章是完成docker的get started guide后的总结，见<https://docs.docker.com/get-started/>
<!--more-->
# 前置概念
## docker架构
docker采用server-client架构，docker deamon（即dockerd）完成构建容器，运行容器等工作，docker client与docker deamon通过REST API或UNIX socket或网卡通信  
docker client可以是
- 名为`docker`的cli（命令行接口）
- docker compose(也是cli)
- docker desktop（GUI）
- etc...
## image与container
image和container的关系类似于类与对象，image可以从docker hub中下载，container是一个image的实例
## docker的进程模型
在启动容器时，会提供一个命令用于启动主进程，docker的默认一个容器只做一件事而且做到最好，所以一个容器一般只运行一个进程，docker的进程调度器也对此做过针对优化  
主进程退出时，docker也会自动停止镜像
# 安装
首先用包管理器安装docker
```bash
sudo pacma -S docker
```
然后启动dockerd
```bash
sudo systemctl enable docker
sudo systemctl start docker
```
可能出现非root用户无法运行dokcer的情况，可以将当前用户加入docker用户组  
注意这实际上是不够安全的，可能会增加一个攻击面
```bash
sudo gpasswd -a ${USER} docker
```
# 使用
docker有许多子命令，可以输入`docker --help`查询所有子命令  
子命令也可以通过`--help`参数查询使用方法，例如`docker image --help`
## 工作流1——使用docker hub提供的镜像
### 启动容器
以ubuntu镜像为例  
拉取一个镜像到本地
```shell
docker pull ubuntu
```
创建一个ubuntu的容器
```shell
docker create ubuntu
```
docker会随机给这个容器随机生成一个名字，也可以指定名字
```shell
docker create --name mycontainer ubuntu
```
创建后，启动容器
```shell
docker start mycontainer
```
---
docker提供了一个更简单的命令`run`来简化这个流程
```shell
docker run ubuntu # 同样可以通过--name指定容器名
```
`run`命令会自动拉取镜像（如果本地没有），创建容器，启动容器
### 查看容器状态
启动ubutnu容器后，可以通过`ps`查看容器状态
```shell
docker ps
```
然而发现并没有结果，这是因为`ps`只输出运行中的容器  
查看全部容器
```shell
docker ps -a
```
发现刚刚启动的容器的状态是`Exited`，这是dokcer的进程模型导致的，因为ubuntu容器的启动命令是`/bin/bash`，bash默认读取标准输入，而没有提供标准输入，所以bash读取到`EOF`后退出，主进程退出后容器也自动停止了
### 交互式操作
前文提及，因为没有提供标准输入，ubutnu镜像立刻退出了，为了避免这种情况，或能够进入ubutnu容器的终端，可以提供标准输入
```shell
docker run -it ubuntu
```
进入ubuntu容器的终端后，按下Ctrl+D，bash退出，ubutnu容器也会被停止  
`-it`参数中，`-i`表示即使没有连接到标准输入也不关闭，`-t`表示分配一个tty，有了`-t`，就能将当前终端连接到容器内bash的标准输入、标准输出、标准错误，有了`-i`，就能在退出容器后（标准输入deattach）后，再次启动（`start`命令）ubuntu容器后，容器不立刻退出（因为标准输入没有关闭，不会读取到EOF，只是在`read`系统调用上阻塞）
### exec
exec命令可以在一个**运行中**的容器内执行命令  
先创造出一个运行中的ubutnu容器
```
docker run -it --name mycontainer ubuntu
# 在容器的bash中按下Ctrl+D或exit
docker start mycontainer
```
再使用`exec`
```shell
docker exec -it mycontainer bash
```
又进入了bash，然而这个bash实际上是新开的bash进程，在容器内输入`top`，可以看到有两个bash，其中一个是通过`run`创建的，另一个是通过`exec`创建的
### attach
如上，为了避免再创建一个bash进程，可以将当前终端的标准输入，标准输出，标准错误连接到容器内
```shell
docker attach mycontainer
```
在容器内执行`top`，发现只有一个bash进程
### 管理容器
停止容器
```shell
docker stop mycontainer
```
删除容器
```shell
docker rm mycontainer
```
## 工作流2——通过镜像协同工作
创建一个镜像后，可以分享给其他人，从而解决环境搭建、统一环境等问题
### 创建镜像
一个Dockerfile的示例
```Dockerfile
FROM node:18-alpine
WORKDIR /app
COPY . .
RUN yarn install --production
CMD ["node", "src/index.js"]
EXPOSE 3000
```
随后通过当前目录下的`Dockerfile`的内容创建镜像
```shell
docker build -t myimage
```
### 分享给其他人
#### 使用docker hub
在docker hub注册帐号，然后将镜像上传置docker hub
```shell
docker push <myname>/<myimage>
```
其他人可以得到你创建的容器
```shell
docker pull <myname>/<myimage>
```
或
```shell
docker run <myname>/<myimage>
```
#### 发送镜像文件
导出镜像到文件
```shell
docker save -o path/to/image_file.tar myimage
```
随后将文件发送给其他人，其他人执行
```shell
docker load -i path/to/image_file.tar
```
即可得到镜像
#### 第三方镜像托管服务
本质和docker hub相同，不过docker hub在国内被墙，而且不同的服务商的商业策略不同，dokcer hub属于典型的freemium模式，即大部分用户免费使用基础功能，小部分用户为高级功能付费。如果使用dokcer开发，可能会遇到不得不向dokcer hub支付的情况。  
此外，dokcer hub最流行的原因还是因为它是官方的镜像托管服务，生态最好
#### 私有镜像仓库
可以使用开源self-host方案自建私有仓库，不再受dokcer hub的限制，不过也要考虑自建的成本  
这应该是企业常用的解决方案
# docker的其他功能
## 数据持久化
### volume
### bind
## dokcer的网络
### 端口映射
# docker compose
假设需要搭建一个前后端分离的web服务，前端页面由机器上已经安装好的nginx分发，后端服务使用docker部署，此外还需要一个mysql容器提供数据库服务。这需要多个容器协作。前文提到，一个容器只做一件事并做到最好，当需要多个容器协作时，使用docker-cli管理的难度就变大了，docker compose就是为了解决这种问题而出现的  
docker compose需要额外安装
```shell
sudo pacman -S docker-compose
```
dokcer compose使用compose.yaml文件描述每个容器的配置以及他们之间的依赖关系等等
一个compose.yaml实例
```yaml
services:
  app:
    image: node:18-alpine
    command: sh -c "yarn install && yarn run dev"
    ports:
      - 127.0.0.1:3000:3000
    working_dir: /app
    volumes:
      - ./:/app
    environment:
      MYSQL_HOST: mysql
      MYSQL_USER: root
      MYSQL_PASSWORD: secret
      MYSQL_DB: todos

  mysql:
    image: mysql:8.0
    volumes:
      - todo-mysql-data:/var/lib/mysql
    environment:
      MYSQL_ROOT_PASSWORD: secret
      MYSQL_DATABASE: todos

volumes:
  todo-mysql-data:
```

# 一点技巧
## 关于参数
不同的命令行工具都有不同的传参风格，其中`docker`的参数只能在固定位置，例如`dokcer run -it ubuntu`的`-it`不能放到`ubuntu`后面




