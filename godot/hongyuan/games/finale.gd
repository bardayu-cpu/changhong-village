extends RefCounted
## 终章：请柬正文 → 写自己的名字（2～12 字）→ 选形象（婚宴的 8 个宾客）→ 装封 → 按住 1 秒盖火漆。

const LOOKS := ["01", "02", "03", "04", "05", "06", "07", "08"]

var r
var phase := "read"   # read → name → look → seal → stamped → done
var t := 0.0
var edit: LineEdit
var error := false
var look := -1
var hold := 0.0
var holding := false
var name := ""
var tex_cache := {}


func start(runner, _beat: Dictionary) -> void:
	r = runner


func process(dt: float) -> bool:
	t += dt
	if phase == "seal":
		if holding:
			hold += dt
			if hold >= 1.0:
				phase = "stamped"
				t = 0.0
				r.play("pop")
		else:
			hold = maxf(0.0, hold - dt * 2.0)
	elif phase == "stamped" and t > 1.4:
		phase = "done"
		r.result = {"name": name, "look": LOOKS[look]}
	return phase == "done"


func _ok_rect() -> Rect2:
	return Rect2(120, 560, 120, 44)


func _look_rect(i: int) -> Rect2:
	return Rect2(36 + (i % 4) * 74, 250 + (i / 4) * 120, 66, 108)


func _envelope() -> Rect2:
	return Rect2(70, 220, 220, 150)


func input(kind: String, pos: Vector2) -> void:
	match phase:
		"read":
			if kind == "tap" and t > 0.6:
				phase = "name"
				t = 0.0
				_make_edit()
		"name":
			if kind == "tap" and _ok_rect().grow(8).has_point(pos):
				_submit_name()
		"look":
			if kind == "tap":
				for i in range(LOOKS.size()):
					if _look_rect(i).has_point(pos):
						look = i
						r.play("blip")
				if look >= 0 and _ok_rect().grow(8).has_point(pos):
					phase = "seal"
					t = 0.0
		"seal":
			if kind == "down":
				holding = true
			elif kind == "up":
				holding = false


func _make_edit() -> void:
	edit = LineEdit.new()
	edit.placeholder_text = r.t_("A7-I1")
	edit.max_length = 12
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.position = Vector2(60, 232)
	edit.size = Vector2(240, 44)
	edit.add_theme_font_override("font", r.FONT)
	edit.add_theme_font_size_override("font_size", 18)
	edit.add_theme_color_override("font_color", r.INK)
	edit.add_theme_color_override("font_placeholder_color", Color(r.WOOD, 0.55))
	var box := StyleBoxFlat.new()
	box.bg_color = r.PAPER
	box.border_color = r.WOOD
	box.set_border_width_all(2)
	edit.add_theme_stylebox_override("normal", box)
	edit.add_theme_stylebox_override("focus", box)
	edit.text_submitted.connect(func(_s: String) -> void: _submit_name())
	r.add_child(edit)
	edit.grab_focus()


func _submit_name() -> void:
	var s := edit.text.strip_edges()
	if s.length() < 2 or s.length() > 12:
		error = true
		r.play("blip")
		return
	name = s
	edit.queue_free()
	edit = null
	phase = "look"
	t = 0.0
	r.play("pop")


func _guest(i: int) -> Texture2D:
	var id: String = LOOKS[i]
	if not tex_cache.has(id):
		var path := "res://hongyuan/assets/w2/finale/chr_LM-GUEST-07.png" if id == "07" else "res://assets/characters/lm/chr_LM-GUEST-%s.png" % id
		tex_cache[id] = load(path) if ResourceLoader.exists(path) else null
	return tex_cache[id]


