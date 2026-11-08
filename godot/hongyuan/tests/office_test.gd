extends SceneTree
class Harness extends "res://hongyuan/player.gd":
	func _save() -> void: pass
var p
var failures := 0
var out := "user://office"
func _initialize() -> void:
	root.size = Vector2i(360, 640)
	root.content_scale_size = Vector2i(360, 640)
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func tap(point: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventScreenTouch.new()
		e.index = 0
		e.position = p.stage.get_global_transform() * point
		e.pressed = pressed
		root.push_input(e, true)
func drag(from: Vector2, to: Vector2) -> void:
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.position = p.stage.get_global_transform() * from
	press.pressed = true
	root.push_input(press, true)
	var motion := InputEventScreenDrag.new()
	motion.index = 0
	motion.position = p.stage.get_global_transform() * to
	motion.relative = to - from
	root.push_input(motion, true)
	press = InputEventScreenTouch.new()
	press.index = 0
	press.position = p.stage.get_global_transform() * to
	press.pressed = false
	root.push_input(press, true)
func tick(sec: float) -> void:
	for i in range(roundi(sec / 0.05)): p.runner._process(0.05)
	await process_frame
func shot(name: String) -> void:
	p.runner.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	check(img.get_size() == Vector2i(360, 640), "360x640 " + name)
	img.save_png(out.path_join(name + ".png"))
func run() -> void:
	root.size = Vector2i(360, 640)
	root.content_scale_size = Vector2i(360, 640)
	await process_frame
	p = Harness.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(p)
	await process_frame
	p.set_process(false)
	p.shot = {}  # 跳过换场淡出，测试里同步进场
	p._enter_step(p.step_indices["call/night_call"])
	var r = p.runner
	r.set_process(false)
	var start := 0
	for i in range(r.beats.size()):
		if r.beats[i].get("narrate", "") == "A3-2i": start = i
	r.begin(start)
	r.reveal = r.say_text.length()
	check(r.player_role == "toretto" and r.player_visible and r.bg_fit and r.texture(r.bg) != null, "CBD office shows controllable Toretto and imported medium-shot background")
	await shot("01-cbd-office-arrival")
	await tick(0.3)
	tap(Vector2(180, 600))
	check(r.mode == "go" and r.go_id == "cake", "Cake is the first and only active hotspot")
	tap(r._icon_rect("flowers").get_center())
	check(r.go_id == "cake", "Future flower hotspot cannot skip the cake")
	tap(Vector2(94, 440))
	await tick(3.0)
	check(r.mode == "say" and r.say_who == "toretto" and r.beats[r.bi].say == "A3-2j", "Explicit cake interaction keeps Toretto's original line")
	r.reveal = r.say_text.length()
	await shot("02-toretto-cake-dialogue")
	await tick(0.3)
	tap(Vector2(180, 600))
	check(r.go_id == "flowers", "Blue flowers follow cake")
	tap(r._icon_rect("flowers").get_center())
	check(r.beats[r.bi].narrate == "A3-2k", "Flower narration is preserved")
	r.reveal = r.say_text.length()
	await tick(0.3)
	tap(Vector2(180, 600))
	check(r.go_id == "desk_phone", "Phone follows blue flowers")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(r.snapshot()))
	var other = r.get_script().new()
	other.setup(r.spec, p.copy, {})
	root.add_child(other)
	other.set_process(false)
	other.begin(saved.beat)
	other.restore(saved)
	check(other.player_role == "toretto" and other.go_id == "desk_phone" and other.feet == r.feet, "Refresh restores office role, desk location and sequence")
	other.free()
	tap(r._icon_rect("desk_phone").get_center())
	check(r.mode == "game" and r.game.lines.size() == 5, "Desk phone opens all five original messages")
	check(r.bg == "w2/call/bg_cbd_window_chat_r3.png" and not r.player_visible and r.actors.is_empty(), "Window phone scene has exactly one baked Toretto and no duplicate portrait/sprite")
	await tick(12.0)
	check(not r._skip_visible(), "Ten-second shortcut cannot discard locked chat lines")
	tap(Vector2(180, 618))
	check(r.game.li == 1 and r.game.reveal == 0, "Tap sends first message, Ayu reply begins separately")
	await tick(0.2)
	tap(Vector2(180, 618))
	check(r.game.li == 1 and r.game.reveal == r.game._current_text().length(), "Fast tap completes this reply without discarding it")
	await shot("03-window-wechat-first-reply")
	for i in range(2):
		tap(Vector2(180, 578))
		await tick(2.0)
	var message_index: int = r.game.li
	drag(Vector2(180, 480), Vector2(180, 560))
	check(r.game.chat_scroll > 0 and r.game.li == message_index, "Dragging chat reviews older messages without sending the next line")
	var message_saved: Dictionary = JSON.parse_string(JSON.stringify(r.snapshot()))
	other = r.get_script().new()
	other.setup(r.spec, p.copy, {})
	root.add_child(other)
	other.set_process(false)
	other.begin(message_saved.beat)
	other.restore(message_saved)
	check(other.game.li == r.game.li and other.game.chat_scroll == r.game.chat_scroll and other.game.reveal == r.game.reveal and not other.player_visible, "Refresh restores window shot, current message, reveal and history position")
	other.free()
	tap(Vector2(180, 618))
	check(r.game.chat_scroll == 0 and r.game.li == message_index, "Tap while reviewing returns to latest without advancing")
	tap(Vector2(180, 618))
	await tick(3.0)
	await shot("04-window-wechat-final-reply")
	var rows: Array = r.game._rows()
	var fit := true
	for row: Dictionary in rows:
		fit = fit and row.y >= 431 and row.y + 15 + row.height <= 606
	check(fit and rows.size() == 2, "Longest reply and preceding message fit below the character without covering his body")
	var ids: Array = []
	for line: Dictionary in r.game.lines: ids.append(line.say)
	check(ids == ["A3-2l", "A3-2m", "A3-2n", "A3-2o", "A3-2p"], "Original l-to-p message order is exact")
	tap(Vector2(180, 618))
	await tick(0.2)
	check(r.player_role == "ayu" and r.beats[r.bi].get("narrate", "") == "A3-2q", "Office returns to Ayu timeline after final message")
	print("FAILURES ", failures)
	p.queue_free()
	await process_frame
	quit(failures)
