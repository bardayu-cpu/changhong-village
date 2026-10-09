extends Node
## Optional caller-managed prefetch through the existing authenticated bridge.
## No network call on normal local startup; no embedded online IDs or uploads.
signal fetched(result:Dictionary)
const Assets=preload("res://ayu_home/v2/assets.gd")
const P:="res://ayu_home/v4/assets/"
var cache_root:="user://ayu_home_v4/"
func valid(path:String,entry:Dictionary) -> bool:
	if not FileAccess.file_exists(path):return false
	var f:=FileAccess.open(path,FileAccess.READ)
	if f==null:return false
	var size:=f.get_length();f.close()
	return size==int(entry.bytes) and FileAccess.get_sha256(path)==entry.sha256
func cached(name:String,entry:Dictionary) -> String:
	return cache_root.path_join(str(entry.sha256)+"."+name.get_extension())
func ensure_all(bridge:Node,file_ids:Dictionary,names:Array=[],use_packaged:=true) -> Dictionary:
	var entries:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(P+"manifest.json")).files
	if names.is_empty():names=entries.keys()
	var count:=0
	for name in names:
		if not entries.has(name):return {"ok":false,"reason":"unknown_asset","file":name}
		var entry:Dictionary=entries[name]
		var source:String=P+name;var destination:=cached(name,entry)
		if use_packaged and not FileAccess.file_exists(source) and ResourceLoader.exists(source):
			Assets.resolved_paths[source]=source;continue
		if use_packaged and valid(source,entry):
			Assets.resolved_paths[source]=source;continue
		if not valid(destination,entry):
			if bridge==null or str(file_ids.get(name,"")).is_empty():return {"ok":false,"reason":"cloud_unconfigured","file":name}
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(cache_root))
			var temporary:=destination+".part"
			call_deferred("fetch",bridge,str(file_ids[name]),temporary)
			var result:Dictionary=await fetched
			if not result.get("ok",false) or not valid(temporary,entry):
				DirAccess.remove_absolute(temporary)
				return {"ok":false,"reason":result.get("reason","checksum_mismatch"),"file":name}
			if FileAccess.file_exists(destination):DirAccess.remove_absolute(destination)
			if DirAccess.rename_absolute(temporary,destination)!=OK:return {"ok":false,"reason":"cache_write_failed","file":name}
			count+=1
		Assets.resolved_paths[source]=destination
	return {"ok":true,"downloaded":count,"files":names.size()}
func fetch(bridge:Node,file_id:String,path:String) -> void:
	bridge.call_fn("@fetchChunks",{"fileID":file_id,"path":ProjectSettings.globalize_path(path)},func(r:Dictionary):fetched.emit(r),90.0)

## 手机预览（村C2 10/5）：照 v4/cloud_manifest.json（tools/ayu_cloud_pack.py 生成）把阿鱼家真用到的 166 个图和声音
## 从云存储 canvas/ayu_home/ 一个个下来（@fetchChunks → 云函数 canvasFile），验字节和 sha256 后存进 user://，
## 再登记到 Assets.resolved_paths：以后 Assets.texture(原来的 res:// 路径) 就读下载好的那份。
## 工程里有原图（电脑上跑）就直接用原图，不下载。on_progress(第几个, 一共几个)
## 分批下载（10/5 晚，001：第一次进门等 10 秒左右）：清单里分了组（boot＝开家进院子、room:房间、game:小游戏……），
## 下载器是一条一直在跑的队列，同时下 PARALLEL 个：先下 boot，进家以后照清单的 order 在后台接着下；
## 要进的房间、要开的小游戏那一组还没下完，want() 把它插到队头，wait_group() 等它下完（带进度）。
## 工程里有原图（电脑上跑）就不下，组都算已经好了
const CLOUD_MANIFEST:="res://ayu_home/v4/cloud_manifest.json"
const PARALLEL:=4
signal file_settled(source:String,ok:bool)
var man:Dictionary={}
var bridge:Node
var queue:Array=[]
var ready_files:Dictionary={}
var failed_files:Dictionary={}
var inflight:Dictionary={}
var running:=0
var downloaded:=0
func setup(cloud_bridge:Node,use_packaged:=true) -> void:
	if running>0:return
	bridge=cloud_bridge;man=JSON.parse_string(FileAccess.get_file_as_string(CLOUD_MANIFEST))
	ready_files.clear();failed_files.clear();queue.clear() # 每次重新看一遍手机里有什么（缓存坏了要重下）
	for source in man.files:
		var entry:Dictionary=man.files[source]
		Assets.resolved_paths.erase(source)
		if use_packaged and (FileAccess.file_exists(source) or ResourceLoader.exists(source)):ready_files[source]=true;continue
		if valid(cloud_cache(entry),entry):Assets.resolved_paths[source]=cloud_cache(entry);ready_files[source]=true
