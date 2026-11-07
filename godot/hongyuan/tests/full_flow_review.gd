extends SceneTree
## Runs every playlist step and all reachable scene games through their normal
## input/state transitions. Step entry is a developer checkpoint; no player save.
## Accelerated simulation is not a real-device timing or full browser claim.
class Harness extends "res://hongyuan/player.gd":
	func _save() -> void: pass
	func _read_checkpoint() -> Dictionary: return {}
	func _start_scene(resume := false) -> void:
		super._start_scene(resume)
		runner.set_process(false)
var p
var view: SubViewport
var out := ""
var report: Array = []
var captures := {}
var failures := 0
var serial := 0
func _initialize() -> void: call_deferred("run")
func frame() -> void: await process_frame
func tick(seconds: float) -> void:
	for i in range(ceili(seconds/0.05)):
		if is_instance_valid(p.runner): p.runner._process(0.05)
		else: p._process(0.05)
func capture(tag: String) -> void:
	if captures.has(tag): return
	captures[tag] = true
	p.stage.queue_redraw()
	if is_instance_valid(p.runner): p.runner.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	serial += 1
	var file := "%03d_%s.png" % [serial,tag.replace("/","_")]
	view.get_texture().get_image().save_png(out.path_join(file))
	report.append({"kind":"frame","tag":tag,"file":file})
func problem(message: String) -> void:
	failures += 1
	print("REVIEW_FAIL ",message)
	report.append({"kind":"failure","message":message})
