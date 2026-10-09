#!/usr/bin/env python3
"""1005 floor plan integration. Coordinates are measured on the new 1448x1086 art.

Only floor-one geometry is rebuilt. Existing game verbs and IDs are retained.
Image processing here is runtime pixel-grid sampling and foreground extraction.
"""
from pathlib import Path
from PIL import Image, ImageDraw
import json, subprocess, copy

V = Path(__file__).resolve().parents[1]
A = V / 'assets'
OUT = A / 'floor1-redraw'
OUT.mkdir(exist_ok=True)
baseline = json.loads(subprocess.check_output(['git', 'show', '2b7e0cf:godot/ayu_home/v4/assets/rooms.json'], cwd=V))
rooms = copy.deepcopy(baseline['rooms'])
art = Image.open(OUT / 'floor1-generated.png').convert('RGBA')
# Architectural pixels: 724x543, displayed at 2x source size and 2x world zoom.
art = art.resize((724,543), Image.Resampling.NEAREST).resize((1448,1086), Image.Resampling.NEAREST)
cabinet=Image.open(OUT/'sources/closet.png').convert('RGBA')
cabinet=cabinet.crop(cabinet.getchannel('A').getbbox()).resize((20,58),Image.Resampling.NEAREST)
panel=Image.new('RGBA',(20,58),'#654327');panel.alpha_composite(cabinet)
art.paste(panel.resize((40,116),Image.Resampling.NEAREST),(1140,394))
art.save(OUT / 'floor1.png')
PREFIX = 'res://ayu_home/v4/assets/floor1-redraw/'
specs = {
 'living': ([538,411,1046,836], [835,520]),
 'dining': ([359,90,707,455], [655,365]),
 'kitchen': ([171,89,366,278], [300,227]),
 'laundry': ([36,277,365,439], [252,380]),
 'cats': ([706,81,876,451], [791,374]),
 'stairs1': ([874,99,1035,453], [936,377]),
 'mahjong': ([1049,99,1404,404], [1345,318]),
 'parents': ([1051,521,1405,817], [1350,686]),
 'workshop': ([31,437,198,837], [139,699]),
 'garage': ([211,437,524,836], [474,491]),
 'closet1': ([1027,345,1200,552], [1100,461]),
 'bath1': ([1193,380,1404,553], [1261,487]),
}

def pt(id,p):
 c=rooms[id]; return [round(p[0]-c['source_crop'][0]+c['source_offset'][0]),round(p[1]-c['source_crop'][1]+c['source_offset'][1])]
def box(id,b): return pt(id,b[:2])+list(b[2:])
def hot(id,hid,pos,approach,**extra):
 h=next(h for h in rooms[id]['hotspots'] if h['id']==hid)
 h.update(pos=pt(id,pos),approach=pt(id,approach),**extra)
 if 'seat' in h:h['seat']=pt(id,pos)
def bounds(id,rects):
 c=rooms[id];c['walk_polygons']=[]
 for x,y,w,h in rects:c['walk_polygons'].append([pt(id,p) for p in [(x,y),(x+w,y),(x+w,y+h),(x,y+h)]])
 c['walk_rect']=[0,0,*c['size']]
def obs(id,rects):rooms[id]['obstacles']=[box(id,b) for b in rects]
def anchor(id,key,p):rooms[id]['anchors'][key]=pt(id,p)
def door(id,target,p,face,label=None):
 rooms[id]['doors'].append(dict(id='to_'+target,target=target,pos=pt(id,p),approach=pt(id,p),face=face,label=label or ('去'+rooms[target]['title']),kind='door',width=30,explicit_opening=True))
def prop(id,name,poly,foot):
 # Polygon alpha avoids rectangular floor patches around a foreground object.
 x0=min(p[0] for p in poly);y0=min(p[1] for p in poly);x1=max(p[0] for p in poly)+1;y1=max(p[1] for p in poly)+1
 tile=art.crop((x0,y0,x1,y1));mask=Image.new('L',tile.size,0)
 ImageDraw.Draw(mask).polygon([(x-x0,y-y0) for x,y in poly],fill=255);tile.putalpha(mask)
 name=id+'-'+name+'.png';tile.save(OUT/name)
 rooms[id]['props'].append(dict(id=name,file=PREFIX+name,pos=pt(id,[x0,y0]),foot=pt(id,[0,foot])[1],front=False))

