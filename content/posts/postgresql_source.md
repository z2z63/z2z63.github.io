---
title: "PostgreSQL源码阅读报告"
author: z2z63
date: 2023-12-21T18:27:09+08:00
tags: [C/C++]
---
这篇文章是数据库系统原理课程的任务“阅读postgresql源码“的报告

# 如何编译
首先声明一点，网上大部分的教程都不太合理，因为对环境的影响太大，权限约束不够严格
作为开源自由软件，pg使用GNU工具链编译，包括`autoconf`,`makefile`，`gcc`等
进入pg项目，在`build`目录下编译
```shell
mkdir build && cd build
# 完成configure，指定-g编译参数,禁用优化，指定安装路径
../configure --enable-debug CFLAGS="O0" --prefix=/home/arch/src/postgres/build # 路径需要使用build目录的绝对路径
# 编译安装
make && make install
```
安装到`build`目录是比较合理的！因为默认的安装位置`/usr/local`需要root权限才能写入，没必要给root权限，也完全没必要安装到这个地方
执行完之后，可能需要设置`LD_LIBRARY_PATH`环境变量
```shell
set LD_LIBRARY_PATH=/home/arch/src/postgres/build/lib   # 指定build/lib目录，同样需要绝对路径
```
`LD_LIBRARY_PATH`告诉linux在哪里找动态链接库，以上方式设置后，只在当前终端生效。没有必要写入`~/.bashrc`
可以使用`ldd`命令查看一个可执行需要加载哪些动态库


# 调试的方法
首先，在使用`configure`时，指定参数`--enable-debug`，以`-g`选项编译pg
`make`命令生成的可执行有多个，需要确定调试的可执行，以及它的入口函数`main`所在的位置
启动pg后，通过`ps aux | grep postgres`可以看到，pg有多个进程协作
```text
➜  postgres git:(master) ✗ ps aux | grep postgres
arch      140029  0.0  0.1 205168 21652 ?        Ss   22:04   0:00 /home/arch/src/postgres/build/bin/postgres -D data
arch      140202  0.0  0.0 205316  8276 ?        Ss   22:05   0:00 postgres: checkpointer
arch      140203  0.0  0.0 205300  7764 ?        Ss   22:05   0:00 postgres: background writer
arch      140225  0.0  0.0 205336 10588 ?        Ss   22:05   0:00 postgres: walwriter
arch      140226  0.0  0.0 206844  8156 ?        Ss   22:05   0:00 postgres: autovacuum launcher
arch      140227  0.0  0.0 206788  7644 ?        Ss   22:05   0:00 postgres: logical replication launcher
arch      140264  0.0  0.0 207788 11612 ?        Ss   22:06   0:00 postgres: arch test [local] idle
```
可以看出，` arch test [local] idle`是pg为处理客户端的连接而创建的进程，所以可以知道一条sql语句执行的全部流程都在这个进程中完成。
在linux上，进程是通过`fork`系统调用创建的。gdb对`fork`有一个限制，`fork`执行结束后，有一个父进程和子进程，然而gdb只能跟踪一个进程。
gdb默认跟踪父进程，导致无法进入子进程调试，可以通过`set follow-fork-mod child`改变这种行为。
然而，这种方式我在使用时发现会导致gdb立刻退出，而pg进程还在后台运行
于是，我尝试使用gdb的attach功能调试` arch test [local] idle`进程
首先，要让gdb能够attach上pg的进程，需要修改`ptrace`的安全策略
```shel
sudo bash -c 'echo 0 > /proc/sys/kernel/yama/ptrace_scope'
```
然后，在`arch test [local] idle`进程执行的代码中打上断点，attach上这个进程，成功进入这个进程开始调试
# pg的其他特性
## 内存管理
常规的程序使用C标准库提供的`malloc`和`free`函数管理内存，如下
```c
OBJ* o = malloc(sizeof(OBJ));
// ... 一些操作
free(o);
```
这种方式的缺点有
1. 需要跟踪大量小对象的生存期，心智负担大，不仅容易忘记释放内存，还降低了性能
2. 必须保持申请的内存的引用，否则将永远无法回收内存

