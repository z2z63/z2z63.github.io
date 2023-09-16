---
title: KDE折腾之自动化设置
date: 2023-07-21 13:14:56
tags: [Linux ,Linux Desktop]
---
# 需求
我有两个外置屏幕，一个1K 23.8英寸，一个1K 21英寸，同时内置屏幕在1K和2K之间（2240x1400）但只有13英寸，所以需要这个配置：
- 内置屏幕：缩放比例150%，字体DPI 144
- 外置屏幕1：缩放比例100%，字体DPI 96

然后残念的是KDE并不支持同时连接不同显示器并设置不同的缩放比例和分辨率，所以我采用的设置是
- 接上外置屏幕时，关闭内置屏幕，设置缩放比例100%，字体DPI 96
- 断开外置屏幕时，设置缩放比例150%，字体DPI 144

然而每次设置，都需要打开KDE systemsetting，修改设置后注销，很麻烦，再加上我使用的主题问题（见末尾），需要在不同字体DPI下设置不同的window decoration，而设置window decoration只能修改配置文件。当接上或者断开外置屏幕时，需要改很多设置，非常麻烦！

于是我就想，能不能写一个脚本，自动化这个过程呢？
# 踩坑过程
## xrandr
在google搜索 kde change scale command line，大部分内容都是`xrandr`，这东西并没有满足我的需求，使用`xrandr --output DisplayPort-0 --scale 1.5x1.5`后，发现它是将屏幕的帧缩放后输出，它会直接修改屏幕的逻辑分辨率，而我想要的是保持逻辑分辨率在物理分辨率（1K）的情况下，缩放显示内容
## kscreen-doctor
又发现能够通过`kscreen-doctor output.eDP.scale.1,5`修改指定屏幕的缩放比例，然而并没有效果，查阅文档后发现这个命令只能对wayland起作用
## QT_SCREEN_SCALE_FACTORS
仔细想了一下，可能缩放比例这个概念就不太正确，分辨率并没有问题，KDE只是一个桌面环境，在KDE修改了缩放比例后，它会以某种方式通知GUI程序，告诉他们应该采用什么样的缩放比例，然后GUI程序就能根据缩放比例调整按钮，文字，图标的大小，达到一个与屏幕大小观感协调的效果。查阅了[archlinux wiki](https://wiki.archlinux.org/title/HiDPI#Qt_5)后，我发现了这个环境变量`QT_SCREEN_SCALE_FACTORS`
```bash
➜  ~ env | grep QT     
QT_AUTO_SCREEN_SCALE_FACTOR=0
QT_IM_MODULE=fcitx
QT_SCREEN_SCALE_FACTORS=eDP=1;DisplayPort-0=1;DisplayPort-1=1;
```
QT会遵循这个环境变量调整缩放比例，所以修改这个环境变量就能达到目的了，于是我把这个环境变量保存在`~/.xprofile`，但重新登录后发现没有起作用，发现环境变量并没有被修改

考虑了一下，应该是修改后，又被KDE修改了，因为缩放比例这个设置保存在KDE中，KDE会根据这个设置去修改底层的一些设置，所以还是要从KDE入手

## 寻找KDE设置文件
在网上搜索能知道KDE的配置文件都在`~/.config/`下，然而具体是哪一个，网上并不能搜索到。于是我先按照名字找到了`~/.config/xsettingd/xsettingd.conf`，我发现有一个选项在修改缩放比例后会改变
```shell
➜  ~ cat ~/.config/xsettingsd/xsettingsd.conf 
Gdk/UnscaledDPI 147456
Gdk/WindowScalingFactor 1
Net/ThemeName "Breeze"
Gtk/EnableAnimations 1
Gtk/DecorationLayout "icon:minimize,maximize,close"
Gtk/PrimaryButtonWarpsSlider 0
Gtk/ToolbarStyle 3
Gtk/MenuImages 1
Gtk/ButtonImages 1
Gtk/CursorThemeSize 24
Gtk/CursorThemeName "breeze_cursors"
Net/IconThemeName "Win11"
Gtk/FontName "Noto Sans,  8"
```
我发现Gdk/UnscaledDPI这个选项，当缩放比例是100%时为98304，当缩放比例为150%时为147456，而Gdk/WindowScalingFactor这个选项并不会改变，猜测它就是xrandr中的scale选项，于是我尝试修改这个选项，发现也没有起作用。
## 监控读写文件
根据我的猜想，在KDE修改设置后，重新登录或者重启就能够生效，一定是把修改保存到了文件，然后启动的时候根据配置文件来设置一些选项，于是我就考虑监控文件读写，进而找到配置文件

### 通过文件修改时间监控文件写入
文件写入后，文件的修改时间会更新，于是我利用find命令查找文件修改时间满足一个范围内的文件
```shell
➜  ~ #!/bin/bash

# 定义要监测的目录
directory=~/.config
# 转换路径为绝对路径
directory=$(realpath "$directory")

# 获取脚本启动时的时间戳
script_start_time=$(date +%s)

# 创建一个关联数组来存储文件的修改时间
declare -A mod_times

while true; do
    # 使用find命令查找目录下所有在脚本启动后被写入的文件    
    while IFS= read -rd '' file; do
        current_mod_time=$(stat -c %Y "$file")

        # 获取文件的修改时间是否在脚本启动之后        
        if [ "$current_mod_time" -gt "$script_start_time" ]; then
            # 如果文件在之前的记录中不存在或修改时间不同，则输出文件路径            
            if [[ ! "${mod_times[$file]}" || "${mod_times[$file]}" -ne "$current_mod_time" ]]; then
                echo "文件已被修改：$file"
                mod_times["$file"]=$current_mod_time
            fi
        fi
    done < <(find "$directory" -type f -print0)

    sleep 1  # 每秒检查一次done

```
启动这个脚本，然后打开KDE systemsetting，修改缩放比例，找到一些文件被修改了，其中有`~/.config/kcmfonts`
它的内容如下
```shell
➜  ~ cat ~/.config/kcmfonts 
[General]
forceFontDPI=0
```
根据文件的修改时间，文件名的提示，还有文件内容的提示，只需要修改这个配置文件，就能达到修改字体DPI的目的

### 更简单的做法
在reddit上看到了另一个做法，修改设置后按照修改时间对文件进行排序，找到最新修改的文件。这个方法确实很简单，我找到了`~/.config/kdeglobals`这个文件，而且非常巧妙的是，它有一段内容为
```text
[KScreen]
ScaleFactor=1.5
ScreenScaleFactors=eDP=1;DisplayPort-0=1;DisplayPort-1=1;
```
根据这个group名和key名，可以确定`ScaleFactor`就是最终的答案了
## 修改配置文件
最开始我使用`sed`修改文件，缺点就是
- 写sed很麻烦
- 担心改错，所以最开始不敢写回文件
- 保存修改很麻烦，需要写入一个临时文件，然后再把临时文件重命名为原文件

在reddit上看到有一个命令是`kwriteconfig5`，是KDE提供的用来修改那些'hidden'（没有提供GUI配置选项）的配置选项，它明显比直接修改文件要方便而且安全

要修改缩放比例，只需要`kwriteconfig5 --file ~/.config/kdeglobals --group KScreen --key ScaleFactor 1.5`

## 命令行注销
也许是X11或者QT的缺陷，修改了缩放比例和字体DPI后，只能对新启动的应用生效，所以通常会注销然后重新登录，所以脚本修改这些设置后，也应该注销

然而这个注销就麻烦了，命令行，注销，一看到这两个词，我就在想，这不就是一个Ctrl+D或者exit就解决的问题吗。然而，这个是ssh会话中使用的，而我想要注销的应该是桌面会话

在网上找到了一些注销方法，有注销X会话的，直接让屏幕卡住了，我的猜想是，X是GUI的底层，而KDE作为桌面环境明显在它之上，也就是说应该注销KDE的会话

在网上找到了这个方法`qdbus org.kde.ksmserver /KSMServer logout 0 0 0`，非常有用，是通过类似进程间通信的方式通知KDE注销，跟手动注销的功能完全一模一样

## 检测外置屏幕连接状态
脚本需要检测现在使用的是什么屏幕，然后作出不同的设置  
为了简单，我就只检测屏幕连接的数量，如果连接的屏幕数量为2，就认为外置屏幕已经连接，为1就认为外置屏幕已经断开
脚本如下
```shell
xrandr --listactivemonitors | awk '/Monitors:/ {print $2}'
```

# 最终成果
```shell
#!/usr/bin/bash

SCALE=$(xrandr --listactivemonitors | awk '/Monitors:/ {print $2}')
THEME_CONFIG=/home/arch/.local/share/aurorae/themes/Win11OS-dark/Win11OS-darkrc

if [ "$SCALE" -eq 1 ]; then
    kwriteconfig5 --file /home/arch/.config/kdeglobals --group KScreen --key ScaleFactor 1.5
    kwriteconfig5 --file /home/arch/.config/kcmfonts --group General --key forceFontDPI 144
    cp  "$THEME_CONFIG-150" "$THEME_CONFIG"
    echo "one monitor connected, scaling to 150%" 
elif [ "$SCALE" -eq 2 ]; then
    kwriteconfig5 --file /home/arch/.config/kdeglobals --group KScreen --key ScaleFactor 1
    kwriteconfig5 --file /home/arch/.config/kcmfonts --group General --key forceFontDPI 96
    cp  "$THEME_CONFIG-100" "$THEME_CONFIG"
    echo "two monitors connected, scaling to 100%"
fi
sleep 1
# loginctl terminate-session $XDG_SESSION_ID
# qdbus org.kde.KWin /Session org.kde.KWin.Session.quit
qdbus org.kde.ksmserver /KSMServer logout 0 0 0
```
运行这个脚本，就能做到自动化设置了

---
KDE窗口超大外边距
参考[reddit](https://www.reddit.com/r/kde/comments/p5nji9/custom_window_decoration_causes_extremely_large/)和[github issue](https://github.com/andreyorst/Breezemite/issues/8),这其实是主题在字体高DPI时的一个bug，解决办法就是修改主题的配置文件，我使用的win11 dark主题，配置文件在`~/.local/share/aurorae/themes/Win11OS-dark/Win11OS-darkrc`，修改
```text
PaddingTop=32
PaddingBottom=76
PaddingRight=47
PaddingLeft=47
```
这四个值，就能控制窗口的外边距  
这个问题，最麻烦的就是，它并没有提供GUI的修改方式，只能通过配置文件来修改，所以定位问题相当麻烦  

此外在150%缩放比例下修改主题配置后，切换到100%缩放比例下，发现窗口边距直接挤压到窗口内部了，非常难看。。。。

解决办法就是，分别在150%缩放比例和100%缩放比例下修改主题配置，然后在脚本中根据缩放比例来选择不同的配置文件，这样就能解决这个问题了

# 总结
不得不说linux桌面真是够折腾的，也许搞了半天，只不过是实现一个windows早就有的功能。linux桌面真不适合个人用户使用。不过，linux是自由的，windows是商业的，专有的，这注定了大部分人会选择windows，而linux因为市场小，发展更慢，桌面体验肯定是不及windows的（如果商业软件体验都不如自由软件，那么商业软件怎么存活？）。虽然折腾桌面很麻烦，但确实方便了不少。使用linux是自由的，桌面哪里看不顺眼都能改，甚至还能换桌面环境和窗口管理器，还能自由选择X11和wayland，而用windows只能微软喂什么就吃什么。小小的自由的代价，还是能接受的

