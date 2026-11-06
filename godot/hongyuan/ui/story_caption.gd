extends Control
## 旧步骤、scene 和电话共用的叙事字幕。输入仍交给播放器。
const FONT := preload("res://hongyuan/fonts/dialogue_font.tres")
const NAMES := {"ayu": "阿鱼", "toretto": "Toretto", "axiao": "阿晓"}
const NARRATION := Color("#202731")
const PAPER := Color("#fff1d5")
const INK := Color("#281a1a")
const GOLD := Color("#d6a456")
const WOOD := Color("#50332a")
const RED := Color("#5e2929")
var text := ""
var speaker := "narrator"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(360, 640)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _draw() -> void: draw_caption(self, text, speaker)

static func avatar(who: String) -> Texture2D:
	if not NAMES.has(who): return null
	return load("res://hongyuan/assets/%s_avatar.png" % who)

static func _display_text(full_text: String, who: String, visible_characters := -1) -> String:
	var shown := full_text if visible_characters < 0 else full_text.substr(0, visible_characters)
	var width := 244.0 if NAMES.has(who) else 296.0
	var one_line := FONT.get_string_size(full_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	# A one-character last line reads badly; use a natural pause without changing copy.
	if "\n" not in full_text and one_line > width and one_line <= width + 24:
		var split := full_text.find("，") + 1
		if split > 0 and split < shown.length(): shown = shown.insert(split, "\n")
	return shown

static func caption_rect(full_text: String, who: String) -> Rect2:
	var named := NAMES.has(who)
	var text_width := 244.0 if named else 296.0
	var text_height := FONT.get_multiline_string_size(_display_text(full_text, who), HORIZONTAL_ALIGNMENT_LEFT, text_width, 16).y
	var height := maxf(text_height + 38, 80 if named else 66)
	return Rect2(14, 604 - height, 332, height)

static func draw_caption(ci: CanvasItem, full_text: String, who: String, visible_characters := -1, next_hint := false) -> void:
	var named := NAMES.has(who)
	var box := caption_rect(full_text, who)
	var panel := StyleBoxFlat.new()
	panel.bg_color = PAPER if named else NARRATION
	panel.border_color = WOOD if named else GOLD
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(8 if named else 2)
	ci.draw_style_box(panel, box)
	var x := 70.0 if named else 18.0
	if named:
		var face := avatar(who)
		if face: ci.draw_texture_rect(face, Rect2(box.position + Vector2(14, 18), Vector2(44, 44)), false)
		var label: String = NAMES[who]
		var tag := Rect2(box.position + Vector2(x, -14), Vector2(FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 26, 28))
		var tag_skin := StyleBoxFlat.new()
		tag_skin.bg_color = RED
		tag_skin.set_corner_radius_all(14)
		ci.draw_style_box(tag_skin, tag)
		ci.draw_string(FONT, tag.position + Vector2(0, 19), label, HORIZONTAL_ALIGNMENT_CENTER, tag.size.x, 14, PAPER)
	var shown := _display_text(full_text, who, visible_characters)
	ci.draw_multiline_string(FONT, box.position + Vector2(x, 28), shown,
		HORIZONTAL_ALIGNMENT_LEFT if named else HORIZONTAL_ALIGNMENT_CENTER, box.size.x - x - 18, 16, -1, INK if named else PAPER)
	if next_hint:
		ci.draw_colored_polygon(PackedVector2Array([box.end - Vector2(24, 17), box.end - Vector2(14, 17), box.end - Vector2(19, 11)]), GOLD)
