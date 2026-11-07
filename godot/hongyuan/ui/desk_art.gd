extends RefCounted
## One physical desk shared by the opening, keepsakes, recovery and final letter.
const FONT := preload("res://hongyuan/fonts/dialogue_font.tres")
const SLOTS := ["pen", "ink", "paper", "stamp", "wax", "envelope"]
const PAPER := Rect2(120, 298, 200, 255.55)
const BODY := Rect2(-58, 58, 299, 485.875)
const SHOULDER := Vector2(128, 258)
const ARM_ROOT := Vector2(20, 20)
const ARM_TIP := Vector2(146, 130)
const PROP_POINTS := [Vector2(91, 355), Vector2(64, 396), Vector2(78, 462), Vector2(341, 333), Vector2(340, 420), Vector2(65, 524)]
static var textures: Dictionary = {}

static func texture(file: String) -> Texture2D:
	var path := "res://hongyuan/assets/" + file
	if not ResourceLoader.exists(path): return null
	if not textures.has(path): textures[path] = load(path)
	return textures[path]

static func cover(ci: CanvasItem, tex: Texture2D, area: Rect2, offset := 0.0) -> void:
	if not tex: return
	var scale := maxf(area.size.x / tex.get_width(), area.size.y / tex.get_height())
	var size := tex.get_size() * scale
	var free_y := maxf(0, size.y - area.size.y) * 0.5
	ci.draw_texture_rect(tex, Rect2(area.get_center() - size * 0.5 + Vector2(0, clampf(offset, -free_y, free_y)), size), false)

static func paper_art(ci: CanvasItem, rect := PAPER) -> void:
	var art := texture("round1/desk_r3/paper_blank.png")
	if art: ci.draw_texture_rect(art, rect, false)

static func draw_arm(ci: CanvasItem, tip: Vector2) -> void:
	var arm := texture("round1/desk_r3/ayu_pen_arm.png")
	if not arm: return
	# Pivot at the sleeve, so the hand remains joined to the shoulder and the
	# pen follows the actual writing cursor instead of floating beside the text.
	var reach := tip - SHOULDER
	var reference := ARM_TIP - ARM_ROOT
	var angle := reach.angle() - reference.angle()
	var scale := reach.length() / reference.length()
	ci.draw_set_transform(SHOULDER, angle, Vector2.ONE * scale)
	ci.draw_texture_rect(arm, Rect2(-ARM_ROOT, arm.get_size()), false)
	ci.draw_set_transform(Vector2.ZERO)

static func draw(ci: CanvasItem, materials: Dictionary, area: Rect2, focus := "", elapsed := 2.0, paper := true, writing := false) -> void:
	cover(ci, texture("round1/desk_r3/desk_bg.png"), area)
	var body := texture("round1/desk_r3/ayu_sit_writing_body.png" if writing else "round1/desk_r3/ayu_sit_existing.png")
	if body: ci.draw_texture_rect(body, BODY, false)
	# Table edge occludes knees and shoes; the upper body is sized by visible
	# alpha bounds, not the full sprite canvas (which has large empty margins).
	cover(ci, texture("round1/desk_r3/desk_foreground.png"), area)
	if paper: paper_art(ci)
	for i in range(SLOTS.size()):
		var id: String = SLOTS[i]
		if (writing and id == "pen") or not (materials.get(id, false) or id == focus): continue
		var k := clampf((elapsed - 0.25) / 0.9, 0, 1) if id == focus else 1.0
		var point: Vector2 = PROP_POINTS[i]
		if id == focus: point += Vector2(-22, -35) * (1.0 - smoothstep(0, 1, k))
		var icon := texture("round1/desk_r3/object_%s.png" % id)
		if icon: ci.draw_texture_rect(icon, Rect2(point - Vector2(21,21), Vector2(42,42)), false, Color(1,1,1,k))
	# Pets sit on the floor beneath the table, with their feet at the same depth.
	var floor_y := area.end.y - 12
	for i in range(2):
		var pet := texture("round1/desk_r3/pet_%s.png" % ("qiuqiu" if i == 0 else "xiduo"))
		if pet: ci.draw_texture_rect(pet, Rect2(28 if i == 0 else 288, floor_y - 56, 48, 56), false)
