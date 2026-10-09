from pathlib import Path
import json, shutil, plistlib, hashlib, stat, subprocess, os

root=Path(__file__).resolve().parents[1]
source=root/'godot'
delivery=root/'交付/完整村庄-1006'
package=delivery/'本地试玩包'
contents=package/'裳泓村.app/Contents'
(contents/'MacOS').mkdir(parents=True,exist_ok=True)
(contents/'Resources').mkdir(exist_ok=True)
files=[]
for f in sorted(source.rglob('*')):
    if not f.is_file(): continue
    rel=f.relative_to(source); parts=rel.parts
    if parts[0] in ['.git','tools','docs','回执','运行数据','wxgame','tests']:continue
    if parts[0]=='.godot' and parts[1] not in ['imported','global_script_class_cache.cfg','uid_cache.bin']:continue
    if any(part in ['evidence','tests','tools','__pycache__'] for part in parts):continue
    if f.suffix in ['.md','.log','.py','.sh','.command']:continue
    if rel.as_posix() in ['export_presets.cfg','override.cfg']:continue
    if 'core' in parts and (f.name.startswith(('test_','check_','graphical_driver','runtime_info','path_probe','pack_local','render_interior_review'))):continue
    files.append({'path':rel.as_posix(),'bytes':f.stat().st_size,'sha256':hashlib.sha256(f.read_bytes()).hexdigest()})
manifest={'files':files,'pck':str(contents/'Resources/裳泓村.pck'),'source_hash':hashlib.sha256(json.dumps(files,sort_keys=True).encode()).hexdigest()}
(delivery/'本地打包清单.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
engine=Path('/Applications/Godot.app/Contents/MacOS/Godot')
shutil.copy2(engine,contents/'Resources/Godot')
launch=contents/'MacOS/裳泓村'
temporary=root/'测试数据/打包临时';temporary.mkdir(parents=True,exist_ok=True)
compile_env=os.environ.copy();compile_env['TMPDIR']=str(temporary);compile_env['CLANG_MODULE_CACHE_PATH']=str(temporary/'modules')
subprocess.run(['clang','-arch','arm64','-arch','x86_64','-Os',str(root/'工具/mac_launcher.c'),'-o',str(launch)],env=compile_env,check=True)
subprocess.run(['codesign','--force','--sign','-','--timestamp=none',str(contents/'Resources/Godot')],check=True)
info={'CFBundleExecutable':'裳泓村','CFBundleIdentifier':'org.suqitown.village1006','CFBundleName':'裳泓村','CFBundleDisplayName':'裳泓村','CFBundlePackageType':'APPL','CFBundleShortVersionString':'1.0.0','CFBundleVersion':'1006.1007','NSHighResolutionCapable':True}
with (contents/'Info.plist').open('wb') as f:plistlib.dump(info,f)
(package/'试玩说明.txt').write_text('裳泓村 · 本地试玩\n\n双击“裳泓村.app”进入。全部游戏资源已放在本地，首次游玩无需下载。\n点击地面走动，点击提示做事；也可用方向键/WASD行走、E互动。底部“村庄地图”可点房屋沿路走去。\n日常里照料动物、种收、做饭和接订单；帮过三张订单后，去找村长林伯申请自己的小院。动物每趟真实5分钟，离开也最多带回一趟。成熟的菜和成品会等你回来。\n关闭窗口会保存，生活存档放在这个试玩包旁的“运行数据”里。移动试玩包时一起保留它。\n这是内置引擎的 Mac 本地应用，无需另外安装 Godot。使用本机临时签名，未做开发者证书签名或公证；未上传、未发布，其他电脑及手机真机尚未验证。\n')
print(json.dumps({'files':len(files),'resource_bytes':sum(x['bytes'] for x in files),'pck':manifest['pck'],'source_hash':manifest['source_hash']},ensure_ascii=False))
