---
title: MATLAB微积分
date: 2023-05-26 15:51:48
tags: [科学计算]
mathjax: true
---
## MATLAB数值求解微分方程
所谓数值求解，也就是无法获得解的方程，只能获得y(x)函数在x取值范围内的近似值
所有MATALB的DOE solver都可以解决形如$\frac{\mathrm{d}y}{\mathrm{d}t}=f(t,y)$的微分方程，所以很多时候需要把待求解微分方程化成这种形式，这种形式有几种特点
1. 导数在等号左边
2. 只有两个变量
3. 导数只有一阶

不过实际上，一些不满足这种形式的微分方程也可化成这种形式
### 一阶微分方程数值求解
$$ y^{'} = \frac{x\sin x}{\cos y} $$
这个微分方程形式非常好，可以直接拿来求解  
使用`ode45`函数，x的取值范围为$[0,1]$，$y(0)=0$,取初值为0  
先定义微分函数
```matlab
function ydot = fn(x, y)
    ydot = x * sin(x) / cos(y);
end
```
然后使用ode45求解
```matlab
[x, y] = ode45(@fn, [0,1], 0);
```
`x`向量的每一列都对应`y`向量的每一列
然后用这个微分方程的解析解与数值解做比较
```matlab
[x, y] = ode45(@fn, [0,1], 0);
subplot(1,2,1);
plot(x, y);
x = 0:0.01:1;
y = asin(sin(x)-x.*cos(x));
subplot(1,2,2)
plot(x, y);

function ydot = fn(x, y)
    ydot = x * sin(x) / cos(y);
end
```
结果如下
