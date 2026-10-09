extends Node2D
const Data = preload("res://ayu_home/home_data.gd")
const Art = preload("res://ayu_home/asset_store.gd")
const CELL := 16.0*Data.WORLD_SCALE
const GRID_WIDTH := int(Data.SIZE.x/CELL)
const GRID_HEIGHT := int(Data.SIZE.y/CELL)
var area := "exterior"
var month := 4
var hour := 12.0
var art: Texture2D
var grid := AStarGrid2D.new()
var walkers: Node2D
var foregrounds: Array = []
var show_spots := true
var elapsed := 0.0
var selected := ""
var loaded_season := -1

func _ready() -> void:
	walkers = Node2D.new()
	walkers.y_sort_enabled = true
	add_child(walkers)
	set_area(area)

func set_area(value: String) -> void:
	area = value
	var filename := area
	if area == "garden":
		loaded_season = Data.season(month)
		filename = ["garden_spring","garden_summer","garden","garden_winter"][loaded_season]
	art = Art.texture(filename+".png")
	if not art: art = Art.texture(area+".png")
	for node in foregrounds: node.queue_free()
	foregrounds.clear()
	grid.region = Rect2i(0,0,GRID_WIDTH,GRID_HEIGHT)
	grid.cell_size = Vector2(CELL,CELL)
	grid.offset = Vector2(CELL/2.0,CELL/2.0)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH): grid.set_point_solid(Vector2i(x,y),not walkable(Vector2(x*CELL+CELL/2,y*CELL+CELL/2)))
	if art and walkers and area != "garden":
		var index := 0
		for rect: Rect2 in Data.obstacles(area):
			var node := Node2D.new()
			node.position = Vector2(0,rect.end.y)
			var sprite := Polygon2D.new()
			sprite.texture = art
			var ratio := art.get_size()/Data.SIZE
			var points := PackedVector2Array()
			var uv := PackedVector2Array()
			if area == "floor1" and index in [0,8]:
				for i in range(24): points.append(rect.get_center()+Vector2(cos(i*TAU/24),sin(i*TAU/24))*rect.size/2.0)
			else:
				var bevel := minf(rect.size.x,rect.size.y)*.09
				points = PackedVector2Array([rect.position+Vector2(bevel,0),rect.position+Vector2(rect.size.x-bevel,0),rect.position+Vector2(rect.size.x,bevel),rect.end-Vector2(0,bevel),rect.end-Vector2(bevel,0),rect.position+Vector2(bevel,rect.size.y),rect.position+Vector2(0,rect.size.y-bevel),rect.position+Vector2(0,bevel)])
			for point in points: uv.append(point*ratio)
			for i in range(points.size()): points[i] -= node.position
			sprite.polygon = points
			sprite.uv = uv
			node.add_child(sprite)
			walkers.add_child(node)
			foregrounds.append(node)
			index += 1
	queue_redraw()

func walkable(point: Vector2) -> bool:
	var inside := false
	for rect: Rect2 in Data.rooms(area).values():
		if rect.has_point(point): inside = true; break
	if not inside:
		for rect: Rect2 in Data.doors(area):
			if rect.has_point(point): inside = true; break
	if not inside: return false
	for rect: Rect2 in Data.obstacles(area):
		if rect.grow(18*Data.WORLD_SCALE).has_point(point): return false
	return true

func nearest(point: Vector2) -> Vector2:
	var cell := Vector2i(clampi(int(point.x/CELL),0,GRID_WIDTH-1),clampi(int(point.y/CELL),0,GRID_HEIGHT-1))
	if not grid.is_point_solid(cell): return grid.get_point_position(cell)
	var best := Vector2.ZERO
	var distance := INF
	for ring in range(1,maxi(GRID_WIDTH,GRID_HEIGHT)+1):
		for dy in range(-ring,ring+1):
			for dx in range(-ring,ring+1):
				if abs(dx) != ring and abs(dy) != ring: continue
				var check := cell+Vector2i(dx,dy)
				if not grid.is_in_boundsv(check) or grid.is_point_solid(check): continue
				var position_at := grid.get_point_position(check)
				var value := position_at.distance_squared_to(point)
				if value < distance: distance = value; best = position_at
		if distance < INF: return best
	return Data.spawn(area)

func path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var start := Vector2i(nearest(from)/CELL)
	var finish := Vector2i(nearest(to)/CELL)
	return grid.get_point_path(start,finish)

func hotspot_at(point: Vector2, radius := 74.0*Data.WORLD_SCALE) -> Dictionary:
	var best := {}
	var distance := radius
	for item: Dictionary in Data.hotspots(area):
		var d := point.distance_to(item.pos)
		if d < distance: distance = d; best = item
	return best

func _process(dt: float) -> void:
	elapsed += dt
	if area == "garden" and loaded_season != Data.season(month): set_area(area)
	queue_redraw()

