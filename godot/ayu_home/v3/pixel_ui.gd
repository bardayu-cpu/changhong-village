extends RefCounted
const FONT=preload("res://assets/fonts/fusion-pixel-12px-proportional-zh_hans.otf.woff2")
const INK=Color("624733")
const CREAM=Color("fff3d8")
const BROWN=Color("976844")
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
				im.set_pixel(x,y,edge if y<2 or y>=26 or x<inset+2 or x>=26-inset else color)
	var b:=StyleBoxTexture.new();b.texture=ImageTexture.create_from_image(im)
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:b.set_texture_margin(side,10);b.set_content_margin(side,12)
	b.modulate_color=Color.WHITE;boxes[key]=b;return b
static func theme() -> Theme:
	var t:=Theme.new();t.default_font=FONT;t.default_font_size=20
	for kind in ["Label","Button","RichTextLabel"]:t.set_color("font_color",kind,INK)
	t.set_stylebox("panel","PanelContainer",box());t.set_stylebox("panel","Panel",box())
	for state in ["normal","hover","pressed","focus","disabled"]:
		t.set_stylebox(state,"Button",box(Color("ecd5a8") if state=="pressed" else (Color("fff9e8") if state=="hover" else CREAM),Color("bc8654") if state=="focus" else INK))
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_hover_pressed_color"]:t.set_color(state,"Button",INK)
	t.set_color("font_disabled_color","Button",Color("ae9781"));t.set_constant("separation","HBoxContainer",10);t.set_constant("separation","VBoxContainer",10)
	return t
static func label(copy:String,sz:=20) -> Label:
	var l:=Label.new();l.text=copy;l.add_theme_font_override("font",FONT);l.add_theme_font_size_override("font_size",sz);l.add_theme_color_override("font_color",INK);return l
static func button(copy:String,callback:Callable) -> Button:
	var b:=Button.new();b.text=copy;b.custom_minimum_size=Vector2(64,48);b.pressed.connect(callback)
	b.button_down.connect(func():b.pivot_offset=b.size*.5;b.scale=Vector2(.96,.96))
	b.button_up.connect(func():b.create_tween().tween_property(b,"scale",Vector2.ONE,.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	return b
class Bubble extends Control:
	var icon:="…"
	var selected:=false
	var white:=false
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
		"tools":["110001100","110001100","011111000","001110000","001110000","001110000","001110000","001110000","000100000"]
	}
	func _ready() -> void:
		mouse_filter=Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var rect:=Rect2(2,0,size.x-4,size.y-8)
		draw_style_box(load("res://ayu_home/v3/pixel_ui.gd").box(Color("fff9eb") if white else (Color("b37d4d") if selected else Color("956748")),Color("684b34") if white else Color("fff6df")),rect)
		var p:=size*Vector2(.5,0);p.y=size.y-9
		draw_colored_polygon(PackedVector2Array([p+Vector2(-7,0),p+Vector2(7,0),p+Vector2(0,9)]),Color("684b34") if white else Color("fff6df"))
		draw_colored_polygon(PackedVector2Array([p+Vector2(-4,-1),p+Vector2(4,-1),p+Vector2(0,5)]),Color("fff9eb") if white else Color("956748"))
		if ICONS.has(icon):
			var pixels:Array=ICONS[icon];var origin:=Vector2((size.x-18)/2,(size.y-26)/2).floor()
			for y in pixels.size():
				for x in str(pixels[y]).length():
					if str(pixels[y])[x]=="1":draw_rect(Rect2(origin+Vector2(x,y)*2,Vector2(2,2)),Color("65432e") if white else Color("fff7e6"))
			return
		var font=load("res://ayu_home/v3/pixel_ui.gd").FONT
		var extent:Vector2=font.get_string_size(icon,HORIZONTAL_ALIGNMENT_LEFT,-1,20)
		draw_string(font,Vector2((size.x-extent.x)/2,(size.y-8)/2+7),icon,HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("65432e") if white else Color("fff7e6"))
