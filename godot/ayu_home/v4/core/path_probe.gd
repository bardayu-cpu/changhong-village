extends SceneTree
func _initialize() -> void:
	print("USER_DIR=",OS.get_user_data_dir())
	print("CACHE_DIR=",OS.get_cache_dir())
	quit()