func group_files(group:String) -> Array:return man.get("groups",{}).get(group,[]) if group!="all" else man.files.keys()
func missing(group:String) -> Array:return group_files(group).filter(func(p):return not ready_files.has(p))
func is_ready(group:String) -> bool:return missing(group).is_empty()
func missing_cloud() -> int:
	if man.is_empty():setup(null)
	return missing("boot").size()
## 把这一组还没下的插到队头（原来在队里的挪上来），再开工
func want(group:String) -> void:
	var front:=missing(group).filter(func(p):return not inflight.has(p))
	for p in front:queue.erase(p);failed_files.erase(p)
	queue=front+queue;pump()
## 后台照清单的 order 把剩下的都排上
func start_background() -> void:
	for g in man.get("order",[]):
		for p in group_files(g):
			if not ready_files.has(p) and not queue.has(p) and not inflight.has(p):queue.append(p)
	pump()
func pump() -> void:
	while running<PARALLEL and not queue.is_empty() and bridge!=null:
		var source:String=queue.pop_front()
		if ready_files.has(source) or inflight.has(source):continue
		inflight[source]=true;running+=1;work(source)
func work(source:String) -> void:
	var entry:Dictionary=man.files[source];var destination:=cloud_cache(entry);var temporary:=destination+".part";var result:Dictionary={}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(cache_root))
	for attempt in 2:
		var req:=Req.new()
		call_deferred("fetch_into",bridge,str(man.prefix)+str(entry.name),temporary,req)
		result=await req.done
		if result.get("ok",false) and valid(temporary,entry):break
		result["ok"]=false;DirAccess.remove_absolute(temporary)
	var ok:bool=result.get("ok",false)
	if ok:
		# 手机上（微信的内存文件系统）改名不落盘：验好以后把字节直接写成正式文件再删 .part，不靠 rename（C3 10/5 查的）
		var bytes:=FileAccess.get_file_as_bytes(temporary);var out:=FileAccess.open(destination,FileAccess.WRITE)
		if out==null:ok=false;result={"reason":"cache_write_failed"}
		else:out.store_buffer(bytes);out.close();DirAccess.remove_absolute(temporary)
	if ok:Assets.resolved_paths[source]=destination;ready_files[source]=true;downloaded+=1
	else:failed_files[source]={"ok":false,"reason":result.get("reason","checksum_mismatch"),"file":source,"detail":result.get("detail","")}
	inflight.erase(source);running-=1;file_settled.emit(source,ok);pump()
## 等这一组下完：on_progress(已好几个, 一共几个)；有一个下不下来就回失败（是哪个、为什么），不卡住
func wait_group(group:String,on_progress:Callable=Callable()) -> Dictionary:
	if group!="all" and not man.get("groups",{}).has(group):return {"ok":false,"reason":"unknown_group","file":group}
	var files:=group_files(group)
	if bridge==null and not is_ready(group):return {"ok":false,"reason":"cloud_unconfigured","file":missing(group)[0]}
	want(group)
	while true:
		var left:=missing(group)
		if on_progress.is_valid():on_progress.call(files.size()-left.size(),files.size())
		if left.is_empty():return {"ok":true,"files":files.size(),"downloaded":downloaded}
		for p in left:
			if failed_files.has(p):return failed_files[p]
		await file_settled
	return {}
## 整个清单一次下完（测试和老写法用）
func ensure_cloud(cloud_bridge:Node,on_progress:Callable=Callable(),use_packaged:=true) -> Dictionary:
	setup(cloud_bridge,use_packaged);downloaded=0
	return await wait_group("all",on_progress)
func cloud_cache(entry:Dictionary) -> String:return cache_root.path_join(str(entry.sha256)+"."+str(entry.name).get_extension())
class Req extends RefCounted:
	signal done(result:Dictionary)
func fetch_into(bridge_node:Node,file_id:String,path:String,req:Req) -> void:
	bridge_node.call_fn("@fetchChunks",{"fileID":file_id,"path":ProjectSettings.globalize_path(path)},func(r:Dictionary):req.done.emit(r),90.0)
