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
	r.setup(spec, copy, {})
	root.add_child(r)
	r.set_process(false)
	r.begin()
	if not saved.is_empty(): r.restore(saved)
	return r
func tick(r, seconds: float) -> void:
	for i in range(roundi(seconds / 0.05)): r._process(0.05)
func saved(r) -> Dictionary: return JSON.parse_string(JSON.stringify(r.snapshot()))
func walk_to(r, point: Vector2) -> void:
	r.game._walk_to(point)
	tick(r, 3.0)
func take(r) -> void:
	walk_to(r, r.game.TAKE_AT)
	r.game.input("tap", r.game._action_rect().get_center())
func feed(r) -> void:
	walk_to(r, r.game._approach(r.game.hungry))
	r.game.input("tap", r.game._action_rect().get_center())

func run() -> void:
	copy = JSON.parse_string(FileAccess.get_file_as_string("res://hongyuan/copy.json"))
	var chapter: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://hongyuan/chapters/chengdu.json"))
	spec = chapter.steps[2].scene.duplicate(true)
	spec.beats.append({"button": "A7-B1"})
	check(chapter.steps[2].id == "chengdu_walk" and chapter.steps[0].copyId == "A2-1a" and chapter.steps[1].copyId == "A2-1b", "Existing Chengdu checkpoint IDs and narration survive")
	var r = make_runner()
	var g = r.game
	check(g.FEET.size() == 6 and g.hungry >= 0 and g.hungry < 6, "Six pandas start with one randomly hungry panda")
	check(not r._skip_visible(), "No next-step shortcut during first ten seconds")
	tick(r, 30.0)
	check(g.fed.is_empty() and not g.bamboo_held and r.mode == "game", "Idle cannot feed a panda or leave the game")
	check(r._skip_visible(), "Framework next-step appears after ten seconds")
	r.feet = Vector2(25, 500)
	g.input("tap", g.BAMBOO)
	tick(r, 3.0)
	check(g._action() == "take" and not g.bamboo_held, "Distant bamboo tap walks; arrival never picks automatically")
	g.input("tap", g._action_rect().get_center())
	check(g.bamboo_held and g.fed.is_empty(), "Near pickup icon puts one bamboo in hand")
	var resumed = make_runner(saved(r))
	check(resumed.game.bamboo_held and resumed.game.hungry == g.hungry and resumed.feet == r.feet, "JSON refresh preserves held bamboo, hungry target and feet")
	check(resumed.game.rng.state == g.rng.state, "Refresh preserves random hunger sequence")
	resumed.free()
	g.input("tap", g.FEET[g.hungry] - Vector2(0, 25))
	tick(r, 3.0)
	check(g._action() == "feed" and g.fed.is_empty(), "Walking to hungry panda does not auto-feed")
	g.input("tap", g._action_rect().get_center())
	check(g.fed.size() == 1 and not g.bamboo_held and g.feed_flash > 0 and g.phase == "chew", "Feed consumes bamboo and immediately changes panda animation")
	g.input("tap", g.FEET[g.last_fed])
	check(g.fed.size() == 1, "Repeated tap cannot double-count the same panda")
	resumed = make_runner(saved(r))
	tick(resumed, 0.8)
	check(resumed.game.fed == g.fed and resumed.game.hungry not in g.fed, "Refresh during chewing resumes with another unfed panda")
	resumed.free()
	tick(r, 0.8)
	walk_to(r, g._approach(g.hungry))
	g.input("tap", g._action_rect().get_center())
	check(g.fed.size() == 1, "Hungry panda cannot be fed without carrying bamboo")
	take(r)
	var wrong: int = (g.hungry + 1) % 6
	walk_to(r, g._approach(wrong))
	g.input("tap", g.FEET[wrong] - Vector2(0, 25))
	check(g.fed.size() == 1 and g.bamboo_held, "Non-hungry panda does not consume bamboo")
	for i in range(2):
		if not g.bamboo_held: take(r)
		feed(r)
		if i < 1: tick(r, 0.8)
	check(g.fed.size() == 3 and g.phase == "done" and r.mode == "game", "Three distinct pandas finish with a visible eating moment")
	resumed = make_runner(saved(r))
	tick(resumed, 1.2)
	check(resumed.mode == "button", "Refresh at third feed continues without duplicate feeding")
	resumed.free()
	tick(r, 1.2)
	check(r.mode == "button", "Three feeds advance to the following beat")
	r.free()
	r = make_runner()
	take(r)
	feed(r)
	var first: int = r.game.fed[0]
	var skipped = r.game
	r._skip()
	check(r.mode == "button" and skipped.fed.size() == 3 and first in skipped.fed and not skipped.bamboo_held, "skip supplies exactly three fed pandas and preserves completed feeding")
	skipped = null
	r.free()
	var sequences := {}
	for seed_value in range(5):
		r = make_runner()
		r.game.rng.seed = 100 + seed_value
		r.game._choose_hungry()
		var order: Array = []
		for i in range(3):
			order.append(r.game.hungry)
			take(r)
			feed(r)
			if i < 2: tick(r, 0.8)
		check(r.game.fed.size() == 3, "Three-feed loop has no dead end, run %d" % (seed_value + 1))
		sequences[str(order)] = true
		r.free()
	check(sequences.size() >= 4, "New runs produce different hungry-panda orders")
	print("FAILURES ", failures)
	quit(failures)
