extends SceneTree
const Runner = preload("res://hongyuan/scene_runner.gd")
var failures := 0
var preview: TextureRect
var out := ""
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures+=1
func tick(r,seconds: float) -> void:
	for i in range(ceili(seconds/0.05)):r._process(0.05)
func snap(vp,r,label: String) -> void:
	r.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out.path_join(label+".png"))
func show_preview(vp: SubViewport) -> void:
	if not is_instance_valid(preview):
		preview=TextureRect.new();preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		root.add_child(preview);preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.texture=vp.get_texture()

func run() -> void:
	root.title="D2 内部交互验证 · 非交付包"
	root.size=Vector2i(480,900)
	out=OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "/private/tmp/hongyuan-round1-interactions"
	DirAccess.make_dir_recursive_absolute(out)
	var copy: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://hongyuan/copy.json"))
	var lines := []
	var whos := ["toretto","ayu","toretto","toretto","toretto","toretto","narrator","ayu"]
	for i in range(8):lines.append({"say":"A4-2"+String.chr(97+i),"who":whos[i]})
	for dims in [Vector2i(360,640),Vector2i(390,844)]:
		var vp:=SubViewport.new();vp.size=dims;vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		root.add_child(vp);show_preview(vp)
		var r:=Runner.new();r.setup({"hideAyu":true,"beats":[{"game":"onsen","lines":lines},{"wait":1000}]},copy,{})
		vp.add_child(r);r.set_process(false)
		var fit:=float(dims.x)/360.0
		r.scale=Vector2.ONE*fit;r.position=(Vector2(dims)-Vector2(360,640)*fit)*0.5
		r.view_rect=Rect2(-r.position/fit,Vector2(dims)/fit)
		Runner.StoryCaption.narration_top=r.view_rect.position.y+32
		r.begin();tick(r,1.2)
		await snap(vp,r,str(dims.x)+"-onsen-entry")
		tick(r,1.5);check(r.game.phase=="join","onsen enters before choosing seat "+str(dims.x))
		var spot: Rect2=r.game._spot()
		check(r.view_rect.has_point(spot.get_center()),"visible mapped seat target "+str(dims.x))
		r.game.input("tap",spot.get_center());tick(r,1.2)
		check(r.game.phase=="talk","seat movement reaches dialogue "+str(dims.x))
		for i in range(8):
			tick(r,0.3)
			if r.game.reveal < r.game._text().length(): r.game.input("tap",Vector2(180,580))
			check(r.game.li==i and r.game.reveal==r.game._text().length(),"line retained "+str(i)+" at "+str(dims.x))
			if i in [0,1,5,7]:await snap(vp,r,str(dims.x)+"-onsen-line"+str(i))
			r.game.input("tap",Vector2(180,580))
		tick(r,6);check(r.mode=="wait","onsen complete "+str(dims.x))
		r.free()
		var rr:=Runner.new();rr.setup({"hideAyu":true,"beats":[{"game":"registration"},{"wait":1000}]},copy,{})
		vp.add_child(rr);rr.set_process(false);rr.scale=Vector2.ONE*fit;rr.position=(Vector2(dims)-Vector2(360,640)*fit)*0.5;rr.view_rect=Rect2(-rr.position/fit,Vector2(dims)/fit);rr.begin()
		tick(rr,1.2);await snap(vp,rr,str(dims.x)+"-registry-entry");tick(rr,1.7);check(rr.game.phase=="stamp","registry arrives at seal "+str(dims.x))
		await snap(vp,rr,str(dims.x)+"-registry-stamp")
		rr.game.input("down",Vector2.ZERO);tick(rr,1.2);check(rr.game.phase=="stamp" and rr.game.hold==0,"off-target hold cannot stamp")
		rr.game.input("down",rr.game._stamp_rect().get_center());tick(rr,0.4);await snap(vp,rr,str(dims.x)+"-registry-press");rr.game.input("up",rr.game._stamp_rect().get_center());check(rr.game.hold==0,"short press can retry")
		rr.game.input("down",rr.game._stamp_rect().get_center());tick(rr,1.1);check(rr.game.phase=="handover","full hold stamps")
		tick(rr,0.8);await snap(vp,rr,str(dims.x)+"-registry-handover");tick(rr,1.0);rr.game.input("tap",rr.game._next_rect().get_center());tick(rr,0.7);check(rr.game.phase=="photo","documents precede photo")
		await snap(vp,rr,str(dims.x)+"-registry-photo")
		rr.game.input("tap",rr.game._next_rect().get_center());tick(rr,1.8)
		check(rr.game.phase=="memory","photo stays present through registration memories "+str(dims.x))
		for i in range(2):
			tick(rr,0.3);rr.game.input("tap",Vector2(180,560))
			check(rr.game.li==i and rr.game._memory_text()==copy["A4-3"+String.chr(97+i)],"registry original memory retained "+str(i))
			await snap(vp,rr,str(dims.x)+"-registry-memory"+str(i))
			rr.game.input("tap",Vector2(180,560))
		tick(rr,0.1);check(rr.mode=="wait","registry completes after memories "+str(dims.x))
		rr.free();vp.free()
	await fishing(copy)
	await candidates(copy)
	print("FAILURES ",failures);quit(failures)

