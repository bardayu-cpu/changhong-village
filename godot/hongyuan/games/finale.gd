extends RefCounted
## 终章：请柬正文 → 写自己的名字（2～12 字）→ 选形象（婚宴的 8 个宾客）→ 装封 → 按住 1 秒盖火漆。

const LOOKS := ["01", "02", "03", "04", "05", "06", "07", "08"]

var r
var phase := "read"
var typed := 0.0
var dragging := false
var from := Vector2.ZERO
var open_progress := 0.0
var t := 0.0
var edit: LineEdit
var error := false
var look := -1
var hold := 0.0
var holding := false
var name := ""
var tex_cache := {}
var keyboard_callback: JavaScriptObject
var keyboard_open := false


func start(runner, _beat: Dictionary) -> void:
	r = runner


func process(dt: float) -> bool:
	t += dt
	match phase:
		"write":
			typed = minf(float(_letter().length()), typed + dt * 14.0)
			if typed >= _letter().length():
				_set_phase("written")
		"fold":
			if t >= 1.3: _set_phase("seal")
		"seal":
			if holding:
				hold = minf(1.0, hold + dt)
				if hold >= 1.0:
					_set_phase("stamped")
					r.play("pop")
		"stamped":
			if t >= 1.2: _set_phase("ready_send")
		"send":
			if t >= 1.8: _set_phase("receive")
		"opening":
			if t >= 0.8: _set_phase("read_received")
	return phase == "done"

func _set_phase(value: String) -> void:
	phase = value
	t = 0.0
	holding = false
	dragging = false
	r.play("blip")

func _letter() -> String:
	return name + "：\n\n" + r.t_("A7-1a") + "\n\n" + r.t_("A7-1c") + "\n\n" + r.t_("A7-1e")

func _ok_rect() -> Rect2:
	return Rect2(100, 560, 160, 48)

func _look_rect(i: int) -> Rect2:
	return Rect2(36 + (i % 4) * 74, 250 + (i / 4) * 120, 66, 108)

func _envelope() -> Rect2:
	return Rect2(50, 255, 260, 165)

func input(kind: String, pos: Vector2) -> void:
	match phase:
		"read":
			if kind == "tap" and t > 0.6:
				_set_phase("name")
				_make_edit()
		"name":
			if kind == "tap" and _ok_rect().grow(8).has_point(pos): _submit_name()
		"written":
			if kind == "tap" and _ok_rect().has_point(pos): _set_phase("fold")
		"seal":
			if kind == "down" and pos.distance_to(_envelope().get_center()) <= 46:
				holding = true
			elif kind == "up":
				holding = false
				hold = 0.0
			elif kind == "move" and pos.distance_to(_envelope().get_center()) > 56:
				holding = false
				hold = 0.0
		"ready_send":
			if kind == "tap" and _ok_rect().has_point(pos): _set_phase("send")
		"receive":
			if kind == "down" and _envelope().grow(12).has_point(pos):
				dragging = true
				from = pos
			elif kind == "move" and dragging:
				open_progress = clampf((pos.x - from.x) / 140.0, 0, 1)
				if open_progress >= 1.0: _set_phase("opening")
			elif kind == "up":
				dragging = false
				open_progress = 0.0
		"read_received":
			if kind == "tap" and t > 0.5: _set_phase("look")
		"look":
			if kind == "tap":
				for i in range(LOOKS.size()):
					if _look_rect(i).has_point(pos):
						look = i
						r.play("blip")
				if look >= 0 and _ok_rect().has_point(pos): _set_phase("welcome")
		"welcome":
			if kind == "tap" and t > 0.6:
				r.result = {"name": name, "look": LOOKS[look]}
				_set_phase("done")

func restore_checkpoint() -> void:
	# Old sealed saves predate sending/opening: continue with the physical letter.
	if phase == "stamped" and hold >= 1.0:
		t = minf(t, 1.2)
	holding = false
	dragging = false
	open_progress = 0.0


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
	if OS.has_feature("web") and OS.has_feature("hongyuan_wechat"):
		edit.virtual_keyboard_enabled = false
		edit.gui_input.connect(_wechat_name_input)
	else:
		edit.grab_focus()


