# 苏七镇奇缘 · Godot demo：罗曼山庄吃席

> 日期：2026-09-14，9/15 宴会厅改成分层场景
> 作者：Claude
> 引擎：Godot 4.7.2，兼容渲染模式，和微信小游戏、网页导出一致
> 流程依据：《苏七镇 · 阶段 1 设计 v1.0》3.1 进镇第 3～7 步

## 怎么玩

在终端里运行：

```
open -a Godot --args --path "/Users/kayra_ayu/Desktop/苏七镇奇缘/苏七镇奇缘-claude 总文件/godot"
```

也可以打开 Godot，在项目管理器里导入这个文件夹，点运行。

操作：点地面走路；走到舞台前的新人桌会弹出悄悄话输入框；写完点「好」，再走回门口的金色光圈。

## 流程

1. 开场：「苏七镇奇缘」，按钮「打开看看」
2. 填昵称：2～12 个字，规则和提示文案按《敏感词与昵称校验模块》第 2 节
3. 选形象：美术生图包里的 8 个预设
4. 两分钟剪辑：【待补】，六句还没定，先跳过
5. 罗曼山庄：阿鱼说「到啦～ 罗曼山庄 席还没散」
6. 走到新人桌：阿鱼说「想跟我们说点什么 写这儿 只有我们看得到」，写悄悄话，最多 200 字
7. 写完：阿鱼说「吃好了？走 带你回镇上」，门口出现金色光圈
8. 出门：【待做】下一段，出了罗曼山庄往南进镇

对白全部摘自设计文档。

## 操作

- 轻点地面：走过去
- 屏幕左下方按住拖：摇杆，平时淡淡地停在左下角
- 别处左右拖：转镜头，左右各最多 45 度（只有 3D 宴会厅 `hall.gd` 有；现在用的分层宴会厅镜头不转，跟着人左右移）
- 电脑上鼠标当手指用（project.godot 里开了 `emulate_touch_from_mouse`）

## 宴会厅布局

有两种做法，`main.gd` 开头的 `USE_LAYERED` 切换，对外接口一样。

**分层场景（现在用的，`scripts/layered_hall.gd`，规格见 `ASSETS.md` 第 14 节）**：画面就是 GPT 的效果图。底图铺满，桌椅、花瓶、灯笼、屏风这些东西在底图上方再画一遍当遮挡块，人脚在某件东西着地的那一行上面（更靠里）时，这件东西画在人前面（y 排序）。人越往里越小，按 `person_px` 两行的高度插值。竖屏时整张图的高度铺满屏幕，镜头跟着人左右移。数据全在 `assets/layered/scene_roman_banquet/scene.json`，由 `tools/build_layered.py` 生成，能走的格子提前算好，手机上不读图片像素。

现在是临时版：底图是效果图原图 `approved_preview_v4.png`，遮挡块和能走的范围是 Claude 按图标的（`tools/stand_in_banquet.json`：桌子是桌面椭圆加一把把椅子的矩形，花瓶和灯笼描了轮廓，屏风、花盆、柱子、栏杆是矩形）。GPT 按任务卡 A03 交分层积木后，换成积木图，边缘会更准。

**3D 体块（`scripts/hall.gd`，留着备用）**：照 GPT 的效果图（`素材交付/reference/approved_preview_v4.png`）用 A01 积木拼：中间红毯通到舞台；两边各两列圆桌（x = ±4.8、±9.6），三排（z = -13.0、-7.8、-2.6），每桌底下一块地毯；红毯两边木格落地灯笼和花架交替；桌组之间立木格屏风；两侧墙是木格窗和囍挂幅；舞台上是主桌，新人站在后面。常量都在 `hall.gd` 开头。积木用在哪、哪些还是占位，见 `回执/A01.md`。

## 测试

```
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/test_hall.gd
```

走到新人桌、走到门口、随机点 40 个地方、摇杆往前和斜推，最后一行 `RESULT PASS` 才算过。分层宴会厅用 `tools/test_layered.gd`，另外查桌子前后遮挡和人的远近大小。`tools/test_map.gd` 打出能走的格子图（# 挡住，. 走得到）。

