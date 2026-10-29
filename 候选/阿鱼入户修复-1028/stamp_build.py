"""Bind the isolated application label to exact overlay and export inputs."""
import hashlib
import json
import re
import shutil
import subprocess
from pathlib import Path

ENTRY = Path(__file__).resolve().parent
ROOT = ENTRY.parents[1]
OVERLAY = ROOT / "候选/整村95-G0-1026/overlay"
QA = ROOT / "测试数据/本轮C2专用目录/1028阿鱼入户修复"


def sha(data):
    return hashlib.sha256(data).hexdigest()


files = {p.relative_to(OVERLAY).as_posix(): sha(p.read_bytes())
         for p in sorted(OVERLAY.rglob("*")) if p.is_file()}
project = (ENTRY / "project.godot").read_text()
normalized = re.sub(r'config/candidate_build_id="[^"]*"',
                    'config/candidate_build_id="BUILD_DIGEST"', project)
preset = (ENTRY / "export_presets.cfg").read_bytes()
template = Path.home() / "Library/Application Support/Godot/export_templates/4.7.2.stable/macos.zip"
inputs = {"overlay": files, "normalized_project_sha256": sha(normalized.encode()),
          "export_preset_sha256": sha(preset), "template_sha256": sha(template.read_bytes())}
digest = sha(json.dumps(inputs, sort_keys=True).encode())
base = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
label = base[:8] + "+" + digest[:8] + " 阿鱼入户候选未验"
project = re.sub(r'config/candidate_build_id="[^"]*"',
                 'config/candidate_build_id="' + label + '"', project)
(ENTRY / "project.godot").write_text(project)
for name in ["project.godot", "export_presets.cfg"]:
    shutil.copy2(ENTRY / name, QA / "工程" / name)
manifest = {"visible_build": label, "source_base_commit": base,
            "source_basis": "base commit plus exact candidate overlay hashes; candidate changes pending precise commit at build time",
            "input_digest": digest, "build_inputs": inputs,
            "bundle_id": "com.bardayu.changhong.ayu1028", "app_version": "0.1.1/1028.3",
            "candidate_app": str(QA / "构建/裳泓村阿鱼入户1028.app"),
            "life_core_root": str(QA / "运行数据"),
            "os_userdata": str(Path.home() / "Library/Application Support/裳泓村阿鱼入户1028-测试数据"),
            "old_frozen_app_replaced": False, "G0_pass": False, "village95_pass": False}
for path in [ENTRY / "构建来源.json", QA / "构建/source-manifest.json"]:
    path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
print("Stamped", label, "overlay files", len(files))
