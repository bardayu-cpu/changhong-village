extends Node
## Versioned PNG cache. Uses the existing WeChat bridge; never reads GPU pixels.
signal fetched(result: Dictionary)
signal progress(current: int, total: int)
const MANIFEST := "res://ayu_home/asset_manifest.json"
const SOURCE := "res://ayu_home/assets/"
var cache_root := "user://ayu_home_art/"
var allow_source := true
var config: Dictionary = {}
static var active_cache := "user://ayu_home_art/"
static var manifest_cache: Dictionary = {}
static var verified_paths: Dictionary = {}

static func manifest() -> Dictionary:
	if manifest_cache.is_empty() and FileAccess.file_exists(MANIFEST):
		var value = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
		if value is Dictionary: manifest_cache = value
	return manifest_cache

static func required_files() -> Array:
	return manifest().get("files", {}).keys()

static func cache_path(name: String, root_path: String = active_cache, cfg: Dictionary = {}) -> String:
	var source := manifest() if cfg.is_empty() else cfg
	var entry: Dictionary = source.get("files", {}).get(name, {})
	return root_path.path_join(str(entry.get("sha256", "missing")) + ".png")

static func image(name: String) -> Image:
	if not manifest().get("files", {}).has(name): return null
	var path: String = verified_paths.get(name,"")
	if path.is_empty() or not FileAccess.file_exists(path):
		var entry: Dictionary = manifest().files[name]
		path = SOURCE + name
		if not valid_file(path,entry): path = cache_path(name)
		if not valid_file(path,entry): return null
		verified_paths[name] = path
	var result := Image.new()
	if result.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK: return null
	return result

static func texture(name: String) -> Texture2D:
	var img := image(name)
	return ImageTexture.create_from_image(img) if img != null else null

static func valid_file(path: String, entry: Dictionary) -> bool:
	if not FileAccess.file_exists(path): return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() != int(entry.get("bytes", -1)): return false
	file.close()
	return FileAccess.get_sha256(path) == str(entry.get("sha256", ""))

func verify(path: String, entry: Dictionary) -> bool:
	return valid_file(path,entry)

func ensure_all(cloud: Node, names: Array = []) -> Dictionary:
	if config.is_empty(): config = manifest()
	active_cache = cache_root
	var entries: Dictionary = config.get("files", {})
	if names.is_empty(): names = entries.keys()
	if entries.is_empty(): return {"ok":false,"reason":"manifest_missing"}
	var downloaded := 0
	var index := 0
	for value in names:
		var name := str(value)
		if not entries.has(name): return {"ok":false,"reason":"unknown_asset","file":name}
		var entry: Dictionary = entries[name]
		var destination := cache_path(name,cache_root,config)
		var source_valid := allow_source and verify(SOURCE + name,entry)
		if not (source_valid or verify(destination,entry)):
			var file_id := str(entry.get("file_id", ""))
			if file_id.is_empty() or cloud == null:
				return {"ok":false,"reason":"cloud_unconfigured","file":name}
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(cache_root))
			var temporary := destination + ".part"
			call_deferred("_fetch",cloud,file_id,temporary,str(entry.get("via","function")))
			var response: Dictionary = await fetched
			if not bool(response.get("ok",false)):
				DirAccess.remove_absolute(temporary)
				return {"ok":false,"reason":response.get("reason","download_failed"),"file":name}
			if not verify(temporary,entry):
				DirAccess.remove_absolute(temporary)
				return {"ok":false,"reason":"checksum_mismatch","file":name}
			if FileAccess.file_exists(destination): DirAccess.remove_absolute(destination)
			if DirAccess.rename_absolute(temporary,destination) != OK:
				return {"ok":false,"reason":"cache_write_failed","file":name}
			downloaded += 1
		verified_paths[name] = SOURCE + name if source_valid else destination
		index += 1
		progress.emit(index,names.size())
	return {"ok":true,"downloaded":downloaded,"files":names.size()}

func _fetch(cloud: Node, file_id: String, destination: String, via: String) -> void:
	var method := "@fetchChunks" if via == "function" else "@fetchFile"
	cloud.call_fn(method,{"fileID":file_id,"path":ProjectSettings.globalize_path(destination)},func(result: Dictionary): fetched.emit(result),90.0)
