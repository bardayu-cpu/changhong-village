extends RefCounted
static func data_root() -> String:
	if ProjectSettings.get_setting("application/config/candidate_enabled",false):
		return str(ProjectSettings.get_setting("application/config/candidate_data_root",""))
	if ProjectSettings.get_setting("application/config/playtest_isolated",false):
		return OS.get_user_data_dir().path_join("playtest")
	return ""
static func prepare() -> bool:
	var root:=data_root()
	return root.is_empty() or DirAccess.dir_exists_absolute(root) or DirAccess.make_dir_recursive_absolute(root)==OK
