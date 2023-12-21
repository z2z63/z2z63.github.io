---
title: "Linux字体"
author: z2z63
date: 2023-09-18T12:17:41+08:00
tags: [Linux, Linux Desktop, Font]
---

之前安装archlinux，随便配置的中文字体，显示中文时总有一些奇奇怪怪的字形，最近翻了archlinux的文档，把字体配置搞清楚了
# 字体是什么
简单来说，字体告诉屏幕如何显示一个字，字体常见的格式有Bitmap和Outline，大致区别就是Bitmap直接指定了每一个像素，有点类似于字模，而Outline指定的是字的轮廓，至于具体怎么显示还需要根据屏幕分辨率，字号等信息来计算。很明显，Outline格式是更加现代的格式，所以此文就忽略Bitmap  
Outline格式有以下几种格式
- PostScript fonts，由adobe发明
- TrueType，由Apple和Microsoft发明，扩展名是ttf
- OpenType，由Microsoft发明，相当于TrueType的进阶版，扩展名是otf或ttf  
  
实际使用中，TrueType是最常见的
# 字体如何安装
只需要把字体文件放到指定目录下，就完成了安装。  
指定目录有哪些，可以查看`/etc/fonts/fonts.conf`  
例如 
```xml
 <!-- Font directory list -->
 
     <dir>/usr/share/fonts</dir>
     <dir>/usr/local/share/fonts</dir>
 
     
     <dir prefix="xdg">fonts</dir>
     <!-- the following element will be removed in the future -->
     <dir>~/.fonts</dir>
```
可见指定路径为`/usr/share/fonts`, `/usr/local/share/fonts`，`$HOME/.local/share/fonts`。不同的路径有不同的作用范围  
安装字体后，为了快速生效，可以使用`fc-cache --force`强制刷新字体缓存  
更好的办法是使用包管理器安装字体
# 字体模块
字体模块分为匹配模块和配置模块
## 字体配置模块
字体配置模块简单来说就是一堆xml文件，遵循特定的语法。
可以配置字体目录，字体配置的目录，字体缓存的目录，还能配置一些特殊的操作，例如
```xml
<!--
  Accept alternate 'system ui' spelling, replacing it with 'system-ui'
-->
        <match target="pattern">
                <test qual="any" name="family">
                        <string>system ui</string>
                </test>
                <edit name="family" mode="assign" binding="same">
                        <string>system-ui</string>
                </edit>
        </match>

<!--
  Load local system customization file
-->
        <include ignore_missing="yes">conf.d</include>

<!-- Font cache directory list -->

        <cachedir>/var/cache/fontconfig</cachedir>
        <cachedir prefix="xdg">fontconfig</cachedir>

```
### 字体匹配模块
字体有很多属性，例如family，familylang，weight，spacing等等。字体匹配做的就是：  
当请求一个字体时，计算请求的字体和所有已有字体的距离，返回距离最小的字体。  
距离就是根据属性计算得出的。这样可以保证请求一个字体时，不管计算机上有没有这个字体，都能返回一个字体。
当计算机上有多个满足请求partten的字体时，仍然只有一个字体返回，这就可能导致返回的字体不是用户希望的字体。  
例如，Noto Sans CJK有中文，日文，韩文。当请求Noto Sans CJK时，以下四个字体都满足请求pattern（假设locale设置为en_US）
- Noto Sans CJK SC
- Noto Sans CJK TC
- Noto Sans CJK JP
- Noto Sans CJK KR

