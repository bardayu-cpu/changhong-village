extends SceneTree
## 冒烟测试：从第三章到终章，每一拍截图，小游戏用模拟输入真玩一遍。
## 用法：xvfb-run godot --path . -s res://hongyuan/tests/scenes_walkthrough.gd -- <输出目录>

class Harness extends "res://hongyuan/player.gd":
	func _save() -> void:
		pass
	func _start_scene(resume := false) -> void:
		super._start_scene(resume)
		runner.set_process(false)

var out := "user://shots"
var p
var n := 0
var fails := 0
var only := PackedStringArray()   # 可选第二个参数：逗号分隔的步骤号，只跑这些章节（快速看图）


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	if args.size() > 1:
		only = args[1].split(",")
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(540, 960)
	call_deferred("run")


func frames(k := 3) -> void:
	for i in range(k):
		await process_frame


func shot(tag: String) -> void:
	await frames(2)
	n += 1
	var img := root.get_texture().get_image()
	img.save_png("%s/%03d_%s.png" % [out, n, tag])


func tick(sec: float) -> void:
	var r = p.runner
	var steps := int(sec / 0.05)
	for i in range(steps):
		if r == null or not is_instance_valid(r):
			return
		r._process(0.05)


func run() -> void:
	p = Harness.new()
	p.size = Vector2(540, 960)
	root.add_child(p)
	p.set_process(false)
	await frames()
	for step_id in ["shanghai/board_car", "shanghai/approach_axiao", "shanghai/line_1", "shanghai/chat_axiao", "chengdu/chengdu_walk"]:
		if not only.is_empty():
			break
		p._enter_step(p.step_indices[step_id])
		if p.shot.type == "chat":
			p.elapsed = 1.0
			p.stage.time = 1.0
			p._present_chat()
		await shot(step_id.replace("/", "_"))
	for step_id in ["shanghai/drive", "call/night_call", "shizuoka/pier", "hainan/wanning", "hongkong/hk", "finale/finale"]:
		if not only.is_empty() and not step_id in only:
			continue
		if not p.step_indices.has(step_id):
			push_error("missing step " + step_id)
			fails += 1
			continue
		p._enter_step(p.step_indices[step_id])
		await frames()
		await play_scene(step_id.get_slice("/", 0))
	await frames(3)
	if not only.is_empty():
		print("SHOTS ", n, " FAILS ", fails)
		quit(1 if fails > 0 else 0)
		return
	if p.shot.type != "terminal" or p.shot.copyId != "W-NEXT" or p.state.get("guest", {}).get("name", "") != "测试宾客":
		push_error("terminal/guest handoff missing")
		fails += 1
	await shot("finale_terminal")
	print("SHOTS ", n, " FAILS ", fails)
	quit(1 if fails > 0 else 0)


func play_scene(tag: String) -> void:
	var guard := 0
	var sid: String = p.shot.fullId
	while p.runner and is_instance_valid(p.runner) and guard < 80 and p.shot.fullId == sid:
		guard += 1
		var r = p.runner
		var beat: Dictionary = r.beats[r.bi] if r.bi < r.beats.size() else {}
		match r.mode:
			"say", "auto":
				tick(0.6)
				await shot(tag + "_say")
				r._next()
			"card", "material", "wait":
				tick(0.8)
				await shot(tag + "_" + r.mode)
				r._next()
			"button":
				await shot(tag + "_button")
				r._next()
			"choice":
				tick(0.6)
				await shot(tag + "_choice")
				r._next()
			"go":
				await shot(tag + "_go")
				var h: Dictionary = r.hotspots.get(r.go_id, {})
				if h.is_empty():
					push_error("no hotspot " + r.go_id)
					fails += 1
					r._next()
				else:
					# 点地只移动；到达后再明确点击无字互动按钮。
					r.target = r._clamp(r._v(h.at))
					r.moving = true
					var before: int = r.bi
					for i in range(200):
						r._process(0.05)
						if i == 10:
							await shot(tag + "_walking")
						if r.bi != before:
							break
					if r.bi == before and r._near_hotspot() == r.go_id:
						r._go_input("up", r._icon_rect(r.go_id).get_center(), true)
					if r.bi == before:
						push_error("did not arrive at " + r.go_id + " feet=" + str(r.feet))
						fails += 1
						r._next()
			"game":
				await play_game(tag, str(beat.game))
		await frames(1)
	if guard >= 80:
		fails += 1
		push_error("scene loop guard " + tag)


