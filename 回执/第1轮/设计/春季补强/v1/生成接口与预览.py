# -*- coding: utf-8 -*-
"""Native seasonal-material preview from read-only world assets, never edits C3 screenshots.
PNG outputs are shader-control masks and an independent asset composition, not repaint assets.
"""
from pathlib import Path
from PIL import Image, ImageDraw
import numpy as np, json, hashlib, math
D=Path(__file__).resolve().parent
P=D.parents[4]/'godot'
V=json.loads((P/'ayu_home/v4/assets/village.json').read_text())
L=json.loads((D.parents[1]/'村外铺景/v2/完整美术布局-v2.json').read_text())
M=D/'masks';M.mkdir(exist_ok=True)
def path(ref):return P/ref[6:] if ref.startswith('res://') else P/'ayu_home/v3/assets'/ref
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def source(ref):return Image.open(path(ref)).convert('RGBA')
def eligible(a):
 c=a.astype(np.int16)
 return (c[:,:,1]-c[:,:,0]>=5)&(c[:,:,1]>=c[:,:,2]*1.22)&(c[:,:,3]>=235)
def drawline(dr,pts,w,fill=0):
 pts=[(round(x/3),round(y/3)) for x,y in pts]
 dr.line(pts,fill=fill,width=max(1,round(w/3)))
 for x,y in pts:dr.ellipse([x-w/6,y-w/6,x+w/6,y+w/6],fill=fill)
protected={
 'house_sunflower.png':[
  [[280,34],[460,24],[1004,245],[1000,274],[270,246]],
  [[871,314],[1298,417],[1300,459],[870,375]],
  [[340,390],[545,391],[551,441],[339,457]],
 ]
}
cached={};records=[];flower_count=0
def flowers(mask,centers,seed=0,radius=1):
 global flower_count
 # Existing native pixel-flower structure: four stepped petals and a yellow centre.
 h,w=mask.shape[:2]
 for i,(x,y) in enumerate(centers):
  x=int(x);y=int(y)
  if x<radius or y<radius or x>=w-radius-1 or y>=h-radius-1 or mask[y,x,0]==0:continue
  flag=64 if (i+seed)%2==0 else 192
  petals=[(0,0)]+[(q,0) for q in range(-radius,radius+1) if q]+[(0,q) for q in range(-radius,radius+1) if q]
  for dx,dy in petals:
   if mask[y+dy,x+dx,0]:mask[y+dy,x+dx,1]=flag
  mask[y,x,2]=255;flower_count+=1
