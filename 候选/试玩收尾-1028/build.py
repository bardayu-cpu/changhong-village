"""Same runtime source, three isolated platform profiles; no gameplay save copying."""
import argparse
import hashlib
import json
import re
import shutil
import subprocess
from pathlib import Path

ENTRY = Path(__file__).resolve().parent
ROOT = ENTRY.parents[1]
OVERLAY = ENTRY / "overlay"
QA = ROOT / "测试数据/本轮C2专用目录/1028试玩收尾"
WORK = QA / "工程"
RELEASE = ROOT / "发布/试玩收尾-1028"
GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"


def sha(data):
    return hashlib.sha256(data).hexdigest()


def setting(text, key, value):
    pattern = r"^" + re.escape(key) + r"=.*$"
    line = key + "=" + value
    if re.search(pattern, text, re.M):
        return re.sub(pattern, lambda _: line, text, flags=re.M)
    return text.replace("[application]\n", "[application]\n" + line + "\n", 1)


def prepare():
    if not WORK.exists():
        private_names = {"运行数据", "测试数据", "user", "users", "save", "saves", "saved", "userdata", "user_data", "playtest", "qa", "QA"}
        def omit_private(directory, names):
            blocked = {".git", ".godot"}
            if Path(directory).resolve() == (ROOT / "godot").resolve():
                blocked |= private_names | {"ayu_home_local_player.json", "music.cfg", "prefs.cfg", "preferences.cfg"}
                blocked |= {n for n in names if n.startswith("ayu_home_v4_") and n.endswith(".json")}
            return blocked.intersection(names)
        shutil.copytree(ROOT / "godot", WORK, symlinks=True, ignore=omit_private)
    # Older locally cloned workspaces may contain a legacy data copy. Ignore it,
    # without deleting or parsing any original data file.
    copied_data = WORK / "运行数据"
    if copied_data.is_dir():
        assert not copied_data.is_symlink() and copied_data.resolve().is_relative_to(WORK.resolve())
        (copied_data / ".gdignore").touch()
    for source in OVERLAY.rglob("*"):
        if source.is_file() and source.relative_to(OVERLAY).as_posix() not in ["project.godot", "export_presets.cfg"]:
            target = WORK / source.relative_to(OVERLAY)
            assert target.resolve().is_relative_to(WORK.resolve())
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
    base = (ENTRY / "qa-project.godot").read_text()
    profiles = {}
    for kind in ["mac", "qa", "web"]:
        text = base
        values = {"config/name": '"裳泓村收尾QA1028"' if kind == "qa" else '"裳泓村试玩"',
                  "config/version": '"0.1.2"', "config/playtest_isolated": "true",
                  "config/candidate_enabled": "true" if kind == "qa" else "false",
                  "config/candidate_data_root": json.dumps(str(QA / "运行数据"), ensure_ascii=False) if kind == "qa" else '""',
                  "config/candidate_os_userdata": json.dumps(str(Path.home() / "Library/Application Support/裳泓村收尾QA1028-测试数据"), ensure_ascii=False) if kind == "qa" else '""',
                  "config/custom_user_dir_name": '"裳泓村收尾QA1028-测试数据"' if kind == "qa" else '"裳泓村试玩"',
                  "config/candidate_build_id": '"BUILD_DIGEST"'}
        for key, value in values.items():
            text = setting(text, key, value)
        text = re.sub(r'^file_logging/log_path=.*$', lambda _: 'file_logging/log_path=' + json.dumps(str(QA / "日志/试玩QA.log") if kind == "qa" else "user://playtest.log", ensure_ascii=False), text, flags=re.M)
        profiles[kind] = text
    old = (ROOT / "候选/阿鱼入户修复-1028/export_presets.cfg").read_text()
    mac = old.replace("阿鱼入户候选1028", "收尾Mac").replace("com.bardayu.changhong.ayu1028", "com.bardayu.changhong.playtest").replace('"0.1.1"', '"0.1.2"').replace('"1028.3"', '"1028.5"')
    private = "运行数据/*,*/运行数据/*,测试数据/*,user/*,users/*,save/*,saves/*,saved/*,userdata/*,user_data/*,playtest/*,qa/*,QA/*,test_data/*,tests/*,test/*,*ayu_home_local_player*,*ayu_home_v4_*,prefs.cfg,preferences.cfg,"
    mac = mac.replace('exclude_filter="', 'exclude_filter="' + private, 1)
    qa = mac.replace("preset.0", "preset.1").replace("收尾Mac", "收尾QA").replace("com.bardayu.changhong.playtest", "com.bardayu.changhong.wrapqa1028")
    web = mac.split("[preset.0.options]")[0].replace("preset.0", "preset.2").replace("收尾Mac", "收尾Web").replace('platform="macOS"', 'platform="Web"') + '''[preset.2.options]
variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=false
vram_texture_compression/for_mobile=false
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
html/head_include="<meta name='viewport' content='width=device-width, initial-scale=1, viewport-fit=cover'>"
progressive_web_app/enabled=false
progressive_web_app/ensure_cross_origin_isolation_headers=false
'''
    presets = mac + "\n" + qa + "\n" + web
    files = {p.relative_to(OVERLAY).as_posix(): sha(p.read_bytes()) for p in sorted(OVERLAY.rglob("*")) if p.is_file()}
    digest = sha(json.dumps({"source": files, "profiles": profiles, "presets": presets}, sort_keys=True).encode())
    label = "收尾1028-" + digest[:8] + " · 试玩版"
    for kind, text in profiles.items():
        (ENTRY / ("project-" + kind + ".godot")).write_text(text.replace("BUILD_DIGEST", label))
    (ENTRY / "export_presets.cfg").write_text(presets)
    (WORK / "export_presets.cfg").write_text(presets)
    shutil.copy2(ENTRY / "project-qa.godot", WORK / "project.godot")
    manifest = {"visible_build": label, "version": "0.1.2/1028.5", "source_base_commit": "4d3f1bd01558ad4cec571370776bf412da25681a", "source_digest": digest,
                "runtime_source_files": files, "Mac_Web_same_runtime_source": True,
                "profile_differences": "QA uses explicit isolated test life/core; final Mac uses stable dedicated userdata/playtest; Web uses its browser origin's userfs/playtest. No old save read or migration.",
                "Web_threads": False, "Web_PWA": False, "actual_phone_pass": False, "village95_pass": False}
    (ENTRY / "构建来源.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    return manifest


def promote():
    formal = ROOT / "godot"
    targets = [(source, formal / source.relative_to(OVERLAY)) for source in OVERLAY.rglob("*") if source.is_file() and source.relative_to(OVERLAY).as_posix() not in ["project.godot", "export_presets.cfg"]]
    for _, target in targets:
        assert target.parent.resolve().is_relative_to(formal.resolve()), target
    backup = QA / "工程接入前备份"
    records = []
    frozen = {p.relative_to(formal).as_posix(): sha(p.read_bytes()) for p in (formal / "ayu_home/v4/assets/village").glob("house_*.png")}
    for source, target in targets:
        rel = target.relative_to(formal)
        item = {"path": "godot/" + rel.as_posix(), "old_link": str(target.readlink()) if target.is_symlink() else None}
        if target.exists():
            save = backup / rel;save.parent.mkdir(parents=True, exist_ok=True);save.write_bytes(target.read_bytes())
            item["old_sha256"] = sha(target.read_bytes())
        target.parent.mkdir(parents=True, exist_ok=True)
        temporary = target.with_name(target.name + ".wrap-tmp")
        temporary.write_bytes(source.read_bytes());temporary.replace(target)
        item["new_sha256"] = sha(target.read_bytes());records.append(item)
    assert all(sha((formal / path).read_bytes()) == value for path, value in frozen.items())
    record = {"files": records, "house_PNGs_unchanged": frozen, "old_saves_read_or_changed": False, "formal_project_save_settings_changed": False}
    (ENTRY / "工程接入清单.json").write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")
    print("Promoted", len(records), "source files; original house PNGs/save contract preserved")


def export(kind):
    marker = RELEASE / ".verified-1028.5"
    if marker.exists():
        marker.unlink()
    shutil.copy2(ENTRY / ("project-" + kind + ".godot"), WORK / "project.godot")
    stage = QA / "重打-1028.5"
    options = {"mac": ("收尾Mac", stage / "mac/裳泓村试玩.app"), "qa": ("收尾QA", stage / "qa/裳泓村收尾QA1028.app"), "web": ("收尾Web", stage / "web/index.html")}
    preset, target = options[kind];target.parent.mkdir(parents=True, exist_ok=True)
    log = QA / ("日志/导出-" + kind + ".log")
    with log.open("w") as output:
        result = subprocess.run([GODOT, "--headless", "--path", str(WORK), "--log-file", str(QA / ("日志/引擎-" + kind + ".log")), "--export-debug" if kind == "qa" else "--export-release", preset, str(target)], stdout=output, stderr=subprocess.STDOUT)
    text = log.read_text(errors="replace")
    print("EXPORT", kind, "exit", result.returncode, "target", target)
    errors = [line for line in text.splitlines() if "Parse Error" in line or "Failed to load script" in line or "Export failed" in line]
    if result.returncode or errors:
        print("\n".join(errors[:8]));raise SystemExit(result.returncode or 3)


if __name__ == "__main__":
    parser = argparse.ArgumentParser();parser.add_argument("--promote-approved", action="store_true");parser.add_argument("--export", choices=["mac", "qa", "web"])
    args = parser.parse_args();metadata = prepare()
    if args.promote_approved:promote()
    if args.export:export(args.export)
    print(metadata["visible_build"])
