extends RefCounted
## Environmental motion uses the same cover/camera transform as its source art.
## Call after the background and before world actors. No UI/camera shake.
static func _transform(ci, source_size: Vector2) -> Transform2D:
	var area: Rect2 = ci.view_rect
	var k := maxf(area.size.x/source_size.x,area.size.y/source_size.y)
	var size := source_size*k
	var free_y := maxf(0,size.y-area.size.y)*0.5
	var offset := clampf(float(ci.camera_y),-free_y,free_y)
	return Transform2D(Vector2(k,0),Vector2(0,k),area.get_center()-size*0.5+Vector2(0,offset))

static func draw(ci, kind: String, time: float) -> void:
	match kind:
		"harbour": _harbour(ci,time)
		"boat": _boat(ci,time)
		"pool": _pool(ci,time)
		"street": _street(ci,time)
	ci.draw_set_transform(Vector2.ZERO)

static func _harbour(ci,time: float) -> void:
	ci.draw_set_transform_matrix(_transform(ci,Vector2(540,1200)))
	for i in range(36):
		var x := fposmod(i*87.0+time*(2.0+i%3),530.0)
		var y := 414.0+fposmod(i*47.0,385)
		var alpha := 0.07+0.07*(0.5+0.5*sin(time*1.4+i))
		ci.draw_rect(Rect2(roundf(x),roundf(y+sin(time+i)*1.8),8+i%4*4,1.5),Color(1,0.9,0.65,alpha))
	var boat: Texture2D = ci.texture("round1/scenes/harbour_boat.png")
	if boat:
		var x := fposmod(time*11.0+90,740)-100
		var y := 603+sin(time*1.2)*2
		var size := boat.get_size()*(146.0/boat.get_width())
		ci.draw_texture_rect(boat,Rect2(Vector2(x,y)-size*0.5,size),false)
		for i in range(4):
			ci.draw_line(Vector2(x-65-i*8,y+size.y*0.35+i*3),Vector2(x-106-i*5,y+size.y*0.35+i*3),Color(0.8,0.94,1,0.22-i*0.04),1.5)

static func _boat(ci,time: float) -> void:
	# Five windows, source pixels in the new 540×1200 cabin. The glints are
	# clipped to glass interior rectangles, never to the wood frame or people.
	ci.draw_set_transform_matrix(_transform(ci,Vector2(540,1200)))
	var panes := [Rect2(3,333,24,82),Rect2(49,338,28,76),Rect2(113,338,67,77),Rect2(205,338,130,76),Rect2(362,338,61,77),Rect2(464,337,28,76),Rect2(520,332,17,82)]
	for j in range(panes.size()):
		var pane: Rect2 = panes[j]
		for i in range(5):
			var y := pane.position.y+pane.size.y*0.64+i*4
			var x := pane.position.x+fposmod(time*7+i*19+j*3,maxf(1,pane.size.x-8))
			ci.draw_rect(Rect2(floorf(x),floorf(y),minf(8,pane.end.x-x),1),Color(1,0.85,0.54,0.19+0.08*sin(time+i)))
		var glow := 0.025+0.018*sin(time*0.65+j)
		ci.draw_rect(pane,Color(1,0.64,0.27,glow))

static func _pool(ci,time: float) -> void:
	# Final Wanning plate: only the pool interior, in source-image pixels.
	# Keep every glint inside this region, including its animated displacement.
	var tex: Texture2D = ci.texture(str(ci.bg))
	if not tex: return
	ci.draw_set_transform_matrix(_transform(ci,tex.get_size()))
	for i in range(24):
		ci.draw_rect(_pool_glint(i,time),Color(0.89,1,1,0.13+0.08*sin(time+i)))

static func _pool_glint(i: int,time: float) -> Rect2:
	var water := Rect2(560,580,280,165)
	var width := 8.0+i%4*3
	var x := water.position.x+fposmod(i*50.12+time*0.84,water.size.x-width)
	var y := water.position.y+3+fposmod(i*38.115,water.size.y-8)+sin(time*1.6+i)*1.3
	return Rect2(roundf(x),roundf(y),width,1.3)

static func _street(ci,time: float) -> void:
	ci.draw_set_transform_matrix(_transform(ci,Vector2(540,960)))
	var cars := ["car_street.png","car_parking.png"]
	for lane in range(2):
		var texture: Texture2D = ci.texture(cars[lane])
		if not texture: continue
		var x := fposmod(time*(27 if lane == 0 else -32)+lane*270,760)-110
		var y := 573.0+lane*25
		var size := texture.get_size()*(82.0/texture.get_width())
		ci.draw_texture_rect(texture,Rect2(Vector2(x,y)-Vector2(size.x*0.5,size.y),size),false,Color(0.83,0.87,0.91))
