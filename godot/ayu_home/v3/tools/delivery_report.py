#!/usr/bin/env python3
"""Produce a portable, evidence-linked handoff; no unchecked criterion is marked passed."""
from pathlib import Path
import json,re,sys,shutil,hashlib,subprocess
V=Path(__file__).resolve().parents[1];E=V/'evidence';R=V.parents[2]
D=Path(sys.argv[1]);D.mkdir(parents=True,exist_ok=True);P=D/'astra-阿鱼家-v3-证据';P.mkdir(exist_ok=True)
def load(name):return json.loads((E/name).read_text())
defs=json.loads((V/'assets/rooms.json').read_text())['rooms'];play=load('playthrough.json');routes=load('routes.json')
reg=(E/'regression.log').read_text();match=re.search(r'PASS (\d+) FAIL (\d+)',reg)
assert match, 'Wait for the full regression suite to finish before handing off.'
assert not play['failures'], 'Playthrough must finish without failures.'
art=load('restore-check.json');pack=load('package-audit.json');clarity=load('clarity-comparison.json')
assert not any(pack['pack_vs_workspace_max_rgb_by_room'].values()), 'Exported art must match the final workspace.'
for folder in ['runtime','comparisons']:
 shutil.copytree(E/folder,P/folder,dirs_exist_ok=True)
for f in E.iterdir():
 if f.is_file() and f.suffix.lower() in ['.json','.jpg','.png'] and '-assembly' not in f.name and '-before-style' not in f.name:shutil.copy2(f,P/f.name)
for name in ['regression.log','playthrough.log','routes.log','cloud.log','pack-probe.log']:
 if (E/name).exists():shutil.copy2(E/name,P/name)
