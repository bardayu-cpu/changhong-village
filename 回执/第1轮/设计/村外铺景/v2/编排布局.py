# coding: utf-8
"""C4 world-coordinate art layout only; no image editing and no production writes."""
from pathlib import Path
import json,math,random
from PIL import Image
R=Path(__file__).resolve().parent
PROJECT=R.parents[4]
C=json.loads((R/'受保护现状.json').read_text())
H=C['houses'];roads=C['roads'];P=C['base_props']
def seg(p,a,b):
 dx,dy=b[0]-a[0],b[1]-a[1];t=max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dy)/(dx*dx+dy*dy or 1)))
 return math.hypot(p[0]-a[0]-t*dx,p[1]-a[1]-t*dy)
def hit(a,b,pad=0):return a[0]<b[0]+b[2]+pad and a[0]+a[2]>b[0]-pad and a[1]<b[1]+b[3]+pad and a[1]+a[3]>b[1]-pad
vertices=[pt for line in roads for pt in line]
connectors=[[h['at'],[h['at'][0],h['at'][1]+36],min(vertices,key=lambda v:math.dist(v,h['at']))] for h in H]
lines=[(a,b) for line in roads+connectors for a,b in zip(line,line[1:])]
river=[[3570,0],[3550,900],[3450,1560],[3550,2100],[3520,2870],[3560,3520],[3510,4050],[3550,4700]]
protect=[h['bounds'] for h in H]+[C['dynamic_site']]
house_ids={h['id'] for h in H}|{'house_community'}
for p in P:
 if p['id'] in house_ids:continue
 fn=p['file'];path=PROJECT/'godot'/fn.removeprefix('res://') if fn.startswith('res://') else PROJECT/'godot/ayu_home/v3/assets'/fn
 with Image.open(path) as im:iw,ih=im.size
 sx,sy=p.get('scale',[1,1]);protect.append([*p['pos'],iw*sx,ih*sy])
approaches=[d['approach'] for d in C['doors']+C['hotspots']]
occupied=[]
def safe_rect(r,road=100,margin=16):
 x,y,w,h=r
 if x<12 or y<12 or x+w>4788 or y+h>4688 or any(hit(r,b,margin) for b in protect):return False
 for iy in range(math.ceil(h/24)+1):
  for ix in range(math.ceil(w/24)+1):
   p=(x+w*ix/max(1,math.ceil(w/24)),y+h*iy/max(1,math.ceil(h/24)))
   if any(seg(p,a,b)<road+12 for a,b in lines):return False
   if any(seg(p,a,b)<72 for a,b in zip(river,river[1:])):return False
   if any(math.dist(p,a)<92 for a in approaches):return False
 return True
