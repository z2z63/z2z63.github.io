---
title: 函数传参的入栈顺序造成的一些细微影响
date: 2023-04-06 00:09:32
tags: [Coding, 汇编]
---
最近遇到了一个函数传参造成的问题，于是来稍微研究一下这个东西  
什么是函数传参顺序？
一个简单例子
```c
bar(foo(1), foo(2));
```
为了准备`bar`函数需要的参数，需要先执行`foo`函数，但是有两个`foo`函数，应该先执行哪个？  
在一般情况下，先执行哪一个并没有什么影响，然而在一些特殊情况下，我们可能非常在意`foo`函数执行的顺序
比如说
1. foo函数内部做出了访问文件系统，发起网络请求等对外界造成影响的操作
2. foo函数内部有状态变量（类似状态机），每次执行`foo`函数时，会改变内部状态，`foo`函数的输出也取决于内部状态
    ，一个最简单的例子就是`foo`函数表示弹栈操作
## 为了研究函数传参的顺序到底是从左到右还是从右到左，我做了以下实验
首先考虑到函数传参的顺序实际上是调用者与被调用者约定的一种数据交换格式，函数的参数可以借由寄存器传递，
也可以把参数埋在调用者的栈内，也可以复制到被调用者的栈内，所以不必分析哪一个`foo`函数先执行，只需要
分析机器指令准备参数的顺序
### C
首先新建文件`test.c`，内容如下
```c
#include <stdio.h>

void fn(int x, int y) { 
    printf("%d %d", x, y);
}

int main() {
    fn(1, 2);
    return 0;
}
```
用gcc编译，然后查看反汇编代码
```shell
gcc -g ./test.c
objdump -S ./a.out
```
`main`函数的反汇编代码如下
```text
0000000000001166 <main>:
    1166:       55                      push   %rbp
    1167:       48 89 e5                mov    %rsp,%rbp
    116a:       be 02 00 00 00          mov    $0x2,%esi
    116f:       bf 01 00 00 00          mov    $0x1,%edi
    1174:       e8 c0 ff ff ff          call   1139 <fn>
    1179:       b8 00 00 00 00          mov    $0x0,%eax
    117e:       5d                      pop    %rbp
    117f:       c3                      ret
```
可见自定义的`fn`函数的传参顺序是从右到左
还可以看出，2被放入了esi，1被放入了edi
`fn`函数的反汇编代码如下
```text
0000000000001139 <fn>:
    1139:       55                      push   %rbp
    113a:       48 89 e5                mov    %rsp,%rbp
    113d:       48 83 ec 10             sub    $0x10,%rsp
    1141:       89 7d fc                mov    %edi,-0x4(%rbp)
    1144:       89 75 f8                mov    %esi,-0x8(%rbp)
    1147:       8b 55 f8                mov    -0x8(%rbp),%edx
    114a:       8b 45 fc                mov    -0x4(%rbp),%eax
    114d:       89 c6                   mov    %eax,%esi
    114f:       48 8d 05 ae 0e 00 00    lea    0xeae(%rip),%rax        # 2004 <_IO_stdin_used+0x4>
    1156:       48 89 c7                mov    %rax,%rdi
    1159:       b8 00 00 00 00          mov    $0x0,%eax
    115e:       e8 cd fe ff ff          call   1030 <printf@plt>
    1163:       90                      nop
    1164:       c9                      leave
    1165:       c3                      ret
```
`fn`函数把edi和esi的值复制到栈帧中，然后再复制到寄存器中，可以确定先准备了2，再准备了1
猜测`0xeae(%rip)`存放着字符串`"%d %d"`的值，进入gdb查看这个地址的值
```text
(gdb) si
0x0000555555555156      3       void fn(int x, int y) { printf("%d %d", x, y); }
(gdb) p (char*)($rip+0xeae)
$22 = 0x555555556004 "%d %d"
```
所以可以确定，`printf`函数的字符串是最后一个被传入的，所以这个`printf`函数也是从右到左
### Python
新建一个`test.py`，内容如下
```python
import dis

def fn(x, y):
    print(x, y)

def main():
    fn(1, "2")

dis.dis(main)
```
在终端执行脚本
```shell
python ./test.py
```
结果如下
```text
  9           0 LOAD_GLOBAL              0 (fn)
              2 LOAD_CONST               1 (1)
              4 LOAD_CONST               2 ('2')
              6 CALL_FUNCTION            2
              8 POP_TOP
             10 LOAD_CONST               0 (None)
             12 RETURN_VALUE
```
可以看出自定义的`fn`函数是从左到右传参的
但是，python的函数传参实际上相当复杂，涉及到位置参数，默认参数，可变参数，关键字参数等等，具体传参顺序
还得看python解释器的实现
### 占坑
## 总结
汇编的函数调用约定，占坑