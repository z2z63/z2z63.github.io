---
title: "第六周：关于C/C++开发，我了解的一切 —— 编译器、构建工具"
author: z2z63
date: 2024-07-20T20:59:10+08:00
---

最近两个月也是基本一直在写C++了，尤其是实习以来，从linux的C++开发切换到windows + visual c++，这其中遇到的问题非常多，也让我不断的思考究竟怎样才是最佳实践。  

此外，实习期间摸鱼时，也阅读了不少python源码，为了理解python的内存管理系统，还翻了四五遍glibc的wiki，粗略看了`malloc`源码，也算是学到了不少知识，为了分享这些知识，我决定先将我从各种项目中学习到的C/C++开发应该了解的知识系统总结一下

## 前置概念
- C/C++是系统开发语言，绝大部分操作系统的系统调用都是以C/C++的API形式提供的
- C++不应该被视为一种语言，而是一个松散的语言联邦。可以认为GNU的C++是gnu-cpp语言，而Microsoft的C++是visual-cpp语言。而这些xxx-cpp语言恰好满足了一个名为C++的语言联邦的约定，于是都称为C++
- 接上，以上观点的原因是，不同平台的C++开发区别实在是太大了。Windows的C++开发者和Linux的C++开发者表面上都在开发C++，但是他们的考虑到底层的方式，使用的工具，使用工具的方式都是截然不同的。例如同一个`printf`，linux的C++开发者会想到文件描述符，会想到tty等等，而Windows的C++开发者会想到Win32 API，会想到回车换行符，会想到控制台主机等等
- C++开发者在跨平台时，需要能够跨CPU架构、操作系统、libc++实现、编译器
- undefined behavior（UB）,即未定义行为，指C++标准明确规定此行为的结果不确定，UB不是未文档的行为
- implementation-defined behavior（IB），即实现定义行为，指C++标准规定此类行为的结果应该由C++实现（通常是编译器vendor）规定
- UB，IB的行为往往是根据当前架构，当前实现方式中选取的性能最好的一种行为，即C++跨平台时需要考虑避免UB和IB

## 工具链
为了将源码转变为最终的二进制，需要编译器、汇编器、链接器、调试器共同工作  
此外，往往还需要配套的构建工具例如makefile、cmake等，他们共同组成了C++工具链

工具链往往跟平台有关，linux往往使用GCC工具链中的`gcc`作为编译器，`as`作为汇编器，`ld`作为链接器，`gdb`作为调试器

此外，一套工具链中的工具是相互协作，共同生成二进制。例如gcc会在编译时，将一些信息嵌入ELF某些段中，指示`ld`如何工作，因此gcc编译的中间产物不能被其他链接器使用，不同平台的汇编代码也不同，例如GCC的汇编器是`GAS`(GNU Assember)，其语法与visual c++的汇编器`MASM`不同。因此，生成二进制产物必须由一套工具链的工具相互协作，不能混用工具链

对于传统开源项目，常常使用GNU的autotools，makeilfe作为构建工具。对于现代C++项目，通常使用CMake作为构建工具，CMake在linux平台往往使用makefile完成最终的构建；而windows可以选择microsoft提供的visual c++工具链，并使用Visual Studio进行开发，Visual Studio往往会调用`msbuild`或`nmake`完成构建

## 编译参数
编译参数即传给编译器的参数。广义的编译参数包括任何字面上传递的参数，狭义的编译参数指一些控制编译器行为的标志，而不包括诸如头文件搜索路径，源文件路径等等

以gcc为例，编译参数一般有一下部分
- 头文件搜索路径
- 源文件路径
- 输出产物路径
- 优化参数
  所谓优化，即将一段代码转为效率更高，但是结果等价的代码  
  优化参数通常为`-f`开头，用于控制是否开启某项编译优化手段  
  此外，还提供了`-O0`，`-O1`，`-O2`，`-O3`方便使用，会分别批量打开对应的优化开关
  `-O0`表示关闭所有开关，而`-O3`表示开启所有开关  
  常使用O2而不使用O3，原因如下
  - 在gcc历史上有段时期O3并不稳定
  - O3的优化结果的等价性更依赖于无UB，大部分开发者无法避免写出无UB的程序，O3优化容易使得这些程序出现错误
  - O2已经提供了足够使用的优化
  - O3优化在进行循环展开时，可能导致循环体超过cache line的大小，反而降低速度
  - O3优化可能利用当前平台特性，可能导致二进制产物无法在其他平台运行
