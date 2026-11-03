#!/usr/bin/env python3
"""Build a local-only .app from one committed revision, never the dirty checkout."""
import argparse, hashlib, json, os, pathlib, plistlib, shutil, subprocess, tarfile, tempfile
p=argparse.ArgumentParser();p.add_argument('--commit',required=True);p.add_argument('--output',required=True);p.add_argument('--godot',default='/Applications/Godot.app/Contents/MacOS/Godot');a=p.parse_args()
repo=pathlib.Path(__file__).resolve().parents[4]
sha=subprocess.check_output(['git','rev-parse',a.commit+'^{commit}'],cwd=repo,text=True).strip()
out=pathlib.Path(a.output).resolve();out.mkdir(parents=True,exist_ok=True)
work=out/('build-'+sha[:8]);work.mkdir(exist_ok=False)
archive=work/'source.tar'
with archive.open('wb') as stream:subprocess.run(['git','archive',sha,'godot'],cwd=repo,stdout=stream,check=True)
with tarfile.open(archive) as source:source.extractall(work)
project=work/'godot';config=project/'project.godot'
text='\n'.join(line for line in config.read_text().splitlines() if not line.startswith(('config/use_custom_user_dir=','config/custom_user_dir_name=')));text=text.replace('config/name="苏七镇奇缘"','config/name="裳泓村试玩1025"\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="ChanghongVillagePlaytest1025"')
# Disable authoring plugins in the isolated export copy, never in the real project.
lines=text.splitlines();clean=[];drop=False
for line in lines:
 if line.startswith('['):drop=line=='[editor_plugins]'
 if not drop:clean.append(line)
config.write_text('\n'.join(clean)+'\n')
subprocess.run([a.godot,'--headless','--path',str(project),'--import','--log-file',str(work/'import.log')],check=True,timeout=600)
app=out/'裳泓村.app';contents=app/'Contents';mac=contents/'MacOS';resources=contents/'Resources';mac.mkdir(parents=True,exist_ok=False);resources.mkdir()
shutil.copy2(a.godot,resources/'Godot')
info={'CFBundleDisplayName':'裳泓村','CFBundleExecutable':'裳泓村','CFBundleIdentifier':'org.suqitown.village.playtest1025','CFBundleName':'裳泓村','CFBundlePackageType':'APPL','CFBundleShortVersionString':'1.0.0','CFBundleVersion':'1025','NSHighResolutionCapable':True}
(contents/'Info.plist').write_bytes(plistlib.dumps(info))
launcher=mac/'裳泓村';launcher.write_text('#!/bin/sh\nAPP_RES="$(CDPATH= cd -- "$(dirname -- "$0")/../Resources" && pwd)"\nexec "$APP_RES/Godot" --main-pack "$APP_RES/裳泓村.pck" "$@"\n');launcher.chmod(0o755)
# Include runtime source and imported resources, exclude editor cache, tests, and old export outputs.
files=[]
for file in project.rglob('*'):
 if not file.is_file():continue
 rel=file.relative_to(project);parts=rel.parts
 if '.git' in parts or 'tests' in parts or 'evidence' in parts or 'tools' in parts:continue
 if '.godot' in parts and len(parts)>1 and parts[1] not in ('imported','global_script_class_cache.cfg','uid_cache.bin'):continue
 if rel.name=='export_presets.cfg' or file.suffix in ('.md','.log','.py','.sh','.pck','.zip'):continue
 files.append(str(rel))
manifest={'commit':sha,'pck':str(resources/'裳泓村.pck'),'files':files};(work/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False))
script=work/'pack.gd';script.write_text('''extends SceneTree
func _initialize() -> void:
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_cmdline_user_args()[0]))
 var pack:=PCKPacker.new()
 if pack.pck_start(manifest.pck)!=OK:quit(1);return
 for file in manifest.files:
  if pack.add_file("res://"+file,"res://"+file)!=OK:quit(2);return
 quit(0 if pack.flush()==OK else 3)
''')
subprocess.run([a.godot,'--headless','--path',str(project),'--log-file',str(work/'pack.log'),'--script',str(script),'--',str(work/'manifest.json')],check=True,timeout=300)
pck=resources/'裳泓村.pck';proof={'commit':sha,'pck_sha256':hashlib.sha256(pck.read_bytes()).hexdigest(),'pck_bytes':pck.stat().st_size,'files':len(files),'save_folder':'~/Library/Application Support/ChanghongVillagePlaytest1025','verification':'尚待C3双击启动及关闭重开验收'}
(out/'交付提交与校验.json').write_text(json.dumps(proof,ensure_ascii=False,indent=2))
print(json.dumps({'app':str(app),**proof},ensure_ascii=False))
