"""Export the standalone love story to a new local directory."""
import argparse
from pathlib import Path
import subprocess
from export_project import love_project

parser = argparse.ArgumentParser()
parser.add_argument('output', type=Path)
parser.add_argument('--content-base-url', help='Split chapters; HTTPS production URL or ./content/ for a loopback-only test')
parser.add_argument('--development-content', action='store_true')
parser.add_argument('--godot', default='/Applications/Godot.app/Contents/MacOS/Godot')
parser.add_argument('--user-data-name', help='Separate review saves from existing player data')
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
out = args.output.resolve()
out.mkdir(parents=True, exist_ok=False)
subprocess.run(['python3', str(Path(__file__).with_name('sync_export_files.py'))], check=True)
with love_project(root, user_data_name=args.user_data_name):
    subprocess.run([args.godot, '--headless', '--path', str(root), '--export-release',
                    '红缘Web', str(out / 'index.html')], check=True)
if args.content_base_url:
    from split_web_pack import split_web
    source = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
    print('Chapter bytes:', split_web(out, root, source, args.content_base_url, args.development_content))
print('Exported:', out)