func fishing(copy: Dictionary) -> void:
	var vp:=SubViewport.new();vp.size=Vector2i(390,844);vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp);show_preview(vp)
	var r:=Runner.new();r.setup({"bg":"round1/scenes/harbor.png","scaleProfile":"harbor","start":[225,490],"beats":[{"game":"fishing"},{"wait":1000}]},copy,{})
	vp.add_child(r);r.set_process(false);r.scale=Vector2.ONE*(390.0/360);r.position=Vector2(0,(844-640*390.0/360)*0.5);r.view_rect=Rect2(-r.position/(390.0/360),Vector2(390,844)/(390.0/360));r.begin()
	await snap(vp,r,"fishing-01-aim")
	r.game.input("down",Vector2(180,590));tick(r,0.6);r.game.input("up",Vector2(180,590));tick(r,0.14)
	check(r.game.phase=="backcast","preparation is a distinct backswing")
	var back_tip: Vector2=r.game._tip();await snap(vp,r,"fishing-02-backcast")
	tick(r,0.12);await snap(vp,r,"fishing-02b-backcast-full")
	tick(r,0.04);tick(r,0.1);check(r.game.phase=="cast","visible forward stroke before flight")
	await snap(vp,r,"fishing-03-forward")
	tick(r,0.16);check(r.game.phase=="fly","lure releases only after forward stroke")
	check(back_tip.distance_to(r.game.from)>12,"rod tip moves through the casting arc")
	await snap(vp,r,"fishing-04-release")
	tick(r,0.3);await snap(vp,r,"fishing-05-flight")
	tick(r,0.36);check(r.game.phase=="wait","lure lands before waiting")
	await snap(vp,r,"fishing-06-wait")
	tick(r,4.1);check(r.game.phase=="bite","fish bite follows wait")
	r.game.input("tap",Vector2(180,560));tick(r,0.3);check(r.game.phase=="reel","retrieve keeps reeling before catch")
	await snap(vp,r,"fishing-07-reel")
	tick(r,0.3);check(r.game.phase=="caught","fish is brought in before success")
	await snap(vp,r,"fishing-08-caught")
	tick(r,1.8);check(r.mode=="wait","single catch completes without failure")
	r.free();vp.free()

func candidates(locked_copy: Dictionary) -> void:
	# Candidate-only layout fixture. No production copy or chapter is modified.
	var copy := locked_copy.duplicate(true)
	var texts := ["选择合适的人，才会想要组建一个稳定的关系。","不是为了结婚而结婚。","两个人的幸福状态，是活在当下。","不是为了去完成一个任务。"]
	var lines := []
	for i in range(4):
		var key := "R1-CAND-F05-%d" % (i+1)
		copy[key] = texts[i]
		lines.append({"say":key,"who":"ayu" if i%2==0 else "toretto"})
	var old_out := out
	out = out.path_join("candidate-f05")
	DirAccess.make_dir_recursive_absolute(out)
	for dims in [Vector2i(360,640),Vector2i(390,844)]:
		var vp:=SubViewport.new();vp.size=dims;vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp);show_preview(vp)
		var r:=Runner.new();r.setup({"hideAyu":true,"beats":[{"game":"onsen","lines":lines},{"wait":1000}]},copy,{})
		vp.add_child(r);r.set_process(false)
		var fit:=float(dims.x)/360.0
		r.scale=Vector2.ONE*fit;r.position=(Vector2(dims)-Vector2(360,640)*fit)*0.5;r.view_rect=Rect2(-r.position/fit,Vector2(dims)/fit)
		Runner.StoryCaption.narration_top=r.view_rect.position.y+32;r.begin();tick(r,2.6);r.game.input("tap",r.game._spot().get_center());tick(r,1.2)
		var label:=Label.new();label.text="内部排版候选 · 未定稿";label.position=Vector2(12,10);label.add_theme_font_override("font",Runner.FONT);label.add_theme_font_size_override("font_size",14);vp.add_child(label)
		for i in range(4):
			tick(r,0.3)
			if r.game.reveal<r.game._text().length():r.game.input("tap",Vector2(180,580))
			var box: Rect2=Runner.StoryCaption.caption_rect(texts[i],lines[i].who,r.game._head_anchor(lines[i].who))
			check(not box.has_point(r.game._head_anchor("ayu")) and not box.has_point(r.game._head_anchor("toretto")),"F05 candidate avoids both heads %d/%d"%[dims.x,i+1])
			check(r.view_rect.encloses(box),"F05 candidate stays visible %d/%d"%[dims.x,i+1])
			await snap(vp,r,"%d-candidate-%d"%[dims.x,i+1])
			r.game.input("tap",Vector2(180,580))
		r.free();vp.free()
	out=old_out