pg使用`MemoryContext`管理内存，所有需要在一定时间后才能释放对象的都使用`MemoryContext`机制。它的优点是
1. 能够满足大量小块内存的情况，又能一次性释放，不必跟踪每一个对象的生存期
2. 不必保持申请的内存的引用

## pg使用的数据结构
pg在对sql语句处理的各个阶段都需要存储一些数据，使用的是一种被称为`List`的数据结构，然而这个称呼实际上不准确，是历史遗留的称呼，因为pg最开始有一部分是用Lisp语言写的，那时使用的是Lisp的`cons-cell list`，相当于链表
在使用C重写原来的Lisp部分时，由于性能问题，在经过多次重构后，最终使用了动态数组实现了这种可以动态增长的线性表结构，而List这种称呼就遗留了下来

# 一条sql语句执行的全过程
单条SQL语句在`exec_simple_query`函数完成执行的过程，见`src/backend/tcop/postgres.c`
```mermaid
graph LR
    A[客户端/应用程序] --SQL语句--> B[解析器]
    B --查询树--> C[重写器]
    C --重写后的查询树--> D[规划器]
    D --执行计划--> E[执行器]
    E --执行结果--> F[客户端/应用程序]
```
或者
```mermaid
graph LR
    A[客户端/应用程序] --原始字符串--> B
    subgraph 核心 
        B["解析（parse）"] --> C["`prepared statement`"]
        C --> D["bind（绑定）"]
        D --> E["`portal`"]
        E --> F[执行]
    end
    F --结果--> G[客户端/应用程序]
```
## 解析
解析有三个过程，词法解析，语法解析，分析  
解析由`pg_parse_query`函数完成，见`src/backend/tcop/postgres.c`
### 词法解析
flex完成词法解析，只需要定义`TOKEN`(词法单元)，flex会自动生成C代码完成词法解析的任务。词法解析完成后，词法信息存储在词法树中，并准备传递给语法解析器  
flex可以快速定义一个词法解析器，可以使用表则表达式，还能指定匹配优先级
### 语法解析
bison完成语法解析，通过定义生成式，可以精确的描述各种复杂的语法结构（更多语法解析的知识参见编译原理）  
bison非常灵活，可以将语法定义和动作结合在一起，并支持多种描述语法的方式，例如上下文无关文法（Context-Free Grammar，CFG），扩展巴克斯范式（Extended Backus-Naur Form，EBNF）等  
bison将定义语法的源文件转换成C代码，编译后可以得到一个语法解析器。

最终，pg通过调用flex和bison，得到了一个解析树（Parse Tree），这样的结构方便后续对它进行操作。任何错误的SQL语法都会在语法解析阶段被检测并处理
### 分析
检查SQL语句中是否出现了非语法错误，例如试图查询一个不存在的表，或者不存在的字段，这个过程将解析树转换成查询树(Query Tree)
查询树由`Query`结构体表示(见`src/include/nodes/parsenodes.h`)，它包括了一次查询的所有信息，例如语句类型，`from`子句的列表，
`group by`子句的列表，是否有`with`语句等等  
分析由`parse_analyze_fixedparams`函数完成，见`src/backend/parser/analyze.c`

## 重写
根据预先制定的规则对查询树进行重写  
同一个目地的查询，它的关系代数表达式有很多种，然而他们的执行效率是不同的，执行效率高的关系代数表达式具有某些特征。  
重写的规则就是执行效率高的关系代数表达式的特征  
Postgres支持视图(View)，任何对视图的查询都会在这个阶段被重写成对基表(Base Table)的查询  
工具类的语句不会被重写  
常见的重写规则有
- 视图展开（View Expansion）
- 谓词下推（Predicate Pushdown）
- 连接消除（Join Elimination）
- 常量折叠（Constant Folding）
- 子查询优化（Subquery Optimization）
- 列裁剪（Column Pruning）