## GPT 素材怎么接

```
python3 tools/import_gpt.py handoff_<场景 id>_v4.json
```

分层场景：`python3 tools/build_layered.py tools/stand_in_banquet.json [检查图.png]`，生成 `assets/layered/<场景>/`；检查图上绿格是能走的、黄框是遮挡块、橙线是着地线、蓝圈是交互点。

读「苏七镇奇缘 -gpt 总文件夹/素材交付」里的交接单，检查、裁透明边、写好导入设置，拷进 `assets/`（去掉版本后缀，版本记在 `assets/sources.json`）。游戏里有 GPT 的图就用，没有就用代码画的占位：贴图见 `Pix.gtex`/`Pix.gmat`，形象见 `Spr.gpt_look`（chr_guestNN 对应第 NN 个形象），道具按 `assets/scenes/` 里的场景配置摆。接完在 `回执/` 写回执。

## 占位和没做的

- 新人用的是现有合照立绘 `备份素材/assets_v1.1_backup/roles/roles-couples/0.couple-basic.png`，只抠掉了原图画进去的棋盘格底，缩小到 320 像素高，没有重画，礼服没动
- 分层宴会厅的遮挡块是 Claude 按效果图标的，边上会带一点地面或地毯（人站在桌子后面，腿边可能被一小块地毯盖住），等 A03 积木替换
- 3D 宴会厅的形状（桌、椅、舞台、墙、灯笼架）是代码搭的 3D 体块，表面贴 GPT 的 A01 贴图；还没交的用代码画的占位：大厅石材地面、舞台木地板、7 个宾客形象（03 号已换成 GPT 的）。清单见 `回执/A01.md`
- 昵称只做了本地校验；敏感词和保留名要走服务端，还没接
- 悄悄话只存在本机 `user://whispers.json`；正式版存云数据库，只有阿鱼能看
- 字体是打包进来的缝合像素字体 12px 简体版（SIL OFL 1.1，许可证在 `assets/fonts/`，也跟着打进游戏包）。GB2312 里 145 个生僻字没有，昵称里有字体显示不出来的字会提示换一个
- 不动的方块和圆柱在搭完厅后按材质合并（`hall.gd` 的 `_merge_static`），一帧的绘制次数从 372 降到 77（微信建议不超过 200）。新加静态物件照常用 `_box`/`_cyl`，会自动并进去；同色材质要用 `Pix.flat`/`Pix.glow` 拿，才能共用、并到一起。地毯（`_rug`）按贴图坐标铺，不参与合并
- **微信里禁止从显卡读回数据**：`SurfaceTool.append_from`、`surface_get_arrays`、`get_mesh_arrays`、纹理的 `get_image` 都会调 WebGL 的 `getBufferSubData`，微信不支持，游戏直接崩（第 5、6 版就是这么崩的，电脑上测不出来）。合并用的几何数据是自己在 CPU 上算的。发版前用 `grep -nE "get_image\(|surface_get_arrays|get_mesh_arrays|append_from|MeshDataTool" scripts/*.gd` 查一遍，只允许截图工具里那一处
- 开场先黑屏，用俯视广角把整个厅画几帧，让着色器提前编译（`hall.warm_up`），走路时不再因为第一次看到某样东西而卡一下
- 转发：`wxgame/share.js` 打开右上角转发，卡片带分享人 id（现在是本机随机 id，接上登录后换住民 id）；卡片标题暂时只写游戏名，文案待阿鱼定；卡片图 `wxgame/share.jpg` 是 `./capture.sh 目录 share` 截的

## 文件

