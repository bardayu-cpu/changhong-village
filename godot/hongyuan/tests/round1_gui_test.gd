extends SceneTree
const Runner = preload("res://hongyuan/scene_runner.gd")
class Harness extends "res://hongyuan/player.gd":
	func _save() -> void: pass
	func _read_checkpoint() -> Dictionary: return {}
var failures := 0
var out := "/private/tmp/hongyuan-gui"
var preview: TextureRect
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures+=1
func tick(r,seconds: float) -> void:
	for i in range(ceili(seconds/0.05)):r._process(0.05)
func viewport(dims: Vector2i) -> SubViewport:
	var vp:=SubViewport.new();vp.size=dims;vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;vp.gui_disable_input=false;root.add_child(vp)
	preview.texture=vp.get_texture();return vp
func button(vp: SubViewport,r: Control,at: Vector2,pressed: bool,touch: bool) -> void:
	var e: InputEvent
	if touch:
		e=InputEventScreenTouch.new();e.index=0
	else:
		e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT
	e.position=r.get_global_transform()*at;e.pressed=pressed
	vp.push_input(e,true)
func drag(vp: SubViewport,r: Control,at: Vector2,touch: bool) -> void:
	var e: InputEvent
	if touch:
		e=InputEventScreenDrag.new();e.index=0
	else:
		e=InputEventMouseMotion.new();e.button_mask=MOUSE_BUTTON_MASK_LEFT
	e.position=r.get_global_transform()*at;e.relative=Vector2(36,0)
	vp.push_input(e,true)
func snap(vp: SubViewport,r: Control,label: String) -> Image:
	r.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	var image:=vp.get_texture().get_image();image.save_png(out.path_join(label+".png"));return image
func dark_pixels(image: Image,r: Control,rect: Rect2) -> int:
	var origin: Vector2=r.get_global_transform()*rect.position
	var end: Vector2=r.get_global_transform()*rect.end
	var count:=0
	for y in range(int(origin.y),int(end.y)):
		for x in range(int(origin.x),int(end.x)):
			var c:=image.get_pixel(x,y)
			if c.r<0.45 and c.g<0.45 and c.b<0.45:count+=1
	return count
func run() -> void:
	root.title="D2 GUI 实测 · 非交付包";root.size=Vector2i(480,900)
	preview=TextureRect.new();preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;preview.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(preview);preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not OS.get_cmdline_user_args().is_empty():out=OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	var copy: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://hongyuan/copy.json"))
	for dims in [Vector2i(360,640),Vector2i(390,844)]:
		var vp:=viewport(dims)
		var r:=Runner.new();r.setup({"hideAyu":true,"beats":[{"game":"group_chat","lines":[{"say":"A1-3b","who":"axiao"}]}]},copy,{})
		vp.add_child(r);r.set_process(false)
		var fit: float=dims.x/360.0;r.scale=Vector2.ONE*fit;r.position=(Vector2(dims)-Vector2(360,640)*fit)*0.5;r.view_rect=Rect2(-r.position/fit,Vector2(dims)/fit);r.begin();tick(r,10)
		var image: Image=await snap(vp,r,str(dims.x)+"-group-chat")
		check(dark_pixels(image,r,Rect2(88,435,220,110))>100,"group message ink visible "+str(dims.x))
		for i in range(5):
			check(dark_pixels(image,r,Rect2(31+(i+3)*24,387,18,18))>5,"member face has visible pixels "+str(dims.x)+"/"+str(i))
		r.free();vp.free()
	var vp:=viewport(Vector2i(390,844))
	var p:=Harness.new();vp.add_child(p);p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame;p._fit_canvas();p._set_paused(false)
	await p._enter_step(p.step_indices["call/night_call"]);p.set_process(false)
	await process_frame
	var r=p.runner;r.set_process(false)
	var call_index:=0
	for i in range(p.shot.scene.beats.size()):
		if p.shot.scene.beats[i].get("game","")=="call":call_index=i
	r.begin(call_index);r.set_process(false)
	await process_frame
	for touch in [true,false]:
		for y in [-50.0,690.0]:
			r.game.phase="talk";r.game.li=0;r.game.reveal=0;r.game.t=0;r.game.holding=false;r.suspend_input()
			var label:=str(y)+( " touch" if touch else " mouse")
			button(vp,r,Vector2(180,y),true,touch);tick(r,0.5)
			check(r.game.reveal>5 and r.game.holding,"full height hold reaches call "+label)
			button(vp,r,Vector2(180,y),false,touch)
			var frozen: float=r.game.reveal;tick(r,0.6)
			check(r.game.reveal==frozen and not r.game.holding,"release pauses call "+label)
	await snap(vp,r,"390-call-full-height")
	# Keep the real Player/Stage Control hierarchy, swap only test scene data.
	r.setup({"bg":"round1/scenes/harbor.png","start":[180,500],"walkArea":[[20,350],[340,350],[340,620],[20,620]],"hotspots":[{"id":"test","at":[300,400],"icon":"pick"}],"beats":[{"go":"test"}]},copy,{})
	r.begin();r.camera_y=30;r.set_process(false)
	await process_frame
	for touch in [true,false]:
		r.feet=Vector2(180,500);r.target=r.feet;r.suspend_input()
		button(vp,r,Vector2(64,558),true,touch);drag(vp,r,Vector2(100,558),touch)
		check(r.stick.x>0.99 and absf(r.stick.y)<0.001,"camera shift preserves horizontal joystick "+str(touch))
		tick(r,0.35)
		check(r.feet.x>180 and absf(r.feet.y-500)<0.01,"horizontal movement has no vertical drift "+str(touch))
		button(vp,r,Vector2(100,558),false,touch)
		check(r.stick==Vector2.ZERO,"release stops joystick "+str(touch))
	await snap(vp,r,"390-camera30-horizontal")
	p.free();vp.free();print("FAILURES ",failures);quit(failures)
