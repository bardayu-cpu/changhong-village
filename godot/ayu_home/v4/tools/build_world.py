#!/usr/bin/env python3
"""v4 navigation, interactions and exact source extraction. Never writes approved artwork."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageChops
import json, copy, hashlib
V=Path(__file__).resolve().parents[1]; A=V/'assets'; E=V/'evidence'
OLD=V.parent/'v3/assets'; ROOT=V.parents[3]
REF=ROOT/'七缘地图2-裳泓村参考图/定稿形象图'
rooms=json.loads((OLD/'rooms.json').read_text())['rooms']
sources={1:Image.open(REF/'5-阿鱼家一楼平面图 2.png').convert('RGBA'),2:Image.open(OLD/'approved-2.png').convert('RGBA'),0:Image.open(OLD/'approved-0.png').convert('RGBA')}
def pt(id,p):
 c=rooms[id];o=c.get('source_offset',[0,0]);r=c.get('source_crop',[0,0]);return [p[0]-r[0]+o[0],p[1]-r[1]+o[1]]
def rect(id,b):return pt(id,b[:2])+list(b[2:])
def hot(room,id,label,pos,approach,kind='reaction',effect='',copy=''):
 h=dict(id=id,label=label,pos=pt(room,pos),approach=pt(room,approach),kind=kind,effect=effect,copy=copy)
 for i,old in enumerate(rooms[room]['hotspots']):
  if old['id']==id:rooms[room]['hotspots'][i]=h;return
 rooms[room]['hotspots'].append(h)
def door(room,target,pos,face):
 d=next(d for d in rooms[room]['doors'] if d['target']==target)
 d['pos']=pt(room,pos);d['approach']=pt(room,pos);d['face']=face
def obstacle(room,*boxes):rooms[room]['obstacles']=[rect(room,b) for b in boxes]
def walk(room,r):rooms[room]['walk_rect']=rect(room,r)
def polygon(room,points):rooms[room]['walk_polygons']=[[pt(room,p) for p in points]]

# The first-floor palette is exactly the approved image again. The runtime sharpener
# is separately bounded at 12/255, so it cannot silently substitute a recoloured redraw.
for id,c in rooms.items():
 c['asset_root']='res://ayu_home/v3/assets/'
 if c['floor']!=1:continue
 src=sources[1];crop=c['source_crop'];off=c['source_offset']
 bg=Image.open(OLD/c['background']).convert('RGBA')
 mask=Image.new('L',bg.size,0);draw=ImageDraw.Draw(mask)
 if c.get('source_polygon'):draw.polygon([tuple(pt(id,p)) for p in c['source_polygon']],fill=255)
 else:draw.rectangle((off[0],off[1],off[0]+crop[2]-crop[0]-1,off[1]+crop[3]-crop[1]-1),fill=255)
 layer=Image.new('RGBA',bg.size);layer.paste(src.crop(crop),off)
 bg.paste(layer,(0,0),mask);bg.save(A/c['background'],optimize=True)
 c['background']='res://ayu_home/v4/assets/'+c['background']
 for p in c['props']:
  old=Image.open(OLD/p['file']).convert('RGBA');x=crop[0]+p['pos'][0]-off[0];y=crop[1]+p['pos'][1]-off[1]
  art=src.crop((x,y,x+old.width,y+old.height));art.putalpha(old.getchannel('A'));art.save(A/p['file'],optimize=True)
  p['file']='res://ayu_home/v4/assets/'+p['file']
  if 'off_file' in p:p.pop('off_file')
 c['approved_mask']='res://ayu_home/v4/assets/'+id+'_approved_mask.png';mask.save(A/(id+'_approved_mask.png'))

# Full furniture footprints, including high/rear parts: one shared grid for everyone.
obstacle('living',(608,413,229,68),(602,446,63,158),(690,488,102,98),(974,478,53,166),(616,655,57,34),(574,385,38,63),(974,391,52,70))
walk('living',(570,395,452,291))
obstacle('dining',(469,142,158,149),(469,70,148,61),(628,57,45,88))
walk('dining',(419,132,260,204))
obstacle('kitchen',(140,35,227,117))
obstacle('laundry',(140,212,73,117),(218,224,45,59),(295,224,60,63),(195,309,24,22))
obstacle('cats',(723,158,53,85),(777,151,62,90),(800,242,31,40),(747,269,45,21))
walk('cats',(721,241,124,66))
obstacle('mahjong',(1140,148,146,103),(1118,161,31,86),(1283,156,33,87),(1160,250,62,29),(1313,68,59,89))
walk('mahjong',(1074,117,294,181))
obstacle('parents',(1130,473,137,154),(1268,473,43,62),(1333,475,58,180),(1074,615,43,47))
obstacle('workshop',(79,374,99,194),(186,402,31,158),(94,648,27,37))
obstacle('garage',(321,418,159,270),(265,386,50,204),(267,530,49,104),(491,398,36,103),(495,650,21,35))
walk('garage',(264,387,260,318))
obstacle('closet1',(1136,317,77,68))
obstacle('bath1',(1233,318,76,60),(1314,312,78,71),(1362,380,31,25))
obstacle('guest',(322,153,179,217),(286,154,40,74),(485,153,46,73),(547,230,64,72),(564,301,47,64),(238,128,55,83),(557,116,60,114))
obstacle('guest_closet',(63,115,116,88),(78,230,45,49),(160,242,30,35))
obstacle('guest_bath',(61,323,59,91),(119,337,42,68),(171,342,62,60),(55,401,40,60))
obstacle('study',(1019,145,213,122),(960,118,54,128),(1265,237,53,74),(1311,267,49,57),(1283,123,52,102))
obstacle('closet2',(1030,380,119,80),(1101,471,51,29))
obstacle('bath2',(1179,383,45,97),(1240,397,40,55),(1271,381,102,102))
obstacle('ayu_room',(1050,587,192,231),(1299,573,71,173),(1233,568,56,67),(1032,569,45,67),(980,665,54,124),(985,804,51,57),(1310,754,67,75))
obstacle('terrace',(232,714,179,88),(324,771,124,105),(396,701,54,51),(409,880,154,45),(47,522,226,118),(53,642,134,256),(708,535,62,52),(848,838,78,84))
obstacle('stairs1',(1018,42,24,258),(1018,337,36,64))
walk('stairs1',(878,78,250,401))
polygon('stairs1',[(881,78),(1016,78),(1016,308),(1058,308),(1058,304),(1112,304),(1112,385),(1130,385),(1130,425),(1116,425),(1116,472),(1065,472),(1065,381),(955,381),(955,335),(881,335)])
obstacle('stairs2',(770,114,43,208),(738,353,39,80),(641,462,180,56),(806,270,35,59))
walk('stairs2',(659,171,357,346))
polygon('stairs2',[(668,171),(907,171),(907,393),(966,393),(966,375),(1016,375),(1016,510),(825,510),(825,460),(661,451)])

# Set thresholds on painted openings/boundary exits, never the middle of a path.
door('living','dining',(646,399),'down');door('living','stairs1',(951,417),'down')
door('living','exterior',(903,673),'up')
door('kitchen','garden',(147,175),'right')
door('kitchen','dining',(390,173),'left')
door('dining','kitchen',(422,174),'right');door('dining','laundry',(422,279),'right')
door('laundry','dining',(376,301),'left')
door('closet1','stairs1',(1132,401),'right');door('closet1','bath1',(1205,403),'left')
door('bath1','closet1',(1234,402),'right')
door('guest_closet','guest',(207,266),'left');door('guest_bath','guest',(225,432),'left')
door('closet2','stairs2',(1038,489),'right');door('closet2','bath2',(1150,490),'left');door('bath2','closet2',(1189,490),'right')
door('stairs1','mahjong',(1091,307),'down');door('stairs2','study',(995,386),'down')
door('stairs1','stairs2',(899,95),'down');door('stairs2','stairs1',(686,180),'down')
rooms['stairs1']['stair_path']=[pt('stairs1',p) for p in [(960,276),(960,256),(960,236),(960,216),(960,196),(960,176),(947,154),(930,136),(913,116),(899,95)]]
rooms['stairs2']['stair_path']=[pt('stairs2',p) for p in [(690,300),(690,280),(690,260),(690,240),(690,220),(686,200),(686,180)]]
obstacle('exterior',(246,575,253,102),(1090,518,80,121),(99,687,513,244),(863,688,305,252),(501,572,38,36),(668,573,32,41),(863,566,39,47),(933,575,38,41))
polygon('exterior',[(124,599),(1180,599),(1179,681),(870,784),(842,925),(835,1017),(655,1017),(650,929),(612,786),(132,682)])
door('exterior','side_path',(742,1004),'up');door('side_path','exterior',(742,938),'down')
door('exterior','garage',(543,606),'down')
# Outdoor source-space is now a full painting at the courtyard scale, not a strip magnified 3.24x.
for id in ['side_path','bridge','oldhouse']:
 c=rooms[id];ox,oy=c['source_crop'][:2]
 for item in c['hotspots']+c['doors']:
  for key in ['pos','approach']:item[key]=[item[key][0]+ox,item[key][1]+oy]
 c['walk_rect'][:2]=[c['walk_rect'][0]+ox,c['walk_rect'][1]+oy]
 c['spawn']=[c['spawn'][0]+ox,c['spawn'][1]+oy]
 c['walk_polygons']=[[[p[0]+ox,p[1]+oy] for p in poly] for poly in c['walk_polygons']]
 c.update(source_crop=[0,0,1448,1086],source_offset=[0,0],size=[1448,1086],background='approved-0.png')
walk('side_path',(65,928,1351,102));obstacle('side_path',(90,923,556,32),(846,923,352,32))
door('side_path','exterior',(742,933),'down');door('side_path','bridge',(1393,997),'left')
polygon('bridge',[(1253,535),(1323,535),(1323,582),(1444,582),(1444,647),(1320,647),(1274,583)])
walk('bridge',(1250,535,198,120));obstacle('bridge',(1307,535,119,40),(1344,650,98,142))
door('bridge','oldhouse',(1279,547),'down');door('bridge','side_path',(1431,619),'left')
door('oldhouse','bridge',(1398,460),'up');door('oldhouse','garden',(1379,348),'down')
obstacle('oldhouse',(1170,31,219,161),(1180,231,77,55),(1272,281,26,52),(1414,413,30,117))
walk('oldhouse',(1191,190,222,311))
polygon('oldhouse',[(1191,190),(1324,190),(1310,224),(1353,282),(1412,373),(1412,498),(1388,498),(1279,317),(1191,236)])
door('garden','kitchen',(698,1010),'up');door('garden','exterior',(755,1010),'up');door('garden','oldhouse',(1406,380),'left')
walk('garden',(57,108,1368,922))
polygon('garden',[(75,108),(576,108),(577,350),(1282,350),(1282,342),(1422,342),(1422,400),(1284,416),(1275,715),(789,746),(789,944),(1405,950),(1405,1030),(64,1030),(64,947),(650,936),(650,742),(65,743)])
obstacle('garden',(77,226,366,150),(75,414,368,144),(77,589,367,154),(84,65,260,77),(580,133,210,214),(827,132,177,214),(1107,131,185,213),(581,438,215,207),(827,438,181,205),(1108,439,185,205),(71,844,558,94),(814,841,488,107),(1050,754,324,153))

# Every announced verb now dispatches its own real scene action / gesture game.
patches={
'living':{'tv':('tv_scene','tv'),'sofa':('seat','sit'),'album':('album',''),'fish':('fish','')},
'dining':{'meal':('meal','eat'),'tea':('drink','drink'),'recipe':('recipe','book'),'flowers':('flowers','')},
'kitchen':{'stove':('soup',''),'sink':('tap','water'),'fridge':('pantry','open')},
'laundry':{'wash':('laundry',''),'basin':('tap','water'),'towel':('fold','fold')},
'cats':{'nest':('pet_scene','pet'),'scratch':('pet_play','pet'),'bowls':('pet_food','food')},
'mahjong':{'tea':('tea',''),'chair':('seat','sit'),'plant':('tend','water')},
'parents':{'bed':('bed','sleep'),'window':('window','window')},
'workshop':{'wood':('wood',''),'tools':('tidy','tools')},
'garage':{'car':('wipe','wipe'),'bike':('bell','bell'),'shelf':('tidy','tools')},
'closet1':{'hang':('fold','fold'),'tidy':('tidy','fold')},
'bath1':{'sink':('tap','water'),'shower':('shower','water'),'towel':('fold','fold')},
'guest':{'bed':('stay','sleep'),'book':('read','book')},
'guest_closet':{'coat':('fold','fold'),'bag':('tidy','open'),'basket':('tidy','fold')},
'guest_bath':{'water':('tap','water'),'shower':('shower','water'),'plant':('tend','water')},
'study':{'computer':('work','computer'),'chair':('read','book')},
'closet2':{'hanger':('fold','fold'),'clothes':('fold','fold')},
'bath2':{'basin':('tap','water'),'shower':('shower','water'),'mat':('fold','fold')},
'ayu_room':{'bunny':('bunny','pet'),'mirror':('mirror','mirror'),'window':('window','window')},
'terrace':{'tea':('tea',''),'stars':('stars',''),'flower':('tend','water'),'bench':('seat','sit')},
'exterior':{'xiduo':('pet_scene','pet'),'bench':('seat','sit'),'flowers':('tend','water')},
'side_path':{'leaf':('leaf','leaf'),'flower':('pick_flowers',''),'listen':('listen','water')},
'bridge':{'fish':('fishing',''),'water':('net',''),'rail':('seat','sit')},
'oldhouse':{'knock':('knock_old','bell'),'pot':('pick_flowers',''),'step':('seat','sit')},
'garden':{'vegetables':('garden',''),'flowers':('flower_garden',''),'fruit':('fruit',''),'pond':('net',''),'garden_play':('garden',''),'bees':('bees','bees')},
}
for id,c in rooms.items():
 for i,h in enumerate(c['hotspots']):
  if h['id'] in patches.get(id,{}):h['kind'],h['effect']=patches[id][h['id']]
  if h['kind']=='reaction' and h.get('effect')=='water':h['kind']='tend'
  # Individual lines stay attached to their actual object.
  h['copy']={'rail':'手心顺着木纹滑过去，脚步慢了下来。','plant':'拨开叶片，把清水浇在根边。','picture':'这幅小画里，也有一扇亮着灯的窗。','fern':'蕨叶舒展开来，接住了一点水。','table':'花瓶转了半圈，花朵朝着窗光。'}.get(h['id'],h.get('copy',''))
  h['copy']=h['copy'] if h['copy'] and h['copy'] not in ['衣服和小物各归其位。','把日常的小事慢慢做好。','整理好了，关上时轻一点。','给下一次来做客的人留个干净的位置。'] else h['label']+'，这里又留下一点你的日常。'

# Each small-room object has its own present-tense household detail.
object_copy={'closet1': {'hang': '肩缝对齐衣架，袖子顺着垂下来。', 'drawer': '抽屉里收着备用纽扣和软尺，用完轻轻推回去。', 'tidy': '厚衣服放下层，常穿的留在伸手就够到的位置。'}, 'guest_closet': {'coat': '空衣架给你留着，把一路带来的外套挂好。', 'bag': '旅行包靠墙放，鞋子和换洗衣物分开放。', 'basket': '把零碎小物放进收纳盒，明早就不必四处找了。'}, 'closet2': {'hanger': '摸摸布料，选一件适合今天温度的外套。', 'drawer': '袜子成双卷好，抽屉里留着一点香皂的味道。', 'clothes': '衣角折进去，叠好的衣服一摞一摞排整齐。'}, 'bath2': {'basin': '水流落进白瓷盆，搓搓掌心，再冲掉泡沫。', 'shower': '热水敲着玻璃，洗好后把开关拧紧。', 'mat': '抖开浴垫，湿的一面朝外，等风把它吹干。'}, 'bath1': {'towel': '把浴巾折成三折，柔软的一边朝外。'}, 'guest_bath': {'plant': '清水沿着花盆边慢慢倒，别弄湿刚擦好的台面。'}}
for room, lines in object_copy.items():
 for h in rooms[room]["hotspots"]:
  if h["id"] in lines:h["copy"]=lines[h["id"]]

hot('mahjong','pairs','花纹翻牌',(1230,183),(1330,257),'pairs')
hot('study','music','听一段原创音乐',(1182,199),(1239,287),'music')
hot('ayu_room','bed','躺下歇一会儿',(1158,710),(1272,817),'bed','sleep')
hot('laundry','drying','晾衣 / 收衣',(257,315),(280,305),'drying','fold')
hot('exterior','ball','和喜多踢球',(1000,719),(977,729),'football')
hot('exterior','today','门上的今日小事',(814,554),(827,650),'today')
rooms['guest_closet']['hotspots'][0]['approach']=pt('guest_closet',(142,234))
hot('garden','garden_play','六畦自己的小菜地',(293,730),(274,775),'garden')
hot('garden','vegetables','当季种子盒',(498,764),(520,758),'seedbox')
hot('garden','flowers','种一畦花',(298,197),(347,203),'flower_garden')
hot('garden','fruit','摘当季的果子',(707,279),(805,344),'fruit')
hot('garden','pond','小溪里捞鱼',(1184,783),(1060,735),'net')
hot('garden','bees','观察蜜蜂访花',(272,161),(347,189),'bees')
# Claude 10/5：小桥两样东西名字跟打开的玩法对上（体验师小毛病 1）。
for h in rooms['bridge']['hotspots']:
 if h['id']=='water':h['label']='在浅水里捞小鱼'
 if h['id']=='fish':h['label']='在桥边钓一尾鱼'
# Additional sitting positions are independent hotspots, not arbitrary stand-in animations.
seats={
'living':[(700,453,'down'),(780,453,'down'),(639,538,'right')],
'dining':[(486,215,'right'),(602,215,'left'),(543,155,'down'),(539,272,'up')],
'mahjong':[(1128,205,'right'),(1299,205,'left'),(1200,141,'down'),(1200,263,'up')],
'guest':[(575,278,'left'),(410,357,'down')],
'study':[(1293,285,'left'),(1123,252,'up')],
'workshop':[(145,553,'up')],
'terrace':[(236,743,'right'),(350,758,'up'),(388,814,'up'),(473,911,'down')],
'ayu_room':[(1338,809,'up')]
}
for id,positions in seats.items():
 for i,(x,y,face) in enumerate(positions):
  hid='seat_'+str(i);hot(id,hid,'坐在这里',(x,y),(x,y+36),'seat','sit');rooms[id]['hotspots'][-1].update(seat=pt(id,(x,y)),face=face)

# The old map had a portal directly in front of the old house. That fake connection is removed.
rooms['garden']['doors']=[d for d in rooms['garden']['doors'] if d['target']!='oldhouse']
rooms['oldhouse']['doors']=[d for d in rooms['oldhouse']['doors'] if d['target']!='garden']
# Claude 10/5：果园到老屋的路接回来（阿鱼细节 4）。门不放在路中间：果园这头在小木桥东头，
# 老屋那头在篱笆小路的尽头，走到路的尽头才过去。
rooms['garden']['doors'].append(dict(id='to_oldhouse',target='oldhouse',pos=[1412,371],approach=[1412,371],face='left',label='过小木桥去老屋',kind='door'))
rooms['oldhouse']['doors'].append(dict(id='to_garden',target='garden',pos=[1140,160],approach=[1140,160],face='down',label='沿篱笆小路去果园',kind='door'))
rooms['oldhouse']['walk_rect']=[1110,140,303,361]
rooms['oldhouse']['walk_polygons']=[[[1128,150],[1152,150],[1176,190],[1191,190],[1324,190],[1310,224],[1353,282],[1412,373],[1412,498],[1388,498],[1279,317],[1191,236],[1165,232],[1128,175]]]
rooms['garden']['doors'].append(dict(id='to_grove',target='grove',pos=[544,111],approach=[544,124],face='down',label='穿过小门去树林',kind='door'))
rooms['garden']['new_gates']=[[544,105,'树林'],[698,1010,'厨房'],[755,1010,'院子']]
rooms['kitchen']['new_gates']=[pt('kitchen',(147,175))+['后门']]
rooms['grove']=dict(id='grove',title='后院树林与秋千',floor=0,group='屋外',outdoor=True,asset_root='res://ayu_home/v4/assets/',background='grove.png',size=[1448,1086],source_crop=[0,0,1448,1086],source_offset=[0,0],props=[],obstacles=[[545,463,75,65],[599,255,53,164],[800,254,55,169],[666,359,111,59],[332,599,164,103],[947,596,168,107]],walk_rect=[50,133,1330,953],walk_polygons=[[[661,134],[767,134],[767,423],[928,444],[1019,469],[1215,443],[1317,308],[1368,313],[1347,427],[1275,527],[1017,567],[814,713],[803,1080],[661,1080],[650,714],[456,576],[233,546],[132,477],[56,325],[122,309],[220,442],[466,497],[529,419],[659,416]]],spawn=[727,1038],anchors={'ayu':[843,525],'mother':[710,613],'father':[610,560]},windows=[],lamps=[],doors=[dict(id='to_garden',target='garden',pos=[728,1072],approach=[728,1064],face='up',label='回后花园',kind='door')],hotspots=[])
hot('grove','swing','坐上秋千看天空',(722,398),(724,459),'swing','sit')
hot('grove','tree','种一棵果树',(422,651),(506,603),'tree')
hot('grove','tree_two','照看小树',(1028,650),(947,591),'tree')
hot('grove','stump','坐在树桩上',(577,495),(624,545),'seat','sit')
hot('grove','fireflies','树林里的微光',(857,500),(849,562),'fireflies')
rooms['guest_closet']['hotspots'][0]['approach']=pt('guest_closet',(142,234))
hot('garden','garden_play','六畦自己的小菜地',(435,707),(486,711),'garden')
for id,c in rooms.items():
 for d in c['doors']:
  d['width']=22 if not c['outdoor'] else 34
  d['explicit_opening']=True
 c['navigation_version']=4
 (A/(id+'.json')).write_text(json.dumps(c,ensure_ascii=False,indent=2)+'\n')
(A/'rooms.json').write_text(json.dumps({'version':4,'rooms':rooms,'order':list(rooms)},ensure_ascii=False,indent=2)+'\n')
print('BUILT',len(rooms),'rooms',sum(len(r['hotspots']) for r in rooms.values()),'objects')
