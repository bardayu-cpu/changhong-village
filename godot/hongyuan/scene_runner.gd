extends Control
## 一段可操控的场景：背景、人物、摇杆/点地走路、靠近出互动按钮、对白、小游戏。
## 内容全部来自章节 JSON 里 type="scene" 那一步的 "scene" 字段，代码不写剧情。
## 图按文件名找：先找 assets/w2/<名字>，再找 assets/<名字>；找不到就画占位，不报错。

signal finished
signal beat_reached(index: int)
signal material_applied(id: String)
signal scene_requested(path: String)

const CANVAS := Vector2(360, 640)
const S := 2.0 / 3.0
const StoryCaption := preload("res://hongyuan/ui/story_caption.gd")
const WorldScale := preload("res://hongyuan/world_scale.gd")
const CoastShow := preload("res://hongyuan/coast_show.gd")
const FONT := preload("res://hongyuan/fonts/dialogue_font.tres")
const ROOT := "res://hongyuan/assets/"
const SPEED := 126.0
const NEAR := 40.0
const INK := Color("#281a1a")
const WOOD := Color("#50332a")
const RED := Color("#5e2929")
const GOLD := Color("#d6a456")
const PAPER := Color("#fff1d5")
const WHEAT := Color("#f4d495")
const GRASS := Color("#59764e")
const NAMES := {"ayu": "阿鱼", "toretto": "Toretto", "axiao": "阿晓"}
const AVATARS := {"ayu": "ayu_avatar.png", "toretto": "toretto_avatar.png", "axiao": "axiao_avatar.png"}
const CARD := Vector2(56, 120)
const SLOTS := {"pen": Vector2(75, 305), "ink": Vector2(180, 305), "paper": Vector2(285, 305), "stamp": Vector2(77, 390), "wax": Vector2(180, 390), "envelope": Vector2(284, 393)}
const GAMES := {
	"desk_chat": preload("res://hongyuan/games/desk_chat.gd"),
	"pandas": preload("res://hongyuan/games/pandas.gd"),
	"fishing": preload("res://hongyuan/games/fishing.gd"),
	"ringtoss": preload("res://hongyuan/games/ringtoss.gd"),
	"fireworks": preload("res://hongyuan/games/fireworks.gd"),
	"call": preload("res://hongyuan/games/call.gd"),
	"mail": preload("res://hongyuan/games/mail.gd"),
	"finale": preload("res://hongyuan/games/finale.gd"),
	"drive": preload("res://hongyuan/games/drive.gd"),
	"seat": preload("res://hongyuan/games/seat.gd"),
	"onsen": preload("res://hongyuan/games/onsen.gd"),
	"photo": preload("res://hongyuan/games/photo.gd"),
	"offer": preload("res://hongyuan/games/offer.gd"),
	"invite_mail": preload("res://hongyuan/games/invite_mail.gd"),
}

var copy: Dictionary
var spec: Dictionary
var beats: Array = []
var materials: Dictionary = {}
var bi := -1
var mode := ""
var t := 0.0
var time := 0.0

# 世界
var bg := ""
var bg_fit := false
var player_role := "ayu"
var scale_profile := ""
var atmosphere := ""
var atmosphere_elapsed := 0.0
var bg_fill := Color("#2a1c18")
var night := 0.0
var sky := Color.TRANSPARENT
var ground := Color.TRANSPARENT
var horizon := 360.0
var decor: Array = []
var walk_area := PackedVector2Array()
var hotspots: Dictionary = {}
var actors: Dictionary = {}
var feet := Vector2(180, 520)
var facing := 1.0
var pose := ""
var player_visible := true
var walk_dist := 0.0
var moving := false
var move_dir := Vector2.ZERO
var target := Vector2.ZERO
var target_hot := ""
var follower := ""
var companion := ""        # 同行的人（和玩家并排走）：目前只有 "toretto"
var comp_pos := Vector2.ZERO
var comp_walk := 0.0
var comp_moving := false
var walkers: Array = []    # 路人：来回走的普通宾客，{guest,a,b,speed,phase}
var sheet_cache: Dictionary = {}
var sheet_rects: Dictionary = {}
var trail: Array[Vector2] = []
var badge := ""

# 输入
var pointer_input := preload("res://hongyuan/pointer_input.gd").new()
var down := false
var down_pos := Vector2.ZERO
var down_ms := 0
var dragged := false
var stick := Vector2.ZERO
var stick_pointer := false

# 文字
var hint := ""
var say_who := ""
var say_text := ""
var reveal := 0.0
var go_id := ""
var button_text := ""
var button_rect := Rect2()
var choice_texts: Array = []
var choice_to: Array = []
var choice_note := ""
var choice_note_t := 0.0
var choice_fallback := false
var material_id := ""
var game: RefCounted
var result: Dictionary = {}
var tex_cache: Dictionary = {}
var used_rects: Dictionary = {}
var person_height := 128.0
var sfx := AudioStreamPlayer.new()
var blip: AudioStreamWAV
var pop: AudioStreamWAV


func setup(scene: Dictionary, copy_table: Dictionary, applied: Dictionary) -> void:
	spec = scene
	copy = copy_table
	materials = applied.duplicate()
	beats = spec.get("beats", [])


func _ready() -> void:
	size = CANVAS
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	blip = _tone(520.0, 660.0, 0.07)
	pop = _tone(330.0, 880.0, 0.16)
	sfx.volume_db = -14.0
	add_child(sfx)


