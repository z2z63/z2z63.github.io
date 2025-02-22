---
title: "OceanBase 数据库大赛初赛结束之后"
author: z2z63
date: 2024-11-10T15:38:53+08:00
---

## 写在前面

仔细数来快三个月没写博客了，虽然我也能找到各种各样的原因，实习离职、秋招、比赛等等，归根结底还是懈怠了。最近各种事项也基本结束，整天忙着无所事事，是时候重新动笔了

本文我将围绕即将结束初赛的 oceanbase 数据库大赛展开，但由于我不喜欢向别人讲解我敲的代码如何如何，所以我会偏向这次比赛涉及的理论、设计、想法  

在这次比赛前我因为准备秋招，花了一些时间读了两本书，我认为对比赛帮助非常大，本文提及的很多想法和设计也是参考了这些书

- C++ primer  
  一本挺厚的书，讲解 C++ 的各种特性，不过说实话看完这本书我也只能自称基本掌握 C++
- DataBase System Concepts  
  讲解数据库的基本理论，基本上大部分成熟的数据库涉及的理论都能在这本书里找到

---
append:  
两位非常厉害的队友: [@Soulter](https://soulter.top/)、[@bosswnx](https://bosswnx.xyz/)  
他们的 github: [@Soulter](https://github.com/soulter), [@bosswnx](https://github.com/bosswnx)  
我们的仓库: [bosswnx/miniob-2024](https://github.com/bosswnx/miniob-2024)  
队友的赛后记: [OceanBase 2024 初赛 MiniOB 开发记录](https://zhuanlan.zhihu.com/p/5953505884)、[OceanBase 数据库内核实现赛 / 自己实现一个数据库](https://blog.virtualfuture.top/posts/miniob/)  

## 现代语言的基础设施

所谓基础设施只是我自己胡编乱造的词。其他高级语言有各种完善的措施来发现错误或避免错误，比如 java，python， rust 等，基本来说，这些措施的目的都是尽量提前暴露错误，或者在出现错误时尽可能的采取合理的措施，防止错误扩大  
为了实现这个目的，有两种方向

1. 给编译器提供更多信息，在编译期检查出潜在的问题
2. 在运行时插入检查

按照以上的观点，C++的基础设施可以说非常少，首先是各种指针运算，指针访问，内存的申请释放等语言特性就有很多不仅仅没有编译期检查，也没有运行时检查，一旦出错了就是各种 undefined behavior（以下简称 UB）。其次就是标准库也存在许多 UB。例如容器访问越界也是 UB。那么 UB 到底是什么 behavoir 呢，这个问题我想无法解答。有时候 UB 导致程序异常，所以我们发现了这个问题并修复，但更多时候 UB 是无法依靠的，因为他完全可能在开发时符合我们的预期并使程序正常执行，并且在正式的生产环境就引发严重的问题

按照上篇文章批评b乎用户时我的观点，一定存在某种方法使得我们可以克服 C++的“缺陷“，否则不可能有大公司愿意使用 C++ 开发项目。而这些”方法“，也就是我在比赛初期尝试引入的基础设施

### miniob 使用的基础设施

#### 核心基础设施

sanitizer总的来说，就是编译器在一些关键处插入检查代码，检查程序中潜在的问题。它的一个非常大的优点是，可以在开发时使用 sanitizer 检查问题，然后在 release 时关闭 sanitizer，提高性能。这样即保证了正确性又不牺牲性能。这也是 do things in cpp's  way的方法，即尽量在编译期提供更多的特性，并且不影响运行时的性能（对于 sanitizer，就是不影响 release 运行时的性能），也就是运行时零开销

在初赛中，项目已有address sanitizer，这是一个用于检查指针越界、悬垂指针等内存相关问题的一个 sanitizer。我引入了undefined behavior sanitizer，这是一个检查 UB 的 sanitizer，可以说是消除 UB 的利器。  
除此之外，还开启了libstdc++ debug mode，它能检查 STL 容器的错误用例，解决了容器访问越界，迭代器失效等问题

以上提及的基础设施中sanitizer主要是对语言特性进行检查，因此非常依赖编译器为 sanitizer 开洞，并且某些 sanitizer 依赖一些平台特性，因此不同编译器 + 不同平台对 sanitizer 的支持程度不同，其中 gcc + linux x64 是支持最好的一个。而 libstdc++ debug mode 主要是靠编译和链接时的小技巧，因此只需要在构建系统中传入`-D_GLIBCXX_DEBUG`就行了

充分利用编译器的警告也是很好的方法，只需在构建系统中传入`-Wall -Werror`，就能强制开发者消除所有的警告，否则无法通过编译。由于 C++ 的特殊性，编译器一个不起眼的警告很有可能导致程序出现严重的错误，消除警告是一个虽然繁琐但绝对值得做的事情

一个非常好的实践是同时使用 gcc 和 clang 编译代码，并消除两个编译器的警告，因为 clang 的静态分析功能更加强大，能够在编译期发现更多问题

#### 次要基础设施

##### clang-tidy 检查代码规范

C++ 做一件事有很多种方法，这些方法中，有些是过时的，有些是不必要的， 有些是极易导致错误的，有些是风格良好的，有些是严谨的。因此 linter 在 C++ 开发中是非常必要的。同时，开启 linter 也能帮助自己学习现代的、工程化的 C++  
如果使用 CLion，就已经内置了clang-tidy和一系列checker，不需要自己配置，因此我非常推荐 C++ 初学者使用 CLion
VSCode 使用 clang-tidy 需要使用 clangd 扩展，并调整一些设置。实际上 VSCode 只要花时间配置，也差不多能达到 CLion 的高度，不过目前我并没有发现一个快速在父类/子类、重载函数的不同版本、头文件声明/源文件定义之间跳转的方法，所以这次比赛还是用的 CLion

##### clang-format 格式化代码  

可能有人认为代码风格只是一个个人偏好问题，但在工程中一致的代码风格不仅仅能促进合作，还能消除因为合并代码时格式化造成的无意义的冲突（上次数据库比赛的前车之鉴）  
引入 clang-format时，应该注意以下几点

1. 保证团队中每个人都使用 clang-fromat，否则就失去了格式化的意义
2. 减少对存量代码的修改

git 提供一个非常方便的功能，能够只格式化工作树中修改过的行

```shell
git clang-format --force --extensions cpp,h || true
```

其中`|| true`是因为如果 clang-format 需要格式化代码，会返回非零值，这个设计是为了给自动化系统提供更多的信息，使脚本更加简洁，但会使 `make`认为命令执行失败

##### git hook 保证每次提交可通过编译

我使用了非常简单粗暴的方法 —— 只要编译过了就是能通过编译，因此我添加了一个precommit hook，它会在每次提交前编译整个项目，如果编译失败就会拒绝提交  
实际使用效果有限，因为编译比较花时间，而且只保证当前工作树的代码时能通过编译的，但这不保证提交后的代码可以通过编译，例如局部提交的情况

#### 基础设施在初赛中帮了多少忙？

address sanitizer， undefined behavior sanitizer，libstdc++ debug mode 可以说是帮助最大，避免了因为内存问题或 UB 花大量时间调试，也避免了本地能通过而测评无法通过这种“赛博灵异现象”

不得不说 C++ 的未定义行为挺多的，以下是我在比赛中遇到的

- 使用未对齐的指针，[其行为未定义](https://stackoverflow.com/questions/51203570/is-it-well-defined-to-hold-a-misaligned-pointer-as-long-as-you-dont-ever-deref)  
  ![unaligned pointer](https://raw.githubusercontent.com/z2z63/image/main/20241110183949.png)
  解决办法：使用`memcpy`逐字节复制到对齐的地址上
- singular iterator 与其他 iterator 比较，[其行为未定义](https://stackoverflow.com/questions/49059404/is-comparing-against-singular-iterator-illegal)  
  ![singular iterator](https://raw.githubusercontent.com/z2z63/image/main/202411101846897.png)
  解决办法：singular iterator即不跟任何容器关联的迭代器，一般是因为容器改变后迭代器失效，注意更新迭代器即可
- 移位运算符右边是负数，[其行为未定义](https://stackoverflow.com/questions/8415895/is-left-and-right-shifting-negative-integers-defined-behavior)  
  ![delete pointer](https://raw.githubusercontent.com/z2z63/image/main/202411101848026.png)
- 使用`delete`运算符删除`new[]`运算符获取的指针，[其行为未定义](https://en.cppreference.com/w/cpp/memory/new/operator_delete)，反之亦然
- `memcpy`的指针参数是非法指针或空指针时，[其行为未定义](https://en.cppreference.com/w/cpp/string/byte/memcpy)，即使复制长度为零  
  ![memcpy null pointer](https://raw.githubusercontent.com/z2z63/image/main/202411101909458.png)
  解决办法：单独处理这种情况，此时不复制

很幸运 UB sanitizer 和 libstdc++ debug mode 都帮忙检查出来了  

其次 address sanitizer 也检查出不少 use-after-free, heap-buffer-overflow等问题，非常省心

#### 我对基础设施的看法

人使用计算机是为了让人干更少的活，机器干更多的活。我认为这就是基础设施的意义，人总是靠不住的，也常常懒得检查、或者无力检查一些潜在的问题，不过幸好我们有 sanitizer 这样强大的工具帮我们检查。  
此外，一些现代语言的特点就是基础设施完善而且往往是官方开发，和语言开发工具一并发行。可以认为现代语言的基础设施离开发者更距离更近，C++的基础设施不比现代语言少，甚至还有一些工具是其他语言没有的。但距离开发者更远，从我开始学习 C++ 到真正使用这些基础设施，已经有 2 年多了。

#### 我对 UB 的看法

既然有 undefined behavior，就一定有 well defined behavior，UB 存在的意义就是形成 C++ 这个语言的良定义子集。实际上，C++标准没有规定平台的大小端，没有规定一个字节有多少个比特，也没有规定指针类型有多少个字节，也没有规定`char`有没有符号。但这不妨碍我们使用 C++ 的良定义子集解决问题。还可以认为标准定义 UB 是将执行一些操作的自由从开发者手中剥夺并交给编译器厂商，编译器厂商就不必对良定义子集以外的任何行为做出保证，并且还能在这片标准为他们提供的“自由空间”内任意发挥  

例如 C++ 并没有规定函数调用约定，而是交给编译器厂商和硬件平台自己决定，这是因为不同传参方式在不同平台的性能不同，甚至某些传参方式在某些平台是不支持的，标准没必要对此做出任何限制。我在实习时见到的一个例子就是由于x64+windows+msvc和arm64+macos+clang两个平台的传参顺序不同，导致一个函数调用表达式在 macos 能按预期运行，在 windows 就报错

又例如由于编译器不必对 UB 做出任何保证，所以编译器优化只需保证在良定义子集内的行为产生的结果在优化前后保持相同即可，也就是说编译器可以根据优化的需要任意改变 UB 产生的结果。以我在初赛中遇到的情况为例，关闭优化时产生段错误，开启O2 优化时产生空指针的成员访问
![null reference](https://raw.githubusercontent.com/z2z63/image/main/202411102008791.png)
众所周知引用不能为空，但这里的确产生了一个空的引用并导致了错误  
原因是因为传入这个引用的地方是空指针解引用
![null pointer dereference](https://raw.githubusercontent.com/z2z63/image/main/202411102014727.png)
提到空指针解引用，我的第一想法就是段错误、非法内存访问等，但实际上，空指针解引用也[是未定义行为](https://stackoverflow.com/questions/2727834/c-standard-dereferencing-null-pointer-to-get-a-reference)

对于引用，标准规定引用必须初始化成一个合法对象或者函数的引用，因此在良定义的程序中空引用不可能存在。而保证「引用必须初始化成一个合法对象或者函数的引用」的工作就由编译器来完成，例如，当开发者尝试初始化一个空引用时，编译器应该拒绝编译。
因此在这个场景下，编译器应当保证不会出现空引用，又由于传入引用的地方是一个指针解引用，而空指针解引用是未定义行为，编译器不必保证空指针解引用时的行为，因此只需保证在不出现空指针解引用时不会出现空引用，因此编译器在开启 O2优化时就能将解引用优化掉并遵守空引用的承诺

更加明确的提出来这个观点，**编译器假定不会出现未定义行为，并以此为前提进行优化**，在这个场景可以解释为，由于有指针解引用，编译器就获得了一个信息：这个指针不能为空，因此优化掉解引用运算符也能保证不出现空引用

##### 其他语言的 UB ？

似乎只有 C++ 才有 UB，其他高级语言很少提及这个词。这是因为其他高级语言的运行时依赖于该语言的虚拟机，而实现这个虚拟机的目的之一就是消除未定义行为和平台差异，即其他高级语言的虚拟机是 C/C++ 写的，而实现虚拟机也就是尝试使用一个有 UB 的语言/平台去实现一个没有 UB 的理想乡。然而消除 UB 是有代价的，这也是 C++ 允许 UB 存在的一个原因

## 解题思路的简单介绍

首先来简单介绍一下 miniob 的设计。和其他数据库相似，miniob 中一条 sql 执行的全流程如下

```mermaid
graph LR
    用户输入的sql语句原始字符串 --语法解析--> 结构化的sql语法树 --语义分析--> 携带相关信息的sql语句 --生成逻辑查询计划--> 逻辑算子树 --优化--> 物理算子树 --执行计划--> 输出执行结果
```

### update

从原理上来说，数据库将磁盘物理快读入内存形成缓冲块，任何读取或修改行为都发生在缓冲块上，再注意以下索引更新即可

### null

翻开 DataBase System Concepts 的数据存储结构章节，里面给出了一个存储 null 值一个非常经典的实现，即在记录内存一个bitmap，其中每个比特标记字段是否为 null
![null bitmap](https://raw.githubusercontent.com/z2z63/image/main/202411102116441.png)

### text

翻开 DataBase System Concepts 的数据存储结构章节，里面提及了一个非常重要的原则：**一条记录不能横跨两页**，而 text 字段支持的大小可以超过一页，为了避免这个问题，可以参考程序设计中常见的方法，把变长转化为定长，也就是 text 的数据在外部单独存储，而记录内只存储指向这个记录的指针
![no record span two page](https://raw.githubusercontent.com/z2z63/image/main/202411102120748.png)

### vector

高维向量的大小可以超过页的大小，所以存储方式类似于 text，也是外部存储数据。向量的索引查询需要通过 10min 的 benchmark 测试，我主要想法在于提高向量查询的性能，以下内容展开说明如何提高性能

## 提高 sql 执行的性能

### 减少 IO 次数

首先，数据库最慢的部分是 IO，而基于磁盘的数据库无法避免 IO，所以提高性能的第一步就是如何减少 IO  
也许读者早就清楚应该使用缓冲，但我这里想清晰明确的指出为什么需要缓冲，还有为什么数据库都使用了相似的设计：分块缓冲

#### 为什么需要缓冲

翻开 Database System Concepts 的数据存储结构章节
![database storage](https://raw.githubusercontent.com/z2z63/image/main/202411102134930.png)
这里指出了冯诺依曼架构下数据库的最基本的矛盾：数据库需要持久化，因此将数据存储到非易失存储介质，但 CPU 只能读取内存中的数据，所以读取任何记录都必须先将记录加载到内存，而记录加载到内存后形成的结构，就可以称为缓冲  
我希望破除一个固有观点，就是认为只有申请了多少 KB 的内存，然后里面存放了记录，这样才能被称之为缓冲。实际上如果只需要一个读取一个 int 字段，在栈上开辟一个 int 变量（声明函数内的自动变量），然后将数据从磁盘读取到这个变量，也是缓冲。可以认为前者是缓冲的形式而后者是缓冲的本质

#### 为什么要分块缓冲

##### 存储设备按块读写

翻开 Database System Concepts 的物理存储系统章节，里面提及了闪存、磁盘、光盘、磁带等非易失存储介质，由于价格、容量、速度、通用性等考量，数据库常常使用闪存或磁盘作为存储介质

对于磁盘，磁盘表面划分为磁道，磁道进一步划分为扇区，而扇区是磁盘读写的最小单元
![magnetic disk](https://raw.githubusercontent.com/z2z63/image/main/202411111404356.png)

对于闪存，常用的 NAND 闪存的读写单元也是一个闪存物理快
![flash memory](https://raw.githubusercontent.com/z2z63/image/main/202411111403825.png)

从 IO 设备划分的角度，常见的非易失存储介质都是块设备，这意味着他们执行一次数据传输的单元是一块数据，而不是一个字符

如果需要读取的数据小于一个存储设备的物理快，实际上硬件仍然会执行整个物理快的读写，即使多读取的数据可能不需要；如果需要写入的数据小于一个物理快，需要先读取需要更新的物理块到内存，完成局部更新后，将更新后的物理快写回存储设备（这一过程也有可能由存储硬件完成）

##### 按块读写速度最快

由于存储设备按块读写，读写 1B 的数据和读写一个物理块的数据所花费的时间相差不大  
除了这个原因，读写前的准备工作和读写后收尾工作也需要花费时间，而且它们花费的时间随读写数据大小的曲线往往是阶梯形的。

- 磁盘从发起读写请求到数据开始传输，需要先找到磁道，然后马达控制磁盘旋转直到找到需要读写的扇区。对于磁盘这样传统的设备，机械部分的速度远远低于电子部分的速度，所以寻道和旋转花费的时间实际上比传输时间还要多
- 外设传输数据到内存需要使用总线，而计算机有许多外设，申请使用总线和释放总线的耗时基本是固定的，如果采取频繁申请总线、单次传输少量数据的策略，申请总线和释放总线的耗时占比将会提升

此外，存储设备的主控单元和操作系统也针对按块读写进行优化，例如存储设备可能会预先读取后续的更多数据，缓存在主控的缓存中。操作系统也会按块读写存储设备，即使用户程序没有发出按块读写的 IO 请求

#### 如何减少IO次数

一个非常经典的方法就是将磁盘物理块加载到内存，形成缓冲块，数据库系统使用有限的内存维护若干缓冲块，并在合适的时机释放缓冲块（可能包括写回脏块）
何时、如何释放缓冲块，一个简单的方法是 LRU，但我想提及一点，在数据库场合下，LRU 不一定是最适合的  

LRU 有效的前提是对 IO 请求的局部性假设，即 LRU 策略无法知道上层的 IO 请求有什么规律，而只能根据大部分场合做出这种通用的假设。但在数据库场合中，select 算子扫描表时，最新访问的缓冲块反而是未来最少使用的。数据库完全可以根据自己的场合定制一个特化的缓冲区管理策略，不过在 miniob 中不必追求这么高的性能也能通过初赛

### 减少系统调用次数

系统调用同样很慢，即使系统调用不涉及 IO。如果每次 SQL 语句执行都有许多次系统调用，性能会明显的下降。接下来我将说明为什么系统调用很慢

1. 系统调用涉及 CPU 现场保存和上下文切换，需要大量栈帧读写
2. 系统调用破坏了程序执行的局部性，使得 TLB、高速缓存等诸多基于局部性原理工作的组件性能降低
3. 系统调用结束后程序不一定立刻恢复执行，而是转为就绪态，而何时转为执行态取决于操作系统的进程调度。即系统调用浪费了当前执行轮次获取到的时间片

但减少系统调用是一个非常 low level 的操作，或者说与操作系统打交道本来就是比较 low level 的操作。如果使用高级语言，可以看到从高级语言运行时、libc 一路往下到操作系统，都在围绕着如何减少系统调用，也就是说，这个工作已经由底层开发者完成了大半，作为上层开发者不必太过操心这件事

例如申请一块内存，如果直接找操作系统要一块内存，通常使用 `brk` 系统调用扩张堆区，或者使用 `mmap` 系统调用得到一块文件映射的内存。而申请内存是一个非常高频的操作，从 libc 到高级语言运行时的内存管理系统都在尽力减少这个开销，比如维护内存池是为了在用户态满足更多内存请求，减少内存碎片是为了提高内存利用率，减少向操作系统要内存的需求。很幸运的是对于上层开发者，申请内存的成本已经非常低了，对于 glibc，可能几条或者十几条机器指令就能完成了，时间复杂度也降低到了`O(1)`（最好的情况）

对于上层开发者，不需要在这些 low level 的层级去追求性能（甚至可能导致负优化），牺牲一定的性能去换来可读性都是可以的

### 使用编译器优化/使用高性能库

这可能对于我们来说是最简单也是起效最快的方式，以这次比赛为例，我在 release build 中关闭了所有不需要的功能，例如 sanitizer、glibcxx debug mode、调试支持等，性能肉眼可见的提高了

sanitizer、glibcxx debug mode会在运行时检查一些条件，会影响性能很合理。调试功能也会间接的影响 release build 的性能，例如某些优化规则会使调试功能失效，所以可能会被禁用。此外调试会在生成的 elf 中嵌入调试信息，包括符号名、机器指令与行号的映射等，可能降低程序的空间局部性

此外，使用 C++非常大的一个优点就是性能完全不用担心，有非常多的高性能库可以轻松调用。向量索引题目中，编制索引是一个计算密集型任务，合理的使用多线程能大大加快速度，而我引入的高性能计算库也支持多线程，不过我已经轻松将ann benchmark的时间优化到了 5min (赛题要求 10min 以内)，就不必再抠这点性能了

## 感想

与其说是初赛的感想不如说是看完 C++ primer，再经过一个 C++ 项目实践后的感想

我个人非常不推荐大学把 C++ 作为大学生学习的第一门编程语言，也不推荐计算机以外的专业要求学生学习 C/C++。因为 C++涵盖的东西实在太多了，C++ primer 是一本 800-900 页讲解语法特性的书，但看完了这本书，也只是了解了 C++11 的特性的一部分，还有 C++11 - C++23 的新特性，当然也包括废弃的 C++11 特性。以我所了解的领域为例，现代 C++一直在提高其编译期计算的能力，在过去这是通过模板实现的，这也是大学的C++课程会教的内容（也许？），但在更新的标准里，随着`constexpr`，`consteval`等 const 系列关键字的引入，concept 的引入，编译期计算领域可以说已经翻天覆地了；C++ 的对象模型，内存模型，内存序也是一个非常大的话题，而且他们还和 C++ 的面向对象、对象生命期、指针等问题纠缠在一起；C++20 前已有许多协程的第三方实现，C++20又引入了 `co_wait` 和 `co_return` 关键字，提供了语言内置的协程解决方案；

就算掌握了新标准，理解了 C++ 的各种特性并能够充分运用，只会 C++ 仍然什么也做不到；往左是各大操作系统提供的能力和机制，往右是各种工程化方法，例如如何加快编译？如何组织构建系统？如何保证 ABI 兼容性？

更不用说现在多少学校教的还是 C++98，而现在生产环境有些已经上 C++20 了。一个很好笑的现状是课程结束后学生基本只学了 C++语法，但连 C++语法都没学完，实际上我直到现在也没学完。如果只是培养计算思维，大可选择 python，java 这样的语言，而不是选择一个极难入门的语言

总结一句话，一入 C++ 就是入了一个大坑，不花个五年十年没法出来的大坑。。。
