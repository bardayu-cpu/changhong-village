"""Split a full export into an offline desk plus immutable, versioned chapter PCKs.
Only export artifacts are modified. Chapter JSON/scripts stay in the startup pack.
"""
import argparse
from collections import defaultdict
from hashlib import md5, sha256
import json
from pathlib import Path
import re
from split_wechat_pack import Entry, read_pack, write_pack, partition, CHAPTERS, MEDIA, CLOUD_CHUNK

STARTUP = {'bg_invite_desk.png', 'invite_card.png', 'invite_base.png', 'invite_pen_stroke.png',
           'invite_slot_pen.png', 'invite_slot_ink.png', 'pen_tip.png'}

def split_web(out, root, source, base_url, development=False):
    pack = out / 'index.pck'
    header, entries = read_pack(pack)
    groups = partition(entries)
    # Determine old root-level art ownership from actual chapter strings and alias maps.
    references = defaultdict(set)
    aliases = json.loads((root / 'hongyuan/assets/manifest.json').read_text()).get('backgrounds', {})
    games = {'drive': 'shanghai', 'desk_chat': 'call', 'pandas': 'chengdu', 'call': 'call',
             'fishing': 'shizuoka', 'onsen': 'shizuoka', 'ringtoss': 'hainan',
             'fireworks': 'hainan', 'photo': 'hongkong', 'offer': 'hongkong', 'mail': 'hongkong',
             'finale': 'finale', 'invite_mail': 'finale'}
    for chapter in CHAPTERS:
        text = (root / f'hongyuan/chapters/{chapter}.json').read_text()
        for key, value in aliases.items():
            if f'"{key}"' in text:
                text += json.dumps(value)
        for game, owner in games.items():
            if owner == chapter:
                text += (root / f'hongyuan/games/{game}.gd').read_text()
        for filename in re.findall(r'[\w./-]+\.(?:png|webp|svg|ogg)', text):
            references[Path(filename).name].add(chapter)
    assigned = {}
    for group, members in groups.items():
        for entry in members:
            name = entry.name.removesuffix('.import').removesuffix('.remap')
            target = group
            if name.startswith('hongyuan/assets/'):
                if Path(name).name in STARTUP or (name.startswith('hongyuan/assets/round1/common/') and group != 'finale') or re.search(r'w2/finale/slot_', name):
                    target = 'main'
                elif group == 'love-media':
                    owners = references[Path(name).name] - {'prologue'}
                    if len(owners) == 1:
                        target = next(iter(owners))
            if group == 'prologue':
                target = 'main'
            assigned[entry.name] = target
    # An import/remap and all of its payloads must move together.
    for entry in entries.values():
        if entry.name.endswith(('.import', '.remap')):
            for path in re.findall(rb'"res://([^"\r\n]+)"', entry.data):
                if path.decode() in assigned:
                    assigned[path.decode()] = assigned[entry.name]
    groups = defaultdict(list)
    for name, group in assigned.items():
        groups[group].append(entries[name])
    cloud = out / 'content'
    cloud.mkdir(exist_ok=False)
    manifest = {'schema': 1, 'mode': 'remote', 'source': source, 'baseUrl': base_url,
                'development': development, 'groups': {'prologue': []}}
    report = {}
    for group, members in sorted(groups.items()):
        if group == 'main':
            continue
        batch, size, batches = [], 0, []
        for entry in sorted(members, key=lambda e: e.name):
            cost = len(entry.data) + len(entry.name.encode()) + 64
            if batch and size + cost > CLOUD_CHUNK:
                batches.append(batch)
                batch, size = [], 0
            batch.append(entry)
            size += cost
        if batch:
            batches.append(batch)
        manifest['groups'][group] = []
        for index, batch in enumerate(batches):
            temp = cloud / f'{group}-{index}.pck'
            write_pack(temp, header, batch)
            digest = sha256(temp.read_bytes()).hexdigest()
            path = temp.with_name(f'{group}-{digest[:20]}.pck')
            temp.rename(path)
            manifest['groups'][group].append({'file': path.name, 'bytes': path.stat().st_size, 'sha256': digest})
        report[group] = sum(p['bytes'] for p in manifest['groups'][group])
    payload = json.dumps(manifest, ensure_ascii=False).encode()
    main = [e for e in groups['main'] if e.name != 'hongyuan/content_manifest.json']
    main.append(Entry('hongyuan/content_manifest.json', payload, md5(payload).digest()))
    write_pack(pack, header, main)
    report['startup_pck'] = pack.stat().st_size
    report['startup_wasm'] = (out / 'index.wasm').stat().st_size
    html = out / 'index.html'
    text = html.read_text()
    text, count = re.subn(r'("index\.pck"\s*:\s*)\d+', lambda m: m[1] + str(pack.stat().st_size), text)
    if count != 1:
        raise RuntimeError('Generated HTML PCK size field changed; do not ship this export')
    html.write_text(text)
    (out / 'content-manifest.json').write_bytes(payload)
    (out / 'content-sizes.json').write_text(json.dumps(report, indent=2) + '\n')
    return report

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('output', type=Path)
    parser.add_argument('--base-url', required=True)
    parser.add_argument('--source', required=True)
    parser.add_argument('--development', action='store_true')
    args = parser.parse_args()
    print(json.dumps(split_web(args.output, Path(__file__).resolve().parents[2], args.source,
                               args.base_url, args.development), indent=2))