## 从第 start 拍开始。前面的布景拍（换背景、摆人、提示）瞬间执行，保证续档时画面对。
func begin(start := 0) -> void:
	_apply_world(spec)
	for i in range(mini(start, beats.size())):
		var beat: Dictionary = beats[i]
		if _is_setup(beat):
			_run_setup(beat)
		elif beat.has("material"):
			materials[beat.material] = true
		elif beat.has("go"):
			_arrive_at(str(beat.go), true)
	bi = start - 1
	_next()


func _apply_world(d: Dictionary) -> void:
	if d.has("player"):
		player_role = str(d.player)
	if d.has("personHeight"):
		person_height = float(d.personHeight)
	if d.has("bg"):
		bg = str(d.bg)
		bg_fit = bool(d.get("bgFit", false))
		scale_profile = WorldScale.profile("", bg)
		atmosphere = ""
		atmosphere_elapsed = 0.0
	if d.has("scaleProfile"):
		scale_profile = str(d.scaleProfile)
	if d.has("atmosphere"):
		atmosphere = str(d.atmosphere)
		atmosphere_elapsed = 0.0
	if d.has("fill"):
		bg_fill = Color(str(d.fill))
	if d.has("sky"):
		sky = Color(str(d.sky))
		ground = Color(str(d.get("ground", d.sky)))
		horizon = float(d.get("horizon", 360))
	if d.has("decor"):
		decor = d.decor
	if d.has("night"):
		night = float(d.night)
	if d.has("badge"):
		badge = _text(str(d.badge))
	if d.has("walkArea"):
		walk_area = PackedVector2Array()
		for p: Array in d.walkArea:
			walk_area.append(Vector2(float(p[0]), float(p[1])))
	if d.has("start"):
		feet = _v(d.start)
		trail.clear()
	if d.has("hotspots"):
		hotspots.clear()
		for h: Dictionary in d.hotspots:
			hotspots[str(h.id)] = h
	if d.has("actors"):
		actors.clear()
		for a: Dictionary in d.actors:
			actors[str(a.id)] = a.duplicate()
	if d.has("pose"):
		pose = str(d.pose)
	if d.has("hideAyu"):
		player_visible = not bool(d.hideAyu)
	if d.has("walkers"):
		walkers = d.walkers
	if d.has("companion"):
		companion = str(d.companion)
		comp_pos = feet + Vector2(36 * facing, -10)
		comp_walk = 0.0


func _is_setup(beat: Dictionary) -> bool:
	for key in ["say", "card", "go", "game", "wait", "material", "button", "choice", "narrate"]:
		if beat.has(key):
			return false
	return true


func _run_setup(beat: Dictionary) -> void:
	_apply_world(beat)
	if beat.has("hint"):
		hint = _text(str(beat.hint)) if str(beat.hint) != "" else ""
	if beat.has("actor"):
		var a: Dictionary = beat.actor
		actors[str(a.id)] = actors.get(str(a.id), {}).merged(a, true)
	if beat.has("remove"):
		actors.erase(str(beat.remove))
	if beat.has("follow"):
		follower = str(beat.follow)
		trail.clear()
	if beat.has("place"):
		feet = _v(beat.place)
		trail.clear()
		if companion != "":
			comp_pos = feet + Vector2(36 * facing, -10)


func _next() -> void:
	bi += 1
	t = 0.0
	mode = ""
	game = null
	_reset_input()
	if bi >= beats.size():
		finished.emit()
		return
	var beat: Dictionary = beats[bi]
	if _is_setup(beat):
		_run_setup(beat)
		_next()
		return
	beat_reached.emit(bi)
	if beat.has("say") or beat.has("narrate"):
		mode = "say"
		say_who = str(beat.get("who", "narrator"))
		say_text = _text(str(beat.get("say", beat.get("narrate", ""))))
		reveal = 0.0
		if beat.has("auto"):
			mode = "auto"
	elif beat.has("card"):
		mode = "card"
		say_text = _text(str(beat.card))
	elif beat.has("go"):
		mode = "go"
		go_id = str(beat.go)
		if beat.has("hint"):
			hint = _text(str(beat.hint))
	elif beat.has("game"):
		mode = "game"
		game = GAMES[str(beat.game)].new()
		game.start(self, beat)
	elif beat.has("wait"):
		mode = "wait"
	elif beat.has("material"):
		mode = "material"
		material_id = str(beat.material)
		sfx.stream = pop
		sfx.play()
	elif beat.has("button"):
		mode = "button"
		button_text = _text(str(beat.button))
		button_rect = Rect2(100, 470, 160, 46)
	elif beat.has("choice"):
		# 终章二选一：第一项接着往下走；其余项切到 beat.to 里对应的场景（如村子）
		mode = "choice"
		choice_texts = []
		for id in beat.choice:
			choice_texts.append(_text(str(id)))
		choice_to = beat.get("to", [])
	queue_redraw()


func _process(dt: float) -> void:
	dt = minf(dt, 0.08)
	t += dt
	if choice_note_t > 0.0:
		choice_note_t = maxf(0.0, choice_note_t - dt)
		if choice_note_t == 0.0 and choice_fallback and mode == "choice":
			choice_fallback = false
			_next()
	time += dt
	if atmosphere != "": atmosphere_elapsed += dt
	var beat: Dictionary = beats[bi] if bi >= 0 and bi < beats.size() else {}
	match mode:
		"say", "auto":
			reveal += dt * 26.0
			if mode == "auto" and t >= float(beat.get("auto", 2.4)):
				_next()
		"card":
			if t >= float(beat.get("duration", 1.8)):
				_next()
		"wait":
			if t >= float(beat.wait):
				_next()
		"material":
			if t >= 2.0:
				materials[material_id] = true
				material_applied.emit(material_id)
				_next()
		"go":
			_walk(dt)
		"game":
			if game and game.process(dt):
				_next()
	queue_redraw()


