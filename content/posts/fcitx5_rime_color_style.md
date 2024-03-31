---
title: "fctix5-rime设置配色方案"
author: z2z63
date: 2024-03-30T23:43:03+08:00
---
rime是一个开源、高度可定制、多平台支持的输入法框架，然而在配置fctix5-rime的配色方案时我又踩了坑，记录一下解决方案<!--more-->
# fctix5不支持rime配色
网上许多rime教程都是用的鼠须管或者小狼毫，分别是rime的macOS和windows发行版，中州韵很少遇到，此外即使遇到了中州韵，往往也是用的ibus，  
然而在2024年的今天，fctix5明显是一个更优的选择  
fctix5和ibus的一个不同点就是，配色方案不是rime的，而是fctix5的，另外在fctix5是主题（theme）而不是rime的配色方案（color style），所以网上抄的各种配色方案都不会生效，例如我抄了一个[仿微信输入法的配色方案](https://git.kuraa.cc/kura/SquirrelConfig/src/commit/5b8482722e392ab496d1d74fed7a21f15eeaa3a4/squirrel.yaml#L148)，然后试了无数次都无法生效！  
# 正确的做法
首先参考[arch wiki](https://wiki.archlinux.org/title/Fcitx5#Themes_and_appearance)，在github我找到了一个看起来不错的[仿macOS的主题](https://github.com/thep0y/fcitx5-themes?tab=readme-ov-file#3%E4%BB%BF-macos)
![mac-light.png](https://github.com/thep0y/fcitx5-themes/raw/main/images/mac-dark.png)
使用步骤见此仓库的README，将主题文件复制到`~/.local/share/fcitx5/themes`下即可

然后打开KDE的system setting
![](https://raw.githubusercontent.com/z2z63/image/main/image.png)
![](https://raw.githubusercontent.com/z2z63/image/main/image1.png)
![](https://raw.githubusercontent.com/z2z63/image/main/image2.png)

KDE会自动识别`~/.local/share/fcitx5/themes`下的所有主题文件，并显示在多选框中  
# 主题微调
使用前文提及的仿macOS主题时又遇到一个问题，候选词间距太大了，然而只要查看过`~/.local/share/fcitx5/themes`的主题文件，能够很清楚的知道主题是怎么指定的。
不同主题在以其名字命名的目录下，这个目录下有一个文件`theme.conf`，它是ini格式的配置文件，可读性较好，而且我找到的主题还贴心的给每个配置加上了中文注释。于是
我修改了一下内容
```ini
[InputPanel/Background/Margin]
# 左侧边距
Left=10
# 右侧边距
Right=10
# 顶部边距
Top=8
# 底部边距
Bottom=8

[InputPanel/Highlight]
# 背景图片
Image=highlight.svg

[InputPanel/Highlight/Margin]
# 高亮区域左边距
Left=10
# 高亮区域右边距
Right=10
# 高亮区域上边距
Top=8
# 高亮区域下边距
Bottom=8

[InputPanel/TextMargin]
# 候选字对左边距
Left=10
# 候选字对右边距
Right=10
# 候选字向上边距
Top=8
# 候选字向下边距
Bottom=8
```
就达到了我想要的效果
# 效果展示
![](https://raw.githubusercontent.com/z2z63/image/main/2024-03-31_00-14.jpg)

# Tips
rime的配置逻辑是，用户修改`xxx.custom.yaml`文件用于覆盖或重写rime的默认配置文件`xxx.yaml`，所以当不确定`xxx.custom.yaml`中的`xxx`是什么时，可以查看
`/usr/share/rime-data/`有哪些文件，假设有一个文件名字为`abc.yaml`，那么能够覆盖它的文件名为`abc.custom.yaml`  
rime的windows发行版名字为小狼毫，对应的配置文件为`squirrel.yaml`，macOS发行版为鼠须管，对应配置文件为`weasel.yaml`，linux发行版名字为中州韵,然而比较坑的是，我并没有发现中州韵对应的配置文件名，相反，在我的fcitx5-rime上对应的配置文件为`fcitx5.yaml`  

我的fcitx5-rime在用户配置错误时，不会报错，而是直接完全使用rime的默认配置，使人不知所措，此外官网上提及的日志文件`/tmp/xxx`，我并没有找到

# 我的rime配置
使用了很长时间，自认为还是比较好用，不过在中文模式下输入中文标点符号这点还是比较不方便
- default.custom.yaml
    ```yaml
    patch:
    "switcher/option_list_separator": '|'
    "switcher/caption": "[方案列表]"
    "switcher/hotkeys":
        - Control+grave
    "switcher/save_options":
    "schema_list":
        - schema: double_pinyin_flypy
        # - schema: luna_pinyin
    "key_binder/bindings":
        - {when: always, accept: Control+space, toggle: ascii_mode}
        - {when: has_menu, accept: minus, send: Page_Up}
        - {when: has_menu, accept: equal, send: Page_Down}
    ```
    主要配置了唯一一个输入法即小鹤双拼（朋友评价为防止别人用我电脑...），ctrl+空格 切换中英文（不知道为什么还是能通过shift切换中英文），
    加减号翻页
- double_pinyin_flypy.custom.yaml
    ```yaml
    patch:
    schema/name: 小鹤双拼
    switches:
    - name: ascii_mode
        reset: 1
        states: [中文, 西文]
    - name: full_shape
        reset: 0
        states: [半角, 全角]
    - name: simplification
        reset: 1
        states: [繁体, 简体]
    - name: ascii_punct
        reset: 0
        states: [ ".,", "。，" ]
    engine/processors:
        - ascii_composer
        # - recognizer
        - key_binder
        - speller
        - punctuator
        - selector
        - navigator
        - express_editor
    ```
    配置了默认使用英文输入法，半角简体，这里配置非常简单，主要目地是覆盖默认的大量配置

---
可以看出即使rime被称为最强输入法，但我几乎没有定制它的功能...