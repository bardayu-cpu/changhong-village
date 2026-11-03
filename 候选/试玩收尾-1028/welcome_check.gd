extends SceneTree
const Welcome=preload("res://ayu_home/v4/core/playtest_welcome.gd")
const Music=preload("res://ayu_home/v4/core/playtest_music.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var output:=""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--report="):output=a.substr(9)
	assert(not output.is_empty())
	var fixture:=output.get_base_dir().path_join("own_fixture_"+str(Time.get_ticks_usec()))
	DirAccess.make_dir_recursive_absolute(fixture)
	ProjectSettings.set_setting("application/config/candidate_data_root",fixture)
	var rows:Array=[]
	for dim in [Vector2i(1280,720),Vector2i(390,844),Vector2i(844,390),Vector2i(540,960)]:
		root.size=dim
		var page=Welcome.new();root.add_child(page)
		await process_frame;await process_frame
		var box:=Rect2(Vector2.ZERO,Vector2(dim))
		var primary:Rect2=page.primary.get_global_rect();var toggle:Rect2=page.music_button.get_global_rect()
		rows.append({"size":[dim.x,dim.y],"primary_inside":box.encloses(primary),"music_inside":box.encloses(toggle),"art_present":page.art.texture!=null,"save":page.save_status})
		page.queue_free();await process_frame
	var path:=fixture.path_join("life.json")
	assert(not FileAccess.file_exists(path))
	var service=Music.ensure(self);var master:=AudioServer.get_bus_volume_db(0)
	service.toggle_from_gesture();assert(not service.enabled and not service.player.playing)
	service.free();service=Music.ensure(self)
	assert(not service.enabled and AudioServer.get_bus_volume_db(0)==master)
	FileAccess.open(path,FileAccess.WRITE).store_string('{"version":4,"test_fixture":true}')
	var before:=FileAccess.get_sha256(path)
	var resume=Welcome.new();root.add_child(resume);await process_frame
	var continue_ok:bool=resume.save_status=="continue" and resume.primary.text=="继续试玩" and FileAccess.get_sha256(path)==before
	resume.queue_free();await process_frame
	FileAccess.open(path,FileAccess.WRITE).store_string('own-invalid-test-fixture')
	before=FileAccess.get_sha256(path)
	var invalid=Welcome.new();root.add_child(invalid);await process_frame
	var keep_ok:bool=invalid.save_status=="unreadable" and invalid.primary.disabled and FileAccess.get_sha256(path)==before
	var report:Dictionary={"kind":"headless_controls_and_prefs_only_not_native_or_phone","layouts":rows,"continue_uses_actual_valid_save":continue_ok,"invalid_save_preserved":keep_ok,"BGM_off_persisted":not service.enabled,"master_volume_unchanged":AudioServer.get_bus_volume_db(0)==master,"track_available":service.available(),"native_audible_test":false,"actual_phone_test":false}
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	var good:bool=continue_ok and keep_ok and not service.enabled and service.available()
	for row in rows:good=good and row.primary_inside and row.music_inside and row.art_present and row.save=="new"
	print("WELCOME_AUTHOR_CHECK ",JSON.stringify(report));quit(0 if good else 3)
