"""Partition a Godot 4.7 export without changing imported resources or remaps."""
from collections import defaultdict
from dataclasses import dataclass
from hashlib import sha256
import json
from pathlib import Path
import re
import shutil
import struct

CHAPTERS = ("prologue", "shanghai", "chengdu", "call", "shizuoka", "hainan", "hongkong", "finale")
MEDIA = {".png", ".jpg", ".jpeg", ".webp", ".svg", ".wav", ".ogg", ".mp3", ".ctex", ".sample", ".oggvorbisstr"}
MAIN_LIMIT = 4_000_000
# Leave margin for accounts with the lower 20 MB total limit.
TOTAL_LIMIT = 20_000_000
CLOUD_CHUNK = 16_000_000


@dataclass(frozen=True)
class Entry:
    name: str
    data: bytes
    digest: bytes


def read_pack(path):
    data = path.read_bytes()
    if len(data) < 104 or struct.unpack_from("<4s5I", data)[:2] != (b"GDPC", 4):
        raise ValueError("Expected a standalone Godot 4.7 PCK v4")
    flags, base, directory = struct.unpack_from("<IQQ", data, 20)
    if flags != 2 or not 104 <= base <= directory <= len(data) - 4:
        raise ValueError("Unsupported PCK flags or directory")
    count, = struct.unpack_from("<I", data, directory)
    pos = directory + 4
    entries = {}
    for _ in range(count):
        size, = struct.unpack_from("<I", data, pos)
        pos += 4
        name = data[pos:pos + size].rstrip(b"\0").decode()
        pos += size
        offset, length, digest, file_flags = struct.unpack_from("<QQ16sI", data, pos)
        pos += 36
        if name in entries or file_flags or base + offset + length > directory:
            raise ValueError(f"Unsupported PCK entry: {name}")
        entries[name] = Entry(name, data[base + offset:base + offset + length], digest)
    return data[:20], entries


def write_pack(path, header, entries):
    with path.open("wb") as out:
        base = 112
        out.write(header + struct.pack("<IQQ", 2, base, 0) + bytes(base - 40))
        directory = bytearray(struct.pack("<I", len(entries)))
        offsets = {}
        for entry in sorted(entries, key=lambda e: e.name):
            name = entry.name.encode()
            name += bytes(-len(name) % 4)
            directory.extend(struct.pack("<I", len(name)) + name)
            # Identical imports (e.g. multiple seasonal aliases) can share bytes.
            key = sha256(entry.data).digest()
            if key not in offsets:
                offsets[key] = out.tell() - base
                out.write(entry.data)
                out.write(bytes(-out.tell() % 16))
            directory.extend(struct.pack("<QQ16sI", offsets[key], len(entry.data), entry.digest, 0))
        offset = out.tell()
        out.write(directory)
        out.seek(32)
        out.write(struct.pack("<Q", offset))


def owner(path, byte_count):
    source = path.removesuffix(".import").removesuffix(".remap")
    media = Path(source).suffix.lower() in MEDIA
    round1_owners = {
        'shanghai_drive.png':'shanghai', 'shanghai_parking.png':'shanghai',
        'panda_garden.png':'chengdu', 'group_chengdu.png':'chengdu',
        'group_shoulder.png':'shanghai', 'call_split.png':'call', 'daily_walk.png':'call',
        'offer_room.png':'hongkong', 'hk_street.png':'hongkong', 'university.png':'hongkong',
        'disney_toys.png':'hongkong', 'disney_garden.png':'hongkong',
        'registry.png':'shizuoka', 'harbor.png':'shizuoka', 'harbour_boat.png':'shizuoka',
        'cabin.png':'shizuoka', 'turtle_boarding.png':'shizuoka', 'wanning_beach.png':'hainan',
    }
    if source.startswith(('hongyuan/assets/round1/scenes/', 'hongyuan/assets/round1/people/')):
        return round1_owners.get(Path(source).name, 'love-media')
    if source.startswith("hongyuan/assets/round1/finale/"):
        return "finale"
    if source.startswith("hongyuan/assets/round1/common/") and Path(source).name in {"welcome.png", "welcome_bg.png", "envelope_open.png", "envelope_sealed.png", "wax_sealed.png"}:
        return "finale"
    if source.startswith("hongyuan/assets/round1/desk_r4/") or source.startswith("hongyuan/assets/w2/finale/slot_"):
        return "main"
    if Path(source).name in {"bg_invite_desk.png", "invite_card.png", "invite_base.png", "invite_pen_stroke.png", "invite_slot_pen.png", "invite_slot_ink.png", "pen_tip.png"}:
        return "main"
    if source.startswith("hongyuan/assets/bgm/"):
        chapter = Path(source).stem.removeprefix("bgm_")
        return "main" if chapter == "prologue" else chapter if chapter in CHAPTERS else "love-media"
    if source.startswith("assets/characters/lm/chr_LM-GUEST-"):
        return "love-media"
    chapter = re.match(r"hongyuan/assets/w2/([^/]+)/", source)
    if media and chapter and chapter[1] in CHAPTERS:
        return chapter[1]
    if media and source.startswith("hongyuan/assets/"):
        # Shared character art and runtime fallback paths can be used across chapters.
        return "love-media"
    if source in ("hongyuan/wedding.gd",):
        return "estate"
    if source.startswith("ayu_home/"):
        return "village-media" if media or byte_count >= 250_000 else "village"
    if source.startswith(("assets/", "scripts/", "shaders/", "data/")):
        if source.startswith("assets/fonts/"):
            return "main"
        return "world-media" if media else "world"
    return "main"