def make(ref,ground=False,kind=1):
 key=(ref,ground)
 if key in cached:return cached[key]
 im=source(ref);w,h=im.size
 small=im.resize((math.ceil(w/3),math.ceil(h/3)),Image.Resampling.NEAREST)
 a=np.array(small);red=eligible(a).astype(np.uint8)*255
 protection=Image.new('L',small.size,255);dr=ImageDraw.Draw(protection)
 if ground:
  drawline(dr,L['river'],106)
  for road in L['main_roads']:drawline(dr,road,112)
  for road in L['gate_connectors']:drawline(dr,road,67)
  for route in L['field_paths']:drawline(dr,route['points'],route['width']+5)
  for drain in L['drains']:
   drawline(dr,drain['boundary_path'],drain['width']+8)
   drawline(dr,drain['outlet_path'],drain['width']+8)
 else:
  for poly in protected.get(Path(ref).name,[]):dr.polygon([(x/3,y/3) for x,y in poly],fill=0)
  if Path(ref).name=='pond.png':dr.ellipse((75/3,42/3,375/3,210/3),fill=0)
 red=np.minimum(red,np.array(protection))
 mask=np.zeros((red.shape[0],red.shape[1],3),dtype=np.uint8);mask[:,:,0]=red
 # Three discreet native blooms per original garden band; no crops, road or river blooms.
 centers=[]
 if ground:
  for g in L['gardens']:
   x,y,gw,gh=g['rect']
   for q in [.25,.50,.75]:
    cx=int((x+gw*(q if g['axis']=='horizontal' else .5))/3)
    cy=int((y+gh*(.5 if g['axis']=='horizontal' else q))/3)
    candidates=[]
    for dy in range(-12,13):
     for dx in range(-12,13):
      yy=cy+dy;xx=cx+dx
      if 0<=yy<red.shape[0] and 0<=xx<red.shape[1] and red[yy,xx]:candidates.append((dx*dx+dy*dy,xx,yy))
    if candidates:
     _,xx,yy=min(candidates);centers.append((xx,yy))
 elif Path(ref).name.startswith('house_') or Path(ref).name=='cabin.png':
  # Six sparse highlights confined to low courtyard vegetation, never roofs/windows.
  yy,xx=np.where((red>0)&(np.indices(red.shape)[0]>red.shape[0]*.64))
  if len(xx):
   bins=np.linspace(0,red.shape[1],7)
   for x0,x1 in zip(bins[:-1],bins[1:]):
    ids=np.where((xx>=x0)&(xx<x1))[0]
    if len(ids):
     q=ids[len(ids)//2];centers.append((xx[q],yy[q]))
 elif 'tree' in Path(ref).name and ref in [p['file'] for p in V['props'] if p.get('plant_type')=='fruit']:
  yy,xx=np.where((red>0)&(np.indices(red.shape)[0]<red.shape[0]*.62))
  for q in [.2,.45,.7]:
   if len(xx):i=int((len(xx)-1)*q);centers.append((xx[i],yy[i]))
 flowers(mask,centers,len(records),2 if Path(ref).name.startswith('house_') or Path(ref).name=='cabin.png' else 1)
 name=('ground' if ground else Path(ref).stem)+'-spring-mask.png'
 outfile=M/name;Image.fromarray(mask).save(outfile,optimize=True)
 rec={'source_texture':ref,'source_sha256':sha(path(ref)),'source_size':[w,h],
      'mask_file':str(outfile),'mask_target':'res://ayu_home/v4/assets/village/c4-spring-v1/'+name,
      'mask_size':list(small.size),'sha256':sha(outfile),'spring_layer_kind':kind,
      'eligible_mask_pixels':int(np.count_nonzero(red)),
      'mask_channels':'R eligible vegetation, G64 pink/G192 cream petals, B255 yellow centre; zero elsewhere',
      'filter':'nearest, repeat disabled, same UV as source; no atlas regions in current village'}
 records.append(rec);cached[key]=(mask,rec);return mask,rec
bgmask,bgrec=make(V['background'],True,0)
for p in V['props']:make(p['file'],False,2 if p.get('plant_type')=='evergreen' else 1)
def spring(im,mask,kind):
 a=np.asarray(im).astype(np.float32)/255.;c=a[:,:,:3];l=c@np.array([.3,.59,.11],dtype=np.float32)
 mm=np.asarray(Image.fromarray(mask).resize(im.size,Image.Resampling.NEAREST)).astype(np.float32)/255.
 t=np.clip((l-.04)/.72,0,1)[:,:,None]
 shade=np.array([.29,.46,.20] if kind==0 else [.10,.29,.12]);mid=np.array([.64,.81,.36] if kind==0 else [.57,.75,.25]);light=np.array([.82,.93,.48] if kind==0 else [.78,.94,.39])
 target=np.where(t<.48,shade+(mid-shade)*t/.48,mid+(light-mid)*(t-.48)/.52)
 eligible_full=eligible(np.asarray(im)).astype(np.float32)[:,:,None]
 weight=mm[:,:,:1]*eligible_full*(.58 if kind==2 else .94)
 col=c*(1-weight)+target*weight
 bloom=(mm[:,:,1:2]>.1)*eligible_full*mm[:,:,:1]*.94
 petal=np.where(mm[:,:,1:2]<.5,np.array([.95,.69,.75]),np.array([.99,.95,.81]))
 petal=np.where(mm[:,:,2:3]>.5,np.array([.91,.77,.39]),petal)
 col=col*(1-bloom)+petal*bloom
 out=np.dstack((np.clip(col*255,0,255).round().astype(np.uint8),np.array(im)[:,:,3]))
 return Image.fromarray(out)
def rain(im):
 a=np.array(im);a[:,:,:3]=(a[:,:,:3].astype(float)*np.array([.8,.86,.95])*np.array([.78,.85,.91])).round().astype(np.uint8)
 return Image.fromarray(a)
def render(season):
 # Source C3 020: settled camera=player(1880,3576)-(0,65), scale1.15, scene540x696.
 center=[1880,3511];scale=1.15;sz=(540,696);offset=(round(sz[0]/2-center[0]*scale),round(sz[1]/2-center[1]*scale))
 scene=Image.new('RGBA',sz)
 # Compose only the visible world region, never alter/crop C3 screenshots.
 ground=source(V['background']);crop=(math.floor(-offset[0]/scale),math.floor(-offset[1]/scale),math.ceil((540-offset[0])/scale),math.ceil((696-offset[1])/scale))
 groundcrop=ground.crop(crop)
 if season==0:
  mfull=Image.fromarray(bgmask).resize(ground.size,Image.Resampling.NEAREST).crop(crop)
  groundcrop=spring(groundcrop,np.array(mfull),0)
 groundcrop=rain(groundcrop).resize((round(groundcrop.width*scale),round(groundcrop.height*scale)),Image.Resampling.NEAREST)
 scene.alpha_composite(groundcrop,(round(crop[0]*scale+offset[0]),round(crop[1]*scale+offset[1])))
 for p in sorted(V['props'],key=lambda x:x.get('foot',x['pos'][1])):
  raw=source(p['file']);s=p.get('scale',[1,1]);w=round(raw.width*s[0]*scale);h=round(raw.height*s[1]*scale);x=round(p['pos'][0]*scale+offset[0]);y=round(p['pos'][1]*scale+offset[1])
  if x>540 or y>696 or x+w<0 or y+h<0:continue
  if season==0:
   mask,rec=cached[(p['file'],False)];raw=spring(raw,mask,rec['spring_layer_kind'])
  raw=rain(raw).resize((w,h),Image.Resampling.NEAREST);scene.alpha_composite(raw,(x,y))
 return scene.convert('RGB')
summer=render(1);spring_preview=render(0)
# One and only one spring/summer view group. Labels are in the adjacent MD, no fake game HUD.
pair=Image.new('RGB',(1088,696),'#311e15');pair.paste(spring_preview,(0,0));pair.paste(summer,(548,0));pair.save(D/'同机位-左春右夏-设计预览.png')
interface={'version':'C4-spring-v1','scope':'Only village spring vegetation. Summer/autumn/winter/rain existing behavior retained. No production/Git edits. N3 not passed.',
 'shader_source':str(D/'春季植物材质.gdshader'),'shader_target':'res://ayu_home/v4/assets/village/c4-spring-v1/season-material.gdshader',
 'source_scene_sha256':sha(P/'ayu_home/v4/assets/village.json'),'source_world':'7d87d81 scene asset state; later C1 task commit a9868f0',
 'texture_bindings':records,'prop_bindings':[{'id':p['id'],'source_texture':p['file'],'plant_kind':{'fruit':3,'deciduous':1,'evergreen':2}.get(p.get('plant_type',''),0),'spring_layer_kind':2 if p.get('plant_type')=='evergreen' else 1} for p in V['props']],
 'material_rules':['Use new shader only for village. Bind background ground mask/layer0 to base_sprite.',
 'Each unique texture+plant-kind must get material with corresponding mask. Never share background material with house sprites.',
 'spring_mask_enabled=true for village; missing masks fail closed using a black mask, never broad whole-sprite tint.',
 'Retain plant_kind for original autumn difference. Register every material for existing season/rain parameter updates.',
 'Do not change weather/ambient/effects_enabled or other outdoor areas. Non-spring shader branches retain original formulas.',
 'mask sampler nearest/repeat disabled. Source UV equals mask UV. No current atlas-region props; future atlas sprites require matching region UV.',
 'No new sprites/collisions/navigation/scene positions. Flower accents encoded in mask and active only for spring.',
 'Copy masks and shader mechanically; do not redraw source PNGs or regenerate summer ground.'],
 'protected':{'ground':'main roads/gate paths/field paths/river/drains excluded','house_sunflower':'three exact roof polygons excluded; all transparent glows excluded','pond':'water centre excluded','all':'runtime full-resolution green/alpha guard prevents mask bleed onto non-green wall/road pixels'},
 'preview':{'file':str(D/'同机位-左春右夏-设计预览.png'),'left':'proposed spring','right':'existing summer','camera':[1880,3511],'scale':1.15,'world_viewport':[540,696],'hour':13,'weather':'rain','type':'independent native shader/asset composition, no player/HUD/weather particles, not a runtime screenshot'},
 'cost':{'masks':len(records),'compressed_bytes':sum(Path(x['mask_file']).stat().st_size for x in records),'rgb_gpu_bytes':sum(x['mask_size'][0]*x['mask_size'][1]*4 for x in records),'shader_extra_sampler':1,'extra_scene_nodes':0,'spring_flower_centres':flower_count},
 'pending':'C1 visual review -> C2 integration -> C3 actual same-camera N3 spring/summer/field group; old summer and winter regression.'}
(D/'C2春季接入-v1.json').write_text(json.dumps(interface,ensure_ascii=False,indent=2))
print(json.dumps(interface['cost']));print('One same-view seasonal pair and exact texture masks/interface saved.')
