extends RefCounted
## 六只熊猫轮流喊饿；每次取一根竹子，走近后手动喂，喂饱五只离场。
## D2-C2 可在喂食间隙接消息；本卡不新增聊天或情感台词。

const FEET := [Vector2(62, 350), Vector2(180, 350), Vector2(298, 350),
	Vector2(62, 452), Vector2(180, 452), Vector2(298, 452)]
const POSES := ["w2/chengdu/panda_sit.png|w2/chengdu/panda_idle.png",
	"w2/chengdu/panda_lie.png|w2/chengdu/panda_sleep.png",
	"w2/chengdu/panda_climb.png|w2/chengdu/panda_idle.png",
	"w2/chengdu/panda_hug.png|w2/chengdu/panda_slow.png",
	"w2/chengdu/panda_lie.png|w2/chengdu/panda_sleep.png",
	"w2/chengdu/panda_sit.png|w2/chengdu/panda_idle.png"]
const BAMBOO := Vector2(180, 532)
const TAKE_AT := Vector2(216, 532)
const NEAR := 42.0
const STICK := Vector2(62, 568)

var r
var phase := "active"
var t := 0.0
var fed: Array = []
var hungry := -1
var bamboo_held := false
var feed_flash := 0.0
var last_fed := -1
var rng := RandomNumberGenerator.new()

func start(runner, _beat: Dictionary) -> void:
	r = runner
	r.player_visible = false # 游戏内按脚点排序绘制熊猫、竹篮和阿鱼。
	r.person_height = 88.0
	r.hint = ""
	rng.randomize()
	_choose_hungry()

func _choose_hungry() -> void:
	var waiting: Array = []
	for i in range(FEET.size()):
		if i not in fed: waiting.append(i)
	hungry = int(waiting[rng.randi_range(0, waiting.size() - 1)]) if not waiting.is_empty() else -1

func process(dt: float) -> bool:
	t += dt
	feed_flash = maxf(0.0, feed_flash - dt)
	if phase == "done":
		return t >= 1.1
	r._walk(dt)
	if phase == "chew" and t >= 0.7:
		phase = "active"
		t = 0.0
		_choose_hungry()
	return false

func _approach(i: int) -> Vector2:
	return FEET[i] + Vector2(32 if i % 3 != 2 else -32, 38)

func _action() -> String:
	if phase != "active": return ""
	if not bamboo_held and r.feet.distance_to(TAKE_AT) <= NEAR: return "take"
	if bamboo_held and hungry >= 0 and r.feet.distance_to(_approach(hungry)) <= NEAR: return "feed"
	return ""

func _act() -> void:
	match _action():
		"take":
			bamboo_held = true
			r.moving = false
			r.play("blip")
		"feed":
			fed.append(hungry)
			last_fed = hungry
			hungry = -1
			bamboo_held = false
			feed_flash = 0.6
			r.moving = false
			r.play("pop")
			t = 0.0
			phase = "done" if fed.size() >= 5 else "chew"
			if phase == "done": r._reset_input()

func _action_rect() -> Rect2:
	var center := BAMBOO + Vector2(36, -26)
	if bamboo_held and hungry >= 0:
		center = FEET[hungry] + Vector2(-40 if hungry % 3 == 2 else 40, -26)
	return Rect2(center - Vector2(24, 24), Vector2(48, 48))

func input(kind: String, pos: Vector2) -> void:
	if phase == "done": return
	# Use runner's pointer ownership/cancellation; never retain a physical press in a save.
	if kind == "down":
		r.stick_pointer = pos.x < 180 and pos.y > 320
	elif kind == "move" and r.dragged and r.stick_pointer:
		r.stick = ((pos - r.down_pos) / 36.0).limit_length()
	elif kind == "up":
		r.stick = Vector2.ZERO
	if kind != "tap": return
	if _action() != "" and _action_rect().has_point(pos):
		_act()
		return
	if not bamboo_held and Rect2(BAMBOO - Vector2(28, 54), Vector2(56, 60)).has_point(pos):
		_walk_to(TAKE_AT)
		return
	if hungry >= 0 and Rect2(FEET[hungry] - Vector2(40, 104), Vector2(80, 110)).has_point(pos):
		_walk_to(_approach(hungry))
		return
	if Geometry2D.is_point_in_polygon(pos, r.walk_area): _walk_to(pos)

func _walk_to(pos: Vector2) -> void:
	r.target = r._clamp(pos)
	r.moving = true

func skip() -> void:
	# Framework calls this only after ten seconds. Preserve already fed pandas.
	for i in range(FEET.size()):
		if fed.size() >= 5: break
		if i not in fed: fed.append(i)
	hungry = -1
	bamboo_held = false
	phase = "done"
	t = 1.1
	r._reset_input()

