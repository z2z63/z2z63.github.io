---
title: "Readme_project"
author: z2z63
date: 2024-07-02T17:25:46+08:00
draft: true
---

## 某README项目
最近搜索时突然发现某个README项目[fucking-algorithm](https://github.com/labuladong/fucking-algorithm)，有124K星星，随便看了几篇文章后，发现内容很一般，更多是给作者的书和付费教程引流  

以下以其一篇讲linux shell的文章为例，拷打内容

> 我个人很喜欢使用 Linux 系统，虽然说 Windows 的图形化界面做的确实比 Linux 好，但是对脚本的支持太差了。一开始有点不习惯命令行操作，但是熟悉了之后反而发现移动鼠标点点点才是浪费时间的罪魁祸首。。。

我初学linux时也是这么想的，然而这种观点本来就是非常片面的，尤其是在花十几天配置neovim之后，我发现它仍然没有jetbrains IDE好用时，我就深刻的认识到了cli，gui，开源与商业的差异

简单来说，cli容易开发，上手难，gui开发难，上手简单，至于提高效率，主要取决于工作类型，某些工作是不可能使用cli提高效率的！

> 一、标准输入和参数的区别
> 这个问题一定是最容易让人迷惑的，具体来说，就是搞不清什么时候用管道符|和文件重定向>，<，什么时候用变量$。
> 
> 比如说，我现在有个自动连接宽带的 shell 脚本connect.sh，存在我的家目录：
> 
> $ where connect.sh
> /home/fdl/bin/connect.sh
> 如果我想删除这个脚本，而且想少敲几次键盘，应该怎么操作呢？我曾经这样尝试过：
> 
> $ where connect.sh | rm
> 实际上，这样操作是错误的，正确的做法应该是这样的：
> 
> $ rm $(where connect.sh)
> 前者试图将where的结果连接到rm的标准输入，后者试图将结果作为命令行参数传入。
> 
> 标准输入就是编程语言中诸如scanf或者readline这种命令；而参数是指程序的main函数传入的args字符数组。
> 
> 前文 Linux文件描述符 说过，管道符和重定向符是将数据作为程序的标准输入，而$(cmd)是读取cmd命令输出的数据作为参数。
> 
> 用刚才的例子说，rm命令源代码中肯定不接受标准输入，而是接收命令行参数，删除相应的文件。作为对比，cat命令是既接受标准输入，又接受命令行参数：
> 
> $ cat filename
> ...file text...
> 
> $ cat < filename
> ...file text...
> 
> $ echo 'hello world' | cat
> hello world
> 如果命令能够让终端阻塞，说明该命令接收标准输入，反之就是不接受，比如你只运行cat命令不加任何参数，终端就会阻塞，等待你输入字符串并回显相同的字符串。

可以看出作者对操作系统、系统调用的了解非常局限，参数只是exec系统调用中携带的参数数组，而标准输入是一个文件，其文件描述符值为`0`，标准输入是shell层面提供的
功能，内核并不会特殊处理（shell在执行fork前，已经打开了标准输入，子进程自动继承了标准输入），shell提供的很多功能只是系统调用的封装，甚至有时候连名字都和
系统调用一模一样

“rm命令源代码中肯定不接受标准输入，而是接收命令行参数，删除相应的文件”，可以看出作者并没有仔细阅读man手册，实际上某些命令是支持读取标准输入的,例如`tree`
命令，一般将需要展示的目录路径作为参数传入，但`tree --from-file`时，就会读取标准输入。这是软件的行为差异，在手册中有详细介绍，很巧的是`rm`确实没有提供
读取标准输入的方法，但作出“不接受标准输入”这个结论，其依据是man手册，而不是想当然

> 二、后台运行程序
> 比如说你远程登录到服务器上，运行一个 Django web 程序：
> 
> $ python manager.py runserver 0.0.0.0
> Listening on 0.0.0.0:8080...
> 现在你可以通过服务器的 IP 地址测试 Django 服务，但是终端此时就阻塞了，你输入什么都不响应，除非输入 Ctrl-C 或者 Ctrl-/ 终止 python 进程。
> 
> 可以在命令之后加一个&符号，这样命令行不会阻塞，可以响应你后续输入的命令，但是如果你退出服务器的登录，就不能访问该网页了。
> 
> 如果你想在退出服务器之后仍然能够访问 web 服务，应该这样写命令 (cmd &)：
> 
> $ (python manager.py runserver 0.0.0.0 &)
> Listening on 0.0.0.0:8080...
> 
> $ logout
> 底层原理是这样的：
> 
> 每一个命令行终端都是一个 shell 进程，你在这个终端里执行的程序实际上都是这个 shell 进程分出来的子进程。正常情况下，shell 进程会阻塞，等待子进程退出才重新接收你输入的新的命令。加上&号，只是让 shell 进程不再阻塞，可以继续响应你的新命令。但是无论如何，你如果关掉了这个 shell 命令行端口，依附于它的所有子进程都会退出。
> 
> 而(cmd &)这样运行命令，则是将cmd命令挂到一个systemd系统守护进程名下，认systemd做爸爸，这样当你退出当前终端时，对于刚才的cmd命令就完全没有影响了。
> 
> 类似的，还有一种后台运行常用的做法是这样：
> 
> $ nohup some_cmd &
> nohub命令也是类似的原理，不过通过我的测试，还是(cmd &)这种形式更加稳定。

首先作者的做法是错误的，在生产环境，应该使用诸如systemd，supervisor这样的进程守护程序运行服务，参见v2ex的一篇[帖子](https://www.v2ex.com/t/997469#reply48)

其次，命令末尾加上`&`，并不是“将cmd命令挂到一个systemd系统守护进程名下，认systemd做爸爸”，参考bash的man手册
> If a command is terminated by the control operator &, the shell executes the command in the background in a subshell. The shell does not wait for the command to finish, and the return status is 0.

逻辑如下
1. 如手册所说，命令末尾加上`&`后，命令在subshell中运行，shell不会等待subshell
2. 