```
project.godot       工程设置：竖屏 540×960、兼容渲染
main.tscn           只挂一个脚本，其余全部用代码搭
scripts/main.gd     流程、界面、昵称校验、悄悄话
scripts/layered_hall.gd  分层宴会厅（现在用的）：底图、遮挡块、寻路、玩家、镜头
scripts/hall.gd     3D 宴会厅（备用）
assets/layered/     分层场景：底图 base.png 和 scene.json（build_layered.py 生成）
scripts/sprites.gd  8 个宾客形象的像素图
scripts/pix.gd      像素贴图
shaders/post.gdshader  移轴模糊、暗角、调色
assets/couple.png   新人合照，抠底后的版本
assets/fonts/       像素字体和许可证。界面字号要用 12 的整倍数，不然像素会歪
capture.sh          开发用：在后台打开游戏，按步骤自动截图
export-wechat.sh    导出微信小游戏到 ../wechat-build/
export_presets.cfg  导出设置：AppID、竖屏；「小游戏」是正式版，「小游戏调试」带调试工具
assets/textures|characters|props|decals|scenes/  GPT 交付的积木（import_gpt.py 接进来）
tools/              接素材的 import_gpt.py、分层场景的 build_layered.py 和临时数据 stand_in_banquet.json、测试脚本 test_layered.gd / test_hall.gd / test_map.gd（有 .gdignore）
wxgame/             微信那一层：分享、登录、调试弹窗、分享图（有 .gdignore）
回执/               每批素材的回执和对照图（有 .gdignore，不进游戏包）
```

截图：`./capture.sh 输出目录 title nick avatar clip arrive walk behind couple leave end stick share`（behind 是站在桌子后面，看遮挡）；和效果图对照的横屏俯视图：`RES=1280x720 ./capture.sh 输出目录 overview`

## 放到手机微信里

用社区插件 godot-minigame（微信官方没有 Godot 适配），已装在 `addons/godot-minigame/`。

```
./export-wechat.sh
```

导出到 `../wechat-build/`，整包约 9.8MB：主包约 100KB（含分享图），引擎分包约 9.7MB（其中游戏内容 1.4MB：字体、分层底图，底图用有损压缩）。生成手机预览二维码：

```
/Applications/wechatwebdevtools.app/Contents/MacOS/cli preview --project "<wechat-build 的完整路径>" --qr-format image --qr-output 二维码.png
```

导出默认是调试版（导出预设「小游戏调试」，带 `suqi_debug` 特性）：左上角绿字是帧率、最慢一帧和绘制次数，点一下打开日志面板；90 秒没进游戏或者出错，会弹窗显示报错和启动进度（`wxgame/debug-console.js`）；卡死的话下次打开先弹上次的日志。不用剪贴板：它在微信里算隐私接口，要先在后台填隐私指引才能用。正式上传前用 `SUQI_DEBUG=0 ./export-wechat.sh`，导出预设「小游戏」，不带这些。日志面板顶上的「远程加载」「删掉本地副本」是远程加载的最小验证（HANDOFF §0.9，`wxgame/remote.js`、`scripts/remote_probe.gd`，回执 `回执/远程加载-最小验证.md`），也只在调试版里。

`../wechat-build` 只由助理 01 导出、出码。只想验证导出脚本时，给一个临时目录：`./export-wechat.sh /tmp/某个空目录`，目录里有东西又不像上次导出的就不删。

`wxgame/` 里是微信那一层的脚本和图，导出时由脚本拷进 `wechat-build/`；有 `.gdignore`，Godot 不导入。

开发者工具生成二维码时报 `worker thread exit with code: null when it is busy`：先 `cli quit` 退出开发者工具再生成。清缓存没用。

插件的几个坑，脚本里都处理了：

- 插件是 3 月的版本，读不懂新格式的版本表，会把模板名认成「4.7」。模板 `minigame4.7.0.7.tpz` 是手动下载后放进缓存的，文件名就叫 `4.7`。缓存位置：`~/Library/Application Support/Godot/app_userdata/苏七镇奇缘/toolkit/templates/sources/github/godothub__godot-minigame__4.7/templates/`。缓存被清掉的话，从插件仓库 4.7 那一版重新下载，放回去
- 插件把游戏包写成 `engine/demo-pck.bin`，4.7 模板却读 `engine/empty-tips.bin`（模板自带的示例），脚本会改成读我们的包，并删掉示例包和分包示例
- iPhone 要在小游戏后台开「高性能+模式」：功能 → 游戏能力地图 → 研发能力 → 生成提效包 → 高性能模式。没开的话，iPhone 上能不能跑：待验证
