#!/usr/bin/env python3
"""Apply the frozen label-only patch after the prior road sample overlay."""
from pathlib import Path
import argparse, hashlib, json, shutil, subprocess, sys

parser = argparse.ArgumentParser()
parser.add_argument('--target', type=Path, required=True)
parser.add_argument('--run', action='store_true')
args = parser.parse_args()
here = Path(__file__).resolve().parent
base = here.parent / '自然路肩样板-1025'
target = args.target.expanduser().resolve()
manifest = json.loads((here / 'bundle.json').read_text())
for row in manifest['files']:
    source = here / 'overlay' / row['path']
    if hashlib.sha256(source.read_bytes()).hexdigest() != row['sha256']:
        raise SystemExit('Patch changed: ' + row['path'])
subprocess.run([sys.executable, str(base / '预览.py'), '--target', str(target)], check=True)
for row in manifest['files']:
    shutil.copy2(here / 'overlay' / row['path'], target / row['path'])
print('Applied isolated second label patch:', target, flush=True)
if args.run:
    qa = target / '_preview'
    raise SystemExit(subprocess.call([
        '/Applications/Godot.app/Contents/MacOS/Godot', '--path', str(target),
        '--script', str(base / 'preview.gd'), '--',
        '--ayu-save=' + str(qa / 'life.json'), '--core-save=' + str(qa / 'core'),
        '--ayu-hour=13', '--ayu-month=7', '--ayu-weather=clear',
        '--qa-out=' + str(qa / 'frames')]))
