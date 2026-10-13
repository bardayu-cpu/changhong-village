extends Node2D
const Assets = preload("res://ayu_home/v2/assets.gd")
## Same 64×84, 16-column contract as Roman lounge_life; foot (32,84).
const UI=preload("res://ayu_home/v4/pixel_ui.gd")
const Spr = preload("res://scripts/sprites.gd")
const DIRS := ["down","left","right","up"]
var id := "ayu"
var preset := 2
var chosen_look:Dictionary={}
var look_override:Dictionary={}
var movement_distance:=0.0
var face := "down"
var action := "idle"
var walking := false
var elapsed := 0.0
var sprite: Sprite2D
var pose_texture:=AtlasTexture.new()
var sheet: Texture2D
var actions: Texture2D
var frames: Dictionary
var action_frames: Dictionary
var bed_anchors: Dictionary = {}
var bubble: Label
var bubble_tail: Sprite2D
var bubble_time := 0.0
var bubble_allowed:=true
var pet := false
var freeze := false
var seated_textures:Dictionary = {}
var target := Vector2.ZERO
var destination_action := "idle"
var destination_face := "down"
var route := PackedVector2Array()
var cooldown := 0.0
## 坐、躺时人画在家具上：排序点放在家具前沿，画面往上抬回座位（lift）。
var lift := 0.0
var blanket := Color(0,0,0,0)
var quilt_tex:Texture2D
var quilt_region:=Rect2()
var in_bed := false # 家人睡觉、休息时躺在床上（和玩家躺床同一套画法）
var head_down := false # 床头朝下的床（新一楼爸妈的床）：头枕在下面的枕头上，脸照常朝上，身子在上面的花被子里

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
		chosen_look=look_override if not look_override.is_empty() else Spr.gpt_look(preset)
		sheet = chosen_look.tex if chosen_look.has("tex") else ImageTexture.create_from_image(Spr.sheet(preset))
	else:
		sheet = Assets.texture("res://ayu_home/v2/assets/chr_%s.png" % id)
		frames = JSON.parse_string(FileAccess.get_file_as_string("res://ayu_home/v2/assets/chr_%s.json" % id)).frames
		if not pet:
			actions = Assets.texture("res://ayu_home/v2/assets/act_%s.png" % id)
			var action_data:Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://ayu_home/v2/assets/act_%s.json" % id))
			action_frames = action_data.frames
			bed_anchors = action_data.get("bed_anchors",{})
	bubble = Label.new()
	bubble.add_theme_font_override("font",load("res://assets/fonts/fusion-pixel-12px-proportional-zh_hans.otf.woff2"))
	bubble.add_theme_font_size_override("font_size",12)
	bubble.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	# 头顶话泡照罗曼（组件库第 5 条）：白底、深边 2 格、胶囊圆角、深色字、下面小尾巴；一格 1 个画布像素（屏幕上 2 像素，跟罗曼一样）
	# 颜色从共用 dialog_skin.gd 的 PAL 取（村-8）
	var DSkin=load("res://scripts/ui/dialog_skin.gd")
	var fill:=Color(DSkin.PAL.bubble.fill);var edge:=Color(DSkin.PAL.bubble.edge)
	bubble.add_theme_color_override("font_color",Color(DSkin.PAL.bubble_text))
	var white:StyleBoxTexture=DSkin.pixel_box(fill,edge,null,9,1,2)
	white.set_content_margin(SIDE_LEFT,8);white.set_content_margin(SIDE_RIGHT,8);white.set_content_margin(SIDE_TOP,4);white.set_content_margin(SIDE_BOTTOM,5)
	bubble.add_theme_stylebox_override("normal",white)
	bubble_tail=Sprite2D.new();bubble_tail.texture=DSkin.tail_tex(fill,edge);bubble_tail.centered=false;bubble_tail.scale=Vector2(.5,.5);bubble_tail.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;bubble.add_child(bubble_tail)
	bubble.z_index = 150 # 比桌上的菜（atmosphere 那层 100）更上面
	bubble.visible = false
	add_child(bubble)
	pose()

func say(line: String) -> void:
	bubble.text = ""
	fit_bubble(BUBBLE_MAX,line)
	bubble.text = line
	bubble.position = Vector2(-bubble.size.x*.5,head_top()-bubble.size.y-6)
	bubble_time = 4
	bubble.visible = true

## 画出来的头顶离脚底多高（坐、躺、宠物各不一样），话泡要整个放在它上面。
func head_top() -> float:
	if pet:return -47.0-lift
	if id=="mother" and in_bed and not walking:return -28.0-lift
	if (in_bed or action in ["sleep","lie"]) and not walking:return -40.0-lift
	if action in ["sit","eat","drink","read","computer","tv","guitar","swing","record","mahjong"] and not walking:return -64.0-lift # 录东西是坐着的（画面里头顶在 22 像素处）
	return -86.0-lift

