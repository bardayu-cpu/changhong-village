extends Node2D
## Background pixels stay out of the world floor. Art comes only from C4.
const Assets=preload("res://ayu_home/v2/assets.gd")
const SIZES={"far":Vector2i(1536,192),"middle":Vector2i(1536,160),"forest":Vector2i(1024,128),"mist":Vector2i(1024,64)}
var plates:Dictionary={}
var errors:Array[String]=[]
var world_view:=Rect2()
var frame_size:=Vector2.ZERO
var zoom:=2.0
var north_y:=520.0
var native_region:=Rect2(3456,0,1344,1152)
var sky:=Color("b8d0db")
var ready_art:=false
var foreground:Node2D
func configure(layers:Dictionary,region:Rect2,north_edge:float) -> bool:
	plates.clear();errors.clear();ready_art=false;native_region=region;north_y=north_edge
	for id in SIZES:
		var row:Dictionary=layers.get(id,{})
		var file:=str(row.get("file",""))
		if file.is_empty() or not FileAccess.file_exists(file):errors.append("missing C4 plate: "+id);continue
		var texture:Texture2D=Assets.texture(file)
		if row.has("region"):
			var r:Array=row.region
			var clip:=Rect2i(r[0],r[1],r[2],r[3])
			if not Rect2i(Vector2i.ZERO,Vector2i(texture.get_size())).encloses(clip):errors.append("outside source: "+id);continue
			var atlas:=AtlasTexture.new();atlas.atlas=texture;atlas.region=Rect2(clip);atlas.filter_clip=true;texture=atlas
		if Vector2i(texture.get_size())!=SIZES[id]:errors.append("wrong native plate size: "+id);continue
		plates[id]=texture
	ready_art=errors.is_empty();queue_redraw()
	if is_instance_valid(foreground):foreground.queue_redraw()
	return ready_art
func bind_terrain(terrain:Node2D) -> void:
	foreground=null
	if not is_instance_valid(terrain):return
	foreground=Node2D.new();foreground.name="G0ForestAndMist"
	foreground.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	terrain.add_child(foreground)
	foreground.draw.connect(func():paint_foreground(foreground))
func set_view(rect:Rect2,scale:float,size:Vector2) -> void:
	if world_view.is_equal_approx(rect) and is_equal_approx(zoom,scale) and frame_size.is_equal_approx(size):return
	world_view=rect;zoom=scale;frame_size=size;queue_redraw()
	if is_instance_valid(foreground):foreground.queue_redraw()
func _draw() -> void:
	if not ready_art or not visible or world_view.position.y>=north_y+64:return
	draw_rect(Rect2(Vector2.ZERO,frame_size),sky)
	var horizon:=roundf((north_y-world_view.position.y)*zoom)
	for id in ["far","middle"]:
		var texture:Texture2D=plates[id]
		var speed:=.04 if id=="far" else .08
		var shift:=clampf(roundf((world_view.get_center().x-4616.0)*speed),-128,128)
		var buried:=64.0 if id=="far" else 48.0
		var pos:=Vector2(frame_size.x*.5-texture.get_width()*zoom*.5-shift*zoom,horizon-(texture.get_height()-buried)*zoom).round()
		# Exactly one image per mountain layer, never a repeating sampler or a fit-to-screen scale.
		draw_texture_rect(texture,Rect2(pos,texture.get_size()*zoom),false)
func paint_foreground(canvas:CanvasItem) -> void:
	if not ready_art or world_view.position.y>=north_y+128:return
	for id in ["mist","forest"]:
		var texture:Texture2D=plates[id]
		var base:=north_y+16.0
		var first:=floori(maxf(native_region.position.x,world_view.position.x)/texture.get_width())
		var last:=ceili(minf(native_region.end.x,world_view.end.x)/texture.get_width())
		for index in range(first,last):
			var dest:=Rect2(Vector2(index*texture.get_width(),base-texture.get_height()),texture.get_size())
			var clipped:=dest.intersection(Rect2(Vector2(native_region.position.x,dest.position.y),Vector2(native_region.size.x,dest.size.y)))
			if clipped.has_area():canvas.draw_texture_rect_region(texture,clipped,Rect2(clipped.position-dest.position,clipped.size))
func snapshot() -> Dictionary:
	return {"ready_art":ready_art,"errors":errors,"world_view":world_view,"frame_size":frame_size,"world_zoom":zoom,"north_y":north_y,"mountain_repeats":false,"source_shift_limit":128}
