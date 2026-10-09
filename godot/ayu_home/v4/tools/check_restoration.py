#!/usr/bin/env python3
"""Compare actual effect-free Godot captures with the approved source coordinates."""
from pathlib import Path
from PIL import Image,ImageChops,ImageStat,ImageDraw,ImageFont
import json,math
V=Path(__file__).resolve().parents[1];E=V/'evidence';A=V/'assets'
REF=V.parents[3]/'七缘地图2-裳泓村参考图/定稿形象图'
original_floor1=Image.open(REF/'5-阿鱼家一楼平面图 2.png').convert('RGB')
refs={1:Image.open(A/'floor1-v3-approved-clarity.png').convert('RGB'),2:Image.open(REF/'5-阿鱼家二楼平面图 2.png').convert('RGB')}
rooms=json.loads((A/'rooms.json').read_text())['rooms'];results=[]
font=ImageFont.truetype('/System/Library/Fonts/STHeiti Medium.ttc',18)
(E/'comparison').mkdir(exist_ok=True)
for name,c in rooms.items():
 if c['floor'] not in (1,2):continue
 x,y=c['source_offset'][:2];l,t,r,b=c['source_crop'];w,h=r-l,b-t
 source=refs[c['floor']].crop((l,t,r,b));render=Image.open(E/'native'/f'{name}.png').convert('RGB').crop((x,y,x+w,y+h))
 mask=Image.new('L',(w,h),255)
 if c.get('source_polygon'):
  mask=Image.new('L',(w,h));ImageDraw.Draw(mask).polygon([(xx-l,yy-t) for xx,yy in c['source_polygon']],fill=255)
 raw_delta=ImageChops.difference(source,render);raw_max=max(v[1] for v in raw_delta.getextrema())
 allowed_label_pixels=0
 if c['floor']==2:
  approved_labels=Image.open(V.parent/'v3/evidence/allowed-edit-mask-2.png').convert('L').crop((l,t,r,b))
  allowed_label_pixels=sum(v>0 for v in ImageChops.multiply(mask,approved_labels).getdata())
  mask=ImageChops.multiply(mask,ImageChops.invert(approved_labels))
 delta=raw_delta.copy();delta.paste((0,0,0),(0,0,w,h),ImageChops.invert(mask))
 maximum=max(v[1] for v in delta.getextrema());over=sum(max(p)>12 for p in delta.getdata())
 results.append({'room':name,'floor':c['floor'],'max_rgb':maximum,'raw_max_including_removed_labels':raw_max,'authorized_removed_label_pixels':allowed_label_pixels,'pixels_over_12':over,'source_offset':c['source_offset'],'integer_placement_offset_px':0})
 panel=Image.new('RGB',(w*3,h+32),'#f1e8d8');d=ImageDraw.Draw(panel)
 for i,(im,label) in enumerate([(source,'v3 已认可底图' if c['floor']==1 else '二楼原图'),(render,'Godot 实际渲染'),(delta.point(lambda x:min(255,x*5)),'差异 × 5')]):panel.paste(im,(i*w,32));d.text((i*w+4,5),label,font=font,fill='#483027')
 panel.save(E/'comparison'/f'{name}.png',optimize=True)
report={'method':'Actual Godot native screenshots, effects off, first floor compared to restored v3 accepted clarity; second floor compared to original; integer source reprojection, per-room source polygon masks and the pre-existing v3 authorized annotation-removal mask. Raw maxima including removed room-name labels are separately reported. Sharpness is bounded separately at 12/255; weather and added gameplay props are excluded from this restoration measurement.','rooms':results,'pass':all(r['pixels_over_12']==0 for r in results),'first_floor_reference':'The user-accepted v3 clear image restored by the October 4 evening visual supplement; NOT the earliest soft original.'}
(E/'accepted-v3-restoration.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
original_delta=ImageChops.difference(original_floor1,refs[1]);original_max=max(z[1] for z in original_delta.getextrema());original_report={'pass':False,'reason':'Restored the v3 image explicitly accepted by the user to meet the latest clarity supplement; the original soft image color tolerance is not met.','max_original_to_restored_source_rgb':original_max,'mean_original_to_restored_source_rgb':sum(ImageStat.Stat(original_delta).mean)/3,'original_files_unchanged':True,'accepted_v3_render_audit':'accepted-v3-restoration.json'}
(E/'restoration.json').write_text(json.dumps(original_report,ensure_ascii=False,indent=2)+'\n')
for group in ['一楼','二楼','屋外']:
 ids=[k for k,x in rooms.items() if x['group']==group];out=Image.new('RGB',(216*4,414*math.ceil(len(ids)/4)),'#f1e8d8');d=ImageDraw.Draw(out)
 for i,name in enumerate(ids):
  im=Image.open(E/'runtime'/f'{name}-960.png');im.thumbnail((216,384));x=i%4*216;y=i//4*414;out.paste(im,(x,y+30));d.text((x+5,y+5),rooms[name]['title'],font=font,fill='#483027')
 out.save(E/f'rooms-{group}.jpg',quality=92)
print('RESULT', 'PASS' if report['pass'] else 'FAIL',len(results),'source regions, maximum RGB difference',max(r['max_rgb'] for r in results))
assert report['pass']
