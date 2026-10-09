"""Native sprite slicing and data authoring; all sources and outputs in this independent project."""
from pathlib import Path
from PIL import Image,ImageDraw
import json,random,hashlib,shutil
R=Path(__file__).resolve().parents[1]; A=R/'godot/ayu_home/v4/assets'; V=A/'village';V.mkdir(exist_ok=True);P=R/'godot/ayu_home/v3/assets';random.seed(1006)
NEAR=Image.Resampling.NEAREST
# The actual household identifiers: 0B/3B are alternate views, never additional houses.
houses=[
 ('erba','二爸家','北坡的灯',6,2,100,80,'这盏灯总留给晚归的人。','把窗边的小灯点亮','灯已经亮了，回村的路也暖了一些。'),
 ('laowu','老屋','旧书与风',5,1,1150,80,'窗边的旧书等人翻一翻。','整理窗边书页','书页压平了，窗下留着你折的小书签。'),
 ('daba','大爸家','竹编小院',1,2,2200,80,'门边的竹篮适合装一趟新鲜菜。','修好竹篮提手','提手扎紧了，下次装菜就稳当了。'),
 ('h5','5A · 养蜂小院','阿禾的蜂蜜',5,1,100,880,'阿禾是本村虚构住户。她照料花圃和蜂箱。','整理晒花架','晒花架腾好了，蜜香里添了花香。'),
 ('ayu','0A · 阿鱼家','阿鱼家的院门',0,2,1150,880,'阿鱼的一家、猫猫和喜多都在这里。','', ''),
 ('h2','2A · 缝补人家','一针一线',2,2,2200,880,'桌边放着针线和折好的布料。','把布料叠好','布料叠好了，椅背上多了一块干净坐垫。'),
 ('h3','3A · 磨坊人家','青叔的小石磨',3,2,100,1680,'青叔是本村虚构住户。他做谷粉，也爱泡茶。','扫净磨坊台面','谷壳扫好了，青叔把茶杯推到你手边。'),
 ('mayor','村公所','村长 · 林伯',6,2,1150,1680,'林伯是虚构村长，在榕树旁替新邻居安家。','理好公告栏','旧便条收妥，新消息能看清了。'),
 ('h6','6A · 花窗人家','窗前花事',6,2,2200,1680,'花窗里有四季轮换的小盆栽。','给窗边花浇水','叶尖亮亮的，花盆旁留了一滴水。'),
 ('h8','8A · 茶香小院','慢慢喝杯茶',5,1,100,2480,'炉边一张竹椅，雨天正好听水声。','沏一壶家常茶','茶泡好了，随时可以坐下喝。'),
 ('h7','7A · 河风人家','河边的鱼篓',1,2,2200,2480,'墙边的空鱼篓等着下一趟收获。','补好鱼篓绳结','绳结扎牢了，院门前留着你的来访记录。'),
 ('h4','4A · 田边平房','收成的便签',5,1,100,3280,'田边的小屋记着每次种下的东西。','写一张种植便签','便签贴好了：慢慢种，熟了再收。'),
 ('h1','1A · 蓝瓦人家','相聚的长桌',1,2,2200,3280,'一张长桌，空位等邻居来坐。','摆好一副茶杯','茶杯摆齐了，今天来串门也算一件好事。')]
# Slice approved lots with crisp pixel edges. Scale with NEAREST; never recolor summer.
lot_polys={1:[(70,850),(80,480),(350,460),(350,245),(590,45),(1110,45),(1375,245),(1385,460),(1500,610),(1480,950),(790,970),(120,950)],2:[(60,880),(75,440),(365,395),(385,145),(600,50),(1160,65),(1390,250),(1370,610),(1470,765),(1460,955),(800,980),(100,960)],3:[(50,915),(120,565),(255,435),(400,170),(635,35),(1200,70),(1375,260),(1490,600),(1500,950),(750,975)],5:[(10,835),(50,560),(90,330),(335,150),(800,100),(1280,255),(1360,580),(1425,860),(1330,970),(450,1030),(50,960)],6:[(35,900),(70,625),(185,355),(400,305),(450,165),(650,52),(910,52),(1080,130),(1160,360),(1340,445),(1410,700),(1420,925),(900,965),(600,965)]}
for typ in [1,2,3,5,6]:
 src=Image.open(R/f'素材来源/房屋 {typ}.png').convert('RGBA');mask=Image.new('L',src.size);ImageDraw.Draw(mask).polygon(lot_polys[typ],fill=255);src.putalpha(mask)
 src.resize((800,600),NEAR).save(V/f'lot{typ}.png')
