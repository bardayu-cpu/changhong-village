extends Node2D
## Background pixels stay out of the world floor. Art comes only from C4.
const Assets=preload("res://ayu_home/v2/assets.gd")
const LAYERS=["far","middle","forest","mist"]
const MOUNTAIN_HALF_COVERAGE=768 # 1280 / 1 / 2 + 128 source-pixel camera shift.
var plates:Dictionary={}
var specs:Dictionary={}
var errors:Array[String]=[]
var view_errors:Array[String]=[]
var world_view:=Rect2()
var frame_size:=Vector2.ZERO
var zoom:=2.0
var north_y:=520.0
var native_region:=Rect2(3456,0,1344,1152)
var sky:=Color("b8d0db")
var ready_art:=false
var foreground:Node2D
func configure(layers:Dictionary,region:Rect2,north_edge:float) -> bool:
	plates.clear();specs.clear();errors.clear();ready_art=false;native_region=region;north_y=north_edge
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	for id in LAYERS:
		var row:Variant=layers.get(id,{})
		if not row is Dictionary:errors.append("invalid plate metadata: "+id);continue
		var spec:=read_plate(id,row)
		if spec.is_empty():continue
		plates[id]=spec.texture;spec.erase("texture");specs[id]=spec
	ready_art=errors.is_empty();queue_redraw()
	if is_instance_valid(foreground):foreground.queue_redraw()
	return ready_art
func integers(value:Variant,count:int) -> Array:
	if not value is Array or value.size()!=count:return []
	var result:Array=[]
	for number in value:
		if not typeof(number) in [TYPE_INT,TYPE_FLOAT]:return []
		if not is_finite(float(number)) or float(number)!=floorf(float(number)):return []
		result.append(int(number))
	return result
func reject_plate(id:String,reason:String) -> Dictionary:
	errors.append(reason+": "+id)
	return {}
func read_plate(id:String,row:Dictionary) -> Dictionary:
	var file:=str(row.get("file",""))
	if file.is_empty() or not (FileAccess.file_exists(file) or ResourceLoader.exists(file)):return reject_plate(id,"missing C4 plate")
	var texture:Texture2D=Assets.texture(file)
	if texture==null:return reject_plate(id,"unreadable plate")
	var image:=texture.get_image()
	if image==null or image.is_empty():return reject_plate(id,"unreadable source pixels")
	if image.is_compressed() and image.decompress()!=OK:return reject_plate(id,"cannot inspect source alpha")
	var size:=integers(row.get("source_size"),2)
	var region:=integers(row.get("region"),4)
	var bounds:=integers(row.get("alpha_bbox"),4)
	var anchor:=integers([row.get("anchor_x"),row.get("anchor_y")],2)
	var baseline:=integers([row.get("baseline_offset")],1)
	if size.is_empty() or region.is_empty() or bounds.is_empty() or anchor.is_empty() or baseline.is_empty():return reject_plate(id,"missing integer source/region/alpha/anchor/baseline metadata")
	if Vector2i(size[0],size[1])!=image.get_size():return reject_plate(id,"source_size differs from original pixels")
	var clip:=Rect2i(region[0],region[1],region[2],region[3])
	var source_rect:=Rect2i(Vector2i.ZERO,image.get_size())
	if not clip.has_area() or not source_rect.encloses(clip):return reject_plate(id,"region outside source")
	var used:=image.get_used_rect()
	if not used.has_area():return reject_plate(id,"empty alpha content")
	# Only fully transparent margins may be removed. Never crop a failed subject.
	if not clip.encloses(used):return reject_plate(id,"region clips nontransparent subject")
	var alpha:=Rect2i(used.position-clip.position,used.size)
	if alpha!=Rect2i(bounds[0],bounds[1],bounds[2],bounds[3]):return reject_plate(id,"alpha_bbox differs from original pixels")
	if anchor[0]<0 or anchor[0]>clip.size.x or anchor[1]<0 or anchor[1]>clip.size.y:return reject_plate(id,"anchor outside region")
	var spec:Dictionary={"source_size":size,"region":region,"alpha_bbox":bounds,"anchor":[anchor[0],anchor[1]],"baseline_offset":baseline[0]}
	if id in ["far","middle"]:
		if anchor[0]-alpha.position.x<MOUNTAIN_HALF_COVERAGE or alpha.end.x-anchor[0]<MOUNTAIN_HALF_COVERAGE:return reject_plate(id,"effective content does not cover 1536 source pixels around anchor")
		if anchor[1]<=alpha.position.y or anchor[1]>alpha.end.y:return reject_plate(id,"horizon anchor outside mountain content")
		var peak:=integers(row.get("peak"),2)
		var buried:=integers(row.get("buried_region"),4)
		if peak.is_empty() or buried.is_empty():return reject_plate(id,"missing peak/buried_region")
		var peak_point:=Vector2i(peak[0],peak[1])
		if not alpha.has_point(peak_point) or peak[1]>=anchor[1]:return reject_plate(id,"peak must remain above horizon anchor")
		if image.get_pixelv(clip.position+peak_point).a<=0:return reject_plate(id,"peak points at transparent padding")
		var burial:=Rect2i(buried[0],buried[1],buried[2],buried[3])
		var local_rect:=Rect2i(Vector2i.ZERO,clip.size)
		if burial.size.x<=0 or burial.size.y<0 or not local_rect.encloses(burial):return reject_plate(id,"buried_region outside region")
		if burial.position.y!=anchor[1] or burial.position.x>alpha.position.x or burial.end.x<alpha.end.x or burial.end.y<alpha.end.y:return reject_plate(id,"buried_region must explicitly contain the lower content from anchor_y")
		spec.peak=peak;spec.buried_region=buried
	if clip!=source_rect:
		var atlas:=AtlasTexture.new();atlas.atlas=texture;atlas.region=Rect2(clip);atlas.filter_clip=true;texture=atlas
	spec.texture=texture
	return spec