- 功能参数
- 警告参数
  通常`-W`开头，用于单独控制是否对某个行为发出警告  
  如果抑制警告，通常是`-Wno`开头  
  `-Wall`表示开启所有警告，常用于避免潜在的问题
  `-Werror`表示将警告转为错误，在比较严格的场合下用于强制开发者消除所有警告
- 语言特定参数
- 诊断参数
- 静态分析参数
- 代码生成参数
  用于控制输出的二进制产物，例如`-fPIC`控制生成地址无关代码，常用于生成共享对象
- 链接器参数
  gcc会在内部调用`ld`，链接器参数会直接传递给`ld`
- 汇编器参数
  同理，gcc会在内部调用`as`，链接器参数会直接传递给`as`
- 宏定义参数
  部分宏定义需要在编译时传入，以控制程序的行为

## 如何编译
大部分场合下，编译时需要指定的编译参数如下
- 头文件搜索路径
- 库搜索路径
- 优化参数
- 调试参数
- 宏定义参数

对于一个单文件，可以在shell中输入编译命令，快速完成编译  
对于C/C++工程，手动输入编译命令非常繁琐，在“古代”的方法是使用shell脚本记录编译的命令，问题如下
- 大型项目构建时间非常长，仅仅修改一个文件也需要重新完成整个工程的编译
- 如果需要传入参数以控制编译行为，脚本就会变得越来越复杂

## Makefile
Makefile就是为了解决以上问题而出现的，它可以认为是shell脚本的一种封装  
Makefile有以下内容：
- 规则  
  规则告诉Makefile如何生成target  
  规则分为显式规则和隐式规则，显式规则组成如下
  - target  
    通常是输出产物的路径名，即一个规则会产生文件，使用伪target可以定义不产生文件的规则
  - prerequisites  
    执行规则前应当满足的先决条件
  - recipe  
    规则如何执行，会交给shell解释执行
- 变量定义
- 其他指令
  例如`include`指令可以引入其他Makefile文件

makefile的隐式规则可以节省非常多的代码，例如
- `aaa.o`如果没有对应的规则可以生成，Makefile会自动应用隐式规则，将`aaa.c`编译得到`aaa.o`
- `CC`为默认的C编译器，`CXX`为默认的C++编译器
- `CFLAGS`为默认编译时，传递给`CC`的编译参数，同理`CXXFLAGS`是默认传递给`CXX`的编译参数

## autotools
C的一个特点是利用宏定义和条件编译，可以控制参与编译的代码，做到适应各种平台，例如
- 跨平台软件实现子进程时，利用条件编译可以在不同的平台调用相应的系统调用
  ```c
  #ifdef LINUX
  // fork ...
  #endif

  #ifdef WIN32
  // CreateProcess...
  #endif
  ```
  注意一般只有标准库没有提供的功能才有必要使用这种方法，例如读写文件就可以直接使用标准库
- 实现一个高性能的HTTP服务器时往往使用`epoll`，但内核版本比较旧的linux系统没有`epoll`，可以使用其下位替代`select`
  ```c
  #ifdef HAVE_EPOLL
  // epoll...
  #else
  // select
  #endif
  ```
- C标准没有规定如何控制符号导出，为了导出动态库，可以在windows平台使用visual c++的扩展`__declspec(dllexport)`，在linux平台可以使用GNU扩展`__attribute__((visibility("default")))`  
  ```c
  #ifdef LINUX
  #define MYEXPORT __attribute__((visibility("default")))
  #endif

  #ifdef WIN32
  #define MYEXPORT __declspec(dllexport)
  #endif
  ```

所以一个C/C++项目在build之前往往还有configure的步骤，configure识别当前平台、工具链，并允许设置一些功能开关，供用户裁剪功能，configure的产物是一堆用户定义的宏和变量，用于传入构建系统。autotools完成的就是configrue的工作  

autotools非常复杂，基于非常原始的文本替换，而且只能在linux平台使用，并不推荐学习autotools，只需要掌握如何使用autotools的`configure`即可