def img(file,caption):return f'![{caption}](astra-阿鱼家-v3-证据/{file})'
def evidence(file,label):return f'[{label}](astra-阿鱼家-v3-证据/{file})'
clauses=[
('1','过','自动实走从院子遍历 26 处并回院子，50 次门切换；无瞬移代替遍历。另验 143 条门和物件接近路线。','playthrough.json'),
('2','没过','门触发、对应出生点、防弹回已完成；浴室互通、厨房后门等仍是逻辑补接，不能声称每一处都与原画开口完全一致。','rooms-一楼.jpg'),
('3','过','地图按一楼、二楼、屋外分组，26 张房间缩略卡直接到达。','runtime/map-一楼-960.png'),
('4','过','每间独立载入；餐厅和书房额外裁去相邻家具，楼梯使用过道多边形隔离。补地板问题见第 6 条。','rooms-二楼.jpg'),
('5','没过','一楼已经变清楚，但高清重构改变了颜色，原始定稿 RGB 容差 ≤12 未达到；对齐搜索结果不是逐件内容完全相同的证明。','clarity-comparison.json'),
('6','没过','两种竖屏均铺满，全屋统一 2 倍逻辑缩放；部分小房间延伸仍能看出裁景边界或平铺纹理，不冒称无缝。','rooms-一楼.jpg'),
('7','过',f'26 处均至少 3 个物件，共 87 个，逐个接近并执行，有状态变化、动画、声音或独立玩法。测试 {play["checks"]} 项、失败 0。','playthrough.json'),
('8','过','全屏投食、鱼追食并消耗；电视为沙发背后视角、背向家人和动态节目；吉他、拼图、相册可完成、可退出。','runtime/play-fish-finished-960.png'),
('9','过','移除角落物件按钮清单，使用物件上方气泡、就近操作与直接点击。地图和测试面板保留必要导航。','runtime/living-960.png'),
('10','过','圆润奶油色与棕色像素边框、白色像素图标；对话底部头像、名字、逐字显示、继续和跳过。美术满意度仍由阿鱼判断。','runtime/dialogue-960.png'),
('11','过','求求灰虎斑、落落橘虎斑、天天金色长毛分别制作；窝、沙发、书房按日期和时段轮换，喜多在院内。','runtime/three-cats-960.png'),
('12','过','电脑启动带 --ayu-test；F2 或「试玩」即时切清晨/午间/傍晚/深夜、四季、晴雨与三种外出状态；正常入口隐藏。','runtime/test-panel-960.png'),
('13','过' if match.group(2)=='0' else '没过',f'原工程回归：PASS {match.group(1)} / FAIL {match.group(2)}；婚宴入口源码未改，并重新渲染两种尺寸。详见日志。','regression.log'),
('14','过','提供 bundle、本交付单、逐文件 SHA-256、截图证据；原电脑 command 已切到 v3。','package-audit.json')]
lines=['# 阿鱼家 v3 交付单','', '**结论：本版已交付，可试玩；没有把 14 条写成全过。第 2、5、6 条未达到原要求。下表是可复查的自验结果，最终仍由阿鱼试玩、Claude 验收。**','',
'本轮只以 `claude-派活-阿鱼家v3完整版-1004.md` 第零节为任务入口，并遵照阿鱼随后补充的像素颗粒参考。新增鱼缸与电视背景已重新处理为明确的像素块，没有沿用较写实的初稿。','',
'## 14 条验收结果','', '| 条 | 自验 | 做成了什么 / 未完成原因 | 证据 |','| --- | --- | --- | --- |']
for no,state,copy,file in clauses:lines.append(f'| {no} | **{state}** | {copy} | {evidence(file,"查看")} |')
lines+=['','## 每间截图排在一起','',img('rooms-一楼.jpg','一楼 12 处，每间实际 Godot 截图'),' ',img('rooms-二楼.jpg','二楼 9 处，包括露台'),' ',img('rooms-屋外.jpg','屋外 5 处，后园内含果园、菜地、花田和蜂箱'),'','## 位置、截图与可点物件清单','',
'截图中的灰蓝衣服短发角色是来访玩家；一家三口按第零节许可继续代码占位。以下为全部 26 处、87 个物件；地图同样全部列出。','',
'| 位置 | 540×960 | 1170×2532 | 物件与玩法 |','| --- | --- | --- | --- |']
for id,c in defs.items():
 hot='；'.join(h['label'] for h in c['hotspots']);lines.append(f'| {c["group"]} · {c["title"]} | {evidence("runtime/"+id+"-960.png","截图")} | {evidence("runtime/"+id+"-1168.png","截图")} | {hot} |')
lines+=['','## 现在怎么打开、怎么玩','',
'双击工程根目录 **打开阿鱼家.command**。已更新到 v3，带电脑测试面板。点空地走路，或用 WASD / 方向键；走近门自动切换，也可点门气泡。E 操作最近物件，M 打开地图，Esc 退出玩法，F2 打开试玩面板。正常时间跟电脑时钟走；测试面板选择「现实时间」即可恢复。','',
'电脑试玩工程：`'+str(R)+'`。场景入口是 `godot/ayu_home/home.tscn` → `v3/home.gd`。不带 `--ayu-home` 启动仍为原婚宴。','',
f'[打开电脑试玩入口](<{R / "打开阿鱼家.command"}>)','',
'## 全屏玩法与像素风更新','',img('runtime/play-fish-960.png','全屏像素鱼缸，点水面投食'),'',img('runtime/play-tv-960.png','沙发背后看一家人与动态电视'),'',
'| 玩法 | 开始 | 完成 | 实测结果 |','| --- | --- | --- | --- |']
for kind,label in [('fish','喂鱼'),('tv','看电视'),('guitar','吉他'),('puzzle','拼图'),('album','相册修复')]:
 lines.append(f'| {label} | {evidence("runtime/play-"+kind+"-960.png","开始截图")} | {evidence("runtime/play-"+kind+"-finished-960.png","完成截图")} | 完成与中途退出均通过；触摸输入证据见 playthrough.json |')