func _wechat_name_input(event: InputEvent) -> void:
	var released: bool = event is InputEventScreenTouch and not event.pressed and not event.canceled
	if event is InputEventMouseButton:
		released = event.button_index == MOUSE_BUTTON_LEFT and not event.pressed
	if not released or keyboard_open or phase != "name":
		return
	var bridge := JavaScriptBridge.get_interface("hongyuanContent")
	if bridge == null:
		return
	keyboard_open = true
	keyboard_callback = JavaScriptBridge.create_callback(func(args: Array) -> void:
		keyboard_open = false
		if phase == "name" and is_instance_valid(edit) and not args.is_empty():
			edit.text = str(args[0])
	)
	bridge.editGuestName(edit.text, edit.max_length, keyboard_callback)


func _submit_name() -> void:
	var s := edit.text.strip_edges()
	if s.length() < 2 or s.length() > 12:
		error = true
		r.play("blip")
		return
	name = s
	edit.queue_free()
	edit = null
	phase = "write"
	typed = 0.0
	t = 0.0
	r.play("pop")


func _guest(i: int) -> Texture2D:
	var id: String = LOOKS[i]
	if not tex_cache.has(id):
		var path := "res://hongyuan/assets/w2/finale/chr_LM-GUEST-07.png" if id == "07" else "res://assets/characters/lm/chr_LM-GUEST-%s.png" % id
		tex_cache[id] = load(path) if ResourceLoader.exists(path) else null
	return tex_cache[id]


