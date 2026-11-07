extends Control
## 对话优先：在场人物用头顶气泡；旁白统一在顶部，轻透明底衬。
const FONT := preload("res://hongyuan/fonts/dialogue_font.tres")
const NAMES := {"ayu": "阿鱼", "toretto": "Toretto", "axiao": "阿晓"}
const PAPER := Color("#fff1d5")
const INK := Color("#281a1a")
const WOOD := Color("#50332a")
const RED := Color("#5e2929")
static var narration_top := 54.0
var text := ""
var speaker := "narrator"
var speaker_anchor := Vector2(-1, -1)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(360, 640)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _draw() -> void: draw_caption(self, text, speaker, -1, false, speaker_anchor)

static func avatar(who: String) -> Texture2D:
	return load("res://hongyuan/assets/%s_avatar.png" % who) if NAMES.has(who) else null

static func _display_text(full_text: String, who: String, width: float, visible_characters := -1) -> String:
	var shown := full_text if visible_characters < 0 else full_text.substr(0, visible_characters)
	var font_size := 16 if NAMES.has(who) else 15
	return wrap_text(shown,width,font_size)

static func wrap_text(shown: String, width: float, font_size: int) -> String:
	if width <= 0: return shown
	# Web's reduced TextServer does not reliably find Chinese word boundaries.
	# Measure each line explicitly so the identical copy fits native and Web.
	var lines: Array[String] = []
	for paragraph in shown.split("\n"):
		var line := ""
		for character in paragraph:
			if not line.is_empty() and FONT.get_string_size(line+character,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x > width:
				lines.append(line)
				line = ""
			line += character
		lines.append(line)
	return "\n".join(lines)

static func caption_rect(full_text: String, who: String, anchor := Vector2(-1, -1)) -> Rect2:
	full_text = _strip_emoji(full_text)
	var named := NAMES.has(who)
	if not named:
		var height := FONT.get_multiline_string_size(_display_text(full_text, who, 308), HORIZONTAL_ALIGNMENT_CENTER, 308, 15).y + 18
		return Rect2(14, narration_top, 332, maxf(38, height))
	if anchor.x >= 0:
		var width := clampf(FONT.get_string_size(full_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 28, 76, 260)
		var height := FONT.get_multiline_string_size(_display_text(full_text, who, width - 28), HORIZONTAL_ALIGNMENT_LEFT, width - 28, 16).y + 28
		return Rect2(clampf(anchor.x - width * 0.5, 12, 348 - width), maxf(narration_top - 40, anchor.y - height - 20), width, height)
	var height := FONT.get_multiline_string_size(_display_text(full_text, who, 244), HORIZONTAL_ALIGNMENT_LEFT, 244, 16).y + 38
	return Rect2(14, 604 - maxf(height, 80), 332, maxf(height, 80))

## 表情字符在 Web 包里不可靠（字体回退会画空），换成占位全角空格，字画完后在原位置贴图标
const EMOJI := {"🤔": "res://hongyuan/assets/think.svg", "😂": "res://hongyuan/assets/laugh.svg"}

static func _strip_emoji(t: String) -> String:
	for e in EMOJI:
		t = t.replace(e, "   ")
	return t

static func draw_caption(ci: CanvasItem, full_text: String, who: String, visible_characters := -1, next_hint := false, anchor := Vector2(-1, -1)) -> void:
	var icons: Array = []
	for e in EMOJI:
		var at := full_text.find(e)
		while at >= 0:
			icons.append([at, EMOJI[e]])
			at = full_text.find(e, at + 1)
	if not icons.is_empty():
		var raw := full_text
		full_text = _strip_emoji(full_text)
		_draw_caption_text(ci, full_text, who, visible_characters, next_hint, anchor)
		# 只处理一行内的表情（本作的表情都在短句末尾）
		var named := NAMES.has(who)
		var bubble := named and anchor.x >= 0
		var box := caption_rect(full_text, who, anchor)
		var inset := 14.0 if bubble else (70.0 if named else 12.0)
		var width := box.size.x - inset - (14 if bubble else (18 if named else 12))
		var fs := 16 if named else 15
		# 居中对齐时末尾空格不算宽度
		var line_w := FONT.get_string_size(full_text.strip_edges(false, true), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var x0 := box.position.x + inset + (0.0 if named else maxf(0.0, (width - line_w) * 0.5))
		for ic in icons:
			if visible_characters >= 0 and visible_characters <= int(ic[0]):
				continue
			var before := FONT.get_string_size(full_text.substr(0, int(ic[0])), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			_draw_face(ci, Vector2(x0 + before + fs * 0.5 + 3, box.position.y + (26 if named else 23) - fs * 0.35), fs * 0.5, str(ic[1]))
		return
	_draw_caption_text(ci, full_text, who, visible_characters, next_hint, anchor)

## 直接画小表情（SVG 在部分 Web 环境会画成白块）
static func _draw_face(ci: CanvasItem, c: Vector2, rad: float, kind: String) -> void:
	var ink := Color("#54353c")
	ci.draw_circle(c, rad, Color("#f6c568"))
	if kind.ends_with("think.svg"):
		ci.draw_circle(c + Vector2(-rad * 0.35, -rad * 0.15), rad * 0.13, ink)
		ci.draw_circle(c + Vector2(rad * 0.35, -rad * 0.15), rad * 0.13, ink)
		ci.draw_line(c + Vector2(-rad * 0.6, -rad * 0.5), c + Vector2(-rad * 0.15, -rad * 0.55), ink, 1.0)
		ci.draw_line(c + Vector2(-rad * 0.25, rad * 0.4), c + Vector2(rad * 0.3, rad * 0.35), ink, 1.0)
		ci.draw_circle(c + Vector2(-rad * 0.55, rad * 0.85), rad * 0.3, Color("#e8a94c"))
	else:
		ci.draw_line(c + Vector2(-rad * 0.55, -rad * 0.2), c + Vector2(-rad * 0.15, -rad * 0.35), ink, 1.0)
		ci.draw_line(c + Vector2(rad * 0.15, -rad * 0.35), c + Vector2(rad * 0.55, -rad * 0.2), ink, 1.0)
		ci.draw_circle(c + Vector2(0, rad * 0.3), rad * 0.35, Color("#633a42"))
		ci.draw_circle(c + Vector2(-rad * 0.95, 0), rad * 0.22, Color("#74c9e6"))
		ci.draw_circle(c + Vector2(rad * 0.95, 0), rad * 0.22, Color("#74c9e6"))

static func _draw_caption_text(ci: CanvasItem, full_text: String, who: String, visible_characters := -1, next_hint := false, anchor := Vector2(-1, -1)) -> void:
	var named := NAMES.has(who)
	var bubble := named and anchor.x >= 0
	var box := caption_rect(full_text, who, anchor)
	var panel := StyleBoxFlat.new()
	panel.bg_color = PAPER if named else Color(0.16, 0.12, 0.09, 0.24)
	panel.set_corner_radius_all(12 if named else 6)
	if named:
		panel.border_color = WOOD
		panel.set_border_width_all(2)
	ci.draw_style_box(panel, box)
	if bubble:
		var tail_x := clampf(anchor.x, box.position.x + 18, box.end.x - 18)
		var a := Vector2(tail_x - 7, box.end.y - 2)
		var b := Vector2(tail_x + 7, box.end.y - 2)
		var tip := Vector2(anchor.x, minf(anchor.y - 3, box.end.y + 17))
		ci.draw_colored_polygon(PackedVector2Array([a, b, tip]), PAPER)
		ci.draw_polyline(PackedVector2Array([a, tip, b]), WOOD, 2)
	var inset := 14.0 if bubble else (70.0 if named else 12.0)
	if named and not bubble:
		var face := avatar(who)
		if face: ci.draw_texture_rect(face, Rect2(box.position + Vector2(14, 18), Vector2(44, 44)), false)
		var label: String = NAMES[who]
		var tag := Rect2(box.position + Vector2(inset, -14), Vector2(FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 26, 28))
		var skin := StyleBoxFlat.new()
		skin.bg_color = RED
		skin.set_corner_radius_all(14)
		ci.draw_style_box(skin, tag)
		ci.draw_string(FONT, tag.position + Vector2(0, 19), label, HORIZONTAL_ALIGNMENT_CENTER, tag.size.x, 14, PAPER)
	var width := box.size.x - inset - (14 if bubble else (18 if named else 12))
	var shown := _display_text(full_text, who, width, visible_characters)
	var at := box.position + Vector2(inset, 26 if named else 23)
	var align := HORIZONTAL_ALIGNMENT_LEFT if named else HORIZONTAL_ALIGNMENT_CENTER
	if not named:
		ci.draw_multiline_string(FONT, at + Vector2(1, 1), shown, align, width, 15, -1, Color(0, 0, 0, 0.6))
	ci.draw_multiline_string(FONT, at, shown, align, width, 16 if named else 15, -1, INK if named else Color(1, 0.97, 0.9, 0.9))
	if next_hint and named and not bubble:
		ci.draw_colored_polygon(PackedVector2Array([box.end - Vector2(24, 17), box.end - Vector2(14, 17), box.end - Vector2(19, 11)]), WOOD)
