# -*- coding: utf-8 -*-
from pathlib import Path
from PIL import Image
import numpy as np,json,hashlib,math,ast
D=Path(__file__).resolve().parent;P=D.parents[4]/'godot'
V=json.loads((P/'ayu_home/v4/assets/village.json').read_text())
L=json.loads((D.parents[1]/'村外铺景/v2/完整美术布局-v2.json').read_text())
B=json.loads((P/'ayu_home/v4/assets/village/c4-spring-v1/bindings.json').read_text())
def canon(s):return s if s.startswith('res://') else 'res://ayu_home/v3/assets/'+s
def path(s):return P/canon(s)[6:]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def art(n):return D/'assets'/n
files=['lotus-summer-v1.png','flowers-summer-v1.png','crown-summer-v1.png','wheat-summer-v1.png']
assets=[{'source':str(art(n)),'target':'res://ayu_home/v4/assets/village/c4-summer-autumn-v1/'+n,'size':list(Image.open(art(n)).size),'sha256':sha(art(n)),'filter':'nearest','alpha':'preserved from built-in imagegen output'} for n in files]
decor=[]
for i,g in enumerate(L['gardens']):
 x,y,w,h=g['rect']
 for j,t in enumerate([.25,.72]):
  fw=80 if (i+j)%3 else 70;fh=fw*.4
  px=x+w*(t if g['axis']=='horizontal' else .5)-fw/2
  py=y+h*(.5 if g['axis']=='horizontal' else t)-fh/2
  decor.append({'id':f'summer_bed_{i}_{j}','asset':files[1],'pos':[round(px),round(py)],'size':[fw,round(fh)],'mirror':(i+j)%2==1,'layer':'low_ground_before_props','seasons':[1],'collisions':[],'garden':g['id']})
crowns=[]
for p in V['props']:
 if not(p['id'].startswith('c4_tree') or p['id'].startswith('orchard')):continue
 w,h=Image.open(path(p['file'])).size;s=p.get('scale',[1,1]);w*=s[0];h*=s[1]
 cw=w*1.10;ch=min(h*.75,cw*137/180)
 crowns.append({'id':'summer_crown_'+p['id'],'parent_prop':p['id'],'asset':files[2],'pos':[round(p['pos'][0]-(cw-w)/2),round(p['pos'][1]-h*.03)],'size':[round(cw),round(ch)],'layer':'after_parent_sprite_same_root','root_foot':p.get('foot'),'seasons':[1],'collisions':[]})
# H7's tree is baked behind the roof: extra crown stays behind the unchanged whole house.
crowns.append({'id':'summer_crown_h7_back','parent_prop':'h7','asset':files[2],'pos':[1611,3179],'size':[180,137],'layer':'before_parent_sprite_same_root','root_foot':3521,'seasons':[1],'collisions':[]})
lotus={'id':'summer_public_lotus','parent_prop':'public_pond','asset':files[0],'pos':[1150,1065],'size':[265,88],'layer':'after_parent_sprite_same_root','root_foot':1210,'seasons':[1],'collisions':[]}
wheat={'id':'summer_wheat_field4','field':'c4_field_4','asset':files[3],'pos':[3850,3320],'size':[585,215],'layer':'low_ground_before_props','seasons':[1],'collisions':[],'shader':'麦田热浪.gdshader','decorative_only':True}
decor.append(wheat)
cache={};mcache={}
def raw(s):
 if s not in cache:cache[s]=Image.open(path(s)).convert('RGBA')
 return cache[s]
def mask(s):
 key=canon(s)
 if key not in mcache:
  b=B['textures'].get(key,{});im=raw(s)
  mcache[key]=Image.open(path(b['mask'])).convert('RGB').resize(im.size,Image.Resampling.NEAREST) if b.get('mask') else Image.new('RGB',im.size)
 return mcache[key]
oldscript=D.parents[1]/'春季补强/v1/生成接口与预览.py'
tree=ast.parse(oldscript.read_text());defs=[x for x in tree.body if isinstance(x,ast.FunctionDef) and x.name in ['spring','eligible']]
ns={'Image':Image,'np':np};exec(compile(ast.Module(body=defs,type_ignores=[]),str(oldscript),'exec'),ns)
def shade(im,mm,season,kind=1,plant_kind=0):
 if season==0:return ns['spring'](im,np.array(mm),kind)
 a=np.array(im);c=a[:,:,:3].astype(np.float32)/255.;m=np.array(mm).astype(np.float32)/255.;l=c@np.array([.3,.59,.11]);eligible=ns['eligible'](a)[:,:,None]
 if season==1:
  c=c+np.array([.075,.060,.012])*m[:,:,:1]*eligible*np.clip((l-.18)/.55,0,1)[:,:,None]
 elif season==2:
  t=np.clip((l-.04)/.72,0,1)[:,:,None];dark=np.array([.42,.29,.09] if kind==0 else [.29,.12,.035]);mid=np.array([.88,.65,.19] if kind==0 else [.95,.49,.065]);light=np.array([1,.88,.43] if kind==0 else [1,.81,.28])
  target=np.where(t<.48,dark+(mid-dark)*t/.48,mid+(light-mid)*(t-.48)/.52);w=m[:,:,:1]*eligible*(.22 if plant_kind==2 else .98);c=c*(1-w)+target*w
 return Image.fromarray(np.dstack((np.clip(c*255,0,255).round().astype(np.uint8),a[:,:,3])))
