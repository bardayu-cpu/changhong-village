extends SceneTree
const Runner := preload("res://hongyuan/scene_runner.gd")
var failures := 0
var copy: Dictionary
var output := ""
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures += 1
func make(saved := {}) -> Control:
	var r := Runner.new()
	r.setup({"hideAyu": true, "beats": [{"game": "finale"}, {"choice": ["G-WEDDING", "G-VILLAGE"], "to": ["res://hongyuan/world_entry.tscn", "res://hongyuan/village_entry.tscn"]}]}, copy,
		{"pen":true,"ink":true,"paper":true,"stamp":true,"wax":true,"envelope":true})
	root.add_child(r)
	r.set_process(false)
	r.begin(int(saved.get("beat", 0)))
	if not saved.is_empty(): r.restore(saved)
	return r
func advance(r, seconds: float) -> void:
	for i in range(ceili(seconds / 0.05)): r._process(0.05)
func shot(r, label: String) -> void:
	r.queue_redraw()
	await process_frame
	await process_frame
	if output != "": root.get_texture().get_image().save_png(output + "/" + label + ".png")
func run() -> void:
	root.size = Vector2i(360,640)
	root.content_scale_size = Vector2i(360,640)
	if not OS.get_cmdline_user_args().is_empty(): output = OS.get_cmdline_user_args()[0]
	copy = JSON.parse_string(FileAccess.get_file_as_string("res://hongyuan/copy.json"))
	var r := make()
	for screen in range(3):
		advance(r, 0.8)
		r.game.input("tap", Vector2(180,580))
	check(r.game.phase == "name", "recipient reads before name entry")
	r.game.edit.text = "a"
	r.game.input("tap", Vector2(180,580))
	check(r.game.phase == "name" and r.game.error, "short name stays editable")
	r.game.edit.text = "久别的朋友"
	r.game.input("tap", Vector2(180,580))
	check(r.game.phase == "write", "name leads to physical handwriting, not avatar selection")
	advance(r, 0.8)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(r.snapshot()))
	var restored := make(saved)
	check(restored.game.phase == "write" and restored.game.name == "久别的朋友" and is_equal_approx(restored.game.typed, r.game.typed), "mid-handwriting checkpoint restores name and strokes")
	r.free();r = restored
	await shot(r,"01-writing")
	advance(r, 12)
	check(r.game.phase == "written", "handwriting finishes on the paper")
	r.game.input("tap", Vector2(180,580));advance(r, 1.4)
	check(r.game.phase == "seal", "folded letter enters the sealing phase")
	r.game.input("down",Vector2(10,10));advance(r,1.2)
	check(r.game.phase == "seal" and r.game.hold == 0, "pressing away from wax cannot seal")
	r.game.input("down",Vector2(180,337));advance(r,0.45)
	r.game.input("up",Vector2(180,337))
	check(r.game.phase == "seal" and r.game.hold == 0, "short hold cannot complete seal")
	r.game.input("down",Vector2(180,337));advance(r,1.1)
	check(r.game.phase == "stamped", "one-second wax press seals")
	advance(r,1.4)
	await shot(r,"02-sealed")
	r.game.input("tap",Vector2(180,580));advance(r,1.9)
	check(r.game.phase == "receive", "letter is sent before recipient receives it")
	await shot(r,"03-received")
	r.game.input("tap",Vector2(180,337))
	check(r.game.phase == "receive", "tap alone cannot open the envelope")
	r.game.input("down",Vector2(80,280));r.game.input("move",Vector2(140,280));r.game.input("up",Vector2(140,280))
	check(r.game.phase == "receive" and r.game.open_progress == 0, "partial tear can be retried")
	r.game.input("down",Vector2(80,280));r.game.input("move",Vector2(240,280));advance(r,0.9)
	check(r.game.phase == "read_received", "opening reveals the addressed paper")
	advance(r,0.6);r.game.input("tap",Vector2(180,580))
	check(r.game.phase == "look", "avatar selection occurs only after opening")
	r.game.input("tap",r.game._look_rect(6).get_center());r.game.input("tap",Vector2(180,580))
	check(r.game.phase == "welcome", "chosen avatar reaches the couple welcome")
	await shot(r,"04-welcome")
	advance(r,0.7);r.game.input("tap",Vector2(180,580));advance(r,0.1)
	check(r.mode == "choice" and r.result == {"name":"久别的朋友","look":"07"}, "both existing destinations receive the chosen identity")
	check(r.choice_to == ["res://hongyuan/world_entry.tscn","res://hongyuan/village_entry.tscn"], "world exits unchanged")
	await shot(r,"05-exits")
	r.free()
	print("FAILURES ",failures)
	quit(failures)
