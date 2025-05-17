---
title: "端口转发的妙用"
author: z2z63
date: 2025-05-17T14:20:07+08:00
---

最近在做毕设过程中遇到很多不方便的地方，突然想到使用端口转发去优化工作流程，于是写一篇文章介绍并总结端口转发的种种妙用  

## 用途展示

1. 服务器无需安装 clash，使用 PC 上的 clash 实现服务器上科学上网
2. 服务器上执行 adb 命令操纵 连接到 PC 的 android 设备
3. 无屏幕无键鼠的 android 开发板无需接入屏幕键鼠，只通过一根数据线就能访问桌面并调试

<!--more-->
## 一条命令启动

这条命令可以实现 服务器使用 PC 的 clash 科学上网

```shell
ssh -R server:8888:localhost:7890 user@server
# 登录之后
export ALL_PROXY="http://localhost:8888"
```

## 原理解释篇

### server-client 软件架构

许多软件都应用了 server-client 架构，例如 docker, adb, systemd, ssh 等等。archlinux wiki 将 daemon 描述为 any program that runs as a "background" process (without a terminal or user interface), commonly waiting for events to occur and offering services。简单来说就是 daemoon 没有 contorl terminal，大部分时间都在等待某个文件描述符产生事件。为什么要使用 server-client 的架构呢？我认为最直接的原因就是 server 的生命期与 client 的生命期不一样。例如 `docker`命令作为一个 cli，生命期结束于`docker`命令执行完毕进程退出，显然 dockerd 的生命期远大于`docker`的生命期。又例如 adb 在第一次执行时，会自动启动 adbd，我不了解 adb 的诸多细节，但大致原因也许就是 adbd 负责维护 PC 和 android 设备的连接，否则每次执行 adb 命令都要重新建立连接，这显然是不可接受的。

软件被分为 server 和 client 后，往往通过端口或者 unix socket 通信，其中通过端口通信是跨平台最友好的。因此许多 server-client 架构的软件都可以使用端口转发实现一些神奇的效果

### 科学上网与魔法上网

所谓魔法上网只是我随意编的词，从我学会科学上网后很长一段时间，我从来没有考虑过科学上网的原理是怎样的。clash 可以说是我使用时间最长的一个软件，几年来我也从来没有考虑过这个软件的原理是怎样的，所谓魔法上网是我对自己的调侃：不去了解背后的原理，出了问题不知道怎么解决，并将其归为玄学、魔法。

所谓科学上网或者魔法上网，本质是代理，能工作的最关键的原因是至今为止防火墙是以黑名单的方式工作的，也就是说仍有许多 ip 地址是防火墙未知并且不会拦截的，于是我们就能通过代理的方式利用尚未被屏蔽的服务器去访问已经被屏蔽的服务器。当然，如果哪天防火墙切换到了白名单模式，任何通过代理绕过防火墙的方法也会失效。

科学上网可以分为代理协议、代理客户端。代理协议的目的是伪装成正常流量以便通过防火墙， 代理客户端的目的是将特殊的代理协议转为 socks 代理协议、http 代理协议，这是因为 socks 和 http 是受支持最广的代理协议。常见的代理协议包括 VMess, ShadowSocks, ShadowSocketR, Trojan 等。常见的代理客户端有 v2ray, clash 系等  

clash 是一个无 GUI 的代理客户端，有许多包装 clash 的 GUI，例如 clash for windows，clash verge 等，他们通过 clash 暴露的 external-controller 与 clash 通信，其中的 clash 往往被称作 clash 核心。

理解了常用的 clash GUI 由 GUI 和 clash 核心组成后，就能认识到任何 clash GUI 的目的都是更方便的操作 clash 核心，而 clash 核心最核心的特点就是规则。围绕规则能做很多事情，以我遇到的情况为例

1. 常见的一条规则是对于国外的网站使用代理，但也有例外。例如 acm.org 的论文使用 ip 管控，也就是说虽然 acm.org 是国外的网站，但我必须直连才能使用学校的 ip 访问到论文，因此添加一条规则`DOMAIN-SUFFIX,acm.org,DIRECT`，这样就能正常访问 acm.org 了
2. 常见的一条规则是 google 的域名使用代理，但也有例外。由于潜在的滥用风险（SPAM），机场往往屏蔽了 SMTP 和 IMAP 协议的流量，导致邮箱客户端无法连接到 Gmail。但很幸运 Gmail 的 imap 域名和端口在大陆是可以直连的，因此加上一条规则`DOMAIN-KEYWORD,imap,DIRECT`，就解决了困扰我很长时间的无法使用邮箱客户端收发 gmail 邮件的问题

通过以上的介绍，我们知道不论使用什么代理客户端，最终都会得到一个代理服务器，它运行着 socks 代理协议或 http 代理协议，对于 clash 来说，代理服务器默认运行在 `http://localhost:7890`，然后只需要将系统代理或软件代理设为 `http://localhost:7890`，就能科学上网了。