func draw(ci) -> void:
	# 回到序章那张桌子：六样齐了，收信人一栏等玩家来写
	var desk: Texture2D = ci.texture("bg_invite_desk.png")
	if desk:
		ci.draw_texture_rect(desk, Rect2(0, 0, 360, 640), false)
		ci.draw_rect(Rect2(0, 0, 360, 640), Color(0, 0, 0, 0.25))
	else:
		ci.draw_rect(Rect2(0, 0, 360, 640), Color("#3a1414"))
	match phase:
		"read":
			_card(ci, 1.0)
			ci.text_at(Vector2(30, 214), ci.t_("A7-1a"), 20, ci.RED, 300)
			ci.text_at(Vector2(30, 246), ci.t_("A7-1c"), 15, ci.INK, 300)
			ci.text_at(Vector2(30, 296), ci.t_("A7-1e"), 18, ci.RED, 300)
		"name":
			_card(ci, 1.0)
			ci.text_at(Vector2(30, 214), ci.t_("A7-1a"), 20, ci.RED, 300)
			ci.text_at(Vector2(30, 462), ci.t_("A7-E1") if error else ci.t_("A7-I2"), 14, ci.RED if error else ci.PAPER, 300)
			ci.pill(_ok_rect(), ci.t_("G-19"), 18, ci.RED, ci.PAPER)
		"look":
			for i in range(LOOKS.size()):
				var rr := _look_rect(i)
				ci.draw_rect(rr, ci.PAPER if i != look else Color("#ffe6a8"))
				ci.draw_rect(rr, ci.GOLD if i == look else ci.WOOD, false, 3.0 if i == look else 2.0)
				var g := _guest(i)
				if g:
					ci.draw_texture_rect_region(g, Rect2(rr.position + Vector2(1, 0), Vector2(64, 84) * 1.0), Rect2(0, 0, 64, 84))
			ci.text_at(Vector2(30, 230), name, 20, ci.PAPER, 300)
			if look >= 0:
				ci.pill(_ok_rect(), ci.t_("G-19"), 18, ci.RED, ci.PAPER)
		"seal", "stamped":
			var e := _envelope()
			# 材料小图标太小，这里画一个整屏可见的大信封
			var env: Texture2D = null
			if env:
				ci.draw_texture_rect(env, e, false)
			else:
				ci.draw_rect(e, Color("#f4d495"))
				ci.draw_rect(e, ci.WOOD, false, 2.0)
				ci.draw_colored_polygon(PackedVector2Array([e.position, e.position + Vector2(e.size.x, 0), e.get_center() + Vector2(0, 10)]), Color("#e8c27e"))
				ci.draw_polyline(PackedVector2Array([e.position, e.get_center() + Vector2(0, 10), e.position + Vector2(e.size.x, 0)]), ci.WOOD, 2.0)
			ci.text_at(e.position + Vector2(0, e.size.y - 10), name, 16, ci.INK, e.size.x)
			var c := e.get_center() + Vector2(0, 10)
			if phase == "seal":
				ci.draw_arc(c, 34, -PI / 2, -PI / 2 + TAU * hold, 40, ci.GOLD, 5.0)
				var a := 0.5 + 0.5 * sin(t * 5.0)
				if not holding:
					ci.draw_circle(c, 20, Color(0.75, 0.15, 0.12, 0.25 + 0.25 * a))
				else:
					ci.draw_circle(c, 18 * hold, Color("#9e1b1b"))
				ci.pill(Rect2(50, 416, 260, 48), ci.t_("G-SEAL"), 24, ci.RED, ci.PAPER)
			else:
				var k := clampf(t / 0.3, 0.0, 1.0)
				ci.draw_circle(c, 26, Color("#9e1b1b"))
				ci.draw_circle(c, 20, Color("#c23a2a"))
				ci.draw_arc(c, 13, 0, TAU, 20, Color("#7d1414"), 2.0)
				ci.draw_circle(c, 40 * (1.0 + k), Color(1, 0.8, 0.5, 0.3 * (1.0 - k)))


func _card(ci, a: float) -> void:
	var card: Texture2D = ci.texture("invite_card.png")
	if card:
		ci.draw_texture_rect(card, Rect2(ci.CARD, card.get_size() * ci.S), false, Color(1, 1, 1, a))
		# 盖住空材料位：终章时六样都齐了
		for id: String in ci.SLOTS:
			ci._draw_material_icon(id, ci.CARD + ci.SLOTS[id] * ci.S, 1.0)
