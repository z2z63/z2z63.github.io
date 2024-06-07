---
title: "浏览器小技巧总结"
author: z2z63
date: 2024-06-07T15:15:14+08:00
---
最近发现身边有些同学并不知道在我看来入门级别的浏览器小技巧，所以专门写一篇文章介绍和总结一下我使用的浏览器小技巧
# Ctrl+F 搜索
Ctrl+F弹出的搜索框会自动聚焦，我的常用流程是
1. 鼠标选中文本
2. Ctrl + C复制文本
3. Ctrl + F 唤起搜索框
4. Ctrl + V (不需要鼠标点击搜索框，因为自动focus)
5. enter 下一项，shift + enter 前一项

这样的流程在第一次选中文本后就不再需要鼠标，非常快捷
# 超链接点击
检索信息时遇到的超链接往往希望在另一个tab页中打开，然而有些页面的超链接由于没有设置`target="_blank"`，点击后会在当前tab页打开，导致无法同时查看两个页面  
可以按住Ctrl然后点击超链接，不论超链接如何设置`target`属性，都会在新tab页中打开  
相对的还有按住Shift然后点击超链接和按住Alt点击超链接，分别是在新窗口打开页面和下载页面
# Tab页切换
实际上绝大部分带tab的应用程序，都可以使用Ctrl+Tab切换tab页，而且长按和短按有不同的效果
# 快速进入常用网站
chrome的搜索栏会记忆访问的网站，在地址栏输入链接的部分，可以补全，相当于缩写网站链接，非常实用的功能  
![](https://raw.githubusercontent.com/z2z63/image/main/202406071953990.png)
例如最近打数据库比赛，输入仓库名的开头三个字符就能快速访问仓库  
这个功能也能在收藏的网站中搜索，例如收藏了xv6实验的网站后就能快速补全  
![](https://raw.githubusercontent.com/z2z63/image/main/202406071955779.png)
搜索bookmark是根据收藏时给bookmark起的名字搜索的，默认的bookmark名是网站的标题，所以中文也能搜索
![](https://raw.githubusercontent.com/z2z63/image/main/202406071957850.png)

---
因为地址栏的补全实在太强大， 需要有意识的维护常用缩写，包括
- 常用网站主动使用缩写，增加缩写使用频率
- 不常用的网站不使用缩写，不在地址栏输入google search的关键词
# 快速导航至浏览器功能
Ctrl + H(History)打开历史页面，可以快速找到之前关闭的页面  
Ctrl + Shit + N打开无痕模式，因为无痕模式相当于使用另一个Profile，不会使用已经有的cookie，而且浏览器扩展默认设置为禁止在无痕模式下工作，可以满足以下需求
- 不想被网站跟踪
- 查看未登录时网页的情况
- 一个站点登录两个帐号
- 快速临时禁用浏览器扩展，排除扩展引起的问题

# 缩放
网页字体太小，或者留白太多时，可以使用缩进增强视觉体验  
快捷键Ctrl + 滚轮
![](https://raw.githubusercontent.com/z2z63/image/main/202406072018756.png)
大部分网站都能在应用110%或125%的缩放时仍然保持良好观感，同时由于增加了字体大小，可以有效避免字体和按钮边缘毛刺、割裂的情况
# 地址栏显示的内容很重要
## 反映资源id
地址栏显示的当前url，可以反映出资源id  
例如github的仓库名由两个部分组成，分别是用户名和仓库名，分别唯一标识了不同的实体  
又例如bilibili的视频链接格式`/video/BVxxxxx`，说明了视频由BV号唯一标识   
有些资源id不会直接显示给用户，但有可能出现在url中
## 文章段落定位
url末尾可以接上诸如`#abce`这样的部分，它被称为[hash](https://en.wikipedia.org/wiki/URI_fragment)，HTTP协议会忽略`#`之后的所有内容，但这样的内容可以被浏览器用于打开页面后滚动至对应的段落，原理是`#`后接的是页面元素的`id`，然后浏览器在页面中找到具有这个`id`值的页面元素，然后滚动使其进入视口并位于顶部
![](https://raw.githubusercontent.com/z2z63/image/main/202406072059168.png)
在大部分具有传统的文章概念的页面中，鼠标悬停标题可以看到一个小图标，点击这个小图标就能定位到这个元素，此时地址栏显示的url的末尾也出现了`hash`  
例如github
![](https://raw.githubusercontent.com/z2z63/image/main/202406072101221.png)
又例如python包常用的文档托管网站[readthedocs.io](https://docs.readthedocs.io/en/stable/)
![](https://raw.githubusercontent.com/z2z63/image/main/202406072104835.png)
知道了段落定位的原理后，可以自己根据页面元素`id`生成带`hash`的url，不仅仅可以在不支持段落定位的网站使用，还可以定位段落以外的页面元素

--- 
为什么说文章段落这个词汇，是因为web页面虽然已经非常复杂多彩，但仍然保留着`Document`这样的概念，从HTML语义化标签和HTML元素的布局模式也可以看出这一点。`<article>`，`<header>`,`<aside>`等语义化标签强化`Document`和视觉中心的存在；默认布局模式下元素从左向右排列，如果横向空间不够就换行，详情请参见《CSS: The Definitive Guide: Web Layout and Presentation》（CSS权威指南第五版）
## 避免被追踪
众所周知在京东淘宝并夕夕这样的网站点击复制分享链接后，复制的链接特别长，后面有一堆`?a=b&c=d`等参数，事实上这些参数都是url parameters，删掉他们也能正常打开页面，不删掉他们反而会被跟踪，当分享给朋友，朋友再点开链接时，服务提供方可以认为你跟这个朋友有相似的爱好，这样的信息可以用于基于协同过滤的推荐系统实现，原理可以参考[推荐系统简单介绍](/posts/recsys-summary/)这篇文章  
此外，链接很短也不代表是安全的，因为可能是使用了[短链](https://zh.wikipedia.org/wiki/%E7%B8%AE%E7%95%A5%E7%B6%B2%E5%9D%80%E6%9C%8D%E5%8B%99)，短链可以30x重定向或者由JS操作`window.location`跳转到一个很长的链接
## 前往任何页面！
用户在页面中导航有两种方式，一个是手动输入url，另一个是通过与页面的超链接、按钮等元素，在网站的引导下前往页面，这种引导可以是内容服务提供方简化用户导航过程，帮助其快速找到想要的内容，也可以是充满了内容服务提供方利益诉求的“诱导”  
以著名的深度学习平台anaconda为例  
用户为了使用anaconda而打开它的官网时，被一个显著的 Sign in 按钮吸引，而旁边就是 Free Download  
![](https://raw.githubusercontent.com/z2z63/image/main/202406072142222.png)
然后来到下载页面，页面显示提供邮箱，除此之外并没有找到其他跟下载有关的按钮或者超链接  
![](https://raw.githubusercontent.com/z2z63/image/main/202406072144085.png)
在输入了自己的邮箱地址后，anaconda公司会将真正的下载地址发送到邮箱中  
然而只需要仔细观察，就能发现刚刚引导用户登录的页面是`https://www.anaconda.com/download`，而邮箱中的链接是`https://www.anaconda.com/download/success`  

由于刚刚的流程并没有注册和登录，所以anaconda网站无法知道访问者是谁，这样的链接很难让人不怀疑是不是没有登录墙保护，Ctrl+Shift+N进入无痕模式，尝试直接输入`/download/success`访问，居然也能成功
![](https://raw.githubusercontent.com/z2z63/image/main/202406072150212.png)

可见这样的页面组织只是为了收集使用者信息，方便anaconda公司宣传产品，所以刻意阻止用户直接下载anaconda而离开页面  

## 根据域名快速判断内容可信度
当使用搜索引擎进行信息检索时，需要在搜索引擎提供的一系列结果中筛选。除了网页标题，域名也是判断内容可信度的一个非常重要的依据  
点名批评百度，不仅仅广告排第一位而且不显示域名，极力误导小白用户，破坏简中互联网  
例如一个小白用户下载steam的流程：打开百度搜索steam
![](https://raw.githubusercontent.com/z2z63/image/main/202406072202725.png)
然而点击第一个超链接
![](https://raw.githubusercontent.com/z2z63/image/main/202406072202789.png)
而如果能提前知道这个网站域名是`game.pengchengxinxi.cn`，就能快速判断出不是steam
# 进阶使用
浏览器不使用dev tool一定是不完整的，dev tool功能非常强大，由浏览器厂商开发，是消费者与商业公司制衡的一个非常有利的工具。它也让前端毫无秘密。任何在前端限制用户使用的页面都在dev tool下暴露原型，其公司的姿态可见一斑
## 长截图
长截图从技术原理上来说比截图复杂得多，甚至有些从原理上是无法长截图的，比如自绘UI，而只能从某些角度近似的实现长截图的功能  
浏览器也是非常经典的自绘UI，而它提供了一个很方便的长截图功能  
首先打开dev tool，找到相应元素，右键捕获截图即可
![](https://raw.githubusercontent.com/z2z63/image/main/202406072216178.png)
寻找元素的技巧如下
- 语义化标签，例如github的仓库主页，有main标签可以快速定位
- 需要长截图是因为一个元素的高度大于视口高度，找到这样的元素即可
- 不断寻找父元素直到其内容覆盖整个屏幕
- 某些页面布局很难甚至无法找到这样的元素
## 我就要复制！
### 解法1: 打开dev tools复制
简单的场合下，仅仅是监听事件然后阻止了复制事件的默认行为，在dev tools中复制即可，因为JS无法控制dev tools  
![](https://raw.githubusercontent.com/z2z63/image/main/202406072238486.png)
### 解法2: 禁用JS
前文提及阻止复制是JS实现的，所以只要打开dev tools禁止页面加载JS脚本，然后刷新页面即可  
![](https://raw.githubusercontent.com/z2z63/image/main/202406072235586.png)
在不考虑各种浏览器扩展，油猴脚本的情况下，可以简单的使用JS的DOM接口实现  
原理是找到包含文本的HTML元素，访问其[innerText](https://developer.mozilla.org/en-US/docs/Web/API/HTMLElement/innerText)属性即可这个元素渲染出的的文本
### 解法3: innerText
![](https://raw.githubusercontent.com/z2z63/image/main/202406072231070.png)
由于这样的元素中的文本被HTML标签分隔，需要依次选中每段文本然后复制，非常麻烦   
可以使用HTML元素的[`innerText`](https://developer.mozilla.org/en-US/docs/Web/API/HTMLElement/innerText)属性，它表示该元素内渲染的文本   
要访问`innerText`属性，必须先获得这个元素的引用，将其保存在JS的变量中，此处不需要使用xpath或CSS selector等选择器，直接使用dev tool提供的快捷功能获取其引用  
![](https://raw.githubusercontent.com/z2z63/image/main/202406072242047.png)
dev tools将这个元素绑定到`temp1`变量上，然后访问其`innerText`属性即可  
![](https://raw.githubusercontent.com/z2z63/image/main/202406072244068.png)
此处获取到的文本是转义过的，而我们明显不想复制`\n`，使用`console.log`打印出来即可  
![](https://raw.githubusercontent.com/z2z63/image/main/202406072245592.png)
## 清除cookie
众所周知bing的中国特供版有些功能并没有，而大陆用户能访问的“国内版”和“国际版”，实际上都是中国特供版，而不是真正的国际版。  
绕过区域限制中的一个步骤就是清除cookie，即使没有登录，网站也可以设置cookie用于追踪用户。只要第一次在大陆网络环境访问bing，被设置了相应cookie，即使下次通过国际网络访问，也会因为之前设置的cookie而被认为是大陆用户  
解决方案就是打开dev tool，依次点击Application - Cookies - https://xxx.com，逐个删除cookie即可
![](https://raw.githubusercontent.com/z2z63/image/main/202406072254466.png)