func draw(ci) -> void:
	var desk = preload("res://hongyuan/ui/desk_art.gd")
	desk.draw(ci, r.materials, r.view_rect, "", t, false)
	match phase:
		"read":
			ci.StoryCaption.draw_caption(ci, "收件人：你", "narrator")
			_paper(ci, _letter().length())
			ci.pill(_ok_rect(), "写下名字", 18, ci.RED, ci.PAPER)
		"name":
			_paper(ci, 0)
			ci.text_at(Vector2(40, 190), ci.t_("A7-I1"), 18, ci.INK, 280)
			ci.text_at(Vector2(40, 474), ci.t_("A7-E1") if error else ci.t_("A7-I2"), 14, ci.WOOD, 280)
			ci.pill(_ok_rect(), ci.t_("G-19"), 18, ci.RED, ci.PAPER)
		"write", "written":
			_paper(ci, int(typed))
			if phase == "write":
				var pen: Texture2D = ci.texture("pen_tip.png")
				var line := int(typed / 12.0)
				var at := Vector2(98 + fmod(typed, 12.0) * 12, 205 + line * 25)
				if pen: ci.draw_texture_rect(pen, Rect2(at, Vector2(30, 48)), false)
			else:
				ci.pill(_ok_rect(), "装进信封", 18, ci.RED, ci.PAPER)
		"fold":
			_envelope_art(ci, false)
			var k := smoothstep(0, 1, clampf(t / 1.3, 0, 1))
			var page := Rect2(Vector2(70, 130).lerp(Vector2(75, 280), k), Vector2(210, 260).lerp(Vector2(210, 95), k))
			ci.draw_rect(page, ci.PAPER)
			ci.draw_rect(page, ci.GOLD, false, 2)
		"seal", "stamped", "ready_send", "send", "receive", "opening":
			if phase == "send":
				ci.draw_set_transform(Vector2(0, -700 * smoothstep(0, 1, clampf(t / 1.8, 0, 1))))
			_envelope_art(ci, phase != "seal" or hold > 0.0)
			ci.draw_set_transform(Vector2.ZERO)
			var c := _envelope().get_center()
			if phase == "seal":
				ci.draw_arc(c, 38, -PI / 2, -PI / 2 + TAU * maxf(0.02, hold), 40, ci.GOLD, 4)
				ci.pill(Rect2(65, 475, 230, 44), "按住火漆一秒", 18, ci.RED, ci.PAPER)
			elif phase == "ready_send":
				ci.pill(_ok_rect(), "寄出请帖", 18, ci.RED, ci.PAPER)
			elif phase == "receive":
				ci.StoryCaption.draw_caption(ci, "你收到了一封请帖", "narrator")
				ci.draw_line(Vector2(76, 275), Vector2(76 + 208 * open_progress, 275), ci.GOLD, 4)
				ci.pill(Rect2(48, 475, 264, 44), "沿封口向右滑动，亲手拆开", 16, ci.RED, ci.PAPER)
			elif phase == "opening":
				var k := clampf(t / 0.8, 0, 1)
				ci.draw_rect(Rect2(70, 255 - 120 * k, 220, 120 + 160 * k), ci.PAPER)
		"read_received":
			_paper(ci, _letter().length())
			ci.pill(_ok_rect(), "收下这份邀请", 18, ci.RED, ci.PAPER)
		"look":
			ci.text_at(Vector2(30, 185), ci.t_("G-CHOOSE-LOOK"), 20, ci.PAPER, 300)
			for i in range(LOOKS.size()):
				var rr := _look_rect(i)
				ci.draw_rect(rr, ci.PAPER if i != look else Color("#ffe6a8"))
				ci.draw_rect(rr, ci.GOLD if i == look else ci.WOOD, false, 3 if i == look else 2)
				var guest := _guest(i)
				if guest: ci.draw_texture_rect_region(guest, Rect2(rr.position + Vector2(1, 0), Vector2(64, 84)), Rect2(0, 0, 64, 84))
			if look >= 0: ci.pill(_ok_rect(), ci.t_("G-19"), 18, ci.RED, ci.PAPER)
		"welcome":
			var welcome: Texture2D = ci.texture("round1/common/welcome.png")
			if welcome:
				ci.draw_texture_rect(welcome, Rect2(54, 120, 252, 353), false)
			else:
				ci.sprite("ayu_stand.png", Vector2(135, 490))
				ci.sprite("w2/common/toretto_neutral_r2.png", Vector2(230, 490))
			ci.StoryCaption.draw_caption(ci, ci.t_("A7-2c"), "ayu", -1, true, Vector2(135, 205))
			ci.pill(_ok_rect(), "去赴约", 18, ci.RED, ci.PAPER)

func _paper(ci, length: int) -> void:
	var page := Rect2(46, 140, 268, 330)
	ci.draw_rect(page, ci.PAPER)
	ci.draw_rect(page.grow(-6), ci.GOLD, false, 2)
	ci.draw_multiline_string(ci.FONT, Vector2(70, 180), _letter().substr(0, length), HORIZONTAL_ALIGNMENT_LEFT, 220, 17, -1, ci.INK)

func _envelope_art(ci, sealed: bool) -> void:
	var rect := _envelope()
	var art: Texture2D = ci.texture("round1/common/envelope_sealed.png") if sealed else null
	if art:
		ci.draw_texture_rect(art, rect, false)
	else:
		ci.draw_rect(rect, ci.WHEAT)
		ci.draw_rect(rect, ci.WOOD, false, 2)
		ci.draw_colored_polygon(PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0), rect.get_center()]), ci.PAPER)
		ci.draw_polyline(PackedVector2Array([rect.position, rect.get_center(), rect.position + Vector2(rect.size.x, 0)]), ci.WOOD, 2)
	ci.text_at(rect.position + Vector2(15, 142), name, 18, ci.INK, 230)
	if sealed and not art:
		var wax: Texture2D = ci.texture("round1/common/wax_sealed.png")
		if wax:
			ci.draw_texture_rect(wax, Rect2(rect.get_center() - Vector2(26,26), Vector2(52,52)), false)
		else:
			ci.draw_circle(rect.get_center(), 24, Color("#9e1b1b"))
			ci.draw_arc(rect.get_center(), 17, 0, TAU, 24, ci.GOLD, 2)
