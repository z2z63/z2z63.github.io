---
title: Linux桌面美化之音频频谱可视化部件panon以及pulseaudio天坑
author: z2z63
date: 2023-03-30 16:47:42
tags: [Linux, Linux Desktop]
draft: true
---

## [panon](https://github.com/rbn42/panon)是一个 KDE 的音频频谱可视化 widget(插件)

先上效果图
![panon效果演示图](https://i.328888.xyz/2023/03/30/iCgwxc.png)

### 如何使用

1. 安装依赖
```bash
sudo pacman -S qt5-websockets \
    python-docopt python-numpy python-pyaudio python-cffi python-websockets
```

2. 在 KDE 桌面右键点击 “add Widget”，在弹出的界面选择 "Get New Widget" - “Download New Widget”,输入 panon 并安装
3. 把 panon widget 添加到桌面

### 天坑来了，panon 只会可视化麦克风的音频输入

经过一番浏览器的操作，我终于发现这个问题在 github 上已经有人提过[issue](https://github.com/rbn42/panon/issues/11)了
有位佬说到{% blockquote %}I think it probably is the same issue. It may be a bug somewhere, I think it is most likely in pulseaudio (because the same happens with other backends when using the available testing scripts).

Best configuration I could find so far is to configure ALSA plug-in in pulseaudio settings (pavucontrol) so it captures the Monitor of Internal Stereo Audio (or sth similar, as I'm translating from another language).

If you do that, panon shows the spectrum of output sound (speakers/headphones), while if you select Internal Stereo Audio the spectrum of the input sound is shown (internal/external microphone).

Please give it a try and tell if you see the same behavior.{% endblockquote %}

虽然很多都看不懂，不过他提到了一个东西叫做[pulseaudio](https://zh.wikipedia.org/wiki/PulseAudio)，他还说了目前最好的方法是设置 ALSA plugin-in，尝试在 KDE 桌面搜索 pulseaudio 并打开，一切都豁然开朗
![pulseaudio的ALSA plugin-in设置项](https://i.328888.xyz/2023/03/30/iCxhZb.png)

然后搞定，打开 spotify 来一首 Matin Garrix 的[Animal](https://open.spotify.com/track/0A9mHc7oYUoCECqByV8cQR),看着 panon 的特效随着 beat 上下跳动的节奏，折腾也有了意义
后面又出现修改 panon 特效或把 panon 的 widget 放到 pannel 上的时候 panon 没反应直接变成一条直线的情况，注销并重新登录即可解决，不得不说 Linux 的桌面还是有点不痛不痒的小 bug(但似乎不是 KDE 桌面的问题？)

### 开源软件不保证可用性

在下载 panon 的时候可以看到这样一句话{% blockquote %}The content avaliable here hase been upload by users like you, and has not been reviewed by your distributor for functionality or stability{% endblockquote %}
![KDE下载panon的界面](https://i.328888.xyz/2023/03/30/iC7uFb.png)
所以那些声称**开源有可能是陷阱**的人究竟是意图何在？
