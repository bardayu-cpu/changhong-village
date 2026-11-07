#!/usr/bin/env python3
"""Run R0 native camera/walk captures; all bitmap/log output stays in scratch.
Usage: python3 godot/tools/run_estate_camera_r0.py --godot /path/to/Godot
Requires imported project resources and a native display for screenshots.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default=os.environ.get('GODOT', '/Applications/Godot.app/Contents/MacOS/Godot'))
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    scratch = root / 'scratch/r0'
    scratch.mkdir(parents=True, exist_ok=True)
    common = [args.godot, '--path', str(root / 'godot')]
    for name, script, flags in [
        ('bounds', 'test_estate_camera_bounds.gd', ['--headless']),
        ('full', 'test_estate_camera_r0.gd', ['--resolution', '64x64', '--position', '0,0']),
    ]:
        command = common + flags + ['--log-file', str(scratch / (name + '-engine.log')), '--script', 'res://tools/' + script]
        with (scratch / (name + '.log')).open('w') as log:
            result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=900)
        text = (scratch / (name + '.log')).read_text()
        if 'SCRIPT ERROR:' in text or 'Failed loading resource:' in text or 'Unable to open file:' in text:
            print(f'{name}: resource/script error; inspect scratch/r0/{name}.log')
            return 1
        if result.returncode not in (0, 2):
            print(f'{name}: failed ({result.returncode})')
            return 1
    report = json.loads((scratch / 'results.json').read_text())
    blocked = [r for r in report['rows'] if 'movement' in r and not r['movement']['reached']]
    invalid = [r for r in report['rows'] if r.get('movement', {}).get('invalid_steps', 0)]
    print(f"captures={len(report['rows'])}; camera failures={len(report['failures'])}; unreachable={len(blocked)}; invalid-step routes={len(invalid)}")
    return 1 if report['failures'] or invalid else (2 if blocked else 0)


if __name__ == '__main__':
    sys.exit(main())