重写由`pg_rewrite_query`函数完成，见`src/backend/tcop/postgres.c`
## 规划
规划查询器会根据已有的信息估计每条路径的成本，选择成本最低的路径，生成执行计划  
例如一个`SELECT`语句，有两条路径可以到达相同的目标，一是全表扫描，二是利用索引。这时规划查询器会估计每个路径的成本  
索引并不是在任何情况下都能加快查询，在查询结果在全表中占比较大时，使用索引的成本更高，因为对于每条记录，利用索引都需要多次IO  
规划由`pg_plan_query`函数完成，见`src/backend/tcop/postgres.c`  
其中，查找所有路径由`subquery_planner`函数完成，见`src/backend/optimizer/plan/planner.c`  
`subquery_planner`返回了一个`PlannerInfo`结构体，它表示了规划路径时生成的所有信息  
随后，`get_cheapest_fractional_path`从其中选择出成本最低的路径，见`src/backend/optimizer/plan/planner.c`  
## 执行器
执行器拿到执行计划后，构造一个对象，叫做`portal`，它表示了一次准备好了的执行。对于`SELECT`语句，它相当于一个打开的游标  
准备`portal`的过程包括
1. 根据查询计划构造`portal`，由`PortalDefineQuery`完成
2. 开启`portal`，由`PortalStart`完成
3. 设置返回结果的格式，由`PortalSetResultFormat`完成
4. 打开并设置接受结果的通道

随后，调用`PortalRun`函数完成最终的执行，见`src/backend/tcop/pquery.c`

# 连接管理
pg是一个支持多种操作系统的软件，不同操作系统的对异步IO的支持程度不同，在较新的linux上，它会使用`epoll`机制  
linux的IO机制主要的进化过程如下
```mermaid
graph LR
    A[常规阻塞IO] --> B[select]
    B --> C[poll]
    C --> D[epoll]
```
`epoll`是一个现代的异步IO机制，它是高性能服务器必不可少的一部分  
简单来说，`epoll`机制有三个主要的函数
```c
int epoll_create (int __size);  // 创建epoll对象，返回一个文件描述符指向epoll实例

// 对监听的文件描述符集合进行操作，可以增加，修改，删除
int epoll_ctl (int __epfd, int __op, int __fd, struct epoll_event *__event);

// 调用时阻塞直到监听的文件描述符集合中有事件发生，返回发生事件的文件描述符集合
extern int epoll_wait (int __epfd, struct epoll_event *__events,int __maxevents, int __timeout)
```
pg主进程启动时，会创建一系列的辅助进程，包括后台写进程，压缩进程等等，随后它会创建一个`epoll`实例，然后进入循环，不断等待`epoll`事件发生、
处理事件、继续等待  
当pg从`epoll_wait`中返回时，它会处理发生的所有事件，如果是客户端的连接，它会通过`BackendStartup`函数创建一个进程处理客户端的请求  
采用这样的模型，在没有客户端连接时，pg主进程长时间阻塞，几乎不占用CPU，在高负载时，`epoll_wait`一次能返回多个事件，性能也非常好

# 总结
## C的缺点
在pg这个项目中可以看出很多C的缺点，然而有些缺点是编译型语言的，所以这里只列出了相比C++，以及Rust的缺点
1. 抽象程度不及C++，虽然C也有一定的抽象，但是还是不能屏蔽足够的细节，在一个有140万行源码的项目中体现非常明显
2. 缺少命名空间机制，在一个140万行源码中的项目考虑一个不会重复的函数难度还是有点高的，其次导致了标识符的名字普遍非常长
3. 异常处理机制太过原始，使用`sigsetjmp`和`siglongjmp`，本质上只是全局goto，不易调试和理解
4. 语言没有常见数据结构的标准库，导致开发一个大型项目的一个必不可少的工作就是重新造轮子

## 读后感
```text
➜  postgres git:(master) ✗ fd -e c -e h | xargs wc -l | tail -n 1
 1562969 total
```
PostgreSQL源码非常大，有150万行，本次课程任务也只是看到了其中冰山一角中的一角，许多内容由于能力有限精力有限，并没有深入研究。  
它向我们展示了一个关系型数据库理论的丰富和深厚，以及一个大型开源项目的复杂性，这对我今后的学习和工作都有很大的帮助。