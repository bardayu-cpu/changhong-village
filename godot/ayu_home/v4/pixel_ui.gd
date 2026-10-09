extends RefCounted
const FONT=preload("res://assets/fonts/fusion-pixel-12px-proportional-zh_hans.otf.woff2")
const DS=preload("res://scripts/ui/dialog_skin.gd")
## 村-8：界面只用组件库第 1 条那几个颜色，都从罗曼那份 dialog_skin.gd 的 PAL 取（改一处两边都变），这里不再另抄一份
static var DEEP:=Color(DS.PAL.box.fill)     # 深褐底
static var OUTER:=Color(DS.PAL.box.edge)    # 最外线
static var GOLD:=Color(DS.PAL.box.rim)      # 金棕线
static var TEXT:=Color(DS.PAL.text)         # 米白字、图标
static var NAME:=Color(DS.PAL.name)         # 名字黄
## 下面两个只给纸做的东西（信纸、拍立得、小游戏的木台子、旧活动面板）：纸上的深棕字和纸色，信纸不换（组件库第 7 条之外）
const INK=Color("624733")
const CREAM=Color("fff3d8")
## 村-4：按钮三种（组件库第 6 条），样子跟罗曼那份 dialog_skin.gd 一家：
##   主按钮 = 对话选项那种红按钮（喜红底、亮边、深红描边、四角金钉、米白字 24，高 48、最窄 88），一屏最好只有一个；
##   次按钮 = 名字牌那种深褐底、金棕双线、米白字 24，高 48；图标按钮 = 深褐方块、金棕线、米白图标，不小于 44×44。
static func secondary_box(down:=false) -> StyleBoxTexture:
	var b:StyleBoxTexture=DS.plate_frame()
	b.set_content_margin(SIDE_LEFT,18);b.set_content_margin(SIDE_RIGHT,18) # 金线里面再留 12（字不贴边）
	b.set_content_margin(SIDE_TOP,8 if down else 6);b.set_content_margin(SIDE_BOTTOM,6 if down else 8)
	if down:b.modulate_color=Color(.8,.8,.8) # 按下去暗一档
	return b
## 字不贴边（组件库第 2 条，第八轮）：红按钮描边 + 亮边 5 像素，里面再留 12，左右各 17；宽度跟着字走，不缩字
const PRIMARY_PADX:=17
static func primary(b:Button) -> Button:
	DS.style_choice(b,FONT);b.add_theme_font_size_override("font_size",24)
	for state in ["normal","hover","focus","disabled","pressed"]:
		var sb:StyleBox=b.get_theme_stylebox(state).duplicate();sb.content_margin_left=PRIMARY_PADX;sb.content_margin_right=PRIMARY_PADX;b.add_theme_stylebox_override(state,sb)
	b.size_flags_horizontal=Control.SIZE_FILL;b.custom_minimum_size=Vector2(maxf(88,b.custom_minimum_size.x),48);return b
static var boxes:Dictionary={}
static func box(color:Color=CREAM,edge:Color=INK) -> StyleBoxTexture:
	var key:=color.to_html()+edge.to_html()
	if boxes.has(key):return boxes[key]
	var im:=Image.create(28,28,false,Image.FORMAT_RGBA8)
	im.fill(Color.TRANSPARENT)
	for y in 28:
		for x in 28:
			var inset:=6 if y<2 or y>=26 else (3 if y<4 or y>=24 else (1 if y<7 or y>=21 else 0))
			if x>=inset and x<28-inset:
				im.set_pixel(x,y,edge if y<2 or y>=26 or x<inset+2 or x>=26-inset else (color.lightened(.12) if y in [3,4] else (color.darkened(.08) if y in [23,24] else color)))
	var b:=StyleBoxTexture.new();b.texture=ImageTexture.create_from_image(im)
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:b.set_texture_margin(side,10);b.set_content_margin(side,12)
	b.modulate_color=Color.WHITE;boxes[key]=b;return b
