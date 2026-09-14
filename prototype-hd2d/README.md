# 苏七镇 · HD-2D 场景样机

> 日期：2026-09-11
> 作者：Claude
> 性质：风格样机，不是正式客户端。回答两个问题：苏七镇做成 HD-2D 好不好看；这套画面手机跑不跑得动
> 参考：小红书笔记《用AI，从零开始搭建HD2D风格游戏场景》，作者热心市民刘一昂（Unity，豆包和 GPT 当老师，像素自己画）

## 怎么打开

- 电脑：双击 `index.html`。要联网，Three.js 从 jsDelivr 加载
- 手机：用发布出去的网页链接，面板里看帧率
- 改代码：改 `src/` 下的文件，再跑 `./build.sh`，会重新拼出 `index.html` 和 `artifact.html`

## 给朋友看的版本

`./build.sh share` 生成 `share/index.html`，一个文件，约 580KB：

- 不连任何国外服务器。Three.js 0.160.0 的 14 个文件在 `vendor/three/`，2026-09-13 从 jsDelivr 上的 npm 官方包下载，MIT 协议，打包时用 esbuild 并进同一个文件
- 字体改用手机自带的，不加载 Google 字体
- 收起调试内容：画质、帧率、Draw Call、"占位美术"说明。保留时间、镇子状态、快速去
- 打包目标是 iOS 12 以上的 Safari，不用 import map，老一点的微信内置浏览器也能跑

打包用的 esbuild 借用本机另一个项目里装好的那份，路径写在 `build.sh` 里；换电脑时用环境变量 `ESBUILD` 指定。

## 发给朋友：怎么发布

2026-09-13 核实。没有域名、没有备案的情况下，只能这样给少数朋友看，不适合大范围转发。

1. 登录腾讯云「云开发平台」 https://tcb.cloud.tencent.com/dev ，腾讯云账号要先实名认证。新建一个环境，先试免费体验版；开不了静态网站托管就选个人版
2. 进「静态网站托管」，点「上传文件」，把 `share/index.html` 传到根目录
3. 复制默认域名链接（`….tcloudbaseapp.com`），先发给自己的「文件传输助手」，在微信里点开，确认能进、能走、画面正常
4. 再发给朋友，提前说两件事：第一次打开会先看到「仅供开发测试」的提示页，点「确定访问」；如果微信提示风险或打不开，点右上角「…」选「在浏览器打开」