## 话泡宽度跟着字走：字少就窄，字多到 max_w 就换行变高（max_w 是画布像素，屏幕上乘 2）
const BUBBLE_MAX:=140.0
func fit_bubble(max_w:float,line:="") -> void:
	var text:String=line if not line.is_empty() else bubble.text
	var f:Font=bubble.get_theme_font("font");var tw:float=f.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
	var w:float=clampf(ceilf(tw)+18.0,36.0,max_w)
	# 高度自己算（自动换行的 Label 量高度要等下一帧，当帧量会按很窄的宽度算出一长条）
	var lines:float=f.get_multiline_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,w-16.0,12,-1,TextServer.BREAK_MANDATORY|TextServer.BREAK_WORD_BOUND|TextServer.BREAK_GRAPHEME_BOUND).y
	var hgt:float=ceilf(lines)+9.0
	# 先定宽再放字（先放字的话，这一帧 Label 会按旧宽度量出一长条，撑大一帧）
	if not line.is_empty():bubble.text=""
	bubble.custom_minimum_size=Vector2(w,hgt);bubble.size=Vector2(w,hgt)
## 尾巴尖对着 tip_x（话泡里的横坐标）；放在人身旁时不要尾巴
func set_tail(tip_x:float,show:bool) -> void:
	bubble_tail.visible=show
	bubble_tail.position=Vector2(clampf(tip_x,10.0,bubble.size.x-10.0)-3.5,bubble.size.y-2.0)
func _process(dt: float) -> void:
	if not freeze: elapsed += dt
	bubble_time -= dt
	bubble.visible = bubble_time > 0 and bubble_allowed
	cooldown = maxf(0,cooldown-dt)
	pose()

func pose() -> void:
	if not sprite: return
	sprite.rotation=0;sprite.scale=Vector2.ONE;sprite.flip_h=false;sprite.flip_v=false
	queue_redraw()
	if pet:
		var col:=3 if action in ["lie","sleep"] and not walking else (1+int(elapsed*6)%2 if walking else 0)
		var atlas:=pose_texture;atlas.atlas=sheet;atlas.region=Rect2(col*64,0,64,64)
		sprite.texture=atlas;sprite.position=Vector2(-24,-47-lift);sprite.scale=Vector2(.75,.75);sprite.flip_h=face=="right"
		return
	var tex: Texture2D = sheet
	var frame := 0
	if id == "visitor":
		var anim:Dictionary=chosen_look.get("anim",Spr.PROC_ANIM)
		var a:Dictionary=anim[face];frame=int(a.idle)
		if walking:frame=int(a.walk[int(elapsed*8)%a.walk.size()])
		var fw:int=int(chosen_look.get("frame_w",16));var fh:int=int(chosen_look.get("frame_h",32))
		var atlas:=pose_texture;atlas.atlas=sheet;atlas.region=Rect2(frame*fw,0,fw,fh)
		var sitting:bool=action in ["sit","eat","drink","read","computer","tv","guitar","swing"] and not walking
		if sitting:atlas.region.size.y=floor(fh*.72)
		sprite.texture=atlas;sprite.scale=Vector2.ONE*(84.0/fh);sprite.flip_h=bool(a.get("flip",false))
		if action in ["sleep","lie"] and not walking:
			# 躺在床上：正脸朝上，只露出头和肩，下半身盖在被子里（不再横着画到床底下）。
			var lying:Dictionary=anim.down
			frame=int(lying.idle);atlas.region=Rect2(frame*fw,0,fw,floor(fh*.4));sprite.flip_h=bool(lying.get("flip",false))
		sprite.position=Vector2(-fw*.5*84.0/fh,(12.0-atlas.region.size.y*84.0/fh if head_down and action in ["sleep","lie"] and not walking else -atlas.region.size.y*84.0/fh)-lift)
		if action=="swing":sprite.position.y+=sin(elapsed*.85)*3
		return
	var seq: Array = frames.get(face,[0])
	if id=="mother" and in_bed and not walking:
		var bed_key:String=("sleep" if action=="sleep" else "lie")+("_down" if head_down else "_up")
		var bed_seq:Array=action_frames.get(bed_key,[])
		if not bed_seq.is_empty():
			var bed_index:int=int(bed_seq[int(elapsed*2)%bed_seq.size()])
			pose_texture.atlas=actions;pose_texture.region=Rect2((bed_index%16)*64,(bed_index/16)*84,64,84)
			sprite.texture=pose_texture
			var head_anchor:Array=bed_anchors.get(bed_key,[32,66 if head_down else 18])
			sprite.position=-Vector2(float(head_anchor[0]),float(head_anchor[1]))-Vector2(0,lift)
			return
	if in_bed and not walking:
		# 只露出头和肩，脸朝上，身子盖在被子里
		var bed_frame:=int(frames.get("down",[16])[0]);var bed_atlas:=pose_texture;bed_atlas.atlas=sheet
		bed_atlas.region=Rect2((bed_frame%16)*64,(bed_frame/16)*84,64,34);sprite.texture=bed_atlas
		sprite.position=Vector2(-32,(-22.0 if head_down else -34.0)-lift);return
	if walking:
		frame = int(seq[int(elapsed*8)%seq.size()])
	elif action == "sit":
		seq = frames["sit_"+face]; frame = int(seq[int(elapsed)%2])
	elif pet:
		seq = frames.get("lie" if action in ["lie","sleep"] else ("sniff" if action=="sniff" else "idle"),frames.idle)
		frame = int(seq[int(elapsed*2)%seq.size()])
	elif action_frames.has(action+"_"+face) and (id!="mother" or action in ["eat","tv","clean","cook","read","drink","mahjong","water","wash","laundry","call","happy","sleep","lie","photo"]):
		tex = actions; seq = action_frames[action+"_"+face]; frame = int(seq[int(elapsed*2)%seq.size()])
	elif action == "talk": frame = 18+int(elapsed*3)%2
	elif face == "down": frame = 16+int(elapsed*2)%2
	else: frame = int(seq[0])
	var atlas := pose_texture
	atlas.atlas = tex
	atlas.region = Rect2((frame%16)*64,(frame/16)*84,64,84)
	sprite.texture = atlas
	sprite.position = Vector2(-32,-84-lift)