func tap_scene(r, at: Vector2) -> void:
	for pressed in [true,false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT;e.pressed = pressed;e.position = at
		r._gui_input(e)
func game_action(r, g, kind: String) -> void:
	match kind:
		"desk_intro": g.input("tap",Vector2(180,585))
		"drive":
			if g.phase == "ready": g.input("tap",Vector2(180,582))
			elif g.phase == "drive":
				# Steer normally while the complete road scroll runs; no distance skip.
				var danger := false
				for car: Dictionary in g.traffic:
					if int(car.lane) == g.lane and car.y > 350 and car.y < 520: danger = true
				if danger:
					var delta := -70 if g.lane > 0 else 70
					g.input("down",Vector2(180,500));g.input("move",Vector2(180+delta,500));g.input("up",Vector2(180+delta,500))
			elif g.phase == "park" and g.bay_y > 220: g.input("down",Vector2(180,500))
		"pandas":
			if g.phase == "active":
				if g._action() != "": g.input("tap",g._action_rect().get_center())
				elif not g.bamboo_held: g.input("tap",g.BAMBOO)
				else: g.input("tap",g.FEET[g.hungry] - Vector2(0,25))
		"call":
			if g.phase == "ring": g.input("tap",g._accept_rect().get_center())
			elif g.phase == "talk": g.input("down",Vector2(180,500))
			elif g.phase == "reply": g.input("tap",g._speaker_rect().get_center() if g.li == 6 else Vector2(180,500))
		"desk_chat", "group_chat": g.input("tap",Vector2(180,610))
		"care":
			if g.phase == "care":
				for i in range(6):
					if i not in g.cleared:
						g.input("down",g.TRAY.get_center());g.input("move",g.CENTERS[i]);g.input("up",g.CENTERS[i]);break
		"balance":
			var index := 0
			for i in range(3):
				if g.levels[i] > g.levels[index]: index = i
			g.input("tap",g.rect(index).get_center())
		"registration":
			if g.phase == "stamp": g.input("down",g._stamp_rect().get_center())
			elif g.phase in ["handover","photo","memory"]: g.input("tap",g._next_rect().get_center())
		"fishing":
			if g.phase == "aim":
				g.input("down",Vector2(180,590));tick(0.6);g.input("up",Vector2(180,590))
			elif g.phase == "bite": g.input("tap",Vector2(180,560))
		"onsen":
			if g.phase == "join": g.input("tap",g._spot().get_center())
			elif g.phase == "talk": g.input("tap",Vector2(180,300))
		"ringtoss":
			if g.phase == "aim":
				g.input("down",Vector2(180,560));g.input("move",Vector2(180,620));g.input("up",Vector2(180,620))
		"offer":
			if g.phase == "list": g.input("tap",g._row().get_center())
			elif g.phase == "letter":
				g.input("down",Vector2(180,400));g.input("move",Vector2(180,230));g.input("up",Vector2(180,230))
				g.input("tap",g._button_rect().get_center())
		"photo":
			if g.phase == "ready": g.input("tap",g.CAMERA)
		"finale":
			match g.phase:
				"read": g.input("tap",Vector2(180,584))
				"name":
					g.edit.text = "测试宾客"
					g.input("tap",g._ok_rect().get_center())
				"written", "ready_send", "read_received": g.input("tap",g._ok_rect().get_center())
				"seal": g.input("down",g._envelope().get_center())
				"receive":
					g.input("down",Vector2(70,280));g.input("move",Vector2(250,280));g.input("up",Vector2(250,280))
				"look":
					g.input("tap",g._look_rect(6).get_center());g.input("tap",g._ok_rect().get_center())
				"welcome": g.input("tap",g._ok_rect().get_center())
		_: problem("Unhandled game "+kind)
func run_scene(id: String) -> void:
	var iterations := 0
	while is_instance_valid(p.runner) and p.shot.fullId == id and iterations < 1000:
		iterations += 1
		while p.fading: await process_frame
		if not is_instance_valid(p.runner) or p.shot.fullId != id: break
		var r = p.runner
		var tag := id + "_%02d_%s" % [r.bi,r.mode]
		if r.mode == "game" and r.game:
			var g = r.game
			var phase := str(g.get("phase")) if "phase" in g else "intro"
			tag += "_" + phase
			if "li" in g: tag += "_"+str(g.li)
			if "read_index" in g: tag += "_"+str(g.read_index)
			if "cleared" in g: tag += "_"+str(g.cleared.size())
			if "turn" in g: tag += "_turn"+str(g.turn)
		if r.mode in ["say","auto"] and r.reveal >= r.say_text.length(): tag += "_readable"
		if r.mode == "say": tick(maxf(0.5,r.say_text.length()/32.0))
		elif r.mode == "game" and r.game and "reveal" in r.game:
			# Let the current sentence settle before recording and tapping onward.
			if str(r.beats[r.bi].game) not in ["call"]: tick(3.0)
		await capture(tag)
		tick(0.45)
		if not is_instance_valid(p.runner) or p.shot.fullId != id: break
		r = p.runner
		match r.mode:
			"say", "card", "material": tap_scene(r,Vector2(180,588))
			"goal": tap_scene(r,Vector2(180,514))
			"button": tap_scene(r,r.button_rect.get_center())
			"go":
				if r._near_hotspot() == r.go_id: tap_scene(r,r._icon_rect(r.go_id).get_center())
				elif r.hotspots.has(r.go_id):
					var at: Vector2 = r._v(r.hotspots[r.go_id].at)
					r._go_input("up",at,true)
				else:
					problem(id+" missing hotspot "+r.go_id);return
			"choice":
				await capture(id+"_choice_destinations")
				if r.result.get("name","") != "测试宾客": problem("Finale guest identity lost")
				if r.choice_to != ["res://hongyuan/world_entry.tscn","res://hongyuan/village_entry.tscn"]: problem("Finale exits changed")
				report.append({"kind":"exits","id":id,"result":r.result,"to":r.choice_to})
				return
			"game": game_action(r,r.game,str(r.beats[r.bi].game))
		await process_frame
	if iterations >= 1000: problem(id+" stuck after 450 simulated seconds at "+p.runner.mode)
func run() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	view = SubViewport.new()
	view.size = Vector2i(360,640) if "360" in OS.get_cmdline_user_args() else Vector2i(390,844)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	root.title = "爱情篇 · 开发回归检查（非交付包）"
	var preview := TextureRect.new()
	preview.texture = view.get_texture()
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(preview)
	await frame()
	p = Harness.new();p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);view.add_child(p);p.set_process(false)
	await frame()
	if not is_instance_valid(p.fade_screen):
		problem("Playlist initialization failed");p.free();quit(1);return
	var count: int = p.playlist.size()
	for i in range(count):
		await p._enter_step(i)
		await frame()
		while p.fading: await process_frame
		var id: String = p.shot.fullId
		print("REVIEW_STEP ",id)
		report.append({"kind":"step","id":id})
		if p.shot.type == "scene": await run_scene(id)
		else:
			await capture(id+"_entry")
			if p.shot.type == "walk":
				var h: Dictionary = p._visible_hotspots()[0]
				var hit: Array = h.hit
				p._handle_tap(Vector2(hit[0]+hit[2]*0.5,hit[1]+hit[3]*0.5))
				for j in range(300):
					p._process(0.05)
					if p.shot.fullId != id: break
				if p.shot.fullId == id:
					var near: Dictionary = p._nearby_hotspot()
					if not near.is_empty(): p._handle_tap(p.Stage.interaction_rect(near).get_center())
				await capture(id+"_after_walk")
			elif p.shot.type == "notification": p._handle_tap(p.Stage.PHONE.get_center())
			elif p.shot.type == "material":
				tick(3.0);await capture(id+"_applied")
			else:
				tick(maxf(0.5,float(p.shot.get("duration",1))-0.1));await capture(id+"_visible")
		await frame()
	var result := {"steps":count,"screenshots":serial,"failures":failures,"method":"developer checkpoint per playlist step; normal game inputs; accelerated time; native fixed SubViewport; no destination world mutation","records":report}
	var file := FileAccess.open(out.path_join("report.json"),FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "));file.close()
	print("REVIEW_DONE steps=",count," screenshots=",serial," failures=",failures)
	p.free();quit(1 if failures else 0)
