---
title: KDE桌面部件pano
author: z2z63
date: 2023-12-23T15:45:44+08:00
---
这篇文章描述了如何在KDE桌面环境使用一个名为pano的音频可视化widget  
<!--more-->
效果图
![](https://raw.githubusercontent.com/z2z63/image/main/imgphoto_2023-12-23_16-20-39.jpg)
# KDE如何安装widget
占坑
# 如何安装pano
pano仓库见<https://github.com/rbn42/panon>，仓库已经两年没有更新了，在比较新的系统上可能会出现一些问题，所以必须手动修改部分源码再重新编译
## 安装依赖
```shell
sudo pacman -S qt5-websockets \
    python-docopt python-numpy python-pyaudio python-cffi python-websockets 
```
其他发行版见README
## 解决一个bug
因为python的`collection.Iterable`在3.10弃用，移动到了`collection.abc.Iterable`，导致pano在python系统解释器版本比较高的情况下会出现无法显示音频的情况，
详见<https://github.com/rbn42/panon/pull/108#issuecomment-1568908093>  
先拉取pano源码
```shell
git clone https://github.com/rbn42/panon.git
cd panon
git submodule update --init
```
然后修改`./third_party/SoundCard/soundcard/pulseaudio.py`，将所有使用到`collection.Iterable`的部分换成`collection.abc.Iterable`
```diff
-import collections
+import collections.abc
-         if isinstance(self.channels, collections.Iterable):
+         if isinstance(self.channels, collections.abc.Iterable):
-         if isinstance(self.channels, collections.Iterable):
+         if isinstance(self.channels, collections.abc.Iterable):
```
然后构建widget
```shell
# Build translations (optional)
mkdir build
cd build
cmake ../translations
make install DESTDIR=../plasmoid/contents/locale
cd ..

# To install
kpackagetool5 -t Plasma/Applet --install plasmoid
```
## 安装后的设置
将pano放到任务栏后，需要设置采集音频的来源  
对于比较新的linux，基本使用`pulseaudio`提供音频服务，`pulseaudio`有很多前端可以快速的配置一些音频的选项，这里使用`pavucontrol`
```shell
sudo pacman -S pavucontrol
```
pavucontrol提供一个简单的GUI前端，打开application launcher搜索pulseaudio，设置ALSA plugin-in的采集来源，如果设置为麦克风，则pano会显示麦克风录音的音频，
然而正常情况下应该是采集耳机中播放的音乐的音频然后可视化
![](https://raw.githubusercontent.com/z2z63/image/main/imgimage_2023-12-23_16-13-53.png)
pano默认的特效有点丑，可以选择其他的特效，最终就能达到上述的效果