# ---------- 走路 ----------

func _walk(dt: float) -> void:
	var before := feet
	if stick.length() > 0.08:
		target_hot = ""
		moving = false
		feet = _clamp(feet + stick * SPEED * dt)
	elif moving:
		feet = feet.move_toward(target, SPEED * dt)
		feet = _clamp(feet)
		if feet.distance_to(target) < 0.5 or (target_hot != "" and _near_hotspot() == target_hot and feet.distance_to(target) < 2.0):
			moving = false
			var arrived := target_hot
			target_hot = ""
			if arrived != "" and _near_hotspot() == arrived:
				_trigger(arrived)
				return
	var step := feet - before
	move_dir = step
	_update_companion(dt)
	if absf(step.x) > 0.05:
		facing = signf(step.x)
	walk_dist += step.length()
	if step.length() > 0.01 and follower != "":
		trail.push_front(feet)
		if trail.size() > 40:
			trail.resize(40)


func _update_companion(dt: float) -> void:
	if companion == "":
		return
	var want := feet + Vector2(36 * facing, -10)
	var before := comp_pos
	comp_pos = comp_pos.lerp(want, 1.0 - exp(-6.0 * dt))
	var moved := comp_pos.distance_to(before)
	comp_moving = moved > 0.12
	comp_walk += moved


func _clamp(p: Vector2) -> Vector2:
	if walk_area.size() < 3 or Geometry2D.is_point_in_polygon(p, walk_area):
		return p
	var best := walk_area[0]
	for i in range(walk_area.size()):
		var c := Geometry2D.get_closest_point_to_segment(p, walk_area[i], walk_area[(i + 1) % walk_area.size()])
		if c.distance_squared_to(p) < best.distance_squared_to(p):
			best = c
	return best


func _near_hotspot() -> String:
	if mode != "go" or not hotspots.has(go_id):
		return ""
	return go_id if feet.distance_to(_v(hotspots[go_id].at)) <= NEAR else ""


func _trigger(id: String) -> void:
	if mode != "go" or id != go_id:
		return
	sfx.stream = blip
	sfx.play()
	_arrive_at(id, false)
	hint = ""
	_next()


func _arrive_at(id: String, _instant: bool) -> void:
	var h: Dictionary = hotspots.get(id, {})
	if h.has("snap"):
		feet = _v(h.snap)
	if h.has("pose"):
		pose = str(h.pose)
	if h.has("face"):
		facing = float(h.face)


func _icon_rect(id: String) -> Rect2:
	var h: Dictionary = hotspots[id]
	var at := _v(h.at)
	if h.has("iconAt"):
		return Rect2(_v(h.iconAt) - Vector2(22, 22), Vector2(44, 44))
	# 图标放在站到该点的人物头顶上方，不压在身上
	var snap := _v(h.get("snap", h.at))
	var top := snap.y - person_height_at(snap.y) - 30.0
	return Rect2(at.x - 22, maxf(60.0, top - 22.0), 44, 44)


# ---------- 输入 ----------

func _gui_input(event: InputEvent) -> void:
	event = pointer_input.normalize(event)
	if event == null:
		return
	if event.get_meta("pointer_cancelled", false):
		suspend_input()
		return
	var pos := Vector2.ZERO
	var kind := ""
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
		kind = "down" if event.pressed else "up"
	elif event is InputEventMouseMotion and down:
		pos = event.position
		kind = "move"
	else:
		return
	accept_event()
	if kind == "down":
		down = true
		down_pos = pos
		down_ms = Time.get_ticks_msec()
		dragged = false
		stick_pointer = mode == "go" and pos.x < 180 and pos.y > 320
	elif kind == "move":
		if pos.distance_to(down_pos) > 12:
			dragged = true
	var tap := kind == "up" and down and not dragged and Time.get_ticks_msec() - down_ms < 350
	if kind == "up":
		down = false
	if tap and _skip_visible() and SKIP_RECT.grow(6).has_point(pos):
		_skip()
		return
	match mode:
		"game":
			if game:
				game.input(kind, pos)
				if tap:
					game.input("tap", pos)
		"say":
			if tap or (kind == "up" and down_pos.distance_to(pos) < 30):
				if reveal < say_text.length():
					reveal = say_text.length()
				elif t > 0.25:
					_next()
		"card":
			if tap and t > 0.6:
				_next()
		"choice":
			if tap and t > 0.4:
				for i in range(choice_texts.size()):
					if _choice_rect(i).grow(6).has_point(pos):
						sfx.stream = blip
						sfx.play()
						var to := str(choice_to[i]) if i < choice_to.size() and choice_to[i] != null else ""
						if to == "":
							_next()
						elif not ResourceLoader.exists(to):
							# 缺失资源时留在选择页，允许玩家重试或选另一条路线
							choice_note = _text("G-VILLAGE-LATER")
							choice_note_t = 3.0
							choice_fallback = false
							push_error("Choice destination is missing: " + to)
						else:
							choice_note = "正在出发…"
							choice_note_t = 30.0
							scene_requested.emit(to)
						return
		"button":
			if tap and button_rect.grow(8).has_point(pos):
				sfx.stream = blip
				sfx.play()
				_next()
		"go":
			_go_input(kind, pos, tap)


