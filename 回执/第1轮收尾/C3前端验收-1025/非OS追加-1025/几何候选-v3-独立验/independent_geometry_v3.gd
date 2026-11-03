extends SceneTree
const World=preload("res://ayu_home/v4/world.gd")
const Actor=preload("res://ayu_home/v4/actor.gd")
const Ground=preload("res://ayu_home/v4/core/village_ground.gd")
var w
var terrain
var layout:Dictionary
var water:PackedVector2Array
var rows:Array=[]
var routes:Array=[]
var out:=""
var field_polys:Array=[]
func _initialize():
 for a in OS.get_cmdline_user_args():
  if a.begins_with("--qa-out="):out=a.trim_prefix("--qa-out=")
 call_deferred("run")
func check(ok:bool,label:String,data:Dictionary={}):rows.append({"pass":ok,"check":label,"details":data})
func packed(values:Array) -> PackedVector2Array:
 var p:=PackedVector2Array()
 for a in values:p.append(Vector2(a[0],a[1]))
 return p
func area(poly:PackedVector2Array) -> float:
 var total:=0.0
 for i in poly.size():
  var a:Vector2=poly[i];var b:Vector2=poly[(i+1)%poly.size()];total+=a.cross(b)
 return absf(total)*.5
func inside_any(p:Vector2,polys:Array) -> bool:
 for poly in polys:
  if Geometry2D.is_point_in_polygon(p,poly):return true
 return false
func rectangle_polygon(r:Rect2) -> PackedVector2Array:return PackedVector2Array([r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)])
func independent_collision(p:Vector2) -> String:
 if Geometry2D.is_point_in_polygon(p,water):return "water"
 for b in w.cfg.obstacles:
  var r:=Rect2(b[0],b[1],b[2],b[3]).grow(3)
  if p.x>r.position.x+.001 and p.x<r.end.x-.001 and p.y>r.position.y+.001 and p.y<r.end.y-.001:return "solid_rect"
 return ""
func walk_test(id:String,requested:Vector2,kind:String):
 var start:Vector2=w.spawn();var finish:Vector2=w.nearest(requested);var path:PackedVector2Array=w.path(start,requested)
 var report={"id":id,"kind":kind,"requested":[requested.x,requested.y],"snapped":[finish.x,finish.y],"snap_distance":finish.distance_to(requested),"path_points":[],"collisions":[],"off_surface_samples":0,"field_interior_samples":0,"surface_samples":0,"off_surface_examples":[]}
 for q in path:report.path_points.append([q.x,q.y])
 check(path.size()>1,"route exists "+id)
 check(report.snap_distance<=float(w.CELL)*sqrt(2.0)*.5+.01,"approach within one cell snap "+id,{"distance":report.snap_distance})
 if path.size()<2:routes.append(report);return
 var actor=Actor.new();actor.position=start;actor.route=path;actor.destination_action="idle"
 var steps:=0;var last_surface:=start-Vector2(99,99)
 while not actor.route.is_empty() and steps<100000:
  var previous:Vector2=actor.position;actor.move_along(1.0/30.0,135);steps+=1
  for point in [previous.lerp(actor.position,.5),actor.position]:
   var collision:=independent_collision(point)
   if not collision.is_empty() and report.collisions.size()<20:report.collisions.append({"point":[point.x,point.y],"kind":collision})
  if last_surface.distance_to(actor.position)>=16:
   last_surface=actor.position;report.surface_samples+=1
   if not inside_any(actor.position,terrain.polygons.road+terrain.polygons.entry_road+terrain.polygons.yard):
    report.off_surface_samples+=1
    if inside_any(actor.position,field_polys):report.field_interior_samples+=1
    if report.off_surface_examples.size()<5:report.off_surface_examples.append([actor.position.x,actor.position.y])
 check(actor.position.distance_to(finish)<.1,"actual Actor move_along arrives "+id)
 check(report.collisions.is_empty(),"independent foot samples avoid solids/water "+id,{"collisions":report.collisions})
 report.steps=steps;report.end=[actor.position.x,actor.position.y];routes.append(report);actor.free()