# A small, tiled, native pixel material: bevels, paper fibres and sewn edges.
static func paper(kind:="paper") -> StyleBoxTexture:
	var key:="material:"+kind
	if boxes.has(key):return boxes[key]
	var wood:bool=kind=="wood"
	var base:=Color("bd9060") if wood else Color("fff0d0")
	var im:=Image.create(64,64,false,Image.FORMAT_RGBA8);im.fill(base)
	for y in 64:
		for x in 64:
			var hash_value:=(x*17+y*43+x*y*3)%127
			if hash_value<8:im.set_pixel(x,y,base.darkened(.055 if wood else .022))
			elif hash_value>122:im.set_pixel(x,y,base.lightened(.12))
			if wood and y%8==0:im.set_pixel(x,y,Color("b08354"))
	for y in 64:
		for x in 64:
			var edge:=mini(mini(x,63-x),mini(y,63-y))
			if edge<2:im.set_pixel(x,y,Color("644a37"))
			elif edge<4:im.set_pixel(x,y,Color("deb981"))
			elif edge==4:im.set_pixel(x,y,Color("fff5d9"))
			elif edge==7:im.set_pixel(x,y,Color("a97950") if wood else Color("d7b78a"))
			elif edge==10 and (x+y)%6<2:im.set_pixel(x,y,Color("e6cba2"))
	# Cut, stepped corners, rather than antialiased round corners.
	for y in 4:
		for x in 4-y:
			for q in [Vector2i(x,y),Vector2i(63-x,y),Vector2i(x,63-y),Vector2i(63-x,63-y)]:im.set_pixelv(q,Color.TRANSPARENT)
	if not wood:
		for y in range(5,15):
			for x in range(49+y-5,59):im.set_pixel(x,y,Color("ecd2a7") if x==49+y-5 else Color("fff9e6"))
	var b:=StyleBoxTexture.new();b.texture=ImageTexture.create_from_image(im)
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:b.set_texture_margin(side,16);b.set_content_margin(side,18)
	b.axis_stretch_horizontal=StyleBoxTexture.AXIS_STRETCH_MODE_TILE;b.axis_stretch_vertical=StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	boxes[key]=b;return b
static func paragraph(copy:String,sz:=24) -> Label:
	var l:=label(copy,sz);l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;return l
static func divider() -> Control:
	var c:=Control.new();c.custom_minimum_size.y=8;c.mouse_filter=Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		for x in range(0,int(c.size.x),8):c.draw_rect(Rect2(x,3,4,2),Color(DS.PAL.box.rim)))
	return c
## 小标题（原来的绿印章）：深褐面板上用名字黄（组件库第 1 条），不另加框
static func stamp(copy:String) -> Label:
	var l:=label(copy,24);l.add_theme_color_override("font_color",Color(DS.PAL.name));return l
## 村-5：面板（地图、生活册、设置、人物卡……）的框跟对话框同一个：深褐底、外一圈深色、里一圈金棕、四角金 L 角花
static func panel_box() -> StyleBoxTexture:
	var b:StyleBoxTexture=DS.box_frame()
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:b.set_content_margin(side,24)
	return b
## 面板里的小块（任务、收集卡、叫吃饭那条）：名字牌那种深褐底、金棕双线
static func card_box() -> StyleBoxTexture:
	var b:StyleBoxTexture=DS.plate_frame()
	for side in [SIDE_LEFT,SIDE_RIGHT]:b.set_content_margin(side,14)
	for side in [SIDE_TOP,SIDE_BOTTOM]:b.set_content_margin(side,10)
	return b
static func icon(which:="album",width:=40,color:=Color(DS.PAL.icon),outline:=Color(0,0,0,0)) -> TextureRect:
	var im:=Image.create(13,13,false,Image.FORMAT_RGBA8);im.fill(Color.TRANSPARENT)
	var grid:Array=Bubble.ICONS.get(which,Bubble.ICONS.album)
	if outline.a>0:
		# 小图标描一圈深色边，压在画上也看得清
		for y in grid.size():
			for x in str(grid[y]).length():
				if str(grid[y])[x]=="1":
					for d in [Vector2i(-1,0),Vector2i(1,0),Vector2i(0,-1),Vector2i(0,1)]:im.set_pixel(x+2+d.x,y+2+d.y,outline)
	for y in grid.size():
		for x in str(grid[y]).length():
			if str(grid[y])[x]=="1":im.set_pixel(x+2,y+2,color)
	var t:=TextureRect.new();t.texture=ImageTexture.create_from_image(im);t.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;t.custom_minimum_size=Vector2(width,width);t.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;t.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;return t
