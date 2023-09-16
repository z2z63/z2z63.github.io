---
title: 右值引用
date: 2023-05-29 22:20:02
tags: [mordencpp]
---
C++11后引入了右值引用等特性，用来支持移动语义和完美转发，在了解右值引用前，需要了解一些前置的概念
1. 左值(lvalue)
    左值字面意义是在等号左边的值，左值是寻址的，具名的，有标识符的  
    有一个特点是，所有声明的变量都是左值
2. 右值(rvalue)
    右值字面意义是在等号右边的值，右值不可寻址，不具名
    具体而言：
    - 一个整数字面量是右值，因为它不对应一个内存存储位置，在汇编中，它存在于指令中的立即数字段
    - 一个临时对象是右值，临时对象是为了写连续的表达式而被编译器支持的，当有例如`func(obj())`时，首先建立一个obj对象，这个对象没有名字，它实际上有一个对于的内存存储位置，但在这行代码执行完后就会被销毁，所以它叫做临时对象

cpp对临时对象有一个限制，因为临时对象是马上就会被销毁的，所以对临时对象的修会被抛弃
- `fn(int a)` 可以用`fn(a)`和`fn(1)`调用，但是会造成复制
- `fn(int &a)`不可以用`fn(1)`调用，因为cpp认为`int&`是允许修改的，而如果修改一个字面量，因为找不到它的内存存储位置，所以无法修改
- `fn(const int& a)`可以用`fn(1)`调用，因为`fn`通过`const`关键字保证自己不会修改临时对象，所以允许传入字面量

# 左值引用
左值常常被称为是变量的别名，为什么呢？  
根据左值的概念，可以确定
```cpp
int a = 1;
int& b = a;
b = 2;
std::cout << a << std::endl;
a = 3;
std::cout << b << std::endl;
```
从抽象的角度来看，a，b具有响应式的关系，修改一个，另一个也会改变  
但实际上，a，b是对同一个地址的引用，换句话来说，a，b 'underlying' 的对象只有一个，这里的对象并不是面向对象的对象  
反汇编的结果也能证实这一观点
```text
        int a = 5;
    1170:       c7 45 e4 05 00 00 00    movl   $0x5,-0x1c(%rbp)
        int &b = a;
    1177:       48 8d 45 e4             lea    -0x1c(%rbp),%rax
    117b:       48 89 45 e8             mov    %rax,-0x18(%rbp)
```
可见，`b`其实跟`*(&a)`是同义的，而我们知道，`*`和`&`效果刚好是相反的，也就说，`b`和`a`是同一个东西，这代表”b是a的别名“，也可以得出`&b`和`&a`是同一个东西，这代表”b和a 'underlying'的对象是同一个“  
当左值引用作为函数参数传递时，在汇编层面上，实际上传递的是地址  
左值引用的初衷也是简化指针的使用，左值引用具有指针的优点：能在函数内修改外部的值，又规避了指针的缺点：错误的指针运算会导致野指针，也可以认为它是受约束的指针

# 右值引用
当自己动手实现一个栈类时，会遇到这个问题
```cpp
Object obj;
vector.push(obj);
```
当push的定义为`push(Obeject obj)`时，会造成复制行为  
当push的定义为`push(Object& obj)`时，虽然可以避免复制，但是又会产生一个新的问题
```cpp
void function(Vector& vector){
    Object obj;
    vector.push(obj);
    return；
}
```
这时，由于`obj`对象是分配在栈上的，当函数退出时，栈帧被清空，`obj`对象也就不存在了，然而`vector`还保留着对`obj`对象的引用  
这种情况其实经常发生，它表现了资源移动时的矛盾：又要避免复制，又要避免引用的对象提前销毁  
一个简单的方法是使用`new`，在堆上构造obj，这样obj的生命期就足够长，能够避免obj提前被销毁  
然而`new`后还需要`delete`，而`new`和`delete`不在同一个上下文中，非常容易忘记`delete`  
这时我们就会想，有没有一个方法能够适当延长`obj`对象的生命期，又能让他自动销毁呢？  
答案就是右值引用了，push定义为`push(Object&& obj)`时，编译器会延长obj对象的生命期，在这个例子中，会采用返回值优化（Return Value Optimization, RVO）或命名的返回值优化（Named Return Value Optimization, NRVO），通过把`obj`这个对象构造在调用者的栈上，避免退出函数时`obj`对象被销毁，从而延长了`obj`对象的生命期  
下面这个例子进一步说明了右值引用延长了临时对象的生命期
```cpp
#include <iostream>

class Object {
public:
    Object() {
        std::cout << "Object constructed" << std::endl;
    }

    ~Object() {
        std::cout << "Object destroyed" << std::endl;
    }
};

void processObject(Object&& obj) {
    std::cout << "Processing object" << std::endl;
    // 对临时对象进行处理，这里只是简单地输出信息}

int main() {
    Object&& ref = Object();  // 将临时对象绑定到右值引用    
    std::cout << "Before function call" << std::endl;
    processObject(std::move(ref));  // 通过右值引用传递临时对象    
    std::cout << "After function call" << std::endl;

    return 0;
}
```
编译后输出为
```text
Object constructed
Before function call
Processing object
After function call
Object destroyed
```
右值引用会延长临时对象的生命期直到右值引用绑定的对象的生命期结束  

回到之前的例子，如果一个函数又要接收左值作为参数，又要接受右值作为参数，可以用`fn(int&& a)`，同时能够在函数里修改a，但是对a作出的修改最终都会被抛弃  
为什么对a作出的修改都会被抛弃呢？  
因为右值是不具名的，即使它被改变了，也没有任何方法能够访问到它
```cpp
#include <iostream>

using namespace std;

void fn(int && a){
    while(a>0){
            cout << a  << endl;
            a--;
    }
}

int main(){
    fn(5);
    return 0;
}
```
输出为
```text
5
4
3
2
1
```
这个例子可能非常反直觉，当执行`a--`时，肯定有一个内存存储位置被赋值了，但是这个位置在哪里？
反汇编后结果如下
```text
int main(){
                    ...
        fn(5);
    11c4:       c7 45 f4 05 00 00 00    movl   $0x5,-0xc(%rbp)
    11cb:       48 8d 45 f4             lea    -0xc(%rbp),%rax
    11cf:       48 89 c7                mov    %rax,%rdi
    11d2:       e8 82 ff ff ff          call   1159 <_Z2fnOi>
```
编译器居然为我们分配了一个变量！  
汇编代码等效为
```cpp
int x = 5;
fn(x);
```

如果把`fn`修改为`void fn(int a)`，相应的反汇编结果为
```text
        fn(5);
    118e:       bf 05 00 00 00          mov    $0x5,%edi
    1193:       e8 b1 ff ff ff          call   1149 <_Z2fni>
```