func _go_input(kind: String, pos: Vector2, tap: bool) -> void:
	if kind == "move" and dragged and stick_pointer:
		stick = ((pos - down_pos) / 36.0).limit_length()
	elif kind == "up":
		stick = Vector2.ZERO
	if not tap:
		return
	var near := _near_hotspot()
	if near != "" and _icon_rect(near).grow(10).has_point(pos):
		_trigger(near)
		return
	# 点目标本身（图标、小圆点或它周围）：走过去，到了自动触发，不用再点第二次
	if hotspots.has(go_id):
		var h: Dictionary = hotspots[go_id]
		var at := _v(h.at)
		if pos.distance_to(at) <= 40.0 or _icon_rect(go_id).grow(10).has_point(pos):
			target = _clamp(_v(h.get("snap", h.at)))
			target_hot = go_id
			moving = true
			return
	# 其他地面点击只走路
	if Geometry2D.is_point_in_polygon(pos, walk_area):
		target = _clamp(pos)
		target_hot = ""
		moving = true


func _reset_input() -> void:
	down = false
	dragged = false
	stick_pointer = false
	stick = Vector2.ZERO
	moving = false
	target_hot = ""


# ---------- 画 ----------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, CANVAS), bg_fill)
	_draw_bg()
	if atmosphere == "coast": CoastShow.draw(self, atmosphere_elapsed)
	_draw_world()
	if night > 0.0:
		draw_rect(Rect2(Vector2.ZERO, CANVAS), Color(0.05, 0.04, 0.12, night))
	if mode == "game" and game:
		game.draw(self)
	if mode == "go":
		_draw_go_ui()
	if badge != "":
		_pill(Rect2(250, 12, 100, 22), badge, 12, Color(RED, 0.85), PAPER)
	if hint != "" and mode in ["go", "game"]:
		_hint(hint)
	if _skip_visible():
		_pill(SKIP_RECT, _text("G-NEXT"), 13, Color(INK, 0.7), WHEAT)
	match mode:
		"say", "auto":
			_draw_say()
		"card":
			_draw_card()
		"material":
			_draw_material()
		"choice":
			draw_rect(Rect2(Vector2.ZERO, CANVAS), Color(0, 0, 0, 0.35))
			for i in range(choice_texts.size()):
				_pill(_choice_rect(i), choice_texts[i], 19, RED if i == 0 else Color(INK, 0.85), PAPER)
			if choice_note_t > 0.0:
				_pill(Rect2(16, 392, 328, 56), choice_note, 16, Color(INK, 0.94), WHEAT)
		"button":
			draw_rect(Rect2(Vector2.ZERO, CANVAS), Color(0, 0, 0, 0.35))
			_pill(button_rect, button_text, 20, RED, PAPER)


func _draw_bg() -> void:
	if sky.a > 0.0:
		for i in range(12):
			var k := i / 12.0
			draw_rect(Rect2(0, horizon * k, 360, horizon / 12.0 + 1), sky.lerp(sky.lightened(0.25), k))
		draw_rect(Rect2(0, horizon, 360, 640 - horizon), ground)
		for y in range(int(horizon) + 16, 640, 24):
			draw_line(Vector2(0, y), Vector2(360, y), ground.darkened(0.06), 1.0)
	for dd: Dictionary in decor:
		var rr: Array = dd.r
		draw_rect(Rect2(float(rr[0]), float(rr[1]), float(rr[2]), float(rr[3])), Color(str(dd.c)))
	if bg == "":
		return
	var tex := texture(bg)
	if not tex:
		return
	var sz := tex.get_size() * S
	draw_texture_rect(tex, Rect2(Vector2.ZERO, CANVAS) if bg_fit else Rect2(((CANVAS - sz) * 0.5).round(), sz), false)


func _draw_world() -> void:
	var items: Array = []
	for id: String in actors:
		var a: Dictionary = actors[id]
		if a.get("hidden", false):
			continue
		items.append({"y": _v(a.at).y + float(a.get("z", 0)), "tex": str(a.tex), "at": _v(a.at), "flip": bool(a.get("flip", false)), "scale": float(a.get("scale", 1.0))})
	if player_visible:
		items.append({"y": feet.y, "player": true})
	if companion == "toretto" and player_visible:
		var cf := "w2/common/toretto_neutral_r2.png"
		if comp_moving and int(comp_walk / 10.0) % 2 == 0:
			cf = "w2/common/toretto_walk.png"
		items.append({"y": comp_pos.y, "tex": cf, "at": comp_pos, "flip": facing < 0, "scale": 1.0})
	for i in range(walkers.size()):
		items.append({"y": _walker_pos(walkers[i]).y, "walker": i})
	if follower != "" and player_visible:
		# 箱子拉杆握在手里：贴着身后走，不再落后一截
		var k := person_height_at(feet.y) / person_height
		var fp := feet + Vector2(-24 * facing * k, 0)
		items.append({"y": feet.y - 1, "tex": follower, "at": fp, "flip": facing < 0, "scale": k, "roll": true})
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.y < b.y)
	for it: Dictionary in items:
		if it.has("player"):
			_draw_player()
		elif it.has("walker"):
			_draw_walker(walkers[int(it.walker)])
		else:
			var frame: String = it.tex
			if it.get("roll", false) and walk_dist > 0.0:
				frame = frame.replace("_1", "_%d" % (1 + int(walk_dist / 8.0) % 2))
			if not sprite(frame, it.at, it.flip, it.scale) and it.get("roll", false):
				var p: Vector2 = it.at
				draw_rect(Rect2(p + Vector2(-11, -34), Vector2(22, 30)), Color("#3f6f8f"))
				draw_rect(Rect2(p + Vector2(-11, -34), Vector2(22, 30)), INK, false, 2.0)
				draw_line(p + Vector2(0, -34), p + Vector2(10 * -facing, -50), INK, 2.0)
				draw_circle(p + Vector2(-6, -3), 2.5, INK)
				draw_circle(p + Vector2(6, -3), 2.5, INK)


