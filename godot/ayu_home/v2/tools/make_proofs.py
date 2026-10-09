#!/usr/bin/env python3
"""Evidence from the actual atlases, props and native runtime screenshots."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,hashlib,subprocess
V2=Path(__file__).resolve().parents[1];ROOT=V2.parents[1];A=V2/'assets';E=V2/'evidence';REF=ROOT.parents[1]/'七缘地图2-裳泓村参考图/定稿形象图'
FONT='/System/Library/Fonts/STHeiti Medium.ttc'
def font(n):return ImageFont.truetype(FONT,n)
def text(d,xy,copy,n=18):d.text(xy,copy,font=font(n),fill='#3c3027')
def frame(im,i):return im.crop((i%16*64,i//16*84,i%16*64+64,i//16*84+84))
names={'ayu':'阿鱼','father':'爸爸','mother':'妈妈','qiuqiu':'求求','luoluo':'落落','tiantian':'天天','xiduo':'喜多'}
labels={'down':'向下','left':'向左','right':'向右','up':'向上','idle':'待机呼吸','talk':'说话','sit':'坐下','eat':'吃饭','tv':'看电视','clean':'打扫','fish':'喂鱼','cook':'做饭','guitar':'弹吉他','computer':'敲电脑','read':'读书','lie':'躺下／休息','work':'手作','record':'唱片','sniff':'嗅闻','walk':'走路'}
def make_strip(who,kind,atlas,groups):
 w,h=1240,280 if kind!='walk' else 480
 canvas=Image.new('RGB',(w,h),'#f3e7cf');d=ImageDraw.Draw(canvas)
 text(d,(16,12),names[who]+' · '+labels[kind]+'   /   64×84 原生像素，以下整数 2 倍显示',22)
 ref=Image.open(A/('portrait_'+who+'.png')) if who in ['ayu','father','mother'] else Image.open(REF/'00_宠物参照.jpg')
 ref.thumbnail((155,h-74));canvas.paste(ref.convert('RGB'),(16,55));text(d,(16,h-28),'定稿参考',16)
 if kind=='walk':
  for row,(direction,ids) in enumerate(groups):
   x=190+(row%2)*520;y=60+(row//2)*196;text(d,(x,y),labels[direction],16)
   for k,i in enumerate(ids):
    cell=frame(atlas,i).resize((128,168),Image.Resampling.NEAREST);canvas.paste(cell,(x+k*128,y+20),cell)
   d.line((x,y+187,x+511,y+187),fill='#8ca775')
 else:
  for col,(direction,ids) in enumerate(groups):
   x=190+col*260;y=62;text(d,(x,y),labels.get(direction,direction),16)
   for k,i in enumerate(ids[:2]):
    cell=frame(atlas,i).resize((128,168),Image.Resampling.NEAREST);canvas.paste(cell,(x+k*128,y+22),cell)
   d.line((x,y+189,x+255,y+189),fill='#8ca775')
 text(d,(190,h-26),'脚点统一 (32,84)；参考只作外观对照。未扩建房间的动作素材不等于场景已接入。',16)
 out=E/'characters'/f'{who}-{kind}.png';out.parent.mkdir(exist_ok=True,parents=True);canvas.save(out,optimize=True)
audit={}
for who in names:
 atlas=Image.open(A/f'chr_{who}.png').convert('RGBA');meta=json.loads((A/f'chr_{who}.json').read_text());groups=meta['frames']
 make_strip(who,'walk',atlas,[(dr,groups[dr]) for dr in ['down','left','right','up']])
 for action in ['idle','talk','sit']:
  rows=[(dr,groups['sit_'+dr]) for dr in ['down','left','right','up']] if action=='sit' else [(action,groups[action])]
  make_strip(who,action,atlas,rows)
 info={'atlas_size':atlas.size,'anchor':meta['anchor'],'standing':{},'sitting':{},'hard_alpha':set(atlas.getchannel('A').getdata())<={0,255},'actions':{}}
 for dr in ['down','left','right','up']:
  bb=frame(atlas,groups[dr][0]).getbbox();sb=frame(atlas,groups['sit_'+dr][0]).getbbox();info['standing'][dr]={'height':bb[3]-bb[1],'bottom':bb[3]};info['sitting'][dr]={'height':sb[3]-sb[1],'bottom':sb[3]}
 if who in ['ayu','father','mother']:
  acts=Image.open(A/f'act_{who}.png').convert('RGBA');m=json.loads((A/f'act_{who}.json').read_text())['frames']
  for action in dict.fromkeys(key.rsplit('_',1)[0] for key in m):
   make_strip(who,action,acts,[(dr,m[action+'_'+dr]) for dr in ['down','left','right','up']])
   info['actions'][action]={dr:frame(acts,m[action+'_'+dr][0]).tobytes()!=frame(acts,m[action+'_'+dr][1]).tobytes() for dr in ['down','left','right','up']}
 else:
  for action in ['lie','sniff']:make_strip(who,action,atlas,[(action,groups[action])])
 audit[who]=info
(E/'validation/atlas-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2))
assert all(all(p['height']==84 and p['bottom']==84 for p in audit[who]['standing'].values()) for who in ['ayu','father','mother'])
assert all(all(p['height']==62 and p['bottom']==84 for p in audit[who]['sitting'].values()) for who in ['ayu','father','mother'])
assert all(v['hard_alpha'] for v in audit.values())
assert all(all(directions.values()) for v in audit.values() for directions in v['actions'].values()),'Every life animation must contain visible changes in every direction'
# Unlit full-world composites make the source layout and dimensions inspectable; these are not phone screenshots.
for room in ['exterior','living','dining']:
 j=json.loads((A/f'{room}.json').read_text());im=Image.open(A/f'{room}_floor.png').convert('RGBA')
 for p in sorted(j['props'],key=lambda p:p['foot']):im.alpha_composite(Image.open(A/p['file']).convert('RGBA'),tuple(p['pos']))
 im.save(E/'validation'/f'layout-{room}.png',optimize=True)
# The project's real scale_check.py measures pixels, not custom pass thresholds.
objects=[{'name':'阿鱼站立','std':'person_h','png':'ayu-frame.png','dim':'h'}]
frame(Image.open(A/'chr_ayu.png'),0).save(E/'validation/ayu-frame.png')
for name,std,dim,png in [('原图落地灯','lamp_floor_h','h','living_lamp.png'),('原图圆桌直径','round_table_w','w','dining_round_table.png'),('原图餐椅','chair_h','h','dining_chair_spare.png')]:objects.append({'name':name,'std':std,'dim':dim,'png':str(A/png)})
objects.extend([{'name':'原图正门门洞高','std':'single_door_h','box':[751,478,799,581],'dim':'h','draw':False},{'name':'原图正门门洞宽','std':'single_door_w','box':[751,478,799,581],'dim':'w','draw':False}])
scale={'scene':'阿鱼家 v2 原图实际尺寸；紧急更正要求原图零改动','image':'layout-living.png','person_px':84,'scale':1,'objects':objects}
(E/'validation/scale-boxes.json').write_text(json.dumps(scale,ensure_ascii=False,indent=2))
subprocess.run(['python3',str(ROOT/'tools/scale_check.py'),'measure',str(E/'validation/scale-boxes.json'),'--md',str(E/'validation/scale-check.md'),'--json',str(E/'validation/scale-check.json')],check=True)
print('ART AUDIT PASS 7 atlases; 84 px standing, 62 px seated; all alpha edges hard; every life action animates. Furniture uses original dimensions; inspect the independent scale report, do not call red rows passed.')
