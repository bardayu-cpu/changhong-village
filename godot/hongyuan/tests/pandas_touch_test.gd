extends SceneTree
## Native 360×640 render with viewport mouse/touch events; enters a developer checkpoint.
## Never writes the player's real save and never claims a full phone/Web playthrough.
class Harness extends "res://hongyuan/player.gd":
	func _save() -> void: pass
var p
var failures := 0
var out := "user://pandas"
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func button(point: Vector2, pressed: bool, touch := true, index := 0, cancelled := false) -> void:
	var event: InputEvent
	if touch:
		event = InputEventScreenTouch.new()
		event.index = index
		event.canceled = cancelled
	else:
		event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = p.stage.get_global_transform() * point
	root.push_input(event, true)
func tap(point: Vector2, touch := true) -> void:
	button(point, true, touch)
	button(point, false, touch)
func drag(point: Vector2, index := 0) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = p.stage.get_global_transform() * point
	event.relative = Vector2(36, 0)
	root.push_input(event, true)
func tick(seconds: float) -> void:
	for i in range(roundi(seconds / 0.05)): p.runner._process(0.05)
	await process_frame
func shot(name: String) -> void:
	p.runner.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	check(img.get_size() == Vector2i(360, 640), "Native 360x640 screenshot: " + name)
	img.save_png(out.path_join(name + ".png"))
func run() -> void:
	# 窗口尺寸要在初始化之后设置，否则会被项目的 540x960 覆盖，截图尺寸检查不过。
	root.size = Vector2i(360, 640)
	root.content_scale_size = Vector2i(360, 640)
	await process_frame
	p = Harness.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(p)
	await process_frame
	p._set_paused(false)
	p._enter_step(p.step_indices["chengdu/chengdu_walk"])
	p.set_process(false)
	var r = p.runner
	r.set_process(false)
	await process_frame
	var g = r.game
	await shot("01-six-pandas-hungry")
	var before: Vector2 = r.feet
	button(Vector2(62, 568), true, true, 2)
	button(Vector2(100, 568), true, true, 3)
	drag(Vector2(100, 568), 3)
	check(r.stick == Vector2.ZERO, "Second finger cannot steal panda joystick")
	drag(Vector2(26, 568), 2)
	await tick(0.4)
	button(Vector2(26, 568), false, true, 2, true)
	check(r.feet.x < before.x and r.stick == Vector2.ZERO and not r.moving, "Touch joystick moves and cancellation stops it")
	tap(g.BAMBOO, false)
	await tick(3.0)
	check(g._action() == "take" and not g.bamboo_held, "Mouse ground/object tap walks without taking")
	tap(g._action_rect().get_center())
	check(g.bamboo_held, "Viewport touch picks up bamboo")
	await shot("02-carrying-bamboo")
	p._set_paused(true)
	check(not r.is_processing() and not r.down and g.bamboo_held, "Background keeps bamboo and clears input")
	p._set_paused(false)
	r.set_process(false)
	p.set_process(false)
	for i in range(5):
		if not g.bamboo_held:
			tap(g.BAMBOO)
			await tick(3.0)
			tap(g._action_rect().get_center())
		tap(g.FEET[g.hungry] - Vector2(0, 25))
		await tick(3.0)
		check(g.fed.size() == i, "Viewport arrival needs explicit feed, round %d" % (i + 1))
		tap(g._action_rect().get_center())
		check(g.fed.size() == i + 1, "Viewport feed %d" % (i + 1))
		if i < 4: await tick(0.8)
	await shot("03-five-pandas-fed")
	await tick(1.3)
	await process_frame
	check(p.shot.id == "chengdu_ping", "Normal game completion reaches preserved group notification")
	p._enter_step(p.step_indices["chengdu/chengdu_walk"])
	r = p.runner
	r.set_process(false)
	await process_frame
	await tick(10.1)
	tap(r.SKIP_RECT.get_center())
	await process_frame
	await process_frame
	check(p.shot.id == "chengdu_ping", "Viewport next-step calls skip and only leaves this minigame")
	print("FAILURES ", failures)
	p.queue_free()
	await process_frame
	quit(failures)
