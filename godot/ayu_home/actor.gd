extends Node2D
const Art = preload("res://ayu_home/asset_store.gd")
static var asset_cache: Dictionary = {}
## Feet-origin actors. Art is cropped at runtime; source PNGs remain untouched.
var actor_id := "ayu"
var activity := "idle"
var direction := "down"
var walking := false
var elapsed := 0.0
var sheet: Texture2D
var frames: Array[Rect2] = []
var frame_height := 1.0
var sprite: Sprite2D
var pet := false
var target_height := 84.0
var reload_timer := 0.0
var foreground: Node2D
const SEATED := ["eat", "eating", "mahjong", "computer", "homework", "game", "tv", "read", "reading", "guitar", "playing_guitar"]

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if sprite == null:
		sprite = Sprite2D.new()
		add_child(sprite)
	foreground = Node2D.new()
	add_child(foreground)
	foreground.draw.connect(_draw_activity.bind(foreground))
	_load_sheet()

func setup(id: String) -> void:
	actor_id = id
	pet = id in ["qiuqiu", "luoluo", "tiantian", "xiduo"]
	target_height = 40.0 if id == "xiduo" else (30.0 if pet else 84.0)
	if is_inside_tree():
		_load_sheet()

func set_activity(action: String) -> void:
	activity = {"work": "workbench", "fish": "feed_fish", "garden": "watering", "pet": "sniff"}.get(action, action)
	elapsed = 0.0
	queue_redraw()

func set_direction(dir: String) -> void:
	if dir in ["down", "left", "right", "up"]:
		direction = dir

func set_walking(on: bool) -> void:
	walking = on

func _load_sheet() -> void:
	var path := "pets.png" if pet else "%s_walk.png" % (actor_id if actor_id in ["ayu", "father", "mother"] else "ayu")
	if asset_cache.has(path):
		sheet = asset_cache[path].texture
		frames.assign(asset_cache[path].frames)
		_update_height()
		_update_sprite()
		return
	var img := Art.image(path)
	if img == null or img.is_empty():
		return
	sheet = ImageTexture.create_from_image(img)
	frames.clear()
	frame_height = 1.0
	var cw := img.get_width() / 3
	var ch := img.get_height() / 4
	# Generated rows may be centered unevenly. Find separated opaque character bands.
	var bands: Array[Vector2i] = []
	var begin := -1
	var last := -1
	for y in range(img.get_height()):
		var occupied := false
		for x in range(0, img.get_width(), 4):
			if img.get_pixel(x, y).a > 0.2:
				occupied = true
				break
		if occupied:
			if begin < 0: begin = y
			last = y
		elif begin >= 0 and y - last > 2:
			bands.append(Vector2i(begin, last + 1))
			begin = -1
	if begin >= 0: bands.append(Vector2i(begin, last + 1))
	for row in range(4):
		var start := bands[row].x if bands.size() == 4 else row * ch
		var end := bands[row].y if bands.size() == 4 else (row + 1) * ch
		for col in range(3):
			frames.append(Rect2(_solid_bounds(img, Rect2i(col * cw, start, cw, end - start))))
	asset_cache[path] = {"texture": sheet, "frames": frames.duplicate()}
	_update_height()
	_update_sprite()

func _solid_bounds(img: Image, area: Rect2i) -> Rect2i:
	var lo := area.end
	var hi := area.position
	for y in range(area.position.y, area.end.y, 2):
		for x in range(area.position.x, area.end.x, 2):
			if img.get_pixel(x, y).a > 0.2:
				lo.x = mini(lo.x, x)
				lo.y = mini(lo.y, y)
				hi.x = maxi(hi.x, x + 2)
				hi.y = maxi(hi.y, y + 2)
	if hi.x <= lo.x: return area
	return Rect2i(lo, hi - lo).intersection(area)