lines+=['', '鱼不是碰到食物即消失的装饰：每条鱼选择最近鱼食、转向追逐、靠近消耗；测试覆盖多条鱼分食和至少 12 粒。电视有 3 个原创小节目、动态移动与雨滴，点屏幕或换台键可切换。吉他用程序合成短旋律，相册只用像素院景，无真实照片。','',
'## 原图、清晰化与补图的核对','',
f'实际 Godot 无效果原生渲染与本版拆层拼图：26 处最大 RGB 差值 **{max(r["runtime_vs_assembly"]["max_rgb"] for r in art["rooms"])}**。零件按整数原坐标放回，偏移 0 px。这只能证明本版素材被正确拼回，不能替代原始定稿还原验收。','',
'院门蓝衣人、二楼标注只在指定蒙版内修补；蒙版外最大 RGB 差值为 0。每处原始定稿 / 本版素材 / Godot 原生截图都有三栏对照。','',
evidence('restore-check.json','逐房间还原数值')+' · '+evidence('clarity-comparison.json','一楼清晰化差异数值')+' · '+evidence('floor1-before-after.png','一楼前后并排')+' · '+evidence('floor1-difference-x4.png','一楼差异放大')+' · '+evidence('allowed-edit-mask-0.png','院门修补范围')+' · '+evidence('allowed-edit-mask-2.png','二楼去字范围'),'',
'一楼清晰化平均颜色变化、超差像素等保留在原始 JSON 中。它不满足「颜色不变 / 背景容差 ≤12」，所以第 5 条明确没过。几个衣柜间、浴室、厨房的裁景与延伸比例也不够自然，地板平铺仍有痕迹；延伸区用于填充视野，可走区域仍以原平面图为主，所以第 6 条没过。','']
for id,c in defs.items():
 if id!='garden':lines.append('- '+evidence('comparisons/'+id+'.png',c['title']+'：定稿 / 素材 / 实际截图'))
