#!/usr/bin/env python3
"""Fail rather than quietly deliver against a replaced approved reference.

Run at the beginning of a work session and immediately before delivery, then
visually open the actual files in that folder. This check does not substitute
for looking at the latest art.
"""
from pathlib import Path
from PIL import Image
import hashlib,json,datetime
V2=Path(__file__).resolve().parents[1]
manifest=json.loads((V2/'reference_manifest.json').read_text())
results=[]
for info in manifest['files']:
    source=Path(info['source'])
    digest=hashlib.sha256(source.read_bytes()).hexdigest()
    assert digest==info['sha256'], f'定稿已替换，必须重做拆层和自验：{source}'
    with Image.open(source) as im:size=list(im.size)
    assert size==info['size']
    results.append({'file':str(source),'sha256':digest,'dimensions':size})
report={'checked_at':datetime.datetime.now().astimezone().isoformat(),'folder':str(Path(results[0]['file']).parent),'files':results,'result':'PASS; still requires visual inspection'}
out=V2/'evidence/validation/reference-preflight.json';out.parent.mkdir(parents=True,exist_ok=True)
out.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print('REFERENCE PASS: current approved folder, 3 files, hashes and dimensions unchanged')