func _update_height() -> void:
	frame_height = 1.0
	for i in range(frames.size()):
		if not pet or i / 3 == ["qiuqiu", "luoluo", "tiantian", "xiduo"].find(actor_id):
			frame_height = maxf(frame_height, frames[i].size.y)
	if sprite != null and sprite.material == null:
		var shader := Shader.new()
		shader.code = "shader_type canvas_item; void fragment(){ if(COLOR.a < 0.2){ discard; } }"
		var mat := ShaderMaterial.new()
		mat.shader = shader
		sprite.material = mat

func _process(delta: float) -> void:
	elapsed += delta
	if sheet == null:
		reload_timer += delta
		if reload_timer > 2.0:
			reload_timer = 0.0
			_load_sheet()
	_update_sprite()
	queue_redraw()
	if foreground != null: foreground.queue_redraw()

func _update_sprite() -> void:
	if sprite == null or sheet == null or frames.is_empty():
		return
	var row: int = ["down", "left", "right", "up"].find(direction)
	var col := 1
	if pet:
		row = ["qiuqiu", "luoluo", "tiantian", "xiduo"].find(actor_id)
		col = 0 if direction == "left" else (2 if direction == "right" else 1)
	elif walking:
		col = [0, 1, 2, 1][int(elapsed * 8.0) % 4]
	var region := frames[row * 3 + col]
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = region
	sprite.texture = atlas
	var unit := target_height / (frame_height if pet else region.size.y)
	sprite.scale = Vector2.ONE * unit
	sprite.position = Vector2(0, -region.size.y * unit / 2.0)
	sprite.rotation = 0.0
	if not walking and not pet and activity in SEATED:
		# Preserve the generated head/clothing, replace straight legs with bent seated legs.
		atlas.region = Rect2(region.position, Vector2(region.size.x, region.size.y * 0.70))
		sprite.position.y = -target_height + 12.0 + atlas.region.size.y * unit / 2.0
	sprite.modulate = Color.WHITE if actor_id in ["ayu", "father", "mother", "qiuqiu", "luoluo", "tiantian", "xiduo"] else Color("b7cfdb")
	if pet and activity in ["sleep", "rest", "lie"]:
		sprite.scale *= Vector2(1.05, 0.70)
		sprite.position.y = -region.size.y * unit * 0.35
	elif activity in ["sleep", "rest", "lie"]:
		sprite.rotation = -PI / 2.0
		sprite.position = Vector2(-target_height * 0.35, -12)
	elif activity == "record":
		sprite.rotation = sin(elapsed * 2.5) * 0.035
	elif pet:
		if walking:
			sprite.scale *= Vector2(1 + sin(elapsed * 12) * 0.045, 1 - sin(elapsed * 12) * 0.055)
		elif activity in ["sniff", "sniffing"]:
			sprite.rotation = sin(elapsed * 4) * 0.11
			sprite.position.y += 3

func _draw() -> void:
	draw_ellipse_shadow()

