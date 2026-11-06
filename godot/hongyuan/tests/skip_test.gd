extends SceneTree
## 用真实触摸事件（经 viewport）玩静冈钓鱼：按住蓄力、松手、等「收！」、点它。

class Harness extends "res://hongyuan/player.gd":
	func _save() -> void:
		pass

var p

func _initialize() -> void:
	root.size = Vector2i(540, 960)
	call_deferred("run")

func touch(pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = pos * 1.5
	e.pressed = pressed
	root.push_input(e)

func wait(sec: float) -> void:
	var end := Time.get_ticks_msec() + int(sec * 1000)
	while Time.get_ticks_msec() < end:
		await process_frame

func run() -> void:
	p = Harness.new()
	p.size = Vector2(540, 960)
	root.add_child(p)
	await wait(0.3)
	p._enter_step(p.step_indices["shizuoka/pier"])
	await wait(0.5)
	var r = p.runner
	var guard := 0
	while r.mode != "game" and guard < 200:
		guard += 1
		if r.mode == "go":
			r._trigger(r.go_id)
		else:
			r._next()
		await wait(0.05)
	print("mode=", r.mode, " game=", r.beats[r.bi].get("game", ""))
	var bi0: int = r.bi
	await wait(10.5)
	print("skip visible=", r._skip_visible())
	touch(Vector2(308, 110), true); await wait(0.08); touch(Vector2(308, 110), false)
	await wait(0.3)
	print("SKIP ", "PASS" if r.bi > bi0 else "FAIL", " mode=", r.mode)
	quit(0)
