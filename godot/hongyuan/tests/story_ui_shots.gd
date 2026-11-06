extends SceneTree
## UI regression through actual render; only moves to named developer checkpoints.
class Harness extends "res://hongyuan/player.gd":
	func _save() -> void: pass
var p
var failures := 0
var out := "user://story-ui"
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
func shot(name: String) -> Image:
	p.stage.queue_redraw()
	if p.runner: p.runner.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image.get_size() == Vector2i(360, 640), "Native 360x640 " + name)
	image.save_png(out.path_join(name + ".png"))
	return image
func tap(pos: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventScreenTouch.new()
		e.index = 0
		e.position = p.stage.get_global_transform() * pos
		e.pressed = pressed
		root.push_input(e, true)
func run() -> void:
	p = Harness.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(p)
	await process_frame
	p.set_process(false)
	p._enter_step(p.step_indices["shanghai/chat_ayu"])
	await create_timer(0.3).timeout
	check(p.stage.chat_rows.size() == 4, "All four original chat messages remain")
	for row: Dictionary in p.stage.chat_rows:
		check(row.visible and p.stage.phone_screen_rect().encloses(row.bubble), "Chat message stays within iPhone screen")
	await shot("01-iphone-group")
	p._enter_step(p.step_indices["chengdu/chengdu_return"])
	await shot("02-world-narration")
	p._enter_step(p.step_indices["shanghai/line_1"])
	await shot("03-world-dialogue")
	p._enter_step(p.step_indices["call/night_call"])
	var r = p.runner
	r.set_process(false)
	while r.mode != "game":
		if r.mode == "go": r._trigger(r.go_id)
		else: r._next()
	await process_frame
	await shot("04-iphone-incoming")
	tap(r.game._accept_rect().get_center())
	check(r.game.phase == "talk", "Moved iPhone accept button receives viewport touch")
	r.game.reveal = r.game._line_text().length()
	var narration := await shot("05-call-single-person-narration")
	r.game.li = 3
	r.game.reveal = r.game._line_text().length()
	var dialogue := await shot("06-call-two-person-dialogue")
	check(narration.get_pixel(24, 580).get_luminance() < 0.15 and dialogue.get_pixel(24, 580).get_luminance() > 0.7, "Narration and dialogue render visibly distinct dark/light panels")
	r.game.phase = "reply"
	r.game.li = 6
	r.game.t = 0.3
	r.game.reveal = r.game._line_text().length()
	tap(r.game._speaker_rect().get_center())
	check(r.game.speaker_on and r.game.li == 7, "Speaker action still receives viewport touch")
	p._enter_step(p.step_indices["hongkong/hk"])
	r = p.runner
	r.set_process(false)
	while r.mode != "game":
		if r.mode == "go": r._trigger(r.go_id)
		else: r._next()
	await process_frame
	await shot("07-iphone-offer")
	tap(r.game._row().get_center())
	check(r.game.phase == "open", "Offer row still opens by viewport touch")
	print("FAILURES ", failures)
	p.queue_free()
	await process_frame
	quit(failures)
