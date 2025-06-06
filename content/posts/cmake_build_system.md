---
title: "cmake杂谈"
author: z2z63
date: 2025-06-04T20:17:20+08:00
---
众所周知 C++项目通常在开发时关闭优化以方便调试，在发布时开启优化以获得更高的性能，通常这是通过开发时给编译器传递`-g`选项，而在发布时给编译器传递`-O2`选项实现的。在某次使用 cmake 时我了解到了`CMAKE_BUILT_TYPE`的概念，这个变量有`Debug`，`Release`，`RelWithDebInfo`, `MinSizeRel`四种典型的值，但当我翻开 cmake 文档时发现 cmake 并没有说明`CMAKE_BUILT_TYPE`会对优化参数有什么影响，而经过我的实验，当`CMAKE_BUILT_TYPE`设为`Debug`时确实会传递`-g`。于是我研究了一番`CMAKE_BUILT_TYPE`如何影响到编译器参数的

阅读文档和源码是很无聊的过程，不感兴趣的读者可以直接跳到 [浅谈 cmake](#浅谈-cmake)

## Read The Fucking Doc

首先翻开`CMAKE_BUILD_TYPE`的文档，cmake 对这个变量说明非常少，仅仅说明了在使用单生成器（makeifle，ninja）时`CMAKE_BUILD_TYPE`可以指定 build configuration，而 build configuration 表明了此次构建的规格

然后翻开`CMAKE_<LANG>_FLAGS`的文档，其中`<LANG>`在编译 cpp 时其值为`CXX`，cmake 在文档中提及这些参数会被传递到所有的编译器调用，即在任何的`CMAKE_BUILD_TYPE`下`CMAKE_CXX_FLAGS`都会作为参数被传递到编译器调用，显然这不是 cmake 的最佳实践。要证明也很简单，在`CMakeLists.txt`中加上一行`message(STATUS CMAKE_CXX_FLAGS=${CMAKE_CXX_FLAGS})`，能看到输出为`-- CMAKE_CXX_FLAGS=`，即`CMAKE_CXX_FLAGS`这个变量为空，因为这个值是留给用户设置的。

`CMAKE_<LANG>_FLAGS`文档还提及`CMAKE_<LANG>_FLAGS_<CONFIG>`会在对应的`<CONFIG>`生效时被传递到所有的编译器调用。那么`<CONFIG>`是什么呢？翻开`CMAKE_<LANG>_FLAGS_<CONFIG>`文档，其中第一句
> Language-wide flags for language \<LANG\> used when building for the \<CONFIG\> configuration

可以勉强推断出`<CONFIG>`即前文提到的 build configuration，也就是`CMAKE_BUILT_TYPE`的值，那么对于 `CMAKE_BUILT_TYPE`值为 Debug 的调试模式，可以使用`CMAKE_CXX_FLAGS_DEBUG`来单独控制此模式的编译参数（顺便提一下`CMAKE_BUILT_TYPE`有时大小写敏感有时不敏感，例如`CMAKE_CXX_FLAGS_DEBUG`中 DEBUG 是全大写）

在 AI 的帮助下我找到了`CMAKE_<LANG>_FLAGS_<CONFIG>_INIT`的文档，cmake 描述其为
> Value used to initialize the CMAKE_\<LANG\>\_FLAGS\_\<CONFIG\> cache entry the first time a build tree is configured for language \<LANG\>.

即`CMAKE_CXX_FLAGS_DEBUG_INIT`可以当做`CMAKE_CXX_FLAGS_DEBUG`的初始值，而经过实验，默认情况下`CMAKE_BUILT_TYPE=Debug`，而`CMAKE_CXX_FLAGS_DEBUG`=`CMAKE_CXX_FLAGS_DEBUG_INIT`=`-g`。因此可以得出一个结论：`CMAKE_CXX_FLAGS_DEBUG_INIT`使调试模式下`-g`被传递给编译器。

进一步思考，`CMAKE_CXX_FLAGS_DEBUG_INIT`的值是从哪里来的呢？文档中提及
> This variable is meant to be set by a toolchain file. CMake may prepend or append content to the value based on the environment and target platform.

第一句提及的所谓 toolchain file 是 cmake 在交叉编译时声明工具链的文件，但是对于非交叉编译，即本地编译本地运行的情况，就没有 toolchain file。第二句提示这个值可能是 cmake 自行设置的

由于 cmake 文档再也找不出有用的内容，我结束了文档阅读，转而阅读 cmake 的源码

## Read The Fucking Source

最终对我帮助非常大的是 cmake 源码内对于 enable_launguage 的 [注释](https://github.com/Kitware/CMake/blob/c95a8348ceb5f03db0623afcee5520abe2b4832e/Source/cmGlobalGenerator.cxx#L483-L529)

所谓 enable_language 是 cmake 的 project 命令背后完成的一项工作，任何语言都需要被 enable 才能使用，而 C 和 C++是 cmake 默认 enable 的，因此我从来没有使用过 enable_languge。顺着注释我发现了 cmake 内部很多有意思的奇技淫巧。

enable_languge 的流程包括检测操作系统、检测 CPU 架构、找到语言对应的编译器、检测编译器的 id、检测编译器支持的功能。

enable_languge 的流程一小部分是在 cmake 源码中使用 C++ 完成的，剩下的大部分都是使用 cmake 语言完成的，这些逻辑可以在`<prefix>/share/cmake/Modules/*.cmake`中找到，其中`<prefix>`是 cmake 的安装目录，`<prefix>/share/cmake/Modules`与 cmake 项目根目录下的`Moduels`目录内容相同，安装时`Moduels`下的所有`*.cmake`脚本原样不动地复制到`<prefix>/share/cmake/Modules`

### 检测操作系统和架构

所谓交叉编译，往往是对于嵌入式操作系统或者嵌入式设备没有足够能力运行完整的开发工具，因此只能依靠其他设备/操作系统编译，常见的交叉编译有 Android 编译 C++库，ios 编译，STM32 编译等等。在交叉编译时，运行编译器的操作系统被称为 Host，而编译产物运行的平台被称为 Target，所谓检测操作系统包括检测 Host OS 和检测 Target OS，在不涉及交叉编译时可以简化为检测 Host OS

对于 Host OS 的检测分为对 Windows、类 Unix（包括一众 linux 发行版和 MacOS） 的检测。 cmake 是能知道自己的目标平台，也就是 cmake 知道当前 Host OS 的大致分类，随后在类 Unix 平台使用 `/usr/bin/uname`可以获取当前平台的系统名称。例如我在 mac 上开发时，`uname -s`返回`Darwin`。

随后 cmake 开始对当前 OS 的架构检测。主流 OS 往往都适配了多种架构，例如 Windows 有 x64,x86,arm，linux 也有 x64,x86,arm，还有 riscv 等一堆千奇百怪的架构，MacOS 也有 Intel 芯和 Apple Silicon 的区别。理论上 cmake 是知道自己目标平台的架构，但由于架构之间指令转译工具的存在，Apple Silicon 的 MacOS 也能照样运行 x64 的 cmake，因此 cmake 选择使用`uname -m`的结果作为 Host 架构。

### 检测编译器和编译器 id

检测编译器即 cmake 找到合适的编译器，检测编译器 id 即 cmake 识别出编译器是 gcc 还是 clang 还是 msvc...  

在类 Unix 平台，优先使用环境变量中指定的编译器，对于 C++，编译器通过环境变量`CXX`指定。其次 cmake 尝试搜索`CC` `c++` `g++` `aCC` `cl` `bcc` `xlC`。搜索使用 cmake 的`find_program`，`find_program`的搜索逻辑比较复杂，但总的来说，在`PATH`内的目录可以被搜索到

找到编译器后，cmake 需要确认编译器 id，因为不同的编译器能够接受的参数不同，传参风格也有所不同。但检测编译器 id 并没有一个优雅的方法，cmake 采取了非常 hack 的方式实现

假设 cmake 的`CMAKE_BINARY_DIRECTORY`，也就是构建目录是`build`，可以找到`build/CMakeFiles/<CMake_version>/CompilerIdCXX/CMakeCXXCompilerId.cpp`，这是 cmake 在 configure 阶段生成的文件，内部通过 feature macro 检测编译器 id，并将结果保持在一个全局的字符串数组中。例如在 macos 平台，会进入这段逻辑

```cpp
#elif defined(__clang__) && defined(__apple_build_version__)
# define COMPILER_ID "AppleClang"
// ...
char const* info_compiler = "INFO" ":" "compiler[" COMPILER_ID "]";
```

随后 CMake 调用刚刚找到的编译器编译这个文件，然后搜索目标文件中的`info_compiler`符号，正则解析出其中的`COMPILER_ID`。AppleClang 表示这个编译器是 clang 编译器的 apple 变种，clang 在不同平台都有各自的变种。

### `CMAKE_CXX_FLAGS_DEBUG_INIT` 赋值

通常我们接触到的编译器例如 gcc,g++,clang,clang++,cl 都被称为前端或者 driver，因为它们自身只是一个很小的二进制，只负责控制预处理器、汇编器、链接器等诸多工具相互协作。
在`CMakeDetermineCompilerId.cmake`中，GNU 和 AppleClang 的`CMAKE_CXX_COMPILER_FRONTEND_VARIANT` 都被设为`GNU`，这表明 AppleClang 和 g++具有相似的传参风格，随后 cmake 加载[`Compiler/GNU.cmake`](https://github.com/Kitware/CMake/blob/0bc051c1804816ade50b7c6d506da46f143e04a0/Modules/Compiler/GNU.cmake#L58-L62)，在其中就能找到对`CMAKE_CXX_FLAGS_<CONFIG>_INIT`的初始化

```cmake
string(APPEND CMAKE_${lang}_FLAGS_INIT " ")
string(APPEND CMAKE_${lang}_FLAGS_DEBUG_INIT " -g")
string(APPEND CMAKE_${lang}_FLAGS_MINSIZEREL_INIT " -Os")
string(APPEND CMAKE_${lang}_FLAGS_RELEASE_INIT " -O3")
string(APPEND CMAKE_${lang}_FLAGS_RELWITHDEBINFO_INIT " -O2 -g")
```

最后可以得出一个结论，cmake 内置了对许多常见 OS 和 compiler 的适配逻辑，包括在这些平台上自动检测 OS，编译器，编译器 id，编译器支持的特性。然而 cmake 对此特性并没有详细的说明

## 浅谈 cmake

### 重新审视跨平台

一年前的我沉迷于 flutter 的跨平台特性：一份代码部署到 windows、linux、macos、android、ios，如果我写了一个很厉害的 app，可以轻松在各个平台使用。  
在客户端开发岗位实习两个月后我逐渐改变了这个观点，各平台之间的差距实在太大了。稍微深究一下各个平台的差异就能感受到跨平台是一个无底洞。例如打开文件有 C 标准规定的`fopen`，但在 windows 平台，libc 的`fopen`可能将路径字符串按照 ANSI 编码解释。同理 windows 将很多 API 都分为了 ANSI 版本和 Unicode 版本，甚至 WIN32 窗口程序的入口函数不是 `main` 而是 `WinMain`。

从近年来 meta、google、腾讯、字节都推出自己的跨平台框架可以看出，跨平台尽管不能真正的跨平台，但仍然是必须的。以我在实习中参与的某个软件开发为例，它跨 windows、linux、macos、android、ios 平台，其中以上平台主要划分为桌面端和移动端，桌面端和移动端尽量复用 UI，但仍然有些 UI 是无法复用的，但业务代码是 100% 复用、100% 跨平台的。我想这就是跨平台的意义：避免为每个平台单独维护一份冗余的代码，提高软件迭代速度。

一个 v2ex 用户的 [评论](https://v2ex.com/t/1071599#:~:text=%E8%B7%A8%E5%B9%B3%E5%8F%B0%E5%B0%B1%E6%98%AF%E5%9C%A8%E5%90%83%E5%B1%8E%EF%BC%8C%E6%A1%86%E6%9E%B6%E5%A4%9A%E5%90%83%E7%82%B9%E4%BD%A0%E5%B0%B1%E5%B0%91%E5%90%83%E7%82%B9%EF%BC%8C%E6%A1%86%E6%9E%B6%E5%B0%91%E5%90%83%E7%82%B9%E4%BD%A0%E5%B0%B1%E5%A4%9A%E5%90%83%E7%82%B9%EF%BC%8C%E6%A1%86%E6%9E%B6%E8%AF%B4%E6%9C%89%E4%BA%9B%E5%B1%8E%E5%AE%9E%E5%9C%A8%E5%92%BD%E4%B8%8D%E4%B8%8B%EF%BC%8C%E4%BD%A0%E5%B0%B1%E8%A6%81%E5%90%AB%E7%9D%80%E6%B3%AA%E5%92%BD%E4%B8%8B%E5%8E%BB%EF%BC%8C%E8%A6%81%E6%98%AF%E4%BD%A0%E4%B9%9F%E5%92%BD%E4%B8%8D%E4%B8%8B%E5%8E%BB%EF%BC%8C%E5%B0%B1%E8%A6%81%E6%B7%B7%E5%9C%A8%E9%A5%AD%E9%87%8C%E7%AB%AF%E7%BB%99%E7%94%A8%E6%88%B7%E4%BA%86) 可以准确的概括我对跨平台的看法：“跨平台就是在吃屎，框架多吃点你就少吃点，框架少吃点你就多吃点，框架说有些屎实在咽不下，你就要含着泪咽下去，要是你也咽不下去，就要混在饭里端给用户了”。所谓跨平台框架、跨平台软件，其内部往往在处理很多无聊又琐碎的东西。cmake 也不例外，翻开 cmake 源码就能看到内部对许多如同上古邪神的 OS、编译器的支持，例如 HP-UX、AIX、Solaris、Borland、HP aCC 、Intel C++、IBM XL C/C++等等。

### cmake 成功的原因

cmake 愿意适配各种奇奇怪怪的东西，不仅包括上文提到的很多现在连听都没听说过的 OS 和编译器，还包括 CUDA、STM32、Android NDK、OpenBSD、PowerPC、Windows Phone、Windows CE、apple 的 watchos、tvos 等等。翻开 cmake generator 文档还能看到 cmake 仍然保留了对 codeblock、eclipse、kate、sublime 的支持（在 3.27 版本标记为废弃）。其中我想聊聊 kate，kate 是 KDE 的文本编辑器，KDE 是 linux 三大桌面环境之一。我使用 linux 作为主力 OS 长达两年，kate 是我非常喜欢的一个文本编辑器，他开箱即用又轻便，而且是一个伪装成文本编辑器的 IDE。长期使用过 windows、linux、macos 后我仍然认为 KDE 中许多软件是我认为非常好用的，比如文件管理器 [dolphin][dolphin]，文本编辑器 [kate][kate]、终端 [konsole] 等等。

回到话题，虽然大家都说自己是写 C++的，但每个人的方向完全不一样，C++社区就是这样的碎片化，而 cmake 愿意对任何 C++的隐蔽角落去做适配，只要选择 cmake，虽然语法很难看，文档又臭又长，但用它组织构建系统总归是不会遇到问题的。

除了以上原因，C++社区对要求 C++的构建工具对平台依赖较小，因此 C++的构建工具大概率不会选择主流的高级语言，否则在从自举过程中就可能遇到一个困境：编译 C++项目需要先编译 C++的构建工具，而 C++的构建工具依赖高级语言，高级语言又依赖 C/C++。

还有一个比较主观的原因，C++社区希望的构建工具应该是足够灵活的，许多大型 C++项目都会在构建过程中使用脚本语言，过去的 linux 传统开源项目常用 perl，现在的项目也许常用 python，我实习时参与的项目则使用 javascript，mentor 介绍时说技术总监对 JS 怀着这样的热情：“一切能用 JS 重写的必将使用 JS 重写”，于是他在项目建立初期便引入了 JS。

为什么要足够灵活呢？我想原因是因为 C++构建过程本身就是比较复杂的，像是自动调用 wget、git 等工具下载源码，根据文件名条件地编译源文件（例如、*_desktop.cpp 只在桌面端构建时参加编译，\*_test.cpp 只在测试时加入编译），还有 flex、bison、qt 都大量的使用了代码生成。那么更进一步，为什么 C++的构建过程这么复杂呢？我对此的理解是，C++反射至今没有标准实现，因此 C++倾向在编译时完成更多的工作。同时因为 C++社区碎片化，导致 C++在工程实践缺少一个公认的约定俗成，在实践中大家都按照自己对最佳实践的理解去组织构建系统。而 cmake 就能在构建阶段做很多事情，比如`execute_process`，`find_programe`，`configure_file`，`ExternalProject`等等。而 cmake 提供的这些命令也相当于总结 C++工程构建中的常见任务。

一句话总结，虽然 cmake 自身存在很多问题，但总体而言 cmake 基本符合了 C++社区对 C++构建工具的期望。

### unix 的古老传承

前文提到 cmake 在类 unix 平台使用`uname -s`检测 OS，使用`uname -m`检测架构，使用`cc`作为 C 编译器。这是因为`uname`是 UNIX 上用于在终端打印机器信息和系统信息的命令，而`cc`是 unix 的 C Compiler 的名称。在“上古时代”出现了许多 unix 分支，当时的软件交付方式是工程师亲自在目标机器上编译软件，所以类 unix 系统只需做到源码级的兼容而不需要做到二进制级别的兼容。linux 为了能够使用 unix 的软件，选择兼容 unix，其中就包括了模仿 unix 的`uname`和`cc`。兼容 unix 后，为 unix 开发的软件不需要修改 Makefile 就能在 linux 编译。随后`uname`和`cc`也进入了 POSIX 标准，而 macos 是 POSIX 兼容机，自然也需要有`uname`和`cc`

这样的历史一方面让我感受到 unix 的古老传承，不愧是任何 OS 教科书都必讲的 OS，另一方面，也让我感受到 C++是一门非常古老的语言，古老到 C++诞生早于 linux，早于 git。我一直在学习现代的 C++，差点忘了 C++原来是如此古老的语言

## append

{{<youtube 40dJS_LC6S8>}}

[kate]:https://kate-editor.org/
[dolphin]:https://apps.kde.org/dolphin/
[konsole]:https://konsole.kde.org/