通常情况下代理服务器绑定到本地回环网络接口，也就是说只有本机可以访问。当然可以绑定到局域网网络接口，于是局域网内其他设备就能访问这个代理服务器。于是我有个初步的想法，假设 PC 的域名是 PC，服务器的域名是 server，在 server 上将代理设为 `http://PC:7890`, 是否就能让服务器使用 PC 上的代理服务器，也就是服务器使用 PC 上的 clash 科学上网了呢？

理论上是可行的，但由于 server 往往在公网上而 PC 工作在层层 NAT 之后，server 是无法主动建立与 PC 的 tcp 连接的。我在做毕设中遇到的情况是，我使用 vpn 软件加入一个 服务器所在的 VLAN，然后通过 ip 访问服务器，但服务器和 PC 的 VLAN 中的 ip 在不同网段，而且服务器的路由表中也没有 PC 网段的路由记录，我猜原因是服务器运维认为这不需要而且不安全。由于以上原因，虽然我的 server 和 PC 在同一个 VLAN 但 server 仍然无法主动建立与 PC 的连接

### ssh 隧道

ssh 隧道就能间接的解决「server 仍然无法主动建立与 PC 的连接」这个问题，man 手册描述 ssh 为
> ssh (SSH client) is a program for logging into a remote machine and for executing commands on a remote machine.  It is intended to provide secure encrypted communications between two untrusted hosts over an insecure network.  X11 connections, arbitrary TCP ports and Unix-domain sockets can also be forwarded over the secure channel.

通过 ssh 隧道，可以将 PC 的 7890 端口转发到服务器的 8888 端口，于是服务器访问 `http://localhost:8888` 时，数据包就会被转发到 PC 的 7890 端口，从而被 PC 的 clash 处理

### adb 与 adbd

adb 也是 server-client 的架构。adb 在第一次启动时会自动启动 adbd，adbd 默认监听 5037 端口，adb 通过与 adbd 通信从而操纵 android 设备。于是我将本地的 5037 端口转发到服务器的 5037 端口，于是服务器上的 adb 就能与运行在 PC 的 adbd 通信，并操纵连接到 PC 的 android 设备。

这样做有什么用呢？因为我使用 rknn-toolkit2 做模型转换、模型性能分析等工作（模型运行在 android 设备），而 rknn-toolkit2 不支持 macos，于是我只能在 x64 架构的服务器上去做，但我不能物理接触到服务器，更不能将数据线插到服务器上。但使用端口转发，我近似实现了数据线插到服务器上的效果，从而简化了我的工作流

### adb 端口转发

做毕设很烦的一件事就是乱七八糟的线实在太多，一个 android 开发板上要接电源线、数据线用于调试、 AR 眼镜的 USB 数据线、接显示器的 HDMI 线、接鼠标的 USB 线。一堆线缠在一起让我心情非常烦躁。而且显示器只有一个，同时要么给 mac 用要么给 android 开发板用，又降低了我的工作效率。于是我就在想能不能通过 adb 把 android 的屏幕流式传输到 mac，经过一番研究后我发现有一个很简单的方法实现

首先在安卓开发版上运行 vnc server，然后用 adb 将 android 设备的 vnc 端口转发到 mac，于是 mac 就能通过 vnc viewer 访问 android 设备的桌面，具体操作如下

1. 在 android 开发板上安装 [droidVNC-NG](https://github.com/bk138/droidVNC-NG)，这一步可以在 mac 下载 app 然后用 adb install 命令安装。droidVNC-NG 可以运行 vnc server，然后通过 ip+端口或浏览器就能远程访问桌面。最方便的是它能够开机后自动启动 vnc 服务
2. 给 android 设备接入显示器，设置并启用 droidVNC-NG，并打开开机自启
3. 执行`adb forward tcp:5901 tcp:5901`，将安卓设备的 5901 端口转发到 mac 本地的 5901 端口
4. 在 mac 使用 vnc viewer 登录远程桌面  
   macos 的 finder 自带了 vnc viewer，无需额外安装 vnc viewer

使用这样的方法，我不再需要接入显示器和键鼠，接线少了一半，工作流程变得非常流畅。指导毕设的学长评价说“我真是每天被线缠着，苦大仇深啊。”

那么 adb 端口转发有什么神奇的地方吗？在我看来就是 adb 连接提供了一个供 TCP 流量通行的隧道，而 adb 连接往下就是 USB 协议栈，仔细考虑一下就会觉得很神奇，TCP 流量跑在 USB 数据线里了，这也许就是计算机网络分层的魅力吧  
一定需要 adb 端口转发吗？其实也不一定，因为校园网有 ap 隔离，导致我的手机、mac、笔记本电脑、android 开发板即使连接了校园网也无法相互通信，这在很长一段时间内都给我造成了麻烦。而用手机开热点一来无法固定 ip 二来手机拿远了就会断开。设想一下校园网没有 AP 隔离，我也许直接使用 android 开发板的 ip + vnc 端口就能访问远程桌面了。

不管怎么说，这个方案是目前我非常满意的方式，不需要记住任何 ip，每次插上数据线执行`adb forward`命令就能访问 android 桌面。在搞硬件的看来已经是非常方便了。

## 总结

去研究日常工作中使用次数最多的软件，花费时间与精力探索如何善用工具优化工作流程，是一个绝对值得的投资

{{<youtube TYq1QInreZo>}}