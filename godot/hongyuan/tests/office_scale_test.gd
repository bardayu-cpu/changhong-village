extends SceneTree
const Runner=preload("res://hongyuan/scene_runner.gd")
var failures:=0
var out:="/private/tmp/office-scale"
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func run() -> void:
	if not OS.get_cmdline_user_args().is_empty():out=OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	root.title="D2 CBD 比例复验 · 非交付包";root.size=Vector2i(480,900)
	var preview:=TextureRect.new();preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;root.add_child(preview);preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var chapter: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://hongyuan/chapters/call.json"))
	var copy: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://hongyuan/copy.json"))
	for dims in [Vector2i(360,640),Vector2i(390,844)]:
		var vp:=SubViewport.new();vp.size=dims;vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp);preview.texture=vp.get_texture()
		var r:=Runner.new();r.setup(chapter.steps[0].scene,copy,{});vp.add_child(r);r.set_process(false)
		var fit: float=dims.x/360.0;r.scale=Vector2.ONE*fit;r.position=(Vector2(dims)-Vector2(360,640)*fit)*0.5;r.view_rect=Rect2(-r.position/fit,Vector2(dims)/fit)
		r.begin(9);r.reveal=r.say_text.length();r.t=1;r.StoryCaption.narration_top=r.view_rect.position.y+54
		for mode in ["say","wait"]:
			r.mode=mode;r.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
			vp.get_texture().get_image().save_png(out.path_join(str(dims.x)+"-office-"+mode+".png"))
		var xf: Transform2D=r._walker_source_transform()
		check(r._walker_pos(r.walkers[0]).distance_to(xf*Vector2(240,840))<0.01,"window colleague feet match source at "+str(dims.x))
		check(r._walker_pos(r.walkers[1]).distance_to(xf*Vector2(750,850))<0.01,"desk colleague feet match source at "+str(dims.x))
		check(float(r.walkers[0].sourceHeight)*xf.x.length()>110,"background adult body remains substantial "+str(dims.x))
		r.free();vp.free()
	print("FAILURES ",failures);quit(failures)
