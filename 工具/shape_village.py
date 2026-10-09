from pathlib import Path
from PIL import Image,ImageDraw
import random,json,math
R=Path(__file__).resolve().parents[1];A=R/'godot/ayu_home/v4/assets';V=A/'village';P=R/'godot/ayu_home/v3/assets';random.seed(734);N=Image.Resampling.NEAREST
m=json.loads((A/'rooms.json').read_text());rooms=m['rooms'];world=rooms['village'];oldindex=json.loads((V/'houses.json').read_text());index={r['id']:r for r in oldindex}
# Deliberate differences in mass, yard frontage and spacing, around a bending village spine.
layout={
'erba':(1800,40,740,555,6),'laowu':(500,110,720,490,5),'daba':(2120,800,850,600,1),
'h5':(95,1170,770,550,5),'ayu':(1090,1470,800,600,0),'h2':(2250,1760,850,595,2),
'h3':(80,2130,825,580,3),'mayor':(1130,2290,745,545,6),'h6':(2500,2730,760,555,6),
'h8':(80,2940,750,535,5),'h7':(1590,3200,790,570,1),'h4':(120,3630,800,540,5),'h1':(2720,3630,850,610,1)}
w,h=3600,4700;im=Image.new('RGB',(w//3,h//3),'#85a258');d=ImageDraw.Draw(im)
for i in range(130000):
 x=random.randrange(w//3);y=random.randrange(h//3);d.rectangle((x,y,x+random.randrange(1,4),y+random.randrange(1,3)),fill=random.choice(['#83a357','#8da961','#91aa62','#78954e','#7c9b51']))
def polyline(points,width,color):
 p=[(int(x/3),int(y/3)) for x,y in points];d.line(p,fill=color,width=int(width/3),joint='curve')
 for x,y in p:d.ellipse((x-width/6,y-width/6,x+width/6,y+width/6),fill=color)
def rect(box,color):d.rectangle(tuple(int(x/3) for x in box),fill=color)
roads=[[(3400,4480),(2430,4420),(2180,4200),(2090,3910),(2250,3900),(2430,3410),(2320,3010),(2090,2980),(2010,2520),(1990,2150),(2080,1720),(1910,1480),(1640,1260),(1510,920),(1370,750),(1750,720),(2160,690)],[(1370,750),(970,790),(820,695)],[(1940,2140),(1050,2140),(970,1830),(480,1800)],[(2090,2975),(1070,2880),(492,2820)],[(1070,2880),(1000,3410),(980,3580),(470,3570)],[(980,3580),(990,4300),(1750,4320),(2180,4200)],[(2010,2520),(2645,2460)],[(2320,3010),(2300,3380),(2890,3380)],[(2430,4420),(3145,4380)],[(970,790),(900,1040),(970,1260)]]
for road in roads:polyline(road,130,'#9e865d');polyline(road,113,'#c7ad7d');polyline(road,95,'#d1b686')
world['size']=[w,h];world['walk_rect']=[30,30,w-60,h-60];world['props']=[];world['obstacles']=[];world['doors']=[];world['lamps']=[];world['spawn']=[1500,2150]
def prop(id,file,x,y,foot,**kw):world['props'].append(dict(id=id,file=file,pos=[x,y],foot=foot,front=False,**kw))
for id,(x,y,ww,hh,typ) in layout.items():
 r=index[id];src=Image.open(V/f'lot{typ}.png').convert('RGBA').resize((ww,hh),N)
 # Add distinct working wings and yard outlines, keeping source pixels/materials.
 if id in ['erba','daba','h3','h7','h1']:
  extension=Image.open(A/'exterior-nocar/exterior_garage.png').convert('RGBA')
  extension=extension.resize({'erba':(135,150),'daba':(160,170),'h3':(135,160),'h7':(170,160),'h1':(195,185)}[id],N)
  src.alpha_composite(extension,({'erba':12,'daba':ww-175,'h3':5,'h7':ww-175,'h1':6}[id],hh-245))
 # A taller covered flower/work corner, a different frontage for the small one-storey families.
 if id in ['h8','h4','laowu']:
  canopy=Image.open(P/'exterior_shed.png').convert('RGBA').resize(({'h8':165,'h4':220,'laowu':125}[id],155),N);src.alpha_composite(canopy,(ww-245,hh-260))
 src.save(V/f'house_{id}.png');prop(id,f'res://ayu_home/v4/assets/village/house_{id}.png',x,y,y+hh-15)
 gate=[x+int(ww*.5),y+hh+52];r['at']=gate;r['bounds']=[x,y,ww,hh];r['art']=f'house_{id}.png';world['obstacles'].append([x+18,y+20,ww-36,hh-10]);world['doors'].append(dict(id='visit_'+id,target=r['target'],label='拜访'+r['title'],kind='door',face='down',pos=[gate[0],gate[1]-22],approach=gate,width=64,explicit_opening=True))
 # Irregular stone forecourts and footpaths connect to the nearest authored road.
 poly=[(x-12,y+hh-55),(x+ww*.4,y+hh-70),(x+ww+18,y+hh-40),(x+ww-25,y+hh+60),(x+ww*.55,y+hh+91),(x-30,y+hh+48)]
 d.polygon([(int(a/3),int(b/3)) for a,b in poly],fill='#bfae83')
 points=[pt for road in roads for pt in road];near=min(points,key=lambda p:(p[0]-gate[0])**2+(p[1]-gate[1])**2);polyline([gate,((near[0]+gate[0])*.5,gate[1]+30),near],75,'#d1b686')
 for i in range(80):
  px=random.randrange(x,x+ww);py=random.randrange(y+hh-20,y+hh+60);rect((px,py,px+random.randrange(5,20),py+3),'#a59872')
 for dx,dy in [(-15,hh-105),(ww-72,hh-120)]:prop('tree_'+id+str(dx),'res://ayu_home/v4/assets/village/fruit_tree.png',x+dx,y+dy,y+dy+150,plant_type='fruit')
# A small stream follows the eastern edge; crossing stones and a public pond broaden the commons.
river=[(3300,10),(3310,720),(3150,1470),(3310,2100),(3410,2820),(3460,3400)]
polyline(river,105,'#638c7e');polyline(river,80,'#7eafa0')
for yy in range(50,3400,71):
 xx=int(3300+50*math.sin(yy/300));rect((xx,yy,xx+35,yy+3),'#a7c8b1')
rect((1040,980,1460,1240),'#618d81');rect((1060,1000,1440,1220),'#80aaa0')
for yy in range(1020,1220,30):rect((1070,yy,1425,yy+3),'#a6c4af')
for xx in range(1220,1280,12):rect((xx,970,xx+9,1250),'#a07b50')
# Four sites are intentionally separated from existing households, reached by a southern common lane.
for xx,yy in [(1130,3900),(1580,3900),(1130,4300),(1580,4300)]:
 d.polygon([(xx//3,yy//3),((xx+345)//3,(yy-20)//3),((xx+375)//3,(yy+220)//3),((xx-12)//3,(yy+250)//3)],fill='#ad9c6d')
 for i in range(200):
  px=random.randrange(xx,xx+340);py=random.randrange(yy,yy+235);rect((px,py,px+5,py+12),'#7d8f4f')
# Public field terraces, hedges, kitchen gardens and stepping stones, not a square city grid.
for x,y in [(50,830),(2500,120),(2500,650),(20,1830),(2720,2510),(60,4380),(2500,3080)]:
 for j in range(5):
  polyline([(x+j*8,y+j*30),(x+180+j*8,y+j*30+10),(x+260,y+j*30+20)],14,'#9c8151')
  for k in range(12):rect((x+k*20+j*7,y+j*30-7,x+k*20+j*7+8,y+j*30),'#4d773b')
# Species-specific vegetation, planted along road bends and around the wider edges.
for k in range(75):
 x=random.randrange(20,w-170);y=random.randrange(0,h-150)
 if any(b[0]-70<x<b[0]+b[2]+70 and b[1]-80<y<b[1]+b[3]+110 for b in [r['bounds'] for r in index.values()]):continue
 if any((x-p[0])**2+(y-p[1])**2<160**2 for p in [pt for road in roads for pt in road]):continue
 prop('wildtree'+str(k),'res://ayu_home/v4/assets/village/fruit_tree.png',x,y,y+150,plant_type='evergreen' if k%3==0 else 'deciduous')
im.resize((w,h),N).save(V/'ground.png')
public={'mayor':[1530,2890],'honey':[890,1160],'pond':[1450,1280],'chicken':[1080,1370],'orchard':[1690,1340],'market':[2330,4340],'home_site':[1350,4080],'map':[1980,2170],'mill':[615,2840]}
world['hotspots']=[dict(id=k,label={'mayor':'村长林伯','honey':'阿禾 · 蜂蜜箱','pond':'池塘 · 喂鱼','chicken':'鸡圈 · 添谷子','orchard':'时令果树','market':'村口货郎','home_site':'看看自己的地','map':'村里的路牌','mill':'青叔 · 石磨与小事'}[k],kind='village',pos=[v[0],v[1]-30],approach=v) for k,v in public.items()]
world['npcs']=[dict(id=k,name={'mayor':'林伯','honey':'阿禾','mill':'青叔','market':'货郎'}[k],pos=[public[k][0],public[k][1]-30],preset={'mayor':0,'honey':4,'mill':1,'market':3}[k]) for k in ['mayor','honey','mill','market']]
prop('honeybox','exterior_beehive_1.png',825,1085,1130);prop('notice','res://ayu_home/v4/assets/village/board.png',1955,2085,2170)
for i in range(3):prop('orchard'+str(i),'res://ayu_home/v4/assets/village/fruit_tree.png',1510+i*140,1130,1300,plant_type='fruit')
# Per-house topology: kitchen and family rooms sit on different sides; store rooms/thresholds vary.
plans={
'erba':(760,720,[(310,100,12,210),(310,440,12,240),(322,350,260,12)],[(60,130,'kitchen'),(415,175,'sofa'),(470,400,'table')]),
'laowu':(690,650,[(260,90,12,250),(260,455,12,170)],[(45,150,'bed'),(400,155,'cabinet'),(400,365,'table')]),
'daba':(780,680,[(480,95,12,190),(480,420,12,205)],[(75,125,'bench'),(555,120,'kitchen'),(205,360,'table')]),
'h5':(730,720,[(345,90,12,250),(345,460,12,220)],[(75,145,'cabinet'),(450,135,'kitchen'),(65,395,'table'),(440,390,'bed')]),
'h2':(660,760,[(40,325,190,12),(385,325,215,12)],[(60,130,'bench'),(390,150,'cabinet'),(85,405,'sofa'),(380,460,'table')]),
'h3':(820,700,[(500,90,12,220),(500,450,12,190)],[(50,160,'bench'),(240,165,'cabinet'),(595,140,'kitchen'),(120,405,'table')]),
'mayor':(710,710,[(270,95,12,180),(270,430,12,225)],[(65,140,'cabinet'),(390,200,'table'),(335,445,'sofa')]),
'h6':(710,790,[(300,90,12,260),(300,480,12,270)],[(65,140,'kitchen'),(405,140,'sofa'),(425,425,'table')]),
'h8':(660,670,[(410,90,12,140),(410,380,12,230)],[(65,145,'table'),(485,145,'kitchen'),(65,410,'bed')]),
'h7':(800,740,[(35,340,255,12),(440,340,325,12)],[(75,150,'kitchen'),(540,150,'bench'),(110,440,'sofa'),(480,450,'table')]),
'h4':(760,670,[(250,90,12,210),(250,440,12,180)],[(35,135,'bed'),(370,135,'kitchen'),(400,390,'table')]),
'h1':(790,800,[(420,90,12,250),(420,480,12,270),(430,375,160,12)],[(65,145,'sofa'),(545,140,'kitchen'),(60,420,'table'),(550,495,'cabinet')])}
files={'table':('res://ayu_home/v4/assets/floor1-redraw/dining-table.png',(120,80)), 'sofa':('res://ayu_home/v4/assets/floor1-redraw/living-sofa.png',(135,90)), 'bench':('res://ayu_home/v4/assets/floor1-redraw/workshop-bench.png',(126,78)), 'cabinet':('res://ayu_home/v4/assets/floor1-redraw/workshop-cabinet.png',(98,112)), 'kitchen':('res://ayu_home/v4/assets/floor1-redraw/kitchen-counter.png',(155,88)), 'bed':('res://ayu_home/v3/assets/guest_bed.png',(150,215))}
# Scaled reusable original furniture; actual silhouettes remain approved pixel sprites.
for key,(src,sz) in files.items():Image.open(R/'godot'/src.removeprefix('res://')).convert('RGBA').resize(sz,N).save(V/('furniture_'+key+'.png'))
guest=Image.open(P/'guest_floor.png').convert('RGBA');tile=guest.crop((149,185,220,235));wall=guest.crop((90,0,300,62))
for id,(ww,hh,walls,furn) in plans.items():
 c=rooms['v_'+id];c.update(size=[ww,hh],walk_rect=[22,100,ww-44,hh-120],spawn=[ww//2,hh-105],view_scale=1.15,props=[],obstacles=[])
 bg=Image.new('RGBA',(ww,hh),'#6a4b2c')
 for yy in range(60,hh-15,50):
  for xx in range(10,ww-10,71):bg.alpha_composite(tile,(xx,yy))
 bg.alpha_composite(wall.resize((ww-20,85),N),(10,6));bd=ImageDraw.Draw(bg)
 for x,y,a,b in walls:
  bd.rectangle((x,y,x+a,y+b),fill='#725030');bd.rectangle((x,y,x+a-2,y+b-3),fill='#b18858');c['obstacles'].append([x,y,a,b])
 bd.rectangle((0,0,9,hh),fill='#68462a');bd.rectangle((ww-10,0,ww,hh),fill='#68462a');bd.rectangle((0,hh-20,ww//2-55,hh),fill='#886035');bd.rectangle((ww//2+55,hh-20,ww,hh),fill='#886035');bg.save(V/f'interior_{id}.png');c['background']=f'res://ayu_home/v4/assets/village/interior_{id}.png'
 for n,(x,y,kind) in enumerate(furn):
  fw,fh=files[kind][1];c['props'].append(dict(id=kind+str(n),file=f'res://ayu_home/v4/assets/village/furniture_{kind}.png',pos=[x,y],foot=y+fh-5,front=False));c['obstacles'].append([x+4,y+fh*.55,fw-8,fh*.45])
 c['doors'][0].update(pos=[ww//2,hh-54],approach=[ww//2,hh-36]);c['hotspots'][0].update(pos=[ww//2-100,hh-120],approach=[ww//2-100,hh-80]);c['hotspots'][1].update(pos=[ww//2+90,hh-150],approach=[ww//2+90,hh-110]);c['hotspots'][2].update(pos=[ww//2,hh-245],approach=[ww//2,hh-190],seat=[ww//2,hh-235])
 if c.get('npc'):c['npc']['pos']=[ww//2+130,hh-210];c['hotspots'][-1].update(pos=[ww//2+130,hh-240],approach=[ww//2+130,hh-160])
 if len(c['doors'])>1:
  c['props'].append(dict(id='stairs',file='res://ayu_home/v4/assets/village/stairs.png',pos=[ww-110,hh-310],foot=hh-160,front=False));c['doors'][1].update(pos=[ww-65,hh-155],approach=[ww-65,hh-125])
 # Each family's upper floor: own study/bed proportions; preserve stairs connected at a real landing.
 up=rooms.get('v_'+id+'_up')
 if up:
  up['background']=c['background'];up['size']=c['size'];up['walk_rect']=c['walk_rect'];up['obstacles']=walls.copy();up['spawn']=[ww-145,hh-115];up['doors'][0].update(pos=[ww-65,hh-155],approach=[ww-65,hh-125]);up['props']=[dict(id='stairs',file='res://ayu_home/v4/assets/village/stairs.png',pos=[ww-110,hh-310],foot=hh-160,front=False),dict(id='bed',file='res://ayu_home/v4/assets/village/furniture_bed.png',pos=[45,110],foot=310,front=False),dict(id='desk',file='res://ayu_home/v4/assets/village/furniture_bench.png',pos=[ww-220,125],foot=195,front=False)];up['obstacles'].append([50,175,140,135]);up['hotspots'][0].update(pos=[ww-140,225],approach=[ww-140,280]);up['hotspots'][1].update(pos=[150,380],approach=[155,405],seat=[150,365])
(V/'houses.json').write_text(json.dumps(list(index.values()),ensure_ascii=False,indent=2))
(V/'topology.json').write_text(json.dumps({'world_size':[w,h],'roads':roads,'houses':layout,'interiors':plans,'public':public},ensure_ascii=False,indent=2))
for k,v in rooms.items():(A/(k+'.json')).write_text(json.dumps(v,ensure_ascii=False,indent=2))
(A/'rooms.json').write_text(json.dumps(m,ensure_ascii=False,indent=2));(R/'交付/完整村庄-1006/房屋及互动清单.json').write_text(json.dumps({k:{'title':v['title'],'size':v['size'],'doors':v['doors'],'interactions':v['hotspots']} for k,v in rooms.items() if k.startswith('v_') or k in ['exterior','village','my_yard','my_cabin']},ensure_ascii=False,indent=2))
print('Shaped village:',len(plans),'different interiors; winding roads;',w,h)
