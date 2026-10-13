"""Integrate source PNGs without repainting them; runtime uses uniform nearest scaling.
All authored geometry, road surfaces, source records and outputs stay in this project.
"""
from pathlib import Path
from PIL import Image, ImageDraw
import copy, json, random, shutil, hashlib, subprocess, sys

R=Path(__file__).resolve().parents[1]; A=R/'godot/ayu_home/v4/assets'; V=A/'village'
S=R/'素材来源/逐户原创设计/输出'; D=R/'交付/完整村庄-1006'; random.seed(1007)
doc=json.loads((A/'rooms.json').read_text()); rooms=doc['rooms']; world=rooms['village']
houses={h['id']:h for h in json.loads((V/'houses.json').read_text())}
top=json.loads((V/'topology.json').read_text()); roads=top['roads'][:10]
archive=R/'素材来源/逐户原创设计/接入前草稿'; archive.mkdir(exist_ok=True)
for f in V.glob('house_*.png'):
    if not (archive/f.name).exists():shutil.copy2(f,archive/f.name)
for name in ['rooms.json','village.json']:
    if not (archive/name).exists():shutil.copy2(A/name,archive/name)

# The user's five supplied designs remain five different lots. All nine new designs coexist.
specs={
 'erba':('erba',1640,0,850,.38,.90), 'laowu':('laowu',420,30,800,.51,.81),
 'daba':('daba',2120,800,850,.48,.87), 'h5':('h5',95,1170,850,.25,.88),
 'h2':('ref2',2250,1760,900,.51,.87), 'h3':('h3',80,2130,875,.61,.90),
 'mayor':('mayor',1130,2290,835,.68,.84), 'h6':('ref6',2500,2730,825,.50,.94),
 'h8':('h8',80,2940,850,.17,.76), 'h7':('h2',1590,3030,430,.66,.80),
 'h4':('ref5',120,3630,875,.50,.89), 'h1':('ref1',2720,3630,850,.50,.90),
 'flower':('h6',60,585,785,.61,.90), 'whitebrick':('whitebrick',2720,20,850,.62,.91),
 'grape':('grape',3780,120,875,.32,.87), 'sunflower':('sunflower',3840,1260,825,.29,.92),
 'persimmon':('persimmon',3730,2450,920,.65,.91), 'rose':('rose',3820,3690,850,.74,.90)
}
for id,title,subtitle in [('flower','花房小楼','晴雨之间的花事'),('whitebrick','白砖小院','窗前球架与绿意')]:
    houses[id]=dict(id=id,title=title,subtitle=subtitle,floors=2,target='v_'+id,fictional=True)
for id,title,subtitle,floors in [('grape','葡萄架小院','藤影下的一张桌',1),('sunflower','向日葵之家','向着太阳慢慢长',2),('persimmon','柿树老院','树下留一张石凳',1),('rose','玫瑰花之家','花篱边的小路',2)]:
    houses[id]=dict(id=id,title=title,subtitle=subtitle,floors=floors,target='v_'+id,fictional=True)
houses['h7'].update(title='7A · 窄巷人家',subtitle='小院里的晾晒绳')
rooms['v_h7']['title']='7A · 窄巷人家 · 一楼'
rooms['v_h7']['hotspots'][0]['copy']='窄窄的院里晒着衣服，旧自行车等主人去赶场。这是一户虚构邻居。'
rooms['v_h7']['hotspots'][1].update(label='理好院里的晾晒绳',copy='衣夹收进小盒，晾晒绳重新拉直了。')
rooms['v_h7_up']['title']='7A · 窄巷人家 · 二楼'