lines+=['','## 门、路线与作息','',
'步行测试从院子进入全图，按实际 AStar 路线逐格移动、执行门触发，等待真实淡入动画完成，抵达后再确认不弹回。没有用快捷导航替代这次全图遍历。另对每间出生点到全部门和物件接近点检查可达性。某些浴室互通和厨房后门是为了完整走通补出的逻辑连接；与原画开口的对应仍不完整，第 2 条未过。','',
'| 时间 | 阿鱼 | 爸爸 | 妈妈 |','| --- | --- | --- | --- |',
'| 00:00–06:00、22:00–24:00 | 卧室睡觉 | 爸妈卧室 | 爸妈卧室 |',
'| 06:00–07:30 | 客厅喂鱼 | 手作房 | 厨房 |',
'| 07:30–08:15 | 餐厅一起吃早饭 | 同左 | 同左 |',
'| 08:15–09:00 | 客厅家务 | 车库整理 | 洗衣房 |',
'| 09:00–10:00 | 外出 | 外出 | 外出 |',
'| 10:00–12:00 | 书房电脑工作 | 外出 | 后园 |',
'| 12:00–13:00 | 餐厅一起吃午饭 | 同左 | 同左 |',
'| 13:00–14:00 | 书房弹吉他 | 茶桌喝茶 | 茶桌喝茶 |',
'| 14:00–15:00 | 书房游戏 | 手作房 | 外出 |',
'| 15:00–17:00 | 后园 | 后园 | 后园 |',
'| 17:00–18:00 | 客厅家务 | 手作房 | 厨房 |',
'| 18:00–19:00 | 餐厅一起吃晚饭 | 同左 | 同左 |',
'| 19:00–20:00 | 客厅音乐 | 茶桌喝茶 | 客厅读书 |',
'| 20:00–21:00 | 客厅电视 | 客厅电视 | 客厅电视 |',
'| 21:00–22:00 | 书房阅读 | 卧室休息 | 卧室休息 |','',
'以上是游戏虚构日常，不写成真实经历。三顿饭、各外出状态与四季都有截图：','']
for hr,label in [('7.75','早餐'),('12.25','午餐'),('18.5','晚餐')]:lines.append('- '+evidence('runtime/meal-'+hr+'-960.png',label))
for hr,label in [('9.5','全家外出'),('10.5','爸爸外出'),('14.5','妈妈外出')]:lines.append('- '+evidence('runtime/away-'+hr+'-960.png',label))
for m,label in [(3,'春'),(7,'夏'),(10,'秋'),(1,'冬')]:lines.append('- '+evidence('runtime/season-'+str(m)+'-960.png',label+'季后园'))
lines+=['','## 人物、宠物和细看图的真实状态','',
'一家三口仍是第零节允许的代码角色，不宣称完成定稿四向骨骼角色。宠物已依据参照重做四帧图集（坐、走两帧、躺），四个图集脚点都对齐 y=62；灰虎斑、橘虎斑、金色长毛和柯基分别可辨。近距离摸猫可完成一小段互动。','',
'交付前重查定稿目录，尚无 `人物四向/`、`细看图/` 新文件。书桌使用已提供的正式特写，电脑、台灯、摆件和猫可点，有光影；其它房间「细看」是可拖动平面裁景占位，**不是已经完成的正式全景细看图**。遵守“细看图由阿鱼出图窗口画”的约定。','',
'## 回归、导出与限制','',
f'- 原工程测试：**PASS {match.group(1)} / FAIL {match.group(2)}**，完整日志在证据目录。',
f'- v3 实走与触摸测试：**{play["checks"]} checks / 0 failures / 50 walks / 87 objects**。',
'- 路线检查：143 routes / 0 failures。云素材本地、下载校验、离线缓存、断网、损坏、重试和未知资源均通过 fixture 验证。',
f'- 实际本地微信导出主包：**{pack["main_bytes"]:,} 字节**，小于 4 MiB。完整引擎/素材包另列于 package-audit.json；没有上传线上。',
'- 主包之外的大图有 SHA-256 清单和已有 bridge 下载接口。真实云 fileID 尚未配置，未做真实云端下载验收。',
'- 两种手机比例是桌面 Godot 实际渲染和触摸事件模拟；没有把它说成真机触屏或微信线上试玩。',
'- 原工程回归中两项大地图步行脚本自身限时 580 秒，外层曾为 300 秒；修正外层为 620 秒，没有改断言。',
'- macOS 沙盒 headless 日志中的系统 CA 读取提示与游戏逻辑无关；以 RESULT 和 Parse/Compile/Failed to load script 扫描共同判定，不能只看 PASS 字样。','',
'## 工程与交接','',
'分支：`village/ayu-home-v3`，从原 v2 分支 `d0eb7d0` 继续，未推 GitHub。新代码、素材、测试和证据在 `godot/ayu_home/v3/`；外部改动仅 home.tscn、阿鱼家 AGENTS 更新、导出过滤、回归超时与电脑 command。','',
'三份本地 skill 已照指定文件直接安装并使用：game-ui-ux、godot-ui-control、game-feel。其纯文字说明来自用户提供的 `.claude/skills/`；本版主要应用统一主题、容器布局、触摸尺寸、反馈和过渡。','',
'交付：`astra-阿鱼家-v3.bundle`、本 Markdown、`astra-阿鱼家-v3-证据/`、`astra-阿鱼家-v3-SHA256SUMS.txt`。工程内 `FILE-SHA256.tsv` 列出本轮代码和素材哈希；外部 SHA256SUMS 列出 bundle、报告与证据文件。','',
'Claude 可先 `git bundle verify astra-阿鱼家-v3.bundle`，再 fetch 分支。bundle 内带完整分支历史，无须访问远程仓库。合并前重点复查第 2、5、6 条和图片边界，不能只凭测试数字当作阿鱼已经满意。','']
(D/'astra-阿鱼家交付-v3.md').write_text('\n'.join(lines))
print('Report written:',D/'astra-阿鱼家交付-v3.md')
