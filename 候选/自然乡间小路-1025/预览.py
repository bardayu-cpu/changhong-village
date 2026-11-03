#!/usr/bin/env python3
"""Create an isolated runnable candidate; never overwrite the active project."""
from pathlib import Path
import argparse,hashlib,json,shutil,subprocess
ap=argparse.ArgumentParser();ap.add_argument('--target',type=Path,required=True);ap.add_argument('--run',action='store_true');args=ap.parse_args()
here=Path(__file__).resolve().parent;repo=here.parents[1];target=args.target.expanduser().resolve()
if target.exists():raise SystemExit('Target already exists; choose a new isolated directory. No files changed.')
manifest=json.loads((here/'bundle.json').read_text())
for row in manifest['files']:
 f=here/'overlay'/row['path']
 if hashlib.sha256(f.read_bytes()).hexdigest()!=row['sha256']:raise SystemExit('Candidate hash mismatch: '+row['path'])
shutil.copytree(repo/'godot',target,ignore=shutil.ignore_patterns('运行数据','测试数据','.DS_Store'))
for row in manifest['files']:
 f=target/row['path'];f.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(here/'overlay'/row['path'],f)
qa=target/'_preview';frames=qa/'frames';frames.mkdir(parents=True);shutil.copy2(here/'查看坐标.json',qa/'查看坐标.json')
print('Created isolated candidate:',target,flush=True)
if args.run:
 cmd=['/Applications/Godot.app/Contents/MacOS/Godot','--path',str(target),'--script',str(here/'preview.gd'),'--','--ayu-save='+str(qa/'life.json'),'--core-save='+str(qa/'core'),'--ayu-hour=13','--ayu-month=7','--ayu-weather=clear','--qa-out='+str(frames)]
 raise SystemExit(subprocess.call(cmd))
