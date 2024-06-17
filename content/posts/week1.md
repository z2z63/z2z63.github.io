---
title: "Week1"
author: z2z63
date: 2024-06-17T19:36:40+08:00
---
最近关于博客的内容考虑了很多，怎样让博客的内容更有价值、怎样输出内容等等。也考虑了未来如果内容做好了，可以开始做SEO等等。因为我认为博客还是一种比较轻松的阅读内容，如果选择输出干货，一来读者不一定了解这方面的知识，二来读者如果非常了解这方面的知识，这篇文章也没有价值；如果想加深对某领域的了解，完全可以看一些经典的书籍，他们的内容比博客好多了，于是我决定改变博客的内容。希望我的博客是启发性的，读者看完后能够对某个小领域有个大致的理解，或者看完后产生兴趣，去阅读更专业的书籍、文档等等。换而言之以后的文章相比深度更倾向广度，比起话题更想随谈。另外我能力也不足以输出深度足够的文章。

# 外部归并排序
最近打数据库比赛，我负责的一道题是归并连接
![](https://raw.githubusercontent.com/z2z63/image/main/202406172000587.png)
需要使用归并排序算法，准确的说是external merge sort，即在内存有限的情况下，利用外存辅助排序，其核心思想是一种经典的算法：分治法（分而治之，divide-and-conquer）。  
假设内存只能使用1G（大致范围，不考虑细枝末节），而需要排序10G的记录，归并排序的步骤是
1. 将10G内存分十次读取到内存，在内存中完成1G记录的排序（可以使用常见的排序算法，例如快速排序），排序结果写入总共10个文件
2. 将10个文件分别读取一块到内存（假设读取100M，总共使用1000M，没有超过1G限制）
3. 从每块的第一个记录中选择最小的一个，取出，输出（每块中最小的记录肯定是第一个，因为块内已经排好序了）
4. 重复3，如果某块使用完，就从对应文件读取下一块
5. 10个文件的内容全部使用完毕，完成排序

算法不难理解，然而实现起来就会遇到各种各样的问题，
- 如果有10.1G的记录，按照上述办法，就会有一个0.1G的文件
- 如果一块大小是80M，该文件的最后一块就是64M
- 如果记录只有900M，算法也应该能正常处理，而且最好不使用外存（但在数据库场合下，前一个算子执行时输出多少记录是不可能预先知道的，例如select算子，可以携带where语句的条件，实际输出的记录数量只能确定范围而无法具体知道其数量）
- 文件应该保存在哪里（放在tmpfs就不满足要求了，因为tmpfs就是使用内存实现的）
- 文件IO怎么做（直接用`read`，`write`系统调用？使用带缓冲的libc？使用`mmap`？）

于是实现这样一个外部归并排序，从最开始的查找资料，理解算法，到选择实现路径，再到动手实现、抽象，重构，分离，加上各种错误处理，考虑各种corner case，已经非常复杂了

另外再考虑使用google test写测试，怎样才能写出一个好的测试，把问题都找出来（自己写测试找bug比写了一堆代码，提测时才发现问题快多了！）  

再考虑借鉴一下现成的算法实现，有例如stxxl这样非常全面系统的大数据处理库，也有github上十几颗星星，一两个文件的实现，还有使用其他语言实现的，等等。怎样保证正确的同时控制复杂度，可以看出从理论到实践的差距非常大，实践的内容已经远超理论的内容了，而我理论的内容也只是了解了部分，只能说希望未来的我能轻松做到吧...

# object header
所谓object header就是一个对象的头部，在许多高级语言中对象都有object header。从理论上也能推导出一定需要一个额外的区域保存一些信息，不一定叫做object header，也可以是object footer

面向对象的一个特点是多态，多态可以理解为子类对象能够完美的嵌入到需要父类的地方，而如何知道该调用父类方法还是子类方法，只能在运行时确定，所以OOP一定要把类型信息带入运行时，这也是OOP的一个overhead（开销）

然而cpp比较特殊，虽然它也是OOP语言，但cpp的大部分（？）对象都是没有object header的，可以做一个简单的实验验证一下
![](https://raw.githubusercontent.com/z2z63/image/main/202406172054157.png)
我的猜测是，cpp首先favour zero cost abstraction(青睐零开销抽象)，让每个对象仅仅因为OOP的需要就带上一个绝大多数场合下都不会使用的object header，是不可接受的  
其次，cpp相比其他传统OOP语言，有很多不同的地方
1. cpp的对象和原始类型不存在鸿沟，反而是可以密切配合的，对象可以轻易取其地址，`malloc`和`new`的区别也仅仅是`new`相比`malloc`多做了类的构造函数，而传统OOP语言，对象和原始对象存在鸿沟，互操作时需要包装类，例如java需要使用繁琐的wrapper box，而JS会自动完成原始类型和对象的转换。
2. cpp的对象和原始类型可以随意放在堆上或者栈上，而传统OOP则将对象放在堆上而原始类型放在栈上
3. cpp的多态必须使用指针，并且必须有虚拟类

结合以上原因，我猜测也许虚拟类的子类的对象会有类似object header的东西，否则从理论上推导，cpp就无法完成多态了
# runtime
上文出现的两个运行时，分别使用了两个不同的含义。
1. 含义一：程序的时态
程序的时态，可以包括开发时，编译时，链接时，装载时，运行时等等，这也是从字面意义上理解runtime
2. 含义二：runtime system的缩写
runtime system提供了程序运行的环境。就算是汇编语言也需要相应的环境才能运行，C的运行时提供以下运行时支持
    1. 栈  
        在操作系统启动时就已经准备好了，因为操作系统主要是C编写的，也需要栈的环境
    2. libc  
        包含C标准定义的函数，有与操作系统交互的函数，也有字符串处理函数
    3. dynamic linker  
        动态链接器用于将多个目标文件中的代码段，数据段等链接起来，于是在运行时能够调用其他目标文件中的函数，linker完成了elf装载完成后bootstrap的过程，bootstrap先于`__start`函数的执行，而`__start`函数先于`main`函数的执行
    4. 多线程支持
        例如线程私有变量，线程安全版本的函数，多线程环境下的`exit`
    5. 内存分配系统
        C标准中提供的`malloc`系列函数，提供了内置的内存分配系统，用于管理堆区
    6. IO缓冲
        libc在操作系统IO操作原语基础上，提供了带缓冲的IO，例如`fread`,`fwrite`等等，并提供了三种缓冲选项（无缓冲，行缓冲，全缓冲），用于在大部分场合下，提高应用程序IO速度，并减小开发者心智负担

> **_NOTE:_** 如果对以上内容感兴趣，参见《程序员的自我修养——链接、装载与库》
# exec的极限
在给上文提及的external merge sort写测试的时候，我最开始使用了非常烂的参数，导致测试程序在一个目录下大量的创建了辅助排序用的文件，它们使用`mkstemp`创建，模板为`aux_sort_fileXXXXXX`，`mkstemp`会自动将末尾的`X`替换成随机的字母，并创建、打开该文件，这样就不必考虑为文件起一个不会重复的名字

为了删除这些文件，我最开始使用的命令是`rm aux*`，然而shell报错"Too many arugments"  
然后我使用的命令是`fd 'aux*' --exec rm {}`，`fd`是`find`的加强版，这个命令相当于`find . -name 'aux*' -exec rm {} \;`

那么"Too many arugments"是为什么呢？  

Linux系统许多地方都是有限制的，例如`hostname`（主机名）长度不能超过某个值，路径长度不能超过某个值等等，这是因为动态长度的东西很难处理，内核实现中为了简单，往往会规定一个`limit`，并定义超过`limit`后的行为（一声不吭？报错？自动截断？）

决定"Too many arugments"的`limit`是`ARG_MAX`，即命令行的最长参数长度，因为`rm aux*`中的`*`是shell的wildcard（通配符）, shell将`aux*`替换成所有文件名开头为`aux`的文件，然后执行命令（内核不会特殊对待`*`，`*`是shell层面的feature），当文件特别多时（当时也许有几千或几万个文件），就有可能触发`limit`

`ARG_MAX`起作用的范围是`exec`系统调用，libc提供的`exec`系列函数（包括`execl`,`execlp`,`execle`等等）只是`exec`系统调用的封装，`ARG_MAX`限制了`exec`能传入的参数的长度。而shell本质上只是`exec`系统调用的一个封装，自然也会受到`ARG_MAX`的限制（参考一些简易shell的实现，只涉及管道，fork，exec）

linux是类unix系统，在unix发展历史上，因为过多vendor(厂商)分别开发和维护自己的unix系统，导致unix分裂，于是若干大头（IEEE，美国政府等）牵头指定了若干标准，有POSIX和Single Unix Specification，它们对以上提及的各种`limit`都有详细的定义，提倡unix系统提供的`limit`应该至少大于某个值，即标准规定的至少应该满足的值

此外，POSIX和Signle Unix Specification有若干版本，以及各自的扩展，例如XSI就是POSIX.1的扩展。unix是使用C开发的，C在历史上也有分裂的时期，于是人们也成立ISO/IEC制定了C的标准，这些标准是语言层面的，不会单独为Unix考虑，更多地考虑中立，但也影响了Unix，例如long应该有多长，INT最大值是多少等等

举一些例子说明ISO C, POSIX, Signle Unix Specification如何相互影响
1. ISO C定义了`FILENAME_MAX`，但随后POSIX定义了`NAME_MAX`和`PATH_MAX`作为`FILENAME_MAX`更好的替代
2. `read`系统调用原来的接口是
    ```c
    int read(int fd, char* buf, unsigned nbytes);
    ```
    ISO C要求泛型数据应该使用`void*`，于是`char* buf`被改成了`void* buf`  
    POSIX.1 引入了`size_t`表示数据的大小，于是`unsigned bytes`变成了`size_t nbytes`  
    此外POSIX.1还引入了`ssize_t`作为`size_t`的有符号版本，以支持负数，`read`的返回值类型也被改成`ssize_t`

    最终的版本
    ```c
    ssize_t read(int fd, void* buf, size_t nbytes);
    ```

为了使自己的程序能够在迁移到POSIX兼容机上，以上标准提供了一系列的机制以供开发POSIX兼容的程序
1. `limit`分为编译时`limit`，运行时`limit`，编译时`limit`是编译时常量，可以在编译时期通过引入诸如`<limit.h>`获取，运行时`limit`可以由诸如配置文件，命令行，系统调用等方式动态的改变，需要在运行时动态获取
   涉及的函数有`sysconf`, `pathconf`, `fpathconf`
2. 不同系统对POSIX的支持程度不一样，POSIX提供一系列Feature test macros供开发者检测POSIX特性的支持，并对不同的支持情况作出反应（使用#ifdef条件编译），这种方法只能处理编译时`limit`

# 标准与扩展
Unix，C/C++，Web都是多家vender，一个标准。vendor往往为了自己的利益，或者自己的需要，提供超过标准要求的功能，并推进这些功能加入标准  
这一方面是因为标准往往为了中立而非常谨慎，甚至有时候可以说是不作为，导致标准提供的功能不足以覆盖部分需求，另一方面，编译器的vender往往也是操作系统的vender，例如Microsft的Windows和Visual c++，Apple的iOS,MacOS和clang，以及GNU与Linux。造操作系统是一个非常艰巨的任务，vendor往往也会造自己的编译器以满足开发操作系统的需求  

举一个我打数据库比赛时遇到的情况，我希望对记录进行排序，记录为一块内存，大小在运行时获得，比较函数取出记录中的属性（基址+偏移，数据类型长度）然后比较属性大小，要使用哪个属性参与比较，也是运行时动态取得的
，考虑cpp提供的`std::sort`，它的数据长度依赖于类型，而类型是编译常量，所以无法做到。考虑来自C的`std::qsort`，它的原型如下
```c
void qsort(void base, size_t nmemb, size_t size,int (*compar)(const void , const void ))
```
因为比较函数`compar`是函数指针，无法使用lambda函数捕获外部变量，也就是说每次sql执行时，`compar`函数行为都是一样的，这肯定不能满足需求，不能实现比较任意属性  

我最终使用的是`qsort_r`
```c
void qsort_r(void base, size_t nmemb, size_t size,int (*compar)(const void, const void , void *),void *arg);
```
这是glibc提供的C标准的GNU扩展，也就是说只有glibc才有，换而言之只能在linux使用（关于OS, libc以后有机会单独讲）
这个函数传入一个额外的`void *arg`，然后它将`arg`作为第三个参数传入`compar`，就能实现动态的比较属性  

如何使用`qsort_r`？

因为`qosrt_r`是GNU扩展，man手册如是描述
>Feature Test Macro Requirements for glibc (see feature_test_macros(7)):
>
>      qsort_r():
>          _GNU_SOURCE

要使用`qsort_c`，首先要定义`_GNU_SOURCE`，然后引入声明了`qsort_r`的头文件`<stdlib.h>`

然后查看gcc预定义的宏
```
➜  bin git:(p6-merge-join) ✗  echo | g++ -dM -E -x c++ - | grep _GNU_SOURCE
#define _GNU_SOURCE 1
```
可以看到我的gcc已经定义了，也就是默认启动了GNU扩展，所以直接引入`<stdlib.h>`即可，无需额外操作  
然而其他版本的gcc也许没有预先定义，最优解法是在编译时通过命令行参数定义

以上例子可以看出标准往往是保守的，从Visual C++的各种`_s`版本函数可以也看出来这点

---
![](https://raw.githubusercontent.com/z2z63/image/main/202406172243329.png)
Visual C++的`_s`系列函数，例如`scanf_s`，`strcpy_s`,`sprintf`，是标准库对应函数的安全版本(security)，主要解决了buffer overflow问题，这些函数是visual c++的独占特性（或windows的独占特性），但是作为C标准的扩展进入了C标准，开发者可以在只引入标准库提供的头文件的情况下使用他们，在将别人的程序迁移至其他平台时造成了不少的麻烦！



> **_NOTE:_** 如果对以上内容感兴趣，参见APUE(《Unix环境高级编程》)