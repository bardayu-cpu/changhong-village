extends Node
## Optional caller-managed prefetch through the existing authenticated bridge.
## No network call on normal local startup; no embedded online IDs or uploads.
signal fetched(result:Dictionary)
const Assets=preload("res://ayu_home/v2/assets.gd")
const P:="res://ayu_home/v2/assets/"
var cache_root:="user://ayu_home_original_v2/"
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
