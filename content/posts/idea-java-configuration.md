---
title: "Idea配置java项目"
date: 2023-09-20T15:29:39+08:00
tags: [Java]
---
IDEA更新后以前的项目不知道为什么不能直接运行了，新建项目后也不会自动创建运行配置了，为了解决这个问题踩了不少坑  
声明一下所说的运行配置是指Run/Debug Configuration
# java项目的构建
众所周知java一般是用maven或者gradle构建的，他们都能做到管理依赖、管理构建任务、编译等过程。  
在idea的运行配置中，也可以选择gradle和maven，然后如果你选择了它们作为运行配置，多半会看到这个界面
![](https://raw.githubusercontent.com/z2z63/image/main/img20230920153257.png)
然而一般来说希望看到的应该是这个
![](https://raw.githubusercontent.com/z2z63/image/main/img20230920154601.png)
实际上，maven和gradle作为构建工具，命令行调用时可以传入不同参数作为task，构建工具不负责运行

# 如何设置idea的运行配置
首先我们要清楚idea支持三种方式
- IDEA Build
- maven
- gradle

和idea定位相同的eclipse也有eclipse build，不推荐使用IDE特有的方式构建，因为他们往往是跟IDE绑定的，无法直接在命令行使用，不如专业的构建工具成熟  
一个新的IDEA项目，需要首先指定java SDK版本  
1. 在设置中找到Project Structure，配置SDK
![](https://raw.githubusercontent.com/z2z63/image/main/img20230920153950.png)
2. 点击File-settings，找到Build,Execution, Deployment - Build Tools - Gradle  
把Build and run using和Run test using改成IntelliJ IDEA
![](https://raw.githubusercontent.com/z2z63/image/main/img20230920154230.png)
使用maven可以跳过这一步
3. 创建一个'Run/Debug Configuration'，选择JDK、main方法入口，保存
   
到这一步已经能够实现这样的效果
![](https://raw.githubusercontent.com/z2z63/image/main/img20230920154601.png)
# Tips
在使用第三方库的时候又踩了一个坑，整理一下java项目使用第三方库的流程
1. 在[maven中心仓库](https://mvnrepository.com/)上搜索想要的包
2. 指定版本后，直接复制配置，粘贴到pom.xml或build.gradle即可
   ![](https://raw.githubusercontent.com/z2z63/image/main/img20230920155320.png)
3. pom.xml或build.gradle改变后，IDEA会重新同步它们的更新，然后可以看到新加入的包出现在文件管理器的'External Libraries'中
4. 至此就可以根据包名使用了。然而比较坑的一点就是包在maven中心仓库的坐标并不总是他们的包名，需要确定包名  
   按理来说，直接找到包的文档网站，能够看到一些代码片段有这样的语句
   ```java
   import com.squareup.okhttp.OkHttpClient;
   ```
    然而实际上，文档中的代码片段几乎不会有这样的语句

## 如何确定包名
首先已经知道了这个包的俗称，根据俗称可以在maven中心仓库搜索得到这个包的坐标，然后就能下载到这个包的jar文件。
根据jar的规范，解压jar包后，在`META-INF/MANIFEST.MF`中有这个jar包的元数据。例如okhttp包，`META-INF/MANIFEST.MF`内容为
```text
Manifest-Version: 1.0
Automatic-Module-Name: okhttp3
```
可以知道包名为okhttp3，而不是com.squareup.okhttp！