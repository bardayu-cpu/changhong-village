extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var args:=OS.get_cmdline_user_args();var out_dir:String=args[0]
	root.size=Vector2i(540,960)
	root.add_child(load("res://ayu_home/v4/phone_boot.tscn").instantiate())
	var home:Node;var shell:Node
	for i in 1200:
		await process_frame
		for child in root.get_children():
			if child.get_script()==preload("res://ayu_home/v4/core/game_viewport.gd"):shell=child;home=child.game
		if is_instance_valid(home) and home.bootstrapped:break
	if not is_instance_valid(home) or not home.bootstrapped:push_error("Home startup timeout");quit(1);return
	home.close_modal();home.set_process(false)
	await home.enter_room("village",false)
	var failures:Array=[];var rows:Array=[]
	var desktop:Vector2i=DisplayServer.screen_get_usable_rect().size
	for buffer in [Vector2i(1280,720),Vector2i(540,960),desktop,Vector2i(1280,720)]:
		root.mode=Window.MODE_MAXIMIZED if buffer==desktop else Window.MODE_WINDOWED
		if buffer!=desktop:root.size=buffer
		for i in 12:await process_frame
		shell.resize_canvas();home.player.position=Vector2(4616,568)
		for z in [1.0,2.0]:
			home.world.cfg.view_scale=z;home.layout();home.camera=home.room_camera_target();home.layout_world()
			for i in 3:await process_frame
			if z==2.0:
				await RenderingServer.frame_post_draw
				var capture:Image=shell.play.get_texture().get_image()
				capture.save_png(out_dir.path_join("author-position-"+str(buffer.x)+"x"+str(buffer.y)+".png"))
			var frame:Vector2=home.scene_frame.size;var feet:Vector2=home.world.get_transform()*home.player.position
			var horizon:Dictionary=home.village_horizon.snapshot()
			var peak:Vector2=horizon.mountain_projection.get("far",{}).get("peak",Vector2(-999,-999))
			var expected:float=root.size.y-108.0-(100.0 if home.compact_footer else 156.0)
			if shell.play.size!=root.size:failures.append("window not fully used")
			if not horizon.view_errors.is_empty():failures.append(str(horizon.view_errors))
			if not horizon.mountain_projection.far.effective_horizontal_coverage:failures.append("far layer width leaves hole")
			if frame.y!=expected:failures.append("scene height differs: "+str(frame))
			if not horizon.ready_art:failures.append(str(horizon.errors))
			if home.view_scale>1 and (peak.y<16 or feet.y>frame.y-16):failures.append("peak/feet margin failed")
			if home.view_scale==1 and home.camera.y!=503:failures.append("zoom1 camera changed")
			var buttons:Array=[]
			for item in home.footer_controls:
				var button:Control=item.node;var rect:=button.get_global_rect()
				buttons.append({"text":button.text,"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y]})
				if rect.size.y<48:failures.append("button too short")
				if home.compact_footer and rect.position.y<home.footer_boundary():failures.append("footer button overlaps scene")
			rows.append({"requested_size":[buffer.x,buffer.y],"buffer":[root.size.x,root.size.y],"requested_zoom":z,"zoom":home.view_scale,"scene":[frame.x,frame.y],"compact_footer":home.compact_footer,"camera":[home.camera.x,home.camera.y],"peak":[peak.x,peak.y],"feet":[feet.x,feet.y],"buttons":buttons,"horizon_errors":horizon.errors,"native_surface_loaded":home.world.village_ground.native_surface.ready_art,"ground_qualified":false})
	# Switching out of the village must restore original parents, anchors and scene reserve.
	await home.enter_room("exterior",false)
	for i in 5:await process_frame
	if home.compact_footer or home.scene_frame.size.y!=456:failures.append("home landscape not restored")
	for saved in home.footer_controls:
		if saved.node.get_parent()!=saved.parent:failures.append("button parent not restored")
	var report:Dictionary={"scope":"C2 GPU author-position composition/layout probe; not normal-walk or native-input acceptance","desktop_usable_size":[desktop.x,desktop.y],"author_position_fixture":true,"G0_scene_versions_used":0,"rows":rows,"home_restored":not home.compact_footer,"failures":failures,"pass":failures.is_empty()}
	FileAccess.open(out_dir.path_join("layout.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("V23_LAYOUT ",JSON.stringify(report));home.life.close_open();quit(0 if failures.is_empty() else 1)
