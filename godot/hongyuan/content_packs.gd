extends Node
## One loader for native/Web HTTP packs and the WeChat object-storage bridge.
## A failed transfer never changes the story checkpoint. Downloads are content-addressed.
signal progress(detail: Dictionary)
const MANIFEST := "res://hongyuan/content_manifest.json"
const CACHE := "user://hongyuan-packs/"
static var runtime: Node
var cache_root := CACHE
var config: Dictionary = {}
var mounted: Dictionary = {}
var jobs: Dictionary = {}
var callbacks: Dictionary = {}
var last_error := ""
var timeout_seconds := 90.0
var stall_seconds := 15.0

static func service() -> Node:
	if not is_instance_valid(runtime):
		runtime = load("res://hongyuan/content_packs.gd").new()
		runtime.name = "HongyuanContent"
		(Engine.get_main_loop() as SceneTree).root.add_child(runtime)
		runtime.configure()
	return runtime

static func ensure(groups: Array[String]) -> bool:
	return await service().ensure_groups(groups)

static func prefetch(groups: Array[String]) -> void:
	service().ensure_groups.call_deferred(groups, true)

func configure(manifest: Dictionary = {}) -> void:
	config = manifest.duplicate(true)
	if config.is_empty() and FileAccess.file_exists(MANIFEST):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
		if parsed is Dictionary:
			config = parsed
	process_mode = Node.PROCESS_MODE_ALWAYS

func ensure_groups(groups: Array[String], background := false) -> bool:
	var bridge: JavaScriptObject
	if OS.has_feature("web") and OS.has_feature("hongyuan_wechat"):
		bridge = JavaScriptBridge.get_interface("hongyuanContent")
		if bridge == null:
			last_error = "资源服务尚未连接"
			return false
		return await _wechat(groups, bridge, background)
	if str(config.get("mode", "bundled")) == "bundled":
		return true
	var entries: Array = []
	for group in groups:
		if not config.get("groups", {}).has(group):
			last_error = "本版本缺少章节清单：" + group
			return false
		entries.append_array(config.groups[group])
	var total := 0
	for entry: Dictionary in entries:
		total += int(entry.bytes)
	var completed := 0
	for entry: Dictionary in entries:
		if not await _entry(entry, completed, total, background):
			progress.emit({"state": "error", "error": last_error, "background": background})
			return false
		completed += int(entry.bytes)
		progress.emit({"state": "ready", "received": completed, "total": total, "background": background})
	return true

func _entry(entry: Dictionary, completed: int, total: int, background: bool) -> bool:
	var hash_value := str(entry.get("sha256", ""))
	if hash_value.length() != 64 or not hash_value.is_valid_hex_number(false) or int(entry.get("bytes", 0)) <= 0:
		last_error = "资源清单校验失败"
		return false
	if mounted.has(hash_value):
		return true
	# A foreground chapter can join its in-flight prefetch without downloading twice.
	if jobs.has(hash_value):
		var shared: Dictionary = jobs[hash_value]
		while not bool(shared.done):
			progress.emit({"state": "download", "received": completed + int(shared.received), "total": total, "background": background})
			await get_tree().process_frame
		return bool(shared.ok)
	var job := {"done": false, "ok": false, "received": 0}
	jobs[hash_value] = job
	var ok := await _download_and_mount(entry, completed, total, background, job)
	job.ok = ok
	job.done = true
	jobs.erase(hash_value)
	return ok

