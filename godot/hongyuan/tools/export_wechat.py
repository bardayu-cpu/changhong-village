"""Build an isolated WeChat release and its separately staged cloud resources."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
from export_project import love_project
from split_wechat_pack import measure, split

parser = argparse.ArgumentParser()
parser.add_argument("output", type=Path)
parser.add_argument("--cloud-output", type=Path, required=True, help="New directory outside the WeChat project")
parser.add_argument("--cloud-prefix", required=True, help="cloud://<environment>.<bucket>/<deployment folder>/")
parser.add_argument("--godot", default="/Applications/Godot.app/Contents/MacOS/Godot")
args = parser.parse_args()
prefix = args.cloud_prefix.rstrip("/") + "/"
match = re.fullmatch(r"cloud://([\w-]+)\.[\w.-]+/(?:[\w.-]+/)+", prefix)
if not match or any(part in {".", ".."} for part in prefix.split("/")):
    parser.error("Provide a cloud File ID prefix with a deployment folder.")
root = Path(__file__).resolve().parents[2]
out = args.output.resolve()
cloud = args.cloud_output.resolve()
if out.exists() or cloud.exists() or cloud.is_relative_to(out) or out.is_relative_to(cloud):
    parser.error("Output and cloud output must be distinct new directories.")
out.mkdir(parents=True)
env = dict(os.environ, TOOLKIT_RELEASE_PROVIDER="github", TOOLKIT_RELEASE_OWNER="godothub",
           TOOLKIT_RELEASE_REPO="godot-minigame", TOOLKIT_RELEASE_TAG="4.7")
source = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip()
preset = root / "export_presets.cfg"
original = preset.read_bytes()
try:
    subprocess.run(["python3", str(Path(__file__).with_name("sync_export_files.py"))], check=True)
    with love_project(root, wechat=True), tempfile.TemporaryDirectory(prefix="hongyuan-export-") as temp:
        command = [args.godot, "--headless", "--path", str(root)]
        subprocess.run(command + ["--log-file", str(Path(temp) / "import.log"), "--editor", "--import"],
                       env=env, check=True)
        export_log = Path(temp) / "export.log"
        subprocess.run(command + ["--log-file", str(export_log), "--export-release", "红缘微信",
                                  str(out / "hongyuan.bin")], env=env, check=True)
        if re.search(r"Can't open file from path|Parse Error:", export_log.read_text()):
            raise RuntimeError("Godot export reported missing or invalid resources.")
finally:
    preset.write_bytes(original)
manifest = split(out, cloud, source)
manifest.update(environment=match[1], prefix=prefix)
(cloud / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
(out / "hongyuan-content-config.js").write_text(
    "GameGlobal.hongyuanContentConfig = " + json.dumps(manifest, ensure_ascii=False) + ";\n"
)
(out / "hongyuan-content.js").write_bytes(Path(__file__).with_name("wechat_content.js").read_bytes())
engine = out / "engine/game.js"
text = engine.read_text()
old = "const pack = '/engine/empty-tips.bin';"
if text.count(old) != 1:
    raise SystemExit("Template pack entry changed; review engine/game.js before shipping.")
engine.write_text(text.replace(old, "const pack = '/love.bin';"))
(out / "engine/empty-tips.bin").unlink(missing_ok=True)
game = out / "game.js"
game.write_text("import './hongyuan-content'\n" + game.read_text())
for name in ("game.json", "project.config.json", "project.private.config.json"):
    path = out / name
    if not path.exists():
        continue
    config = json.loads(path.read_text())
    if name == "game.json":
        config["subpackages"] = [{"name": group, "root": group + "/"} for group in ("engine", *manifest["local"])]
    else:
        config["projectname"] = "hongyuan-love"
    if name == "project.config.json":
        configured_id = re.search(r'"微信小游戏/游戏_AppID"="(wx[0-9a-f]{16})"', original.decode())
        if not configured_id or config.get("appid") != configured_id[1]:
            raise SystemExit("Exported AppID does not match the Hongyuan preset.")
    path.write_text(json.dumps(config, ensure_ascii=False, indent=2) + "\n")
print("Package sizes (bytes):", json.dumps(measure(out)))
print("Upload the .bin objects from", cloud, "to", prefix, "before WeChat preview.")