def paste_decor(scene,d,off,scale):
 img=Image.open(art(d['asset'])).convert('RGBA')
 if d.get('mirror'):img=img.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
 img=img.resize((round(d['size'][0]*scale),round(d['size'][1]*scale)),Image.Resampling.NEAREST)
 scene.alpha_composite(img,(round(d['pos'][0]*scale+off[0]),round(d['pos'][1]*scale+off[1])))
def render(center,season,size=(640,360),scale=1.15):
 off=[round(size[0]/2-center[0]*scale),round(size[1]/2-center[1]*scale)];scene=Image.new('RGBA',size)
 bg=raw(V['background']);box=[math.floor(-off[0]/scale),math.floor(-off[1]/scale),math.ceil((size[0]-off[0])/scale),math.ceil((size[1]-off[1])/scale)]
 tile=shade(bg.crop(box),mask(V['background']).crop(box),season,0).resize((round((box[2]-box[0])*scale),round((box[3]-box[1])*scale)),Image.Resampling.NEAREST)
 scene.alpha_composite(tile,(round(box[0]*scale+off[0]),round(box[1]*scale+off[1])))
 if season==1:
  for d in decor:paste_decor(scene,d,off,scale)
 for p in sorted(V['props'],key=lambda q:q.get('foot',q['pos'][1])):
  im=raw(p['file']);s=p.get('scale',[1,1]);w=round(im.width*s[0]*scale);h=round(im.height*s[1]*scale);x=round(p['pos'][0]*scale+off[0]);y=round(p['pos'][1]*scale+off[1])
  if x>size[0] or y>size[1] or x+w<0 or y+h<0:continue
  family=[d for d in crowns if d['parent_prop']==p['id']]+([lotus] if p['id']=='public_pond' else [])
  if season==1:
   for d in family:
    if d['layer'].startswith('before'):paste_decor(scene,d,off,scale)
  kind=B['textures'].get(canon(p['file']),{}).get('spring_layer_kind',1);pk={'fruit':3,'deciduous':1,'evergreen':2}.get(p.get('plant_type'),0)
  img=shade(im,mask(p['file']),season,kind,pk).resize((w,h),Image.Resampling.NEAREST);scene.alpha_composite(img,(x,y))
  if season==1:
   for d in family:
    if not d['layer'].startswith('before'):paste_decor(scene,d,off,scale)
 return scene.convert('RGB')
views=[('荷塘',[1260,1130]),('麦田',[4140,3440]),('门前',[1880,3511])]
sheet=Image.new('RGB',(1932,1092),'#311e15')
for row,(name,center) in enumerate(views):
 for col,season in enumerate([0,1,2]):sheet.paste(render(center,season),(col*646,row*366))
sheet.save(D/'同机位春夏秋-荷塘麦田门前-设计预览.png')
frames=[];field=np.array(Image.open(art(files[3])).convert('RGB'));hh,ww=field.shape[:2];yy,xx=np.indices((hh,ww));uvy=yy/hh;uvx=xx/ww
for i in range(20):
 t=i*.12;band=np.clip((uvy-.04)/(.65-.04),0,1);band=band*band*(3-2*band);wave=np.sin(t*1.7+uvy*31+uvx*5)+.35*np.sin(t*.9+uvy*57);jx=np.clip(np.round(xx+wave*.75*band).astype(int),0,ww-1);frames.append(Image.fromarray(field[yy,jx]))