func run():
 w=World.new();w.nav_only=true;root.add_child(w);w.set_process(false);w.load_room("village")
 layout=JSON.parse_string(FileAccess.get_file_as_string("res://ayu_home/v4/assets/village/layout-1025.json"));water=packed(layout.water_polygon)
 terrain=Ground.new();root.add_child(terrain);terrain.configure_path(str(w.cfg.ground_layers),w.asset_path(str(w.cfg.background)));terrain.mount_layers(func(_kind):return null)
 for f in layout.fields:
  if f.has("polygon"):field_polys.append(packed(f.polygon))
  else:field_polys.append(rectangle_polygon(Rect2(f.rect[0],f.rect[1],f.rect[2],f.rect[3])))
 check(w.cfg.get("rebuild_navigation",false),"candidate rebuilds navigation rather than old baked mask")
 check(w.cfg.doors.size()==19,"19 effective doors")
 check(w.cfg.hotspots.size()==11,"11 public/closed/loach hotspots")
 var old:Dictionary=w.spot("visit_laowu");check(old.get("kind","")=="closed_house" and not old.has("target"),"old house remains naturally closed")
 var frozen_ids:Array=[]
 for house in layout.houses:frozen_ids.append(str(house.id))
 var house_entry_ids:Array=[]
 var public_entry_ids:Array=[]
 for entry in layout.entry_paths:
  if str(entry.id) in frozen_ids:house_entry_ids.append(str(entry.id))
  else:public_entry_ids.append(str(entry.id))
 check(house_entry_ids.size()==20 and frozen_ids.all(func(id):return id in house_entry_ids),"20 house entry paths including closed front")
 check(public_entry_ids.size()==12,"only 12 declared public/spawn spurs",{"ids":public_entry_ids})
 check(terrain.polygons.bridge.is_empty(),"no bridge geometry")
 check(not w.cfg.props.any(func(p):return "bridge" in str(p.id)),"no bridge props")
 var layout_houses:Dictionary={}
 for h in layout.houses:layout_houses[str(h.id)]=h
 var houses:Array=JSON.parse_string(FileAccess.get_file_as_string("res://ayu_home/v4/assets/village/houses.json"))
 check(houses.size()==20 and layout_houses.size()==20,"exact 20 house identities")
 for h in houses:
  var raw:Dictionary=layout_houses.get(str(h.id),{});var bound:Array=h.bounds
  check(not raw.is_empty() and Vector2(bound[0],bound[1]).distance_to(Vector2(raw.pos[0],raw.pos[1]))<.01 and Vector2(bound[2],bound[3]).distance_to(Vector2(raw.bounds_size[0],raw.bounds_size[1]))<.01,"C4 frozen house bounds "+str(h.id))
  var hits:Array=Geometry2D.intersect_polygons(rectangle_polygon(Rect2(bound[0],bound[1],bound[2],bound[3])),water)
  check(hits.is_empty(),"house entirely land-side "+str(h.id))
 var material_overlap:Array=[];var water_overlap:Array=[]
 for kind in ["road","yard","entry_road"]:
  for poly in terrain.polygons[kind]:
   for b in w.cfg.obstacles:
    var overlaps:Array=Geometry2D.intersect_polygons(poly,rectangle_polygon(Rect2(b[0],b[1],b[2],b[3])))
    for overlap in overlaps:
     if area(overlap)>.1:material_overlap.append({"surface":kind,"obstacle":b,"area":area(overlap)})
   for overlap in Geometry2D.intersect_polygons(poly,water):
    if area(overlap)>.1:water_overlap.append({"surface":kind,"area":area(overlap)})
 check(material_overlap.is_empty(),"drawn road/field-path/entry polygons avoid collision footprints",{"overlap_count":material_overlap.size(),"first_overlaps":material_overlap.slice(0,12)})
 check(water_overlap.is_empty(),"drawn paths do not create hidden river crossings",{"overlaps":water_overlap})
 var baseline:=var_to_str([terrain.polygons,terrain.field_rects,terrain.field_tiles])
 var seasons:Array=[]
 for index in 4:
  terrain.set_season(index)
  var visible:Array=[]
  for layer in terrain.get_children():visible.append(layer.visible)
  check(var_to_str([terrain.polygons,terrain.field_rects,terrain.field_tiles])==baseline and visible.all(func(v):return v),"candidate geometry/layers stable season "+str(index))
  seasons.append({"season_index":index,"geometry_sha256":baseline.sha256_text(),"visible_layers":visible.size()})
 for d in w.cfg.doors:
  walk_test(str(d.id),World.v(d.approach),"door")
  var plane:Dictionary=w.door_plane(d);var normal:Vector2=plane.normal;var point:Vector2=plane.point
  check(w.crossed_door(d,point-normal*8,point+normal*8),"normal door-plane crossing can trigger "+str(d.id))
 for h in w.cfg.hotspots:walk_test(str(h.id),World.v(h.approach),str(h.kind))
 walk_test("north_mountain_viewpoint",Vector2(4580,600),"normal_route_viewpoint")
 var loach:Dictionary=w.spot("loach_memory");check(not loach.is_empty() and not Geometry2D.is_point_in_polygon(World.v(loach.approach),water),"S2 bank approach land-side")
 var off_field:Array=[]
 for route in routes:
  if int(route.field_interior_samples)>0:off_field.append({"id":route.id,"field_interior_samples":route.field_interior_samples,"surface_samples":route.surface_samples,"examples":route.off_surface_examples})
 FileAccess.open(out+"/result.json",FileAccess.WRITE).store_string(JSON.stringify({"mode":"independent headless actual World/AStar + Actor.move_along fixed 1/30 engine steps; independent rectangle/water/material intersection and route surface sampling; no OS input, no C2 result assertions reused","rows":rows,"routes":routes,"road_collision_overlaps":material_overlap,"path_water_overlaps":water_overlap,"routes_entering_field_interiors":off_field,"seasons":seasons,"art_scope":"empty field material / trees pending, not visual acceptance","OS_input":false},"  "))
 print(JSON.stringify({"checks":rows.size(),"failures":rows.filter(func(r):return not r.pass).size(),"routes":routes.size(),"material_overlaps":material_overlap.size(),"routes_entering_fields":off_field.size()}))
 w.queue_free();terrain.queue_free();await process_frame;quit(0)