world['props']=[p for p in world['props'] if p['id'] not in specs and not p['id'].startswith('tree_') and not p['id'].startswith('wildtree')]
world['doors']=[d for d in world['doors'] if d['id']=='visit_ayu']
ayu=houses['ayu']; b=ayu['bounds']; world['obstacles']=[[b[0]+18,b[1]+20,b[2]-36,b[3]-10]]
records=[]
for id,(source,x,y,w,gx,gy) in specs.items():
    src=S/(source+('-v2.png' if (S/(source+'-v2.png')).exists() else '-v1.png')); dst=V/('house_'+id+'.png');shutil.copy2(src,dst)
    iw,ih=Image.open(src).size;scale=w/iw;h=round(ih*scale);gate=[round(x+w*gx),round(y+h*gy)]
    row=houses[id];row.update(bounds=[x,y,w,h],art=dst.name,at=[gate[0],gate[1]+34])
    world['props'].append(dict(id=id,file='res://ayu_home/v4/assets/village/'+dst.name,pos=[x,y],foot=gate[1]-25,scale=[scale,scale],front=False))
    world['obstacles'].append([x+14,y+16,w-28,max(20,gate[1]-y-58)])
    world['doors'].append(dict(id='visit_'+id,target=row['target'],label='拜访'+row['title'],kind='door',face='down',pos=gate,approach=row['at'],width=68,explicit_opening=True))
    records.append(dict(house=id,source=str(src.relative_to(R)),runtime=str(dst.relative_to(R)),sha256=hashlib.sha256(dst.read_bytes()).hexdigest(),source_size=[iw,ih],scale=scale,gate=gate))