func bind_terrain(terrain:Node2D) -> void:
	foreground=null
	if not is_instance_valid(terrain):return
	foreground=Node2D.new();foreground.name="G0ForestAndMist"
	foreground.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	terrain.add_child(foreground)
	foreground.draw.connect(func():paint_foreground(foreground))
func set_view(rect:Rect2,scale:float,size:Vector2) -> void:
	if world_view.is_equal_approx(rect) and is_equal_approx(zoom,scale) and frame_size.is_equal_approx(size):return
	world_view=rect;zoom=scale;frame_size=size;view_errors.clear()
	if scale<1.0 or scale!=floorf(scale):view_errors.append("world zoom must remain a positive integer")
	if size.x<=0 or size.y<=0:view_errors.append("invalid logical game buffer")
	queue_redraw()
	if is_instance_valid(foreground):foreground.queue_redraw()
func mountain_rect(id:String) -> Rect2:
	var texture:Texture2D=plates[id]
	var spec:Dictionary=specs[id]
	var speed:=.04 if id=="far" else .08
	var alpha:Array=spec.alpha_bbox
	var half_content:float=minf(float(spec.anchor[0]-alpha[0]),float(alpha[0]+alpha[2]-spec.anchor[0]))
	var allowance:float=clampf(floorf(half_content-frame_size.x/(2.0*zoom)),0.0,128.0)
	var shift:=clampf(roundf((world_view.get_center().x-4616.0)*speed),-allowance,allowance)
	var baseline:=roundf((north_y+float(spec.baseline_offset)-world_view.position.y)*zoom)
	var pos:=Vector2(frame_size.x*.5-(float(spec.anchor[0])+shift)*zoom,baseline-float(spec.anchor[1])*zoom).round()
	return Rect2(pos,texture.get_size()*zoom)
func _draw() -> void:
	if not ready_art or not view_errors.is_empty() or not visible or world_view.position.y>=north_y+64:return
	draw_rect(Rect2(Vector2.ZERO,frame_size),sky)
	for id in ["far","middle"]:
		var texture:Texture2D=plates[id]
		# Exactly one image per mountain layer, never a repeating sampler or a fit-to-screen scale.
		draw_texture_rect(texture,mountain_rect(id),false)
func paint_foreground(canvas:CanvasItem) -> void:
	if not ready_art or not view_errors.is_empty() or world_view.position.y>=north_y+128:return
	for id in ["mist","forest"]:
		var texture:Texture2D=plates[id]
		var spec:Dictionary=specs[id]
		var base:=north_y+float(spec.baseline_offset)
		var first:=floori((world_view.position.x+float(spec.anchor[0]))/texture.get_width())
		var last:=ceili((world_view.end.x+float(spec.anchor[0]))/texture.get_width())
		for index in range(first,last):
			var dest:=Rect2(Vector2(index*texture.get_width()-float(spec.anchor[0]),base-float(spec.anchor[1])),texture.get_size())
			var clipped:=dest.intersection(Rect2(Vector2(world_view.position.x,dest.position.y),Vector2(world_view.size.x,dest.size.y)))
			if clipped.has_area():canvas.draw_texture_rect_region(texture,clipped,Rect2(clipped.position-dest.position,clipped.size))
func snapshot() -> Dictionary:
	var projected:Dictionary={}
	for id in ["far","middle"]:
		if not specs.has(id):continue
		var spec:Dictionary=specs[id];var rect:=mountain_rect(id)
		var alpha:Array=spec.alpha_bbox
		var used:=Rect2(rect.position+Vector2(alpha[0],alpha[1])*zoom,Vector2(alpha[2],alpha[3])*zoom)
		var peak:=rect.position+Vector2(spec.peak[0],spec.peak[1])*zoom
		projected[id]={"rect":rect,"peak":peak,"peak_in_frame":Rect2(Vector2.ZERO,frame_size).has_point(peak),"content_top_in_frame":used.position.y>=0,"effective_horizontal_coverage":used.position.x<=0 and used.end.x>=frame_size.x,"visible_source_height":int(spec.anchor[1])-int(alpha[1])}
	return {"ready_art":ready_art,"errors":errors.duplicate(),"view_errors":view_errors.duplicate(),"world_view":world_view,"frame_size":frame_size,"world_zoom":zoom,"north_y":north_y,"mountain_repeats":false,"source_shift_limit":128,"layers":specs.duplicate(true),"mountain_projection":projected,"visual_or_input_acceptance":false}
