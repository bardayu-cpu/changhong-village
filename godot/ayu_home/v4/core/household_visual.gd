extends Node2D
## C4 supplies each real object and its two placements; no furniture substitutes or automatic offsets.
const Assets=preload("res://ayu_home/v2/assets.gd")
var ui
var room_id:=""
var layers:Array=[]
var sprites:Array=[]
func setup(owner) -> void:
	ui=owner;room_id=ui.home.area.trim_prefix("v_")
	layers=ui.home.world.cfg.get("household_visual",{}).get("layers",[])
	for layer in layers:
		var anchor:=Node2D.new();ui.home.world.actors.add_child(anchor)
		var sprite:=Sprite2D.new();sprite.centered=false
		sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;anchor.add_child(sprite)
		sprites.append({"anchor":anchor,"sprite":sprite,"layer":layer})
	ui.state.changed.connect(refresh);refresh()
static func selected_state(layer:Dictionary,progress:Dictionary) -> Dictionary:
	var key:=str(layer.get("state","helped"))
	return layer.get("after",{}) if bool(progress.get(key,false)) else layer.get("before",{})
func refresh() -> void:
	var progress:Dictionary=ui.state.data.village.household_progress.get(room_id,{})
	for row in sprites:
		var pose:=selected_state(row.layer,progress)
		var sprite:Sprite2D=row.sprite;sprite.visible=false
		if pose.is_empty():continue
		var file:=str(pose.get("file",""));var rect:Array=pose.get("rect",[])
		if file.is_empty() or rect.size()!=4 or float(rect[2])<=0 or float(rect[3])<=0:continue
		if not FileAccess.file_exists(file) and not ResourceLoader.exists(file):continue
		var texture:=Assets.texture(file)
		if texture==null:continue
		var source:Array=pose.get("region",[])
		if source.size()==4:
			var atlas:=AtlasTexture.new();atlas.atlas=texture
			atlas.region=Rect2(source[0],source[1],source[2],source[3]);atlas.filter_clip=true;texture=atlas
		var foot:=float(pose.get("foot",float(rect[1])+float(rect[3])))
		row.anchor.position=Vector2(0,foot)
		sprite.position=Vector2(rect[0],float(rect[1])-foot)
		sprite.texture=texture;sprite.scale=Vector2(rect[2],rect[3])/texture.get_size();sprite.visible=true