func restore_checkpoint() -> void:
	# JSON integers become floats; normalize indices and keep the same hungry panda/RNG.
	var unique: Array = []
	for value in fed:
		var index := int(value)
		if index >= 0 and index < FEET.size() and index not in unique: unique.append(index)
	fed = unique
	if fed.size() >= 5:
		phase = "done"
		hungry = -1
		bamboo_held = false
	elif phase == "active" and (hungry < 0 or hungry >= FEET.size() or hungry in fed):
		_choose_hungry()
	r._reset_input()

func draw(ci) -> void:
	var items: Array = []
	for i in range(FEET.size()): items.append({"y": FEET[i].y, "panda": i})
	items.append({"y": r.feet.y, "player": true})
	items.append({"y": BAMBOO.y, "bamboo": true})
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.y < b.y)
	for item: Dictionary in items:
		if item.has("player"): _draw_player(ci)
		elif item.has("bamboo"): ci.sprite("w2/chengdu/bamboo_clump.png", BAMBOO, false, 0.55)
		else:
			var i: int = item.panda
			var art: String = POSES[i]
			if i in fed:
				art = "w2/chengdu/panda_eat.png" if int(r.time * 3 + i) % 2 == 0 else "w2/chengdu/panda_slow.png"
			ci.sprite(art, FEET[i], i % 2 == 1, 0.8)
	if hungry >= 0:
		var at: Vector2 = FEET[hungry] + Vector2(0, -87 + sin(r.time * 4) * 2)
		ci.pill(Rect2(at - Vector2(27, 15), Vector2(54, 30)), ci.t_("G-PANDA-HUNGRY"), 15, ci.PAPER, ci.INK)
		ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-5, 14), at + Vector2(5, 14), at + Vector2(0, 20)]), ci.PAPER)
		ci.draw_arc(_approach(hungry), 9, 0, TAU, 24, Color(ci.GOLD, 0.7), 2)
	if feed_flash > 0 and last_fed >= 0:
		ci.draw_arc(FEET[last_fed] + Vector2(0, -28), 20 + (0.6 - feed_flash) * 35, 0, TAU, 28, Color(ci.GOLD, feed_flash), 2)
	var prompt := "G-PANDA-TAKE" if not bamboo_held else "G-PANDA-FEED"
	if phase == "done": prompt = "G-PANDA-DONE"
	ci._hint(ci.t_(prompt))
	ci.pill(Rect2(12, 96, 110, 28), ci.t_("G-PANDA-COUNT") % mini(fed.size(), 5), 14, Color(ci.INK, 0.78), ci.PAPER)
	if phase != "done":
		_draw_stick(ci)
		if not bamboo_held: ci.draw_arc(TAKE_AT, 9, 0, TAU, 24, Color(ci.GOLD, 0.7), 2)
		var action := _action()
		if action != "":
			var icon: Texture2D = ci.texture("w2/common/icon_pick.png" if action == "take" else "w2/common/icon_feed.png")
			if icon: ci.draw_texture_rect(icon, _action_rect(), false)

func _draw_player(ci) -> void:
	var art := "ayu_idle.png"
	if (r.moving or r.stick.length() > 0.08) and r.move_dir.length() > 0.01:
		var frame := 1 + int(r.walk_dist / 10.0) % 4
		if absf(r.move_dir.y) > absf(r.move_dir.x) * 1.3:
			var direction := "back" if r.move_dir.y < 0 else "front"
			art = "w2/common/ayu_walk_%s_%d.png|ayu_idle.png" % [direction, frame]
		else: art = "w2/common/ayu_walk_side_%d.png|ayu_idle.png" % frame
	ci.sprite(art, r.feet, r.facing < 0)
	if bamboo_held:
		var tex: Texture2D = ci.texture("w2/chengdu/bamboo_held.png")
		if tex: ci.draw_texture_rect(tex, Rect2(r.feet + Vector2(16 * r.facing - 6, -49), Vector2(12, 37)), false)

func _draw_stick(ci) -> void:
	var base: Texture2D = ci.texture("w2/common/joystick_base.png")
	var knob: Texture2D = ci.texture("w2/common/joystick_knob.png")
	var origin: Vector2 = r.down_pos if r.down and r.stick_pointer else STICK
	if base: ci.draw_texture_rect(base, Rect2(origin - Vector2(36, 36), Vector2(72, 72)), false)
	if knob: ci.draw_texture_rect(knob, Rect2(origin + r.stick * 25 - Vector2(16, 16), Vector2(32, 32)), false)