## light=true 给纸做的东西（信纸、拍立得、小游戏的木台子、旧的活动面板）：字照旧深棕；别的界面是深褐面板、米白字（村-5）
static func theme(light:=false) -> Theme:
	var t:=Theme.new();t.default_font=FONT;t.default_font_size=24
	for kind in ["Label","RichTextLabel"]:t.set_color("font_color",kind,INK if light else Color(DS.PAL.text))
	if light:t.set_stylebox("panel","PanelContainer",paper());t.set_stylebox("panel","Panel",paper())
	else:t.set_stylebox("panel","PanelContainer",card_box());t.set_stylebox("panel","Panel",card_box())
	for state in ["normal","hover","pressed","focus","disabled"]:t.set_stylebox(state,"Button",secondary_box(state=="pressed"))
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_hover_pressed_color"]:t.set_color(state,"Button",Color(DS.PAL.text))
	t.set_font_size("font_size","Button",24)
	for state in ["normal","focus"]:t.set_stylebox(state,"LineEdit",box(CREAM,Color("91a271")) if light else card_box())
	t.set_color("font_color","LineEdit",INK if light else TEXT);t.set_color("caret_color","LineEdit",INK if light else TEXT);t.set_color("selection_color","LineEdit",Color("c6d5a1"))
	t.set_color("font_disabled_color","Button",Color(DS.PAL.box.rim));t.set_constant("separation","HBoxContainer",10);t.set_constant("separation","VBoxContainer",10)
	return t
## 村-7：界面字号只用 24 / 36 / 48（组件库第 2 条：像素字 12 的整倍才清楚，客人多是长辈，不设比 24 小的字）。
## 各处原来写的 14～20、22、23、25、28 照最近的一档落：30 以下 24，30～41 是 36，再大 48
static func fs(sz:int) -> int:return 24 if sz<30 else (36 if sz<42 else 48)
static func label(copy:String,sz:=24) -> Label:
	sz=fs(sz);var l:=Label.new();l.text=copy;l.add_theme_font_override("font",FONT);l.add_theme_font_size_override("font_size",sz);return l # 字的颜色交给主题：深褐面板上米白，纸上深棕
## 不要框的一行字：奶白字 + 深棕描边，直接压在画上也看得清（阿鱼 10/5：地点、任务只留一行字）。
static func outlined(copy:String,sz:=24) -> Label:
	var l:=label(copy,sz);l.add_theme_color_override("font_color",TEXT);l.add_theme_color_override("font_outline_color",OUTER);l.add_theme_constant_override("outline_size",6)
	l.add_theme_color_override("font_shadow_color",Color(0,0,0,.35));l.add_theme_constant_override("shadow_offset_y",2);l.mouse_filter=Control.MOUSE_FILTER_IGNORE;return l
