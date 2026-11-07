extends RefCounted
## Shared desk composition for opening, each keepsake, recovery and the last letter.
const FONT := preload("res://hongyuan/fonts/dialogue_font.tres")
const SLOTS := ["pen", "ink", "paper", "stamp", "wax", "envelope"]
static var textures: Dictionary = {}

static func texture(file: String) -> Texture2D:
	var path := "res://hongyuan/assets/" + file
	if not ResourceLoader.exists(path):
		return null
	if not textures.has(path):
		textures[path] = load(path)
	return textures[path]

static func cover(ci: CanvasItem, tex: Texture2D, area: Rect2, offset := 0.0) -> void:
	if not tex:
		return
	var scale := maxf(area.size.x / tex.get_width(), area.size.y / tex.get_height())
	var size := tex.get_size() * scale
	var free_y := maxf(0, size.y - area.size.y) * 0.5
	ci.draw_texture_rect(tex, Rect2(area.get_center() - size * 0.5 + Vector2(0, clampf(offset, -free_y, free_y)), size), false)

static func draw(ci: CanvasItem, materials: Dictionary, area: Rect2, focus := "", elapsed := 2.0, paper := true) -> void:
	var desk := texture("round1/common/bg_desk.png")
	if not desk:
		desk = texture("bg_invite_desk.png")
	cover(ci, desk, area)
	if paper:
		var card := texture("round1/common/letter_blank.png")
		if card:
			ci.draw_texture_rect(card, Rect2(70, 242, 220, 281), false)
	for i in range(SLOTS.size()):
		var id: String = SLOTS[i]
		var on := bool(materials.get(id, false))
		var k := clampf((elapsed - 0.25) / 0.9, 0, 1) if id == focus else 1.0
		var point := Vector2(88 + i * 36.5, 494)
		if id == focus:
			on = true
			point += Vector2(-36, -60) * (1.0 - smoothstep(0, 1, k))
		if on:
			var icon := texture("round1/common/item_%s.png" % id)
			if not icon:
				icon = texture("w2/finale/slot_%s.png" % id)
			if icon:
				ci.draw_texture_rect(icon, Rect2(point - Vector2(19, 19), Vector2(38, 38)), false, Color(1,1,1,k))
			elif id in ["pen", "ink"]:
				if id == "pen":
					ci.draw_line(point + Vector2(-7, 11), point + Vector2(7, -11), Color("#742a31", k), 5)
					ci.draw_circle(point + Vector2(8, -12), 3, Color("#d5ae62", k))
				else:
					ci.draw_rect(Rect2(point - Vector2(10, 5), Vector2(20, 17)), Color("#482a42", k))
					ci.draw_rect(Rect2(point - Vector2(6, 12), Vector2(12, 7)), Color("#b38b50", k))
		else:
			ci.draw_arc(point, 18, 0, TAU, 24, Color("#a27f57", 0.35), 1)
	# The pet positions advance with the keepsakes; no new named people or story facts.
	var count := 0
	for id in SLOTS:
		if materials.get(id, false) or id == focus:
			count += 1
	var pet := texture("round1/common/pet.png")
	if pet:
		var at := Vector2(40 + count * 39, 602 + sin(elapsed * 1.4) * 1.2)
		var frame := 3 if count % 2 == 0 else int(elapsed * 2.0) % 2
		ci.draw_texture_rect_region(pet, Rect2(at - Vector2(24,24), Vector2(48,48)), Rect2(frame * 64, 0, 64, 64))
