# 阿鱼家完整生活实施约定
2026-10-04 用户最新直接指示最高优先。完整交付，不再交灰盒；GPT 全做全验。基线 deca36c2ae7a5434cbfa13c398e1990e47edf9d9；本副本无 remote，不改 Claude 原仓库。

美术参考目录：/Users/kayra_ayu/Desktop/苏七镇奇缘/七缘地图2-裳泓村/定稿形象图/。三张建筑图锁布局和暖色像素风。阿鱼约14岁，长黑发白T黑裤球鞋红绳；父亲蓝POLO深裤；母亲棕发髻粉开衫藏青裙。三猫求求灰虎斑、落落橘虎斑、天天金长毛；柯基喜多住院外，允许出现。麻将人物有摸牌出牌聊天动作，不做玩家麻将规则。父母家务、饭点、四季作物自行创作，不当真人史实。

交付场景 res://ayu_home/home.tscn；隔离开发入口 --ayu-home，不改默认婚宴流。真实时间+内部可控测试时钟。三顿饭齐聚、存在都不在/仅父亲外出/仅母亲外出的时段。访客敲门有人应、无人留言返回；主人可入。访客不能因无人永久失去玩法，提供明确来访时间。所有楼层/院落可走，每物件大点击区，楼梯双向、退出安全。核心小游戏吉他、书架拼图、相册修复；客房可躺起，喂鱼电视唱片机工具台可玩。按参考图布局，供用户闲居。

分工：runtime agent拥有 home.gd/home.tscn/world.gd/home_data.gd/测试和 main.gd 唯一入口改动。activities agent拥有 actor.gd/activities.gd/activities 测试。root拥有 assets、集成修复、最终报告与bundle。不要改另一人文件，不提交；完成回报路径。

API：actor.gd extends Node2D，以脚点为position，setup(id:String)，set_activity(action:String)，set_direction(dir:String)，set_walking(on:bool)。id ayu/father/mother/qiuqiu/luoluo/tiantian/xiduo，方向 down/left/right/up。世界1024×768；人物84px，猫30左右狗40。支持actorsheet assets/{ayu,father,mother}_walk.png，均3列4行，行顺序down,left,right,up，列步行左/站/右；alpha真实透明，成品图已全部到位。宠物assets/pets.png：3列4行，行灰猫/橘猫/金猫/柯基，列left/down/right。各帧居中脚点靠底，按实际alpha bounds确定裁图更稳。图到后不能继续用占位。

activities.gd extends CanvasLayer，signal closed，signal completed(kind:String)，open(kind:String, context:Dictionary={})，close()。kind guitar/puzzle/album/relax/fish/tv/record/workbench/garden。不动钱包，持久进度由home控制；儿童友善无真实相册照片。puzzle/album使用本模块已生成的背景图局部纹理或原创图。不用下载版权音乐，吉他声音程序合成自己旋律。面板540x960与1170x2532可读可按。

已交付背景文件：assets/exterior.png, floor1.png, floor2.png, garden.png（无文字无人物宠物，尽量保持参考布局）。使用normalized几何以适应贴图尺寸，动画与物件由运行层叠加。运行角色绕桌/门/墙须符合占地；背景不是唯一走动地面mask。请看原参考定义正确room/door连通。支持脚点排序和前景家具遮挡。角色不会穿墙或直接楼层瞬移可见。

所有新素材独立目录，后续manifest大小hash可远程替换；不把真实照片放包。独立本地生活存档，不写旧coins，床不跳时间或发钱。测试时钟/主人模拟仅开发入口可用。截屏带commit/时刻标记但生产UI不露debug。最终跑全项目run_tests.sh和专项测试+真实渲染手机截图，未测不得报过。
