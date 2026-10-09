#!/usr/bin/env python3
"""屋外的门和路（Claude 10/5 第五轮，阿鱼按门序号说的）。可以反复跑。
- 拿掉院子 16 号门（沿侧门去后园）：阿鱼「不可以出去，要去菜园需要从 20 走出去然后绕着左边的路走过去」
- 院外小道往左走到头（画上那条土路本来就一直通到左边）进后园；后园原来的「回院子」（24 号）改成通院外小道，
  放在后园底下那条土路的左头，走回去落在小道左头。23 号回猫窝走道照旧，23、24 不再挨着
- 院子 18 号「进车库」挪到画上的卷帘门那里：气泡在卷帘门上，站位在车尾和卷帘门右边那一小块空地
"""
from pathlib import Path
import json
A=Path(__file__).resolve().parents[1]/'assets'
def door(id,target,pos,approach,face,label):
	return dict(id=id,target=target,pos=pos,approach=approach,face=face,label=label,kind='door',width=34,explicit_opening=True)
def fix(rid,c):
	if rid=='exterior':
		# 第六轮第 8 条（阿鱼）：车默认停在车库里，院子里不画车（车那层和它的挡路框都拿掉），进车库的站位挪到卷帘门正前面
		c['props']=[p for p in c['props'] if not str(p['file']).endswith('exterior_car.png')]
		c['obstacles']=[b for b in c['obstacles'] if b!=[246,575,253,102]]
		# 第六轮第 10 条：棚子底下走不进去（原来人走进去被整个棚子盖住、看不见）
		if [985,588,122,42] not in c['obstacles']:c['obstacles'].append([985,588,122,42])
		c['doors']=[d for d in c['doors'] if d['target']!='garden']
		for d in c['doors']:
			if d['id']=='to_workshop':d['span']=[40] # 院子当中的门：门有多宽写明。车停在手作房门前，门从车头左边那块空地进
			if d['id']=='to_living':d['span']=[783,647,96]
			if d['id']=='to_garage':d['pos']=[440,528];d['approach']=[440,612];d['face']='down'
		for h in c['hotspots']:
			if h['id']=='bench':h['pos']=[838,622];h['seat']=[780,615];h['face']='down' # 台阶「坐一会儿」的气泡挪到台阶右头，不盖住往门走的台阶
	if rid=='side_path':
		c['doors']=[d for d in c['doors'] if d['target']!='garden']
		c['doors'].append(door('to_garden','garden',[46,988],[72,988],'right','沿小路去后园'))
		c['walk_rect']=[40,928,1376,102]
	if rid=='garden':
		c['doors']=[d for d in c['doors'] if d['target'] not in ('exterior','side_path')]
		c['doors'].append(door('to_side_path','side_path',[46,1000],[74,1000],'right','沿小路回院外小道'))
		poly=c['walk_polygons'][0]
		c['walk_polygons'][0]=[[40,1030] if p==[64,1030] else ([40,970] if p==[64,947] else p) for p in poly]
		if [64,947] in poly:pass
	return c
allr=json.loads((A/'rooms.json').read_text())
for rid in ['exterior','side_path','garden']:
	c=fix(rid,json.loads((A/(rid+'.json')).read_text()));(A/(rid+'.json')).write_text(json.dumps(c,ensure_ascii=False,indent=2)+'\n')
	allr['rooms'][rid]=fix(rid,allr['rooms'][rid])
# 第六轮第 24 条：屋外门洞不自己往两边找，要宽的门写明宽度（院门、小道回院门、后园回猫窝走道）
SPAN={'exterior':{'to_side_path':[180]},'side_path':{'to_exterior':[150]},'garden':{'to_cats':[100]}}
for rid,m in SPAN.items():
	for cc in [allr['rooms'][rid]]:
		for d in cc['doors']:
			if d['id'] in m:d['span']=m[d['id']]
(A/'rooms.json').write_text(json.dumps(allr,ensure_ascii=False,indent=2)+'\n')
for rid in ['exterior','side_path','garden']:print(rid,[(d['id'],d['approach']) for d in allr['rooms'][rid]['doors']])