然而因为Noto Sans CJK JP的地区代号JP在CN之前，导致某些字体使用Noto Sans CJK JP渲染。例如下图的关和门都使用了Noto Sans CJK JP字体
![](https://raw.githubusercontent.com/z2z63/image/main/img20230918174512.png)
这种情况可以通过设置字体优先级解决,在`~/.config/fontconfig/conf.d/perfer.conf`写入
```xml
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <alias>
    <family>sans-serif</family>
    <prefer>
      <family>Noto Sans CJK SC</family>
      <family>Noto Sans CJK TC</family>
      <family>Noto Sans CJK JP</family>
    </prefer>
  </alias>
  <alias>
    <family>monospace</family>
    <prefer>
      <family>Noto Sans Mono CJK SC</family>
      <family>Noto Sans Mono CJK TC</family>
      <family>Noto Sans Mono CJK JP</family>
    </prefer>
  </alias>
</fontconfig>
```

然后刷新字体缓存即可生效  
需要注意的是，由于linux字体的配置是分布在不同地方的，配置可能有重复的情况发生。  

例如假设我希望使用JetBrains Mono作为等宽字体，修改`~/.config/fontconfig/conf.d/perfer.conf`为
```xml
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <alias>
    <family>sans-serif</family>
    <prefer>
      <family>Noto Sans CJK SC</family>
      <family>Noto Sans CJK TC</family>
      <family>Noto Sans CJK JP</family>
    </prefer>
  </alias>
  <alias>
    <family>monospace</family>
    <prefer>
      <family>JetBrains Mono</family>
      <family>Noto Sans Mono CJK SC</family>
      <family>Noto Sans Mono CJK TC</family>
      <family>Noto Sans Mono CJK JP</family>
    </prefer>
  </alias>
</fontconfig>
```
并没有生效，因为在`~/.config/fontconfig/fonts.conf`中有这么一段
```xml
  <alias>
    <family>sans-serif</family>
    <prefer>
      <family>Noto Sans CJK SC</family>
      <family>Noto Sans CJK TC</family>
      <family>Noto Sans CJK JP</family>
    </prefer>
  </alias>
  <alias>
    <family>monospace</family>
    <prefer>
      <family>Noto Sans Mono CJK SC</family>
      <family>Noto Sans Mono CJK TC</family>
      <family>Noto Sans Mono CJK JP</family>
    </prefer>
  </alias>
```
所以修改linux配置文件时，应该遵循一个原则，就是先从/etc下的配置文件寻找。因为/etc下的配置文件是第一个被加载的，
这些配置文件做的事往往有
1. 完成一些默认配置
2. include更多的配置文件
3. 规定用户配置文件应该放在哪里

/etc下的配置文件的重要性非常高。因为在网上查阅有关配置文件的资料时，往往受限于版本、发行版的不同、软件来源等方式，网上的资料不一定管用。而/etc不仅仅是软件的配置文件，还能在一定程度上充当软件的说明书，它的作用有点类似于gcc的头文件，是编译器最高优先级的接口定义文档。
# 关于字体
在字体非常多的属性中，有几个属性是最突出的
## 衬线与非衬线
衬线就是serif，非衬线就是sans serif，衬线是字形笔画的起始段与末端的装饰细节部分。
![](https://raw.githubusercontent.com/z2z63/image/main/img20230918180529.png)
从最近十几年来各大互联网公司的logo演变可以看出来，非衬线越来越受欢迎。推荐正文部分使用非衬线字体，能够缓解视觉压力
## 等宽与比例
所谓等宽，也就是每一个字符的宽度相等，在视觉上每一行能够对齐，这是一种编程友好字体，几乎所有IDE都默认使用等宽字体（如果有IDE默认使用非等宽字体，赶紧抛弃它吧！）
![](https://raw.githubusercontent.com/z2z63/image/main/img20230918181053.png)

等宽字体往往指的是英文ASCII字符等宽，还有一种字体能够做到中文字符和英文等宽，这种字体在中英文混合排版的时候非常方便
## CJK
CJK就是Chinese Japan Korea的缩写，表示中日韩文字。作为一个archlinux中国用户，即使locale设置为en_US，也不可避免的要使用CJK字体
## Emoji
众所周知，Unicode字符集是包括emoji的。网上下载的字体文件是一系列Unicode字符的字形的集合，也就是说，一个普通的字体很有可能是没有emoji的。linux在font fallback后会发现没有字体能够显示这个emoji，于是就是显示成一个方框。需要显示emoji只需要安装emoji字体即可
## Patched font
Patched font即为打了补丁的字体，有一些TUI(Textual User Interface)可能需要这些字体，用于显示一些特殊的符号
# 小技巧
## 解决WPS Office打开文档时字体显示异常
![](https://raw.githubusercontent.com/z2z63/image/main/img20230918182036.png)
可以鼠标选中显示异常的字体，发现字体是微软雅黑，我的电脑上没有安装微软雅黑，所以fallback到了其他字体，然而使用其他字体显示微软雅黑多少有点瑕疵。例如字体加粗部分就会显得非常粗
解决办法有两个
1. 如果安装了双系统，可以挂载windows分区，然后把windows的`C:\Windows\Fonts\`目录软链接到`/usr/share/fonts/WindowsFonts/`
2. 安装windows字体

因为windows字体非常多，可能导致一句中文使用了不同字体渲染，非常丑，可以指定字体优先级来避免
## 查看fallback到的字体
使用Chrome浏览器查看，打开网页[https://c.runoob.com/front-end/61/](https://c.runoob.com/front-end/61/)在线编辑HTML，在CSS中指定字体，然后F12打开浏览器开发者工具，选中元素，点击Computed，就能看到实际渲染使用的字体
![](https://raw.githubusercontent.com/z2z63/image/main/img20230918183157.png)
# fc-*系列工具
## fc-list
执行
```shell
fc-list
```
可以输出计算机上所有字体  
```bash
fc-list :lang=zh
```
可以输出中文字体
```bash
fc-list :spacing=100
```
可以输出所有等宽字体
## fc-match
执行
```bash
fc-match mono
```
可以根据mono请求字体，这实际上是调用了字体匹配模块的功能。
```bash
fc-match -s mono
```
可以输出所有满足请求的字体并排序
需要debug时，可以设置`FC_DEBUG`环境变量
```bash
FC_DEBUG=1 fc-match mono
```
`FC_DEBUG`的每个位都有约定的含义，见[https://man.archlinux.org/man/fonts-conf.5](https://man.archlinux.org/man/fonts-conf.5)
## fc-cache
```bash
fc-cache --force
```
强制重新生成字体缓存，在修改了字体配置或安装了新字体后执行，可以立即生效