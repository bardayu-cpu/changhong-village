from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json
V=Path(__file__).resolve().parents[1];A=V/'assets';E=V/'evidence';font=ImageFont.truetype('/System/Library/Fonts/STHeiti Medium.ttc',14)
for name,c in json.loads((A/'rooms.json').read_text())['rooms'].items():
 im=Image.open(E/'native'/f'{name}.png').convert('RGBA');layer=Image.new('RGBA',im.size);d=ImageDraw.Draw(layer);mask=(A/f'{name}.nav').read_bytes();cols=c['size'][0]//4
 for i,b in enumerate(mask):
  if b==0:x=(i%cols)*4;y=(i//cols)*4;d.rectangle((x,y,x+3,y+3),fill=(75,172,109,75))
 for r in c['obstacles']:x,y,w,h=r;d.rectangle((x,y,x+w,y+h),outline=(227,62,55,235),width=2)
 for door in c['doors']:
  x,y=door['approach'];d.ellipse((x-6,y-6,x+6,y+6),fill=(255,217,68,255));d.text((x+7,y-9),door['label'],font=font,fill=(68,31,19,255),stroke_width=1,stroke_fill=(255,249,219,255))
 Image.alpha_composite(im,layer).save(E/'overlay'/f'{name}.png',optimize=True)
print('RESULT PASS overlay 27 current native renders, baked walk masks, obstacles and real doors')