# Fresh procedural road surface; PNG source buildings themselves remain unchanged.
W,H=4800,4700
world['size']=[W,H];world['walk_rect']=[30,30,W-60,H-60]
ground=Image.new('RGB',(W//3,H//3),'#8aaa5a');d=ImageDraw.Draw(ground)
for i in range(145000):
    x=random.randrange(W//3);y=random.randrange(H//3)
    d.rectangle((x,y,x+random.randrange(1,4),y+random.randrange(1,3)),fill=random.choice(['#8baa5d','#8faf61','#7fa355','#99b564','#83a753','#91ac5b']))
def line(points,width,color):
    q=[(int(x/3),int(y/3)) for x,y in points];d.line(q,fill=color,width=max(1,int(width/3)),joint='curve')
    for x,y in q:d.ellipse((x-width/6,y-width/6,x+width/6,y+width/6),fill=color)
def rect(b,c):d.rectangle(tuple(int(a/3) for a in b),fill=c)
roads=roads+[[(820,695),(910,960),(620,1100),(460,1115)],[(2160,690),(2650,660),(3200,680)],[(2000,3700),(2300,3790)],[(940,1100),(1060,1370),(1630,1400)]]
roads += [[(3200,680),(3470,750),(3680,750),(4260,820),(4670,910),(4710,1800),(4610,2330),(4700,3020),(4690,4280),(4300,4350)],[(3150,2460),(3220,1980),(3450,1900),(3690,1900),(4090,1970)],[(3260,3380),(3380,3050),(3660,3050),(4300,3140)],[(3145,4380),(3460,4320),(3670,4320),(4310,4350)]]
for width,color in [(126,'#a88956'),(113,'#cfb17b'),(94,'#ddc08a')]:
    for rd in roads:line(rd,width,color)
for row in houses.values():
    x,y,w,h=row['bounds'];gate=row['at']; points=[pt for rd in roads for pt in rd]
    near=min(points,key=lambda p:(p[0]-gate[0])**2+(p[1]-gate[1])**2)
    line([gate,(gate[0],gate[1]+36),near],76,'#d9bb85')
    for i in range(45):
        xx=gate[0]+random.randrange(-55,55);yy=gate[1]+random.randrange(-10,50);rect((xx,yy,xx+9,yy+3),'#c4a373')
# Curving stream stays along the outer edge, clear of all front gates.
river=[(3570,0),(3550,900),(3450,1560),(3550,2100),(3520,2870),(3560,3520),(3510,4050),(3550,4700)]
line(river,85,'#567f70');line(river,62,'#56a6a0');line(river,39,'#76bbb1')
for yy in range(55,H,67):rect((3530,yy,3560,yy+3),'#a5d6c2')
for yy in [750,1900,3050,4320]:
    rect((3440,yy-38,3630,yy+38),'#8e6745')
    for xx in range(3444,3628,12):rect((xx,yy-34,xx+9,yy+34),'#c49b63')
    rect((3434,yy-45,3636,yy-40),'#5f4937');rect((3434,yy+40,3636,yy+45),'#5f4937')
world['obstacles'] += [[3480,0,90,660],[3480,850,90,970],[3480,1990,90,980],[3480,3150,90,1080],[3480,4420,90,280]]
# Kitchen gardens on terraces; earth, golden grain and varied flowers punctuate the green.
for idx,(x,y) in enumerate([(2500,660),(20,1880),(2750,2530),(50,4380),(2720,3400)]):
    for j in range(4):
        line([(x+j*8,y+j*28),(x+210+j*8,y+j*28+10)],15,'#986940')
        for k in range(10):
            rect((x+k*21+j*8,y+j*28-5,x+k*21+j*8+8,y+j*28+1),['#4a7a3e','#d3b85c','#67964c'][idx%3])
for xx,yy in [(1130,3900),(1580,3900),(1130,4300),(1580,4300)]:
    d.polygon([(xx//3,yy//3),((xx+345)//3,(yy-12)//3),((xx+360)//3,(yy+230)//3),((xx-6)//3,(yy+245)//3)],fill='#b1a575')
    for i in range(100):
        px=random.randrange(xx,xx+340);py=random.randrange(yy,yy+225);rect((px,py,px+4,py+9),'#7d984f')
# Flower verge around the southern garden site, bamboo behind its northern neighbour.
for i in range(80):
    x=1900+random.randrange(30);y=4330+random.randrange(210);rect((x,y,x+4,y+6),'#4e8249');rect((x-2,y-3,x+5,y+1),random.choice(['#e8a7ba','#e6c85e','#9b81ba','#f1e8c3']))
for x in range(1890,2000,15):
    line([(x,4010),(x-10,3825)],4,'#527e49')
    for y in range(3840,3990,24):line([(x-10,y+8),(x-32,y-10)],4,'#739647')
ground.resize((W,H),Image.Resampling.NEAREST).save(V/'ground.png')
# Trees are independent sprites, never a rectangular patch cut from a whole landscape.
def prop(id,file,x,y,foot,scale=1,**kw):return dict(id=id,file='res://ayu_home/v4/assets/village/'+file,pos=[x,y],foot=foot,scale=[scale,scale],front=False,**kw)
def dist_segment(x,y,a,b):
    dx,dy=b[0]-a[0],b[1]-a[1]; t=max(0,min(1,((x-a[0])*dx+(y-a[1])*dy)/max(1,dx*dx+dy*dy)))
    return ((x-a[0]-t*dx)**2+(y-a[1]-t*dy)**2)**.5
for i in range(150):
    x=random.randrange(30,W-190);y=random.randrange(15,H-180)
    if any(b[0]-80<x<b[0]+b[2]+60 and b[1]-100<y<b[1]+b[3]+85 for b in [r['bounds'] for r in houses.values()]):continue
    if any(dist_segment(x+70,y+145,a,b)<105 for rd in roads for a,b in zip(rd,rd[1:])):continue
    if 1000<x<2100 and y>3750:continue
    kind=['evergreen','deciduous','fruit'][i%3];file=['green_tree.png','pear_tree.png','apple_tree.png'][i%3]
    world['props'].append(prop('wildtree'+str(i),file,x,y,y+150,plant_type=kind))
world['props']=[p for p in world['props'] if p['id']!='site_pond']
world['props'].append(prop('site_pond','pond.png',910,3810,4040,1.25))
top['roads']=roads;top['houses']={k:r['bounds'] for k,r in houses.items()};top['world_size']=[W,H]

# New homes have authored room organisation, circulation and their own interactions.
def new_room(id,title,w,h,walls,furniture,copy_text,help_label,help_result,upper=False):
    c=dict(id=id,title=title,group='村庄',floor=0,size=[w,h],asset_root='res://ayu_home/v3/assets/',background='res://ayu_home/v4/assets/village/interior_'+id+'.png',props=[],obstacles=copy.deepcopy(walls),hotspots=[],doors=[],anchors={},windows=[],lamps=[[w//2,170,260]],source_offset=[0,0],spawn=[w//2,h-85],walk_rect=[22,96,w-44,h-118],outdoor=False,view_scale=1.15)
    im=Image.new('RGB',(w,h),'#c3a270');dd=ImageDraw.Draw(im)
    for y in range(80,h-20,28):
        for x in range(-70 if (y//28)%2 else 0,w,140):dd.rectangle((x,y,x+137,y+25),fill=random.choice(['#bb9865','#c4a06c','#c9a676']),outline='#ad8a5c')
    dd.rectangle((10,12,w-10,79),fill='#e0cfaa');dd.rectangle((5,5,w-5,11),fill='#755339')
    dd.rectangle((0,0,9,h),fill='#705036');dd.rectangle((w-10,0,w,h),fill='#705036')
    for x,y,ww,hh in walls:dd.rectangle((x,y-10,x+ww,y+hh),fill='#cbb890',outline='#76583d',width=3)
    dd.rectangle((0,h-20,w//2-55,h),fill='#76583d');dd.rectangle((w//2+55,h-20,w,h),fill='#76583d')
    im.save(V/('interior_'+id+'.png'))
    sizes={'bed':(150,215),'kitchen':(155,88),'table':(120,80),'sofa':(135,90),'bench':(126,78),'cabinet':(98,112)}
    for n,(kind,x,y) in enumerate(furniture):
        fw,fh=sizes[kind];c['props'].append(prop(kind+str(n),'furniture_'+kind+'.png',x,y,y+fh-5));c['obstacles'].append([x+5,y+fh*.6,fw-10,fh*.4])
    c['props'] += [prop('window','window.png',w//2-98,21,75),prop('stairs','stairs.png',w-110,h-300,h-160)]
    c['doors']=[dict(id='downstairs' if upper else 'outside',label='下到一楼' if upper else '回到村路',target=id.removesuffix('_up') if upper else 'village',pos=[w-65,h-155] if upper else [w//2,h-54],approach=[w-65,h-125] if upper else [w//2,h-36],kind='door',width=60,explicit_opening=True,face='down' if upper else 'up')]
    if not upper:c['doors'].append(dict(id='upstairs',label='上二楼',target=id+'_up',pos=[w-65,h-155],approach=[w-65,h-125],kind='door',width=60,explicit_opening=True,face='down'))
    c['hotspots']=[dict(id='resident_note',label='看看生活便签',pos=[95,h-170],approach=[95,h-125],kind='village',copy=copy_text),dict(id='house_help',label=help_label,pos=[w//2+80,h-190],approach=[w//2+80,h-115],kind='village',house=id.removeprefix('v_').removesuffix('_up'),copy=help_result),dict(id='tea_seat',label='坐一会儿',pos=[w//2,h-260],approach=[w//2,h-220],kind='seat',seat=[w//2,h-250],face='down')]
    rooms[id]=c
new_room('v_flower','花房小楼 · 一楼',780,710,[[320,100,12,180],[320,430,12,235],[40,360,170,12]],[('bench',50,135),('cabinet',180,125),('kitchen',430,120),('table',435,330)],'木窗搭成的花房在左手边，右边的小厨房能看见盆栽。住户为虚构邻居。','换好花架托盘','托盘擦干净了，新枝可以慢慢长。')
new_room('v_flower_up','花房小楼 · 二楼',780,710,[[435,100,12,180],[435,430,12,235]],[('bed',65,130),('bench',535,150),('cabinet',295,120)],'房间隔着小书房，窗台留出一片晒种子的地方。','压好窗边的种子纸','种子纸压平了，记着你今天来过。',True)
new_room('v_whitebrick','白砖小院 · 一楼',900,740,[[330,100,12,220],[330,470,12,200],[590,100,12,230],[590,480,12,190]],[('sofa',55,160),('table',115,365),('kitchen',665,135),('cabinet',700,330)],'中间的过厅把起居间和灶屋分开，门外有旧球架。这里是一户虚构邻居。','收好廊下的球','球放进廊下的篮筐，门口又宽敞了。')
new_room('v_whitebrick_up','白砖小院 · 二楼',900,740,[[390,100,12,245],[390,490,12,190]],[('bed',75,130),('bed',590,125),('bench',85,435)],'两间卧房围着二楼小厅，栏杆外能看见村路转弯。','整理阳台花盆','花盆挪开了门口，阳台有了更宽的落脚处。',True)
new_room('v_grape','葡萄架小院',850,640,[[235,100,12,170],[235,410,12,180],[500,100,12,160]],[('kitchen',45,130),('table',350,160),('bed',615,110),('bench',370,370)],'一侧是灶屋，一侧是卧房，中间的过厅正对葡萄架。住户为虚构邻居。','扶好藤架的小竹竿','小竹竿扎好了，藤影下多出一处可坐的空位。')
new_room('v_sunflower','向日葵之家 · 一楼',650,830,[[38,320,170,12],[350,320,260,12],[260,465,12,300]],[('bench',75,130),('cabinet',430,130),('kitchen',65,430),('table',390,450)],'门边留着向日葵种子的小纸袋，狭长过道通向后灶屋。住户为虚构邻居。','整理晒种子的纸袋','纸袋按日期摆齐了，来年还有一片向日葵。')
new_room('v_sunflower_up','向日葵之家 · 二楼',650,830,[[295,100,12,245],[295,490,12,275]],[('bed',65,120),('bench',380,130),('cabinet',70,460)],'楼上的窗面向花田，桌边放着一幅未完成的画。','放平窗前的小画纸','画纸压在书下面，等主人回来继续画。',True)
new_room('v_persimmon','柿树老院',880,680,[[285,100,12,230],[285,460,12,175],[560,100,12,170],[560,405,12,230]],[('bed',70,130),('table',390,220),('cabinet',690,120),('bench',675,410)],'过厅围着树下的院子展开，右边粮房较高。住户为虚构邻居。','收好树下的竹篮','竹篮摆进廊下，落果的位置也扫干净了。')
new_room('v_rose','玫瑰花之家 · 一楼',820,760,[[310,90,12,235],[310,475,12,235],[322,350,225,12]],[('bench',60,125),('table',65,405),('sofa',470,125),('kitchen',485,430)],'左侧长廊连着插花桌，右边才是起居间和灶屋。住户为虚构邻居。','换掉花瓶里的水','花瓶换好水了，一枝玫瑰留在你坐过的桌边。')
new_room('v_rose_up','玫瑰花之家 · 二楼',820,760,[[365,100,12,210],[365,465,12,240]],[('bed',490,120),('bench',80,155),('cabinet',85,410)],'楼上小书桌正对侧廊，花篱的颜色从窗外一直延进来。','夹好窗边的花瓣书签','花瓣压进旧书，等下次串门再翻开。',True)
for id in ['v_grape','v_persimmon']:
    rooms[id]['doors']=[d for d in rooms[id]['doors'] if d['id']!='upstairs'];rooms[id]['props']=[p for p in rooms[id]['props'] if p['id']!='stairs']
for spot in rooms['v_grape']['hotspots']:
    if spot['id']=='tea_seat':spot.update(pos=[425,460],approach=[425,520],seat=[425,480])

# A small starter home on its own clean site; no borrowed farmhouse floor holes.
shutil.copy2(S/'cabin-v1.png',V/'cabin.png')
yard=rooms['my_yard'];yard['background']='res://ayu_home/v4/assets/village/yard_ground.png';yard['walk_rect']=[35,360,980,500]
yi=Image.new('RGB',(350,300),'#8eab63');yd=ImageDraw.Draw(yi)
for i in range(10000):
    x=random.randrange(350);y=random.randrange(300);yd.rectangle((x,y,x+2,y+1),fill=random.choice(['#89a75d','#96b36d','#80a257','#91ad67']))
yd.polygon([(55,115),(217,105),(258,165),(226,240),(183,292),(129,292),(129,233),(53,203)],fill='#d6b886')
for i in range(800):
    x=random.randrange(350);y=random.randrange(300)
    if yi.getpixel((x,y))==(214,184,134):yd.rectangle((x,y,x+2,y+1),fill='#cbb07c')
yi.resize((1050,900),Image.Resampling.NEAREST).save(V/'yard_ground.png')
yard['props']=[dict(id='cabin',file='res://ayu_home/v4/assets/village/cabin.png',pos=[150,45],foot=405,scale=[.45,.45],front=False),prop('yard_tree1','green_tree.png',45,450,600,1.3,plant_type='evergreen'),prop('yard_tree2','apple_tree.png',880,290,450,plant_type='fruit'),prop('yard_tree3','pear_tree.png',865,650,810,plant_type='fruit')]
yard['obstacles']=[[230,90,560,277]]
yard['doors'][1].update(pos=[486,410],approach=[486,445]);yard['spawn']=[550,760]
new_room('my_cabin','自己的小屋',780,710,[],[('bed',65,130),('kitchen',545,120)],'','','')
cabin=rooms['my_cabin'];cabin['props']=[p for p in cabin['props'] if p['id']!='stairs']
cabin['doors']=[dict(id='yard',label='到自己的院子',target='my_yard',pos=[390,656],approach=[390,680],face='up',kind='door',width=60,explicit_opening=True)]
cabin['hotspots']=[dict(id='yard',label='摆放家具',pos=[415,420],approach=[415,470],kind='village'),dict(id='diary',label='写在这里的日子',pos=[240,390],approach=[240,430],kind='village'),dict(id='rest_seat',label='坐在床边',pos=[145,345],approach=[145,380],kind='seat',seat=[145,330],face='down')]
# Both neighbours stand on open floor with a clear approach, beside their work.
for rid,npc_pos,approach in [('v_h5',[520,340],[520,385]),('v_h3',[600,390],[600,440])]:
    rooms[rid]['npc']['pos']=npc_pos
    for spot in rooms[rid]['hotspots']:
        if spot['id'] in ['honey','mill']:spot.update(pos=npc_pos,approach=approach)
for rid,cfg in rooms.items():
    if not rid.startswith('v_'):continue
    cfg['props']=[p for p in cfg['props'] if p['id']!='tea_bench']
    for spot in cfg['hotspots']:
        if spot['id']=='tea_seat':
            x,y=spot['seat'];cfg['props'].append(dict(id='tea_bench',file='res://ayu_home/v3/assets/exterior_bench.png',pos=[x-30,y-23],foot=y+10,front=False))

for k,c in rooms.items():(A/(k+'.json')).write_text(json.dumps(c,ensure_ascii=False,indent=2))
(A/'rooms.json').write_text(json.dumps(doc,ensure_ascii=False,indent=2));(V/'houses.json').write_text(json.dumps(list(houses.values()),ensure_ascii=False,indent=2));(V/'topology.json').write_text(json.dumps(top,ensure_ascii=False,indent=2))
(D/'逐户素材接入记录.json').write_text(json.dumps(records,ensure_ascii=False,indent=2))
(D/'房屋及互动清单.json').write_text(json.dumps({k:{'title':c['title'],'doors':c['doors'],'interactions':c['hotspots']} for k,c in rooms.items() if k.startswith('v_') or k in ['exterior','village','my_yard','my_cabin']},ensure_ascii=False,indent=2))
print('Integrated',len(houses),'different village houses;',len(rooms),'areas; source PNGs preserved verbatim')
if (R/'素材来源/逐户室内重绘/葡萄架小院/家具整套-v2-粗像素.png').exists():
    subprocess.run([sys.executable,str(R/'工具/integrate_new_interiors.py')],check=True)