func play_game(tag: String, name: String) -> void:
	var r = p.runner
	var g = r.game
	var before: int = r.bi
	match name:
		"drive":
			await shot(tag + "_drive_ready")
			g.input("tap", Vector2(180, 582))
			tick(2.0)
			g.input("down", Vector2(180, 500)); g.input("move", Vector2(230, 500)); g.input("up", Vector2(230, 500))
			tick(1.0)
			await shot(tag + "_drive")
			g.scroll = g.LENGTH - 10.0
			tick(1.0)
			g.input("down", Vector2(180, 500)); g.input("move", Vector2(240, 500)); g.input("up", Vector2(240, 500))
			for i in range(400):
				if r.bi != before:
					break
				# 车位到了附近就按住减速，然后松手
				if g.phase == "park" and g.bay_y > 400 and not g.holding:
					g.input("down", Vector2(180, 500))
				if i == 60:
					await shot(tag + "_parking")
				r._process(0.05)
		"fishing":
			g.input("down", Vector2(180, 590)); tick(0.6)
			await shot(tag + "_fish_charge")
			g.input("up", Vector2(180, 590)); tick(0.8)
			while g.phase == "wait":
				r._process(0.05)
			await shot(tag + "_fish_bite")
			g.input("down", Vector2(180, 560)); tick(0.5)
			await shot(tag + "_fish_caught")
			tick(2.0)
		"ringtoss":
			await shot(tag + "_ring_aim")
			g.input("down", Vector2(180, 560)); g.input("move", Vector2(180, 600)); g.input("move", Vector2(182, 640))
			await shot(tag + "_ring_drag")
			g.input("up", Vector2(182, 640)); tick(0.4)
			await shot(tag + "_ring_fly")
			tick(1.5)
			await shot(tag + "_ring_land")
			g.input("tap", g._continue_rect().get_center()); tick(1.0)
		"fireworks":
			for q in [Vector2(90, 150), Vector2(260, 120), Vector2(180, 260), Vector2(120, 300), Vector2(250, 330)]:
				g.input("down", q); tick(0.3)
			await shot(tag + "_fireworks")
			tick(2.0)
			await shot(tag + "_finale_burst")
			tick(2.0)
			await shot(tag + "_wax")
			tick(1.0)
		"call":
			await shot(tag + "_call_ring")
			g.input("tap", g._accept_rect().get_center())
			g.input("down", g._listen_rect().get_center())
			var captured := false
			for i in range(1200):
				if r.bi != before or g.phase != "talk":
					break
				r._process(0.05)
				if g.birthday_flash > 0.0 and not captured:
					await shot(tag + "_call_talk")
					captured = true
			g.input("up", g._listen_rect().get_center())
			tick(0.7)
			for i in range(4):
				tick(0.2)
				await shot(tag + "_call_reply")
				g.input("tap", g._speaker_rect().get_center() if g.li == 6 else Vector2(180, 500))
			tick(0.3)
			await shot(tag + "_call_hangup")
			tick(0.4)
		"desk_chat":
			for i in range(g.lines.size()):
				tick(3.0)
				await shot(tag + "_window_wechat_" + str(i + 1))
				g.input("tap", Vector2(180, 618))
		"offer":
			await shot(tag + "_offer_list")
			g.input("tap", g._row().get_center())
			tick(0.6)
			await shot(tag + "_offer_open")
			g.input("down", Vector2(180, 250)); g.input("move", Vector2(180, 200)); g.input("move", Vector2(180, 170)); g.input("up", Vector2(180, 170))
			await shot(tag + "_offer_scrolled")
			for i in range(6):
				g.input("tap", Vector2(180, 250))
			tick(0.3)
			await shot(tag + "_offer_end")
			g.input("tap", g._button_rect().get_center())
			await shot(tag + "_offer_accept")
		"mail":
			await shot(tag + "_mail_list")
			g.input("tap", g._row().get_center()); tick(1.0)
			await shot(tag + "_mail_open")
			g.input("tap", Vector2(180, 400))
		"onsen":
			await shot(tag + "_onsen_join")
			g.input("tap", Vector2(g.SPOT_X, g.WATER_Y - 10))
			tick(0.5)
			await shot(tag + "_onsen_glide")
			tick(1.2)
			for i in range(g.lines.size()):
				tick(2.5)
				await shot(tag + "_onsen_line_" + str(i + 1))
				g.input("tap", Vector2(180, 300))
			tick(3.0)
			await shot(tag + "_onsen_night")
		"photo":
			tick(1.5)
			await shot(tag + "_photo_walk")
			tick(4.0)
			await shot(tag + "_photo_ready")
			g.input("tap", g.CAMERA)
			for i in range(5):
				r._process(0.05)
				await frames(2)
			await shot(tag + "_photo_flash")
			tick(0.9)
			await frames(2)
			await shot(tag + "_photo_show")
		"seat":
			tick(5.0)
			await shot(tag + "_seat_pick")
			g.input("tap", g.TABLES[2])
			tick(2.0)
			await shot(tag + "_seat_walk")
			tick(4.0)
			await shot(tag + "_seated")
			tick(3.0)
		"finale":
			tick(1.0)
			await shot(tag + "_invite")
			g.input("tap", Vector2(180, 400))
			await frames()
			g.edit.text = "测试宾客"
			await shot(tag + "_name")
			g.input("tap", g._ok_rect().get_center())
			g.input("tap", g._look_rect(2).get_center())
			await shot(tag + "_look")
			g.input("tap", g._ok_rect().get_center())
			g.input("down", g._envelope().get_center()); tick(0.5)
			await shot(tag + "_seal_hold")
			tick(1.0); g.input("up", Vector2.ZERO)
			await shot(tag + "_sealed")
			tick(2.0)
	for i in range(100):
		if r.bi != before:
			return
		r._process(0.05)
	push_error("game did not finish: " + name + " phase=" + str(g.phase))
	fails += 1
	r._next()
