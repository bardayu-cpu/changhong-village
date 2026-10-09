#!/usr/bin/env python3
"""Code-pixel people/pets and audio only; scenery is restored from approved originals."""
from pathlib import Path
import sys, importlib.util, math, json, random, hashlib, wave, struct
from PIL import Image, ImageDraw
ROOT=Path(__file__).resolve().parents[3]; OUT=ROOT/'ayu_home/v2/assets'; OUT.mkdir(parents=True,exist_ok=True)
def module(name,path):
 s=importlib.util.spec_from_file_location(name,path); m=importlib.util.module_from_spec(s); s.loader.exec_module(m); return m
sys.path.insert(0,str(ROOT/'tools/pixel_art'))
C=module('roman_people',ROOT/'回执/样板间-代码小人-休息间四位/draw_chars.py')
REF=ROOT.parents[1]/'七缘地图2-裳泓村参考图/定稿形象图'
rng=random.Random(104)
C.RAMPS.update({k:[C.hx(v) for v in cs] for k,cs in {
 'red_string':['631b25','952334','bb3345','d95361','ed8990'],
 'ayu_hair':['100e15','18171d','26242c','37313a','514349'],
 'white':['504247','aca2a0','d7ceca','f5eee6','fffaf2'],
 'blue':['18233d','233969','2d5191','3e6ab2','6e99d2'],
 'pink':['4f2b2c','8f4a48','bb7068','da9a89','f3bd9f'],
 'navy':['151a2a','212b41','303e57','42516d','62748b'],
 'brown_hair':['221319','362028','57352f','794838','a96e49']}.items()})
old_front=C.hair_front; old_side=C.hair_side; old_detail=C.torso_details; old_arm=C.draw_arm
# Extend the existing code-pixel anatomy, preserving contact and directional lighting.
def hair_front(F,P,g,dy,back):
 if P['hair_style']!='long': return old_front(F,P,g,dy,back)
 q=dict(P,hair_style='swept'); top=g['top']+dy; chin=g['chin']+dy
 old_front(F,q,g,dy,back)
 for s in (-1,1):
  F.capsule(32+s*12,top+13,32+s*15,min(chin+25,69),3.2,4,'longhair','hair',P['hair'])
 if back:
  F.rows(top+15,min(chin+27,70),lambda y:14.5,'longhair','hair',P['hair'],('vcyl',30,17,0))
 C.hair_bands(F,lambda x,y:x+math.sin(y*.14),3.2,top+12,chin+28,parts=('longhair',))
def hair_side(F,P,g,dy,sx,f,hc,hr,pose=None):
 if P['hair_style']!='long': return old_side(F,P,g,dy,sx,f,hc,hr)
 old_side(F,dict(P,hair_style='swept'),g,dy,sx,f,hc,hr)
 F.capsule(sx(hc-8),g['top']+dy+14,sx(hc-10),min(g['chin']+dy+26,70),5,7,'longhair','hair',P['hair'])
 C.hair_bands(F,lambda x,y:x+.15*y,3.2,g['top']+dy+12,g['chin']+dy+28,parts=('longhair',))
def details(F,P,g,sh,hem,back):
 if back:return
 mid=32
 if P['name']=='妈妈':
  for y in range(int(sh)+1,int(hem)):
   for x in range(28,35): F.recolor(x,y,mat='white',only=('torso',))
  for y in range(int(sh)+9,int(hem),7):F.put(36,y,C.hx('593c30'))
 elif P['name']=='爸爸':
  for y in range(int(sh)+1,int(sh)+8):
   for x in (30,32):F.recolor(x,y,dl=1,only=('torso',))
  for y in (int(sh)+3,int(sh)+7):F.put(32,y,C.hx('e5ddd2'))
 elif P['name']=='阿鱼':
  for x in range(27,37):F.recolor(x,sh+1,dl=-1,only=('torso',))
def arm(F,P,*args,**kw):
 old_arm(F,P,*args,**kw)
 if P['name']=='阿鱼':
  hx,hy=args[6],args[7]
  F.capsule(hx-1.7,hy-2,hx+1.7,hy-2,0.65,0.65,'bracelet','hand','red_string')
