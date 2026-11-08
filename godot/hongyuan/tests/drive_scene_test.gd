extends SceneTree
## 第一章驾驶小游戏（games/drive.gd，scene 形式）：用真实触摸事件验证
## 点开始 → 左右滑换车道 → 按住刹车、松手前停进右边车位 → 10 秒后出现「下一步」。
class Harness extends "res://hongyuan/player.gd":
	func _save() -> void: pass
var p
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: print("PASS ", label)
	else:
		failures += 1
		push_error(label)
func touch(point: Vector2, pressed: bool, index := 0) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.pressed = pressed
	e.position = p.stage.get_global_transform() * point
	root.push_input(e, true)
func drag(point: Vector2, rel: Vector2, index := 0) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = p.stage.get_global_transform() * point
	e.relative = rel
	root.push_input(e, true)
func tick(seconds: float) -> void:
	for i in range(roundi(seconds / 0.05)): p.runner._process(0.05)
	await process_frame
func run() -> void:
	root.size = Vector2i(360, 640)
	root.content_scale_size = Vector2i(360, 640)
	await process_frame
	p = Harness.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(p)
	await process_frame
	p._set_paused(false)
	p._enter_step(p.step_indices["shanghai/drive"])
	p.set_process(false)
	var r = p.runner
	r.set_process(false)
	await process_frame
	while r.mode != "game": r._next()
	var g = r.game
	# 任务卡已经确认过一次，开车不再要第二次「出发」
	check(g.phase == "drive", "Driving begins right after the goal card")
	await tick(0.5)
	# 向右滑一道，再向左滑回
	check(g.lane == 1, "Starts in the middle lane")
	touch(Vector2(180, 300), true)
	drag(Vector2(220, 300), Vector2(40, 0))
	touch(Vector2(220, 300), false)
	check(g.lane == 2, "Swipe right changes to the right lane")
	await tick(0.8)
	touch(Vector2(220, 300), true)
	drag(Vector2(160, 300), Vector2(-60, 0))
	touch(Vector2(160, 300), false)
	check(g.lane == 1, "Swipe left changes back one lane")
	drag(Vector2(160, 300), Vector2(-60, 0))
	check(g.lane == 1, "Drag without touching down does not change lane")
	# 开到停车阶段（快进里程，保证滑动换道逻辑仍有效）
	g.scroll = g.LENGTH - 5.0
	await tick(0.5)
	check(g.phase == "park" and g.lane == 2, "Road ends at the parking lot on the right lane")
	# 车位开到附近再按住，就自动停进去。入位之后才松手。
	var guard := 0
	while g.bay_y < g.CAR_Y - 280.0 and guard < 400:
		await tick(0.05)
		guard += 1
	check(g.phase == "park", "Without braking the car keeps rolling toward the bay")
	touch(Vector2(180, 400), true)
	check(g.holding, "Touch down in park phase starts braking")
	guard = 0
	while g.phase == "park" and guard < 400:
		await tick(0.05)
		guard += 1
	check(g.phase == "in", "Holding the brake parks into the bay before release (guard=%d)" % guard)
	touch(Vector2(180, 400), false)
	# 入位后收尾，场景前进；10 秒后出现「下一步」
	for i in range(60):
		if not is_instance_valid(r) or p.shot.id != "drive": break
		await tick(0.05)
	check(p.shot.id != "drive", "Parked drive hands control back to the story")
	p._enter_step(p.step_indices["shanghai/drive"])
	r = p.runner
	r.set_process(false)
	await process_frame
	while r.mode != "game": r._next()
	g = r.game
	check(not r._skip_visible(), "Next button is hidden at first")
	await tick(10.5)
	check(r._skip_visible(), "Next button appears after 10 seconds")
	# 车位还远就按住：车不能原地停死，要继续开，车位一靠近自己停进去（不用松手再按）。
	touch(Vector2(180, 582), true)
	touch(Vector2(180, 582), false)
	g.scroll = g.LENGTH - 5.0
	await tick(0.2)
	check(g.phase == "park" and g.bay_y < g.CAR_Y - 300.0, "Early hold: bay still far")
	touch(Vector2(180, 400), true)
	await tick(0.5)
	check(g.speed > 30.0, "Early hold keeps the car rolling (speed=%d)" % int(g.speed))
	guard = 0
	while g.phase == "park" and guard < 400:
		await tick(0.05)
		guard += 1
	check(g.phase in ["in", "done"], "Early hold still parks once the bay arrives (guard=%d)" % guard)
	touch(Vector2(180, 400), false)
	print("FAILURES ", failures)
	quit(failures)
