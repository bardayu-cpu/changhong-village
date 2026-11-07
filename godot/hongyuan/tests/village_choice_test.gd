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
	p._enter_step(p.step_indices["finale/finale"])
	await wait(0.5)
	var r = p.runner
	var guard := 0
	r.result = {"name": "测试", "look": "01"}
	while r.mode != "choice" and guard < 300:
		guard += 1
		r._next()
		await wait(0.02)
	print("mode=", r.mode, " bi=", r.bi)
	await wait(0.6)
	touch(Vector2(180, 336), true); await wait(0.08); touch(Vector2(180, 336), false)
	await wait(0.3)
	print("after village tap note_t=", r.choice_note_t, " note=", r.choice_note, " scene=", get_current_scene())
	quit(0)
