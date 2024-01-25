---
title: 逐渐向右移动的类型——静态类型成为新语言的趋势
author: z2z63
date: 2024-01-25T19:33:40+08:00
---
许多新语言(2000之后发明的语言)大多有一个偏好：类型后置
<!--more-->
![](https://pic1.zhimg.com/v2-a476982529c75f87f01c8f41423aa69e_r.jpg?source=1def8aca)
- rust:
    ```rust
    let x : i32 = 1;
    ```
- go:
    ```go
    var a []string
    ```
- kotlin:
    ```kotlin
    var language : String = "French"
    ```
- TypeScript:
    ```TS
    let x : number = 1;
    ```
在我看来，有以下几个原因
# 动态类型不可取
说到动态类型不得不提JS和python，从它们的发展过程来看动态类型存在很多问题
## JS
ECMAscript规定它是动态类型，弱类型的语言，使得JS非常灵活，但也带来很多问题。不提ES2015之前的JS，JS写下一个变量不知道它的类型，它的类型可以在运行时随意改变，甚至ECMAscript规定JS可以自动转型，例如
```JS
1 + "1"
```
JS发现类型不匹配后，会自动将`1`转型以执行`+`运算符
```html
<div id="myoutput1"></div>
<div id="myoutput2"></div>
<script>(()=>{
    document.querySelector("#myoutput1").innerText = 1 + "1"
    document.querySelector("#myoutput2").innerText = 1 - "1"
})();
</script>
```
在线HTML执行后输出为
```text
11
0
```
---  
这样灵活的JS为前端工程化带来了很大的麻烦，于是microsoft提出了Typescript，实现了静态类型约束。不过TS也带来了一些新的问题，比如经常被调侃为做‘类型体操’

## python
python和JS的定位都是脚本语言，自然也是动态类型的语言，不过相比JS，python是强类型的，不会自动转型。不过pyton同样因为过于灵活，开发大型项目时力不从心。大型项目更需要的是严谨刻板，茴香豆的茴即使有四种写法，也会规定只能使用一种。  

从python3.5开始，逐渐引入了type hint。有了type hint，不仅language server能从其中受益，开发者也能使用像pyright, mypy这类静态类检查器来检查代码中潜在的错误，不过python引入type hint是渐进的，目前（python3.12）type hint虽然支持了许多功能，但仍然有很多第三方库没有提供type hint或者没有提供完整的type hint，此外python的静态类型检查器也并不完善，有些时候还是只增加许多琐碎的代码来通过静态类型检查，或者在某处禁用静态类型检查  

# 静态类型的痛
从JS和python的发展历程可以看出动态类型的问题很严重，虽然天生泛型，但是一门面向工业面向生产的语言，必须选择静态类型，不过静态类型也有一些问题
1. 语言更繁琐
2. 需要实现泛型

从JS和python所处的年代，那时选择动态类型是很合理的，被C++折磨太多，突然抛弃类型就会非常轻松。  

对于静态类型带来的疼痛，新语言往往使用了对应的’止痛药‘：省略类型  

所谓类型推导，也就是编译器提供了强大的类型推导能力，能够在很多时候省略掉类型声明，减少静态类型带来的疼痛，例如rust在大部分时候都不需要声明类型，编译器会自动根据右值推导，例如根据数值范围推导是`i32`还是`i64`，根据函数返回类型推导，
甚至还能根据return语句自动推导函数返回类型。这反映出编译技术的不断进步，给开发者带来了不少便利，开发者再也不需要像以前使用C/C++时到处写类型了

于是类型在大部分时候可以省略，一个变量的声明中类型成了可选，如果不写类型，怎么知道这个语句到底是声明还是赋值呢？  
有两种方案
- 类型前置，使用`auto`，`var`等在省略类型时占位
    C++11后可以使用`auto`让编译器推导类型，java也可以使用`var`省略类型
    另外，同样是新语言的dart采用了`var`
- 类型后置，使用`let`，`var`等标志变量声明
    TS，rust，kotlin都采用这种方式省略类型

那么为什么选择类型后置呢，大概是为了整齐，众所周知C++有这种风格
```C++
int
a = 1;

std::string 
s = "xxxx";
```
这是为了避免类型名称长度不一致，长短交错，增加阅读难度  

如果使用类型后置
```rust
let url :String = "https://google.com";
let res :Response = reqwest::get(url).await?;
let body :String = res.text().await?;
// 以上类型都可以省略
```
更加整齐  

---

此外还有一个因素，如果使用IDE的virtual text功能，可以在`let url = "https://google.com"`的`url | =`光标所在的位置增加一个虚拟文本，标注出类型，就能避免大量省略类型造成类型不清晰
![](https://raw.githubusercontent.com/z2z63/image/main/Screenshot_20240125_213022.jpg)