## 路人沿 a→b 来回走；位置只由时间决定，不进存档。
func _walker_pos(w: Dictionary) -> Vector2:
	var a := _v(w.a)
	var b := _v(w.b)
	var length := maxf(a.distance_to(b), 1.0)
	var d := fposmod(time * float(w.get("speed", 30)) + float(w.get("phase", 0.0)) * length * 2.0, length * 2.0)
	return a.lerp(b, (d if d <= length else length * 2.0 - d) / length)


func _draw_walker(w: Dictionary) -> void:
	var a := _v(w.a)
	var b := _v(w.b)
	var length := maxf(a.distance_to(b), 1.0)
	var d := fposmod(time * float(w.get("speed", 30)) + float(w.get("phase", 0.0)) * length * 2.0, length * 2.0)
	var heading := (b - a).normalized() * (1.0 if d <= length else -1.0)
	var row := 8 if heading.x > 0 else 4
	if absf(heading.y) > absf(heading.x):
		row = 0 if heading.y > 0 else 12
	var path := "res://assets/characters/lm/chr_LM-GUEST-%s.png" % str(w.guest)
	if not sheet_cache.has(path):
		sheet_cache[path] = load(path) if ResourceLoader.exists(path) else null
	var sheet: Texture2D = sheet_cache[path]
	var pos := a.lerp(b, (d if d <= length else length * 2.0 - d) / length)
	var height := person_height_at(pos.y) * float(w.get("scale", 0.94))
	if not sheet:
		draw_rect(Rect2(pos - Vector2(7, height), Vector2(14, height)), Color("#6b3fa0"))
		return
	var f := row + int(d / 8.0) % 4
	var key := path + str(f)
	if not sheet_rects.has(key):
		sheet_rects[key] = Rect2(sheet.get_image().get_region(Rect2i(f * 64, 0, 64, 84)).get_used_rect())
	var used: Rect2 = sheet_rects[key]
	var k := height / maxf(used.size.y, 1.0)
	_shadow(pos, used.size.x * k * 0.3)
	draw_texture_rect_region(sheet, Rect2(pos + Vector2((used.position.x - 32.0) * k, -height), used.size * k), Rect2(used.position + Vector2(f * 64, 0), used.size))


func _player_frame() -> String:
	var walking := mode == "go" and (moving or stick.length() > 0.08) and move_dir.length() > 0.01
	var name := "ayu_idle.png"
	if player_role == "toretto":
		name = "w2/common/toretto_neutral_r2.png"
		if walking:
			name = "w2/common/toretto_walk.png" if int(walk_dist / 10.0) % 2 == 0 else "w2/common/toretto_neutral_r2.png"
		elif pose != "":
			name = {"gifts": "w2/common/toretto_gifts_r2.png", "sit": "w2/common/toretto_sit.png", "back": "w2/common/toretto_back_r2.png"}.get(pose, pose)
	elif pose != "" and not walking:
		name = {"sit": "w2/shizuoka/ayu_sit.png|ayu_idle.png", "fishing": "w2/shizuoka/ayu_fish_hold.png|w2/common/ayu_fishing.png", "throw": "w2/hainan/ayu_throw_hold.png|w2/common/ayu_throw.png", "cheer": "w2/common/ayu_cheer.png", "back": "w2/common/ayu_idle_back.png|ayu_idle.png"}.get(pose, pose)
		if pose == "surprised": name = "w2/common/ayu_surprised.png|ayu_idle.png"
	elif walking:
		var f := 1 + int(walk_dist / 10.0) % 4
		if absf(move_dir.y) > absf(move_dir.x) * 1.3:
			var dirn := "back" if move_dir.y < 0 else "front"
			name = "w2/common/ayu_walk_%s_%d.png|w2/common/ayu_walk_side_%d.png|%s" % [dirn, f, f, "ayu_walk.png" if f % 2 == 1 else "ayu_idle.png"]
		else:
			name = "w2/common/ayu_walk_side_%d.png|%s" % [f, "ayu_walk.png" if f % 2 == 1 else "ayu_idle.png"]
	if follower != "" and walking:
		name = "w2/hongkong/ayu_drag_side_%d.png|%s" % [1 + int(walk_dist / 10.0) % 4, name]
	return name


func _draw_player() -> void:
	var walking := mode == "go" and (moving or stick.length() > 0.08) and move_dir.length() > 0.01
	var bob := -1.0 if walking and int(walk_dist / 10.0) % 2 == 0 else 0.0
	sprite(_player_frame(), feet + Vector2(0, bob), facing < 0, 1.0, feet.y)