| 项 | 情况 | 来源 |
| --- | --- | --- |
| 费用 | 个人版 19.9 元/月，流量 0.21 元/GB；这个页面约 0.58MB，100 人次约 1 分钱。免费体验版能不能开静态网站托管：待验证 | [套餐](https://cloud.tencent.com/document/product/876/127357)、[计费](https://developers.weixin.qq.com/minigame/dev/wxcloud/billing/price.html) |
| 提示页 | 2025-10-09 以后建的环境，默认域名先显示「仅供开发测试使用」中间页，要点「确定访问」 | [默认域名说明](https://docs.cloudbase.net/service/alias) |
| 下载问题 | 默认域名下，页面以外的请求会被当成下载。share 版是单个文件，只有页面这一个请求，不受影响。旧 iPhone（iOS 16.4 以下）会不会整页被当成下载：待验证 | 同上 |
| 微信里打开 | 不保证。官方客服回复过：默认域名要换成已备案的自己的域名 | [社区回复](https://developers.weixin.qq.com/community/minihome/doc/000004b0760698fae5c30643161c00)、[外链规范](https://weixin.qq.com/agreement/weixin_external_links_content_management_specification) |
| 使用范围 | 官方写明默认域名「严禁用于正式生产环境或分发给大规模用户」 | [默认域名说明](https://docs.cloudbase.net/service/alias) |

想长期、放心地在微信里传：买域名、做 ICP 备案、绑成自定义域名，这是唯一稳妥的办法。域名价格：需补充。

## 他的做法，苏七镇的做法

| 步骤 | 视频里 | 样机里 | 正式版还要做 |
| --- | --- | --- | --- |
| 定风格 | 参考《歧路旅人》 | 美术包 1.2 调色板；单一暖光从左上来，阴影偏紫 | 风格锚点（任务卡 A01） |
| 搭白模 | Unity 里摆 3D 场景 | 按阿鱼标注的地图由北向南摆，见下一节 | 按实景照片校比例 |
| 像素贴图 | AI 出图，再自己清理 | 全部用代码逐像素画：青石板、小青瓦、穿斗白墙、水面 | AI 出图后按美术包 2.3 做像素网格修正 |
| 2D 角色站在 3D 里 | 自己画 | 占位：宾客 3 号预设、三猫一狗、三种作物三个阶段 | 8 个宾客、三猫一狗按美术包出 |
| 光照 | 实时光 | 太阳加灯笼点光，天色跟北京时间走 | — |
| 后期 | 景深、泛光 | 移轴模糊、泛光、调色、暗角 | 微信不建议做后处理，要写省电的版本 |

## 样机里有什么

- **地图**：罗曼山庄 → 牌坊（匾写"苏七镇"）→ 本地人集市 → 镇政府和苏七小学，门口是黄葛树 → 老街 → 石板桥 17 孔 → 河南岸住宅区、游客集市；月老庙在河对岸西边。桥是过河唯一的路
- **规则**：逢单日赶场、6～8 月涨水、19:30～20:30 夜游，判断方法和 `server-claude/src/time.js` 一致
- **共建**：17 盏桥灯，面板上拖动看点亮效果，全亮时弹"桥全亮了"
- **对白**：走到地方阿鱼说一句，全部摘自《阶段 1 设计 v1.0》第 4 节和《文案改写版 v2》
- **互动**：点地面自动寻路；点猫狗听介绍；点球踢一脚；找得到躲在卡卡角角的求求
- **遮挡**：人走到房子背后时，挡在前面的那排房子和黄葛树冠会变透明
- **画质**：低、中、高三档，面板显示帧率和 Draw Call。手机默认中档

## 占位和待确认

- 阿鱼和 Toretto 没放进来。美术包 0.1 规定只能用现有原图，原图是 1024×1536 的立绘，要先按美术包 3.1 出小尺寸 sprite
- 宾客、动物、作物都是代码画的占位
- 月老庙只做了外殿。没许愿的人看不到内殿，样机不做
- 没接服务端。球的计数、桥灯进度只在本机
- 桥在游戏里先叫"石板桥"，这是阿鱼地图上的叫法。用不用"茹公桥"：待阿鱼定
- 桥灯点亮顺序：阶段 1 设计写"从东岸往西"，按阿鱼标注的地图桥是南北向。样机从北岸老街一侧往南点：待确认
- 新人家门窗上的"囍"是样机加的装饰：待阿鱼确认
- 美术包 1.1 提案头身比 1:2，现有阿鱼立绘约 1:5。美术包自己规定以现有素材为准，样机的宾客按约 1:3 画

## 微信小游戏的限制

2026-09-11 核实。

| 项 | 数字 | 来源 |
| --- | --- | --- |
| 包体 | 主包 ≤ 4MB；主包加分包 ≤ 30MB。30MB 是 2023 年对开通虚拟支付的游戏放宽的，没开的是否也是 30MB：待验证 | [分包](https://developers.weixin.qq.com/minigame/dev/guide/base-ability/subPackage/useSubPackage.html)、[公告](https://developers.weixin.qq.com/community/minigame/doc/00088e009103508f3270aaf9c61001) |
| 代码 | 不能从网络加载，全部算包体 | [JS 支持](https://developers.weixin.qq.com/minigame/dev/guide/runtime/js-support.html) |
| WebGL2 | Android 微信 8.0.24 起；iOS 只在高性能模式下，官方写"存在较多问题" | [高性能模式](https://developers.weixin.qq.com/minigame/dev/guide/performance/perf-high-performance.html) |
| 渲染建议 | Draw Call ≤ 200；单张贴图 ≤ 512、图集 ≤ 1024；阴影贴图 ≤ 1024；原话"不建议在微信小游戏使用后处理" | [渲染优化](https://developers.weixin.qq.com/minigame/dev/guide/game-engine/unity-webgl-transform/Design/RenderOptimization.html) |
| Cocos Creator 3.8 | 官方支持发微信小游戏；后处理内置 Bloom，没有景深和移轴 | [发布](https://docs.cocos.com/creator/3.8/manual/zh/editor/publish/publish-wechatgame.html)、[后处理](https://docs.cocos.com/creator/3.8/manual/zh/render-pipeline/use-post-process.html) |
| 团结引擎 / Unity | 代码分包后首包 3～5MB；启动时间是普通小游戏的 2～3 倍 | [Wasm 分包](https://developers.weixin.qq.com/minigame/dev/guide/game-engine/unity-webgl-transform/Design/WasmSplit.html)、[启动优化](https://developers.weixin.qq.com/minigame/dev/guide/game-engine/unity-webgl-transform/Design/StartupOptimization.html) |
| Three.js | 没有官方维护的小游戏适配 | [threejs-miniprogram](https://github.com/wechat-miniprogram/threejs-miniprogram) |

## 样机实测

| 项 | 数字 |
| --- | --- |
| Draw Call | 桌面每帧 57～111 |
| 最大贴图 | 地面 1008×763，图集 512×256 |
| 阴影贴图 | 中、低档 1024，高档 2048 |
| 帧率 | 预览窗口在后台，测不准。要用真机打开网页看面板 |

## 如果定了走 HD-2D，要改的文档

以下只列不改，等阿鱼确认：

- GDD 第 1、7 节引擎：Phaser 3 只能做 2D，走 HD-2D 等于把它排除。候选剩 Cocos Creator 3.8（本机已装 3.8.8）和团结引擎
- GDD 第 1、6 节美术："16-bit 像素"改成"3D 场景＋像素贴图＋2D 像素角色"
- 美术生图包 1.3、3.2：场景从"整张背景＋可走层＋遮挡层"改成"3D 模块＋像素贴图"
- 阶段 1 项目计划任务卡 01：评估报告加一栏"HD-2D 在中低端机上的帧率"
- 任务卡 A01：风格锚点从一张图改成一个能跑的场景切片

## 文件

```
share/index.html  给朋友看的单文件，不依赖外网
vendor/three/     Three.js 0.160.0，打包 share 版用
index.html      拼好的单文件，本地打开
artifact.html   同上，去掉 html/head，用来发布网页
build.sh        拼文件
src/00-head.html   页面、样式、面板
src/10-core.js     坐标、调色板、时间规则、对白
src/20-pixel.js    像素贴图、地面、招牌字
src/25-facades.js  川西民居立面
src/30-sprites.js  宾客、动物、作物
src/40-kit.js      房子、屋顶、树、摊位、门楼
src/45-layout.js   地图分区、河、桥、桥灯、夜游船
src/46-town.js     摆房子、摆树、摆摊
src/50-nav.js      寻路
src/55-actors.js   玩家、动物、镇上的人、球
src/60-render.js   光、天色、后期、画质
src/70-ui.js       对白、输入、面板、主循环
```
