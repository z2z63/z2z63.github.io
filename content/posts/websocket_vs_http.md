---
title: "Websocket_vs_http"
author: z2z63
date: 2024-03-14T22:14:18+08:00
draft: true
---
最近面试腾讯时，我提及我在做的一个某即时通讯软件的第三方客户端使用了websocket接受新消息，因为websocket相比http长轮询在移动设备上更省电，面试官突然反问，为什么websocket更省电<!--more-->，我当时没答出来，现在列出几点我的想法
# 为什么websocket比http长轮询更省电
1. websocket省去了http长轮询重复发送http报文时多次传输的http头部
   众所周知http头部可以携带很多有用的信息，这些信息可以用于服务器的整花活，例如代理、缓存、分布式等等，举例我的博客
   ```text
   ➜  ~ curl https://blog.virtualfuture.top/ --head | wc -c       
    % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                    Dload  Upload   Total   Spent    Left  Speed
    0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
    1064
    ```
    我的博客使用了cloudflare代理，所以http头部字段较多，而现实中的即时通讯软件为了验证客户端等各种需求，http头部也需要携带很多信息。http长轮询中，客户端每次发送HTTP报文时都会将http头部重复，长此以往自然多发送了很多数据
2. 重复建立TCP连接？
   HTTP1.1允许多个HTTP请求复用一个TCP连接，所以这个理由很牵强

占坑