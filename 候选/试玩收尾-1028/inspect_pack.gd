extends SceneTree
var suspicious:Array=[]
var count:=0
var paths:Array=[]
func visit(path:String) -> void:
	var dir:=DirAccess.open(path)
	if dir==null:return
	dir.include_hidden=true
	dir.include_navigational=false
	for folder in dir.get_directories():visit(path.path_join(folder))
	for file in dir.get_files():
		count+=1
		var full:=path.path_join(file);paths.append(full)
		var private_folder:=false
		for folder in ["运行数据","测试数据","user","users","save","saves","saved","userdata","user_data","playtest","qa","test_data","tests","test"]:
			if full.to_lower().begins_with("res://"+folder+"/"):private_folder=true
		if private_folder or "ayu_home_local_player" in file or file in ["life.json","core.a","core.b","music.cfg","village_music.cfg"] or full in ["res://prefs.cfg","res://preferences.cfg"] or file.begins_with("ayu_home_v4_"):suspicious.append(full)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var output:=""
	var qa:=false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.substr(9)
		if arg=="--qa":qa=true
	visit("res://")
	var report:Dictionary={"kind":"packed_profile_inspection_no_gameplay_or_save_opened","resources":count,"all_resource_paths":paths,"possible_gameplay_saves_in_pack":suspicious,"playtest_isolated":ProjectSettings.get_setting("application/config/playtest_isolated",false),"candidate_enabled":ProjectSettings.get_setting("application/config/candidate_enabled",false),"candidate_root":ProjectSettings.get_setting("application/config/candidate_data_root",""),"userdata_name":ProjectSettings.get_setting("application/config/custom_user_dir_name",""),"version":ProjectSettings.get_setting("application/config/version",""),"build":ProjectSettings.get_setting("application/config/candidate_build_id","")}
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	report.erase("all_resource_paths")
	print("PACK_PROFILE ",JSON.stringify(report));quit(0 if suspicious.is_empty() and report.playtest_isolated and bool(report.candidate_enabled)==qa and (qa or str(report.candidate_root).is_empty()) else 3)