func _draw_activity(canvas: Node2D) -> void:
	if walking:
		if pet:
			# Independent alternating paws; the body never supplies the gait by translation.
			var stride := sin(elapsed * 12) * 4
			var fur := Color("8f8b7e") if actor_id == "qiuqiu" else Color("bb874d")
			for side in [-1, 1]:
				canvas.draw_line(Vector2(side * 7, -8), Vector2(side * 7 + stride * side, -1), fur, 4)
		return
	if not pet and activity in SEATED:
		_draw_seated_legs(canvas)
	var mirror := -1.0 if direction == "left" else 1.0
	var offset := Vector2(0, 12) if not pet and activity in SEATED else Vector2.ZERO
	if activity not in ["sleep", "rest", "lie"] and not pet:
		canvas.draw_set_transform(offset, 0, Vector2(mirror, 1))
	var pulse := sin(elapsed * 5.0)
	var skin := Color("e9b088")
	var wood := Color("98623c")
	if pet and activity in ["sleep", "rest", "lie"]:
		canvas.draw_arc(Vector2(12, -target_height + 5), 3, 0, PI, 8, Color("d9c39b"), 1)
	elif activity in ["sleep", "rest", "lie"]:
		canvas.draw_rect(Rect2(-64, -17, 70, 14), Color("c8dba4"))
		canvas.draw_string(ThemeDB.fallback_font, Vector2(7, -32 - sin(elapsed) * 3), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("f1deb0"))
	elif activity in ["greeting", "talk"]:
		_arm(canvas, Vector2(11, -54), Vector2(23, -57 - pulse * 7))
		canvas.draw_circle(Vector2(23, -57 - pulse * 7), 3, skin)
	elif activity == "record":
		canvas.draw_circle(Vector2(29, -46), 9, Color("4c5147"))
		canvas.draw_circle(Vector2(29, -46), 3, Color("bf9766"))
		_arm(canvas, Vector2(10, -50), Vector2(16, -40 + pulse * 2))
		canvas.draw_arc(Vector2(29, -46), 14, -0.5, 0.5, 10, Color("c2c998"), 2)
	elif pet:
		if activity in ["sniff", "sniffing"]:
			canvas.draw_arc(Vector2(18, -4), 5 + pulse, 0, PI, 8, Color("c4bc93"), 1)
	elif activity in ["guitar", "playing_guitar"]:
		canvas.draw_line(Vector2(6, -39), Vector2(28, -55), Color("3e2a20"), 9)
		canvas.draw_line(Vector2(6, -39), Vector2(28, -55), Color("a77b45"), 5)
		canvas.draw_circle(Vector2(8, -44), 8, Color("493024"))
		canvas.draw_circle(Vector2(8, -44), 7, Color("b7844e"))
		canvas.draw_circle(Vector2(3, -36), 12, Color("493024"))
		canvas.draw_circle(Vector2(3, -36), 11, Color("bd8d52"))
		canvas.draw_arc(Vector2(3, -36), 9, 0.4, 2.5, 14, Color("d6ac71"), 1)
		canvas.draw_circle(Vector2(5, -40), 5, Color("d3ac70"))
		canvas.draw_circle(Vector2(5, -40), 4, Color("38281f"))
		canvas.draw_rect(Rect2(-4, -33, 10, 2), Color("62402b"))
		for n in range(3):
			canvas.draw_line(Vector2(-2 + n, -32), Vector2(27 + n, -54), Color("e9d4a3"), 1)
		for fret in range(4):
			var p := Vector2(13, -44).lerp(Vector2(26, -54), fret / 3.0)
			canvas.draw_line(p + Vector2(-1, -2), p + Vector2(2, 1), Color("765535"), 1)
		_arm(canvas, Vector2(-12, -49), Vector2(5, -38 + pulse * 3))
	elif activity in ["cooking", "cook", "eating", "eat", "feed_fish", "feeding", "watering"]:
		var end := Vector2(18, -40 + pulse * 5)
		_arm(canvas, Vector2(10, -54), end)
		if activity in ["cooking", "cook"]:
			canvas.draw_circle(Vector2(22, -33), 10, Color("252d2b"))
			canvas.draw_circle(Vector2(22, -33), 8, Color("667063"))
			canvas.draw_arc(Vector2(22, -33), 7, 3.4, 5.9, 14, Color("a1aa8b"), 1)
			canvas.draw_circle(Vector2(21, -34), 3, Color("d5a35d"))
			canvas.draw_circle(Vector2(26, -31), 2, Color("849b64"))
			canvas.draw_line(end, Vector2(28, -29), Color("4b3528"), 4)
			canvas.draw_line(end, Vector2(28, -29), Color("b28a51"), 2)
		elif activity == "watering":
			canvas.draw_arc(Vector2(13, -31), 5, 1.5, 4.8, 12, Color("345347"), 3)
			canvas.draw_rect(Rect2(13, -38, 16, 14), Color("345347"))
			canvas.draw_rect(Rect2(14, -37, 14, 12), Color("64917c"))
			canvas.draw_rect(Rect2(15, -36, 3, 9), Color("90b69a"))
			canvas.draw_line(Vector2(26, -32), Vector2(35, -28), Color("345347"), 4)
			canvas.draw_line(Vector2(26, -32), Vector2(35, -28), Color("83aa91"), 2)
			for drop in range(3):
				canvas.draw_line(Vector2(36 + drop * 3, -26 + drop * 3), Vector2(37 + drop * 3, -24 + drop * 3), Color("98c7cd"), 1)
		elif activity in ["feed_fish", "feeding"]:
			canvas.draw_rect(Rect2(-13, -38, 9, 12), Color("81623e"))
			canvas.draw_rect(Rect2(-12, -37, 7, 10), Color("d4ba80"))
			canvas.draw_line(Vector2(-12, -35), Vector2(-6, -35), Color("f3dd9f"), 1)
			for crumb in range(3):
				canvas.draw_rect(Rect2(18 + crumb * 4, -29 + crumb * 5 + pulse * 2, 2, 2), Color("b88245"))
		else:
			canvas.draw_circle(Vector2(20, -34), 8, Color("80684b"))
			canvas.draw_circle(Vector2(20, -35), 7, Color("f2e3bf"))
			canvas.draw_arc(Vector2(20, -35), 5, 0.0, PI, 12, Color("d9c6a3"), 2)
			canvas.draw_line(end, Vector2(6, -57), wood, 2)
	elif activity in ["homework", "reading", "read", "computer", "game", "tv", "workbench", "mahjong", "cleaning", "clean"]:
		_arm(canvas, Vector2(-10, -52), Vector2(-7, -36 + pulse * 2))
		_arm(canvas, Vector2(10, -52), Vector2(17 + pulse * 5, -36))
		if activity == "homework":
			canvas.draw_rect(Rect2(6, -42, 24, 18), Color("f7efd6"))
			for n in range(3): canvas.draw_line(Vector2(9, -37 + n * 4), Vector2(23, -37 + n * 4), Color("bfb399"), 1)
			canvas.draw_line(Vector2(17 + pulse * 4, -43), Vector2(13 + pulse * 4, -31), Color("b38e4f"), 2)
		elif activity in ["reading", "read"]:
			canvas.draw_rect(Rect2(-11, -40, 27, 16), Color("b79566"))
			canvas.draw_line(Vector2(2, -40), Vector2(2, -24), Color("f2dfb5"), 2)
		elif activity in ["cleaning", "clean"]:
			canvas.draw_line(Vector2(16, -41), Vector2(27 + pulse * 7, -2), wood, 3)
			canvas.draw_rect(Rect2(18 + pulse * 7, -5, 20, 5), Color("d5b46a"))
		elif activity == "mahjong":
			var cycle := fmod(elapsed, 1.2)
			var reach := lerpf(28, 8, cycle / 0.6) if cycle < 0.6 else lerpf(8, -8, minf((cycle - 0.6) / 0.3, 1))
			_arm(canvas, Vector2(10, -52), Vector2(reach, -33))
			for tile in range(3):
				canvas.draw_rect(Rect2(-12 + tile * 8, -25, 6, 8), Color("f7eed6"))
				canvas.draw_circle(Vector2(-9 + tile * 8, -22), 1, Color("60836d"))
			canvas.draw_rect(Rect2(reach - 3, -36 if cycle < 0.9 else -27, 7, 10), Color("f7eed6"))
			canvas.draw_circle(Vector2(reach, -32 if cycle < 0.9 else -23), 1.5, Color("60836d"))
		elif activity == "workbench":
			canvas.draw_line(Vector2(15, -37), Vector2(20, -46 + pulse * 6), Color("513b2b"), 5)
			canvas.draw_line(Vector2(15, -37), Vector2(20, -46 + pulse * 6), Color("a17a4d"), 3)
			canvas.draw_line(Vector2(15, -38), Vector2(19, -47 + pulse * 6), Color("cfac70"), 1)
			canvas.draw_rect(Rect2(14, -49 + pulse * 6, 14, 7), Color("394544"))
			canvas.draw_rect(Rect2(15, -48 + pulse * 6, 12, 5), Color("818e87"))
			canvas.draw_line(Vector2(16, -47 + pulse * 6), Vector2(25, -47 + pulse * 6), Color("b6c1b1"), 1)
		else:
			canvas.draw_rect(Rect2(-12, -34, 30, 7), Color("59666b"))

	canvas.draw_set_transform(Vector2.ZERO)