C.hair_front=hair_front;C.hair_side=hair_side;C.torso_details=details;C.draw_arm=arm
original_geom=C.geom
sit_adjust=0
def home_geom(P):
 g=original_geom(P);g['sit_dy']+=11+sit_adjust;return g
C.geom=home_geom
original_make_frame=C.make_frame
def aligned_frame(P,d,pose):
 global sit_adjust
 sit_adjust=0
 im=original_make_frame(P,d,pose)
 if pose.get('kind')=='sit':
  # Repose the torso, keeping the bent legs and feet planted; never shrink the bitmap.
  for _ in range(3):
   top=im.getbbox()[1]
   target=22+pose.get('bob',0)
   if top==target:break
   sit_adjust+=target-top;im=original_make_frame(P,d,pose)
 sit_adjust=0
 return im
C.make_frame=aligned_frame

PARAM={
 'ayu':dict(C.CHARS['10'],name='阿鱼',H=84,extra=0,sex='f',skin='skin',hair='ayu_hair',hair_style='long',top='white',bottom='suit_pants',shoe='shoe_black',sleeve='short',sw=22,hipw=23,leg_r=4.3,arm_r=3.0,face_rx=11.5),
 'father':dict(C.CHARS['10'],name='爸爸',H=84,extra=0,skin='skin',hair='ayu_hair',top='blue',sleeve='short',sw=26,hipw=24,face_rx=12),
 'mother':dict(C.CHARS['09'],name='妈妈',H=85,extra=2,skin='skin',hair='brown_hair',top='pink',bottom='navy',leg_mat='skin',shoe='shoe_brown',sw=24,hipw=23,hem_drop=8,jacket_frac=.75,face_rx=11.5)
}
ACTIONS=['eat','tv','clean','fish','cook','guitar','computer','read','lie','work','record']
BASE_FRAMES={'down':[0,1,2,3],'left':[4,5,6,7],'right':[8,9,10,11],'up':[12,13,14,15],'idle':[16,17],'talk':[18,19],'sit_down':[20,21],'sit_left':[22,23],'sit_right':[24,25],'sit_up':[26,27]}
def save(im,name):
 p=OUT/(name+'.png'); im.save(p,optimize=True); return name+'.png'
