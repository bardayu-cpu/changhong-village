extends SceneTree
## 手机预览接云（村C2 10/5）：电脑上用假云（从「上传云存储/ayu_home」那个文件夹拷）跑真的下载流程：
## 照 cloud_manifest.json 一个个要 → 验字节和 sha256 → 存进缓存 → 登记 Assets.resolved_paths；
## 然后每张图都用 Assets.texture(原来的 res:// 路径) 读下载好的 WebP，大小跟原 PNG 一样。
## 再测：第二次一个都不下；坏了一个会重下；云上没有的回失败、不卡住
const CloudAssets=preload("res://ayu_home/v4/cloud_assets.gd")
const Assets=preload("res://ayu_home/v2/assets.gd")
class FakeCloud extends Node:
	var folder:="";var prefix:="";var calls:=0;var corrupt_once:="";var missing:=""
	func call_fn(name:String,data:Dictionary,cb:Callable,_t:=0.0) -> void:
		calls+=1
		var file:=str(data.fileID).trim_prefix(prefix)
		if file==missing:cb.call({"ok":false,"reason":"download_failed","detail":"假云上没有"});return
		var bytes:=FileAccess.get_file_as_bytes(folder.path_join(file))
		if file==corrupt_once:bytes[100]^=0xff;corrupt_once=""
		var f:=FileAccess.open(str(data.path),FileAccess.WRITE);f.store_buffer(bytes);f.close()
		cb.call({"ok":true,"bytes":bytes.size()})
var bad:Array=[]
func check(ok:bool,what:String) -> void:
	print(("过 " if ok else "不行 ")+what)
	if not ok:bad.append(what)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var man:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://ayu_home/v4/cloud_manifest.json"))
	var cloud:=FakeCloud.new();cloud.folder=ProjectSettings.globalize_path("res://").path_join("../上传云存储/ayu_home");cloud.prefix=man.prefix;root.add_child(cloud)
	var loader:=CloudAssets.new();loader.cache_root=OS.get_user_data_dir().path_join("phone-cloud-test");root.add_child(loader)
	DirAccess.make_dir_recursive_absolute(loader.cache_root)
	for f in DirAccess.get_files_at(loader.cache_root):DirAccess.remove_absolute(loader.cache_root.path_join(f))
	var steps:=[0];var r:Dictionary=await loader.ensure_cloud(cloud,func(i,n):steps[0]=i,false)
	check(r.ok and r.downloaded==man.files.size(),"第一次全下：%s，云函数来回 %d 次"%[str(r),cloud.calls])
	check(steps[0]==man.files.size(),"进度走到 %d / %d"%[steps[0],man.files.size()])
	# 手机上改名不落盘（C3 10/5）：下完缓存里要是 166 个正式名字、一个 .part 都不剩
	var names:=DirAccess.get_files_at(loader.cache_root);var parts:=0
	for x in names:if x.ends_with(".part"):parts+=1
	check(names.size()==man.files.size() and parts==0,"缓存里 %d 个正式文件、.part 剩 %d 个"%[names.size()-parts,parts])
	var shown:=0
	for source in man.files:
		if str(source).ends_with(".png"):
			Assets.textures.erase(source)
			var t:Texture2D=Assets.texture(source);var im:=Image.load_from_file(ProjectSettings.globalize_path(source))
			if t==null or t.get_size()!=Vector2(im.get_size()):bad.append("读不出或大小不对 "+source)
			else:shown+=1
		else:
			Assets.sounds.erase(source);if Assets.sound(source)==null:bad.append("声音读不出 "+source)
	check(shown==man.files.size()-4,"%d 张图都从下载好的 WebP 读出来、大小跟原图一样"%shown)
	# 抽一张逐像素比：无损
	var one:="res://ayu_home/v2/assets/chr_mother.png";var a:=Image.load_from_file(ProjectSettings.globalize_path(one));var b:=Assets.texture(one).get_image();b.convert(a.get_format())
	check(a.get_data()==b.get_data(),"新妈妈图集下载后逐像素一样")
	cloud.calls=0;r=await loader.ensure_cloud(cloud,Callable(),false)
	check(r.ok and r.downloaded==0 and cloud.calls==0,"第二次一个都不下（读手机里的）")
	var victim:String=man.files.values()[5].name;var entry:Dictionary=man.files.values()[5]
	var f:=FileAccess.open(loader.cache_root.path_join(str(entry.sha256)+"."+victim.get_extension()),FileAccess.READ_WRITE);f.seek(50);f.store_8(7);f.close()
	cloud.corrupt_once=victim;cloud.calls=0;r=await loader.ensure_cloud(cloud,Callable(),false)
	check(r.ok and r.downloaded==1 and cloud.calls==2,"缓存坏了一个：重下，第一次下坏了再要一次（来回 %d 次）"%cloud.calls)
	cloud.missing=man.files.values()[9].name;DirAccess.remove_absolute(loader.cache_root.path_join(str(man.files.values()[9].sha256)+"."+cloud.missing.get_extension()))
	r=await loader.ensure_cloud(cloud,Callable(),false)
	check(not r.ok and r.reason=="download_failed","云上没有：回失败（%s）、不卡住"%str(r.reason))
	for x in DirAccess.get_files_at(loader.cache_root):DirAccess.remove_absolute(loader.cache_root.path_join(x))
	print("RESULT PASS" if bad.is_empty() else "RESULT FAIL "+str(bad.slice(0,5)))
	quit()
