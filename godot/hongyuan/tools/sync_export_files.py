"""Sync runtime resources. Web keeps all delivery art; WeChat includes reachable art only."""
from pathlib import Path
import fnmatch
import json
import re

root = Path(__file__).resolve().parents[2]
assets = root / 'hongyuan/assets'
art = sorted(p for p in assets.rglob('*') if p.suffix in {'.png', '.webp', '.svg'} and 'w2_review' not in p.parts)
scripts = sorted(p for p in (root / 'hongyuan').rglob('*.gd') if not {'tests', 'tools'} & set(p.parts))
fonts = sorted(p for p in (root / 'hongyuan/fonts').glob('*') if p.suffix in {'.tres', '.ttf', '.woff2'})
common = scripts + fonts + [root / 'hongyuan/boot.tscn', root / 'hongyuan/player.tscn']
common += [root / 'hongyuan/world_entry.tscn', root / 'hongyuan/village_entry.tscn']
# These modules load maps, people and rooms by name, so Godot's static scene
# dependency scan alone cannot include their runtime resources.
world_files = [
    p for folder in ['scripts', 'shaders', 'assets', 'ayu_home']
    for p in (root / folder).rglob('*')
    if p.is_file() and p.suffix in {'.gd', '.gdshader', '.tscn', '.tres', '.dialogue', '.png', '.jpg', '.webp', '.svg', '.wav', '.ogg', '.ttf', '.woff2'}
    and not {'tests', 'tools', 'docs'} & set(p.parts)
]
common += world_files
guests = [root / ('assets/characters/lm/chr_LM-GUEST-%02d.png' % i) for i in [1, 2, 3, 4, 5, 6, 8]]
reachable = set()


def strings(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for item in value.values():
            yield from strings(item)
    elif isinstance(value, list):
        for item in value:
            yield from strings(item)


def include(value):
    if not any(ext in value for ext in ['.png', '.webp', '.svg']):
        return
    # The resolver uses the first existing fallback. Packing that same first choice is sufficient.
    for candidate in value.split('|'):
        candidate = candidate.removeprefix('res://hongyuan/assets/')
        pattern = re.sub(r'%[0-9]*[ds]', '*', candidate)
        for prefix in ['', 'w2/']:
            matches = [p for p in art if fnmatch.fnmatchcase(p.relative_to(assets).as_posix(), prefix + pattern)]
            if matches:
                reachable.update(matches)
                return


runtime_strings = set()
for chapter in (root / 'hongyuan/chapters').glob('*.json'):
    runtime_strings.update(strings(json.loads(chapter.read_text())))
for script in scripts:
    runtime_strings.update(re.findall(r'"([^"\n]+)"', script.read_text()))
for value in runtime_strings:
    include(value)
manifest = json.loads((assets / 'manifest.json').read_text())
# Legacy stage looks up background aliases; unused review aliases are not runtime dependencies.
for key, entry in manifest.get('backgrounds', {}).items():
    if key in runtime_strings:
        for value in strings(entry):
            include(value)
# Keep these small dynamic maps whole (e.g. id + '_avatar', animation frame arrays).
for section in ['sprites', 'images']:
    for value in strings(manifest.get(section, {})):
        include(value)


def refs(paths):
    return ['res://' + p.relative_to(root).as_posix() for p in paths]


p = root / 'export_presets.cfg'
parts = re.split(r'(?=^\[preset\.\d+\]$)', p.read_text(), flags=re.M)
for i, part in enumerate(parts):
    web = 'name="红缘Web"' in part
    wechat = 'name="红缘微信"' in part
    if not (web or wechat):
        continue
    found = re.search(r'export_files=PackedStringArray\((.*?)\)\n', part)
    if not found:
        raise RuntimeError('Missing export_files in Hongyuan preset')
    files = refs(common + guests + (art if web else sorted(reachable)))
    if web:
        files += re.findall(r'"([^"]+)"', found.group(1))
    line = 'export_files=PackedStringArray(' + ', '.join('"%s"' % f for f in sorted(set(files))) + ')\n'
    part = part.replace(found.group(0), line)
    part = re.sub(r'include_filter="([^"]*)"', lambda m: 'include_filter="' + ','.join(dict.fromkeys(m.group(1).split(',') + ['assets/*.json', 'assets/*.dialogue', 'assets/*.jpg', 'ayu_home/*.json', 'ayu_home/*.nav'])) + '"', part, count=1)
    parts[i] = part
p.write_text(''.join(parts).rstrip() + '\n')
print('Web art:', len(art), 'WeChat reachable art:', len(reachable), 'scripts/fonts:', len(common))