for id,(crop,spawn) in specs.items():
 c=rooms[id];width=crop[2]-crop[0];off=[max(0,(320-width)//2),48]
 c.update(size=[max(width,320),600],source_crop=crop,source_offset=off,
          background=PREFIX+'floor1.png',asset_root=PREFIX,props=[],doors=[],obstacles=[],
          windows=[],lamps=[],anchors={},new_gates=[],navigation_version=5)
 c['spawn']=pt(id,spawn)
 c.pop('stair_path',None);c.pop('approved_mask',None);c.pop('source_polygon',None)
 # Default all old anchor names to safe spawn until mapped below.
 for key in baseline['rooms'][id]['anchors']:anchor(id,key,spawn)
 # Atlas thumbnails preserve this floor's new composition in the existing map.
 thumb=art.crop(crop);thumb.thumbnail((224,180),Image.Resampling.NEAREST);thumb.save(OUT/('thumb_'+id+'.png'))

bounds('living',[(587,451,411,344),(595,428,73,34),(766,428,63,37),(894,426,82,37),(988,451,75,47),(804,778,178,42)])
obs('living',[(611,529,271,82),(842,551,49,87),(658,729,40,39),(611,602,71,135),(692,629,111,96),(817,707,78,69),(744,735,54,47),(978,551,41,216),(548,512,41,255),(552,458,37,41),(976,512,42,40)])
bounds('dining',[(371,163,313,248),(328,192,52,55),(327,381,53,34),(387,401, 70, 40),(602,401,63,40)])
obs('dining',[(442,171,190,171),(444,112,192,58),(371,105,31,113),(367,311,39,77),(503,385,74,29),(646,110,40,97),(650,348,36,40),(650,201,37,30)])
bounds('kitchen',[(212,192,127,64),(322,191,37,61)])
obs('kitchen',[(194,108,136,84)])
bounds('laundry',[(103,290,222,126),(316,381,43,36)])
obs('laundry',[(103,309,97,65),(212,292,49,61),(275,356, 40,60),(51,295,43,120),(100,377,34,41),(271,290,51,58)])
bounds('cats',[(754,137,63,277),(762,410, 62, 34),(718,118,99,31)])
obs('cats',[(716,148,34,253),(818,149, 50,219),(728,382, 40, 30),(829,389, 40, 30)])
bounds('stairs1',[(891,125,88,309),(888,410,96,39)])
obs('stairs1',[(976,342, 40,64)])
bounds('mahjong',[(1090,160,298,191),(1090,347,51,49)])
obs('mahjong',[(1142,141,157,174),(1106,110,76,48),(1340,146,47,132),(1342,281,51,83),(1053,115, 30,245)])
bounds('parents',[(1088,550,290,230),(1077,515,59,52),(1246,518,48,48)])
obs('parents',[(1144,591,169,186),(1059,590,51,128),(1355,561, 40,117),(1121,732,29,56),(1311,732,29,56),(1061,737, 40,56)])
bounds('workshop',[(65,628,101,165),(85,786,61,40)])
obs('workshop',[(42,451,149,175),(146,658, 40,104),(41,684,39,96),(94,605, 40,51)])
bounds('garage',[(262,453,232,338),(389,429, 70,35),(266,781,201,41)])
obs('garage',[(302,520,156,251),(230,531,53,150),(229,453, 60,75),(235,719, 40,69),(480,589,31,133),(301,451,39,45),(478,448,32,64)])
bounds('closet1',[(1061,400,77,104),(1088,367, 50,53),(1034,447, 70,50),(1078,497,58,43)])
obs('closet1',[(1143,397,31,110)])
bounds('bath1',[(1228,477, 90,44),(1242,516, 50,27)])
obs('bath1',[(1212,400,98,75),(1316,396,82,117)])

# Continuous thresholds on the painted openings. No invisible kitchen back door.
door('living','dining',[632,441],'down');door('dining','living',[632,425],'up')
door('living','cats',[796,448],'down');door('cats','living',[796,427],'up')
door('living','stairs1',[934,448],'down');door('stairs1','living',[934,432],'up')
door('living','closet1',[1046,470],'left');door('closet1','living',[1050,470],'right')
door('living','exterior',[869,803],'up')
door('dining','kitchen',[351,220],'right');door('kitchen','dining',[347,220],'left')
door('dining','laundry',[351,401],'right');door('laundry','dining',[347,401],'left')
door('dining','garage',[420,425],'up');door('garage','dining',[420,447],'down')
door('garage','exterior',[365,804],'up');door('workshop','exterior',[117,805],'up')
door('closet1','mahjong',[1113,392],'down');door('mahjong','closet1',[1113,379],'up')
door('closet1','parents',[1104,525],'up');door('parents','closet1',[1104,537],'down')
door('parents','bath1',[1266,536],'down');door('bath1','parents',[1266,532],'up')
door('stairs1','stairs2',[935,143],'down')
rooms['stairs1']['stair_path']=[pt('stairs1',[935,y]) for y in range(396,142,-23)]+[pt('stairs1',[935,143])]
# The new plan's actual north exit is in the cat passage. Keep the existing garden
# approach coordinate; only its reciprocal target changes. No outdoor art/geometry.
door('cats','garden',[770,131],'down','穿过北门去后花园')
for d in rooms['garden']['doors']:
 if d['target']=='kitchen':d.update(id='to_cats',target='cats',label='回楼梯旁猫窝走道')
rooms['garden']['new_gates']=[]

points={
'living':{'fish':([568,563],[604,503]),'tv':([1008,626],[943,666]),'sofa':([707,579],[712,618]),'album':([762,666],[814,655]),'lamp':([1000,734],[944,764]),'seat_0':([678,579],[704,620]),'seat_1':([800,579],[836,640]),'seat_2':([648,673],[710,756])},
'dining':{'meal':([539,256],[650,285]),'tea':([466,140],[419,180]),'recipe':([595,139],[642,249]),'flowers':([553,232],[413,272]),'seat_0':([472,268],[416,270]),'seat_1':([605,267],[651,274]),'seat_2':([541,190],[417,185]),'seat_3':([541,329],[545,364])},
'kitchen':{'stove':([282,150],[289,220]),'fridge':([207,172],[227,222]),'sink':([241,174],[258,218])},
'laundry':{'wash':([68,393],[150,393]),'basin':([181,337],[228,376]),'towel':([275,320],[275,379]),'drying':([222,396],[255,399])},
'cats':{'nest':([844,276],[788,278]),'scratch':([739,315],[789,334]),'bowls':([775,399],[788,378])},
'stairs1':{'rail':([879,282],[931,284]),'plant':([994,371],[940,399]),'picture':([982,146],[941,165])},
'mahjong':{'tea':([1137,128],[1107,193]),'chair':([1151,224],[1104,239]),'plant':([1368,336],[1316,323]),'pairs':([1224,224],[1323,254]),'seat_0':([1157,224],[1108,269]),'seat_1':([1281,224],[1322,255]),'seat_2':([1219,159],[1330,184]),'seat_3':([1219,298],[1240,341])},
'parents':{'lamp':([1134,746],[1121,693]),'bed':([1222,694],[1343,687]),'window':([1381,692],[1343,710])},
'workshop':{'wood':([112,580],[139,647]),'tools':([118,515],[155,641]),'lamp':([81,473],[71,649]),'seat_0':([114,632],[124,663])},
'garage':{'car':([385,651],[475,642]),'bike':([258,591],[288,695]),'shelf':([267,478],[354,486])},
'closet1':{'hang':([1157,438],[1103,442]),'drawer':([1158,489],[1103,485]),'tidy':([1158,414],[1105,423])},
'bath1':{'sink':([1269,430],[1264,493]),'shower':([1364,453],[1295,494]),'towel':([1218,472],[1245,491])},
}
for id,objects in points.items():
 for hid,(p,a) in objects.items():hot(id,hid,p,a)
next(h for h in rooms['closet1']['hotspots'] if h['id']=='hang')['label']='叠好次净衣'
rooms['cats']['title']='楼梯旁猫窝走道';rooms['closet1']['title']='东侧过道与次净衣柜';rooms['stairs1']['title']='一楼楼梯';rooms['bath1']['title']='爸妈卧室浴室'
anchors={
'living':{'ayu_seat':[786,581],'father_seat':[652,647],'mother_seat':[653,700],'guest_seat':[689,581],'fish':[604,503],'clean':[918,783],'qiuqiu':[725,771],'luoluo':[785,580],'tiantian':[651,703],'qiuqiu_evening':[721,768],'luoluo_evening':[785,580],'tiantian_evening':[682,750]},
'dining':{'father_meal':[472,270],'mother_meal':[604,270],'ayu_meal':[538,330],'guest_meal':[538,193],'cook':[415,214],'mother_read':[653,330],'father_read':[416,330],'clean':[651,378],'qiuqiu':[412,377]},
'cats':{'qiuqiu':[786,188],'luoluo':[786,278],'tiantian':[786,356]},
'parents':{'father':[1200,691],'mother':[1258,691]},
'kitchen':{'mother':[292,219]},'laundry':{'mother':[246,393]},'workshop':{'father':[139,651]},'garage':{'father':[475,670]},'stairs1':{'father':[936,380]},'mahjong':{'father':[1105,269],'mother':[1321,292]},
}
for id,aa in anchors.items():
 for k,p in aa.items():anchor(id,k,p)
for id,c in rooms.items():
 if id in specs:c['lamps']=[pt(id,specs[id][1])+[110]]
rooms['living']['fish_rect']=box('living',[551,526,27,81]);rooms['living']['tv_rect']=box('living',[994,586,11,98]);rooms['dining']['steam']=pt('dining',[541,250])
rooms['dining']['meal_center']=pt('dining',[539,257]);rooms['dining']['vase_position']=pt('dining',[574,225]);rooms['living']['vase_position']=pt('living',[751,651])

# Re-cut major furniture silhouettes and wall fronts from exactly the same raster.
shapes={
'living': [('sofa',[(613,530),(861,530),(861,550),(889,550),(889,631),(843,638),(842,611),(681,611),(681,698),(664,747),(618,727)],739),('table',[(716,626),(781,626),(805,650),(805,694),(780,724),(716,724),(693,701),(693,650)],723),('chair',[(851,700),(890,723),(895,753),(872,782),(825,759),(816,733)],779),('aquarium',[(547,511),(588,511),(588,698),(547,698)],698),('tv',[(994,561),(1020,573),(1020,700),(994,707)],708),('south-wall-left',[(539,790),(802,790),(802,833),(539,833)],835),('south-wall-right',[(986,790),(1045,790),(1045,833),(986,833)],835)],
'dining':[('table',[(509,195),(575,195),(610,221),(618,265),(600,300),(572,317),(506,317),(468,288),(462,246),(478,214)],320),('chairs',[(449,285),(482,285),(507,317),(481,341),(453,322)],343),('south-wall',[(469,410),(595,410),(595,451),(469,451)],454)],
'kitchen':[('counter',[(191,106),(331,106),(331,194),(191,194)],197),('south-wall',[(159,255),(348,255),(348,281),(159,281)],281)],
'laundry':[('fixtures',[(105,293),(198,293),(198,374),(105,374)],377),('cabinet',[(275,354),(315,354),(315,419),(275,419)],419),('south-wall',[(33,420),(349,420),(349,443),(33,443)],443)],
'cats':[('nests',[(818,148),(869,148),(869,369),(818,369)],370),('shelf',[(716,149),(751,149),(751,402),(716,402)],404)],
'stairs1':[('rail',[(875,114),(893,114),(893,409),(875,409)],410)],
'mahjong':[('table',[(1169,176),(1268,176),(1274,263),(1169,265)],268),('south-wall',[(1143,366),(1409,366),(1409,390),(1143,390)],390)],
'parents':[('bed',[(1144,590),(1309,590),(1310,780),(1143,780)],783),('south-wall',[(1050,790),(1426,790),(1426,817),(1050,817)],818)],
'workshop':[('bench',[(42,545),(190,545),(190,623),(42,623)],628),('cabinet',[(146,658),(187,658),(187,782),(146,782)],784)],
'garage':[('car',[(333,520),(427,520),(451,543),(459,711),(438,765),(325,765),(301,715),(305,553)],771)],
'closet1':[('cabinet',[(1140,394),(1180,394),(1180,510),(1140,510)],510)],
'bath1':[('fixtures',[(1212,402),(1310,402),(1310,476),(1212,476)],479),('shower',[(1316,394),(1399,394),(1399,515),(1316,515)],517)],
}
for id,layers in shapes.items():
 for name,poly,foot in layers:prop(id,name,poly,foot)

for id in [*specs,'garden']:(A/(id+'.json')).write_text(json.dumps(rooms[id],ensure_ascii=False,indent=2)+'\n')
baseline['rooms']=rooms
(A/'rooms.json').write_text(json.dumps(baseline,ensure_ascii=False,indent=2)+'\n')
print('Floor 1 rebuilt:',len(specs),'rooms;',sum(len(rooms[k]['hotspots']) for k in specs),'preserved hotspots')
