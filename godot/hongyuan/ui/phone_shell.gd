extends RefCounted
## iPhone 外观：窄边框、圆角屏、胶囊前摄、侧键、底部手势条。
## 群聊、来电和 Offer 共用几何；内容和命中区域留在各自玩法。
const BODY := Rect2(12, 20, 336, 604)
const SCREEN := Rect2(22, 30, 316, 584)
const HEADER := Rect2(28, 82, 304, 48)
const LIGHT := Color("#f2f3f5")
const DARK := Color("#223143")

static func _round_box(ci: CanvasItem, rect: Rect2, color: Color, radius: int, edge := Color.TRANSPARENT, border := 0) -> void:
	var skin := StyleBoxFlat.new()
	skin.bg_color = color
	skin.set_corner_radius_all(radius)
	skin.border_color = edge
	skin.set_border_width_all(border)
	ci.draw_style_box(skin, rect)

static func draw_shell(ci: CanvasItem, dark := false, opacity := 1.0) -> void:
	_round_box(ci, BODY.grow(2), Color(0.02, 0.03, 0.05, 0.6 * opacity), 40)
	_round_box(ci, BODY, Color("#15171d") * Color(1, 1, 1, opacity), 38, Color("#787e8b") * Color(1, 1, 1, opacity), 2)
	_round_box(ci, SCREEN, Color(DARK if dark else LIGHT, opacity), 29)
	_round_box(ci, Rect2(137, 40, 86, 24), Color(0.02, 0.025, 0.035, opacity), 12)
	ci.draw_circle(Vector2(211, 52), 4, Color(0.12, 0.18, 0.25, opacity))
	ci.draw_circle(Vector2(210, 51), 1.2, Color(0.3, 0.43, 0.57, opacity))
	for side in [Rect2(9, 121, 3, 25), Rect2(9, 163, 3, 42), Rect2(9, 217, 3, 42), Rect2(348, 176, 3, 65)]:
		_round_box(ci, side, Color(0.38, 0.41, 0.46, opacity), 1)
	var ink := Color(Color("#f2f3f5") if dark else Color("#20242a"), opacity)
	# Status glyphs only: no invented story time, date or notification text.
	for i in range(4): ci.draw_rect(Rect2(271 + i * 4, 58 - i * 2, 3, 4 + i * 2), ink)
	_round_box(ci, Rect2(295, 48, 21, 11), Color.TRANSPARENT, 3, ink, 1)
	ci.draw_rect(Rect2(298, 51, 15, 5), ink)
	ci.draw_rect(Rect2(317, 51, 2, 5), ink)
	_round_box(ci, Rect2(130, 608, 100, 4), ink, 2)

static func draw_message(ci: CanvasItem, rect: Rect2, sender: String) -> void:
	var fill := Color("#c9eab7") if sender == "ayu" else Color.WHITE
	if sender == "system": fill = Color("#dde2e8")
	_round_box(ci, rect, fill, 9)
