extends RefCounted
## 书桌 + 笔记本电脑 + 阿鱼的背影（过肩视角）。G0 看英文 Offer 和 F4 写邀请邮件共用。
## 所有坐标是 360×640 逻辑画布；屏幕内容由各自的玩法画在 SCREEN 里。
const SCREEN := Rect2(30, 108, 300, 220)
const LID := Rect2(18, 94, 324, 244)
const INK := Color("#281a1a")
const BACK_TEX := "w2/common/ayu_idle_back.png"
const BACK_USED := Rect2(37, 8, 54, 192)
const BACK_H := 300.0
const BACK_FEET_Y := 652.0

static func _round(ci: CanvasItem, rect: Rect2, color: Color, radius: int, edge := Color.TRANSPARENT, border := 0) -> void:
	var skin := StyleBoxFlat.new()
	skin.bg_color = color
	skin.set_corner_radius_all(radius)
	skin.border_color = edge
	skin.set_border_width_all(border)
	ci.draw_style_box(skin, rect)


## 房间、桌面、台灯、杯子：整屏背景。
static func draw_room(ci: CanvasItem, time: float) -> void:
	for i in range(16):
		var k := i / 15.0
		ci.draw_rect(Rect2(0, i * 22, 360, 23), Color("#2c2433").lerp(Color("#3d3040"), k))
	# 桌面
	ci.draw_rect(Rect2(0, 344, 360, 296), Color("#7a553d"))
	for y in range(356, 640, 26):
		ci.draw_line(Vector2(0, y), Vector2(360, y), Color("#6a4732"), 1.0)
	ci.draw_rect(Rect2(0, 344, 360, 4), Color("#9a7152"))
	# 台灯（右）
	ci.draw_rect(Rect2(318, 306, 4, 40), Color("#2a2a32"))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(300, 282), Vector2(340, 282), Vector2(332, 306), Vector2(308, 306)]), Color("#d8a24a"))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(304, 306), Vector2(336, 306), Vector2(352, 346), Vector2(288, 346)]), Color(1.0, 0.86, 0.5, 0.12))
	# 杯子（左）
	ci.draw_rect(Rect2(12, 372, 20, 22), Color("#e8e0d2"))
	ci.draw_rect(Rect2(12, 372, 20, 22), INK, false, 2.0)
	ci.draw_rect(Rect2(32, 377, 6, 10), INK, false, 2.0)
	for i in range(2):
		var k := fposmod(time * 0.4 + i * 0.5, 1.0)
		ci.draw_circle(Vector2(22 + sin(time * 2 + i) * 2, 368 - k * 18), 2.5, Color(1, 1, 1, 0.3 * (1.0 - k)))


## 笔记本：屏幕盖 + 屏幕底 + 键盘面。屏幕内容之后由调用方画在 SCREEN 里。
static func draw_laptop(ci: CanvasItem, glow := 1.0) -> void:
	_round(ci, LID.grow(3), Color(0, 0, 0, 0.35), 12)
	_round(ci, LID, Color("#1d2028"), 10, Color("#8a8f9c"), 2)
	ci.draw_rect(SCREEN, Color("#f5f7fb"))
	ci.draw_circle(Vector2(180, 101), 2.0, Color("#3a4a60"))
	# 屏幕的微光洒在桌面
	ci.draw_rect(Rect2(20, 342, 320, 6), Color(0.8, 0.9, 1.0, 0.18 * glow))
	# 机身底座（略带透视）
	ci.draw_colored_polygon(PackedVector2Array([Vector2(12, 338), Vector2(348, 338), Vector2(368, 380), Vector2(-8, 380)]), Color("#aeb4c0"))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(12, 338), Vector2(348, 338), Vector2(350, 342), Vector2(10, 342)]), Color("#6f7583"))
	for row in range(3):
		var y := 350.0 + row * 8.0
		for i in range(14):
			var x := 24.0 + i * 22.0 - row * 3.0
			ci.draw_rect(Rect2(x, y, 17, 5), Color("#d9dde5"))
	ci.draw_rect(Rect2(150, 374, 60, 3), Color("#8d93a1"))


## 过肩：阿鱼的背影坐在椅子里，椅背盖住下半身。
static func draw_ayu_back(ci) -> void:
	var tex: Texture2D = ci.texture(BACK_TEX)
	var k := BACK_H / BACK_USED.size.y
	var w := BACK_USED.size.x * k
	if tex:
		ci.draw_texture_rect_region(tex, Rect2(180.0 - w * 0.5, BACK_FEET_Y - BACK_H, w, BACK_H), BACK_USED)
	else:
		ci.draw_rect(Rect2(150, 360, 60, 300), Color("#2a1a1a"))
	_round(ci, Rect2(104, 520, 152, 140), Color("#2f2b3a"), 22, Color("#4a4560"), 3)
	_round(ci, Rect2(116, 532, 128, 16), Color(1, 1, 1, 0.06), 8)


## 按宽度手动折行（英文按空格，中文逐字）。
static func wrap(ci, text: String, width: float, size: int) -> Array:
	var out: Array = []
	for para in text.split("\n"):
		var line := ""
		var tokens: PackedStringArray = para.split(" ") if " " in para else para.split("")
		var joiner := " " if " " in para else ""
		for tok in tokens:
			var trial := tok if line == "" else line + joiner + tok
			if line != "" and ci.FONT.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
				out.append(line)
				line = tok
			else:
				line = trial
		out.append(line)
	return out


## 邮件窗口的标题栏：三个圆点 + 标题（可空）。
static func draw_window_bar(ci, title := "") -> void:
	ci.draw_rect(Rect2(SCREEN.position, Vector2(SCREEN.size.x, 22)), Color("#dfe4ee"))
	for i in range(3):
		ci.draw_circle(SCREEN.position + Vector2(12 + i * 12, 11), 3.5, [Color("#ee6a5f"), Color("#f5bd4f"), Color("#61c454")][i])
	if title != "":
		ci.text_at(SCREEN.position + Vector2(0, 16), title, 12, Color("#3a4150"), SCREEN.size.x)
