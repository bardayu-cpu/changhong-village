"""接入逐户透明图集；只读取透明边界，不修改生成的 PNG。"""
from pathlib import Path
from PIL import Image
import copy, hashlib, json, shutil

root = Path(__file__).resolve().parents[1]
assets = root / 'godot/ayu_home/v4/assets'
destination = assets / 'village/interiors'
destination.mkdir(exist_ok=True)
names = ['table','chair','bed','cabinet','kitchen','sofa','workbench','lamp']
sizes = {'bed':(150,215),'kitchen':(155,88),'table':(120,80),'sofa':(135,90),'bench':(126,78),'cabinet':(98,112),'tea_bench':(60,46)}
mapping = {'bench':'workbench','tea_bench':'chair'}
sets = {
 'grape': dict(title='葡萄架小院', file='家具整套-v2-粗像素.png', version='grape-v2',
  cells=[(0,0,400,512),(400,0,410,512),(810,0,390,512),(1200,0,336,512),(0,512,438,512),(438,512,402,512),(840,512,427,512),(1267,512,269,512)],
  rooms={'v_grape':[('pantry','cabinet',690,365,98,112),('rattan_sofa','sofa',55,410,135,90),('lantern','lamp',564,414,36,54)]}),
 'sunflower': dict(title='向日葵之家', file='家具整套-v1.png', version='sunflower-v1',
  cells=[(0,0,400,512),(400,0,410,512),(810,0,390,512),(1200,0,336,512),(0,512,360,512),(360,512,450,512),(810,512,510,512),(1320,512,216,512)],
  rooms={'v_sunflower':[('reading_lamp','lamp',540,170,36,70)],'v_sunflower_up':[('bedside_lamp','lamp',235,200,36,70)]},
  overrides={'v_sunflower_up':{'bench1':'sofa'}}),
 'persimmon': dict(title='柿树老院', file='家具整套-v1.png', version='persimmon-v1',
  cells=[(0,0,385,490),(385,0,325,490),(710,0,430,490),(1140,0,396,490),(0,490,414,534),(414,490,499,534),(913,490,347,534),(1260,490,276,534)],
  rooms={'v_persimmon':[('brick_stove','kitchen',60,350,170,145),('reed_daybed','sofa',315,105,195,95),('oil_lamp','lamp',765,280,45,78)]}),
 'rose': dict(title='玫瑰花之家', file='家具整套-v1.png', version='rose-v1',
  cells=[(0,0,380,550),(380,0,440,550),(820,0,410,550),(1230,0,306,550),(0,550,490,474),(490,550,430,474),(920,550,390,474),(1310,550,226,474)],
  rooms={'v_rose':[('vase_cabinet','cabinet',190,190,95,145),('glass_lamp','lamp',650,190,40,70)],'v_rose_up':[('glass_lamp','lamp',665,190,40,70)]},
  overrides={'v_rose_up':{'bench1':'table'}}),
}
manifest_path=assets/'rooms.json'
manifest=json.loads(manifest_path.read_text())
records=[]
for house,spec in sets.items():
 source=root/'素材来源/逐户室内重绘'/spec['title']
 png=source/spec['file']
 if not png.exists():continue
 runtime=destination/(spec['version']+'.png')
 shutil.copy2(png,runtime)
 with Image.open(png) as image:
  alpha=image.getchannel('A');regions={}
  for name,(x,y,w,h) in zip(names,spec['cells']):
   bounds=alpha.crop((x,y,x+w,y+h)).point(lambda value:255 if value>128 else 0).getbbox()
   if not bounds:raise ValueError(house+':'+name+' has no opaque pixels')
   x0,y0,x1,y1=bounds
   if x0==0 or y0==0 or x1==w or y1==h:raise ValueError(house+':'+name+' touches the crop boundary')
   x0=max(0,x0-3);y0=max(0,y0-3);x1=min(w,x1+3);y1=min(h,y1+3)
   regions[name]=[x+x0,y+y0,x1-x0,y1-y0]

 def decorate(prop,kind,box,room):
  w,h=box;x,y=prop['pos'];cx,bottom=x+w/2,y+h;target=(w,h)
  if prop['id']=='tea_bench':
   seat=next(s['seat'] for s in room['hotspots'] if s['id']=='tea_seat')
   target=(96,74);cx,bottom=seat[0],seat[1]+24
   prop['foot']=seat[1]-1 # 椅背排在坐下人物后方，避免整张椅子盖住身体。
   if house=='persimmon':cx+=24 # 两只独凳，坐点对准左凳，不落在中缝。
  elif house=='persimmon' and kind=='bed':target=(220,160)
  region=regions[kind];scale=min(target[0]/region[2],target[1]/region[3])
  sw,sh=region[2]*scale,region[3]*scale
  prop['pos']=[round(cx-sw/2,3),round(bottom-sh,3)]
  prop.update(file='res://ayu_home/v4/assets/village/interiors/'+runtime.name,atlas_region=region,scale=[scale,scale],interior_set=spec['version'])
  return [round(cx-sw/2+4,3),round(bottom-sh*.4,3),round(max(1,sw-8),3),round(sh*.4,3)]

 for room_id,extras in spec['rooms'].items():
  baseline=source/('接入前房间.json' if room_id=='v_'+house else '接入前二楼.json')
  room_path=assets/(room_id+'.json')
  if not baseline.exists():shutil.copy2(room_path,baseline)
  room=json.loads(baseline.read_text());obstacles=copy.deepcopy(room['obstacles'])
  if room_id in ['v_sunflower_up','v_rose_up']:
   shift=50 if room_id=='v_sunflower_up' else 40
   for spot in room['hotspots']:
    if spot['id']=='tea_seat':
     for field in ['pos','approach','seat']:spot[field][0]+=shift
  for prop in room['props']:
   kind='tea_bench' if prop['id']=='tea_bench' else prop['id'].rstrip('0123456789')
   if kind not in sizes:continue
   box=sizes[kind];x,y=prop['pos'];w,h=box;old=[x+5,y+h*.6,w-10,h*.4]
   obstacles=[b for b in obstacles if not all(abs(a-c)<.001 for a,c in zip(b,old))]
   if house=='grape' and kind=='bench':prop['pos'][1]-=35;prop['foot']-=35
   art_kind=spec.get('overrides',{}).get(room_id,{}).get(prop['id'],mapping.get(kind,kind))
   obstacle=decorate(prop,art_kind,box,room)
   if kind!='tea_bench':obstacles.append(obstacle)
  for identifier,kind,x,y,w,h in extras:
   prop={'id':'new_'+identifier,'pos':[x,y],'foot':y+h-5,'front':False}
   obstacles.append(decorate(prop,kind,(w,h),room));room['props'].append(prop)
  room['obstacles']=obstacles
  room['interior_art_status']='new_household_set_pending_graphical_acceptance'
  room_path.write_text(json.dumps(room,ensure_ascii=False,indent=2));manifest['rooms'][room_id]=room
 record={'house':spec['title'],'source':str(png),'sha256':hashlib.sha256(png.read_bytes()).hexdigest(),'image_unmodified':True,'regions':regions,'new_objects':8,'rooms':list(spec['rooms']),'state':'已接入工程；待整屋显示与实际坐点复验','preserved':'阿鱼家原画及旧素材原件未改'}
 (source/'接入记录.json').write_text(json.dumps(record,ensure_ascii=False,indent=2))
 records.append({'house':house,'rooms':list(spec['rooms']),'new_objects':8,'regions':regions})
manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
print(json.dumps(records,ensure_ascii=False))