func _draw() -> void:
	if art: draw_texture_rect(art,Rect2(Vector2.ZERO,Data.SIZE),false)
	else: draw_rect(Rect2(Vector2.ZERO,Data.SIZE),Color("bda47d"))
	if area == "garden": _draw_season()
	if show_spots:
		for item: Dictionary in Data.hotspots(area):
			var v: Vector2 = item.pos
			var active: bool = item.id == selected
			draw_circle(v,(20 if active else 12)*Data.WORLD_SCALE,Color(1,.91,.68,.85 if active else .68))
			draw_arc(v,(22 if active else 15)*Data.WORLD_SCALE,0,TAU,24,Color(.35,.24,.12,.85),2*Data.WORLD_SCALE)
			draw_circle(v,4*Data.WORLD_SCALE,Color("76552f"))
	if area in ["exterior","garden"]:
		for i in range(12):
			var x := 80.0+fmod(i*157.0+elapsed*13.0,1390.0)
			var y := 230.0+sin(elapsed*1.1+i)*22.0+i*52.0
			draw_circle(Vector2(x,y)*Data.WORLD_SCALE,3*Data.WORLD_SCALE,Color(1,.88,.45,.45 if hour >= 18 else .25))

func _draw_season() -> void:
	var season := Data.season(month)
	if season == 3:
		for i in range(28):
			var at := Vector2(fmod(i*87.0+elapsed*5,1536),fmod(i*143.0+elapsed*14,1100))*Data.WORLD_SCALE
			draw_rect(Rect2(at,Vector2(3,3)*Data.WORLD_SCALE),Color(1,1,.96,.60))
	# Butterflies, bees, birds and ground wildlife have visibly different seasonal motion.
	for i in range(5):
		var v := Data.p(.36+i*.12,.72)+Vector2(sin(elapsed*(1.1 if season != 2 else .4)+i)*27,cos(elapsed*1.6+i)*13)*Data.WORLD_SCALE
		var wing := 5+int(abs(sin(elapsed*8+i))*5)
		if season == 2 and i % 2 == 0: v.y = Data.SIZE.y*.765
		elif season == 3 and i % 2 == 0: v.y = Data.SIZE.y*.795
		draw_set_transform(v,0,Vector2.ONE*Data.WORLD_SCALE)
		v = Vector2.ZERO
		if season == 0 and i % 2 == 0:
			draw_rect(Rect2(v-Vector2(wing,8),Vector2(wing,14)),Color("e9a5c2"))
			draw_rect(Rect2(v+Vector2(3,-8),Vector2(wing,14)),Color("e9a5c2"))
			draw_rect(Rect2(v,Vector2(3,12)),Color("675445"))
		elif season == 1 and i % 2 == 0:
			draw_rect(Rect2(v,Vector2(15,9)),Color("e7b84f"))
			draw_rect(Rect2(v+Vector2(4,0),Vector2(3,9)),Color("57442f"))
			draw_rect(Rect2(v+Vector2(10,0),Vector2(3,9)),Color("57442f"))
			draw_rect(Rect2(v+Vector2(-2,-wing/2),Vector2(9,4)),Color("e6eee1"))
			draw_rect(Rect2(v+Vector2(8,-wing/2),Vector2(9,4)),Color("e6eee1"))
		elif season == 1:
			draw_rect(Rect2(v+Vector2(6,-3),Vector2(3,24)),Color("47918c"))
			draw_rect(Rect2(v-Vector2(13,1),Vector2(40,4)),Color("bfdbd4"))
			draw_rect(Rect2(v-Vector2(11,-6),Vector2(36,4)),Color("bfdbd4"))
		elif season == 2 and i % 2 == 0:
			draw_rect(Rect2(v,Vector2(18,13)),Color("bb7645"))
			draw_rect(Rect2(v+Vector2(12,-7),Vector2(9,11)),Color("bb7645"))
			draw_rect(Rect2(v-Vector2(8,14),Vector2(10,22)),Color("cd9160"))
			draw_rect(Rect2(v+Vector2(18,-5),Vector2(2,2)),Color("3c3229"))
		elif season == 3 and i % 2 == 0:
			draw_rect(Rect2(v-Vector2(3,3),Vector2(22,14)),Color("897557"))
			for spike in range(5): draw_rect(Rect2(v+Vector2(spike*4,-6-(spike%2)*3),Vector2(3,7)),Color("625c47"))
			draw_rect(Rect2(v+Vector2(17,4),Vector2(8,7)),Color("b7a078"))
			draw_rect(Rect2(v+Vector2(24,4),Vector2(3,3)),Color("3c3229"))
		else:
			draw_rect(Rect2(v,Vector2(17,9)),Color("5c705f") if season != 3 else Color("a5a187"))
			draw_rect(Rect2(v+Vector2(12,-5),Vector2(7,7)),Color("5c705f") if season != 3 else Color("a5a187"))
			draw_rect(Rect2(v+Vector2(19,-2),Vector2(5,2)),Color("d8aa54"))
			draw_line(v+Vector2(6,3),v+Vector2(2,-wing),Color("3d574e"),4)
			draw_line(v+Vector2(8,3),v+Vector2(16,-wing),Color("3d574e"),4)

	draw_set_transform(Vector2.ZERO)