fields=[]
# Exact authored districts, with different rows/aspects rather than an automatic grid scatter.
candidates=[('北巷长田',[1260,85,305,430],34,28,'dense'),('东田北块',[3020,855,325,340],38,32,'dense'),('东田南块',[3020,1250,300,405],42,34,'spaced'),('东岸长田',[3825,2120,510,215],36,30,'mixed'),('东岸南田',[3830,3300,625,255],40,30,'dense'),('村西菜田',[35,1930,390,125],34,28,'mixed'),('花巷苗圃',[1200,1000,200,140],31,26,'nursery'),('南巷菜田',[2420,3570,235,330],38,32,'spaced')]
for label,r,spacing,rowgap,kind in candidates:
 if safe_rect([r[0]-15,r[1]-15,r[2]+30,r[3]+30],90):
  x,y,w,h=r;poly=[[x+10,y],[x+w-12,y+5],[x+w,y+h-13],[x+w-8,y+h],[x+6,y+h-4],[x,y+14]]
  fields.append({'id':'c4_field_'+str(len(fields)),'label':label,'rect':r,'polygon':poly,'spacing':spacing,'row_gap':rowgap,'kind':kind,'rows':(h-42)//rowgap,'columns':(w-42)//spacing,'perimeter':poly+[poly[0]],'bank_width':16,'entry_gap':'south-west','crop_scale':.60 if kind=='nursery' else .69})
  occupied.append([r[0]-20,r[1]-20,r[2]+40,r[3]+40])
# Drainage is continuous around plot sides. Eastern outlets reach the actual river; other plots end in a small soak pit.
drains=[];paths=[]
for f in fields:
 x,y,w,h=f['rect'];path=[[x-20,y-12],[x+w+18,y-12],[x+w+18,y+h+17],[x-19,y+h+17]]
 if x>2800:
  yy=y+h//2;nearest=min(([round(a[0]+t*(b[0]-a[0])),round(a[1]+t*(b[1]-a[1]))] for a,b in zip(river,river[1:]) for t in [max(0,min(1,(yy-a[1])/(b[1]-a[1] or 1)))]),key=lambda q:abs(q[1]-yy))
  start=[x-20,yy] if x>3600 else [x+w+18,yy]
  # For east-bank plots take the near (west) plot edge, rather than cross through crops.
  if x>3600:path=[[x-20,y-12],[x-20,y+h+17],[x+w+18,y+h+17]]
  drains.append({'field':f['id'],'boundary_path':path,'outlet_path':[start,nearest],'width':13,'end':'river','walkable':'shallow','bank_collision':False})
 else:drains.append({'field':f['id'],'boundary_path':path,'outlet_path':[],'width':11,'end':'soak_pit','pit':[x-19,y+h+17,36,24],'walkable':True})
 goal=[x+w+29,y+h+33] if x<100 else [x-29,y+h+33]
 near_points=[]
 for a,b in [(a,b) for line in roads for a,b in zip(line,line[1:])]:
  dx,dy=b[0]-a[0],b[1]-a[1];t=max(0,min(1,((goal[0]-a[0])*dx+(goal[1]-a[1])*dy)/(dx*dx+dy*dy or 1)));near_points.append([round(a[0]+t*dx),round(a[1]+t*dy)])
 end_x=x+w-26 if x<100 else x+26
 near=min(near_points,key=lambda p:math.dist(p,goal));variants=[[near,[goal[0],near[1]],goal,[end_x,goal[1]]],[near,[near[0],goal[1]],goal,[end_x,goal[1]]]]
 for route in variants:
  if all(not any(hit([a[0]+(b[0]-a[0])*i/max(1,n)-18,a[1]+(b[1]-a[1])*i/max(1,n)-18,36,36],r,4) for r in protect) and not any(seg((a[0]+(b[0]-a[0])*i/max(1,n),a[1]+(b[1]-a[1])*i/max(1,n)),u,v)<55 for u,v in zip(river,river[1:])) for a,b in zip(route,route[1:]) for n in [math.ceil(math.dist(a,b)/16)] for i in range(n+1)):
   paths.append({'field':f['id'],'points':route,'width':42});break
# Both eastern plots share a narrow access lane, not detached entry pads.
if any(f['label']=='东田北块' for f in fields) and any(f['label']=='东田南块' for f in fields):
 paths.extend([{'field':'east_shared','points':[[3050,676],[2982,784],[2982,1718],[3060,1718]],'width':30},{'field':'east_north_access','points':[[2982,1215],[3060,1215]],'width':34}])
gardens=[]
for i,h in enumerate(H):
 if h['id']=='ayu':continue # original approved Ayu courtyard and art stay untouched
 x,y,w,hh=h['bounds'];options=[]
 for side in [-1,1]:
  options += [[x+24 if side<0 else x+w-254,y+hh+23,230,86],[x-105 if side<0 else x+w+16,y+hh-235,90,205],[x+24 if side<0 else x+w-205,y+hh+40,180,72]]
 picked=0
 for r in options:
  if safe_rect(r,70,8) and not any(hit(r,o,10) for o in occupied):
   gardens.append({'id':'garden_'+h['id']+'_'+str(picked),'house':h['id'],'rect':r,'variant':(i+picked)%4,'axis':'vertical' if r[3]>r[2] else 'horizontal','pieces':3,'connection':'low packed-earth verge tied to courtyard edge; central door approach clear'});occupied.append(r);picked+=1
   if picked==2:break
rng=random.Random(141014);plants=[]
def place(kind,cx,cy,w,h,group):
 r=[round(cx-w/2),round(cy-h),w,h]
 root=[round(cx)-17,round(cy)-17,34,17]
 if r[0]<12 or r[1]<12 or r[0]+w>4788 or r[1]+h>4688:return False
 if not safe_rect(root,95,16) or any(hit(root,o,12) for o in occupied):return False
 # A canopy may hang behind a facade, but must never paint over a nearer house.
 if any(hit(r,hh['bounds'],4) and cy>=next(pp['foot'] for pp in P if pp['id']==hh['id'] or (hh['id']=='community' and pp['id']=='house_community')) for hh in H):return False
 if hit(r,C['dynamic_site'],0):return False
 if any(hit(r,[hh['at'][0]-115,hh['at'][1]-35,230,265]) for hh in H):return False
 if any(seg((cx,cy),a,b)<100 for a,b in zip(river,river[1:])):return False
 plants.append({'id':'c4_'+kind+'_'+str(len(plants)),'kind':kind,'rect':r,'group':group,'mirror':bool(len(plants)%3==1),'foot':[round(cx),round(cy)],'root_collision':[round(cx)-14,round(cy)-15,28,13] if kind in ['tree','bamboo'] else None});occupied.append(root);return True
groups=[('北巷树组',[[1490,610],[1330,610],[1560,630]]),('西蜂院树组',[[70,1850],[220,1870],[380,1850]]),('东田岸林',[[3390,1060],[3350,1250],[3350,1630]]),('东渠北岸',[[3730,1080],[3760,1200],[3720,1460]]),('东渠中岸',[[3685,2310],[3630,2560],[3650,2770]]),('东渠南岸',[[3670,3590],[3640,3890],[3670,4100]]),('东侧边林',[[4490,1050],[4580,1120],[4420,1150]]),('西南田边',[[2020,3270],[2150,3390],[2070,3630]]),('东南田边',[[4560,3280],[4540,3490],[4400,3580]])]
for name,centers in groups:
 for j,(cx,cy) in enumerate(centers):
  kind='bamboo' if ('岸' in name and j%3==1) else 'tree';w,h=(150,180) if kind=='tree' else (126,176)
  for dx,dy in [(0,0),(-60,40),(60,40),(0,100),(-110,-20)]:
   if place(kind,cx+dx,cy+dy,w,h,name):break
# A few irregular peripheral groups fill empty landscape, never a regular tree-grid.
for zone,rect in [('西外缘',[20,1400,450,2200]),('东外缘',[4150,1850,460,1600]),('中心缓冲',[2060,1260,690,580])]:
 x,y,w,h=rect
 for n in range(24):
  cx=x+rng.randrange(w);cy=y+rng.randrange(h);kind='tree' if n%3 else 'shrub';pw,ph=(140,171) if kind=='tree' else (140,66);place(kind,cx,cy,pw,ph,zone)
layout={'version':'C4-outdoor-v2','date':'2026-10-14','world_size':[4800,4700],'grid_pixel':3,'owner':'C4','base_props':P,'house_gate_contract':H,'main_roads':roads,'gate_connectors':connectors,'river':river,'bridge_y':[750,1900,3050,4320],'fields':fields,'field_paths':paths,'drains':drains,'gardens':gardens,'plants':plants,'remove_prop_prefixes':['land_','wildtree'],'preserve_doors_hotspots_spawn':True,'dynamic_site':C['dynamic_site'],'collision_policy':'only listed tree/bamboo roots; banks/crops/flowers shallow walkable; original solids unchanged','source_policy':'existing atlas and transparent tree rendered in code-native world composition; original images immutable','art_status':'await rendered visual QA and C1 approval; not runtime N1/N2 pass'}
(R/'完整美术布局-v2.json').write_text(json.dumps(layout,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'fields':[(f['label'],f['rect'],f['rows'],f['columns']) for f in fields],'paths':len(paths),'garden_bands':len(gardens),'raised_groups':len(plants),'root_collisions':sum(bool(p['root_collision']) for p in plants)},ensure_ascii=False))