# Original Ayu buildings, together on one reusable map sprite; the real courtyard remains unchanged.
im=Image.new('RGBA',(800,600));house=Image.open(A/'exterior-nocar/exterior_house.png').convert('RGBA');house.thumbnail((640,470),NEAR);im.alpha_composite(house,(158,48));garage=Image.open(A/'exterior-nocar/exterior_garage.png').convert('RGBA');garage.thumbnail((182,190),NEAR);im.alpha_composite(garage,(5,310));im.save(V/'lot0.png')
# Large village ground, native three-pixel grain, warm lanes, stream and connected yards.
w,h=3200,4200;im=Image.new('RGB',(w//3,h//3),'#84a957');d=ImageDraw.Draw(im)
for i in range(60000):
 x=random.randrange(w//3);y=random.randrange(h//3);c=random.choice(['#8bae5b','#799c4d','#92ad62','#7e9f56']);d.rectangle((x,y,x+random.randrange(1,3),y+1),fill=c)
def rect(box,fill):d.rectangle(tuple(int(x/3) for x in box),fill=fill)
# Two north-south lanes and cross lanes; houses connect to each, no navigation islands.
for x in [970,2070]:rect((x-75,40,x+75,4170),'#c4a373');rect((x-60,40,x+60,4170),'#d6b883')
for yy in [740,1540,2340,3140,3980]:rect((45,yy-65,3155,yy+65),'#c4a373');rect((45,yy-52,3155,yy+52),'#d6b883')
for id,title,sub,typ,floors,x,y,*_ in houses:
 rect((x-14,y+475,x+814,y+685),'#b6a77c');rect((x,y+480,x+800,y+670),'#cdbb8e')
 # little stone slabs and yard shadows
 for xx in range(x+5,x+795,42):
  for yy in range(y+505,y+670,32):rect((xx,yy,xx+37,yy+27),random.choice(['#cfbd95','#d4c29c','#c6b48d']))
 rect((x+350,y+620,x+450,y+750),'#d6b883')
for i in range(19000):
 x=random.randrange(10,w//3-10);y=random.randrange(10,h//3-10)
 if im.getpixel((x,y)) in [(214,184,131),(205,187,142)]:d.point((x,y),fill=random.choice(['#c8a779','#dec394','#b99a72']))
# Commons: pond, footbridge, orchards, market lane, four prospective home sites.
rect((1170,2500,1870,2900),'#6a9786');rect((1200,2530,1840,2870),'#78a9a0')
for yy in range(2550,2870,45):rect((1210,yy,1830,yy+4),'#9cc2ad')
for xx in range(1440,1570,16):rect((xx,2490,xx+13,2900),'#aa784d')
for xx,yy in [(1170,3260),(1610,3260),(1170,3640),(1610,3640)]:
 rect((xx,yy,xx+360,yy+270),'#c0aa80')
 for i in range(80):
  a=random.randrange(xx,xx+355);b=random.randrange(yy,yy+265);rect((a,b,a+5,b+10),'#758b4a')
im.resize((w,h),NEAR).save(V/'ground.png')
# Matching indoor floor: source tile / panel / window fragments; furniture uses the original sprite pack.
src=Image.open(P/'guest_floor.png').convert('RGBA');tile=src.crop((149,185,220,235));wall=src.crop((90,0,300,62));base=Image.new('RGBA',(600,600),'#513922')
for yy in range(65,580,50):
 for xx in range(10,590,71):base.alpha_composite(tile,(xx,yy))
base.alpha_composite(wall.resize((580,90),NEAR),(10,8));db=ImageDraw.Draw(base);db.rectangle((0,0,9,599),fill='#6b4828');db.rectangle((590,0,599,599),fill='#6b4828');db.rectangle((0,580,244,599),fill='#916132');db.rectangle((354,580,599,599),fill='#916132');base.save(V/'interior.png')
# Wooden stair flight, actual traversable portal in every two-storey interior.
st=Image.new('RGBA',(85,150));sd=ImageDraw.Draw(st)
for j in range(10):sd.rectangle((5,j*13+5,77,j*13+17),fill='#916034',outline='#513925');sd.line((7,j*13+6,76,j*13+6),fill='#d4a360',width=2)
sd.rectangle((0,0,5,147),fill='#5c4227');sd.rectangle((78,0,84,147),fill='#5c4227');st.save(V/'stairs.png')
# Existing small fruit-tree sprite extracted as a transparent sprite from the approved garden.
garden=Image.open(P/'garden.png').convert('RGBA');tree=garden.crop((865,140,1115,420));mask=Image.new('L',tree.size);md=ImageDraw.Draw(mask);md.polygon([(8,100),(25,50),(80,5),(180,0),(242,62),(245,180),(185,230),(162,275),(111,275),(97,215),(38,205),(0,165)],fill=255);tree.putalpha(mask);tree.resize((150,168),NEAR).save(V/'fruit_tree.png')
# Readable notice-board sprite, plant pots and benches retain existing source detail.
board=Image.new('RGBA',(76,95));bd=ImageDraw.Draw(board);bd.rectangle((10,5,67,63),fill='#644322');bd.rectangle((15,10,62,58),fill='#e5cf98');bd.rectangle((15,64,20,92),fill='#644322');bd.rectangle((58,64,63,92),fill='#644322')
for yy in [21,31,41]:bd.rectangle((24,yy,53,yy+2),fill='#987a4a')
board.save(V/'board.png')
def hot(id,label,x,y,kind='village',**kw):return dict(id=id,label=label,pos=[x,y-30],approach=[x,y],kind=kind,**kw)
def door(id,label,target,x,y,face='down'):return dict(id=id,label=label,target=target,pos=[x,y-22],approach=[x,y],face=face,kind='door',width=60,explicit_opening=True)
def cfg(id,title,outdoor=False,size=[600,600]):return dict(id=id,title=title,group='村庄',floor=0,size=size,background='res://ayu_home/v4/assets/village/interior.png',asset_root='res://ayu_home/v3/assets/',props=[],obstacles=[],hotspots=[],doors=[],anchors={},windows=[],lamps=[[300,280,280]],source_offset=[0,0],spawn=[300,490],walk_rect=[22,100,556,478],outdoor=outdoor,view_scale=1.2)
def prop(c,id,file,pos,foot=None):c['props'].append(dict(id=id,file=file,pos=pos,foot=foot if foot else pos[1]+65))
manifest=json.loads((A/'rooms.json').read_text());rooms=manifest['rooms'];world=cfg('village','裳泓村',True,[w,h]);world.update(background='res://ayu_home/v4/assets/village/ground.png',spawn=[1560,1555],walk_rect=[30,30,w-60,h-60],nav_cell=16,lamps=[],view_scale=1.15)
index=[]
for id,title,sub,typ,floors,x,y,line,action,result in houses:
 target='exterior' if id=='ayu' else 'v_'+id
 prop(world,id,f'res://ayu_home/v4/assets/village/lot{typ}.png',[x,y],y+575)
 world['obstacles'].append([x+20,y+20,760,565]);gate=[x+400,y+670];world['doors'].append(door('visit_'+id,'拜访'+title,target,*gate))
 index.append(dict(id=id,title=title,subtitle=sub,floors=floors,at=gate,target=target,fictional=id not in ['ayu','erba','daba','laowu']))
 # Yard furniture, tree species and roadside flowers are seasonal independently of walls.
 for dx in [-5,725]:prop(world,'tree_'+id+str(dx),'res://ayu_home/v4/assets/village/fruit_tree.png',[x+dx,y+490],y+645);world['props'][-1]['plant_type']='fruit'
 if id=='ayu':continue
 c=cfg(target,title+' · 一楼');c['doors']=[door('outside','回到村路','village',300,554,'up')];c['hotspots']=[hot('resident_note','门边的生活便签',115,420,copy=line),hot('house_help',action,420,390,copy=result,house=id),hot('tea_seat','坐一会儿',290,320,'seat',seat=[290,295],face='down')]
 prop(c,'table','res://ayu_home/v4/assets/floor1-redraw/living-table.png',[245,210],287);c['obstacles'].append([244,235,100,48])
 prop(c,'cabinet','res://ayu_home/v4/assets/floor1-redraw/workshop-cabinet.png',[40,108],200);c['obstacles'].append([42,139,95,55])
 prop(c,'plant','exterior_pot_window_left.png',[435,142],202)
 if id in ['h3','daba','h7']:prop(c,'workbench','res://ayu_home/v4/assets/floor1-redraw/workshop-bench.png',[180,105],190);c['obstacles'].append([180,135,120,48])
 else:prop(c,'sofa','res://ayu_home/v4/assets/floor1-redraw/living-sofa.png',[180,118],205);c['obstacles'].append([190,160,130,50])
 if floors==2:
  prop(c,'stairs','res://ayu_home/v4/assets/village/stairs.png',[489,100],245);c['doors'].append(door('upstairs','上二楼',target+'_up',530,280))
  up=cfg(target+'_up',title+' · 二楼');up['doors']=[door('downstairs','下到一楼',target,530,280)];up['spawn']=[460,340];prop(up,'stairs','res://ayu_home/v4/assets/village/stairs.png',[489,100],245);prop(up,'bed','guest_bed.png',[58,115],330);up['obstacles']=[[60,150,170,195]]
  up['hotspots']=[hot('window_note','看看窗边书页',365,250,copy=sub+'。窗外的路通往每一位邻居；回来时书签还在这里。'),hot('rest_seat','在床边歇脚',170,410,'seat',seat=[170,365],face='down')];rooms[up['id']]=up
 if id=='h3':c['hotspots'].append(hot('mill','青叔 · 石磨和订单',380,450));c['npc']={'name':'青叔','pos':[380,430],'preset':1}
 if id=='h5':c['hotspots'].append(hot('honey','阿禾 · 养蜂人的小事',380,450));c['npc']={'name':'阿禾','pos':[380,430],'preset':4}
 if id=='mayor':c['hotspots'].append(hot('mayor','林伯 · 申请住下',380,450));c['npc']={'name':'林伯','pos':[380,430],'preset':0}
 rooms[target]=c
# Public places connect to the same common inventory. These sprites come from the approved house pack.
for id,label,x,y in [('mayor','村长林伯',1590,2330),('honey','阿禾 · 蜂蜜箱',1200,2970),('pond','池塘 · 喂鱼',1730,2860),('chicken','鸡圈 · 添谷子',1810,3030),('orchard','村里的果树',1180,3140),('market','村口货郎',930,3980),('home_site','看看自己的地',1530,3630),('map','村里的路牌',1970,1610)]:world['hotspots'].append(hot(id,label,x,y))
prop(world,'honeybox','exterior_beehive_1.png',[1150,2900],2950);prop(world,'notice','res://ayu_home/v4/assets/village/board.png',[1925,1515],1610)
for i in range(4):prop(world,'orchard'+str(i),'res://ayu_home/v4/assets/village/fruit_tree.png',[1110+i*160,3020],3170);world['props'][-1]['plant_type']='fruit'
world['npcs']=[{'id':'mayor','name':'林伯','pos':[1590,2300],'preset':0},{'id':'honey','name':'阿禾','pos':[1200,2940],'preset':4},{'id':'mill','name':'青叔','pos':[680,2385],'preset':1},{'id':'market','name':'货郎','pos':[930,3950],'preset':3}]
world['hotspots'].append(hot('mill','青叔 · 磨坊小事',680,2415))
rooms['village']=world
# Physical personal site and cabin: one state, four locations; no family house sold to the player.
yard=cfg('my_yard','自己的小院',True,[1050,900]);yard.update(background='res://ayu_home/v3/assets/exterior_floor.png',spawn=[550,735],walk_rect=[280,450,600,390],view_scale=1.25);yard['doors']=[door('village','回村里走走','village',550,815,'up'),door('cabin','进自己的小屋','my_cabin',500,480)]
prop(yard,'cabin','res://ayu_home/v4/assets/village/lot5.png',[100,-80],450);yard['hotspots']=[hot('yard','布置与开地',680,615),hot('farm','自留地与动物帮忙',365,680)];rooms['my_yard']=yard
c=cfg('my_cabin','自己的小屋');c['doors']=[door('yard','到自己的院子','my_yard',300,554,'up')];c['hotspots']=[hot('yard','摆放家具',370,390),hot('diary','写在这里的日子',150,330),hot('rest_seat','坐在床边',140,430,'seat',seat=[140,390],face='down')];prop(c,'bed','guest_bed.png',[55,105],325);c['obstacles']=[[60,150,170,190]];rooms['my_cabin']=c
# Natural connection: existing Ayu exterior remains identical, original south exit joins the whole village.
for dr in rooms['exterior']['doors']:
 if dr['id']=='to_side_path':dr['target']='village';dr['label']='走到村路上'
# Keep side-path, bridge, garden and all existing games reachable from the original home map.
for k,v in rooms.items():(A/(k+'.json')).write_text(json.dumps(v,ensure_ascii=False,indent=2))
(A/'rooms.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2));(V/'houses.json').write_text(json.dumps(index,ensure_ascii=False,indent=2))
(R/'交付/完整村庄-1006/房屋及互动清单.json').write_text(json.dumps({k:{'title':v['title'],'doors':v['doors'],'interactions':v['hotspots']} for k,v in rooms.items() if k.startswith('v_') or k in ['exterior','village','my_yard','my_cabin']},ensure_ascii=False,indent=2))
print('Built',len(index),'village lots,',len(rooms),'total areas; PNGs',len(list(V.glob('*.png'))))
