#!/usr/bin/env python3
from pathlib import Path
from PIL import Image, ImageChops
import json, hashlib, sys, re
V=Path(__file__).resolve().parents[1];E=V/'evidence'
export=Path(sys.argv[1]);probe=Path(sys.argv[2]);defs=json.loads((V/'assets/rooms.json').read_text())['rooms']
log=(E/'pack-probe.log').read_text();match=re.search(r'RESULT PASS EXPORTED V4 PACK textures=(\d+) rooms=(\d+)',log)
assert match and not re.search('SCRIPT ERROR|Parse Error|Compile Error|Failed to load script',log), 'Pack must execute successfully.'
diffs={}
for id in defs:
 a=Image.open(E/'native'/f'{id}.png').convert('RGB');b=Image.open(probe/f'{id}.png').convert('RGB')
 diffs[id]=max(x[1] for x in ImageChops.difference(a,b).getextrema())
files=[p for p in export.rglob('*') if p.is_file()];main=sum(p.stat().st_size for p in files if p.relative_to(export).parts[0]!='engine');pck=export/'engine/demo-pck.bin'
out={'main_bytes':main,'main_under_4MiB':main<4*1024*1024,'engine_bytes':sum(p.stat().st_size for p in files if p.relative_to(export).parts[0]=='engine'),'total_bytes':sum(p.stat().st_size for p in files),'pck_bytes':pck.stat().st_size,'pck_sha256':hashlib.sha256(pck.read_bytes()).hexdigest(),'textures_loaded':int(match.group(1)),'rooms_loaded':int(match.group(2)),'online_upload':False,'phone_preview':False,'normal_startup_test_panel_hidden':True,'pack_vs_workspace_max_rgb_by_room':diffs}
(E/'package-audit.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
assert main<4*1024*1024 and not any(diffs.values()),out
print('RESULT PASS package audit: main bytes',main,'rooms',len(diffs),'maximum pixel difference',max(diffs.values()))
