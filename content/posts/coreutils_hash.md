---
title: "coreutils之hash table"
author: z2z63
date: 2023-10-14T16:08:58+08:00
# math:
#   enable: true
---
最近在阅读coreutils，发现很多有意思的部分，比如哈希表的链表实现
## 字符串哈希函数
coreutils中内置了对字符串的哈希函数
```c
size_t
hash_string (const char *string, size_t n_buckets)
{
  size_t value = 0;
  unsigned char ch;

  for (; (ch = *string); string++)
    value = (value * 31 + ch) % n_buckets;
  return value;
}
```
用法为
```c
char* str = "a demo string";
size_t hash_code = hash_string(str, 100);
```
可以看出计算哈希的部分就是
```c
  for (; (ch = *string); string++)
    value = (value * 31 + ch) % n_buckets;
```
一个好的哈希函数，应该做到把输入数据均匀的映射到哈希表的所有槽，也就是每个槽的概率应该是接近的。  
还可以说，一个好的哈希函数应该充分受到输入数据的每一位的影响，最好的情况就是，当输入数据的其中一位发生改变，计算出的哈希码中多位发生改变  
31这个数字非常巧妙，因为
$$
31 = 32 - 1 = 2^0 + 2^1 + 2^2 + 2^3 + 2^4
$$
而计算机是二进制的，也就是说`a * pow(2, x)`等于`a << x`
假设`value==19`，那么`value * 31`可以表示为
```text
    10011
   10011
  10011
 10011
10011
——————————
1001001101
```
可以看出`value * 31`每一位都会受到`value`中每一位的影响，`value`中任意一位发生变动，`value * 31`每一位也必须重新计算。然后`value * 31 + ch`会添加上`ch`造成的影响，`(value * 31 + ch) % n_buckets`约束结果的范围  
取余操作肯定影响了哈希码的随机性，假设`n_buckets==8`，`value * 31 + ch`就只会保留低三位，大大降低了哈希码的随机性.  
我的理解是，当哈希表长度小时，每个槽插入数据的概率也会增加。例如哈希表长为10，那么哈希表中每个槽的插入数据概率为$\frac{1}{10}$，当插入两个数据时碰撞的概率为$\frac{10}{10\times10}=\frac{1}{10}$，当哈希表长为11时， 插入两个数据碰撞的概率为$\frac{11}{11\times11}=\frac{1}{11}$，当然当插入数据越多时，两者差距会越来越大。所以哈希表规模较小时碰撞本来就是很容易发生的。而我们关注的也只是规模较大时哈希表的性能，规模较小时哈希表和其他查询结构也没有明显优势
{{<gitalk>}}