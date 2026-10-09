#!/usr/bin/env python3
"""一楼挡路框对齐画上的家具（Claude 10/5，阿鱼细节第 5 节「看着能走却不能走」）。

astra 一楼重画版里有几处挡路框比家具大一圈，把画上明明是空地的地方也挡住了：
- 餐厅：圆桌一个大框把整块地毯都挡了 → 换成桌面 + 四边椅子
- 茶桌与麻将室：同上
- 卫生间与洗衣：洗手台的框连旁边的白瓷砖空地也挡了 → 只挡洗手台
- 爸妈卧室浴室：洗手台框伸到了地砖上，可走区又从地砖下面才开始 → 只挡台面，地砖能走
改完重新烘焙一楼导航：Godot --headless --path godot --script res://ayu_home/v4/tools/bake_navigation.gd -- --floor1
"""
from pathlib import Path
import json
A=Path(__file__).resolve().parents[1]/'assets'
FIX={
 'dining':{'replace':{(83,129,190,171):[(122,160,120,112),(160,128,44,32),(160,270,44,32),(90,164,40,112),(234,164,40,112)]}},
 'mahjong':{'replace':{(93,90,157,174):[(120,118,90,90),(143,86,44,32),(143,205,44,48),(88,138,34,44),(208,138,36,44)]}},
 'laundry':{'replace':{(67,80,97,65):[(128,80,37,65)]}},
 'bath1':{'replace':{(73,68,98,75):[(73,68,98,34)]},'polygons':[[[89,104],[179,104],[179,189],[89,189]],[[103,184],[153,184],[153,211],[103,211]]]},
}
def apply(c,fix):
	obs=[]
	for b in c['obstacles']:obs+= [list(x) for x in fix.get('replace',{}).get(tuple(b),[b])]
	for b in fix.get('add',[]):
		if list(b) not in obs:obs.append(list(b))
	c['obstacles']=obs
	if 'polygons' in fix:c['walk_polygons']=fix['polygons']
# 第三轮：体验师查出 5 处小家具能踩上去，补挡路框（爸妈卧室上方小柜、右侧小桌、右下盆栽；麻将室右下盆栽；手作房左小柜）
EXTRA={'parents':[(92,62,38,38),(278,150,30,42),(306,250,32,42)],'mahjong':[(256,270,34,38)],'workshop':[(95,222,34,42)]}
for rid,boxes in EXTRA.items():
	FIX.setdefault(rid,{}).setdefault('add',boxes)
allr=json.loads((A/'rooms.json').read_text())
for rid,fix in FIX.items():
	c=json.loads((A/(rid+'.json')).read_text());apply(c,fix);(A/(rid+'.json')).write_text(json.dumps(c,ensure_ascii=False,indent=2)+'\n')
	apply(allr['rooms'][rid],fix);print(rid,c['obstacles'])
# 爸妈的床在新图里床头朝下（枕头在下半截），躺下时头朝下
for c in [allr['rooms']['parents']]:
	for h in c['hotspots']:
		if h['id']=='bed':h['head_dir']='down'
# 手作房左小柜补了挡路框，小灯的站位挪到柜子前面
for c in [allr['rooms']['workshop']]:
	for h in c['hotspots']:
		if h['id']=='lamp':h['approach']=[116,272]
wc=json.loads((A/'workshop.json').read_text())
for h in wc['hotspots']:
	if h['id']=='lamp':h['approach']=[116,272]
# 第五轮：玩家坐凳子时爸爸不挤在旁边，爸爸干活的站位挪到工作台左下
wc['anchors']['father']=[176,330];allr['rooms']['workshop']['anchors']['father']=[176,330]
# 第六轮第 18 条：楼梯左边的木扶手是靠墙立着的一条，人只会在它右边走，排在所有人后面，人不再被扶手盖住
sc=json.loads((A/'stairs1.json').read_text())
for c in [sc,allr['rooms']['stairs1']]:
	for p in c['props']:
		if str(p['file']).endswith('stairs1-rail.png'):p['foot']=64
(A/'stairs1.json').write_text(json.dumps(sc,ensure_ascii=False,indent=2)+'\n')
(A/'workshop.json').write_text(json.dumps(wc,ensure_ascii=False,indent=2)+'\n')
(A/'rooms.json').write_text(json.dumps(allr,ensure_ascii=False,indent=2)+'\n')
