extends RefCounted
## Coherent side-rear pixel scene, rather than separately scaled body/arm/desk.
const FONT := preload("res://hongyuan/fonts/dialogue_font.tres")
const SLOTS := ["pen", "ink", "paper", "stamp", "wax", "envelope"]
const SOURCE_SIZE := Vector2(841,1870)
const REGIONS := {"pen":Rect2(482,728,122,139), "ink":Rect2(514,470,90,114), "stamp":Rect2(712,546,85,112), "wax":Rect2(695,636,100,94), "envelope":Rect2(595,505,177,138)}
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
static func canvas(area: Rect2) -> Rect2:
	var k := maxf(area.size.x / SOURCE_SIZE.x, area.size.y / SOURCE_SIZE.y)
	var size := SOURCE_SIZE * k
	return Rect2(Vector2(area.get_center().x - size.x * 0.5, area.position.y),size)
static func head(area: Rect2) -> Vector2:
	var rect := canvas(area)
	return rect.position + Vector2(310,370) * (rect.size.x / SOURCE_SIZE.x)
static func paper_transform(area: Rect2) -> Transform2D:
	var rect := canvas(area)
	var k := rect.size.x / 360.0
	# Parallel sides follow the physical sheet's perspective. Text is intentionally
	# small in this cinematic view; the recipient later gets a readable close-up.
	return Transform2D(Vector2(0.43,0.112)*k, Vector2(-0.265,0.38)*k, rect.position + Vector2(210,270)*k)
static func paper_art(ci: CanvasItem, rect := Rect2(46,140,268,330)) -> void:
	var art := texture("round1/desk_r3/paper_blank.png")
	if art: ci.draw_texture_rect(art,rect,false)
static func draw(ci: CanvasItem, materials: Dictionary, area: Rect2, focus := "", elapsed := 2.0, _paper := true, writing := false) -> void:
	var rect := canvas(area)
	var idle := texture("round1/desk_r4/idle.png")
	var full := texture("round1/desk_r4/writing.png")
	ci.draw_texture_rect(full if writing else idle,rect,false)
	if writing: return
	var k := rect.size.x / SOURCE_SIZE.x
	for id: String in REGIONS:
		if not materials.get(id,false) and id != focus: continue
		var source: Rect2 = REGIONS[id]
		var alpha := clampf((elapsed - 0.25) / 0.9,0,1) if id == focus else 1.0
		ci.draw_texture_rect_region(full,Rect2(rect.position + source.position*k,source.size*k),source,Color(1,1,1,alpha))
