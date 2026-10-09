from pathlib import Path
from PIL import Image,ImageDraw
import json,random
R=Path(__file__).resolve().parents[1];A=R/'godot/ayu_home/v4/assets';V=A/'village';P=R/'godot/ayu_home/v3/assets';N=Image.Resampling.NEAREST
m=json.loads((A/'rooms.json').read_text());rooms=m['rooms'];plans=json.loads((V/'topology.json').read_text())['interiors'];random.seed(23)
guest=Image.open(P/'guest_floor.png').convert('RGBA');window=guest.crop((58,399,305,457));window.resize((196,46),N).save(V/'window.png')
for idx,(id,(w,h,walls,furn)) in enumerate(plans.items()):
 im=Image.new('RGBA',(w,h),'#ae7947');d=ImageDraw.Draw(im)
 # Ordinary warm planks, with staggered joints, without cloning a furniture erase patch.
 for row,y in enumerate(range(75,h,22)):
  for x in range(-96 if row%2 else 0,w,192):
   c=random.choice(['#ad7948','#b17d49','#b27e4b','#b5824f','#aa7546']);d.rectangle((x,y,x+189,y+20),fill=c);d.line((x,y,x+190,y),fill='#c99960',width=2);d.line((x,y+21,x+192,y+21),fill='#815732',width=1)
   for j in range(3):
    gx=random.randint(x+6,x+165);gy=random.randint(y+3,y+17);d.rectangle((gx,gy,gx+random.randint(8,25),gy+1),fill='#ba8752')
 # Kitchen / wet utility corners: household-specific sizes, slate not another wood palette swap.
 for x,y,kind in furn:
  if kind=='kitchen':
   for xx in range(max(12,x-22),min(w-12,x+182),32):
    for yy in range(92,min(h-45,y+210),30):d.rectangle((xx,yy,xx+29,yy+27),fill='#b4aa8c',outline='#c7bc9b')
 d.rectangle((10,12,w-12,74),fill='#d3bf93')
 for i in range(w//8):
  x=random.randrange(12,w-14);y=random.randrange(15,72);d.rectangle((x,y,x+3,y+2),fill='#d9c69e')
 for yy,c in [(5,'#563c27'),(9,'#977146'),(74,'#705035'),(79,'#d2a975')]:d.rectangle((6,yy,w-6,yy+3),fill=c)
 for x,y,ww,hh in walls:
  # Readable partitions with a dark plinth and light plaster surface.
  d.rectangle((x-2,y-10,x+ww+2,y+hh),fill='#64462f');d.rectangle((x,y-8,x+ww-1,y+hh-6),fill='#d0bc91');d.line((x,y-10,x+ww,y-10),fill='#edddbc',width=3)
 d.rectangle((0,0,9,h),fill='#654830');d.rectangle((w-10,0,w,h),fill='#654830');d.rectangle((0,h-20,w//2-55,h),fill='#8d6843');d.rectangle((w//2+55,h-20,w,h),fill='#8d6843')
 # A worn woven mat near the entrance; design differs in width and orientation with the plan.
 rx,ry=w//2-65,h-132;d.rectangle((rx,ry,rx+130,ry+75),fill='#5e8170',outline='#3c5b4e',width=3)
 for off in [5,10]:d.rectangle((rx+off,ry+off,rx+130-off,ry+75-off),outline='#c9b78a',width=2)
 for xx in range(rx+18,rx+119,22):d.rectangle((xx,ry+33,xx+5,ry+38),fill='#d8c694')
 im.save(V/f'interior_{id}.png');c=rooms['v_'+id]
 c['props']=[p for p in c['props'] if not p['id'].startswith('detail_')]
 c['props'].append(dict(id='detail_window',file='res://ayu_home/v4/assets/village/window.png',pos=[w//2-98,21],foot=75,front=False))
 for n,(x,y) in enumerate([(25,h-230),(w-72,90)]):c['props'].append(dict(id='detail_plant'+str(n),file='exterior_pot_window_left.png',pos=[x,y],foot=y+68,front=False))
 c['lamps']=[[int(w*.32),115,240],[int(w*.72),int(h*.7),220]]
 if 'v_'+id+'_up' in rooms:
  rooms['v_'+id+'_up']['props'].append(dict(id='detail_window',file='res://ayu_home/v4/assets/village/window.png',pos=[w//2-98,21],foot=75,front=False))
for k,c in rooms.items():(A/(k+'.json')).write_text(json.dumps(c,ensure_ascii=False,indent=2))
(A/'rooms.json').write_text(json.dumps(m,ensure_ascii=False,indent=2))
# Reviewable composed overview, clearly source art rather than an engine screenshot.
bg=Image.open(V/'ground.png').convert('RGBA')
for prop in sorted(rooms['village']['props'],key=lambda p:p['foot']):
 path=prop['file'];src=R/'godot'/path.removeprefix('res://') if path.startswith('res://') else P/path
 art=Image.open(src).convert('RGBA');bg.alpha_composite(art,tuple(prop['pos']))
bg.thumbnail((1150,1500),N);bg.save(R/'交付/完整村庄-1006/村庄总览-场景素材合成.png')
print('Refined',len(plans),'interior floors and completed native asset overview')
