extends Node2D
const Assets = preload("res://ayu_home/v2/assets.gd")
## Same 64×84, 16-column contract as Roman lounge_life; foot (32,84).
const UI=preload("res://ayu_home/v3/pixel_ui.gd")
const Spr = preload("res://scripts/sprites.gd")
const DIRS := ["down","left","right","up"]
var id := "ayu"
var face := "down"
var action := "idle"
var walking := false
var elapsed := 0.0
var sprite: Sprite2D
var sheet: Texture2D
var actions: Texture2D
var frames: Dictionary
var action_frames: Dictionary
var bubble: Label
var bubble_time := 0.0
var pet := false
var freeze := false
var seated_textures:Dictionary = {}
var target := Vector2.ZERO
var destination_action := "idle"
var destination_face := "down"
var route := PackedVector2Array()
var cooldown := 0.0

func setup(who: String) -> void:
	id = who
	pet = id in ["qiuqiu","luoluo","tiantian","xiduo"]
	sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = false
	add_child(sprite)
	if pet:
		sheet=Assets.texture("res://ayu_home/v3/assets/"+id+".png")
	elif id == "visitor":
		sheet = ImageTexture.create_from_image(Spr.sheet(5))
	else:
		sheet = Assets.texture("res://ayu_home/v2/assets/chr_%s.png" % id)
		frames = JSON.parse_string(FileAccess.get_file_as_string("res://ayu_home/v2/assets/chr_%s.json" % id)).frames
		if not pet:
			actions = Assets.texture("res://ayu_home/v2/assets/act_%s.png" % id)
			action_frames = JSON.parse_string(FileAccess.get_file_as_string("res://ayu_home/v2/assets/act_%s.json" % id)).frames
	bubble = Label.new()
	bubble.add_theme_font_override("font",load("res://assets/fonts/fusion-pixel-12px-proportional-zh_hans.otf.woff2"))
	bubble.add_theme_font_size_override("font_size",12)
	bubble.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	bubble.custom_minimum_size.x=144
	bubble.add_theme_color_override("font_color",Color("4a3528"))
	var box := StyleBoxFlat.new()
	box.bg_color = Color("fff9e8")
	box.border_color = Color("674b36")
	box.set_border_width_all(2);box.set_corner_radius_all(10)
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	bubble.add_theme_stylebox_override("normal",UI.box(Color("fff9e8")))
	bubble.z_index = 50
	bubble.visible = false
	add_child(bubble)
	pose()

func say(line: String) -> void:
	bubble.text = line
	bubble.position = Vector2(-72,-124 if not pet else -69)
	bubble_time = 4
	bubble.visible = true

func _process(dt: float) -> void:
	if not freeze: elapsed += dt
	bubble_time -= dt
	bubble.visible = bubble_time > 0
	cooldown = maxf(0,cooldown-dt)
	pose()

func pose() -> void:
	if not sprite: return
	if pet:
		var col:=3 if action in ["lie","sleep"] and not walking else (1+int(elapsed*6)%2 if walking else 0)
		var atlas:=AtlasTexture.new();atlas.atlas=sheet;atlas.region=Rect2(col*64,0,64,64)
		sprite.texture=atlas;sprite.position=Vector2(-24,-47);sprite.scale=Vector2(.75,.75);sprite.flip_h=face=="right"
		return
	var tex: Texture2D = sheet
	var frame := 0
	if id == "visitor":
		var a: Dictionary = Spr.PROC_ANIM[face]
		frame = int(a["idle"])
		if walking: frame = int(a["walk"][int(elapsed*8)%a["walk"].size()])
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(frame*16,0,16,32)
		sprite.texture = atlas
		sprite.scale = Vector2.ONE*(84.0/31.0)
		sprite.position = Vector2(-8*84.0/31.0,-32*84.0/31.0)
		sprite.flip_h = bool(a["flip"])
		if action == "sit":
			# Existing player silhouette: shorten only the leg rows into a bent pose.
			if not seated_textures.has(face):
				var original:Image=Spr.sheet(5)
				var seated:=Image.create(16,24,false,Image.FORMAT_RGBA8)
				seated.blit_rect(original,Rect2i(frame*16,0,16,20),Vector2i.ZERO)
				var pal:Dictionary=Spr.palette(5)
				for y in range(20,24):
					for x in range(3,13):
						if x in [7,8]:continue
						seated.set_pixel(x,y,pal["f"] if y==23 else (pal["p"] if y<22 else pal["P"]))
				seated_textures[face]=ImageTexture.create_from_image(seated)
			sprite.texture=seated_textures[face]
			sprite.position.y = -24*84.0/31.0
		return
	var seq: Array = frames.get(face,[0])
	if walking:
		frame = int(seq[int(elapsed*8)%seq.size()])
	elif action == "sit":
		seq = frames["sit_"+face]; frame = int(seq[int(elapsed)%2])
	elif pet:
		seq = frames.get("lie" if action in ["lie","sleep"] else ("sniff" if action=="sniff" else "idle"),frames.idle)
		frame = int(seq[int(elapsed*2)%seq.size()])
	elif action_frames.has(action+"_"+face):
		tex = actions; seq = action_frames[action+"_"+face]; frame = int(seq[int(elapsed*2)%seq.size()])
	elif action == "talk": frame = 18+int(elapsed*3)%2
	elif face == "down": frame = 16+int(elapsed*2)%2
	else: frame = int(seq[0])
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2((frame%16)*64,(frame/16)*84,64,84)
	sprite.texture = atlas
	sprite.position = Vector2(-32,-84)

func move_along(dt: float, speed := 100.0) -> void:
	walking = not route.is_empty()
	if route.is_empty(): return
	var next: Vector2 = route[0]
	var diff := next-position
	if diff.length() <= speed*dt:
		position = next; route.remove_at(0)
	else:
		position += diff.normalized()*speed*dt
		face = "right" if abs(diff.x)>abs(diff.y) and diff.x>0 else ("left" if abs(diff.x)>abs(diff.y) else ("down" if diff.y>0 else "up"))
	if route.is_empty():
		walking = false; action = destination_action; face = destination_face
