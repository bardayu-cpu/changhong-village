extends SceneTree
func _initialize():call_deferred("run")
func point(a:Array)->Vector2:return Vector2(a[0],a[1])
func plain(poly:PackedVector2Array)->Array:
 var result:Array=[]
 for v in poly:result.append([v.x,v.y])
 return result
func bounds(poly:PackedVector2Array)->Rect2:
 var b:=Rect2(poly[0],Vector2.ZERO)
 for v in poly:b=b.expand(v)
 return b
func run():
 var layout=JSON.parse_string(FileAccess.get_file_as_string("res://ayu_home/v4/assets/village/layout-1025.json"))
 var cfg=JSON.parse_string(FileAccess.get_file_as_string("res://ayu_home/v4/assets/village.json"))
 var g=load("res://ayu_home/v4/core/village_ground.gd").new();root.add_child(g);g.configure_path(str(cfg.ground_layers),str(cfg.background))
 var surfaces:Array=g.polygons.road+g.polygons.entry_road+g.polygons.yard
 var junctions:Array=[]
 for line in layout.roads+layout.field_paths+layout.entry_paths:junctions.append(point(line.points[0]));junctions.append(point(line.points[-1]))
 var runs:Array=[]
 for road in layout.roads:
  if not str(road.id) in ["main","south_plot_access"]:continue
  var current:=PackedVector2Array()
  for i in range(1,road.points.size()):
   var a:=point(road.points[i-1]);var b:=point(road.points[i]);var tangent:Vector2=(b-a).normalized();var side:=Vector2(-tangent.y,tangent.x)
   var p:Vector2=b+side*(float(road.width)*.5+25)
   var allowed:bool=(road.id=="main" and b.y>1170 and b.y<2680 and b.x>3400) or (road.id=="south_plot_access" and b.y>3940 and b.y<4430)
   for j in junctions:
    if b.distance_to(j)<70:allowed=false
   for box in layout.surface_obstacles:
    if Rect2(box[0],box[1],box[2],box[3]).grow(20).has_point(p):allowed=false
   if allowed:current.append(p)
   else:
    if current.size()>5:runs.append(current)
    current=PackedVector2Array()
  if current.size()>5:runs.append(current)
 for previous in layout.get("irrigation_channels",[]):cfg.blocked_polygons.erase(previous.polygon)
 layout.irrigation_channels=[]
 for line in runs:
  for poly in Geometry2D.offset_polyline(line,7,Geometry2D.JOIN_ROUND,Geometry2D.END_ROUND):
   var pieces:Array=[poly]
   for solid in surfaces:
    if not bounds(poly).intersects(bounds(solid).grow(3)):continue
    var next:Array=[]
    for piece in pieces:next.append_array(Geometry2D.clip_polygons(piece,solid))
    pieces=next
   for piece in pieces:
    if piece.size()<3:continue
    layout.irrigation_channels.append({"polygon":plain(piece),"centre":plain(line),"kind":"shallow roadside irrigation; stops before lane junctions"})
    cfg.blocked_polygons.append(plain(piece))
 FileAccess.open("res://ayu_home/v4/assets/village/layout-1025.json",FileAccess.WRITE).store_string(JSON.stringify(layout,"  "))
 FileAccess.open("res://ayu_home/v4/assets/village.json",FileAccess.WRITE).store_string(JSON.stringify(cfg,"  "))
 var rooms=JSON.parse_string(FileAccess.get_file_as_string("res://ayu_home/v4/assets/rooms.json"));rooms.rooms.village=cfg
 FileAccess.open("res://ayu_home/v4/assets/rooms.json",FileAccess.WRITE).store_string(JSON.stringify(rooms,"  "))
 print("IRRIGATION_RUNS ",layout.irrigation_channels.size());g.free();quit()
