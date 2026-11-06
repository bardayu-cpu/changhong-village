extends Control
## 对话优先：在场人物用头顶气泡；旁白统一在顶部，轻透明底衬。
const FONT := preload("res://hongyuan/fonts/dialogue_font.tres")
const NAMES := {"ayu": "阿鱼", "toretto": "Toretto", "axiao": "阿晓"}
const PAPER := Color("#fff1d5")
const INK := Color("#281a1a")
const WOOD := Color("#50332a")
const RED := Color("#5e2929")
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
	var one_line := FONT.get_string_size(full_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if "\n" not in full_text and one_line > width and one_line <= width + 24:
		var split := full_text.find("，") + 1
		if split > 0 and split < shown.length(): shown = shown.insert(split, "\n")
	return shown

static func caption_rect(full_text: String, who: String, anchor := Vector2(-1, -1)) -> Rect2:
	var named := NAMES.has(who)
	if not named:
		var height := FONT.get_multiline_string_size(_display_text(full_text, who, 308), HORIZONTAL_ALIGNMENT_CENTER, 308, 15).y + 18
		return Rect2(14, 54, 332, maxf(38, height))
	if anchor.x >= 0:
		var width := clampf(FONT.get_string_size(full_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 28, 76, 260)
		var height := FONT.get_multiline_string_size(_display_text(full_text, who, width - 28), HORIZONTAL_ALIGNMENT_LEFT, width - 28, 16).y + 28
		return Rect2(clampf(anchor.x - width * 0.5, 12, 348 - width), maxf(54, anchor.y - height - 20), width, height)
	var height := FONT.get_multiline_string_size(_display_text(full_text, who, 244), HORIZONTAL_ALIGNMENT_LEFT, 244, 16).y + 38
	return Rect2(14, 604 - maxf(height, 80), 332, maxf(height, 80))

static func draw_caption(ci: CanvasItem, full_text: String, who: String, visible_characters := -1, next_hint := false, anchor := Vector2(-1, -1)) -> void:
	var named := NAMES.has(who)
	var bubble := named and anchor.x >= 0
	var box := caption_rect(full_text, who, anchor)
	var panel := StyleBoxFlat.new()
	panel.bg_color = PAPER if named else Color(0.08, 0.07, 0.06, 0.18)
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
