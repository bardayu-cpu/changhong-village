"""Export the standalone love story to a new local directory."""
import argparse
from pathlib import Path
import subprocess
from export_project import love_project

parser = argparse.ArgumentParser()
parser.add_argument('output', type=Path)
parser.add_argument('--godot', default='/Applications/Godot.app/Contents/MacOS/Godot')
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
out = args.output.resolve()
out.mkdir(parents=True, exist_ok=False)
subprocess.run(['python3', str(Path(__file__).with_name('sync_export_files.py'))], check=True)
with love_project(root):
    subprocess.run([args.godot, '--headless', '--path', str(root), '--export-release',
                    '红缘Web', str(out / 'index.html')], check=True)
print('Exported:', out)
