#!/usr/bin/env python3
"""Validate and copy the approved C4 masks/shader without changing source art."""
import hashlib
import json
from pathlib import Path
import shutil
import struct

ROOT = Path(__file__).resolve().parents[1]
GODOT = ROOT / "godot"
SOURCE = ROOT / "回执/第1轮/设计/春季补强/v1"
CONTRACT = SOURCE / "C2春季接入-v1.json"
TARGET = GODOT / "ayu_home/v4/assets/village/c4-spring-v1"
REPORT = ROOT / "回执/第1轮/C2-C4春季v1导入核对.json"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def encode(data):
    return (json.dumps(data, ensure_ascii=False, indent=2) + "\n").encode()


def png_size(path):
    data = path.read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", path
    return list(struct.unpack(">II", data[16:24]))


def resource(path):
    assert path.startswith("res://"), path
    result = (GODOT / path[6:]).resolve()
    assert result.is_relative_to(GODOT), path
    return result


def main():
    contract = json.loads(CONTRACT.read_text())
    scene_path = GODOT / "ayu_home/v4/assets/village.json"
    assert sha(scene_path) == contract["source_scene_sha256"], "Village baseline changed"
    scene = json.loads(scene_path.read_text())
    canonical = lambda path: path if path.startswith("res://") else scene["asset_root"] + path
    textures, props, copies, original = {}, {}, [], {}
    shader = Path(contract["shader_source"]).resolve()
    assert shader.is_relative_to(SOURCE) and sha(shader) == contract["shader_sha256"]
    copies.append((shader, resource(contract["shader_target"]), contract["shader_sha256"]))
    for binding in contract["texture_bindings"]:
        name = canonical(binding["source_texture"])
        source = resource(name)
        mask = Path(binding["mask_file"]).resolve()
        assert mask.is_relative_to(SOURCE)
        assert name not in textures
        assert sha(source) == binding["source_sha256"] and png_size(source) == binding["source_size"], name
        assert sha(mask) == binding["sha256"] and png_size(mask) == binding["mask_size"], mask
        textures[name] = {"mask": binding["mask_target"], "spring_layer_kind": binding["spring_layer_kind"]}
        copies.append((mask, resource(binding["mask_target"]), binding["sha256"]))
        original[name] = sha(source)
    scene_props = {p["id"]: p for p in scene["props"]}
    for binding in contract["prop_bindings"]:
        name = canonical(binding["source_texture"])
        prop = scene_props[binding["id"]]
        assert binding["id"] not in props and "atlas_region" not in prop
        assert canonical(prop["file"]) == name and name in textures
        assert binding["plant_kind"] == {"fruit": 3, "deciduous": 1, "evergreen": 2}.get(prop.get("plant_type"), 0)
        assert binding["spring_layer_kind"] == textures[name]["spring_layer_kind"]
        props[binding["id"]] = {"texture": name, "plant_kind": binding["plant_kind"], "spring_layer_kind": binding["spring_layer_kind"]}
    assert set(props) == set(scene_props) and len(textures) == len(props) == 50
    assert textures[canonical(scene["background"])]["spring_layer_kind"] == 0
    protected = sorted((GODOT / "ayu_home/v4/assets").glob("*.json")) + sorted((GODOT / "ayu_home/v4/assets").glob("*.nav"))
    before = {str(path.relative_to(GODOT)): sha(path) for path in protected}
    for source, target, expected in copies:
        assert target.is_relative_to(TARGET), target
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        assert sha(target) == expected
    manifest = {"version": contract["version"], "textures": textures, "props": props}
    (TARGET / "bindings.json").write_bytes(encode(manifest))
    assert all(sha(resource(name)) == expected for name, expected in original.items())
    assert all(sha(GODOT / path) == expected for path, expected in before.items())
    REPORT.write_bytes(encode({
        "scope": "Exact C4 spring import; runtime checks and C3 acceptance are separate",
        "contract_sha256": sha(CONTRACT), "shader_sha256": sha(resource(contract["shader_target"])),
        "binding_manifest_sha256": sha(TARGET / "bindings.json"),
        "source_scene_sha256": sha(scene_path), "texture_count": len(textures), "prop_count": len(props),
        "original_texture_hashes": original, "protected_room_json_and_nav_hashes": before,
        "all_original_textures_and_room_json_nav_unchanged": True,
        "copies": [{"file": str(t.relative_to(GODOT)), "sha256": h} for _, t, h in copies],
        "pending": "Headless resource/parameter checks; C3 real-window N3 and performance",
    }))
    print("C4 SPRING IMPORT PASS: 50 exact masks + shader; 50 prop bindings; source textures / room JSON / navigation unchanged")


if __name__ == "__main__":
    main()
