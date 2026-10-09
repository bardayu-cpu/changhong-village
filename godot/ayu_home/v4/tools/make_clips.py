#!/usr/bin/env python3
"""Package actual rendered input-test frames into compact GIFs; never render synthetic gameplay."""
from pathlib import Path
from PIL import Image
import json
E=Path(__file__).resolve().parents[1]/'evidence';out=E/'clips';out.mkdir(exist_ok=True);index=[]
for folder in sorted((E/'play').iterdir()):
 if not folder.is_dir():continue
 files=sorted(folder.glob('[0-9][0-9][0-9][0-9].png'))
 if not files:continue
 frames=[]
 for file in files:
  im=Image.open(file).convert('RGB');im.thumbnail((360,640),Image.Resampling.NEAREST)
  frames.append(im.quantize(colors=256,method=Image.Quantize.FASTOCTREE))
 dest=out/(folder.name+'.gif')
 frames[0].save(dest,save_all=True,append_images=frames[1:],duration=180 if folder.name!='thirty-minute-route' else 900,loop=0,optimize=False,disposal=2)
 index.append({'clip':dest.name,'source':'Actual Godot SubViewport frames with input events','frames':len(files),'size_bytes':dest.stat().st_size,'playback':'Event-sampled, accelerated recap; see JSON for measured wall time','isolated_growth_clock_fixture':folder.name.startswith('harvest-')})
 print(dest.name,len(files),dest.stat().st_size,flush=True)
(out/'index.json').write_text(json.dumps(index,ensure_ascii=False,indent=2)+'\n')