func _draw_go_ui() -> void:
	if hotspots.has(go_id):
		var h: Dictionary = hotspots[go_id]
		var at := _v(h.at)
		var near := _near_hotspot() != ""
		if near:
			var r := _icon_rect(go_id)
			r.position.y += sin(time * 5.0) * 2.0
			var icon := texture("w2/common/icon_%s.png" % str(h.get("icon", "pick")))
			if icon:
				draw_texture_rect(icon, Rect2(r.get_center() - Vector2(24, 24), Vector2(48, 48)), false)
			else:
				_pill(r, _text(str(h.get("label", "G-13"))) if h.has("label") else "！", 16, PAPER, INK, true)
		else:
			var a := 0.55 + sin(time * 4.5) * 0.25
			draw_circle(at, 5, Color(1.0, 0.9, 0.6, a))
			draw_arc(at, 10 + sin(time * 4.5) * 2.0, 0, TAU, 24, Color(1.0, 0.9, 0.6, a), 1.5)
	var origin := down_pos if down and stick_pointer else Vector2(64, 558)
	var base := texture("w2/common/joystick_base.png")
	var knob := texture("w2/common/joystick_knob.png")
	if base and knob:
		draw_texture_rect(base, Rect2(origin - Vector2(36, 36), Vector2(72, 72)), false)
		draw_texture_rect(knob, Rect2(origin + stick * 25 - Vector2(16, 16), Vector2(32, 32)), false)


func _draw_say() -> void:
	StoryCaption.draw_caption(self, say_text, say_who, int(reveal), reveal >= say_text.length() and mode == "say", _speaker_anchor(say_who))


func _speaker_anchor(who: String) -> Vector2:
	if who == player_role and player_visible:
		return feet - Vector2(0, person_rect(_player_frame(), feet).size.y)
	if companion != "" and who == companion and player_visible:
		return comp_pos - Vector2(0, person_rect("w2/common/toretto_neutral_r2.png", comp_pos).size.y)
	if actors.has(who) and not actors[who].get("hidden", false):
		var a: Dictionary = actors[who]
		return _v(a.at) - Vector2(0, person_rect(str(a.tex), _v(a.at), float(a.get("scale", 1))).size.y)
	return Vector2(-1, -1)


func _draw_card() -> void:
	# 章节名叠在画面上，不再黑屏：上一屏的东西一直看得见
	var beat: Dictionary = beats[bi] if bi >= 0 and bi < beats.size() else {}
	var dur := float(beat.get("duration", 1.8))
	var a := clampf(t / 0.35, 0.0, 1.0) * clampf((dur - t) / 0.35, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, CANVAS), Color(INK, 0.28 * a))
	draw_rect(Rect2(0, 270, 360, 84), Color(INK, 0.72 * a))
	draw_rect(Rect2(0, 270, 360, 2), Color(GOLD, 0.8 * a))
	draw_rect(Rect2(0, 352, 360, 2), Color(GOLD, 0.8 * a))
	draw_multiline_string(FONT, Vector2(30, 318), say_text, HORIZONTAL_ALIGNMENT_CENTER, 300, 20, -1, Color(WHEAT, a))


const NEXT_STOP := {"paper": "W-NEXT-SHIZUOKA", "stamp": "W-NEXT-HAINAN", "wax": "W-NEXT-HONGKONG"}


func _draw_material() -> void:
	# 回到序章那张桌子：这一章的东西落进请柬，不弹「收入囊中」
	var desk := texture("bg_invite_desk.png")
	var fade := clampf(t / 0.4, 0.0, 1.0)
	if desk:
		draw_texture_rect(desk, Rect2(Vector2.ZERO, CANVAS), false, Color(1, 1, 1, fade))
	else:
		draw_rect(Rect2(Vector2.ZERO, CANVAS), Color(INK, 0.82 * fade))
	var card := texture("invite_card.png")
	if card:
		draw_texture_rect(card, Rect2(CARD, card.get_size() * S), false, Color(1, 1, 1, fade))
	for id: String in SLOTS:
		var on: bool = materials.get(id, false)
		var k := fade
		if id == material_id:
			k = clampf((t - 0.4) / 0.8, 0.0, 1.0)
			on = k > 0.0
			if k > 0.0 and k < 1.0:
				draw_circle(CARD + SLOTS[id] * S, 30 * k, Color(GOLD, 0.35 * (1.0 - k)))
		if on:
			_draw_material_icon(id, CARD + SLOTS[id] * S, k)
	var count := 0
	for id: String in SLOTS:
		if materials.get(id, false) or id == material_id:
			count += 1
	var c := clampf((t - 1.0) / 0.4, 0.0, 1.0)
	var next_id: String = NEXT_STOP.get(material_id, "")
	var caption := "%d / 6" % count
	if next_id != "" and copy.has(next_id):
		caption += "　" + _text(next_id)
	draw_rect(Rect2(60, 560, 240, 34), Color(INK, 0.6 * c))
	draw_string(FONT, Vector2(60, 583), caption, HORIZONTAL_ALIGNMENT_CENTER, 240, 15, Color(WHEAT, c))


