extends SceneTree
## Feed viewport events through Control hit testing, never call gameplay handlers directly.
class Harness extends "res://hongyuan/player.gd":
	func _save() -> void: pass
var p
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
	else: print("PASS ",label)
func send(event: InputEvent, point: Vector2) -> void:
	event.position = p.stage.get_global_transform() * point
	root.push_input(event, true)
func button(point: Vector2, pressed: bool, touch := false, index := 0, cancelled := false) -> void:
	var e: InputEvent
	if touch:
		e = InputEventScreenTouch.new()
		e.index = index
		e.canceled = cancelled
	else:
		e = InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	send(e, point)
func motion(point: Vector2, touch := false, index := 0) -> void:
	var e: InputEvent = InputEventScreenDrag.new() if touch else InputEventMouseMotion.new()
	if touch:
		e.index = index
		e.relative = Vector2(36,0)
	send(e, point)
func settle(sec := 0.1) -> void:
	await create_timer(sec).timeout
func run() -> void:
	root.size = Vector2i(360,640)
	p = Harness.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(p)
	await settle()
	p._set_paused(false)
	for touch in [false, true]:
		p._enter_step(p.step_indices["shanghai/board_car"])
		await settle()
		button(Vector2(263,445),true,touch)
		button(Vector2(263,445),false,touch)
		await settle(1.5)
		check(p.stage.player_feet.x>250, "Viewport ground tap moves, touch="+str(touch))
		check(p.shot.id=="board_car", "Arrival needs interaction, touch="+str(touch))
		button(Vector2(64,558),true,touch)
		motion(Vector2(28,558),touch)
		await settle(0.4)
		button(Vector2(28,558),false,touch)
		check(p.stage.player_feet.x<230 and p.stick==Vector2.ZERO, "Viewport joystick moves/releases, touch="+str(touch))
	p._enter_step(p.step_indices["shanghai/board_car"])
	button(Vector2(64,558),true,true,2)
	button(Vector2(300,440),true,true,3)
	motion(Vector2(100,558),true,3)
	check(p.stick==Vector2.ZERO, "Second finger cannot steal joystick")
	motion(Vector2(100,558),true,2)
	button(Vector2(100,558),false,true,2,true)
	check(p.stick==Vector2.ZERO and not p.moving, "Touch cancellation releases joystick")
	p._enter_step(p.step_indices["call/night_call"])
	await settle()
	while p.runner.mode!="go": p.runner._next()
	var r = p.runner
	await settle()
	var before: Vector2 = r.feet
	button(Vector2(64,558),true,true)
	motion(Vector2(100,558),true)
	await settle(0.3)
	button(Vector2(100,558),false,true)
	check(r.feet.x>before.x and r.stick==Vector2.ZERO, "Scene runner receives direct touch GUI events")
	p._set_paused(true)
	check(not r.is_processing() and not r.down, "Pause stops scene and clears gesture")
	p._set_paused(false)
	check(r.is_processing(), "Resume restarts scene")
	print("FAILURES ",failures)
	p.queue_free()
	await process_frame
	quit(failures)
