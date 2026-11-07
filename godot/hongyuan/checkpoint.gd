extends RefCounted

const PATH := "user://hongyuan_save.json"
const PENDING_PATH := "user://hongyuan_save.json.tmp"
const WEB_KEY := "hongyuan_save.json"

static func read() -> Dictionary:
	var saved := _decode(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else {}
	if OS.has_feature("web") and OS.has_feature("hongyuan_wechat"):
		var wx := JavaScriptBridge.get_interface("wx")
		var mobile := _decode(str(wx.getStorageSync(WEB_KEY)))
		if int(mobile.get("revision", -1)) > int(saved.get("revision", -1)):
			saved = mobile
	elif OS.has_feature("web"):
		var web_save := _decode(str(JavaScriptBridge.eval(
			"try { localStorage.getItem('hongyuan_save.json') || '' } catch (_) { '' }",
			true
		)))
		if int(web_save.get("revision", -1)) > int(saved.get("revision", -1)):
			saved = web_save
	return saved

static func write(state: Dictionary) -> bool:
	var revision := int(state.get("revision", 0))
	var contents := JSON.stringify(state)
	var browser_saved := false
	if OS.has_feature("web") and OS.has_feature("hongyuan_wechat"):
		var result := int(JavaScriptBridge.eval(
			"""(function() {
				try {
					var current = JSON.parse(wx.getStorageSync(%s) || 'null');
					if (current && current.version === 1 && current.revision >= %d) return -1;
					wx.setStorageSync(%s, %s);
					return 1;
				} catch (_) { return 0; }
			})()""" % [JSON.stringify(WEB_KEY), revision, JSON.stringify(WEB_KEY), JSON.stringify(contents)], true
		))
		if result == -1:
			return false
		browser_saved = result == 1
	elif OS.has_feature("web"):
		# Browser refresh can precede IndexedDB's async file flush.
		var result := int(JavaScriptBridge.eval(
			"""try {
				const next = %s;
				const current = JSON.parse(localStorage.getItem(%s) || 'null');
				if (current && current.version === 1 && current.revision >= %d) { -1 }
				else { localStorage.setItem(%s, next); 1 }
			} catch (_) { 0 }""" % [JSON.stringify(contents), JSON.stringify(WEB_KEY), revision, JSON.stringify(WEB_KEY)],
			true
		))
		if result == -1:
			return false
		browser_saved = result == 1

	var file := FileAccess.open(PENDING_PATH, FileAccess.WRITE)
	if file == null:
		return browser_saved
	var written := file.store_string(contents)
	file.close()
	if not written:
		return browser_saved
	var file_saved := DirAccess.rename_absolute(PENDING_PATH, PATH) == OK
	if file_saved and OS.has_feature("web"):
		JavaScriptBridge.force_fs_sync()
	return file_saved or browser_saved

static func _decode(value: String) -> Dictionary:
	if value.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(value)
	if parsed is Dictionary and int(parsed.get("version", 0)) == 1:
		return parsed
	return {}
