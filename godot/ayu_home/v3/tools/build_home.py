#!/usr/bin/env python3
"""Build v3 rooms using integer crops of references and the retained first-floor remaster candidate.
Generated corrections are composited only inside the explicitly authorized masks.
Room padding clones a tile from that same room; it never contains a neighbouring room.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageChops
import json, hashlib, shutil, importlib.util
# Keep byte-identical PNGs untouched so a repeated build does not reimport every room.
_save_png=Image.Image.save
def save_if_changed(self,fp,*args,**kw):
 if isinstance(fp,(str,Path)) and str(fp).endswith('.png') and Path(fp).exists():
  try:
   with Image.open(fp) as previous:
    if previous.size==self.size and previous.mode==self.mode and previous.tobytes()==self.tobytes():return
  except OSError:pass
 return _save_png(self,fp,*args,**kw)
Image.Image.save=save_if_changed
V=Path(__file__).resolve().parents[1]; A=V/'assets'; E=V/'evidence'; G=V.parents[1]
REF=G.parents[1]/'七缘地图2-裳泓村参考图/定稿形象图'
def dump(p,x):
 text=json.dumps(x,ensure_ascii=False,indent=2)+'\n'
 if not p.exists() or p.read_text()!=text:p.write_text(text)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
sources=[Image.open(REF/n).convert('RGBA') for n in ['阿鱼家123.png','5-阿鱼家一楼平面图 2.png','5-阿鱼家二楼平面图 2.png']]
# Clear reconstruction permitted by the brief; keep untouched approved source for comparison.
sources[1].save(A/'floor1-original.png',optimize=True)
sources[1]=Image.open(A/'floor1-clear-source.png').convert('RGBA')
sources[1].save(A/'floor1-clear.png',optimize=True)
# Keep the generated full frames for provenance, but ship only allowed corrected pixels.
repairs={0:[(754,492,807,588)],2:[(30,0,489,65),(51,204,184,243),(96,402,214,443),(383,375,450,411),(686,293,760,329),(1091,279,1181,316),(848,422,909,457),(958,420,1013,452),(1059,437,1160,472),(1233,437,1342,474),(550,670,663,710),(1121,698,1226,737),(1360,708,1442,748),(1143,951,1226,988)]}
for idx,file in [(0,'door-repair-source.png'),(2,'labels-repair-source.png')]:
 repair=Image.open(A/file).convert('RGBA');mask=Image.new('L',sources[idx].size)
 for r in repairs[idx]:sources[idx].paste(repair.crop(r),r[:2]);ImageDraw.Draw(mask).rectangle(r,fill=255)
 mask.save(E/f'allowed-edit-mask-{idx}.png');sources[idx].save(A/f'approved-{idx}.png',optimize=True)
# Pure extraction/adaptation of earlier lossless prop masks for the three existing spaces.
spec=importlib.util.spec_from_file_location('original',V.parent/'v2/tools/restore_original.py');old=importlib.util.module_from_spec(spec);spec.loader.exec_module(old)
old.A=A;old.E=E/'restoration';old.E.mkdir(exist_ok=True)
rooms={}
class Room:
 def __init__(self,id,title,floor,crop,tile,walk,spawn,poly=None):
  self.id=id;self.floor=floor;self.crop=crop;self.src=sources[floor];self.ox,self.oy=crop[:2]
  w,h=crop[2]-crop[0],crop[3]-crop[1];self.off=((max(320,w)-w)//2,48);self.size=(max(320,w),max(600,h+96))
  self.original=self.src.crop(crop);self.tile=self.src.crop(tile)
  self.canvas=Image.new('RGBA',self.size)
  for y in range(0,self.size[1],self.tile.height):
   for x in range(0,self.size[0],self.tile.width):self.canvas.paste(self.tile,(x,y))
  if poly:
   mask=Image.new('L',(w,h));ImageDraw.Draw(mask).polygon([(x-self.ox,y-self.oy) for x,y in poly],fill=255);self.canvas.paste(self.original,self.off,mask)
  else:self.canvas.paste(self.original,self.off)
  # Padding is same-floor pixel texture; thin edge in source wall palette bounds each independent space.
  wall=self.src.getpixel((crop[0]+4,crop[1]+4));d=ImageDraw.Draw(self.canvas)
  d.rectangle((0,0,self.size[0]-1,10),fill=wall);d.rectangle((0,self.size[1]-10,self.size[0],self.size[1]),fill=wall)
  if self.off[0]>=8:
   d.rectangle((0,0,7,self.size[1]),fill=wall);d.rectangle((self.size[0]-8,0,self.size[0],self.size[1]),fill=wall)
  self.cfg=dict(id=id,title=title,floor=floor,group='一楼' if floor==1 else '二楼',size=list(self.size),source_crop=list(crop),source_offset=list(self.off),background=id+'_floor.png',props=[],obstacles=[],hotspots=[],doors=[],windows=[],lamps=[],anchors={},walk_polygons=[],walk_rect=self.rect(walk),spawn=self.pt(spawn),camera_ahead=45,outdoor=False)
  if poly:self.cfg['source_polygon']=poly
  rooms[id]=self.cfg
 def pt(self,p):return [p[0]-self.ox+self.off[0],p[1]-self.oy+self.off[1]]
 def rect(self,r):return self.pt(r[:2])+list(r[2:])
 def prop(self,name,r,foot,ob=None):
  x,y,w,h=r;im=self.src.crop((x,y,x+w,y+h));file=self.id+'_'+name+'.png';im.save(A/file,optimize=True)
  self.cfg['props'].append(dict(id=name,file=file,pos=self.pt([x,y]),foot=foot-self.oy+self.off[1],front=False))
  # Replace only hidden backing with original floor pixels; composite remains identical.
  fill=Image.new('RGBA',(w,h))
  for iy in range(0,h,self.tile.height):
   for ix in range(0,w,self.tile.width):fill.paste(self.tile,(ix,iy))
  self.canvas.paste(fill,self.pt([x,y]))
  if ob:self.cfg['obstacles'].append(self.rect(ob))
 def hot(self,id,label,p,approach,kind='reaction',effect='spark',copy=''):
  self.cfg['hotspots'].append(dict(id=id,label=label,pos=self.pt(p),approach=self.pt(approach),kind=kind,effect=effect,copy=copy))
 def anchor(self,id,p):self.cfg['anchors'][id]=self.pt(p)
 def light(self,p,r=150):self.cfg['lamps'].append(self.pt(p)+[r])
 def window(self,r):self.cfg['windows'].append(self.rect(r))
 def finish(self):
  self.canvas.save(A/(self.id+'_floor.png'),optimize=True)
  comp=self.canvas.copy()
  for p in sorted(self.cfg['props'],key=lambda x:x['foot']):comp.alpha_composite(Image.open(A/p['file']),p['pos'])
  comp.convert('RGB').save(E/(self.id+'-assembly.png'),optimize=True)
  dump(A/(self.id+'.json'),self.cfg)
R={}
def room(*args,**kw):r=Room(*args,**kw);R[r.id]=r;return r
# Existing living/dining keep the approved pixel masks and obstruction model, without the old incorrect door approaches.
for fun,idx in [(old.living,1),(old.dining,1)]:
 s,files=fun(sources[idx]);c=s.j;id=s.name
 c.update(id=id,title={'living':'客厅','dining':'餐厅'}[id],group='一楼',floor=1,outdoor=False,doors=[],background=id+'_floor.png')
 for h in c['hotspots']:h.update(kind={'fish':'fish','tv':'tv','album':'album','recipe':'puzzle'}.get(h['id'],'reaction'),effect={'lamp':'lamp','sofa':'sit','meal':'sit','tea':'steam','cook':'steam'}.get(h['id'],'spark'),copy='')
 c['hotspots']=[h for h in c['hotspots'] if h['id'] not in ['dining','exit','living','cook']]
 # Centered padding makes a constant 2x camera possible even in tall phone aspect.
 im=Image.open(A/(id+'_floor.png'));pad=(max(320,im.width)-im.width)//2;off=[pad,48];sz=[max(320,im.width),max(600,im.height+96)]
 tile=sources[1].crop((842,582,921,661));base=Image.new('RGBA',sz)
 for y in range(0,sz[1],tile.height):
  for x in range(0,sz[0],tile.width):base.paste(tile,(x,y))
 base.paste(im,tuple(off));base.save(A/(id+'_floor.png'),optimize=True)
 for p in c['props']:p['pos']=[p['pos'][0]+off[0],p['pos'][1]+off[1]];p['foot']+=off[1]
 for key in ['spawn','steam']:
  if key in c:c[key]=[c[key][0]+off[0],c[key][1]+off[1]]
 for key in ['walk_rect','fish_rect','tv_rect']:
  if key in c:c[key][:2]=[c[key][0]+off[0],c[key][1]+off[1]]
 for key in ['obstacles','windows','lamps']:
  for ar in c.get(key,[]):ar[:2]=[ar[0]+off[0],ar[1]+off[1]]
 for h in c['hotspots']:
  for key in ['pos','approach']:h[key]=[h[key][0]+off[0],h[key][1]+off[1]]
 for key,ar in c['anchors'].items():c['anchors'][key]=[ar[0]+off[0],ar[1]+off[1]]
 c.update(size=sz,source_offset=off[:2]);rooms[id]=c
 # Doors are reached in the clear band directly under the original opening.
 if id=='living':c['walk_rect']=[22,108,436,280];c['obstacles'][0]=[110,180,168,22] # sofa left doorway gap is preserved
 else:c['walk_rect']=[19,157,268,207]
# Integer source rectangles. Small rooms retain their original dimensions inside same-palette padding.
k=room('kitchen','厨房',1,(130,26,408,193),(344,159,365,179),(171,151,210,32),(346,170))
k.prop('counter',(140,35,227,117),153,(140,126,226,26));k.hot('stove','煮一锅汤',(304,102),(321,170),'reaction','steam','小火咕嘟着，汤香慢慢飘出来。');k.hot('fridge','开冰箱',(164,91),(199,172),'reaction','open','冰箱亮起小灯，食材整齐地放着。');k.hot('sink','洗洗手',(234,101),(247,172),'reaction','water','水流落进水槽，洗完轻轻关好。');k.light((289,98));k.window((215,40,49,40));k.anchor('mother',(289,171))
l=room('laundry','卫生间与洗衣',1,(133,204,401,342),(269,282,291,301),(187,280,184,40),(350,307))
l.prop('washer',(143,276,49,56),330,(144,311,46,19));l.hot('wash','洗一筐衣服',(166,303),(209,310),'reaction','wash','洗衣机转起来了，泡泡绕着衣服转。');l.hot('basin','拧开水龙头',(324,249),(294,307),'reaction','water','洗干净双手，水声渐渐停了。');l.hot('towel','整理毛巾',(251,316),(274,310),'reaction','fold','把毛巾叠成整齐的小方块。');l.light((318,235));l.anchor('mother',(253,310))
c=room('cats','猫房',1,(708,77,874,325),(775,257,797,273),(723,245,131,64),(827,288))
for i,(id,label,p) in enumerate([('nest','猫窝',(753,235)),('scratch','猫抓柱',(813,254)),('bowls','添水和猫粮',(779,285))]):c.hot(id,label,p,(750+i*38,292),'reaction',['pet','spark','food'][i],['猫窝软软的，等它们睡醒再摸摸。','轻轻拨动逗猫绳。','水碗添满了，三只猫都围过来。'][i])
c.light((782,129));c.anchor('qiuqiu',(747,231));c.anchor('luoluo',(795,238));c.anchor('tiantian',(786,286))
s=room('stairs1','一楼楼梯与过道',1,(874,40,1144,489),(885,271,928,317),(880,261,248,212),(953,313),poly=[(874,40),(1035,40),(1035,337),(1057,337),(1057,298),(1119,298),(1119,390),(1143,390),(1143,420),(1119,420),(1119,489),(1057,489),(1057,401),(1018,401),(1018,340),(874,340)])
s.cfg['walk_polygons']=[[s.pt(p) for p in [(880,261),(1017,261),(1017,352),(1080,352),(1080,302),(1113,302),(1113,422),(1127,422),(1127,477),(1058,477),(1058,374),(955,374),(955,330),(880,330)]]]
s.hot('rail','摸摸木扶手',(972,194),(985,285),'reaction','spark','木扶手被日常摸得很光滑。');s.hot('plant','浇一小杯水',(887,225),(898,281),'reaction','water','水慢慢渗进泥土。');s.hot('picture','看看小画',(945,68),(964,279),'reaction','picture','一幅没有题字的小画。');s.light((940,83));s.anchor('father',(991,297))
m=room('mahjong','茶桌与麻将室',1,(1050,30,1391,310),(1337,167,1366,192),(1074,129,294,155),(1100,269))
m.prop('table',(1121,134,185,140),266,(1150,204,112,42));m.hot('tea','沏茶',(1202,92),(1300,132),'reaction','steam','只摆茶杯，坐下来喝茶聊天。');m.hot('chair','坐下聊会儿',(1119,205),(1097,214),'reaction','sit','在茶桌旁坐了一会儿。');m.hot('plant','照顾绿植',(1330,99),(1332,162),'reaction','water','叶子上落了几滴水。');m.light((1205,75));m.anchor('father',(1123,252));m.anchor('mother',(1301,250))
p=room('parents','爸妈卧室',1,(1056,430,1406,705),(1085,519,1110,552),(1070,495,317,181),(1092,554))
p.prop('bed',(1129,465,134,159),622,(1132,519,132,100));p.hot('lamp','开关床头灯',(1138,496),(1100,533),'reaction','lamp','床头灯暖暖地亮着。');p.hot('bed','把被子铺好',(1196,549),(1282,575),'reaction','fold','拉平被角，枕头也摆整齐。');p.hot('window','听听窗外',(1210,699),(1305,660),'reaction','window','窗外有风，窗帘轻轻晃动。');p.light((1139,488));p.window((1155,698,147,40));p.anchor('father',(1170,557));p.anchor('mother',(1224,558))
w=room('workshop','爸爸的手作房',1,(70,365,228,747),(116,581,163,611),(109,537,100,152),(163,654))
w.prop('bench',(81,376,135,184),560,(86,503,92,58));w.hot('wood','磨一只木鸟',(145,494),(163,583),'workbench');w.hot('tools','收好工具',(141,435),(193,560),'reaction','tools','工具一件件挂回自己的位置。');w.hot('lamp','工作台小灯',(155,392),(193,581),'reaction','lamp','工作台被暖光照亮了。');w.light((154,392));w.anchor('father',(146,575))
g=room('garage','车库',1,(254,350,535,802),(491,577,520,636),(267,392,253,305),(493,674))
g.prop('car',(318,418,162,278),693,(329,495,148,191));g.hot('car','擦一擦车窗',(399,466),(496,493),'reaction','wipe','车窗映出一点明亮的天光。');g.hot('bike','转转自行车铃',(295,552),(289,629),'reaction','bell','叮铃，车铃清清脆脆。');g.hot('shelf','整理杂物架',(507,414),(496,456),'reaction','tools','杂物架空出一个整齐的小角落。');g.light((298,381));g.anchor('father',(288,456))
cl=room('closet1','一楼衣柜间',1,(1115,307,1220,422),(1168,400,1190,412),(1129,385,76,29),(1149,400))
for i,(id,name,pos) in enumerate([('hang','挂好外套',(1160,348)),('drawer','打开抽屉',(1190,385)),('tidy','整理衣柜',(1150,383))]):cl.hot(id,name,pos,(1138+i*24,402),'reaction',['fold','open','fold'][i],'衣服和小物各归其位。')
cl.light((1160,330))
b=room('bath1','一楼浴室',1,(1226,306,1410,421),(1287,386,1310,406),(1236,377,153,35),(1295,398))
for id,name,pos,ap,fx,txt in [('sink','洗手台',(1254,351),(1292,399),'water','细细的水流落下。'),('shower','打开淋浴',(1371,348),(1349,399),'water','水珠敲着玻璃，随后关好。'),('towel','整理浴巾',(1331,400),(1310,399),'fold','浴巾叠好，留在伸手就能拿到的地方。')]:b.hot(id,name,pos,ap,'reaction',fx,txt)
b.light((1354,328))
# Upstairs.
gu=room('guest','客房',2,(221,99,626,535),(527,373,568,426),(247,204,355,229),(577,413))
gu.prop('bed',(324,151,174,220),368,(332,228,160,132));gu.hot('bed','躺下休息',(409,292),(512,367),'relax');gu.hot('lamp','开关床头灯',(306,164),(281,222),'reaction','lamp','床头灯晕开一圈暖色。');gu.hot('book','翻一本书',(584,184),(569,228),'reaction','book','翻过一页，纸张沙沙地响。');gu.light((306,165));gu.window((296,456,224,44))
gc=room('guest_closet','客房衣帽间',2,(54,102,226,292),(138,264,154,280),(74,232,119,45),(177,253))
for i,(id,label,p) in enumerate([('coat','挂外套',(116,159)),('bag','整理旅行包',(112,262)),('basket','放好收纳盒',(168,251))]):gc.hot(id,label,p,(87+i*43,264),'reaction','fold' if i!=1 else 'open','给下一次来做客的人留个干净的位置。')
gc.light((163,146))
gb=room('guest_bath','客房浴室',2,(49,320,245,477),(136,427,173,446),(104,393,112,53),(199,432))
for i,(id,label,p) in enumerate([('water','拧开水龙头',(189,357)),('shower','试试温水',(86,372)),('plant','给盆栽浇水',(69,444))]):gb.hot(id,label,p,(124+i*35,435),'reaction','water','水声轻轻响起，又慢慢停下。')
gb.light((199,339))
st=room('stairs2','二楼楼梯与过道',2,(641,98,1027,547),(865,350,895,380),(658,327,350,191),(891,364),poly=[(647,103),(919,103),(919,396),(1024,397),(1024,546),(956,546),(956,462),(819,462),(819,518),(646,458)])
st.hot('rail','木扶手',(788,253),(847,339),'reaction','spark','沿着扶手，慢慢上下楼。');st.hot('fern','照顾楼梯绿植',(810,307),(849,346),'reaction','water','叶片接住几滴水。');st.hot('table','过道的小花',(759,376),(799,420),'reaction','spark','花朵在过道里晒太阳。');st.light((817,211));st.anchor('mother',(865,426))
sd=room('study','书房',2,(951,99,1374,395),(965,237,990,271),(975,245,377,93),(1058,306),poly=[(951,99),(1374,99),(1374,368),(1020,368),(1020,395),(951,395)])
sd.prop('desk',(1016,137,215,112),247,(1026,207,190,36));sd.hot('computer','阿鱼的书桌',(1115,163),(1126,284),'detail');sd.hot('guitar','弹一首小旋律',(1295,166),(1255,296),'guitar');sd.hot('puzzle','书架里的拼图',(986,199),(1004,290),'puzzle');sd.hot('chair','靠窗读书',(1294,274),(1258,315),'reaction','book','靠在小椅上，慢慢读两页。');sd.light((1049,149));sd.light((1329,264));sd.anchor('ayu',(1100,262));sd.anchor('father',(1215,285))
ac=room('closet2','阿鱼的衣柜',2,(1025,369,1163,511),(1072,482,1087,498),(1036,458,112,40),(1085,487))
for i,(id,label,p) in enumerate([('hanger','挑一件外套',(1106,411)),('drawer','看看抽屉',(1133,487)),('clothes','叠好换洗衣服',(1068,479))]):ac.hot(id,label,p,(1050+i*38,489),'reaction','fold' if i!=1 else 'open','整理好了，关上时轻一点。')
ac.light((1103,391))
ab=room('bath2','阿鱼的浴室',2,(1174,369,1386,510),(1258,456,1272,470),(1191,444,171,47),(1269,478))
for i,(id,label,p) in enumerate([('basin','洗手',(1198,452)),('shower','淋浴水声',(1334,417)),('mat','晒晒浴垫',(1271,488))]):ab.hot(id,label,p,(1203+i*63,483),'reaction','water' if i<2 else 'fold','把日常的小事慢慢做好。')
ab.light((1201,397))
a=room('ayu_room','阿鱼卧室',2,(966,532,1392,964),(1279,750,1313,798),(984,580,386,280),(1016,632))
a.prop('bed',(1043,584,198,236),817,(1072,666,158,145));a.hot('bunny','摸摸兔子玩偶',(1204,779),(1249,809),'reaction','bunny','兔子玩偶轻轻晃了晃耳朵。');a.hot('mirror','梳妆镜',(1363,785),(1310,812),'reaction','mirror','镜子里映出房间的粉色与暖光。');a.hot('lamp','开关床头灯',(1054,581),(1029,643),'reaction','lamp','小灯亮起来了。');a.hot('window','看一眼窗外',(1170,909),(1277,851),'reaction','window','窗外的花随着风轻轻动。');a.light((1055,584));a.light((1250,584));a.window((1098,880,166,45));a.anchor('ayu',(1135,731))
t=room('terrace','二楼露台',2,(31,490,940,1037),(507,574,551,616),(98,540,806,380),(839,591))
t.prop('umbrella',(208,589,233,226),799,(226,724,183,74));t.prop('lounge',(324,767,125,110),877,(330,831,112,38));t.hot('tea','露台喝茶',(424,726),(472,767),'reaction','steam','端着一杯温茶，听听风。');t.hot('stars','躺椅上看星星',(384,816),(492,857),'stars');t.hot('flower','照顾花盆',(174,603),(214,590),'reaction','water','花盆里的泥土润湿了。');t.hot('bench','看看村子',(480,909),(558,870),'reaction','sit','坐下来，远处的村子安安静静。');t.light((905,904));t.anchor('ayu',(558,870))
# World-space conversion shared by routes/hotspots; never guess at runtime.
def pt(id,p):
 c=rooms[id];o=c.get('source_offset',[0,0]);cr=c.get('source_crop',[0,0]);return [p[0]-cr[0]+o[0],p[1]-cr[1]+o[1]]
def link(a,b,pa,pb,fa='down',fb='down',label_a='',label_b='',ka='door',kb='door'):
 for aa,bb,p,f,lab,kind in [(a,b,pa,fa,label_a,ka),(b,a,pb,fb,label_b,kb)]:
  rooms[aa]['doors'].append(dict(id='to_'+bb,target=bb,pos=pt(aa,p),approach=pt(aa,p),face=f,label=lab or ('去'+rooms[bb]['title']),kind=kind))
# Painted door anchors where available. Inferred bathroom/back-door connections are disclosed in the handoff.
link('living','dining',(650,410),(649,323),'down','up')
link('living','stairs1',(943,410),(954,312),'down','up')
link('dining','kitchen',(423,173),(371,173),'right','left')
link('dining','laundry',(423,284),(361,308),'right','left')
link('dining','garage',(444,322),(445,403),'up','down')
link('stairs1','cats',(891,285),(838,286),'right','left')
link('stairs1','mahjong',(1091,315),(1104,271),'down','up')
link('stairs1','parents',(1090,419),(1095,488),'up','down')
link('stairs1','closet1',(1102,404),(1141,399),'left','right')
link('closet1','bath1',(1191,400),(1239,399),'left','right')
link('stairs1','stairs2',(947,267),(855,338),'down','down','上二楼','下一楼','stairs','stairs')
link('stairs2','guest',(666,421),(578,413),'right','left')
link('guest','guest_closet',(259,256),(181,262),'right','left')
link('guest','guest_bath',(260,418),(200,433),'right','left')
link('stairs2','study',(986,418),(1029,316),'down','up')
link('stairs2','closet2',(1003,477),(1043,485),'left','right')
link('closet2','bath2',(1138,483),(1200,482),'left','right')
link('stairs2','ayu_room',(983,502),(1010,618),'up','down')
link('stairs2','terrace',(861,502),(846,563),'up','down')
# The complete courtyard is the original painting. A narrow off-canvas strip continues the road to the bridge.
ex,files=old.exterior(sources[0]);c=ex.j;c.update(id='exterior',title='门前院子',group='屋外',outdoor=True,floor=0,background='exterior_floor.png',doors=[],source_offset=[0,0]);rooms['exterior']=c
c['hotspots']=[h for h in c['hotspots'] if h['id'] in ['xiduo','bench','flowers']]
for h in c['hotspots']:h.update(kind='reaction',effect='sit' if h['id']=='bench' else 'pet' if h['id']=='xiduo' else 'spark',copy='喜多在自己的院子里。' if h['id']=='xiduo' else '在家门前慢慢待一会儿。')
# Outdoor routes remain separate focused spaces; each image is a lossless region of the same exterior.
def outdoor(id,title,crop,walk,spawn):
 im=sources[0].crop(crop);im.save(A/(id+'_floor.png'),optimize=True)
 c=dict(id=id,title=title,group='屋外',floor=0,outdoor=True,background=id+'_floor.png',source_crop=list(crop),source_offset=[0,0],size=list(im.size),props=[],obstacles=[],hotspots=[],doors=[],windows=[],lamps=[],anchors={},walk_rect=[walk[0]-crop[0],walk[1]-crop[1],walk[2],walk[3]],walk_polygons=[],spawn=[spawn[0]-crop[0],spawn[1]-crop[1]],camera_ahead=80)
 rooms[id]=c;return c
outdoor('side_path','院外小道',(0,790,1448,1086),(80,956,1338,79),(742,995))
outdoor('bridge','溪边小桥',(1090,410,1448,1086),(1258,552,181,98),(1384,610))
outdoor('oldhouse','老屋门口',(1070,0,1448,545),(1200,199,213,296),(1392,427))
rooms['oldhouse']['walk_polygons']=[[[1200-1070,199],[1260-1070,199],[1413-1070,401],[1413-1070,495],[1391-1070,495],[1297-1070,326],[1200-1070,235]]]
for id,items in {'side_path':[('leaf','路边的落叶',(532,1008),'spark','收起一片落叶，夹进生活册。'),('flower','小路边的野花',(230,966),'water','野花把头抬起来了。'),('listen','听溪水',(1183,1005),'water','沿着小路，能听到远处流水。')],'bridge':[('water','听桥下的水',(1360,632),'water','水流绕过石头，荡开小小波纹。'),('fish','看看小鱼',(1345,561),'spark','小鱼从桥下游过去。'),('rail','靠一靠木栏杆',(1367,602),'sit','木桥被太阳晒得暖暖的。')],'oldhouse':[('knock','敲敲老屋的门',(1226,177),'bell','轻敲两下木门。老屋门口是这次散步最远的地方。'),('pot','门前的花盆',(1270,178),'water','给老屋门前的花浇一点水。'),('step','坐在老屋台阶',(1233,211),'sit','在这里坐一会儿，再沿原路回家。')]}.items():
 for hid,lab,p,fx,txt in items:
  ap=p if id=='side_path' else ((1355,613) if id=='bridge' else (1234,221))
  rooms[id]['hotspots'].append(dict(id=hid,label=lab,pos=pt(id,p),approach=pt(id,ap),kind='reaction',effect=fx,copy=txt))
# Backyard existing extension already uses the approved exterior's pixel language; seasonal assets are local.
for name in ['garden.png','garden_spring.png','garden_summer.png','garden_winter.png']:shutil.copy2(V.parent/'assets'/name,A/name)
size=list(Image.open(A/'garden.png').size)
rooms['garden']=dict(id='garden',title='后花园 · 果园 · 菜地',group='屋外',floor=0,outdoor=True,background='garden.png',size=size,source_crop=[0,0,*size],source_offset=[0,0],props=[],obstacles=[[590,251,173,91],[834,253,136,91],[1123,259,147,78],[586,553,175,84],[832,552,154,83],[1125,552,147,81]],hotspots=[],doors=[],windows=[],lamps=[[552,724,170]],anchors={'mother':[518,342],'father':[1014,319],'ayu':[788,735]},walk_rect=[460,111,835,909],walk_polygons=[],spawn=[738,938],camera_ahead=100)
for hid,lab,p,ap,kind,fx,txt in [('vegetables','给菜地浇水',(394,490),(497,493),'reaction','water','菜叶抖落了几滴水。'),('flowers','看看花田',(284,173),(500,181),'reaction','spark','花田里有细细的虫鸣。'),('bees','观察蜂箱',(321,111),(506,146),'reaction','bees','蜜蜂在花与蜂箱间来回忙碌。'),('fruit','照顾果树',(928,235),(1020,325),'reaction','fruit','果树跟着季节慢慢变化。'),('pond','看看溪边',(1221,786),(1138,719),'fish','water',''),('garden_play','照料一块小菜地',(257,700),(493,697),'garden','water','')]:rooms['garden']['hotspots'].append(dict(id=hid,label=lab,pos=list(p),approach=list(ap),kind=kind,effect=fx,copy=txt))
link('exterior','living',(783,647),(902,665),'down','up','进家门','回院子')
link('exterior','workshop',(286,610),(159,675),'down','up','进手作房','回到院子')
link('exterior','garage',(552,617),(495,680),'down','up','进车库','回到院子')
link('exterior','side_path',(742,969),(742,968),'up','down','走出院门','回院子')
link('exterior','garden',(161,628),(738,938),'right','up','沿侧门去后园','回院子')
link('kitchen','garden',(191,170),(545,711),'right','down','后门 · 去花园','从后门回厨房')
link('side_path','bridge',(1379,997),(1389,629),'left','up','沿溪去小桥','沿小道回家')
link('bridge','oldhouse',(1394,566),(1391,432),'down','up','沿小桥去老屋','回小桥')
link('garden','oldhouse',(1255,372),(1245,232),'left','down','沿果园小路去老屋','去果园')
# Visible marker sits on the painted door; its walking approach remains on clear floor.
door_visuals={
'living':{'dining':(647,371),'stairs1':(942,371),'exterior':(902,733)},
'dining':{'kitchen':(393,143),'laundry':(389,268),'garage':(445,369),'living':(646,371)},
'kitchen':{'dining':(391,139),'garden':(150,177)},'laundry':{'dining':(388,270)},
'stairs1':{'living':(957,336),'cats':(856,270),'mahjong':(1090,307),'parents':(1090,451),'closet1':(1123,404),'stairs2':(951,244)},
'mahjong':{'stairs1':(1090,273)},'parents':{'stairs1':(1090,459)},'closet1':{'stairs1':(1137,395)},
'garage':{'dining':(445,369),'exterior':(497,721)},'workshop':{'exterior':(145,706)},
'guest':{'stairs2':(606,412),'guest_closet':(223,232),'guest_bath':(235,416)},
'guest_closet':{'guest':(213,232)},'guest_bath':{'guest':(232,416)},
'stairs2':{'stairs1':(859,304),'guest':(657,416),'study':(985,368),'terrace':(862,509),'closet2':(1017,477),'ayu_room':(999,524)},
'study':{'stairs2':(983,364)},'ayu_room':{'stairs2':(999,565)},'terrace':{'stairs2':(861,535)},
'exterior':{'living':(782,553),'workshop':(285,549),'garage':(444,522),'side_path':(742,913),'garden':(155,609)}
}
for id,targets in door_visuals.items():
 for d in rooms[id]['doors']:
  if d['target'] in targets:d['pos']=pt(id,targets[d['target']])
# Three tangible interactions in dining/living, plus a fourth tea book in dining.
rooms['dining']['hotspots'].append(dict(id='flowers',label='照顾桌上的花',pos=pt('dining',(547,190)),approach=pt('dining',(449,201)),kind='reaction',effect='water',copy='给桌上的小花换一点清水。'))
# Reachable approaches and object drawing coordinates are separate and explicit.
for id,r in R.items():r.finish()
# The dining view includes its two door leaves, never the neighbouring aquarium or garage furniture.
c=rooms['dining'];cr=c['source_crop'];off=c['source_offset'];shape=[(390,16),(706,16),(706,350),(670,350),(670,401),(615,401),(615,353),(474,353),(474,401),(410,401),(410,353),(390,353)];c['source_polygon']=shape
mask=Image.new('L',tuple(c['size']),0);ImageDraw.Draw(mask).polygon([tuple(pt('dining',p)) for p in shape],fill=255)
base=Image.open(A/c['background']).convert('RGBA');tile=sources[1].crop((623,291,663,324));fill=Image.new('RGBA',base.size)
for yy in range(0,base.height,tile.height):
 for xx in range(0,base.width,tile.width):fill.paste(tile,(xx,yy))
fill.paste(base,(0,0),mask);fill.save(A/c['background'],optimize=True)
for prop in c['props']:
 im=Image.open(A/prop['file']).convert('RGBA');x,y=prop['pos'];cut=mask.crop((x,y,x+im.width,y+im.height));im.putalpha(ImageChops.multiply(im.getchannel('A'),cut));im.save(A/prop['file'],optimize=True)
for id,c in rooms.items():dump(A/(id+'.json'),c)
dump(A/'rooms.json',{'rooms':rooms,'order':list(rooms),'version':3})
# Maps display furniture, not the hidden backing layer.
for id,c in rooms.items():
 comp=Image.open(A/c['background']).convert('RGBA')
 for prop in sorted(c['props'],key=lambda x:x['foot']):comp.alpha_composite(Image.open(A/prop['file']),tuple(prop['pos']))
 comp.save(E/(id+'-assembly.png'),optimize=True)
 if not c['outdoor']:
  crop=c['source_crop'];off=c['source_offset'];comp=comp.crop((off[0],off[1],off[0]+crop[2]-crop[0],off[1]+crop[3]-crop[1]))
 comp.thumbnail((240,180),Image.Resampling.NEAREST);comp.save(A/('thumb_'+id+'.png'),optimize=True)

# Sprite atlas integration: trim only transparent margins and align all feet.
im=Image.open(A/'pets-source.png').convert('RGBA')
for row,id in enumerate(['qiuqiu','luoluo','tiantian','xiduo']):
 atlas=Image.new('RGBA',(64*4,64));stats=[]
 for col in range(4):
  cell=im.crop((int(col*im.width/4),int(row*im.height/4),int((col+1)*im.width/4),int((row+1)*im.height/4)))
  box=cell.getchannel('A').point(lambda v:255 if v>100 else 0).getbbox();cell=cell.crop(box)
  scale=min(59/cell.width,(50 if row<2 else 57)/cell.height);cell=cell.resize((round(cell.width*scale),round(cell.height*scale)),Image.Resampling.NEAREST)
  pos=(col*64+(64-cell.width)//2,62-cell.height);atlas.alpha_composite(cell,pos);stats.append({'column':col,'size':cell.size,'foot_y':62})
 atlas.save(A/(id+'.png'),optimize=True);dump(E/(id+'-alignment.json'),stats)
# Inventory includes approved room sources, correction masks and deterministic build recipes.
dump(V/'reference_manifest.json',{'files':[{'name':p.name,'source':str(p),'sha256':sha(p),'bytes':p.stat().st_size} for p in REF.iterdir() if p.suffix.lower() in ['.png','.jpg','.webp']]})
dump(E/'asset-edits.json',{'authorized_corrections':repairs,'masked_repairs_scope':'exterior and second floor ONLY; first floor is assessed separately','source_pixels_outside_correction_masks_changed':0,'room_count':len(rooms),'padding':'same-room floor tile, source layout remains fixed','sharpness':'precision clear reconstruction; not a pixel-identical restoration; see clarity-comparison.json'})
files={p.name:{'bytes':p.stat().st_size,'sha256':sha(p)} for p in A.iterdir() if p.suffix in ['.png','.json','.wav'] and p.name!='manifest.json' and not p.name.endswith('-source.png') and p.name not in ['approved-2.png','floor1-clear.png','floor1-original.png']}
dump(A/'manifest.json',{'version':3,'files':files,'total_bytes':sum(f['bytes'] for f in files.values()),'note':'Runtime file hashes; generated candidates and original-art comparisons are excluded.'})
print('Built',len(rooms),'spaces;',sum(len(c['hotspots']) for c in rooms.values()),'objects;',sum(len(c['doors']) for c in rooms.values()),'directed doorways')