func _download_and_mount(entry: Dictionary, completed: int, total: int, background: bool, job: Dictionary) -> bool:
	var hash_value := str(entry.sha256)
	DirAccess.make_dir_recursive_absolute(cache_root)
	var cached := cache_root + hash_value + ".pck"
	if FileAccess.file_exists(cached) and FileAccess.get_sha256(cached) == hash_value:
		if ProjectSettings.load_resource_pack(cached, false):
			mounted[hash_value] = true
			return true
	var base := str(config.get("baseUrl", ""))
	if OS.has_feature("web") and not base.is_empty():
		base = str(JavaScriptBridge.eval("new URL(%s, location.href).href" % JSON.stringify(base), true))
	var local_http := bool(config.get("development", false)) and (base.begins_with("http://127.0.0.1:") or base.begins_with("http://localhost:"))
	if not base.begins_with("https://") and not local_http:
		last_error = "章节下载地址尚未配置"
		return false
	var filename := str(entry.get("file", ""))
	if filename.contains("/") or filename.contains("..") or filename.is_empty():
		last_error = "资源文件名无效"
		return false
	var temporary := cached + ".part"
	var request := HTTPRequest.new()
	request.timeout = timeout_seconds
	request.body_size_limit = int(entry.bytes)
	if not OS.has_feature("web"):
		request.download_file = temporary
	request.accept_gzip = false
	add_child(request)
	var response: Array = []
	request.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray):
		response.append([result, code, body]))
	var error := request.request(base.trim_suffix("/") + "/" + filename)
	if error != OK:
		request.queue_free()
		last_error = "网络未连接，请稍后重试"
		return false
	var last_bytes := -1
	var last_change := Time.get_ticks_msec()
	var last_emit := 0
	while response.is_empty():
		var received := request.get_downloaded_bytes()
		job.received = received
		var now := Time.get_ticks_msec()
		if received != last_bytes:
			last_bytes = received
			last_change = now
		if now - last_emit > 100:
			progress.emit({"state": "download", "received": completed + received, "total": total, "background": background})
			last_emit = now
		if now - last_change > stall_seconds * 1000.0:
			request.cancel_request()
			break
		await get_tree().process_frame
	request.queue_free()
	if response.is_empty() or int(response[0][0]) != HTTPRequest.RESULT_SUCCESS or int(response[0][1]) != 200:
		DirAccess.remove_absolute(temporary)
		last_error = "下载中断，请检查网络后重试"
		return false
	# Web uses an explicit close before hashing; never inspect an open buffered writer.
	if OS.has_feature("web"):
		var writer := FileAccess.open(temporary, FileAccess.WRITE)
		if writer == null:
			last_error = "暂时无法保存这段回忆，请重试"
			return false
		writer.store_buffer(response[0][2])
		writer.close()
	var file := FileAccess.open(temporary, FileAccess.READ)
	var actual_size := file.get_length() if file != null else -1
	var valid := actual_size == int(entry.bytes)
	if file:
		file.close()
	var actual_hash := FileAccess.get_sha256(temporary)
	if not valid or actual_hash != hash_value:
		print("CONTENT_INTEGRITY expected_bytes=", entry.bytes, " actual_bytes=", actual_size, " expected_sha=", hash_value, " actual_sha=", actual_hash)
		DirAccess.remove_absolute(temporary)
		last_error = "资源未完整下载，请重试"
		return false
	if DirAccess.rename_absolute(temporary, cached) != OK or not ProjectSettings.load_resource_pack(cached, false):
		last_error = "资源保存失败，请腾出设备空间后重试"
		return false
	mounted[hash_value] = true
	if OS.has_feature("web"):
		JavaScriptBridge.force_fs_sync()
	return true

func _wechat(groups: Array[String], bridge: JavaScriptObject, background: bool) -> bool:
	for group in groups:
		var first := -1 if bool(bridge.local(group)) else 0
		for i in range(first, int(bridge.count(group))):
			var key := "%s/%d" % [group, i]
			if mounted.has(key):
				continue
			var result: Array = []
			var token := str(Time.get_ticks_usec()) + key
			callbacks[token] = JavaScriptBridge.create_callback(func(args: Array):
				result.append(str(args[0]) if not args.is_empty() else "")
				callbacks.erase(token))
			bridge.fetch(group, i, callbacks[token])
			var started := Time.get_ticks_msec()
			while result.is_empty():
				if Time.get_ticks_msec() - started > timeout_seconds * 1000.0:
					last_error = "下载超时，请重试"
					return false
				var status: Variant = JSON.parse_string(str(bridge.status(group, i)))
				if status is Dictionary:
					status.background = background
					progress.emit(status)
				await get_tree().process_frame
			if str(result[0]).is_empty() or not ProjectSettings.load_resource_pack(result[0], false):
				last_error = "资源下载未完成，请重试"
				return false
			mounted[key] = true
	return true
