extends RefCounted
## 窗前的微信回忆：背景里的人拿着手机，消息轻叠在空出的地面。
## 不再盖全屏手机，也不重复绘制背景里已出现的 Toretto。
const Bubble := preload("res://hongyuan/ui/phone_shell.gd")
const CHAT_TOP := 431.0
const CHAT_BOTTOM := 600.0
const CHAT_TOUCH := Rect2(12, 414, 336, 206)
var r
var lines: Array = []
var li := 0
var phase := "chat"
var t := 0.0
var reveal := 0.0
# Previous-message offset, retained under the existing checkpoint key.
var chat_scroll := 0.0
var dragging := false
var last_y := 0.0

func start(runner, beat: Dictionary) -> void:
	r = runner
	lines = beat.get("lines", [])
	r.play("pop")

func process(dt: float) -> bool:
	t += dt
	if phase == "chat" and t > _typing_delay():
		reveal = minf(reveal + dt * 34.0, _current_text().length())
	return phase == "done"

func _current_text() -> String:
	return r.t_(str(lines[li].say)) if li < lines.size() else ""

func _typing_delay() -> float:
	return 0.55 if li < lines.size() and lines[li].who == "ayu" else 0.2

func _rows() -> Array:
	var rows: Array = []
	if lines.is_empty(): return rows
	var end := clampi(li - roundi(chat_scroll), 0, lines.size() - 1)
	var total := 0.0
	for i in range(maxi(0, end - 1), end + 1):
		var message: String = r.t_(str(lines[i].say))
		var width := clampf(r.FONT.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 28, 96, 292)
		var height: float = maxf(38, r.FONT.get_multiline_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, width - 28, 15).y + 18)
		rows.append({"index": i, "who": str(lines[i].who), "text": message, "width": width, "height": height})
		total += height + 19
	var y := maxf(CHAT_TOP, CHAT_BOTTOM - total)
	for row: Dictionary in rows:
		row.y = y
		y += float(row.height) + 19
	return rows

func input(kind: String, pos: Vector2) -> void:
	if phase != "chat": return
	if kind == "down":
		dragging = CHAT_TOUCH.has_point(pos)
		last_y = pos.y
	elif kind == "move" and dragging:
		# Pull down to older messages, push up to the latest pair. A drag never sends.
		if absf(pos.y - last_y) >= 28:
			chat_scroll = clampf(chat_scroll + signf(pos.y - last_y), 0, li)
			last_y = pos.y
	elif kind == "up": dragging = false
	elif kind == "tap" and t >= 0.12:
		if chat_scroll > 0:
			chat_scroll = 0
			return
		if reveal < _current_text().length():
			reveal = _current_text().length()
			t = maxf(t, _typing_delay())
			return
		li += 1
		t = 0.0
		reveal = 0.0
		if li >= lines.size(): phase = "done"
		else: r.play("blip")

func draw(ci) -> void:
	# No dimmer: the window, his hands and gifts stay fully visible above the chat.
	Bubble._round_box(ci, Rect2(112, 411, 136, 21), Color(1, 1, 1, 0.77), 10)
	ci.draw_circle(Vector2(125, 421), 5, Color("#66a977"))
	ci.draw_circle(Vector2(130, 424), 3.5, Color("#8fbe96"))
	ci.draw_string(ci.FONT, Vector2(140, 426), ci.t_("G-WINDOW-CHAT"), HORIZONTAL_ALIGNMENT_LEFT, 103, 12, Color("#46554b"))
	for row: Dictionary in _rows():
		var own: bool = row.who == "toretto"
		var latest: bool = int(row.index) == li
		var entering := (1.0 - clampf(t / 0.22, 0, 1)) if latest else 0.0
		var y: float = float(row.y) + entering * 6
		var x: float = 342 - float(row.width) if own else 18
		var rect := Rect2(x, y + 15, float(row.width), float(row.height))
		ci.draw_string(ci.FONT, Vector2(x + 4, y + 11), ci.NAMES[row.who], HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 6, 11, Color(0.13, 0.18, 0.15, 0.6))
		ci.draw_string(ci.FONT, Vector2(x + 3, y + 10), ci.NAMES[row.who], HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 6, 11, Color("#f6f5ed"))
		Bubble._round_box(ci, rect, Color(0.78, 0.92, 0.70, 0.96) if own else Color(1, 1, 1, 0.95), 8)
		if latest and t < _typing_delay() and reveal == 0:
			for i in range(3):
				ci.draw_circle(rect.position + Vector2(18 + i * 10, 20 + sin(t * 10 - i) * 2), 2.3, Color("#79927b"))
		else:
			var shown: String = str(row.text).substr(0, int(reveal)) if latest else str(row.text)
			ci.draw_multiline_string(ci.FONT, rect.position + Vector2(14, 22), shown, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 28, 15, -1, ci.INK)
	var hint: String = ci.t_("G-WINDOW-HISTORY" if chat_scroll > 0 else "G-WINDOW-NEXT")
	ci.text_at(Vector2(23, 624), hint, 11, Color(0.13, 0.18, 0.15, 0.6), 316)
	ci.text_at(Vector2(22, 623), hint, 11, Color("#f6f5ed"), 316)
