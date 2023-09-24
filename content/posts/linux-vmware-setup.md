---
title: "Linux使用VMware"
date: 2023-09-24T19:55:45+08:00
draft: true
---
为了完成课程的任务，折腾了很久终于搞好了VMware。
# 安装VMware
VMware分为个人使用免费的player和商用付费的workstation，archlinux可以在[aur](https://aur.archlinux.org/packages/vmware-workstation)中找到vmware并安装。
非archlinux可以在官网找到安装包
# 配置VMware
安装后还需要配置很多东西才能使用
## 安装linux-headers
archlinux的更新是滚动更新，而更新了linux内核后需要重启才能完全生效。所以就会出现pacman能够查到已经安装了linux-headers包，但是仍然无法使用VMware的情况
## 加载内核模块
需要加载vmw_vmci和vmmon这两个模块
```bash
sudo modprobe -a vmw_vmci vmmon
```
然而很有可能无法加载，输出为找不到模块，这是因为对于比较新的内核，需要自己编译这两个模块
找到这个[仓库](https://github.com/mkubecek/vmware-host-modules)，拉下来，根据INSTALL中的方法，首先根据workstation的版本，切换到对应分支
```bash
git clone https://github.com/mkubecek/vmware-host-modules
cd vmware-host-modules
git checkout workstation-17.0.2
```
然后开始编译，编译完成后安装
```bash
make
sudo make install
```
然后重新加载模块
```bash
sudo modprobe -a vmw_vmci vmmon
```
## 设置网络
执行
```bash
sudo systemctl start  vmware-networks.service
```
有可能会失败，根据systemctl的日志，需要先配置网络
aur中的VMware workstation包将`vmware-netcfg`软链接到`/usr/bin`所以可以直接使用
```bash
sudo vmware-netcfg
```
在弹出的界面中配置网络
![](https://raw.githubusercontent.com/z2z63/image/main/img20230924205037.png)
设置开机自启，再重启
```bash
sudo systemctl enable vmware-networks.service
reboot
```

至此就完成了最基础的设置，已经可以在VMware虚拟机中连接网络了
