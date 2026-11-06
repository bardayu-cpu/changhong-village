extends SceneTree
const Runner = preload("res://hongyuan/scene_runner.gd")
var failures := 0
var copy: Dictionary
var spec: Dictionary

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1

func make_runner(start: int, saved := {}) -> Control:
	var r = Runner.new()
	r.setup(spec, copy, {})
	root.add_child(r)
	r.set_process(false)
	r.begin(start)
	if not saved.is_empty(): r.restore(saved)
	return r

func index_of(key: String, value: String) -> int:
	for i in range(spec.beats.size()):
		if str(spec.beats[i].get(key, "")) == value: return i
	return -1

func tick(r, seconds: float) -> void:
	for i in range(int(seconds / 0.05)): r._process(0.05)

func touch(r, at: Vector2, pressed: bool, canceled := false, finger := 0) -> void:
	var event := InputEventScreenTouch.new()
	event.position = at
	event.index = finger
	event.pressed = pressed
	event.canceled = canceled
	r._gui_input(event)

func tap(r, at: Vector2) -> void:
	touch(r, at, true)
	touch(r, at, false)

func run() -> void:
	copy = JSON.parse_string(FileAccess.get_file_as_string("res://hongyuan/copy.json"))
	spec = JSON.parse_string(FileAccess.get_file_as_string("res://hongyuan/chapters/call.json")).steps[0].scene
	var office := index_of("go", "cake")
	var r = make_runner(office)
	check(r.player_role == "toretto" and r.player_visible and r.feet == Vector2(60, 610), "Dawn switches the controllable role to Toretto")
	check(r.bg_offset == Vector2(0, -140) and r._clamp(Vector2(180, 300)).y >= 540, "Walkable floor is below the desk, never on its surface")
	tap(r, Vector2(300, 400))
	check(r.bi == office, "Distant desk phone does not skip approach")
	tap(r, Vector2(180, 548)); tick(r, 2.0)
	check(r._near_hotspot() == "cake" and r.bi == office, "Walking arrives without auto-activating desk")
	tap(r, r._hotspot_rect("flowers").get_center())
	check(r.go_id == "cake", "Later flower tap cannot skip cake")
	tap(r, r._hotspot_rect("cake").get_center())
	check(r.say_text == copy["A3-2j"], "Cake immediately triggers A3-2j")
	r._next()
	check(r.go_id == "flowers", "Next hotspot is blue flowers")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(r.snapshot()))
	var resumed = make_runner(int(saved.beat), saved)
	check(resumed.player_role == "toretto" and resumed.go_id == "flowers" and resumed.feet == r.feet,
		"JSON reload preserves Toretto, feet and completed cake inspection")
	tap(resumed, resumed._hotspot_rect("flowers").get_center())
	check(resumed.say_text == copy["A3-2k"], "Blue flowers immediately trigger A3-2k")
	resumed._next()
	check(resumed.go_id == "desk_phone" and resumed.mode == "go", "A3-2k waits for an explicit phone action")
	tap(resumed, resumed._hotspot_rect("cake").get_center())
	check(resumed.mode == "go", "Wrong object cannot send the message")
	tap(resumed, resumed._hotspot_rect("desk_phone").get_center())
	check(resumed.mode == "game" and resumed.game.lines[0].say == "A3-2l", "Phone opens the original chat")
	var chat = resumed.game
	for i in range(5):
		check(chat.li == i and chat.lines[i].who == ["toretto", "ayu", "toretto", "toretto", "ayu"][i], "Chat preserves sender and order for message %d" % i)
		tick(resumed, 0.2); tap(resumed, Vector2(180, 400)); tick(resumed, 0.05)
	check(resumed.player_role == "ayu" and resumed.say_text == copy["A3-2q"], "Finishing chat resets to Ayu and original montage")
	r.free(); resumed.free()

	var burden := index_of("game", "burden")
	check(str(spec.beats[burden - 3].get("narrate")) == "A3-2t" and str(spec.beats[burden - 2].get("narrate")) == "A3-P1"
		and str(spec.beats[burden - 1].get("button")) == "A3-B2" and str(spec.beats[burden + 1].get("narrate")) == "A3-3a"
		and str(spec.beats[burden + 2].get("narrate")) == "A3-3b", "Burden is between 2t → P1 → B2 and 3a/3b")
	r = make_runner(burden - 1)
	tick(r, 2.0)
	check(r.mode == "button" and r.player_role == "ayu", "Help button is manual and Toretto role is reset")
	tap(r, r.button_rect.get_center())
	var g = r.game
	check(g.care_labels == ["Toretto", "晚安", "电话"] and g.pressure_labels == ["周报", "会议", "加班", "家里电话", "工作压力", "相处的摩擦"], "All nine bubble labels exactly match the specified original copy")
	tick(r, 35.0)
	check(g.phase == "helping" and g.care_count == 0 and g.idle_t >= 8, "Idle never completes or fails; eight-second hint is armed")
	var distance_ok := true
	for pos: Vector2 in g.positions: distance_ok = distance_ok and pos.distance_to(g.CENTER) >= 98.9
	check(distance_ok and g.positions != g.PRESSURE, "Pressure approaches each second but stops clear of Ayu")
	tap(r, g.TARGET.get_center())
	check(g.care_count == 0, "Tapping Ayu alone does not create care")
	touch(r, g.CARE[0], true); touch(r, Vector2(8, 8), false)
	check(not g.dragging and g.care_count == 0, "Missed drop returns freely without failure")
	touch(r, g.CARE[0], true); touch(r, g.TARGET.get_center(), false, true)
	check(not g.dragging and g.care_count == 0, "Canceled touch does not deliver care")
	touch(r, g.CARE[1], true)
	touch(r, g.CARE[2], true, false, 1); touch(r, g.TARGET.get_center(), false, false, 1)
	check(g.dragging and g.care_count == 0, "Second finger cannot deliver or cancel first finger")
	var nearest: int = g._nearest()
	touch(r, g.TARGET.get_center(), false)
	check(g.removed[nearest] and g.care_count == 1 and g.pop_t[nearest] > 0 and g.hearts.size() == 1,
		"Dropping on Ayu removes the nearest pressure with immediate pop and heart")
	tick(r, 0.5)
	check(g.pop_t[nearest] == 0, "Removed pressure finishes shrinking in 0.4 seconds")
	touch(r, g.CARE[0], true)
	saved = JSON.parse_string(JSON.stringify(r.snapshot()))
	resumed = make_runner(int(saved.beat), saved)
	check(resumed.game.removed == g.removed and resumed.game.care_count == 1 and resumed.game.hearts.size() == 1
		and not resumed.game.dragging, "Reload preserves removed bubbles and hearts without a held drag")
	r.suspend_input(); check(not g.dragging, "Background suspension clears drag")
	var restored = resumed.game
	for i in range(6):
		if restored.removed[i]: continue
		touch(resumed, restored.CARE[0], true); touch(resumed, restored.positions[i], false)
	check(restored.care_count == 6 and restored.hearts.size() == 6, "Unlimited copies of one care bubble remove all six targets")
	tick(resumed, 0.45)
	check(restored.phase == "relaxed" and resumed.bi == burden, "All six gone starts relaxed pose")
	tick(resumed, 0.5); check(resumed.bi == burden, "Relaxed pose holds before returning to story")
	tick(resumed, 0.6)
	check(resumed.bi == burden + 1 and resumed.say_text == copy["A3-3a"], "Relaxed pause completes into original A3-3a")
	r.free(); resumed.free()
	print("FAILURES ", failures)
	quit(failures)