func move_along(dt: float, speed := 100.0) -> void:
	walking=not route.is_empty()
	if not walking:return
	var budget:=speed*minf(dt,.25)
	while budget>0 and not route.is_empty():
		var next:Vector2=route[0];var diff:=next-position;var distance:=diff.length()
		if distance>.01:face="right" if absf(diff.x)>absf(diff.y) and diff.x>0 else ("left" if absf(diff.x)>absf(diff.y) else ("down" if diff.y>0 else "up"))
		if distance<=budget:movement_distance+=distance;budget-=distance;position=next;route.remove_at(0)
		else:movement_distance+=budget;position+=diff.normalized()*budget;budget=0
	if route.is_empty():walking=false;action=destination_action;face=destination_face

func _draw() -> void:
	draw_set_transform(Vector2(0,-lift))
	if pet:
		if action=="happy":
			for i in 3:draw_rect(Rect2(-14+i*13,-55-sin(elapsed*4+i)*5,4,4),Color("edb3b2"))
		return
	if id=="visitor" and action in ["sit","eat","drink","read","computer","tv","guitar","swing"] and not walking:
		draw_rect(Rect2(-13,-9,10,12),Color("384456"));draw_rect(Rect2(3,-9,10,12),Color("384456"));draw_rect(Rect2(-15,2,14,5),Color("6b5246"));draw_rect(Rect2(3,2,14,5),Color("6b5246"))
	# 新母亲动作自带手臂、道具和被子，避免旧代码色块叠在新图上。
	if id=="mother" and not walking:return
	if action in ["drink","eat"] and not walking:
		var raise:float=(sin(elapsed*2)+1)*6
		draw_rect(Rect2(5,-33-raise,12,6),Color("e9b98e"));draw_rect(Rect2(13,-38-raise,10,10),Color("f5e3bb"));draw_rect(Rect2(15,-38-raise,6,3),Color("9b6a35"))
	if action in ["photo","hug"]:
		draw_rect(Rect2(17,-58,7,21),Color("edc5a2"));draw_rect(Rect2(16,-65,3,9),Color("edc5a2"));draw_rect(Rect2(23,-65,3,9),Color("edc5a2"))
	if action in ["sleep","lie"] and not walking:
		if (id=="visitor" or in_bed) and not head_down: # 床头朝下时身子在床上那床花被子里，不另画被头
			# 被子边：颜色取自这张床的被面，盖住肩膀。
			var quilt:Color=blanket if blanket.a>0 else Color("efe2c4")
			# 被头翻折一道：上沿亮一点、下面一道阴影，左右两角收一个像素，像盖到胸口的被子。
			var top:=-8.0 if head_down else -4.0
			if quilt_tex and quilt_region.size.x>0:
				draw_texture_rect_region(quilt_tex,Rect2(-25,top,50,12),quilt_region)
				draw_rect(Rect2(-25,top+(10 if head_down else 0),50,2),Color(1,1,1,.35))
			else:
				draw_rect(Rect2(-25,top,50,12),quilt);draw_rect(Rect2(-24,top+(10 if head_down else -2),48,3),quilt.lightened(.35));draw_rect(Rect2(-25,top+(-2 if head_down else 10),50,2),quilt.darkened(.12))
		var y:float=-43-fmod(elapsed*8,17);draw_string(UI.FONT,Vector2(24,y),"呼",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("eedabb"))

	if action=="wash":
		for i in 2:draw_rect(Rect2(-17+i*22,-37+sin(elapsed*9+i)*3,13,7),Color("edc5a2"))
