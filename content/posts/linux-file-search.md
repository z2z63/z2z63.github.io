---
title: Linux搜索神器
author: z2z63
date: 2023-04-01 23:35:22
tags: [Linux]
---
使用Linux时，常常需要在文件系统中快速搜索到内容，比如说
1. 在一个项目中需要快速找到一个文件的路径，需要按照文件名搜索出路径
2. 想找某个文件，但是完全不知道它在哪里，需要全局搜索
3. 在一个项目中想要搜索一个特定字符串的出现
### 需求1: 根据文件名搜索路径--`find`
可以使用find命令，它是linux大多数发行版都自带的命令
```shell
find . -name "filename"
```
这个命令会在当前目录下递归搜索叫做filename的文件，但是这个文件名必须是完全匹配
如果只是知道文件名的大概，或者无法保证文件名完全一致，可以用正则匹配
```shell
find . -name "filename.*"
```
这个命令会搜索所有满足正则表达式`filename.*`的文件，但是注意，**由于bash会将`*`解释为匹配的文件，必
须用双引号把括起来**  
至此这个命令足够日常使用了，但是有些情景就不好用了，例如完全不知道这个文件的路径，只知道它的名字，或许可
以这样
```shell
find / -name "filename"
```
这个命令会在根目录递归搜索所有文件，似乎能达到目的，但是它会去尝试读取一些系统文件和权限不足以访问的
文件 ，导致输出一大堆错误信息 ，为了避免错误输出淹没了查找结果的输出，可以给予高权限
```shell
sudo find / -name "filename"
```
但是这个命令其实**相当危险！**，作为超级用户，不应该给予它如此高的权限，这是没必要的，还可能有风险
而且由于linux实现的的文件系统是VFS(虚拟文件系统)，并不是所有文件的open和read操作都会在硬盘上生效，
比如说，访问`/proc`下的文件实际上是从内存中读取进程的相关信息，访问`/dev`下的文件实际上是尝试从
设备中读取数据，另外实际上你也会发现，即使给了最高的权限，还是有些文件无法被读取  
很明显，我们想要搜索的文件常常都是用户文件，它的权限不高，所以没必要用这种方式，另外为了防止错误信息
淹没了查找结果，可以把错误信息丢掉
```shell
find / -name "filename" 2>/dev/null
```
在shell中，`2`代表标准错误，同理`0`代表标准输入，`1`代表标准输出，`>`代表重定向输出，`/dev/null`
是linux的空设备，它相当于一个无底洞，输出到`/dev/null`就相当于丢弃输出  
虽然find命令很强大，但是如你所见，用它搜索文件有时候还是不好用
### 需求2:全局搜索文件--`locate`
locate可能需要自己[安装](https://wiki.archlinux.org/title/locate)，如
[archwiki](https://wiki.archlinux.org/title/locate)所说，locate命令是在预先建立好的文件系统
索引数据库中搜索，这可以大大加快速度（当用find全局搜索或者在机械硬盘中搜索时往往能体会到find的速度）
locate的工作原理有点类似于Windows平台的[everything](https://www.voidtools.com/zh-cn/)，
但实际上locate可能胜过everything
第一次使用locate命令前需要先建立索引(需要root权限)
```shell
sudo updatedb
```
然后直接搜索
```shell
locate "filename"
```
可以在全局查找文件，另外locate会考虑权限控制，只会显示用户可访问的文件，就不会出现在`/proc`和`/dev`
下搜索的情况  
这个命令用来全局模糊搜索非常好用，因为`locate`默认把参数解释为正则匹配的`partten`  
在日常使用的过程中可能会出现这个问题，`locate`输出的结果太多了，例如
```shell
locate python | wc
411629  411761 48329698
```
如上，用`wc`统计出有411629行，也就是有411629个匹配结果！  
让我们来看看为什么会有这么多结果，首先可以发现，如果一个目录名包括了`python`字符串，那么这个目录下所有文件
都会命中正则匹配！例如`/home/arch/.cache/JetBrains/CLion2022.3/python_stubs/-548636620/PySide6
`另外有些目录下的匹配结果是不需要的，比如说我只想看看我的电脑上有多少个python解释器，
那么`~/.cache`很有可能就是不需要的,那么如何避免这些情况呢？
- 更加准确的描述方式
如果我只想找到python解释器的位置，那么`python-stub`还有`python-websockets`就是不满足的，可以
扩展正则语法的否定预查更加精准的匹配，然而这个情景下，用准确的文件名匹配更好
    ```shell
    locate "*/python"
    ```
    这个命令的意思是`*`匹配前的路径，`python`匹配文件名，这样就能精准匹配到名为`python`的文件
- 过滤不需要的信息
    执行过一遍`locate`后我已经知道某些路径下的搜索结果是不需要的，例如我想过滤`~/.cache`下的所有结果
    ```shell
    locate "python" | grep -v ".cache"
    ```
    这里用到了`grep`的反向匹配过滤掉`~/.cache`下的所有匹配结果，但是这么过滤后可能还是太多了，需要
    进一步过滤，例如想要过滤`python-websockets`下的所有结果，通过查看grep的手册发现并没有反向匹配两种pattern的方法，这里可以利用linux shell的
    强大之处
  ```shell
  locate "python" | grep -v ".cache" | grep -v "python-websockets"
  ```
  利用最简单的概念和最简单的操作就能组合出非常复杂的流程，这体现出linux设计的优点，也体现了
  [最小惊讶原理](https://en.wikipedia.org/wiki/Principle_of_least_astonishment)，说实话
  我第一次看到这种用法只吃惊了1秒！
### 需求3:搜索文件内容--`grep`,`ag`,<del>`ack`</del>
在VScode和jetbrain系IDE中都可以通过Ctrl+Sift+F在整个项目中搜索文件内容，linux的命令行也有对应的
工具`grep`和`ag`，但是`grep`的命令太长，所以这里暂时略过`grep`<del>(因为我也不会)</del>  
`ag`是[The Silver Searcher](https://github.com/ggreer/the_silver_searcher)的指代，[`tldr`](https://tldr.sh/)对`ag`的介绍是
{% blockquote %}  Recursively search for PATTERN in PATH.
Like grep or ack, but faster.
{% endblockquote %}  
`ag`大多数发行版都没有自带，需要自己安装
```shell
sudo pacman -S the_silver_searcher
```
假设我想看一个python项目引入了哪些库，可以用ag搜索`import`语句
```shell
ag "import"
```
ag默认使用正则表达式搜索，而且搜索速度非常快！

---
搜索非常快的原因见github仓库