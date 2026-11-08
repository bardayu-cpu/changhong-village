extends SceneTree
## P0 回归：停车不操作也能自己停完；街边点车能自己走过去上车。

class Harness extends "res://hongyuan/player.gd":
	func _save() -> void:
		pass

var fails := 0


func _initialize() -> void:
	root.size = Vector2i(540, 960)
	call_deferred("run")


func check(ok: bool, msg: String) -> void:
	print(("PASS " if ok else "FAIL ") + msg)
	if not ok:
		fails += 1


func run() -> void:
	var p = Harness.new()
	p.size = Vector2(540, 960)
	root.add_child(p)
	for i in range(3):
		await process_frame
	# 1) 停车：开到终点后完全不碰屏幕，几秒内要自己停进车位
	p.shot = {}  # 跳过换场淡出，测试里同步进场
	p._enter_step(p.step_indices["shanghai/drive"])
	for i in range(3):
		await process_frame
	var r = p.runner
	var g = r.game
	g.input("tap", Vector2(180, 582))
	g.scroll = g.LENGTH - 5.0
	var sid: String = p.shot.fullId
	var t := 0.0
	while t < 20.0 and p.shot.fullId == sid:
		if p.runner and is_instance_valid(p.runner):
			p.runner._process(0.05)
		await process_frame
		t += 0.05
	check(p.shot.fullId != sid, "停车不操作 %.1f 秒内自动入位" % t)
	# 2) 停车：点一下就停
	p.shot = {}  # 跳过换场淡出，测试里同步进场
	p._enter_step(p.step_indices["shanghai/drive"])
	for i in range(3):
		await process_frame
	g = p.runner.game
	g.input("tap", Vector2(180, 582))
	g.scroll = g.LENGTH - 5.0
	p.runner._process(0.05)
	for i in range(30):
		p.runner._process(0.05)
	g.input("tap", Vector2(180, 400))
	t = 0.0
	while t < 3.0 and g.phase == "park":
		p.runner._process(0.05)
		t += 0.05
	check(g.phase != "park", "停车点一下 %.1f 秒内入位（bay_y=%.0f）" % [t, g.bay_y])
	# 3) 街边：点车本身（不在可走区域内），阿鱼自己走过去并上车
	p.shot = {}  # 跳过换场淡出，测试里同步进场
	p._enter_step(p.step_indices["shanghai/board_car"])
	for i in range(3):
		await process_frame
	sid = p.shot.fullId
	p._handle_tap(Vector2(272, 380))
	t = 0.0
	while t < 10.0 and p.shot.fullId == sid:
		p._move(0.05)
		await process_frame
		t += 0.05
	check(p.shot.fullId != sid, "街边点车 %.1f 秒后上车（现在 %s）" % [t, p.shot.fullId])
	quit(1 if fails > 0 else 0)
