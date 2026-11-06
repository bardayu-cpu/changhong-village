extends SceneTree
## 冒烟测试：从第三章到终章，每一拍截图，小游戏用模拟输入真玩一遍。
## 用法：xvfb-run godot --path . -s res://hongyuan/tests/scenes_walkthrough.gd -- <输出目录>

class Harness extends "res://hongyuan/player.gd":
	func _save() -> void:
		pass

var out := "user://shots"
var p
var n := 0
var fails := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
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
	await frames()
	for step_id in ["shanghai/drive", "call/night_call", "shizuoka/pier", "hainan/wanning", "hongkong/hk", "finale/finale"]:
		if not p.step_indices.has(step_id):
			push_error("missing step " + step_id)
			fails += 1
			continue
		p._enter_step(p.step_indices[step_id])
		await frames()
		await play_scene(step_id.get_slice("/", 0))
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
			"go":
				await shot(tag + "_go")
				var h: Dictionary = r.hotspots.get(r.go_id, {})
				if h.is_empty():
					push_error("no hotspot " + r.go_id)
					fails += 1
					r._next()
				else:
					# 点地走过去，验证寻路和到达触发
					r.target = r._clamp(r._v(h.at))
					r.target_hot = r.go_id
					r.moving = true
					var before: int = r.bi
					for i in range(200):
						r._process(0.05)
						if i == 10:
							await shot(tag + "_walking")
						if r.bi != before:
							break
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
			while r.bi == before and g.phase == "talk":
				tick(0.6)
				if g.li == 3:
					await shot(tag + "_call_talk")
				g.input("tap", Vector2(180, 400))
		"mail":
			await shot(tag + "_mail_list")
			g.input("tap", g._row().get_center()); tick(1.0)
			await shot(tag + "_mail_open")
			g.input("tap", Vector2(180, 400))
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
