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

glibc提供了一个内存管理系统，在linux平台，几乎所有进程都会链接到glibc。包括解释语言，诸如shell、python。它们如果需要访问操作系统，也要链接到glibc。因此glibc是用户程序的最底层，简化用户程序与操作系统的交互
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
      1. 至此可以保证一定有一个`arena`可以分配出一个`pool`
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
## glibc的内存管理系统
glibc的内存管理系统非常复杂。也许是因为glibc开发完成于“古代”，源码风格非常乱，花括号缩进可读性非常差，几百行的if else分支随处可见，宏里还会使用局部变量，不推荐阅读  

我花费了一些时间阅读`malloc`实现后，只理解了部分。以下大部分内容都来自于glibc的[wiki](https://sourceware.org/glibc/wiki/MallocInternals)，但我希望它的内容比wiki更容易阅读

### arena
glibc向操作系统索取内存的方式有两种，一种是通过`brk`扩展堆区，另一种是通过`mmap`得到映射的一块内存。glibc将通过`brk`扩展的堆区称为main arena，它是第一个初始化的arena

与MSVC不同，glibc不存在单线程版本和多线程版本。为了实现`malloc`的线程安全，arena对象有一个互斥锁字段，用于控制互斥访问

为了缓解多线程环境下的互斥时间开销，一个进程可以有多个arena，一个arena可以有一个或多个heap（此处的heap仅仅指连续内存，不是进程的heap），一个heap有多个chunck，chunck是glibc管理内存的最小单位，返回给用户的内存首地址也是chunck的**一部分**
> **Note:** arena拥有的内存不一定不是连续的，因为只有heap才是连续的，而一个arena可以拥有多个heap

arena的结构如下（省略部分），bin相关介绍见下文
```C
struct malloc_state
{
  __libc_lock_define (, mutex);     // 互斥锁用于互斥访问arena
  int flags;
  int have_fastchunks;              // 记录是否有fastbin
  mfastbinptr fastbinsY[NFASTBINS];
  mchunkptr top;
  mchunkptr last_remainder;
  mchunkptr bins[NBINS * 2 - 2];
  unsigned int binmap[BINMAPSIZE];
  struct malloc_state *next;        // 形成单链表
  struct malloc_state *next_free;
};

### heap
```
heap的结构如下
```C
typedef struct _heap_info
{
  mstate ar_ptr;                // 指向heap所属的arena
  struct _heap_info *prev;      // 形成单链表
  size_t size;                  // 此heap拥有的连续字节数
  size_t mprotect_size;
  size_t pagesize;              // 分配此heap时使用的页大小，一般是4K
  char pad[-3 * SIZE_SZ & MALLOC_ALIGN_MASK];   // 用于使后续数据对齐
} heap_info;
```
![](https://sourceware.org/glibc/wiki/MallocInternals?action=AttachFile&do=get&target=MallocInternals-heaps.svg)

### chunck
Q：为什么`malloc`需要提供申请的内存的大小，而`free`不需要
A：因为`malloc`返回的内存是chunck的一部分，而chunck记录了该chunck的大小

chunck是一块长度不固定的内存，两个相邻的chunck可以合并成一个更大的chunck

chunck结构如下
```C
struct malloc_chunk {
  INTERNAL_SIZE_T      mchunk_prev_size;// chucnk空闲时表示临接的chunck的大小，用于chunck合并
  INTERNAL_SIZE_T      mchunk_size;     // chunck的大小
  struct malloc_chunk* fd;              // forward的缩写，在chuck空闲时用于形成双向链表
  struct malloc_chunk* bk;              // back的缩写，在chuck空闲时用于形成双向链表
  struct malloc_chunk* fd_nextsize;     // 指向更大的chunck，当chunck较大时用于形成双向链表，chunck较小时不使用
  struct malloc_chunk* bk_nextsize;     // 指向更小的chunck，当chunck较大时用于形成双向链表，chunck较小时不使用
};
```
由于需要记录一些元数据，一个chunck会有一些额外的空间开销  

规定一个chunck的大小为8字节的倍数，当用户申请的空间+chunck额外开销不足8字节倍数时，需要向上取整。由于chunck的大小是8字节的倍数，`mchunk_size`字段的低三位一直是零，可以用来记录一些额外的信息
```
+-------------+---+---+---+
| mchunk_size | A | M | P |
+-------------+---+---+---+
```
- A(0x4)  
  用于标记该chunc所属的heap是否是通过`mmap`获得的。增加这一标志后，如果`A`为0，表示chucnk来自主arena，即进程的堆区，如果`A`为1，表示chunck来自映射的内存。由于`mmmap`返回的地址永远是页对齐的，可以通过chunck地址的高位确定它来自的heap 
- M(0x2)
  当申请的内存太大时，malloc会直接使用`mmap`创建一个超大的chucnk，`M`位标记该chunck是直接使用`mmap`创建的
- P(0x1)
  标记前一个邻接的chunck正在被使用，此时`mchunk_prev_size`字段无效，设置该位会阻止邻接chunck的合并

`malloc`返回的是分配的chunck的`mchunk_size`之后的地址，即`fd`和`bk`是分时复用的
<table><tbody><tr>  <td style="text-align: center;"><p class="line862">In-use Chunk</p></td>
  <td style="text-align: center;"><p class="line862">Free Chunk</p></td>
</tr>
<tr>  <td><span class="anchor" id="line-96"></span><p class="line891"><object data="https://sourceware.org/glibc/wiki/MallocInternals?action=AttachFile&amp;do=get&amp;target=MallocInternals-chunk-inuse.svg" title="" type="image/svg+xml">MallocInternals-chunk-inuse.svg</object></p></td>
  <td><p class="line891"><object data="https://sourceware.org/glibc/wiki/MallocInternals?action=AttachFile&amp;do=get&amp;target=MallocInternals-chunk-free.svg" title="" type="image/svg+xml">MallocInternals-chunk-free.svg</object></p></td>
</tr>
</tbody></table>

此外，在chunck结构体之后，还有一个隐含的冗余`size`字段，它用于保护chunck。当用户不慎使用了错误的指针运算修改了`mchunk_size`字段时，glibc可以通过冗余的`size`字段判断出异常，并发出警告


一个arena通过四个链表记录了空闲的chuck，这些链表被称为bins

#### fastbin
arena的`mfastbinptr fastbinsY[NFASTBINS];`字段表示了fastbin，它是一个数组，数组的每个元素都是一个单链表的表头，链表中的所有chunck的大小都是相同的

与python相似，fastbinsY的索引也表示大小类别，通过申请内存的大小可以快速确定索引。fastbin是`malloc`申请内存的快速通道

fastbin的`P`位置零，用于阻止chunck合并
#### unsorted bin
释放后的chunck会先进入unsorted bin，随后（触发某个条件后）它们会被排序，然后进入其他bin
#### small bin
small bin是normal bin的一部分，它们通过双向链表组织。normal bin即arena的`mchunkptr bins[NBINS * 2 - 2];`成员

当unsorted bin排序后，chunck如果足够小，会进入small bin。此时尝试将该chunck与small bin中已有的chunck进行合并，合并后的chunck进入large bin。因此，small bin不存在邻接的chunck

当从small bin中取出chunck时，只需要取出第一个足够大的chunck即可
#### large bin
当unsorted bin排序后，chunck如果足够大，会进入large bin，此外，还可以由small bin中的chunck合并得来

当从large bin中取出chunck时，需要寻找足够大的chunck中最小的一个，此时的chunck可能还是比需要的大小更大，需要将该chunck分为两个chunck，一个chunck可以恰好满足需要的大小，剩下的chunck可以继续使用

### tcache
为了加快`malloc`的速度，可以缓存一些空闲的chunck，这些chunck是每个线程都有的（Thread Local Storage），即per thread cache，简称tcache

tcache定义如下
```C
typedef struct tcache_perthread_struct
{
  uint16_t counts[TCACHE_MAX_BINS];
  tcache_entry *entries[TCACHE_MAX_BINS];
} tcache_perthread_struct;
static __thread tcache_perthread_struct *tcache = NULL;
```
`__thread`是GCC的私有关键字，用于声明线程局部存储。当一个线程第一次使用`malloc`时，会触发tcache的初始化流程

tcache表示一个数组，其中每个元素是单链表的表头，但指向的不是chunck首地址而是payload，这样的chunck可以直接返回给用户。每个单链表的所有chunck的大小都是相等的，entries的索引表示大小类别，就像fastbin，可以通过需要申请的大小快速计算出tcache的索引

由于tache是线程局部的，访问tcache不必加锁，比fastbin更快（fastbin可以通过原子操作访问）。当tcache不存在恰好满足的chunck时，会回退到fastbin

### 总结
glibc源码非常晦涩，有许多GCC特性，它是一个比较通用的内存管理系统，在空间开销、速度、减少内存碎片三个角度做了充分的权衡。这也导致了它在一些场合下性能不足某些
特化的内存管理系统

## python vs glibc
相同
- 使用大小类别使大部分内存请求都在在 O(1) 的时间复杂度内完成
- 都使用了缓存加快速度（usedpools、tcache）

不同
- Python的内存管理系统开销非常大，实际上，Python语言本身就是一个开销比较高的语言
- Python的内存管理系统强调规整化内存请求，减少内存碎片。glibc强调通用性
  

最后，来复习一下计算机系统结构中的8个伟大思想
- 面向摩尔定律的设计
- 使用抽象简化设计  
  Python使用`arena`、`pool`、`block`抽象描述内存分配系统，而glibc使用`arena`，`heap`，`chunck`，使用上述抽象将内存管理系统简化为
  操作各个对象
- 加速大概率事件  
  Python使用`usedpools`，glibc使用tcache和fastbin。对于绝大部分内存请求，只需要根据请求的大小类别就可在常数时间内完成内存的分配
- 通过并行提高性能  
  glibc提供了多个arena，本质是降低锁的粒度，提高内存管理系统的并发度。此外，glibc还使用了原子操作访问fastbin，甚至使用线程局部的tcache，实现“无锁并发”（实际上操作的数据都不是同一个）  
  python由于GIL的存在，内存管理系统并没有考虑并发
- 通过流水线提高性能
- 通过预测提高性能  
  现代CPU通过分支预测提高流水线的吞吐率，分支预测失败时，需要清空流水线，开销较大。Python和glibc都使用了GNU的`__builtin_expect`控制分支的汇编代码生成，有利于提高流水线的吞吐率
- 存储器层次  
  内存管理系统并没有涉及主存以外的存储器，但从缓存的角度，`tcache`和`usedpools`都充当了缓存加快了内存分配速度  
  此外，`usedpools`去除了`pool_header`中无用的其他数据，使得cache line中能存放更多的`usedpools`元素，有利于使用高速缓存加快速度
- 通过冗余提高可靠性  
  glibc通过冗余`size`字段，实现了一定程度的发现内存错误甚至是修复错误的功能  
  python由于其内存分配系统的用户是CPyhton和Python C扩展的开发者，CPython提供了`_PyMem_DebugMalloc`帮助他们发现内存错误。`_PyMem_DebugMalloc`的实现中实际上包含了一些冗余信息，但不在本文范围之内

## 关于内存分配系统
我认为内存分配系统实际上是一个内存分时复用系统。提及分时复用，大部分人也许会想到计算机网络学到的分时复用（Time Division Multiplexing，TDM）

如果将每次的内存申请看作用户请求使用一定的带宽，而进程拥有的所有内存看作线路，就能看出内存分配系统与分时复用系统的相似性

内存分配系统存在的必要基于两个事实
- 内存不是无限的
- 进程需要长期运行，如果不分时复用内存，迟早用完所有的物理内存
  
由此可以推出，某些短期运行的进程，也许可以不手动释放内存，可以依靠进程退出时操作系统释放进程占据的所有页这一手段来释放内存