## 小图标按钮：只有一个像素图标，按下缩一下。
static func icon_button(which:String,callback:Callable,width:=46) -> Button:
	width=maxi(width,44);var b:=Button.new();b.custom_minimum_size=Vector2(width,width);b.focus_mode=Control.FOCUS_NONE;b.pressed.connect(callback)
	for state in ["normal","hover","pressed","focus","disabled"]:b.add_theme_stylebox_override(state,secondary_box(state=="pressed"))
	var tex:TextureRect=icon(which,width-14,Color(DS.PAL.icon));tex.mouse_filter=Control.MOUSE_FILTER_IGNORE;tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);tex.offset_left=7;tex.offset_top=7;tex.offset_right=-7;tex.offset_bottom=-7;b.add_child(tex)
	b.button_down.connect(func():b.pivot_offset=b.size*.5;b.scale=Vector2(.92,.92))
	b.button_up.connect(func():b.create_tween().tween_property(b,"scale",Vector2.ONE,.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	return b
static func button(copy:String,callback:Callable,main:=false) -> Button:
	var b:=Button.new();b.text=copy;b.custom_minimum_size=Vector2(64,48);b.pressed.connect(callback)
	if main:primary(b)
	b.button_down.connect(func():b.pivot_offset=b.size*.5;b.scale=Vector2(.96,.96))
	b.button_up.connect(func():b.create_tween().tween_property(b,"scale",Vector2.ONE,.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	return b
class Bubble extends Control:
	var icon:="…"
	var selected:=false
	var white:=false
	var turn:=0 # 门的箭头朝向：0 上 1 右 2 下 3 左，指向门外那一间
	const ICONS={
		"door":["000010000","000111000","001111100","011111110","000010000","000010000","000010000","000010000","000000000"],
		"fish":["000000000","001111000","011111100","111101110","011111101","001111111","000111101","000000000","000000000"],
		"tv":["001000100","000101000","111111111","100000001","100000001","100000001","111111111","000010000","001111100"],
		"guitar":["000000110","000001100","000011000","000110000","001110000","011011000","110001100","110001100","011111000"],
		"puzzle":["000110000","111111100","110001100","110001111","111111111","110001100","110001100","111111100","000110000"],
		"album":["111111111","100000001","101100001","100000001","100010001","100111001","101111101","100000001","111111111"],
		"detail":["001111000","011001100","110000110","110000110","011001100","001111000","000001100","000000110","000000011"],
		"stars":["000010000","000010000","001111100","111111111","001111100","001111100","011001110","010000010","000000000"],
		"relax":["110000000","110000000","111111110","111111111","100000001","111111111","100000001","100000001","000000000"],
		"water":["000010000","000110000","000111000","001111100","011111110","011111110","011011110","001111100","000111000"],
		"open":["111111111","100010001","100010001","101010101","100010001","100010001","111111111","100000001","000000000"],
		"lamp":["000111000","001111100","011111110","111111111","000010000","000010000","000010000","001111100","000000000"],
		"fold":["011000110","111101111","101111101","001111100","001111100","001111100","001111100","001111100","000000000"],
		"tea":["000101000","001010000","000000000","111111100","100000111","100000101","011111110","000000000","111111111"],
		"pet":["011000110","011000110","000110000","000110000","000000000","001111100","011111110","011111110","001111100"],
		"tools":["110001100","110001100","011111000","001110000","001110000","001110000","001110000","001110000","000100000"],
		"clock":["001111100","010010010","100010001","100010001","100011101","100000001","100000001","010000010","001111100"],
		"sun":["000010000","010000010","001111100","001111100","101111101","001111100","001111100","010000010","000010000"],
		"rain":["001110000","011111100","111111110","111111111","011111110","000000000","010010010","100100100","000000000"],
		"spring":["000101000","001111100","000111000","001111100","000101000","000010000","001010000","000110000","000010000"],
		"summer":["000000110","000001111","011001110","111101100","011111000","000110000","000010000","000010000","000010000"],
		"autumn":["000010000","010111010","011111110","001111100","111111111","011111110","000111000","000010000","000010000"],
		"winter":["000010000","010010010","001010100","000111000","111111111","000111000","001010100","010010010","000010000"],
		"cat":["100000001","110000011","111111111","110111011","111111111","111101111","011111110","001111100","000000000"],
		"gear":["000101000","010111010","001111100","111000111","011000110","111000111","001111100","010111010","000101000"],
		"bag":["001111100","010000010","111111111","100010001","111111111","100000001","100000001","100000001","111111111"],
		"map":["110011000","101101110","100100101","100100101","100100101","100100101","100100101","111001101","000000011"],
		"camera":["000000000","001110000","111111111","100000001","100111001","101000101","100111001","100000001","111111111"],
		"note":["011111110","010000010","010111010","010000010","010111010","010000010","010110010","010000010","011111110"]
	}
	func _ready() -> void:
		mouse_filter=Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		# 「这里能点」提示泡：照罗曼（组件库第 5 条）深褐底、金棕边、台阶圆角、下面小尾巴，里面米白 9×9 点阵图标
		var DSkin=load("res://scripts/ui/dialog_skin.gd")
		var fill:=Color(DS.PAL.hint.fill);var edge:=Color(DS.PAL.hint.edge)
		var rect:=Rect2(2,0,size.x-4,size.y-8)
		draw_style_box(DSkin.pixel_box(fill,edge,null,5,2,2),rect)
		var tail:Texture2D=DSkin.tail_tex(fill,edge)
		draw_texture(tail,Vector2(round(size.x*.5-tail.get_width()*.5),size.y-8-4))
		if ICONS.has(icon):
			var pixels:Array=ICONS[icon];var origin:=Vector2((size.x-18)/2,(size.y-26)/2).floor()
			for y in pixels.size():
				for x in str(pixels[y]).length():
					if str(pixels[y])[x]=="1":
						var q:Vector2=[Vector2(x,y),Vector2(8-y,x),Vector2(8-x,8-y),Vector2(y,8-x)][turn]
						draw_rect(Rect2(origin+q*2,Vector2(2,2)),fill if white else Color(DS.PAL.hint.icon))
			return
		# 家人头上的「！」：字号 24（村-7），颜色只用组件库那几个（村-3）
		var font=load("res://ayu_home/v4/pixel_ui.gd").FONT
		var extent:Vector2=font.get_string_size(icon,HORIZONTAL_ALIGNMENT_LEFT,-1,24)
		draw_string(font,Vector2((size.x-extent.x)/2,(size.y-8)/2+8),icon,HORIZONTAL_ALIGNMENT_LEFT,-1,24,fill if white else Color(DS.PAL.hint.icon))
