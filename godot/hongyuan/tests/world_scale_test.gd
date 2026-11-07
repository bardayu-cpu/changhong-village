extends SceneTree
class Harness extends "res://hongyuan/player.gd":
	func _save() -> void: pass
var p
var failures := 0
var out := "user://world-scale"
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func tap(at: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventScreenTouch.new()
		e.index = 0
		e.position = p.stage.get_global_transform() * at
		e.pressed = pressed
		root.push_input(e, true)
func tick(sec: float) -> void:
	for i in range(roundi(sec / 0.05)): p.runner._process(0.05)
	await process_frame
func shot(name: String) -> void:
	if p.runner: p.runner.queue_redraw()
	p.stage.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	check(img.get_size() == Vector2i(360, 640), "360x640 " + name)
	img.save_png(out.path_join(name + ".png"))
func enter(step: String, key: String, value: String):
	p._enter_step(p.step_indices[step])
	var r = p.runner
	r.set_process(false)
	for i in range(r.beats.size()):
		if str(r.beats[i].get(key, "")) == value:
			r.begin(i)
			return r
	check(false, "Missing beat " + value)
	return r
func run() -> void:
	root.size = Vector2i(360, 640)
	root.content_scale_size = Vector2i(360, 640)
	await process_frame
	p = Harness.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(p)
	await process_frame
	p.set_process(false)
	p._enter_step(p.step_indices["shanghai/board_car"])
	check(p.stage.person_height_at(420) < p.stage.person_height_at(550), "Old Shanghai renderer scales the same person smoothly with floor depth")
	await shot("01-shanghai-street")
	p._enter_step(p.step_indices["shanghai/line_1"])
	check(p.stage.person_height_at(410) < 65, "Parking people are calibrated to the smaller distant cars")
	await shot("02-shanghai-parking-dialogue")
	p._enter_step(p.step_indices["chengdu/chengdu_walk"])
	await shot("03-chengdu")
	var r = enter("call/night_call", "go", "phone")
	await shot("04-room")
	r = enter("call/night_call", "go", "cake")
	r.feet = Vector2(94, 440)
	tap(r._icon_rect("cake").get_center())
	r.reveal = r.say_text.length()
	check(r._player_frame().ends_with("toretto_gifts_r2.png"), "Inspecting cake uses the contextual lowered-hand pose")
	var office_rect: Rect2 = r.person_rect(r._player_frame(), r.feet)
	check(office_rect.size.y > 210 and office_rect.size.y < 230 and office_rect.end.y == r.feet.y, "Office body matches desk scale and feet remain anchored")
	await shot("05-office-proportion-and-pose")
	r = enter("shizuoka/pier", "game", "fishing")
	check(r.game._tip().y > r.person_rect(r._player_frame(), r.feet).position.y, "Fishing line remains attached below the scaled character top")
	await shot("06-pier")
	r = enter("shizuoka/pier", "go", "seat")
	# #46 起船上对白搬进了温泉小游戏：坐下之后先进温泉，对白第一句仍是 A4-2a。
	var onsen_beat := {}
	for b: Dictionary in r.beats:
		if b.get("game", "") == "onsen":
			onsen_beat = b
	check(r.mode == "go" and not onsen_beat.is_empty() and onsen_beat.lines[0].get("say", "") == "A4-2a", "Couple sit together before their first marriage conversation line")
	await shot("07-boat-approach")
	tap(Vector2(220, 440))
	await tick(3.0)
	check(r.mode == "go" and r._near_hotspot() == "seat", "Walking to the correctly scaled bench still requires explicit sit interaction")
	tap(r._icon_rect("seat").get_center())
	r.reveal = r.say_text.length()
	var ayu_rect: Rect2 = r.person_rect(r._player_frame(), r.feet)
	var t_feet: Vector2 = r._v(r.actors.toretto.at)
	var t_rect: Rect2 = r.person_rect(r.actors.toretto.tex, t_feet)
	check(r.pose == "sit" and absf(ayu_rect.size.y - t_rect.size.y) < 0.01 and r.feet.y == t_feet.y, "Two seated bodies share seat depth and height instead of a small man and large standing woman")
	check(absf(r._speaker_anchor("toretto").y - t_rect.position.y) < 0.01 and absf(r._speaker_anchor("ayu").y - ayu_rect.position.y) < 0.01, "Both head bubbles use the actual drawn seated silhouette")
	await shot("08-boat-seated-dialogue")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(r.snapshot()))
	var other = r.get_script().new()
	other.setup(r.spec, p.copy, {})
	root.add_child(other)
	other.set_process(false)
	other.begin(saved.beat)
	other.restore(saved)
	check(other.person_rect(other._player_frame(), other.feet) == ayu_rect, "JSON restore retains the same seated world size and foot position")
	other.free()
	r = enter("hainan/wanning", "go", "stall")
	await shot("09-pool")
	r = enter("hainan/wanning", "say", "A5-3a")
	r.reveal = r.say_text.length()
	var ayu_h: float = r.person_rect(r._player_frame(), r.feet).size.y
	var t_h: float = r.person_rect(r.actors.toretto.tex, r._v(r.actors.toretto.at)).size.y
	check(absf(ayu_h - t_h) < 0.01 and r.actors.toretto.tex.ends_with("toretto_back_r2.png"), "208px and 1599px source images produce the same world height and both look toward the sea")
	await shot("10-beach-watching")
	r = enter("hongkong/hk", "go", "exit")
	r.feet = Vector2(180, 590)
	var near_height: float = r.person_rect(r._player_frame(), r.feet).size.y
	await shot("11-airport-near")
	tap(Vector2(270, 410))
	await tick(3.0)
	var far_height: float = r.person_rect(r._player_frame(), r.feet).size.y
	check(near_height > far_height * 1.4 and far_height > 95 and far_height < 110, "Airport walking recedes from a foreground adult to door-calibrated depth")
	var standing: Rect2 = r.person_rect("ayu_idle.png", r.feet)
	var walking: Rect2 = r.person_rect("w2/common/ayu_walk_side_2.png", r.feet)
	check(standing.end.y == walking.end.y and standing.size.y == walking.size.y, "Idle and walking frames never change foot baseline or body height")
	await shot("12-airport-far")
	r = enter("finale/finale", "game", "seat")
	await tick(4.0)
	var original_height: float = r.person_height
	await shot("13-banquet-orthographic")
	check(r.person_height == original_height, "Banquet drawing no longer mutates the scene's shared character height")
	print("FAILURES ", failures)
	p.queue_free()
	await process_frame
	quit(failures)
