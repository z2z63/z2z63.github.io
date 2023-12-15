---
title: "Linux释放磁盘空间"
date: 2023-12-15T15:02:39+08:00
---
主力使用Linux一段时间后，系统占用的空间总会越来越多。虽然linux的包复用率非常高，甚至有些时候更新，包的大小还会负增长，但这无法阻止用户数据的增长，所以清理
也主要是清理用户数据  
# 查看磁盘使用率
```shell
df -h
```
# 清理包管理器的缓存
`pacman`会自动缓存下载过的软件包，以支持快速重新安装，以及恢复到以前的版本  
这样的设计大部分情况都是合理的，而缺点就是
1. 一个软件包，安装了一份，又保留了一份安装包，
2. `pacman`不会自动删除以前的包

所以[archlinux wiki](https://wiki.archlinux.org/title/pacman#:~:text=Cleaning%20the%20package%20cache)建议定期手动删除包缓存
```shell
sudo pacman -Sc
```
# 清理开发环境的缓存
## jetbrains IDE
jetbrains全家桶长期使用会产生不少缓存，可以使用jetbrains toolbox一键清除
![toolbox](https://raw.githubusercontent.com/z2z63/image/main/img20231215151720.png)  
## VScode
VScode的扩展可以把二进制也打包进去，导致有的扩展并不小，可以选择卸载短期不会使用的扩展
## Python
### anaconda虚拟环境
查看conda虚拟环境  
```shell
conda env list
```
鉴于某些不留requirements.txt的项目的环境真不好装，可以先生成requirements.txt再删除，日后也能恢复
```shell
conda list -e > requirements.txt
```
### pip缓存
pip也会缓存下载过的包，可以手动删除
```shell
pip cache remove '*'
```
一般只有简单的项目或者系统解释器会使用pip，删除pip缓存时也要注意环境
### 数据文件
搞爬虫或者机器学习，经常会生成一些数据文件，有各种训练用的数据或者检查点  
另外有些库自带下载数据集的功能，不指定路径就默认在用户的家，然而这些数据集可能之后都不会使用了  
不需要的数据可以直接删除，需要的数据，可以选择压缩（对已经压缩过的数据格式，再压缩几乎不会减小大小，然而将零碎文件打包确实能减少大小）
## Java
### maven缓存
maven也会缓存下载过的包，如果使用不同版本的JDK，最后缓存的包可能会占据一些空间
```shell
rm -r ~/.m2/repository
```
删除缓存后，下次运行maven时会重新下载依赖
### gradle缓存
gradle作为android官方指定构建工具，它的缓存可能比maven还要多
```shell
rm -r ~/.gradle/caches/
```
## C/C++
### 编译产物
不管是使用autoconf + make还是cmake，最终的构建命令基本都是`make`  
一个大型或者中型项目编译产物可能不小，为了加快构建速度make往往会缓存许多构建中间产物  
进入构建目录执行
```shell
make clean
```
### 本地安装的软件
C/C++的依赖确实很难搞，有些时候会在`/usr/local`下安装一些软件作为项目的依赖  
这些软件往往是下载源码，编译安装的，进入对应的构建目录
```shell
make uninstall
```
然而，软件的作者可能没有写uninstall目标，甚至源码目录都被删掉了，这种时候只能手动卸载了
## JS
### npm
npm利用包缓存实现自我修复的功能，因此不建议直接清除缓存，相反，npm提供了验证并压缩缓存的方法
```
du -h --max-depth=0 ~/.npm
npm cache verify
du -h --max-depth=0 ~/.npm
```

## docker
docker的镜像也会占用不少的空间而且平时很难注意到
查看容器
```shell
docker ps -a
```
删除容器
```shell
docker rm <container-name>
```

查看本地的镜像
```shell
docker image list
```
删除本地的镜像
```shell
docker image rm <image-id>
```
## 数据库
数据库也属于一种死角了。爬取了一些数据，或者从网络下载并导入了一些数据，就会导致数据库占用增大很多  
可以选择删除不需要的表，或者不需要的数据库

# 普通软件
## 微信
微信在linux并没有一个完美的解决方案，我曾经使用过运行在wine中的微信，时间一长，微信就会不知廉耻的膨胀到几十G，这其中很多是收到的文件  
最好的方法是打开微信，删除指定聊天的数据  
---
然而或许我们不需要直接使用微信这样的毒瘤软件，可以选择将微信的消息转发到telegram，telegram不会自动下载文件，文件能在服务器上保存很久，
使用3个月后telegram的占用也只有600M，完爆微信  
如何部署微信转发telegrame见<https://www.v2ex.com/t/908436>

## 短期不需要的软件
可以查看安装的AUR中的包，删除最近不会使用的（需要的时候总会想起来安装的）
## chrome
网站可以使用localStorage，某些时候可能一个网站就会占用几百M的空间，根据我的实践，占用空间巨大的往往是不太需要的
进入<chrome://settings/content/all>，点击按照存储的数据大小排序
![](https://raw.githubusercontent.com/z2z63/image/main/img20231215155732.png)
选择近期不需要的删除  
注意也会删除cookie，导致登录状态退出，而且某些网站删除缓存数据后下次进入还会重新生成，导致加载速度变慢  
作为一个每天都使用的软件，chrome的缓存不应该删除太多
# 一点技巧
## Download目录
Download目录全是用户数据，可以按照大小排序，然后删除比较大，又不需要的
## 仓库盘
很多没有的文件并不是没有价值，可以买一块机械硬盘当作仓库盘，全部扔里面
## 打包与压缩
根据文件系统的知识，磁盘是按块管理的，这就导致不可避免的出现存储空间的浪费，对于大量的小文件，这样的浪费更加明显  
仓库盘中的文件就满足这种特征，可以打包然后压缩  
打包会减少很多因为按块管理造成的浪费，压缩的效果不确定，因为对文本文件，压缩效果显著，而对已经压缩过的文件，压缩后几乎不会减小大小
## 删除孤儿包
```shell
sudo pacman -Rns $(pacman -Qtdq)
```
大部分时候都没有孤儿包，偶尔删除一下即可