def action_frame(P,act,d,k):
 seated=act in ['eat','tv','guitar','computer','read','record']
 if act=='lie':
  # Deliberately drawn horizontal pose, no rotating a standing sprite.
  im=Image.new('RGBA',(64,84));q=ImageDraw.Draw(im)
  q.ellipse((1,49,24,72),fill=C.RAMPS[P['hair']][2]+(255,));q.ellipse((7,53,25,70),fill=C.RAMPS['skin'][3]+(255,))
  q.line((15,60,20,60),fill='#5c2a1e',width=1)
  q.rounded_rectangle((23,56,41,73),radius=3,fill=C.RAMPS[P['top']][3]+(255,),outline='#302129')
  q.rounded_rectangle((40,58,59,74),radius=2,fill=C.RAMPS[P['bottom']][2]+(255,),outline='#221c25');q.line((42,67,58,67),fill=C.RAMPS[P['bottom']][1]+(255,))
  q.rectangle((58,61,63,66),fill=C.RAMPS[P['shoe']][3]+(255,));q.rectangle((58,70,63,75),fill=C.RAMPS[P['shoe']][3]+(255,));q.line((27,64+k,41,65+k),fill='#fac28e',width=3)
  if P['name']=='阿鱼':q.line((35,64+k,35,67+k),fill='#bf3345');q.line((62,61,62,75),fill='#efe8e6')
  if d in ['left','up']:im=im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
  if d=='up':q=ImageDraw.Draw(im);q.ellipse((41,49,63,70),fill=C.RAMPS[P['hair']][2]+(255,))
  return im
 pose=dict(C.walk_poses(d)[0],kind='sit' if seated else 'walk',arms='lap' if seated else 'free',bob=k)
 im=C.make_frame(P,d,pose);overlay=Image.new('RGBA',(64,84));q=ImageDraw.Draw(overlay)
 # Anatomical forearms change locally; seated legs stay bent in all action frames.
 sy=52 if seated else 36; sign=1; hand=(32+sign*(13-k*5),sy+9-k*8)
 if act=='tv':return C.make_frame(P,d,dict(pose,bob=k))
 skin=C.RAMPS['skin'][3]+(255,); outline='#5c2a1e'
 q.line((32+sign*10,sy,hand[0],hand[1]),fill=outline,width=6);q.line((32+sign*10,sy,hand[0],hand[1]),fill=skin,width=4)
 if act=='eat':
  q.arc((22,sy+10,41,sy+20),0,180,fill='#463635',width=3);q.arc((24,sy+10,39,sy+17),0,180,fill='#eee1bd',width=3)
  q.line((hand[0],hand[1],hand[0]+sign*7,hand[1]-5),fill='#b08a49',width=1)
 elif act=='clean':
  q.line((hand[0],hand[1],45+k*4,78),fill='#8d5835',width=3);q.polygon([(39+k*4,75),(50+k*4,75),(54+k*4,82),(35+k*4,82)],fill='#caad64',outline='#6b5032')
 elif act=='fish':
  q.rectangle((hand[0]-3,hand[1]-4,hand[0]+3,hand[1]+3),fill='#deb550',outline='#71402a');q.point((hand[0]+sign*9,hand[1]+7+k*4),fill='#e6c696')
 elif act=='cook':
  q.ellipse((35,51,57,62),fill='#3b4144',outline='#151a2a');q.line((hand[0],hand[1],45,55),fill='#b8862b',width=2)
 elif act=='guitar':
  q.ellipse((26,55,49,76),fill='#c98d58',outline='#3a2218');q.ellipse((31,50,47,65),fill='#c98d58',outline='#3a2218');q.line((40,59,54,39),fill='#71402a',width=5);q.ellipse((36,59,42,65),fill='#22140f');q.line((30,65+k*3,41,62+k*3),fill=skin,width=3)
 elif act=='computer':
  q.rectangle((19,65,47,70),fill='#b5b9bf',outline='#46465c');q.line((24,60,29+k*4,66),fill=skin,width=3)
 elif act=='read':
  q.polygon([(20,59),(31,62),(44,58),(44,72),(31,75),(20,71)],fill='#eee0ba',outline='#845234');q.line((31,62,31,74),fill='#a77b45');q.line((23,63+k*2,28,64+k*2),fill='#ab956d')
 elif act=='work':
  q.line((hand[0],hand[1],hand[0]+k*3,hand[1]-10),fill='#8f5535',width=2);q.rectangle((hand[0]-4,hand[1]-13,hand[0]+4,hand[1]-10),fill='#737a8f')
 elif act=='record':
  q.ellipse((28,59,47,77),fill='#201c26',outline='#110f15');q.ellipse((35,66,40,71),fill='#de8399')
 if d=='left':overlay=overlay.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
 if d=='up':overlay.alpha_composite(im);return overlay
 im.alpha_composite(overlay)
 return im

