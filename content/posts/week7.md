---
title: "第七周：关于C/C++开发，我了解的一切 —— LSP、debugger与IDE"
author: z2z63
date: 2024-07-27T18:57:33+08:00
---

解决了工具链的问题，还只能在命令行完成项目的构建。要使用IDE进行C++开发，除了工具链的知识外，还需要了解其他知识才能配置出一个好用的C++ IDE
## 前置概念
- “古代”并没有IDE，或并没有合格的IDE，开发者使用的工具基本等于文本编辑器
- “近代”的IDE往往是编译器厂商做的，即IDE的vendor往往也是compiler的vendor，可以认为是一种捆绑销售策略

IDE的很多知识都可以通过配置neovim学习。neovim是vim的分支，相比vim，他有以下优点
- 支持异步
  neovim建立的一个原因就是vim的异步支持太烂，neovim获得成功后，倒逼vim也添加了异步功能
- 内置LSP支持
  提供了一套API供LSP插件调用
- 使用lua作为配置语言
  性能远超vim script
- etc

## LSP
language server protocol即语言服务器协议，它是由microsoft提出的一个JSON RPC（基于JSON的远程过程调用）协议  
microsoft开发的VSCode是一个轻量的IDE，大部分功能都由插件提供。进行某个语言的开发就需要使用到诸如语法高亮，跳转到定义，查找引用等功能，这些功能由对应的语言插件提供，而这些功能就被称为语言服务

由于插件和VSCode的editor是分开的，需要一种机制通信。LSP提出的目的就是作为语言服务器和文本编辑器通信的规范

LSP的提出让IDE支持多种语言变得非常简单。过去一个IDE要支持多个语言就需要分别开发多个语言的语言服务功能，现在只需要提供LSP功能，然后分别启动对应语言的语言服务器即可。它促进了IDE与语言服务的解耦，也促进了分工（IDE厂商和语言服务器厂商各司其职）

LSP是一个JSON RPC，语言服务器处于远程，而文本编辑器处于本地。但所谓远程仅仅指逻辑意义上的远程。例如大部分情况下，用户在本地进行开发，语言服务器也运行在用户的计算机中，此时可以使用例如unix socket等高效的信道，避免网络层、链路层、物理层造成的开销。远程开发时，语言服务器就处于远程，通过HTTP协议与文本编辑器通信
> **Note:** 远程有物理和逻辑两种含义，逻辑的远程即相对进程而言，如果使用套接字等方式与本地另一个进程通信，此时可以被称为是逻辑的远程。物理上的远程可以是不处于同一个计算机，或不处于同一个局域网

此外，JSON RPC可以通过HTTP，即作为HTTP协议的上层协议。使用HTTP协议开发非常容易，因为它相当于web后端开发，此外JS操作JSON也非常简单，大大简化了vscode语言插件的开发

## 语言服务器
语言服务器为了提供语言服务，需要一些信息。以python为例，它需要python的安装目录，以读取第三方库的信息，此外，它还需要了解项目的结构，这样才能提供跨文件跳转，相对导入等功能

LSP规定了若干语言服务器可以提供的功能
- 自动补全
- 跳转到定义
- 跳转到声明
- 鼠标悬停显示文档（hover动作显示宏展开，函数签名，类型定义，文档等）
- 查找引用
- 符号重命名
- 代码折叠范围
- Code Action
- etc

一个语言服务器不必实现全部功能，LSP允许语言服务器告知文本编辑器它所支持的功能，即语言服务器的能力

## clangd
C++开发最好用的语言服务器就是clangd了，clangd是clang相关工程的产物，clang相关工程有很多强大的配套工具，我目前只使用过clangd和clang-format，还剩很多工具等待挖掘

