---
title: matplotlib在linux平台上显示中文的解决方案
date: 2023-04-02 22:12:22
tags: [Linux, 科学计算]
---
matplotlib 是python的可视化库，但是如果在matplotlib的图表中使用了中文，
会找不到中文字体而显示乱码，网上有很多教程解决这个问题，但是在我的linux上都不管用
经过不断尝试和google，终于找到了方法  
可以随便选择能够选择中文的字体，但是要注意font family和字体名称的问题，以下以微软
雅黑为例
1. 把`msyh.ttc`放到matplotlib的字体目录下
    ```shell
    mv /path/to/msyh.ttc /path/to/matplotlib/mpl-data/fonts/ttf/
    ```
    其中第一个路径是微软雅黑字体文件的路径，对于linux来说，这个字体可以从网上下载
    如果安装了这个字体可以在`/usr/fonts`下找到（用`locate`命令搜索, 见[linux文件搜索神器](https://z2z63.github.io/2023/04/01/linux-file-search/)
    第二个路径是matplotlib安装的目录，可以执行以下代码找到这个目录
    ```python
    import matplotlib
    print(matplotlib.matplotlib_fname())
    ```
2. 修改matplotlib配置文件  
    打开matplotlib的全局配置文件，会看到这段话
    ```text
    ## This is a sample Matplotlib configuration file - you can find a copy
    ## of it on your system in site-packages/matplotlib/mpl-data/matplotlibrc
    ## (relative to your Python installation location).
    ## DO NOT EDIT IT!
    ##
    ## If you wish to change your default style, copy this file to one of the
    ## following locations:
    ##     Unix/Linux:
    ##         $HOME/.config/matplotlib/matplotlibrc OR
    ##         $XDG_CONFIG_HOME/matplotlib/matplotlibrc (if $XDG_CONFIG_HOME is set)
    ##     Other platforms:
    ##         $HOME/.matplotlib/matplotlibrc
    ## and edit that copy.
    ```
    这句话的意思就是，为了不污染全局配置，可以把这个配置文件复制到用户的配置目录下，单独为一个用户配置
    ```shell
    cp /path/to/matplotlibrc ~/.config/matplotlib/matplotlibrc
    ```
    然后用vim打开matplotlibrc，找到以下两行，取消注释改成这样
    ```text
    font.family:  Microsoft YaHei, sans-serif
    font.serif:   Microsoft YaHei, DejaVu Serif # 此处把微软雅黑放到第一个位置
    ```
   
3. 最关键的步骤，**移除缓存**  
    网上很多教程都有这一步：执行python代码
    ```python
    from matplotlib.font_manager import _rebuild
    _rebuild()
    ```
    但是我执行这个代码的时候出现了Import Error，也许是版本问题  
    为了强制重新生成字体缓存，可以删掉matplotlib的缓存
    ```shell
    rm -rf ~/.cache/matplotlib
    rm -rf ~/.matplotlib/*.cache
    ```
搞定，至此可以放心的使用matplotlib了