def people():
 report={}
 for ident,P in PARAM.items():
  walk,extra=C.all_frames(P);frames=walk+extra;im=Image.new('RGBA',(1024,168))
  for i,fr in enumerate(frames):
   if ident=='ayu':
    d=ImageDraw.Draw(fr)
    for y in (81,82):
     for x in range(10,55):
      if fr.getpixel((x,y))[3] and fr.getpixel((x,y))[:3] in C.RAMPS['shoe_black']:d.point((x,y),fill='#efe8e6')
   im.paste(fr,(i%16*64,i//16*84))
  save(im,'chr_'+ident)
  meta=dict(frame=[64,84],frames=BASE_FRAMES,fps=8,idle_fps=2,talk_fps=3,sit_fps=1,height_m=1.75,anchor=[32,84])
  (OUT/('chr_'+ident+'.json')).write_text(json.dumps(meta,ensure_ascii=False,indent=2))
  actions={};af=[]
  for act in ACTIONS:
   for direction in ['down','left','right','up']:
    actions[act+'_'+direction]=[len(af),len(af)+1];af += [action_frame(P,act,direction,k) for k in range(2)]
  sheet=Image.new('RGBA',(1024,math.ceil(len(af)/16)*84))
  for i,fr in enumerate(af):sheet.paste(fr,(i%16*64,i//16*84))
  save(sheet,'act_'+ident);(OUT/('act_'+ident+'.json')).write_text(json.dumps(dict(frame=[64,84],frames=actions,fps=2,anchor=[32,84]),indent=2))
  report[ident]={'standing':[frames[i].getbbox() for i in [0,4,8,12]],'sitting':[frames[i].getbbox() for i in [20,22,24,26]]}
  ref=Image.open(REF/{'ayu':'阿鱼定稿1.png','father':'父亲定稿 1.png','mother':'母亲定稿 1.png'}[ident]);ref.thumbnail((192,288));save(ref,'portrait_'+ident)
 (OUT/'anatomy.json').write_text(json.dumps(report,indent=2))

def pet_frame(ident,d,k,mode='walk'):
 im=Image.new('RGBA',(64,84));q=ImageDraw.Draw(im);dog=ident=='xiduo';long=ident=='tiantian';c={'qiuqiu':['#48444b','#8b8890','#c2bec0'],'luoluo':['#784629','#c18545','#f1c17d'],'tiantian':['#855029','#c89756','#efd495'],'xiduo':['#75412a','#bf7c3c','#f7e8c9']}[ident];face=d!='up';side=d in ['left','right'];flip=d=='left'
 if mode=='lie':
  # Curled cat / resting corgi: recognisable ears, folded forepaws and tail;
  # all marks remain code pixels and keep the same (32,84) anchor.
  q.ellipse((13,65+k,51,82),fill=c[1],outline=c[0])
  q.ellipse((20,68+k,47,79),fill=c[2])
  q.line((44,78,49,74,51,76,48,81,34,82,26,79),fill=c[0],width=5)
  q.line((44,78,49,74,50,77,46,80,34,81,27,78),fill=c[1],width=3)
  q.ellipse((11,65,31,80),fill=c[1],outline=c[0])
  q.polygon([(12,70),(12,60 if not dog else 57),(19,65)],fill=c[1],outline=c[0])
  q.polygon([(22,64),(28,59 if not dog else 56),(30,70)],fill=c[1],outline=c[0])
  q.line((14,64,15,67),fill=c[2],width=2);q.line((26,63,26,66),fill=c[2],width=2)
  q.ellipse((14,71,27,79),fill=c[2]);q.line((14,71,17,72,19,71),fill=c[0]);q.line((23,71,25,72,27,71),fill=c[0]);q.point((21,75),fill='#78504c')
  q.line((17,80,23,80),fill=c[0]);q.line((26,80,31,80),fill=c[0])
  if ident in ['qiuqiu','luoluo']:
   for x in [29,35,41]:q.line((x,67+k,x+1,71+k),fill=c[0],width=2)
   for x in [17,22,26]:q.line((x,66,x,68),fill=c[0])
  if long:
   for x,y in [(15,76),(30,72),(34,68),(42,68),(46,75)]:q.line((x,y,x-2,y+3),fill=c[2],width=2)
  return im
 bottom=83;bob=k%2 if mode in ['walk','idle'] else 0;top=53 if not dog else 50
 if side:
  q.ellipse((14,62+bob,51,78),fill=c[1],outline=c[0]);q.ellipse((33,top+bob,54,73+bob),fill=c[2] if dog else c[1],outline=c[0]);q.polygon([(35,58),(35,48 if dog else 52),(42,57)],fill=c[1],outline=c[0]);q.polygon([(46,55),(51,48 if dog else 52),(53,61)],fill=c[1],outline=c[0]);
  for i,x in enumerate([20,29,40,48]):q.rectangle((x+(k%2*3 if i%2 else 0),75,x+3+(k%2*3 if i%2 else 0),bottom),fill=c[2],outline=c[0])
  if not dog:q.line((16,70,8,60+k*2,7,56+k*2),fill=c[0],width=5);q.line((16,70,8,60+k*2),fill=c[1],width=3)
  q.point((49,62+bob),fill='#18121a');q.point((54,68+bob),fill='#18121a')
  if flip:im=im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
 else:
  q.ellipse((20,64+bob,44,81),fill=c[1],outline=c[0]);q.rectangle((21,76,28,83),fill=c[2],outline=c[0]);q.rectangle((36,76,43,83),fill=c[2],outline=c[0]);q.ellipse((17,top+bob,47,73+bob),fill=c[1],outline=c[0]);q.polygon([(18,59),(19,48 if dog else 51),(27,55)],fill=c[1],outline=c[0]);q.polygon([(37,55),(45,48 if dog else 51),(47,60)],fill=c[1],outline=c[0])
  if face:
   q.ellipse((25,62+bob,40,72+bob),fill=c[2]);q.rectangle((23,60+bob,25,63+bob),fill='#201c26');q.rectangle((39,60+bob,41,63+bob),fill='#201c26');q.point((32,67+bob),fill='#382125')
  if long:
   for x in range(19,47,4):q.line((x,71,x-2,75+(x%3)),fill=c[2],width=2)
 if ident in ['qiuqiu','luoluo']:
  q=ImageDraw.Draw(im)
  for x in [25,31,37]:q.line((x,54+bob,x+1,57+bob),fill=c[0]);q.line((21,69,25,70),fill=c[0],width=2)
 return im

def pets():
 for ident in ['qiuqiu','luoluo','tiantian','xiduo']:
  frames=[]
  for d in ['down','left','right','up']:frames += [pet_frame(ident,d,k) for k in range(4)]
  frames += [pet_frame(ident,'down',k,'idle') for k in range(4)]
  for d in ['down','left','right','up']:frames += [pet_frame(ident,d,k,'idle') for k in range(2)]
  frames += [pet_frame(ident,'down',k,'lie') for k in range(2)]+[pet_frame(ident,'down',k) for k in range(2)]
  im=Image.new('RGBA',(1024,168))
  for i,f in enumerate(frames):im.paste(f,(i%16*64,i//16*84))
  save(im,'chr_'+ident);(OUT/('chr_'+ident+'.json')).write_text(json.dumps(dict(frame=[64,84],frames=dict(BASE_FRAMES,lie=[28,29],sniff=[30,31]),fps=8,anchor=[32,84]),indent=2))

PAL=['#9b7249','#ad8153','#be9160','#cba16c','#d9b47e','#e5c793'];OL='#3a2927'
def sounds():
 sr=22050;r=random.Random(72)
 for name,length in [('door',.7),('knock',.62),('living_amb',4),('dining_amb',4),('yard_amb',4),('switch',.11)]:
  vals=[]
  for i in range(int(sr*length)):
   t=i/sr;noise=r.uniform(-1,1);v=0
   if name=='knock':
    for st in [.02,.19,.36]:
     a=t-st
     if 0<a<.1:v+=(math.sin(a*420*math.tau)+noise*.3)*math.exp(-a*60)*.22
   elif name=='door':v=(noise*.05+math.sin(t*math.tau*(210-t*80))*.1)*math.sin(t/length*math.pi)**2
   elif name=='switch':v=noise*.1*math.exp(-t*80)
   elif name=='living_amb':v=.008*noise+.025*math.sin(math.tau*(130.81 if t%1<.5 else 164.81)*t)*math.sin(math.pi*(t%1))**2
   elif name=='dining_amb':v=noise*.055*(.7+.3*math.sin(t*4))+.009*math.sin(800*t)*max(0,1-(t%1.3)*18)
   else:v=noise*.015+.025*math.sin(math.tau*(1900+350*math.sin(t*12))*t)*max(0,math.sin(t*math.pi*2))**16
   vals.append(struct.pack('<h',int(max(-1,min(1,v))*32767)))
  with wave.open(str(OUT/(name+'.wav')),'wb') as f:f.setparams((1,2,sr,0,'NONE','not compressed'));f.writeframes(b''.join(vals))
if __name__=='__main__':
 people();pets();sounds()
 from restore_original import main
 main()