func draw_ellipse_shadow() -> void:
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.28))
	draw_circle(Vector2.ZERO, target_height * 0.2, Color(0.16, 0.12, 0.07, 0.2))
	draw_set_transform(Vector2.ZERO)

func _draw_seated_legs(canvas: Node2D) -> void:
	var trousers := Color("25282c") if actor_id in ["ayu", "visitor"] else Color("2d394b")
	var outline := Color("151e29")
	var side := -1 if direction == "left" else (1 if direction == "right" else 0)
	if actor_id == "mother":
		var hem := PackedVector2Array([Vector2(-12, -20), Vector2(12, -20), Vector2(17 + side * 5, -4), Vector2(-17 + side * 5, -4)])
		canvas.draw_colored_polygon(hem, outline)
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(-11, -19), Vector2(11, -19), Vector2(15 + side * 5, -5), Vector2(-15 + side * 5, -5)]), trousers)
		for fold in [-7, 0, 7]: canvas.draw_line(Vector2(fold, -17), Vector2(fold + side * 3, -6), Color("44516a"), 1)
	else:
		canvas.draw_rect(Rect2(-12, -20, 24, 14), outline)
		canvas.draw_rect(Rect2(-11, -19, 22, 12), trousers)
		canvas.draw_line(Vector2(0, -18), Vector2(0, -7), Color("141c24"), 1)
	if side != 0:
		for y in [-10, -7]:
			canvas.draw_line(Vector2(0, y), Vector2(side * 15, y + 3), outline, 7)
			canvas.draw_line(Vector2(0, y), Vector2(side * 15, y + 3), trousers, 5)
			canvas.draw_line(Vector2(3 * side, y - 1), Vector2(side * 13, y + 2), Color("455168"), 1)
			canvas.draw_line(Vector2(side * 15, y + 3), Vector2(side * 15, 0), outline, 5)
			canvas.draw_line(Vector2(side * 15, y + 3), Vector2(side * 15, 0), Color("d4a079") if actor_id == "mother" else trousers, 3)
			_shoe(canvas, Vector2(side * 15, 0), actor_id == "mother")
	else:
		for x in [-8, 8]:
			canvas.draw_line(Vector2(x, -12), Vector2(x, -1), outline, 7)
			canvas.draw_line(Vector2(x, -12), Vector2(x, -1), trousers, 5)
			if actor_id == "mother": canvas.draw_line(Vector2(x, -3), Vector2(x, 0), Color("d4a079"), 2)
			_shoe(canvas, Vector2(x, 0), actor_id == "mother")

