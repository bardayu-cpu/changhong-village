extends SceneTree
const Runner = preload("res://hongyuan/scene_runner.gd")
var failures := 0
var copy: Dictionary

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS ", label)
	else:
		failures += 1
		push_error(label)

func make_scene(spec: Dictionary, saved := {}) -> Control:
	var r = Runner.new()
	r.setup(spec, copy, {})
	root.add_child(r)
	r.set_process(false)
	r.begin(int(saved.get("beat", 0)))
	if not saved.is_empty():
		r.restore(saved)
	return r

func roundtrip(r) -> Dictionary:
	return JSON.parse_string(JSON.stringify(r.snapshot()))

func run() -> void:
	var emoji = load("res://hongyuan/fonts/HongyuanEmoji.ttf")
	emoji.allow_system_fallback = false
	check(emoji.has_char(0x1F602) and emoji.has_char(0x1F914), "Bundled emoji contains both original glyphs without OS fonts")
	check(load("res://hongyuan/fonts/dialogue_font.tres").fallbacks.size() == 1, "Dialogue font includes packaged emoji fallback")
	copy = JSON.parse_string(FileAccess.get_file_as_string("res://hongyuan/copy.json"))
	var spec := {"start":[80,500], "walkArea":[[20,350],[340,350],[340,620],[20,620]],
		"hotspots":[{"id":"seat","at":[220,450],"icon":"sit"}], "beats":[{"go":"seat"},{"say":"A4-2h","who":"ayu"}]}
	var r = make_scene(spec)
	# #49 起：点目标本身会自己走过去并触发；点别处的地面只走路、不触发。
	r._go_input("up", Vector2(220,450), true)
	for i in range(100): r._process(0.05)
	check(r.mode == "say", "Tapping the target walks there and triggers it")
	r.free()
	r = make_scene(spec)
	r._go_input("up", Vector2(220,400), true)
	for i in range(100): r._process(0.05)
	check(r.bi == 0 and r.mode == "go", "Tapping other ground only walks")
	r.feet = Vector2(215,450)
	r._go_input("up", r._icon_rect("seat").get_center(), true)
	check(r.mode == "say" and not r.moving and r.stick == Vector2.ZERO, "Explicit icon starts dialogue and clears movement")
	r.free()
	r = make_scene(spec)
	r.feet = Vector2(130,490)
	r.target = Vector2(210,455)
	r.moving = true
	var resumed = make_scene(spec, roundtrip(r))
	check(resumed.feet == r.feet and resumed.target == r.target and resumed.moving, "JSON checkpoint restores feet and walking destination")
	r.free(); resumed.free()
	for game_name in ["fishing", "ringtoss", "fireworks", "finale", "drive"]:
		var sc := {"start":[180,520],"beats":[{"game":game_name},{"button":"A7-B1"}]}
		r = make_scene(sc)
		var g = r.game
		match game_name:
			"fishing":
				g.phase = "bite"; g.bob = Vector2(190,300); g.t = 0.4; g.power = 0.6
			"ringtoss":
				g.phase = "land"; g.thrown = 1; g.t = 0.3; g.aim = g.pegs[2]
				g.rings = [{"at":g.pegs[2],"peg":true}]
			"fireworks":
				g.input("down",Vector2(90,150)); g.input("down",Vector2(220,260)); g.process(0.1)
			"finale":
				g.phase = "seal"; g.name = "测试宾客"; g.look = 2; g.hold = 0.4; g.holding = true
			"drive":
				g.phase = "park"; g.scroll = 5300; g.bay_y = 380; g.lane = 2; g.holding = true
		var saved := roundtrip(r)
		resumed = make_scene(sc, saved)
		check(resumed.game.phase == g.phase, game_name + " restores phase")
		match game_name:
			"fishing": check(resumed.game.bob == g.bob and is_equal_approx(resumed.game.t,0.4), "Fish bite position and timing survive reload")
			"ringtoss": check(resumed.game.rings[0].at == g.pegs[2] and resumed.game.thrown == 1, "Ring landing and throw count survive reload")
			"fireworks": check(resumed.game.count == 2 and resumed.game.bursts[0].at == Vector2(90,150), "Fireworks preserve the tapped centers and count")
			"finale":
				check(resumed.game.name == "测试宾客" and resumed.game.look == 2 and not resumed.game.holding, "Guest selection survives; physical press is cleared")
				for i in range(30): resumed.game.process(0.05)
				check(resumed.game.phase == "seal", "Resume never completes seal without a new press")
				resumed.game.input("down", resumed.game._envelope().get_center())
				for i in range(20): resumed.game.process(0.05)
				check(resumed.game.phase == "stamped", "A full one-second press stamps the seal")
			"drive": check(resumed.game.scroll == 5300 and resumed.game.bay_y == 380 and not resumed.game.holding, "Parking location survives without restoring a finger hold")
		r.free(); resumed.free()
	print("FAILURES ", failures)
	quit(failures)
