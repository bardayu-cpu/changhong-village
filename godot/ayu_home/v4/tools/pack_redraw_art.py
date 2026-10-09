#!/usr/bin/env python3
"""Sample artwork into the requested coarse pixel grid, and extract alpha sprites."""
from pathlib import Path
from PIL import Image
import shutil, json, hashlib
V=Path(__file__).resolve().parents[1];A=V/'assets/floor1-redraw';S=A/'sources';S.mkdir(exist_ok=True)
G=Path('/Users/kayra_ayu/.codex/generated_images/01a10845-1178-7801-bca0-dd50a6a1b5c2')
files={
 'tea':'9fd5ef35-f29f-427c-aa6d-705154cb7b50',
 'soup':'ed384071-da55-4143-93fe-50536c9f798d',
 'laundry':'fa3b7030-f2ba-4a35-bc1e-369de3182170',
 'wood':'5bbb7ded-ef89-44cc-8bfd-8aaee8852fbd',
 'pairs':'aaf7efef-c126-4ee4-af66-17df2a7d9e2b',
 'stars-day':'48c37ba1-a045-47d4-a477-9667f0c39d3e',
 'stars-night':'32cb8aef-34d6-4051-94db-3dde8e91a28e',
 'household':'428de11f-e97f-48a3-8f9e-589e0d9c724b',
 'botanical':'3e942552-de48-45b3-b089-5acdf93b202c',
 'meals':'06f07f82-0fd7-4cd6-bcd0-95570fb85b74'}
manifest={}
for name,uid in files.items():
 source=S/(name+'.png')
 if not source.exists():shutil.copy2(G/('exec-'+uid+'.png'),source)
 im=Image.open(source).convert('RGBA')
 manifest[name]={'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'source_size':list(im.size)}
 if name not in ['household','botanical','meals']:
  im.resize((154,188),Image.Resampling.NEAREST).save(A/(name+'.png'))
  manifest[name]['logical_pixels']=[154,188]
 else:
  sizes=([64,48,90,54,80,72,72,24,24,24,24,24,24,24,24,64] if name=='household' else [32,32,32,40,32,48,24,24,48,32,32,32,32,32,24,24])
  for i in range(16):
   x=i%4;y=i//4;tile=im.crop((x*im.width//4,y*im.height//4,(x+1)*im.width//4,(y+1)*im.height//4))
   alpha=tile.getchannel('A').point(lambda x:255 if x>=128 else 0);tile.putalpha(alpha)
   bbox=alpha.getbbox()
   if not bbox:raise ValueError((name,i,'empty'))
   tile=tile.crop(bbox);limit=32 if name=='meals' else sizes[i]
   ratio=limit/max(tile.size);tile=tile.resize((max(1,round(tile.width*ratio)),max(1,round(tile.height*ratio))),Image.Resampling.NEAREST)
   tile.save(A/(('meal' if name=='meals' else name)+'-'+str(i)+'.png'))
  manifest[name]['sprites']=16
# The existing florist workbench was already a detailed painting; retain composition
# and put it on the same coarse display grid as the new household backgrounds.
Image.open(V/'assets/life-scenes.png').crop((0,676,560,1400)).resize((154,188),Image.Resampling.NEAREST).save(A/'flowers.png')
(A/'art-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('Packed 8 scene backgrounds and 48 alpha sprites; backgrounds display at ~3px/cell on 540px screens')