frames[0].save(D/'麦田热浪-材质动效示意.gif',save_all=True,append_images=frames[1:],duration=120,loop=0)
interface={'version':'C4-summer-autumn-lotus-v1','scope':'Summer dense crown geometry/flowers/lotus/wheat/sun/heat; autumn large gold/orange vegetation. No new gameplay. Spring and winter retained. Static design, not runtime pass.',
 'assets':assets,'shader_copy':[{'source':str(D/'夏秋植物材质.gdshader'),'target':'res://ayu_home/v4/assets/village/c4-summer-autumn-v1/season-material.gdshader','sha256':sha(D/'夏秋植物材质.gdshader')},{'source':str(D/'麦田热浪.gdshader'),'target':'res://ayu_home/v4/assets/village/c4-summer-autumn-v1/wheat-heat.gdshader','sha256':sha(D/'麦田热浪.gdshader')}],
 'existing_mask_bindings':'res://ayu_home/v4/assets/village/c4-spring-v1/bindings.json','no_new_control_masks':True,
 'low_decorations':decor,'tree_crowns':crowns,'lotus':lotus,
 'placement_policy':['All positions are world top-left; size is final world draw rect; original foot/positions unchanged.','Summer-only overlays hidden for spring/autumn/winter. Effective season follows existing effects_enabled policy.','Crown shares original root/foot; no new root collision; baked H7 crown must be BEHIND house sprite so roof stays unchanged.','Low flowers/wheat rendered above base ground but below houses/NPCs/player, no collision.','Lotus above existing public_pond sprite, within existing water. No new task/reward/item or changed fish feeding.'],
 'pond_access':{'existing_pond_prop':'public_pond','pond_rect':[1035,1000,435,245],'feeding_hotspot':[1450,1250],'existing_approach':[1450,1280],'water_collision_only_if_not_already_covered':[[1165,1080,235,28],[1148,1108,264,42],[1170,1150,220,24]],'shore_walk_space':'Keep entire south/east approach outside water unobstructed, no new bank wall.','nav':'Only if missing water solids are added, C2 rebakes village navigation and C3 walks approach.'},
 'sun':{'season':1,'area':'outdoor village','weather_strength':{'clear':1.0,'cloud':.25,'rain':0.0,'snow':0.0},'hour_gate':[[0,0],[8,0],[9.5,1],[15.5,1],[17.5,0],[24,0]],'material_uniform':'summer_sun','behavior':'Bright warm leaf glints with saturated source greens, not whole-frame exposure/colour overlay. Keep original weather/day-night ambient and indoors. Generated crowns/flowers carry warm highlights; reuse weather modulation.'},
 'heat':{'shader_asset':'wheat-heat.gdshader','applies_to':'summer_wheat_field4 TEXTURE only, never screen_texture/UI/player','uniform':'heat_strength','gate':'effects_enabled AND season1 AND clear AND hour12..16; ease gate over0.5s','range':[0,1],'maximum_displacement_world_px':1.0125,'field_world_size':[585,215],'rain_uniform':'existing rain factor','preview':'麦田热浪-材质动效示意.gif is mathematical preview, not in-game evidence'},
 'cicada_C2_logic':{'scope':'summer outdoor daytime; strongest10..17 on clear, subdued on cloud, mute at night/rain/indoors','source':'existing available sound or free native synthesis, no paid service','controls':'Existing sound toggle/master volume and existing dialogue ducking; no new settings/UI','mix':'quiet intermittent fast trills, nominal0.10 volume, avoid continuous loud tone'},
 'autumn':{'targets':'existing vegetation R masks only, deciduous/fruit/crops/grass golden/orange; evergreen bamboo22% blend','unchanged':'source houses/roads/water/player; spring block and winter block retained','summer_wheat_removed':'Summer decorative wheat layer hides in autumn; original field still receives strong gold vegetation palette.'},
 'views':{'sheet':'同机位春夏秋-荷塘麦田门前-设计预览.png','columns':['spring current','summer proposed','autumn proposed'],'rows':views,'hour':13,'weather':'clear in all panels','viewport_each':[640,360],'scale':1.15,'type':'native asset/material composition without actors/HUD, not screenshots'},
 'source_sha256':{'village':sha(P/'ayu_home/v4/assets/village.json'),'spring_shader':sha(P/'ayu_home/v4/assets/village/c4-spring-v1/season-material.gdshader'),'spring_bindings':sha(P/'ayu_home/v4/assets/village/c4-spring-v1/bindings.json')},
 'cost':{'generated_assets':4,'normalized_texture_rgba_bytes':sum(x['size'][0]*x['size'][1]*4 for x in assets),'summer_sprites':len(decor)+len(crowns)+1,'new_tree_roots':0,'control_mask_memory_increment':0},
 'pending':'C1 review -> C2 compile/integrate/day-weather/audio/heat logic -> C3 live seasonal, approach, night/rain/audio/heat checks.'}
(D/'C2夏秋荷塘接入-v1.json').write_text(json.dumps(interface,ensure_ascii=False,indent=2))
print(json.dumps(interface['cost']));print('Same-view spring/summer/autumn sheet, heat preview and exact interface saved.')
