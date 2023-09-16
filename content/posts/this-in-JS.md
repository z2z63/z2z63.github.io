---
title: JS中的this
date: 2023-07-16 00:18:01
tags: [JS]
---
箭头函数和普通函数中的this
```js
const obj = {
    name: "Alice",
    ptr:this,
    sayName: function () {
        console.log(this)
    },
    sayNameArrow: () => {
        console.log(this)
    }
};

const sayName = obj.sayName;
const sayNameArrow = obj.sayNameArrow;

obj.sayName();
sayName();
obj.sayNameArrow();
sayNameArrow();
```
输出为
```text
{name: 'Alice', ptr: Window, sayName: ƒ, sayNameArrow: ƒ}
demo1.js:5 Window {window: Window, self: Window, document: document, name: '', location: Location, …}
demo1.js:8 Window {window: Window, self: Window, document: document, name: '', location: Location, …}
demo1.js:8 Window {window: Window, self: Window, document: document, name: '', location: Location, …}
```
可见：
- 普通函数的this指向调用它的对象，如果在obj上调用它，既`obj.sayName()`，那么this就指向obj，如何在全局作用域调用它，既`sayName()`，那么this就指向全局对象window
- 箭头函数不提供this，它的this是捕获外部的this，在此处就相当于是捕获了`obj.ptr`，而`obj`内的this指向的是obj所在的作用域，也就是全局作用域，所以`obj.sayNameArrow()`和`sayNameArrow()`的this都指向全局对象window

如果尝试打印`obj.ptr`，会发现它在浏览器中就是`window`，也就是全局对象