func _draw_material_icon(id: String, c: Vector2, k: float) -> void:
	var art := texture("w2/finale/slot_%s.png" % id)
	if id in ["pen", "ink"]:
		art = texture("invite_slot_%s.png" % id)
		if art:
			draw_texture_rect(art, Rect2(CARD, art.get_size() * S), false, Color(1, 1, 1, k))
			return
	if art:
		var sz := art.get_size() * S
		draw_texture_rect(art, Rect2(c - sz * 0.5, sz), false, Color(1, 1, 1, k))
		return
	var col := Color(1, 1, 1, k)
	match id:
		"paper":
			draw_rect(Rect2(c - Vector2(13, 16), Vector2(26, 32)), PAPER * col)
			draw_rect(Rect2(c - Vector2(13, 16), Vector2(26, 32)), WOOD * col, false, 1.5)
			for i in range(4):
				draw_line(c + Vector2(-8, -9 + i * 6), c + Vector2(8, -9 + i * 6), Color(WOOD, 0.6 * k), 1.0)
		"stamp":
			draw_rect(Rect2(c + Vector2(-6, -16), Vector2(12, 14)), WOOD * col)
			draw_rect(Rect2(c + Vector2(-14, -2), Vector2(28, 12)), RED * col)
			draw_rect(Rect2(c + Vector2(-16, 10), Vector2(32, 4)), Color("#c0392b") * col)
		"wax":
			draw_circle(c, 15, Color("#9e1b1b") * col)
			draw_circle(c, 10, Color("#c23a2a") * col)
			draw_circle(c + Vector2(-4, -4), 3, Color(1, 0.7, 0.6, 0.6 * k))
		"envelope":
			draw_rect(Rect2(c - Vector2(20, 13), Vector2(40, 26)), WHEAT * col)
			draw_polyline(PackedVector2Array([c + Vector2(-20, -13), c + Vector2(0, 2), c + Vector2(20, -13)]), WOOD * col, 1.5)
			draw_rect(Rect2(c - Vector2(20, 13), Vector2(40, 26)), WOOD * col, false, 1.5)


# ---------- 快速浏览：小游戏和走路 10 秒后出「下一步」，不能整章跳过 ----------
const SKIP_RECT := Rect2(268, 96, 80, 28)
const SKIP_AFTER := 10.0
const NO_SKIP := ["call", "desk_chat", "finale", "seat"]  # 来电对白不能删；终章要玩家自己填名字入席


func _choice_rect(i: int) -> Rect2:
	return Rect2(80, 250 + i * 62, 200, 48)


func _skip_visible() -> bool:
	if t < SKIP_AFTER or bi < 0 or bi >= beats.size():
		return false
	if mode == "go":
		return hotspots.has(go_id)
	return mode == "game" and game != null and not str(beats[bi].get("game", "")) in NO_SKIP


func _skip() -> void:
	sfx.stream = blip
	sfx.play()
	if mode == "go":
		_trigger(go_id)
		return
	if game.has_method("skip"):
		game.skip()
	pose = ""
	_next()


func _hint(text: String) -> void:
	var w := minf(320.0, 30.0 + 16.0 * text.length())
	_pill(Rect2((CANVAS.x - w) * 0.5, 46, w, 34), text, 16, Color(INK, 0.78), WHEAT)


# ---------- 工具（小游戏也用） ----------

func texture(name: String) -> Texture2D:
	for candidate in name.split("|"):
		if candidate == "":
			continue
		if not tex_cache.has(candidate):
			var path: String = ROOT + candidate
			if not ResourceLoader.exists(path) and not candidate.begins_with("w2/"):
				path = ROOT + "w2/" + candidate
			tex_cache[candidate] = load(path) if ResourceLoader.exists(path) else null
		if tex_cache[candidate]:
			return tex_cache[candidate]
	return null


func person_height_at(floor_y: float) -> float:
	return WorldScale.height_at(scale_profile, floor_y, person_height)


func person_rect(name: String, at: Vector2, scale_k := 1.0, depth_y := NAN) -> Rect2:
	var tex := texture(name)
	if not tex: return Rect2(at, Vector2.ZERO)
	if not used_rects.has(tex): used_rects[tex] = WorldScale.visible_rect(tex)
	var height := person_height_at(at.y if is_nan(depth_y) else depth_y) * scale_k
	var local := WorldScale.local_rect(tex.resource_path, tex.get_width(), used_rects[tex], height)
	return Rect2(at + local.position, local.size)


func sprite(name: String, at: Vector2, flip := false, scale_k := 1.0, depth_y := NAN) -> bool:
	var tex := texture(name)
	if not tex:
		return false
	var person := "ayu_" in name or "toretto_" in name or "axiao_" in name
	if person:
		var rect := person_rect(name, at, scale_k, depth_y)
		var used: Rect2 = Rect2(used_rects[tex])
		if used.size.y > 0:
			_shadow(at, rect.size.x * 0.28)
			draw_set_transform(at, 0, Vector2(-1, 1) if flip else Vector2.ONE)
			draw_texture_rect_region(tex, Rect2(rect.position - at, rect.size), used)
			draw_set_transform(Vector2.ZERO)
			return true
	var sz := tex.get_size() * S * scale_k
	at = (at / S).round() * S
	draw_set_transform(Vector2.ZERO)
	_shadow(at, sz.x * 0.28)
	draw_set_transform(at, 0.0, Vector2(-1, 1) if flip else Vector2.ONE)
	draw_texture_rect(tex, Rect2(Vector2(-sz.x * 0.5, -sz.y + 5.0 * scale_k), sz), false)
	draw_set_transform(Vector2.ZERO)
	return true


func _shadow(at: Vector2, w: float) -> void:
	var pts := PackedVector2Array()
	for i in range(16):
		var a := TAU * i / 16.0
		pts.append(at + Vector2(cos(a) * w, sin(a) * w * 0.28))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.22))


func _panel(r: Rect2, fill: Color, edge: Color) -> void:
	draw_rect(r, fill)
	draw_rect(r.grow(-2), edge, false, 2.0)
	draw_rect(r, Color(INK, 0.9), false, 2.0)


