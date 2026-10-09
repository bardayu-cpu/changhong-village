extends SceneTree
const Loader=preload("res://ayu_home/v4/cloud_assets.gd")
const Assets=preload("res://ayu_home/v2/assets.gd")
class FakeCloud extends Node:
	var folder:=ProjectSettings.globalize_path("res://../素材来源/下载器测试输入")
	var prefix:="";var calls:Dictionary={};var bad:="";var corrupt_once:=""
	func call_fn(_name:String,data:Dictionary,cb:Callable,_t:=0.0) -> void:
		var file:=str(data.fileID).trim_prefix(prefix);calls[file]=int(calls.get(file,0))+1
		await get_tree().process_frame
		if file==bad:cb.call({"ok":false,"reason":"download_failed"});return
		var bytes:=FileAccess.get_file_as_bytes(folder.path_join(file))
		if file==corrupt_once:bytes[100]^=0xff;corrupt_once=""
		var f:=FileAccess.open(data.path,FileAccess.WRITE);f.store_buffer(bytes);f.close();cb.call({"ok":true})
var failures:Array=[]
func check(ok:bool,what:String) -> void:
	print("CHECK ",ok," ",what)
	if not ok:failures.append(what)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var cloud:=FakeCloud.new();root.add_child(cloud)
	var loader:=Loader.new();loader.cache_root=ProjectSettings.globalize_path("res://../测试数据/下载器缓存");root.add_child(loader)
	DirAccess.make_dir_recursive_absolute(loader.cache_root)
	for file in DirAccess.get_files_at(loader.cache_root):DirAccess.remove_absolute(loader.cache_root.path_join(file))
	loader.setup(cloud,false);cloud.prefix=loader.man.prefix
	var r:Dictionary=await loader.wait_group("boot")
	check(r.ok and loader.ready_files.size()==47 and cloud.calls.size()==47,"首次只下载47个启动文件，非166个")
	loader.start_background();loader.want("room:living");loader.want("room:living")
	r=await loader.wait_group("room:living");check(r.ok,"过门优先准备房间")
	r=await loader.wait_group("game:garden");check(r.ok,"小游戏按组准备")
	r=await loader.wait_group("all");check(r.ok,"后台全部下载完成")
	var duplicates:=0
	for n in cloud.calls.values():if int(n)!=1:duplicates+=1
	check(duplicates==0,"并发时不重复下载同一文件")
	var images:=0
	for source in loader.man.files:
		if source.ends_with(".png"):
			Assets.textures.erase(source)
			if Assets.texture(source)!=null:images+=1
	check(images==162,"162张下载图实际解码成功")
	cloud.calls.clear();loader.setup(cloud,false);r=await loader.wait_group("boot")
	check(r.ok and cloud.calls.is_empty(),"有缓存重开零下载")
	var victim:String=loader.man.groups["room:living"][0];var entry:Dictionary=loader.man.files[victim]
	FileAccess.open(loader.cloud_cache(entry),FileAccess.WRITE).store_string("corrupt")
	cloud.corrupt_once=entry.name;loader.setup(cloud,false);r=await loader.wait_group("room:living")
	check(r.ok and cloud.calls.get(entry.name,0)==2,"坏缓存重下，传输损坏自动再试")
	DirAccess.remove_absolute(loader.cloud_cache(entry));cloud.bad=entry.name;loader.setup(cloud,false)
	r=await loader.wait_group("room:living");check(not r.ok,"下载失败可返回，不死等")
	cloud.bad="";r=await loader.wait_group("room:living");check(r.ok,"同组重试可恢复，不丢已缓存文件")
	loader.setup(cloud,false);check(loader.is_ready("all"),"重新建立下载器后缓存仍完整")
	r=await loader.wait_group("absent");check(not r.ok,"缺组不能冒称准备完毕")
	print("RESULT ","PASS" if failures.is_empty() else "FAIL"," ",failures)
	loader.queue_free();cloud.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