def partition(entries):
    assigned = {name: owner(name, len(entry.data)) for name, entry in entries.items()}
    remapped = defaultdict(set)
    for entry in entries.values():
        if not entry.name.endswith((".remap", ".import")):
            continue
        for target in re.findall(rb'"res://([^"\r\n]+)"', entry.data):
            path = target.decode()
            if path in entries:
                remapped[path].add(assigned[entry.name])
    for target, groups in remapped.items():
        if len(groups) != 1:
            raise ValueError(f"Shared remap crosses package boundaries: {target}: {groups}")
        assigned[target] = groups.pop()
    groups = defaultdict(list)
    for name, group in assigned.items():
        groups[group].append(entries[name])
    return groups


def split(out, cloud, source_sha):
    pack = out / "engine/demo-pck.bin"
    header, entries = read_pack(pack)
    groups = partition(entries)
    cloud.mkdir(parents=True, exist_ok=False)
    local = {}
    remote = {}
    manifest = {"source": source_sha, "local": local, "remote": remote}
    write_pack(out / "love.bin", header, groups.pop("main"))
    pack.unlink()
    for group in ("world", "estate", "village"):
        folder = out / group
        folder.mkdir()
        (folder / "game.js").write_text("// Loaded by the Godot resource bridge.\n")
        dest = folder / "content.bin"
        write_pack(dest, header, groups.pop(group))
        local[group] = {"path": f"{group}/content.bin", "bytes": dest.stat().st_size}
    for group, members in sorted(groups.items()):
        batch = []
        size = 0
        batches = []
        for entry in sorted(members, key=lambda e: e.name):
            cost = len(entry.data) + len(entry.name.encode()) + 64
            if batch and size + cost > CLOUD_CHUNK:
                batches.append(batch)
                batch, size = [], 0
            batch.append(entry)
            size += cost
        if batch:
            batches.append(batch)
        remote[group] = []
        for i, batch in enumerate(batches, 1):
            dest = cloud / f"{group}-{i:02}.bin"
            write_pack(dest, header, batch)
            digest = sha256(dest.read_bytes()).hexdigest()
            target = dest.with_name(f"{dest.stem}-{digest[:16]}.bin")
            dest.rename(target)
            remote[group].append({"file": target.name, "bytes": target.stat().st_size, "sha256": digest})
    for name in ("subpackages", "subpacks"):
        if (out / name).exists():
            shutil.rmtree(out / name)
    for path in out.rglob("*"):
        if path.is_file() and (path.suffix in {".md", ".import"} or path.name.startswith(".")):
            path.unlink()
    (cloud / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    return manifest


def measure(out):
    config = json.loads((out / "game.json").read_text())
    names = {entry["root"].strip("/") for entry in config["subpackages"]}
    sizes = {"main": 0, **dict.fromkeys(sorted(names), 0)}
    for path in out.rglob("*"):
        if not path.is_file():
            continue
        parts = path.relative_to(out).parts
        group = parts[0] if len(parts) > 1 and parts[0] in names else "main"
        sizes[group] += path.stat().st_size
    total = sum(sizes.values())
    if sizes["main"] >= MAIN_LIMIT or total >= TOTAL_LIMIT:
        raise ValueError(f"WeChat size budget exceeded: {sizes}, total={total}")
    return {**sizes, "total": total}
