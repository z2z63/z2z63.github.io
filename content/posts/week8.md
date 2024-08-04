---
title: "努力成为Python core dev的第八周：从libc到python，我要的内存从哪儿来的？"
author: z2z63
date: 2024-08-04T14:21:56+08:00
---
实习期间摸了不少的鱼，通勤路上在看各种文档，在公司摸鱼时就在看glibc或cpython的源码，花了不少时间总算是理解了部分。所谓内存管理系统充斥着各种指针运算，抽象程度非常高，这篇文章我希望是定性的去描述内存分配系统，因为源码总是枯燥又无聊的，如果不是它出现了问题，我想大部分人都不会去看源码吧
## 总览
glibc作为libc的GNU实现，按照分层的角度，它往下是操作系统，往上是用户代码，它将操作系统的许多能力以C标准规定的形式提供，并且在linux平台，glibc还提供了稳定的系统调用接口

从操作系统的角度，每个进程都有自己的地址空间，当进程需要更多的内存时，有两种方式，可以通过`mmap`系统调用申请一块可读可写的内存，还可以通过`brk`系统调用扩张堆区。无论使用哪种方式，操作系统分配内存的最小单位是页，一般是4K

4K是一个非常粗的粒度，从操作系统的角度，4K是为了减少内存管理系统的开销并减少内存碎片的一个权衡结果，但对于用户进程来说，4K还是太大了，因此用户态还需要一个内存管理系统，用于满足用户程序零散、频繁的内存需求

glibc提供了一个内存管理系统，在linux平台，几乎所有进程都会链接到glibc。包括解释语言，诸如shell、python。它们如果需要访问操作系统，也要链接到glibc。因此glibc是用户程序的最底层，简化了用户程序与操作系统的交互
> 如果只使用系统调用的ABI接口，就不必链接到glibc。但需要写内联汇编，而且直接使用系统调用难度高，移植性差

分层并不能解决所有问题，许多用户程序会在glibc提供的内存管理系统之上再实现一个自己的内存管理系统。python在编译时，可以选择是否使用python内置的内存管理系统，如果选择否，就会直接使用libc的内存管理系统。为了性能和开销、这个选项是默认打开的

## 前置知识
阅读glibc和python的源码需要不少的指针经验，还需要有从汇编角度理解C代码的能力
- C的结构体可以认为是一块内存+各字段的偏移+各字段的数据长度。编译后，结构体成员的访问会变成地址运算+地址访问
- 许多平台都有数据对齐的要求，数据不对齐轻则读取速度降低，重则无法访问数据
- 申请一块内存时，这块内存要求是连续的，越大的连续内存申请越难以满足
- 内存碎片，即由于不规律的索取内存，内存千疮百孔，即使空闲内存总和满足了申请大小，但不存在足够大的连续内存而无法满足内存申请，导致内存使用率低下

## Python的内存分配系统
Python的语言特性依赖于大量小对象的创建，例如函数传参、本地变量访问、unicode对象等，导致Python的内存需求是大量、频繁、琐碎的。

如果直接使用libc提供的内存分配系统，由于大量小块内存的请求，会产生大量的内存碎片，不仅仅增加了进程的内存使用，而且使用系统调用向操作系统申请内存这个过程很慢，降低了Python解释器运行速度

为了缓解这种现象，Python内置了一个简单的内存分配系统。相比libc，它会尝试占用更多的内存，然后满足大量小块内存申请的同时减少内存碎片的产生。如果可行，它也会将闲置内存归还给操作系统

Python有三套内存管理系统，一套是内置的内存管理系统，在release模式下使用，一套是调试时使用的内存管理系统，用于开发CPython时帮助发现潜在的问题，最后一套是原始的内存管理系统，即直接使用libc的内存管理系统
```C
typedef struct {
    /* user context passed as the first argument to the 4 functions */
    void *ctx;

    /* allocate a memory block */
    void* (*malloc) (void *ctx, size_t size);

    /* allocate a memory block initialized by zeros */
    void* (*calloc) (void *ctx, size_t nelem, size_t elsize);

    /* allocate or resize a memory block */
    void* (*realloc) (void *ctx, void *ptr, size_t new_size);

    /* release a memory block */
    void (*free) (void *ctx, void *ptr);
} PyMemAllocatorEx;
```
结构体`PyMemAllocatorEx`相当于一个内存管理系统的接口，只要实现了这个接口，就能将此内存管理系统用于CPython中

