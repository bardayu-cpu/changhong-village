extends SceneTree
var h
var sequence:=0
var root_path:=""
var driver_file:=""
var start_label:="开场"
var trace:Array=[]
var last_observation:=""
func _initialize() -> void:
	root_path=ProjectSettings.globalize_path("res://../测试数据/图形验收/")
	driver_file=root_path+"command.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-label="):start_label=arg.trim_prefix("--qa-label=")
	call_deferred("run")
func run() -> void:
	root.size=Vector2i(540,960);root.content_scale_size=Vector2i(540,960)
	var boot=load("res://ayu_home/v4/phone_boot.tscn").instantiate();root.add_child(boot)
	for i in 600:
		await process_frame
		for child in root.get_children():
			if child.get_script()!=null and child.get_script().resource_path=="res://ayu_home/v4/home.gd":h=child
		if h!=null and h.bootstrapped:break
	if h==null:print("DRIVER_NO_HOME");quit(1);return
	print("DRIVER_READY");await create_timer(1).timeout;await capture(start_label)
	while true:
		await create_timer(.2).timeout
		var observation:String=h.area+"|"+h.note+"|"+h.scene_action+"|"+h.player.action+"|"+str(h.effects_log.size())+"|"+(h.village_ui.page if h.village_ui.opened else "world")
		if observation!=last_observation:
			last_observation=observation
			trace.append({"at":Time.get_unix_time_from_system(),"area":h.area,"note":h.note,"action":h.scene_action,"player_action":h.player.action,"effects":h.effects_log.slice(-4),"page":h.village_ui.page if h.village_ui.opened else "world","position":[h.player.position.x,h.player.position.y],"fps":Engine.get_frames_per_second(),"memory":OS.get_static_memory_usage()})
			var tf:=FileAccess.open(root_path+"图形轨迹-"+start_label+".json",FileAccess.WRITE);tf.store_string(JSON.stringify(trace));tf.close()
			await capture(start_label+"-观察%03d"%trace.size())
		if not FileAccess.file_exists(driver_file):continue
		var c=JSON.parse_string(FileAccess.get_file_as_string(driver_file))
		if not c is Dictionary or int(c.get("seq",0))<=sequence:continue
		sequence=int(c.seq)
		var outcome:="ok"
		match str(c.get("command","")):
			"click":
				var target=find_button(root,str(c.get("text","")))
				if target==null:outcome="button_missing"
				else:
					var scroll=target.get_parent()
					while scroll!=null:
						if scroll is ScrollContainer:scroll.ensure_control_visible(target)
						scroll=scroll.get_parent()
					await process_frame;await process_frame
					await click_at(target.get_global_rect().get_center())
			"point":await click_at(Vector2(c.x,c.y))
			"capture":pass
			"resize":root.size=Vector2i(c.width,c.height)
			"quit":h.village_ui.checkpoint();quit();return
			_:outcome="unknown"
		await create_timer(.6).timeout
		await capture(str(c.get("name","步骤%03d"%sequence)))
		var f:=FileAccess.open(root_path+"response.json",FileAccess.WRITE);f.store_string(JSON.stringify({"seq":sequence,"result":outcome,"area":h.area,"position":[h.player.position.x,h.player.position.y],"pending":h.pending,"route":h.player.route.size(),"core":h.village_ui.state.data}));f.close()
func find_button(n:Node,wanted:String):
	if n is Button and n.is_visible_in_tree() and n.text==wanted:return n
	for child in n.get_children():
		var got=find_button(child,wanted)
		if got!=null:return got
	return null
func click_at(pos:Vector2) -> void:
	var motion:=InputEventMouseMotion.new();motion.position=pos;root.push_input(motion,true)
	for down in [true,false]:
		var e:=InputEventMouseButton.new();e.position=pos;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;root.push_input(e,true);await process_frame
func capture(name:String) -> void:
	await process_frame
	# 验收窗口被桌面遮挡时也取得当前帧；不改动玩家输入、时间或存档。
	RenderingServer.force_draw()
	var img:=root.get_texture().get_image();img.save_png(ProjectSettings.globalize_path("res://../交付/完整村庄-1006/截图/"+name+".png"))
	var controls:Array=[];walk_controls(root,controls)
	var f:=FileAccess.open(root_path+"controls.json",FileAccess.WRITE);f.store_string(JSON.stringify(controls));f.close()
func walk_controls(n:Node,out:Array) -> void:
	if n is Control and n.is_visible_in_tree() and (n is Button or n is Label):
		out.append({"type":n.get_class(),"text":n.text,"rect":[n.global_position.x,n.global_position.y,n.size.x,n.size.y]})
	for child in n.get_children():walk_controls(child,out)
