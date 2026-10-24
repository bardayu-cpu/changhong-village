extends Control
signal house_selected(id:String)
const UI=preload("res://ayu_home/v4/pixel_ui.gd")
const C=preload("res://ayu_home/v4/core/config.gd")
const Assets=preload("res://ayu_home/v2/assets.gd")
var state
var houses:Array=[]
var chosen:=""
var current:=Vector2.ZERO
var world_size:=Vector2(4800,4700)
var background_path:="res://ayu_home/v4/assets/village/ground.png"
var scenery:Array=[]
var house_buttons:Array=[]
func _ready() -> void:
	custom_minimum_size=Vector2(0,480);texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;mouse_filter=Control.MOUSE_FILTER_IGNORE;resized.connect(queue_redraw)
	var cfg:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://ayu_home/v4/assets/village.json"))
	var dimensions:Array=cfg.get("size",[4800,4700])
	if dimensions.size()==2 and float(dimensions[0])>0 and float(dimensions[1])>0:world_size=Vector2(dimensions[0],dimensions[1])
	background_path=str(cfg.get("background",background_path))
	if background_path.is_empty():background_path="res://ayu_home/v4/assets/village/ground.png"
	elif not background_path.begins_with("res://"):background_path=str(cfg.get("asset_root","res://ayu_home/v3/assets/"))+background_path
	scenery=cfg.get("props",[]).duplicate();scenery.sort_custom(func(a,b):return float(a.get("foot",0))<float(b.get("foot",0)))
	for house in houses:
		var b:=Button.new();b.flat=true;b.tooltip_text=str(house.title);b.focus_mode=Control.FOCUS_NONE
		for key in ["normal","hover","pressed","focus"]:b.add_theme_stylebox_override(key,StyleBoxEmpty.new())
		b.pressed.connect(func():house_selected.emit(str(house.id)));add_child(b);house_buttons.append({"button":b,"house":house})
	resized.connect(place_buttons);place_buttons()
func place_buttons() -> void:
	var s:=minf(size.x/world_size.x,size.y/world_size.y);var offset:=(size-world_size*s)*.5
	for row in house_buttons:
		var b:Array=row.house.bounds;var dimensions:=Vector2(maxf(44,float(b[2])*s),maxf(44,float(b[3])*s))
		row.button.position=offset+Vector2(b[0]+b[2]*.5,b[1]+b[3]*.5)*s-dimensions*.5;row.button.size=dimensions
func _draw() -> void:
	var scale:=minf(size.x/world_size.x,size.y/world_size.y);var offset:=(size-world_size*scale)*.5
	draw_texture_rect(Assets.texture(background_path),Rect2(offset,world_size*scale),false)
	for prop in scenery:
		var path:String=str(prop.file)
		if not path.begins_with("res://"):path="res://ayu_home/v3/assets/"+path
		var texture=Assets.texture(path)
		if texture==null:continue
		var s:Array=prop.get("scale",[1,1]);var at:=Vector2(prop.pos[0],prop.pos[1]);var dimensions:Vector2=texture.get_size()*Vector2(s[0],s[1])
		draw_texture_rect(texture,Rect2(offset+at*scale,dimensions*scale),false)
	for h in houses:
		var p:=offset+Vector2(h.at[0],h.at[1])*scale
		draw_string(UI.FONT,p+Vector2(-35,13),str(h.title).split(" · ")[0],HORIZONTAL_ALIGNMENT_CENTER,72,16,Color("443c2c"))
		draw_string(UI.FONT,p+Vector2(-36,12),str(h.title).split(" · ")[0],HORIZONTAL_ALIGNMENT_CENTER,72,16,Color("fff3d8"))
	for id in C.LOCATION_POINTS:
		var xy:Array=C.LOCATION_POINTS[id];var p:=offset+Vector2(xy[0],xy[1])*scale
		var selected:bool=id==chosen or (not state.data.village.location.is_empty() and id==state.data.village.location)
		draw_rect(Rect2(p-Vector2(17,10),Vector2(34,20)),Color("ebd67d") if selected else Color("c2a47a"),false,3)
	if current!=Vector2.ZERO:draw_circle(offset+current*scale,5,Color("fff3c4"))