func _shoe(canvas: Node2D, at: Vector2, feminine: bool) -> void:
	canvas.draw_rect(Rect2(at + Vector2(-5, -1), Vector2(11, 5)), Color("22211f"))
	canvas.draw_rect(Rect2(at + Vector2(-4, 0), Vector2(9, 3)), Color("785641") if feminine else Color("454749"))
	canvas.draw_line(at + Vector2(-2, 0), at + Vector2(3, 0), Color("ae8360") if feminine else Color("767879"), 1)
	if actor_id in ["ayu", "visitor"]: canvas.draw_line(at + Vector2(-4, 3), at + Vector2(5, 3), Color("e8dfce"), 1)

func _arm(canvas: Node2D, start: Vector2, end: Vector2) -> void:
	var a := start.round()
	var b := end.round()
	canvas.draw_line(a, b, Color("644434"), 6)
	canvas.draw_line(a, b, Color("d9966d"), 4)
	canvas.draw_line(a + Vector2(-0.7, -0.7), b + Vector2(-0.7, -0.7), Color("eeb88b"), 2)
	canvas.draw_circle(b, 3, Color("644434"))
	canvas.draw_circle(b + Vector2(0, -0.5), 2, Color("e7aa7d"))
	canvas.draw_line(b + Vector2(-1, -1), b + Vector2(1, -1), Color("f2c396"), 1)
