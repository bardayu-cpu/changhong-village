# 提交前检查（给 01、02、03、04）

每次 `git commit`，会先跑 `godot/tools/check_assets.py --staged`，查这次要提交的 JSON 和图。

## 提交被拦了怎么看

终端里会打出几段，每段三行：

```
拦下  godot/assets/kitchen/kitchen_atlas_v2.png
      场景零件有 312 个半透明像素（透明度只许 0 或 255）
      怎么办：让画图的把边缘改成硬边……
```

- 第一行是**哪个文件**，第二行是**哪里不对**，第三行是**怎么改**。
- 「拦下」的必须改：改完 `git add` 那个文件，再提交一次。
- 「提醒」不挡提交（图超过 1 MB、这次多了 2 MB 以上、文件名有大写），看一眼，要缩图的话记进回执。
- 图是 GPT 交的：不要自己改图，把「拦下」那几行原样写进回执给 01，让 GPT 返工。
- 实在要先提交（比如要把坏图存一份给 GPT 看），先问 01，再用 `git commit --no-verify` 跳过检查，并在提交说明里写为什么跳过。

## 查哪些（详细见 check_assets.py 开头）

| 拦下 | 只提醒 |
|---|---|
| JSON 读不出来 | 不在下面四类里的图，进手机包超过 100 KB |
| **图太大**（01 D 10/2，阿鱼嫌 1 MB 太大；量的是进手机包的大小，有损导入的按 WebP 估）：零件 blk_ art_ fg_ prop_ decal_ ≤ 100 KB；人物 chr_ ≤ 300 KB；背景 base_、base.png、瓦片 tex_ ≤ 500 KB；界面 ≤ 100 KB | |
| 场景零件（blk_、art_、fg_、chr_、厨房图集）有半透明像素 | 一次提交让要进包的图多出 2 MB 以上 |
| base.png 跟 scene.json / layout.json 写的画布大小不一样；GPT 的整张背景 base_*.png 不是 1536 宽 | assets/ 下文件名有大写、空格 |
| 瓦片尺寸不对（地砖 80×52、红毯 140×96、侧墙 96×240、55 桌竖墙 40×240），地砖、红毯有透明 | |

不查：回执/、参考/、.godot/ 下的东西；界面底和特效（base_ui_、decal_、tex_ui_）、零件另出的影子层（shadow_，01 D 10/2）可以半透明。

自己先查一遍：`python3 godot/tools/check_assets.py --staged`（查已经 git add 的），或者 `python3 godot/tools/check_assets.py 某张图.png`（查硬盘上的）。
