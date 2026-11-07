# D3 人物情景补图交接（2026-11-07）

范围：仅补图和素材清单，未修改代码、未提交git、未更动已认可的desk_r4。使用内置 `image_gen`（不是CLI/API）；所有最终资产已复制到项目内，逐图人工查看且PNG解码核验成功。实际运行接入与交互验收由D2完成，这份文档不将图片完成等同于全篇完成。

项目目录：`godot/hongyuan/assets/round1/people/`。

| 文件 | 实际像素 | 用途与注意 |
|---|---|---|
| group_shoulder.png | 841×1870 | 上海窗边越肩持iPhone；上海地标仅用于上海，不能用于成都。手机屏幕空白。 |
| group_chengdu.png | 841×1870 | 与上海版相同人物/手/手机构图，窗外改为成都树木、民居与远山，无上海塔。 |
| call_split.png | 916×1717 | 上下双地点通话，上阿鱼夜间卧室，下Toretto沙发；各自手机在耳旁；上方有气泡空间。不是精确9:20，cover约需左右各裁10%，两张脸在中部。 |
| offer_room.png | 841×1870 | 阿鱼独自在房间坐电脑前，后侧视角，屏幕留白，未烘焙其他主角。 |
| daily_walk.png | 841×1870 | 两人傍晚河边同行，自然成人比例；背景有路人；无字幕，无扶眼镜动作。两主角已烘焙，禁止再叠第二对。 |
| turtle_boarding.png | 916×1717 | 旁观视角的乌龟客船，明确龟壳/龟首/开门/舷梯/近岸码头，近处无人，远处游客。不是精确9:20；角色走位应从源图几何映射。 |

## 接入坐标（源图像素，不是360逻辑画面坐标）

- 两张群聊：手机有效可写屏幕约`Rect2(482,804,111,207)`；Dynamic Island位于`y785`附近。手机中屏幕小，建议显示微信图标/未读点，正文消息用清晰轻量浮层，而不是强行在约48逻辑像素宽的屏上排完整中文。实际坐标以cover变换后的矩形为准。
- 双人通话：分界`y900`；阿鱼头顶约`(520,380)`，Toretto头顶约`(500,1120)`；气泡可在各头顶上方，不能将两行都放最顶部同位置。
- 邮件屏幕四角约`(563,849),(705,864),(686,983),(547,962)`；电脑点击包围`Rect2(464,836,257,221)`。先显示可点击未读提醒，再展开可读的正式Offer正文。
- 乌龟船入口脚点约`(578,837)`，舷梯下沿中心`(300,1216)`；舷梯安全多边形约`(180,1190),(420,1230),(640,832),(552,808)`；码头在`y1250`以下。原图是静态美术，登船角色动作、遮挡、海面动画由程序接入，不能把这张静图本身算作可上船玩法完成。

## 生成提示集和修订

共同提示：游戏生产素材，硬边像素马赛克、360×800逻辑网格、阶梯轮廓、有限材质色阶、禁止平滑动漫线稿/笔刷/文字/水印；成年阿鱼黑长发刘海白T黑裤黑白鞋，Toretto黑短发细黑眼镜白T黑裤黑白鞋，不扶眼镜。

1. 群聊：rear three-quarter over-the-shoulder view；阿鱼窗边咖啡椅坐姿、身体左下、手持物理大小iPhone在中右，屏幕正对相机留白且有DynamicIsland；窗外上海滨江。首轮不够高，内置编辑扩为9:20，保留手和手机位置。
2. 双人通话：two horizontal locations；上半阿鱼卧室床边接电话、旁边猫；下半Toretto自己的客厅沙发接电话；各头顶安静墙面留给运行时对白，不烘焙文字，不重复人物。
3. Offer：阿鱼一个人、白天卧室书桌、侧后方坐电脑前，完整房间可见，屏幕空白。首轮误加Toretto，已用内置编辑完全移除，不使用首轮；扩为9:20。
4. 日常：two adults walking side by side on an urban riverside promenade at dusk；人物脚点自然、眼神交流、远处路人、树木灯光河面，留顶部旁白位置，不生成气泡或心形装饰。
5. 乌龟船：elevated external observer view；functional turtle-shaped passenger ferry, hexagon shell roof and turtle head bow；visible open cabin doorway，broad gangway with handrails continuous to foreground pier；近景无主角、远处有旅客；日本海湾和山岛酒店。不要把船画成活乌龟。
6. 成都变体：精确保留群聊室内/人物/手/屏幕位置，仅窗外改成都绿树、民居屋顶、远山；无东方明珠、上海塔或游轮。

D2看首轮后要求再次统一颗粒：`group_shoulder`、`group_chengdu`、`offer_room`采用`desk_r4/writing.png`为风格参考做一次内置编辑；提示“Image1 is edit target, Image2 STYLE REFERENCE ONLY; exact841x1870 canvas and scene geometry unchanged; hard square clusters on coherent360x800 logical grid, remove paper noise/grain, contiguous flat pixel color shapes”。已覆盖工作区的这三张候选；最终预览已查看，屏幕位置保留。

原始生成文件保留于`/Users/kayra_ayu/.codex/generated_images/01a1b5eb-adf4-7593-b493-d083cf39c1c1/`，没有清理。工作区`art_manifest.json`包含全部最终图的尺寸/字节/SHA256。

未自判D4通过，未宣称真机/交互通过。