此外，C标准规定malloc或calloc在申请内存的大小为零时，[其结果未定义](https://en.cppreference.com/w/c/memory/malloc#:~:text=If%20size%20is%20zero%2C%20the%20behavior%20of%20malloc%20is%20implementation%2Ddefined.)。Python为了其跨平台特性，将申请内存大小为零的请求转变为申请内存大小为1的请求，消除了UB

Python管理内存分为三个层级：`arena`，`pool`，`block`
### arena
一个`arena`大小为1MiB，一个`arena`包括多个`pool`
```C
struct arena_object {
    uintptr_t address;                  // arena的起始地址，直接使用mmap分配这块内存
    block* pool_address;                // 指向下一个未初始化的pool
    uint nfreepools;                    // 记录该arena中有多少个空闲的pool
    uint ntotalpools;                   // 该arena中所有的pool，包括空闲pool和已使用的pool
    struct pool_header* freepools;      // 记录空闲pool的单链表
    struct arena_object* nextarena;     // 双向链表
    struct arena_object* prevarena;
};
```
`arena_object`只是一个用于book keeping的结构，`arena`的内存都是额外分配的

Python解释器运行时，存在多个`arena`，通过一个动态数组管理
```C
/* Array of objects used to track chunks of memory (arenas). */
static struct arena_object* arenas = NULL;
/* Number of slots currently allocated in the `arenas` vector. */
static uint maxarenas = 0;

/* The head of the singly-linked, NULL-terminated list of available
 * arena_objects.
 */
static struct arena_object* unused_arena_objects = NULL;
```
动态数组的首地址为`arenas`，长度为`maxarenas`，`unused_arena_objects`之后的数组元素是未使用的arena，并且他们通过单链表连接


### pool
一个pool包含多个block，而且一个pool的每个block的大小都是相等的。所以pool有一个大小类别，即sizeclass（sizeclass说明见block）
```C
struct pool_header {
    union { block *_padding;
            uint count; } ref;          // _padding仅仅用于对齐，count表示该pool分配了多少个block
    block *freeblock;                   // 单链表组织空闲block
    struct pool_header *nextpool;       // 指向下一个与同大小类别的pool
    struct pool_header *prevpool;       // 前一个pool，组成双链表
    uint arenaindex;                    // 该pool所属的arena在`arenas`动态数组中的索引
    uint szidx;                         // 大小类别的索引
    uint nextoffset;                    // 距离下一个空闲block的偏移，相对的起始地址为pool首地址
    uint maxnextoffset;                 // 空闲blocks中最大的偏移
};
typedef struct pool_header *poolp;
```
### block
block的大小有`16`，`32`，`48`，`64`等等，以`16`为阶梯大小递增,这是block的大小类别，`16`的大小类别索引为`0`，`32`的大小类别索引为2，以此类推

```C
/* When you say memory, my mind reasons in terms of (pointers to) blocks */
typedef uint8_t block;
```
block的定义非常有意思，比较考验对C的理解

C一个非常灵活的地方在于，给结构体分配内存时，分配的内存大小不一定是结构体的大小。以结构体
```C
struct MyStruct{
    int a；
}
```
为例，可以给`MyStruct`分配更多的内存
```
+---------------------+
|       int a         |
+---------------------+
|       空  闲         |
|                     |
|       空  间         |
+---------------------+
```
多于的空间可以解释为其他用途的数据

此处`block`的大小在是由其所在的`pool`决定的，所以`block`没必要再记录自身的大小

此外，`block`的使用中经常出现`*(block**)b`，实际上`block`隐含了一个`next`结构体成员

可以将`block`的定义改为以下定义
```C
struct block {
    struct block* next;
}
```
与原`block`定义是等价的，`*(block**)b`也可以改写成`b->next`，这样可读性更好
> **Note:** 以上改写基于一个事实：next成员的偏移为零，其地址与结构体首地址相同

`block`记录了这一小块内存的起始地址，假设该`block`所属`pool`的大小类别为`16`，即`block`表示的一小块内存的大小为`16`
- `block`正在被使用时，它表示的`16`字节的内存完全交给上层使用，`block`本身不额外占据空间
- `block`闲置时，前`8`个字节（64位机器的指针宽度）记录了结构体成员变量`next`，`next`指向下一个空闲的`block`

可以认为，一个`pool`的所有空闲`block`组成了一个单链表，而`pool->nextoffset`记录了链表头

`pool`的内存视图如下
```
+-------------------------------------------------------------------+
| pool_header  |  block1  | block2 | block3 | block4 | block5 | ... |
+-------------------------------------------------------------------+
```
可以看出，`pool_header`在分配内存时，也分配了多于`pool_header`大小的内存（实际上，一个`pool`大小一般是16KiB）
### usedpools
`usedpools`可以说是整个Python内存管理系统中最精彩、最能体现C奇技淫巧的部分
去掉部分条件编译后如下
```C
#define PTA(x)  ((poolp )((uint8_t *)&(usedpools[2*(x)]) - 2*sizeof(block *)))
#define PT(x)   PTA(x), PTA(x)

static poolp usedpools[2 * ((NB_SMALL_SIZE_CLASSES + 7) / 8) * 8] = {
    PT(0), PT(1), PT(2), PT(3), PT(4), PT(5), PT(6), PT(7)
    , PT(8), PT(9), PT(10), PT(11), PT(12), PT(13), PT(14), PT(15)
    , PT(16), PT(17), PT(18), PT(19), PT(20), PT(21), PT(22), PT(23)
    , PT(24), PT(25), PT(26), PT(27), PT(28), PT(29), PT(30), PT(31)
}
```
`usedpools`非常巧妙地组织了正在使用的`pool`，它是分配内存时的快速通道。
> **Note:** 理解`usedpools`需要画一些草稿辅助

`usedpools`被视为一个数组，每两个`poolp`表示数组的一个元素（entry），数组的一个元素即一个链表头，链表头是一个环形双向链表的哨兵节点（哨兵节点不存储数据），数组的索引即大小类别的索引

假设要分配`27`个字节，首先向上取整到`16`的倍数，即取整到`32`，`32`对应的大小类别的索引为`2`,于是访问`usedpools[2 + 2]`，得到一个`poolp`。在初始化时，`usedpools[2 + 2]->nextpool`和`usedpools[2 + 2]->prevpool`指向的值都是`usedpools[2 + 2]`的地址，即表示该环形双向链表为空；如果该大小类别已经有`pool`分配了，`usedpools[2 + 2]`表示的环形双向链表就会有两个节点（包括哨兵节点）

`usedpools`第一次见时，理解起来很费劲。但理解其意图后，`usedpools`的用法还是有些可读性。它去除了`pool_header`结构体中不必要的部分，可以认为是一种索引。`usedpools`的元素大小越小，cache line就能放下更多的`usedpools`元素，性能就越高

`usedpools`已经有一位core dev讲解过
{{<bilibili BV1qV4y1J7gY>}}
### malloc流程
python有四套内存管理系统，可以通过编译参数指定使用哪一个
- 编译参数为`--with-pydebug --without-pymalloc`，会使用`_PyMem_DebugRawMalloc`作为malloc入口
- 编译参数为`--with-pydebug`，会使用`_PyMem_DebugMalloc`作为malloc入口
- 编译参数为`--without-pymalloc`，会使用`_PyMem_RawMalloc`作为malloc入口
- 编译参数无以上提及的两个参数，会使用`_PyObject_Malloc`作为malloc入口

`--with-pydebug`的目地是为了开发cpython时，帮助发现内存问题，`--without-pymalloc`的目地是直接使用libc的内存管理系统

一般来说，python以release模式编译并发行，所以最主要的malloc入口是`_PyObject_Malloc`，以下定性地阐述其流程
- 如果申请大小大于一个阈值（512字节），就直接使用`_PyMem_RawMalloc`分配内存，它将大小为零的内存申请转换为大小为1的内存申请（为了消除UB），然后直接使用libc的`malloc`，`malloc`申请的内存直接返回
- 以下部分的申请大小都小于阈值
  1. 将申请内存大小向上取整到`16`的倍数，并计算其sizeclass的索引
  2. 访问`usedpools[size + size]`，得到该sizeclass对应的`pool`的环形双向链表
    - 如果链表中存在元素，则从`pool->freeblock`中取出一个空闲block
      - 取出后如果`pool`已满，将该`pool`从`usedpools`中移除
      - 如果未满，返回
    - 如果链表中不存在元素，则尝试建立一个新的`pool`，并从其中取`block`
      - 如果不存在可用的（非全满）的`arena`，就创建一个`arena`，并将其加入`arenas`表示的动态数组的管理中
      1. 至此可以保证一定有一个`arnea`可以分配出一个`pool`
      2. 从`arena`中取出一个`pool`，并处理取出`pool`后`arena`全满、`pool`未初始化等情况
      3. 从该`pool`中取出
      4. 将取出的`pool`插入到`usedpools[size + size]`表示的环形双向链表中

一些细节：
1. 大部分内存请求都是小规模的，会进入python内置的内存管理系统
2. 大部分小规模的内存请求可以通过sizeclass的索引查找`usedpools`快速满足
3. `arenas`表示的动态数组中，会优先使用第一个未满的`arena`，用满后才会开辟新的`arena`
4. 从一个`pool`取`block`时，优先取地址更大的`block`，即使存在低地址的block归还给`pool`。这样可以将查找推迟到该`poool`的所有`block`都分配过一次之后
5. 大量使用`__builtin_expect`，主动提供分支预测信息，加快流水线执行机器指令

### 总结
- 所有内存请求都规整到`16`的倍数，一个`pool`的所有`block`的大小都是相等的，减少了内存碎片
- `usedpools`按照大小类别快速满足内存请求，体现了“加速大概率事件”这一计算机体系架构的核心思想
- 优先使用最满的`arena`，减少内存使用量