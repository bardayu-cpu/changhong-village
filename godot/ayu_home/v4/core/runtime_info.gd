extends SceneTree
func _initialize() -> void:
	print("USER_DATA ",OS.get_user_data_dir())
	for row in ProjectSettings.get_property_list():
		if "shader_cache" in str(row.name):print(row.name," = ",ProjectSettings.get_setting(row.name))
	quit()
