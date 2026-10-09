#!/usr/bin/env python3
"""Verify actual Godot native renders, without disguising the first-floor remaster as original pixels."""
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw, ImageStat, ImageFont
import json, hashlib, math

V=Path(__file__).resolve().parents[1]; A=V/'assets'; E=V/'evidence'
defs=json.loads((A/'rooms.json').read_text())['rooms']
refs=json.loads((V/'reference_manifest.json').read_text())['files']
refdir=Path(refs[0]['source']).parent
font=ImageFont.truetype('/System/Library/Fonts/STHeiti Medium.ttc',18)
orig=[Image.open(refdir/n).convert('RGB') for n in ['阿鱼家123.png','5-阿鱼家一楼平面图 2.png','5-阿鱼家二楼平面图 2.png']]
approved=[Image.open(A/n).convert('RGB') for n in ['approved-0.png','floor1-clear.png','approved-2.png']]
def diff(a,b,mask=None):
 d=ImageChops.difference(a.convert('RGB'),b.convert('RGB'))
 if mask:d.paste((0,0,0),(0,0,a.width,a.height),ImageChops.invert(mask))
 hist=d.histogram();maximum=max(max(i for i,n in enumerate(hist[c*256:(c+1)*256]) if n) for c in range(3))
 count=sum(1 for p in d.getdata() if max(p)>12)
 return {'max_rgb':maximum,'pixels_over_12':count,'mean_absolute_rgb':round(sum(ImageStat.Stat(d,mask).mean)/3,4)}

(E/'comparisons').mkdir(exist_ok=True);results=[]
for id,c in defs.items():
 native=Image.open(E/'native'/f'{id}.png').convert('RGB')
 assembly=Image.open(E/f'{id}-assembly.png').convert('RGB')
 item={'id':id,'title':c['title'],'runtime_vs_assembly':diff(native,assembly),'placed_prop_count':len(c['props'])}
 if id!='garden':
  crop=c['source_crop'];x,y=c['source_offset'];w,h=crop[2]-crop[0],crop[3]-crop[1]
  mask=Image.new('L',(w,h),255)
  if 'source_polygon' in c:
   mask=Image.new('L',(w,h));ImageDraw.Draw(mask).polygon([(xx-crop[0],yy-crop[1]) for xx,yy in c['source_polygon']],fill=255)
  render=native.crop((x,y,x+w,y+h));source=orig[c['floor']].crop(crop);selected=approved[c['floor']].crop(crop)
  item['runtime_vs_selected_art']=diff(render,selected,mask)
  item['runtime_vs_original_reference']=diff(render,source,mask)
  item['retained_pixels']=sum(mask.histogram()[1:]);item['integer_placement_offset_px']=0
  panel=Image.new('RGB',(w*3,h+34),'#f1e8d8');d=ImageDraw.Draw(panel)
  for col,(im,label) in enumerate([(source,'原始定稿'),(selected,'本版素材'),(render,'Godot 原生截图')]):panel.paste(im,(col*w,34));d.text((col*w+6,6),label,font=font,fill='#483027')
  target=E/'comparisons'/f'{id}.png'
  if not target.exists() or Image.open(target).convert('RGB').tobytes()!=panel.tobytes():panel.save(target,optimize=True)
 results.append(item)

edits=[]
for idx in [0,2]:
 mask=Image.open(E/f'allowed-edit-mask-{idx}.png');edits.append({'source':idx,'outside_authorized_masks':diff(orig[idx],approved[idx],ImageChops.invert(mask))})
out={'method':'Godot native screenshots, effects off, exact integer source crop and per-room isolation masks. Original reference and selected remaster are assessed separately. First-floor original color tolerance is NOT passed.','rooms':results,'authorized_edit_checks':edits}
(E/'restore-check.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
for group in ['一楼','二楼','屋外']:
 ids=[k for k,x in defs.items() if x['group']==group];out=Image.new('RGB',(216*4,414*math.ceil(len(ids)/4)), '#f1e8d8');d=ImageDraw.Draw(out)
 for i,id in enumerate(ids):
  im=Image.open(E/'runtime'/f'{id}-960.png');im.thumbnail((216,384));x=i%4*216;y=i//4*414;out.paste(im,(x,y+30));d.text((x+5,y+5),defs[id]['title'],font=font,fill='#483027')
 out.save(E/f'rooms-{group}.jpg',quality=93)
print(json.dumps({'rooms':len(results),'max_runtime_assembly':max(r['runtime_vs_assembly']['max_rgb'] for r in results),'original_first_floor_tolerance_passed':False,'authorized_edits':edits},ensure_ascii=False))
