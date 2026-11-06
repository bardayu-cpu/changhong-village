extends RefCounted
const PhoneShell := preload("res://hongyuan/ui/phone_shell.gd")
var r
var lines: Array = []
var li := 0
var phase := "chat"
var t := 0.0
var chat_scroll := 0.0
var dragging := false
var last_y := 0.0

func start(runner, beat: Dictionary) -> void:
	r = runner
	lines = beat.get("lines", [])
	r.play("pop")

func process(dt: float) -> bool:
	t += dt
	return phase == "done"

func _rows() -> Array:
	var rows: Array = []
	var y := 144.0
	for i in range(mini(li + 1, lines.size())):
		var message: String = r.t_(str(lines[i].say))
		var height: float = maxf(48, r.FONT.get_multiline_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, 188, 15).y + 24)
		rows.append({"who": str(lines[i].who), "text": message, "y": y, "height": height})
		y += height + 16
	return rows

func _max_scroll() -> float:
	var rows := _rows()
	return maxf(0, float(rows[-1].y) + float(rows[-1].height) - 548) if not rows.is_empty() else 0.0

func input(kind: String, pos: Vector2) -> void:
	if phase != "chat": return
	if kind == "down":
		dragging = true
		last_y = pos.y
	elif kind == "move" and dragging:
		chat_scroll = clampf(chat_scroll + last_y - pos.y, 0, _max_scroll())
		last_y = pos.y
	elif kind == "up": dragging = false
	elif kind == "tap" and t >= 0.12:
		li += 1
		t = 0.0
		if li >= lines.size(): phase = "done"
		else:
			chat_scroll = _max_scroll()
			r.play("blip")

func draw(ci) -> void:
	ci.draw_rect(Rect2(0, 0, 360, 640), Color(0, 0, 0, 0.55))
	PhoneShell.draw_shell(ci)
	ci.text_at(Vector2(30, 111), ci.NAMES.ayu, 20, ci.INK, 300)
	ci.draw_line(Vector2(30, 130), Vector2(330, 130), Color(ci.WOOD, 0.2), 1)
	for row: Dictionary in _rows():
		var y: float = float(row.y) - chat_scroll
		if y < 140 or y + float(row.height) > 550: continue
		var own: bool = row.who == "toretto"
		var rect := Rect2(50 if own else 92, y, 216, float(row.height))
		PhoneShell.draw_message(ci, rect, "ayu" if own else "toretto")
		ci.draw_multiline_string(ci.FONT, rect.position + Vector2(14, 25), row.text, HORIZONTAL_ALIGNMENT_LEFT, 188, 15, -1, ci.INK)
		var av: Texture2D = ci.texture(ci.AVATARS[row.who])
		if av: ci.draw_texture_rect(av, Rect2(280 if own else 42, y + 4, 32, 32), false)
	ci.pill(Rect2(108, 562, 144, 32), ci.t_("G-19"), 15, ci.WOOD, ci.PAPER)
