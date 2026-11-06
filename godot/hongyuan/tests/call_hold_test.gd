extends SceneTree
const Runner = preload("res://hongyuan/scene_runner.gd")
var failures := 0
var copy: Dictionary
var spec: Dictionary

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func make_runner(saved := {}) -> Control:
	var r = Runner.new()
	r.setup(spec, copy, {}); root.add_child(r); r.set_process(false); r.begin()
	if not saved.is_empty(): r.restore(saved)
	return r
func tick(r, seconds: float) -> void:
	for i in range(roundi(seconds / 0.05)): r._process(0.05)

func run() -> void:
	copy = JSON.parse_string(FileAccess.get_file_as_string("res://hongyuan/copy.json"))
	var chapter: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://hongyuan/chapters/call.json"))
	var call_beat: Dictionary
	for beat: Dictionary in chapter.steps[0].scene.beats:
		if beat.get("game", "") == "call": call_beat = beat
	spec = {"beats": [call_beat, {"say": "A3-2i"}]}
	var r = make_runner()
	var g = r.game
	g.input("down", Vector2(5, 5)); tick(r, 1.0)
	check(g.phase == "ring", "Ringing needs manual accept")
	g.input("up", Vector2(5, 5)); g.input("tap", g._accept_rect().get_center()); tick(r, 1.0)
	check(g.phase == "talk" and g.reveal == 0.0, "Accepted call waits for hold")
	g.input("tap", Vector2(180, 400)); tick(r, 0.5)
	check(g.li == 0 and g.reveal == 0.0, "Tap cannot skip the listening sentences")
	g.input("down", Vector2(5, 5)); tick(r, 0.5)
	check(g.reveal > 5 and g.reveal < 7 and g.li == 0, "Anywhere on screen reveals about 12 characters per second")
	g.input("up", Vector2(5, 5))
	var frozen: float = g.reveal
	var elapsed: float = g.t
	tick(r, 10.0)
	check(g.reveal == frozen and g.t == elapsed and g.hint_t >= 9.9, "Release freezes text and line timer; idle hint is armed at ten seconds")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(r.snapshot()))
	var resumed = make_runner(saved)
	check(resumed.game.li == g.li and resumed.game.reveal == 0.0 and not resumed.game.holding,
		"Refresh restarts the current sentence without restoring a press")
	var legacy := saved.duplicate(true)
	legacy.game.li = 5
	var migrated = make_runner(legacy)
	check(migrated.game.phase == "reply" and migrated.game.li == 5, "Older call checkpoint in the reply half migrates to tap mode")
	migrated.free()
	g.input("down", Vector2(355, 630)); tick(r, 0.25)
	check(g.reveal > frozen, "A second hold continues without losing characters")
	r.suspend_input()
	check(not g.holding, "Background cancellation releases listening")
	g.input("down", Vector2(355, 630))
	for i in range(1000):
		if g.phase == "birthday": break
		r._process(0.05)
	check(g.li == 3 and g.reveal == copy["A3-2d"].length() and g.birthday_flash > 0.0
		and g.birthday_flash <= 0.3 and r.pose == "surprised", "Completed birthday line flashes once and switches Ayu pose")
	tick(r, 0.35)
	check(g.birthday_flash == 0.0 and g.phase == "birthday", "White flash lasts 0.3 seconds")
	tick(r, 0.35)
	check(g.phase == "reply" and g.li == 4, "A3-2e begins without another hold")
	g.input("down", Vector2(30, 30)); tick(r, 5.0)
	check(g.li == 4, "Holding cannot auto-advance reply sentences")
	g.input("up", Vector2(30, 30))
	for expected in range(5, 7):
		g.input("tap", Vector2(30, 30)); tick(r, 0.2)
		check(g.li == expected and g.phase == "reply", "Single tap advances to reply index %d" % expected)
	g.input("tap", Vector2(30, 30)); tick(r, 0.3)
	check(g.li == 6 and not g.speaker_on, "After three replies ordinary continue cannot skip speaker action")
	var before_speaker = make_runner(JSON.parse_string(JSON.stringify(r.snapshot())))
	check(before_speaker.game.li == 6 and not before_speaker.game.speaker_on, "Reload before speaker action still requires the icon")
	before_speaker.free()
	g.input("tap", g._speaker_rect().get_center()); tick(r, 0.2)
	check(g.li == 7 and g.speaker_on, "Speaker click lights the speaker and reveals A3-2h")
	var after_speaker = make_runner(JSON.parse_string(JSON.stringify(r.snapshot())))
	check(after_speaker.game.li == 7 and after_speaker.game.speaker_on, "Reload after speaker action preserves visible on state")
	after_speaker.free()
	g.input("tap", Vector2(30, 30))
	check(g.phase == "hangup" and r.bi == 0, "Dismissing A3-2h starts automatic hangup")
	tick(r, 0.3)
	check(r.bi == 0, "Hangup remains visible during its animation")
	tick(r, 0.35)
	check(r.bi == 1 and r.say_text == copy["A3-2i"], "Hangup finishes in 0.6 seconds without a button")
	r.free(); resumed.free()
	print("FAILURES ", failures); quit(failures)
