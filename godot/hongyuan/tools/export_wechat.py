"""Export love-story only to a NEW directory; never delete an existing candidate."""
import argparse
import json
import os
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
env = dict(os.environ, TOOLKIT_RELEASE_PROVIDER='github', TOOLKIT_RELEASE_OWNER='godothub',
           TOOLKIT_RELEASE_REPO='godot-minigame', TOOLKIT_RELEASE_TAG='4.7')
with love_project(root, wechat=True):
    subprocess.run([args.godot, '--headless', '--path', str(root), '--export-release', '红缘微信',
                    str(out / 'hongyuan.bin')], env=env, check=True)
pack = out / 'engine/demo-pck.bin'
if not pack.is_file():
    raise SystemExit('Missing engine/demo-pck.bin; candidate is incomplete.')
engine = out / 'engine/game.js'
text = engine.read_text()
old = "const pack = '/engine/empty-tips.bin';"
if old not in text:
    raise SystemExit('Template pack entry changed; review engine/game.js before shipping.')
engine.write_text(text.replace(old, "const pack = '/engine/demo-pck.bin';"))
# These files belong only to the newly created template export.
(out / 'engine/empty-tips.bin').unlink(missing_ok=True)
for name in ['game.json', 'project.config.json', 'project.private.config.json']:
    p = out / name
    if not p.exists():
        continue
    config = json.loads(p.read_text())
    if name == 'game.json':
        config['subpackages'] = [s for s in config.get('subpackages', []) if s.get('name') == 'engine']
    else:
        config['projectname'] = 'hongyuan-love'
    if name == 'project.config.json':
        # The Godot exporter writes the already-configured AppID. Never replace it with the template ID.
        config.setdefault('packOptions', {}).setdefault('ignore', []).extend([
            {'type': 'folder', 'value': 'subpackages'}, {'type': 'folder', 'value': 'subpacks'},
            {'type': 'suffix', 'value': '.md'}, {'type': 'suffix', 'value': '.import'},
        ])
    p.write_text(json.dumps(config, ensure_ascii=False, indent=2) + '\n')
print('Exported:', out)
print('D4 mobile verification and authenticated WeChat preview remain required.')
