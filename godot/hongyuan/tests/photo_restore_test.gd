extends SceneTree
const Runner = preload("res://hongyuan/scene_runner.gd")
const Ambient = preload("res://hongyuan/ui/ambient_scene.gd")
var failures := 0
var preview: TextureRect
var copy: Dictionary
var out := "/private/tmp/hongyuan-photo-restore"
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures += 1
func tick(r: Control,seconds: float) -> void:
	for i in range(ceili(seconds/0.05)): r._process(0.05)
func make(vp: SubViewport,saved: Dictionary = {}) -> Control:
	var r := Runner.new()
	r.setup({"bg":"round1/scenes/disney_toys.png","scaleProfile":"disney","hideAyu":true,"beats":[{"game":"photo"},{"wait":1000}]},copy,{})
	vp.add_child(r);r.set_process(false)
	var fit := vp.size.x/360.0
	r.scale=Vector2.ONE*fit;r.position=(Vector2(vp.size)-Vector2(360,640)*fit)*0.5
	r.view_rect=Rect2(-r.position/fit,Vector2(vp.size)/fit);r.begin()
	if not saved.is_empty(): r.restore(saved)
	return r
func snap(vp: SubViewport,r: Control,file: String) -> void:
	r.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out.path_join(file+".png"))
func show_preview(vp: SubViewport) -> void:
	if not is_instance_valid(preview):
		preview=TextureRect.new();preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		root.add_child(preview);preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.texture=vp.get_texture()

func run() -> void:
	root.title="D2 内部交互验证 · 非交付包"
	root.size=Vector2i(480,900)
	if not OS.get_cmdline_user_args().is_empty():out=OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	copy=JSON.parse_string(FileAccess.get_file_as_string("res://hongyuan/copy.json"))
	for dims in [Vector2i(360,640),Vector2i(390,844)]:
		var vp:=SubViewport.new();vp.size=dims;vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp);show_preview(vp)
		for phase in ["walk","ready","prep","flash","show"]:
			var r=make(vp)
			r.game.phase=phase;r.game.ayu_x=111.0;r.game.toretto_x=99.0;r.game.t=0.21
			var saved: Dictionary=JSON.parse_string(JSON.stringify(r.snapshot()))
			r.free()
			# Also cover an older ready checkpoint that never saved Toretto's x.
			if phase == "ready": saved.game.erase("toretto_x")
			r=make(vp,saved)
			var label: String=str(dims.x)+"-"+phase
			if phase == "walk":
				check(r.game.ayu_x==111 and r.game.toretto_x==99,"mid-walk preserves both positions "+label)
			else:
				check(r.game.ayu_x==r.game.AYU_STOP and r.game.toretto_x==r.game.TORETTO_STOP,"both people present after restore "+label)
			if phase == "ready":
				check(r.hint==r.t_("G-PHOTO"),"camera prompt restores "+label)
				await snap(vp,r,label)
				r.game.input("tap",r.game.CAMERA)
			if phase in ["ready","prep","flash","show"]:
				check(r.game.phase=="prep" and r.game._frames==0 and r.game._photo==null,"missing GPU photo restarts clean capture "+label)
				for i in range(3):
					r.queue_redraw();await process_frame;await RenderingServer.frame_post_draw;r._process(0.016)
				check(r.game.phase=="flash" and r.game._photo!=null,"actual frame recaptured "+label)
				tick(r,0.95)
				await snap(vp,r,label+"-recovered")
				check(r.game.phase=="show" and r.game._photo.get_width()==dims.x,"polaroid keeps viewport pixels "+label)
				tick(r,2.3);check(r.mode=="wait","restored photo completes "+label)
			r.free()
		vp.free()
	var contained := true
	for i in range(24):
		for time in [0.0,0.8,3.2,14.0,53.7]:
			contained = contained and Rect2(560,580,280,165).encloses(Ambient._pool_glint(i,time))
	check(contained,"all animated glints remain within Wanning pool source region")
	print("FAILURES ",failures);quit(failures)