参见[clangd](https://clangd.llvm.org/installation)的文档，为了提供语言服务，它需要知道每个文件的编译命令，编译命令实际上提供了以下clangd需要的信息
- 头文件搜索路径
- 用户定义的宏
- 编译的二进制产物（用于定位外部定义的变量）

clangd需要的编译命令可以通过`compile_commands.json`文件提供。为了使用clangd，只需要想办法根据C++项目配置生成这个文件即可
- Makefile工程  
  使用[Bear](https://github.com/rizsotto/Bear?tab=readme-ov-file)生成`compile_commands.json`
- CMake工程  
  CMake可以通过打开CMAKE_EXPORT_COMPILE_COMMANDS选项来导出`compile_commands.json`
  ```shell
  cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=1
  ```
  注意CMake只有在生成Makefile工程或Ninja工程时，才能导出`compile_commands.json`
  > This option is implemented only by Makefile Generators and Ninja Generators. It is ignored on other generators.
- Visual Studio工程  
  安装Visual Studio的插件[clang power tools](https://clangpowertools.com/)，Visual Studio打开工程后，右键解决方案，在上下文菜单中点击“Export Compilation Database”即可，参考[generate-json-compilation-database](https://clangpowertools.com/blog/generate-json-compilation-database.html)

clangd是一个非常强大的语言服务器，体验不输各种商业化的语言服务器（其他很多语言的语言服务器基本都是商业的更好用），而且clangd作为clang相关工程的产物，是自由开源软件，可以说是clang给全世界的馈赠

## debugger
不同的工具链都有debuger，例如GNU工具链有gdb，LLVM有LLDB  
要能够调试，需要在编译时指示编译器在生成二进制时携带调试信息  

调试是一个非常大的话题，以下是我了解的部分
- 可调试的可执行或库携带调试信息，这些信息包括机器指令与源码文件+行号的映射关系
- debugger是另外一个进程，它需要attach上被调试进程
- 调试需要硬件支持，涉及中断
- linux提供ptrace系统调用，供debugger使用

具备以上知识只能在命令行调用debugger，在绝大部分情况下我们都是使用IDE的debug功能。就像LSP，debuger也有协议与文本编辑器通信，这样IDE就不需要自己实现每个语言的调试功能，这个协议为[DAP](https://microsoft.github.io/debug-adapter-protocol/)，即Debug Adapter Protocol

有了DAP，debugger就能和IDE分离，debugger可以运行在远程，而IDE运行在本地，这样的调试被成为远程调试

调试时常用功能如下
- 变量查看
- 函数调用堆栈查看
- 执行命令  
  以gdb为例，常用`p`命令（打印表达式），`x`命令（查看任意地址的内容），`disass`命令（查看反汇编结果），`i r`命令（查看寄存器）
## 例子一：使用VSCode阅读并调试CPython源码
拉取源码，切换到稳定分支（因为主分支可能有不稳定的特性）
```shell
git clone git@github.com:python/cpython.git
cd cpython && git checkout 3.12
```
阅读[python dev guide](https://devguide.python.org/getting-started/setup-building/#install-dependencies)，安装依赖（可选）

```shell
sudo apt-get install build-essential gdb lcov pkg-config \
      libbz2-dev libffi-dev libgdbm-dev libgdbm-compat-dev liblzma-dev \
      libncurses5-dev libreadline6-dev libsqlite3-dev libssl-dev \
      lzma lzma-dev tk-dev uuid-dev zlib1g-dev libmpdec-dev
```
安装扩展[C/C++](https://marketplace.visualstudio.com/items?itemName=ms-vscode.cpptools)，[Makefile Tools](https://marketplace.visualstudio.com/items?itemName=ms-vscode.makefile-tools)

### 配置扩展设置
阅读C/C++扩展的文档，想要让VSCode能够提供C的语言服务，需要配置C/C++扩展的intellisence，配置规则如下
1. C/C++扩展使用`.vscode/c_cpp_properties.json`记录Intellisence的配置，可以配置头文件搜索路径，用户定义的宏，C标准等等，详细配置选项见[customize-default-settings-cpp](https://code.visualstudio.com/docs/cpp/customize-default-settings-cpp)
2. C/C++扩展在无主动配置时可以自动生成一个默认的配置，其头文件搜索路径为项目的所有目录（即项目中任何头文件都能被搜索到） + 系统路径，用户定义的宏为空
3. C/C++扩展的intellisence配置也可以由[CMake Tools](https://marketplace.visualstudio.com/items?itemName=ms-vscode.cmake-tools)扩展、[Makefile Tools](https://marketplace.visualstudio.com/items?itemName=ms-vscode.makefile-tools)扩展提供
4. `compile_commands.json`也能提供足够信息让intellisenc工作


CPython作为一个传统开源项目，使用auto tools + Makefile，对于这样的工程，可以使用Makefile Tools扩展，它识别项目结构，并将intellisence配置提供给C/C++，这样就能在VSCode使用C的语言服务

需要配置以下设置
1. Makefile路径
2. pre config脚本（即`configure`）

Makefile Tools扩展会先运行`configure`，然后dry-run生成的Makefile，最终生成intellisence配置

---
我在使用以上方案时，发现一些问题
1. Makefile Tools扩展的pre config无法指定脚本运行路径，无法支持树外构建（可以自己写一个脚本，`cd build && ../configure`）
2. Makefile dry-run太慢，而且日志不直接输出在VSCode窗口内，需要手动查看日志文件
3. 每次用VSCode打开项目，都会重新pre config 然后dry-run，浪费时间

为了避免以上问题，我使用Bear生成`compile_commands.json`，然后将这个文件提供给C/C++扩展
```shell
mkdir build && cd build
../configure --with-pydebug --prefix=/home/z2z63/src/cpython/build/usr
bear -- make
```
设置C/C++扩展的选项
![](https://raw.githubusercontent.com/z2z63/image/main/202407272225946.png)

设置完成后，C/C++扩展会完成项目的扫描，可以通过右下角的状态栏图标确认intellisence的状态
![](https://code.visualstudio.com/assets/docs/cpp/intellisense/language-status-bar.png)

至此已经完成了intellisence的设置，可以正常使用语言服务的功能阅读CPython源码了

### 构建CPython
在终端输入命令
```shell
cd build
make
```
即可完成构建

每次都输入命令比较麻烦，VSCode的语言插件可以帮助创建默认的构建任务，但不一定符合需求，由于以上都是自定义的，所以也需要自定义一个构建的任务，任务在`.vsocde/tasks.json`中定义
点击 Terminal - Configure Tasks
![](https://raw.githubusercontent.com/z2z63/image/main/202407272340275.png)
选择Create task.json file from template
![](https://raw.githubusercontent.com/z2z63/image/main/202407272343894.png)
模板选择others
![](https://raw.githubusercontent.com/z2z63/image/main/202407272346566.png)

这样就创建了一个默认的`tasks.json`
```json5
{
    // See https://go.microsoft.com/fwlink/?LinkId=733558
    // for the documentation about the tasks.json format
    "version": "2.0.0",
    "tasks": [
        {
            "label": "echo",
            "type": "shell",
            "command": "echo Hello"
        }
    ]
}
```
稍加改动即可
```json
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "build cpython",
            "type": "shell",
            "command": "make",
            "problemMatcher": [
                "$gcc"
            ],
            "options": {
                "cwd": "${workspaceFolder}/build"
            },
            "group": "build"
        }
    ]
}
```

然后将此任务设置为默认的构建任务
![](https://raw.githubusercontent.com/z2z63/image/main/202407272338004.png)
![](https://raw.githubusercontent.com/z2z63/image/main/202407272351027.jpg)
通过Ctrl+Shift+B快捷键触发构建时，会执行这个任务
> **Note:** 关于task的文档参见 [Integrate with External Tools via Tasks](https://code.visualstudio.com/docs/editor/tasks#vscode)
### 调试CPython
CPython是一个解释器，它的主要工作是执行python脚本  
创建一个`test/fib.py`目录，内容如下
```python
def fib(n):
    if n < 2:
        return 0
    else:
        return fib(n-1) + fib(n-2)

print(fib(10))
```

然后使用gdb进行调试
```shell
gdb build/python test/fib.py
```
即可进入gdb调试

---

C/C++扩展提供了C的调试功能，但需要配置。配置一般来说是通过CMake Tools等扩展提供的，由于以上的配置是自己设置的，C/C++的默认配置也不能满足需求，需要手动配置

创建一个空的`launch.json`文件
![](https://raw.githubusercontent.com/z2z63/image/main/202407280005517.png)
原内容如下
```json5
{
    // Use IntelliSense to learn about possible attributes.
    // Hover to view descriptions of existing attributes.
    // For more information, visit: https://go.microsoft.com/fwlink/?linkid=830387
    "version": "0.2.0",
    "configurations": []
}
```
使用C/C++提供的模板，快速填充
![](https://raw.githubusercontent.com/z2z63/image/main/202407280006075.png)

裁剪部分内容，最终如下
```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "(gdb) Launch",
            "type": "cppdbg",
            "request": "launch",
            "program": "${workspaceFolder}/build/python",
            "args": [
                "test/fib.py"
            ],
            "cwd": "${workspaceFolder}",
            "externalConsole": false,
            "MIMode": "gdb",
        }
    ]
}
```
在`Programs/python.c`的`main`函数打上断点，按下F5，即可进入调试
![](https://raw.githubusercontent.com/z2z63/image/main/202407280012869.png)

如果想要输入gdb命令，需要在前面加上`-exec`

如果想要直接运行而不调试，可以按下Shift + F9，或点击 Run - Run Without Debugging
> **Note:** 关于launch的文档见 [Debugging](https://code.visualstudio.com/docs/editor/debugging#_launch-configurations)

## 例子二：使用VSCode调试glibc
下载源码包，并解压
```
wget https://ftp.gnu.org/gnu/glibc/glibc-2.40.tar.gz
tar xvf glibc-2.40.tar.gz
```
补充一个常识，根目录下文件名全大写的文件往往是非常重要的文件，现在常用`README.md`作为项目的说明，在markdown还没有流行的“近代”或“古代”，往往使用`README`，此外，C项目往往还会提供`INSTALL`文件，用来说明如何安装软件

glibc根目录下的`INSTLL`提及
> The GNU C Library cannot be compiled in the source directory.  You must build it in a separate build directory

即glibc必须树外构建，而且这种树外构建更复杂，要求源码树和构建目录在两个不同的目录下

调整项目结构
```shell
mkdir src
mv ../glibc src
mkdir build
```
形成的结构如下
```
glibc
  ├── build
  └── src  （原glibc根目录）
```
进入build目录完成configure
```shell
cd build
../src/configure --prefix=/home/z2z63/src/glibc/build/usr 
```
之后配置C/C++扩展，获得语言服务的步骤同例子一

### 调试glibc
与python不同，glibc的二进制产物是名为libc的动态库，动态库是不能被直接调试的，需要提供一个可执行，它链接到动态库，然后可执行调用动态库中的函数，就能进入到动态库中了

此外，glibc构建后的二进制产物是不能被链接的，因为文件分布的位置不正确，需要安装
```shell
make install
```
然后在项目根目录创建`main.c`，让它作为入口
```c
#include <malloc.h>

int main(int argc, char** argv){
    int* a = (int*)malloc(sizeof(int));
    *a = 10;
    free(a);
    return 0;
}
```
然后，只需要让`main.c`在链接时，链接到刚刚安装的glibc，而不是系统路径的glibc
```shell
gcc main.c -g -Xlinker -rpath=/home/z2z63/src/glibc/build/usr/ -o build/main
```
`-Xlinker`表示后面的参数传递给链接器，`-rpath=/home/z2z63/src/glibc/build/usr/`指将`/home/z2z63/src/glibc/build/usr/`作为rpath嵌入到生成的elf中

rpath是linux动态链接器提供的机制，如果一个可执行动态链接到一些动态库，通常指这个可执行在执行前需要链接到这些库。
> **Note:** 动态库还可以在进程启动后，通过`dlopen`函数打开，这样的链接被称为运行时动态链接

内核完成elf解析并将相应的段装载至内存后，设置返回的PC为动态链接器的入口地址，退出内核态进入用户态后，动态链接器开始工作，它将需要的动态库加载进内存，并修正GOT（全局偏移表），这样就能够调用其他ELF中的函数，或引用其他ELF中的对象。动态链接器完成bootstrap后，`__start`开始执行，完成诸如全局变量初始化等工作，最后，`main`开始执行，至此才进入了用户的入口函数

动态链接器位于`/usr/lib/ld-linux-x86-64.so.2`，它在加载动态库时，由于默认的`/lib`和`/usr/lib`的查找优先级最低，可以被诸如`rpath`、`LD_LIBRARY_PATH`等设置覆盖

使用`ldd`命令验证已经正确链接到了指定的glibc
```shell
$ ldd build/main
linux-vdso.so.1 (0x00007509b4e22000)
libc.so.6 => /home/z2z63/src/glibc/build/usr/lib/libc.so.6 (0x00007509b4c37000)
/lib64/ld-linux-x86-64.so.2 => /usr/lib64/ld-linux-x86-64.so.2 (0x00007509b4e24000)
```

添加`.vscode/launch.json`文件
```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "(gdb) Launch",
            "type": "cppdbg",
            "request": "launch",
            "program": "${workspaceFolder}/build/main",
            "args": [],
            "cwd": "${workspaceFolder}",
            "externalConsole": false,
            "MIMode": "gdb",
        }
    ]
}
```
然后在`main.c`的第四行，即
```c
    int* a = (int*)malloc(sizeof(int));
```
打上断点，按下F5，再点击Step into或按下F7，成功进入了glibc的malloc实现
![](https://raw.githubusercontent.com/z2z63/image/main/202407280213244.png)