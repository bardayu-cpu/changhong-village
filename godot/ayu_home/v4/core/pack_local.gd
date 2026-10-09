extends SceneTree
func _initialize() -> void:
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../交付/完整村庄-1006/本地打包清单.json"))
	var pack:=PCKPacker.new()
	var error:=pack.pck_start(str(manifest.pck))
	if error!=OK:print("PACK_START_FAILED ",error);quit(1);return
	for file in manifest.files:
		error=pack.add_file(str(file.path),"res://"+str(file.path))
		if error!=OK:print("PACK_FILE_FAILED ",file.path," ",error);quit(1);return
	error=pack.flush()
	print("PACK_COMPLETE ",manifest.files.size()," ",error);quit(0 if error==OK else 1)