autotools给编译者（一般区别于开发者）提供的接口为`configure`，它是一个在项目根目录的具有执行权限的脚本，一般用法如下
```shell
CFLAGS=-O2 -g ../configure --prefix=/home/arch/xxx
```
`configure`提供的开关由开发者定义，需要使用`../configure --help`查看支持的所有开关  
`CFLAGS`通常作为环境变量传入`configure`，随后`configure`将参数嵌入生成的`Makefile`中  
`--prefix`一般用于指定安装目录，默认安装目录`/usr/local`需要root权限，也可以手动指定一个无特权目录

autotools虽然本身的概念非常晦涩，从设计上来说也不好用，但许多大型开源项目都使用了autotools，原因如下
- 大部分使用autotools的项目都是历史悠久的老牌开源项目，当时只有autotools可选
- autotools是GNU三板斧之一，GNU认为自由软件构建所需的工具链也得是自由的
  
## 树外构建
大部分构建工具都会缓存构建中间产物以加快构建速度，套用本博客的文章[《第二周：败者树、范式与反范式》](../week2#唯一事实原则)的观点，构建中间产物是cache，它违反了唯一事实原则。其后果是在某些情况下，中间产物可能不是最新的，这时需要强制清空所有构建产物，执行一次干净的构建。因此，构建工具往往提供`clean`的功能

如果将源文件在文件系统中的分布看作源码树，那么直接在项目根目录进行构建，构建的中间产物就会和源码树混杂在一起，这样的构建被称为树内构建，在`clean`时，需要深入源码树每个层级，精准删除构建中间产物而不删除源文件。Makefile的`clean`目标一般是使用`find`命令实现的

构建的中间产物就会和源码树混杂在一起后，会产生如下问题
- 使得`clean`操作变得复杂（甚至部分项目无法保证彻底`clean`，例如glibc）
- 开发时大量无关文件和源文件混杂，影响效率

鉴于树内构建的问题，通常使用树外构建，即创建一个目录（通常为`build`），进入此目录进行构建。构建后，输出的构建中间产物和最终产物都在`build`目录内，clean时不必担心误删源文件

autotools + Makefile的树外构建流程如下
1. 新建一个目录用于构建并进入该目录
   ```shell
   mkdir build
   cd build
   ```
2. 完成configure
   ```shell
   ../configure
   ```
3. 构建
   ```shell
   make
   ```
## CMake
前文提及的autotools + Makefile在许多老牌开源项目中被使用，但它也有很多问题
1. 只能在linux平台使用
2. 命令式语法，经常需要重复处理一些琐碎细节
3. 支持多种工具链的心智负担大

CMake是相比Makefile更优的做法，它使用`CMakeLists.txt`文件管理工程，CMake完成的是configure的过程，它本身并不负责构建，而只负责生成构建配置。 

CMake核心概念是target，target可以通过`add_executable`，`add_library`，`add_custom_target`产生
- `add_executable`会使输出的二进制中增加对应的可执行
- `add_library`可以输出动态库，静态库，也可以是接口库，接口库是CMake的概念，相比其他库，接口库没有构建的过程
- `add_custom_target`用于执行任意命令

target可以携带属性，可以通过`set_target_properties`设置属性，通过`get_target_property`访问属性，例子：  
- 可执行可以携带`WIN32_EXECUTABLE `属性，这样的可执行在windows平台运行时，是窗口程序，不需要控制台主机或windows terminal作为宿主，可以显示Win32的窗口，其入口函数为`WinMain`
- 库可以携带属性，控制其输出产物，例如`SHARED`输出共享库，`STATIC`输出静态库，`MODULE`输出不参与链接其他target，可供`dlopen`在运行时动态链接的库

### CMake的跨平台特性
CMake在不同的平台有不同的行为
- CMake会自动调整输出产物的格式，在windows平台输出exe、dll、lib，在linux平台输出可执行（无扩展名）、so（共享库）、a（静态库）  
- CMake在不同平台生成对应的工程，例如在linux平台默认生成Makefile工程，在windows平台默认生成Visual Studio工程，在MacOS平台默认生成XCode工程
- `find_pacakge`时，在不同平台采用不同的搜索策略，符合这些平台组织软件包的方式

### 第三方库
CMake大大简化了C++项目使用第三方库的过程，经过实践，我认为`find_package`和`ExternalProject_Add`是非常方便的功能

#### `find_package`
在linux平台，许多C++第三方库可以通过包管理器安装，只要第三方库支持CMake，就会将`Find<PackageName>.cmake`或`<PackageName>Config.cmake`或相似名称的CMake文件安装到`/usr/lib/cmake/<package-name>/`下
> **Note:** 在Linux平台，安装指的是带权限的复制。man描述`install`命令为“install - copy files and set attributes”

`find_package`在linux平台会搜索此目录，并执行其中的CMake文件，执行的结果通常包括设置了头文件搜索路径变量，添加了若干库；随后只需使用`target_include_directories`添加头文件搜索路径，使用`target_link_libraries`链接到此库即可

### `ExternalProject`
`ExternalProject`是一个非常强大的功能，可以说是C++第三方库的最终银弹。  
`find_package`在Linux平台的一个缺点是，它默认使用系统的软件包，而linux系统的软件包版本一般无法选择，由发行版软件源控制。许多项目使用的第三方库的版本比系统软件包的版本旧。linux软件包大部分也使用语义化版本（参考[《第五周：CI/CD、git workflow与软件发行》](../week5/)）。如果主版本号不一致，一般是无法使用的。

此外，使用`find_package`的前提是第三方库提供了诸如`Find<PackageName>.cmake`这样的文件，然而还有些时候第三方库没有提供

以上问题都能通过`ExternalProject`解决，它提供了丰富的选项，支持使用HTTP下载，使用git拉取源码包，支持自定义configure、build、install  

无论第三方库是如何组织软件包的，想要能够被别人调用，最终都需要提供两个信息：头文件搜索路径、库搜索路径。软件包在安装时，也通常是安装头文件和库，以及一些文档。通常使用`ExternalProject`拉取指定版本的第三方库源码，完成configure、构建、安装，然后手动配置其头文件搜索路径和库搜索路径

以[AnyQ](https://github.com/baidu/AnyQ)为例，以下是AnyQ引入指定版本的libcurl的配置
```cmake
include(ExternalProject)

SET(CURL_PROJECT  "extern_curl")
SET(CURL_URL      "https://curl.haxx.se/download/curl-7.60.0.tar.gz")
SET(CURL_SOURCES_DIR ${THIRD_PARTY_PATH}/curl)
SET(CURL_DOWNLOAD_DIR  "${CURL_SOURCES_DIR}/src/")

ExternalProject_Add(
    ${CURL_PROJECT}
    ${EXTERNAL_PROJECT_LOG_ARGS}
    DOWNLOAD_DIR          ${CURL_DOWNLOAD_DIR}
    DOWNLOAD_COMMAND      wget --no-check-certificate ${CURL_URL} -c && tar -zxvf curl-7.60.0.tar.gz
    DOWNLOAD_NO_PROGRESS  1
    PREFIX                ${CURL_SOURCES_DIR}
    CONFIGURE_COMMAND     cd ${CURL_DOWNLOAD_DIR}/curl-7.60.0 && ./configure --prefix=${THIRD_PARTY_PATH} --without-ssl 
    BUILD_COMMAND         cd ${CURL_DOWNLOAD_DIR}/curl-7.60.0 && make
    INSTALL_COMMAND       cd ${CURL_DOWNLOAD_DIR}/curl-7.60.0 && make install
    UPDATE_COMMAND        ""
)
```

由于`ExternalProject`可以完全控制configure，可以在configure时，传入编译参数、功能开关等，实现第三方库携带调试符号，根据项目需求裁剪第三方库功能等需求。例如AnyQ就去掉了libcurl自带的ssl功能，在不需要HTTPS的场合下可以大大减小二进制大小

### `FetchContent`
`FetchContent`也能用来将其他C++项目集成进来，但这个项目必须也使用CMake  

以上我并没有使用“第三方库”这样的字眼，因为`FetchContent`会将其他CMake工程的所有target全部添加到本CMake工程内，容易会造成名称冲突  

相反，`ExternalProject`将第三方库转变成了一个target，并且能够指定target的名称，就不会出现名称冲突的情况
> The ExternalProject_Add() function creates a custom target to drive download, update/patch, configure, build, install and test steps of an external project:

### CMake缺点
写了这么多CMake的优点，终于轮到吐槽CMake了。没错，CMake本身的问题实在是太多了，但苦于CMake已经成了C++项目的事实标准，很多时候并没有更好的选择


所有指令都是无返回值的，任何输出都是输出到一个变量上，非常不符合大部分编程语言的习惯  
不仅仅无返回值，很多指令的行为依赖于各种变量的定义，也就是输入不明显，行为依赖于执行到此指令时各种变量的值

甚至if else还有这种逆天语法
```cmake
if(<condition>)
  <commands>
elseif(<condition>) # optional block, can be repeated
  <commands>
else()              # optional block
  <commands>
endif()
```

字符串操作可读性也非常不好
```cmake
string(REPLACE <match-string> <replace-string> <out-var> <input>...)
string(REGEX MATCH <match-regex> <out-var> <input>...)
```
配合无返回值的设计，非常考验眼力


CMakeLists.txt一旦写长了，非常难以阅读。而了解一个项目最快的方式就是去阅读CMake配置，了解其构建流程

还有generator expression这种逆天设计
```cmake
# WRONG: New lines and spaces all treated as argument separators, so the
# generator expression is split and not recognized correctly.
target_compile_definitions(tgt PRIVATE
  $<$<AND:
      $<CXX_COMPILER_ID:GNU>,
      $<VERSION_GREATER_EQUAL:$<CXX_COMPILER_VERSION>,5>
    >:HAVE_5_OR_LATER>
)
```

此外，许多第三方库提供的`Find<PackageName>.cmake`等文件，并没有文档说明它添加了哪些库，设置了哪些变量。官网文档大部分不会提及如何使用`find_package`引入他们的库，在`Find<PackageName>.cmake`文件开头写段注释已经算是"well documentated"的做法（相信大部分人都不会去看这个文件里面的注释吧）

CMake的文档也是又臭又长，许多指令的行为很复杂，因为传参很多，还能依赖于各种变量（通常是CMAKE开头）的定义，读文档非常考验耐心。CMake Tutorial写的也是又臭又长的风格，当然这也是C++项目的通病了

## 分层配置
如果在源码树中非常深的位置想要git不追踪某个文件，可以在项目的根目录写下这个文件相对根目录的路径
```.gitignore
aaa/bbb/ccc/ddd/eee/fff/ggg/a.out
```
然而这种做法并不优雅，git提供了更优的方法  
在`aaa/bbb/ccc/ddd/eee/fff/ggg/`目录下创建一个`.gitignore`文件，其中写下
```.gitignore
a.out
```
优点是忽略这个文件的配置和这个文件距离很近，上下文关联强

同理，Makefile和CMake也支持这样的分层配置
Makefile可以通过`Include`指令添加子目录的Makefile，CMake可以通过`include_subdirectory`引入CMake子工程

以[Paddle](https://github.com/PaddlePaddle/Paddle)为例，源码树的每一层都有`CMakeLists.txt`
```
➜  paddle git:(develop) fd CMakeLists.txt  | tree --fromfile 
.
├── cinn
│   ├── adt
│   │   ├── CMakeLists.txt
│   │   └── print_utils
│   │       └── CMakeLists.txt
│   ├── ast_gen_ius
│   │   └── CMakeLists.txt
│   ├── auto_schedule
│   │   ├── analysis
│   │   │   └── CMakeLists.txt
│   │   ├── CMakeLists.txt
│   │   └── search_space
│   │       ├── auto_gen_rule
│   │       │   └── CMakeLists.txt
│   │       └── CMakeLists.txt
│   ├── backends
│   │   ├── CMakeLists.txt
│   │   ├── llvm
│   │   │   └── CMakeLists.txt
│   │   └── nvrtc
│   │       └── CMakeLists.txt
│   ├── CMakeLists.txt
│   ├── common
│   │   └── CMakeLists.txt
│   ├── hlir
│   │   ├── CMakeLists.txt
│   │   ├── dialect
│   │   │   ├── CMakeLists.txt
│   │   │   ├── operator
│   │   │   │   ├── CMakeLists.txt
│   │   │   │   ├── ir
│   │   │   │   │   └── CMakeLists.txt
│   │   │   │   └── transforms
│   │   │   │       └── CMakeLists.txt
...
```
这样的配置可以将编译逻辑下放到源码树的末梢，并减少上层CMake工程变更，上层CMake工程关注整体架构，下层CMake工程关注编译细节，还能减少git协作时上层CMake配置变更冲突的情况