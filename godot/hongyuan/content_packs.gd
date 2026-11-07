extends RefCounted
## Only the WeChat release splits Godot resources. Other exports use their original files.

static var mounted: Dictionary = {}

static func ensure(groups: Array[String]) -> bool:
	if not OS.has_feature("web") or not OS.has_feature("hongyuan_wechat"):
		return true
	var bridge := JavaScriptBridge.get_interface("hongyuanContent")
	if bridge == null:
		push_error("Hongyuan WeChat content bridge is missing.")
		return false
	for group in groups:
		var first := -1 if bool(bridge.local(group)) else 0
		for i in range(first, int(bridge.count(group))):
			var key := "%s/%d" % [group, i]
			if mounted.has(key):
				continue
			var result: Array = []
			var callback := JavaScriptBridge.create_callback(func(args: Array) -> void:
				result.append(str(args[0]) if not args.is_empty() else "")
			)
			bridge.fetch(group, i, callback)
			var tree := Engine.get_main_loop() as SceneTree
			while result.is_empty():
				await tree.process_frame
			if result[0] == "" or not ProjectSettings.load_resource_pack(result[0], false):
				push_error("Unable to mount Hongyuan pack: " + key)
				return false
			mounted[key] = true
	return true
