---
title: docker 使用方法
date: 2023-03-28 23:21:19
tags: [Linux]
---
### [docker](https://www.docker.com/)是容器技术，是向管理复杂依赖关系的妥协，也是快速部署软件的方法
#### 安装
1. 首先用包管理器安装docker
```bash
sudo pacma -S docker
```
2. 然后启动docker deamon(docker容器和docker宿主通过虚拟网卡通信，使用docker前需要先启用docker deamon以创造一个虚拟网卡)
```bash
sudo systemctl enable docker
sudo systemctl start docker
```
3. 可能出现非root用户无法运行dokcer的情况，可以将当前用户加入docker用户组
```bash
sudo gpasswd -a ${USER} docker
```
#### 使用
- 查看当前所有容器
    ```bash
    docker ps -a
    CONTAINER ID    IMAGE        COMMAND            CREATED         STATUS                    PORTS     NAMES
    b6849e6f407d    archlinux    "/usr/bin/bash"    4 seconds ago   Exited (0) 1 second ago             bold_chatelet
    10cea609699d    archlinux    "/usr/bin/bash"    4 days ago      Exited (0) 4 days ago               admiring_knuth
    ```
    `IAMGE`字段是docker镜像的名字，`NAMES`字段才是容器名，可以在创建时指定容器名，也可以重命名容器
- 容器存在但处于停止状态
    ```bash
    docker run <container name or id>
    ```
    如果想要进入交互式界面
    ```bash
    docker run -it <container name or id>
    ```
- 容器存在而且正在运行
    进入交互式界面
    ```bash
    docker exec -it <container name or id> /bin/bash
    ```
- 停止容器
    对于交互式容器，退出交互式界面就会自动停止容器，对于其他容器，可能需要手动停止
    ```bash
    docker stop <container name or id>
    ```
- 新建容器
    ```bash
    docker run <docker mirror name>
    ```
    当docker镜像在本地仓库不存在时，会自动从docker hub下载
