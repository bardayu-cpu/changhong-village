#!/usr/bin/env python3
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,hashlib,subprocess
V=Path(__file__).resolve().parents[1];A=V/'assets';E=V/'evidence/floor1-redraw';E.mkdir(exist_ok=True)
r=json.loads((A/'rooms.json').read_text())['rooms'];art=Image.open(A/'floor1-redraw/floor1.png').convert('RGBA')
font=ImageFont.truetype('/System/Library/AssetsV2/com_apple_MobileAsset_Font8/86ba2c91f017a3749571a82f2c6d890ac7ffb2fb.asset/AssetData/PingFang.ttc',22)
comparison=Image.new('RGB',(1448*2,1142),'#e5d7b9');comparison.paste(art,(0,56));comparison.paste(Image.open(V.parent/'v3/assets/approved-2.png'),(1448,56));d=ImageDraw.Draw(comparison);d.text((24,14),'一楼 · 1005 新定稿重画 · 724×543 像素网格',font=font,fill='#4e392b');d.text((1472,14),'二楼 · approved-2.png 原样参照',font=font,fill='#4e392b');comparison.save(E/'floor1-floor2.png')
for id,c in r.items():
 if c['floor']!=1:continue
 crop=c['source_crop'];off=c['source_offset'];w,h=c['size'];base=Image.new('RGBA',(w,h),(25,24,22,255));base.alpha_composite(art,(off[0]-crop[0],off[1]-crop[1]));over=Image.new('RGBA',(w,h));draw=ImageDraw.Draw(over)
 nav=(A/(id+'.nav')).read_bytes();gw=w//4;gh=h//4
 for y in range(gh):
  for x in range(gw):
   if not nav[y*gw+x]:draw.rectangle((x*4,y*4,x*4+3,y*4+3),fill=(74,255,148,95))
 for i,door in enumerate(c['doors']):
  x,y=door['pos'];draw.ellipse((x-6,y-6,x+6,y+6),fill='#ffe271');draw.text((x+7,y-10),str(i+1),font=font,fill='#fff8e5')
 for spot in c['hotspots']:
  x,y=spot['approach'];draw.rectangle((x-3,y-3,x+3,y+3),fill='#8ccfff')
 base=Image.alpha_composite(base,over);base=base.crop((0,20,w,min(h,crop[3]-crop[1]+100)));base=base.resize((base.width*2,base.height*2),Image.Resampling.NEAREST)
 image=Image.new('RGB',(base.width,base.height+80),'#262c2a');image.paste(base,(0,80));dd=ImageDraw.Draw(image);dd.text((14,8),c['title']+' · 可走区',font=font,fill='white');dd.text((14,40),'绿：可走  黄：门槛  蓝：交互站位',font=font,fill='#b9dcc5');image.save(E/('walk-'+id+'.png'))
# Verify everything outside the explicit junction remains at the requested base.
base=json.loads(subprocess.check_output(['git','show','2b7e0cf:godot/ayu_home/v4/assets/rooms.json'],cwd=V))['rooms'];unchanged=[]
for id,c in r.items():
 if c['floor']==1:continue
 if id=='garden':
  a=dict(c);b=dict(base[id]);a.pop('doors');b.pop('doors');a.pop('new_gates');b.pop('new_gates');assert a==b
 else:assert c==base[id]
 unchanged.append(id)
report={'untouched_geometry_rooms':unchanged,'allowed_boundary_adjustment':'garden reciprocal kitchen -> cats, remove legacy synthetic labeled gate overlays only','main_scene_unchanged':subprocess.check_output(['git','diff','2b7e0cf','--','godot/project.godot'],cwd=V).decode()==''}
(E/'scope-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print('Saved comparison, 12 walkable overlays, scope audit')
