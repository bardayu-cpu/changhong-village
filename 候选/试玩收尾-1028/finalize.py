"""Inspect staged packs, then publish only after the previous QA GUI is released."""
import argparse
import hashlib
import json
import plistlib
import shutil
import subprocess
from pathlib import Path

ENTRY = Path(__file__).resolve().parent
ROOT = ENTRY.parents[1]
QA = ROOT / "测试数据/本轮C2专用目录/1028试玩收尾"
STAGE = QA / "重打-1028.5"
RELEASE = ROOT / "发布/试玩收尾-1028"
GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def file_manifest(folder):
    files = [{"path": p.relative_to(folder).as_posix(), "bytes": p.stat().st_size,
              "sha256": sha(p)} for p in sorted(folder.rglob("*")) if p.is_file()]
    digest = hashlib.sha256(json.dumps(files, ensure_ascii=False, sort_keys=True,
                                     separators=(",", ":")).encode()).hexdigest()
    return {"manifest_sha256": digest, "bytes": sum(f["bytes"] for f in files), "files": files}


def check():
    source = json.loads((ENTRY / "构建来源.json").read_text())
    apps = {"mac": STAGE / "mac/裳泓村试玩.app", "qa": STAGE / "qa/裳泓村收尾QA1028.app"}
    packs = {"web": STAGE / "web/index.pck"}
    result = {"version": source["version"], "build": source["visible_build"],
              "source_digest": source["source_digest"], "packages": {}, "private_files_in_packs": {}}
    for kind, app in apps.items():
        info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
        assert info["CFBundleVersion"] == "1028.5"
        subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True)
        packs[kind] = next((app / "Contents/Resources").glob("*.pck"))
    for kind, pack in packs.items():
        report = QA / ("验收/包配置-" + kind + "-1028.5.json")
        log = QA / ("日志/包配置-" + kind + "-1028.5.log")
        command = [GODOT, "--headless", "--main-pack", str(pack), "--log-file", str(QA / ("日志/包引擎-" + kind + "-1028.5.log")), "--script", str(ENTRY / "inspect_pack.gd"), "--", "--report=" + str(report)]
        if kind == "qa":command.append("--qa")
        with log.open("w") as output:
            completed = subprocess.run(command, stdout=output, stderr=subprocess.STDOUT, timeout=90)
        assert completed.returncode == 0, (kind, log)
        data = json.loads(report.read_text())
        assert not data["possible_gameplay_saves_in_pack"] and data["build"] == source["visible_build"]
        result["private_files_in_packs"][kind] = []
        result["packages"][kind] = file_manifest(apps[kind] if kind in apps else STAGE / "web")
        result["packages"][kind]["full_index_report_sha256"] = sha(report)
        result["packages"][kind]["indexed_resource_count"] = data["resources"]
    (QA / "构建/1028.5包核验.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print("Verified staged 1028.5: all three pack indexes contain zero old/QA saves or prefs")
    return result


def publish(result):
    pairs = [(STAGE / "mac/裳泓村试玩.app", RELEASE / "Mac/裳泓村试玩.app"),
             (STAGE / "web", RELEASE / "Web"),
             (STAGE / "qa/裳泓村收尾QA1028.app", QA / "构建/裳泓村收尾QA1028.app")]
    old_outputs = []
    for index, (source, target) in enumerate(pairs):
        assert source.resolve().is_relative_to(STAGE.resolve()) and not target.is_symlink()
        assert target.parent.resolve().is_relative_to(ROOT.resolve())
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.exists():
            old = QA / ("本轮废弃生成输出-" + str(index))
            assert not old.exists()
            target.rename(old);old_outputs.append(old)
        source.rename(target)
    for old in old_outputs:
        # These are only the output artifacts renamed above, never a save folder.
        assert old.parent == QA and old.name.startswith("本轮废弃生成输出-")
        shutil.rmtree(old)
    (RELEASE / "构建清单.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    marker = RELEASE / ".verified-1028.5"
    marker.write_text(result["build"] + "\n")
    result["old_generated_outputs_replaced_and_removed"] = True
    (QA / "构建/1028.5包核验.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print("Published verified 1028.5; stable entry paths now ready")


if __name__ == "__main__":
    parser = argparse.ArgumentParser();parser.add_argument("--publish-after-GUI-release", action="store_true")
    args = parser.parse_args();result = check()
    if args.publish_after_GUI_release:publish(result)