func _pill(r: Rect2, text: String, font_size: int, fill: Color, fg: Color, outline := false) -> void:
	draw_rect(r, fill)
	draw_rect(r, Color(INK, 0.95) if outline or fill.a > 0.9 else Color(GOLD, 0.6), false, 2.0)
	var asc := FONT.get_ascent(font_size)
	var desc := FONT.get_descent(font_size)
	draw_string(FONT, Vector2(r.position.x, r.position.y + (r.size.y + asc - desc) * 0.5), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, font_size, fg)


func text_at(pos: Vector2, text: String, font_size: int, color: Color, width := -1.0, align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	draw_multiline_string(FONT, pos, text, align, width, font_size, -1, color)


func pill(r: Rect2, text: String, font_size: int, fill: Color, fg: Color) -> void:
	_pill(r, text, font_size, fill, fg, true)


func _text(id: String) -> String:
	return keep_units(str(copy.get(id, id)).replace("<br>", "\n"))


static var _unit_re: RegEx
## 「24 年」「10 个月」：数字和后面的字之间去掉空格：Web 包会在任何空格（含不断行空格）处折行
static func keep_units(s: String) -> String:
	if _unit_re == null:
		_unit_re = RegEx.create_from_string("(\\d) (?=[\\x{4e00}-\\x{9fff}])")
	return _unit_re.sub(s, "$1", true)


func t_(id: String) -> String:
	return _text(id)


func play(kind: String) -> void:
	sfx.stream = pop if kind == "pop" else blip
	sfx.play()


static func _v(a: Variant) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


func _tone(f0: float, f1: float, dur: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var ph := 0.0
	for i in range(n):
		var k := float(i) / n
		ph += TAU * lerpf(f0, f1, k) / rate
		var s := int(sin(ph) * 9000.0 * (1.0 - k))
		data.encode_s16(i * 2, s)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	return w

# Only gameplay values enter the checkpoint. Nodes, resources, input holds and caches do not.
const GAME_SAVE_FIELDS := ["phase", "t", "power", "bob", "from", "wait_for", "fish_t", "missed",
	"li", "reveal", "hand", "aim", "thrown", "rings", "hit_flash", "bursts", "count", "need",
	"finale_t", "color_offset", "look", "hold", "name", "error", "lane", "car_x", "scroll",
	"speed", "bump", "traffic", "spawn_at", "bay_y", "park_t", "hint_t", "birthday_seen", "birthday_flash", "call_time", "speaker_on", "chat_scroll",
	"fed", "hungry", "bamboo_held", "feed_flash", "last_fed", "ayu_x", "sky_s", "field", "typed", "typing"]

func snapshot() -> Dictionary:
	var saved := {"beat": bi, "mode": mode, "feet": [feet.x, feet.y], "facing": facing,
		"target": [target.x, target.y], "moving": moving, "walk_dist": walk_dist,
		"pose": pose, "t": t, "reveal": reveal, "result": result.duplicate(true), "trail": [], "atmosphere_elapsed": atmosphere_elapsed}
	for p: Vector2 in trail:
		saved.trail.append([p.x, p.y])
	if game:
		var values := {}
		for prop: Dictionary in game.get_property_list():
			var key := str(prop.name)
			if key in GAME_SAVE_FIELDS:
				values[key] = _pack_value(game.get(key))
		if "edit" in game and is_instance_valid(game.edit):
			values.name = game.edit.text
		if "rng" in game:
			values.rng_state = str(game.rng.state)
		saved.game = values
	return saved

func restore(saved: Dictionary) -> void:
	if int(saved.get("beat", -1)) != bi or str(saved.get("mode", "")) != mode:
		return
	feet = _v(saved.get("feet", [feet.x, feet.y]))
	facing = float(saved.get("facing", facing))
	target = _v(saved.get("target", [feet.x, feet.y]))
	moving = bool(saved.get("moving", false)) and mode == "go"
	walk_dist = float(saved.get("walk_dist", 0))
	pose = str(saved.get("pose", pose))
	t = float(saved.get("t", 0))
	atmosphere_elapsed = float(saved.get("atmosphere_elapsed", 0))
	reveal = float(saved.get("reveal", 0))
	result = saved.get("result", {}).duplicate(true)
	trail.clear()
	for p: Array in saved.get("trail", []):
		trail.append(_v(p))
	if game and saved.get("game", null) is Dictionary:
		var values: Dictionary = saved.game
		for prop: Dictionary in game.get_property_list():
			var key := str(prop.name)
			if key in GAME_SAVE_FIELDS and values.has(key):
				game.set(key, _unpack_value(values[key]))
		if "rng" in game and values.has("rng_state"):
			game.rng.state = int(values.rng_state)
		if "edit" in game and game.phase == "name":
			game._make_edit()
			game.edit.text = game.name
		if game.has_method("restore_checkpoint"):
			game.restore_checkpoint()
	queue_redraw()

static func _pack_value(value: Variant) -> Variant:
	if value is Vector2:
		return {"vector2": [value.x, value.y]}
	if value is Array:
		return value.map(_pack_value)
	if value is Dictionary:
		var out := {}
		for key: Variant in value:
			out[key] = _pack_value(value[key])
		return out
	return value

static func _unpack_value(value: Variant) -> Variant:
	if value is Array:
		return value.map(_unpack_value)
	if value is Dictionary:
		if value.has("vector2"):
			return _v(value.vector2)
		var out := {}
		for key: Variant in value:
			out[key] = _unpack_value(value[key])
		return out
	return value

func suspend_input() -> void:
	pointer_input.reset()
	_reset_input()
	if game:
		if "holding" in game:
			game.holding = false
		if "dragging" in game:
			game.dragging = false
		if "swiping" in game:
			game.swiping = false
