extends SceneTree
const Home=preload("res://ayu_home/v4/home.gd")
var h
var out:=""
var rows:Array=[]
var shots:Array=[]
func _initialize():
 for a in OS.get_cmdline_user_args():
  if a.begins_with("--qa-out="):out=a.trim_prefix("--qa-out=")
 root.set_meta("player_profile",{"id":"c3-winter-engine-1025","openid":"c3-winter-engine-1025","avatar":2,"nick":"C3\u51ac\u5b63\u5f15\u64ce\u9694\u79bb"});call_deferred("run")
func check(ok:bool,label:String,data:Dictionary={}):
 rows.append({"pass":ok,"check":label,"details":data});print("CHECK ",ok," ",label)
func snap(name:String,extra:Dictionary={}):
 for i in 4:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out+"/"+name+".png")
 var meta={"name":name,"area":h.area,"hour":h.hour,"month":h.month,"weather":h.weather,"position":[h.player.position.x,h.player.position.y],"window":[root.size.x,root.size.y],"world_scale":[h.world.scale.x,h.world.scale.y],"extra":extra}
 FileAccess.open(out+"/"+name+".json",FileAccess.WRITE).store_string(JSON.stringify(meta,"  "));shots.append(meta)
func find_map(node:Node):
 if node.get_script()!=null and node.get_script().resource_path=="res://ayu_home/v4/core/map_view.gd":return node
 for child in node.get_children():
  var found=find_map(child)
  if found!=null:return found
 return null
func run():
 root.size=Vector2i(540,960);h=Home.new();root.add_child(h)
 var deadline=Time.get_ticks_msec()+30000
 while not h.bootstrapped and Time.get_ticks_msec()<deadline:await process_frame
 if not h.bootstrapped:quit(1);return
 root.title="C3\u975eOS \u00b7 \u51ac\u5b63\u51e0\u4f55"
 var baseline:="";var collision_base:="";var terrain_rows:Array=[]
 for month in [4,7,10,12,4]:
  h.village_ui.close();h.set_test_clock(13,month,"clear")
  h.village_ui.state.now_override=Time.get_unix_time_from_datetime_string("2026-%02d-15T13:00:00"%month)-int(Time.get_time_zone_from_system().bias)*60
  await h.enter_room("village",false)
  h.player.position=h.world.nearest(Vector2(1240,650));h.camera=h.room_camera_target();h.layout()
  for i in 4:await process_frame
  var g=h.world.village_ground
  var geometry:String=var_to_str([g.polygons,g.field_rects,g.field_tiles])
  var visible:Array=[]
  for child in g.get_children():visible.append({"name":str(child.name),"visible":child.visible})
  var collision:Array=[]
  for y in range(520,721,10):collision.append(h.world.passable(Vector2(1240,y)))
  var collision_sig:=var_to_str(collision)
  if baseline.is_empty():baseline=geometry;collision_base=collision_sig
  check(geometry==baseline,"same world geometry month "+str(month))
  check(collision_sig==collision_base,"same collision samples month "+str(month))
  check(visible.size()==8 and visible.all(func(x):return x.visible),"8 mounted layers visible month "+str(month))
  var route:PackedVector2Array=h.world.path(h.player.position,Vector2(1240,540))
  check(route.size()>1,"route exists month "+str(month))
  var name:="world-month%d-run%d"%[month,terrain_rows.size()]
  await snap(name,{"road_polygons":g.polygons.road.size(),"layers":visible})
  h.player.route=route;h.player.destination_action="idle"
  var frames:=0
  while not h.player.route.is_empty() and frames<300:await process_frame;frames+=1
  check(h.player.position.distance_to(h.world.nearest(Vector2(1240,540)))<3,"engine route arrival month "+str(month),{"position":[h.player.position.x,h.player.position.y],"frames":frames})
  var road_count:int=g.polygons.road.size()
  var world_geometry=geometry;h.village_ui.show_page("\u5730\u56fe")
  for i in 4:await process_frame
  var map=find_map(h.village_ui.root)
  check(map!=null,"actual map view exists month "+str(month))
  if map!=null:
   var mg:String=var_to_str([map.terrain.polygons,map.terrain.field_rects,map.terrain.field_tiles])
   check(mg==world_geometry,"map and world geometry equal month "+str(month))
  await snap("map-month%d-run%d"%[month,terrain_rows.size()])
  h.village_ui.close();await h.enter_room("living",false);h.player.position=h.world.nearest(Vector2(385,338));h.camera=h.room_camera_target();h.layout()
  await snap("Ayu-month%d-run%d"%[month,terrain_rows.size()])
  terrain_rows.append({"month":month,"road_polygons":road_count,"geometry_sha256":geometry.sha256_text(),"collision_samples":collision,"world":name})
 FileAccess.open(out+"/result.json",FileAccess.WRITE).store_string(JSON.stringify({"mode":"non-OS actual Home world/map render, engine navigation route; test clock only, no rewards/progress injection","rows":rows,"terrain":terrain_rows,"shots":shots,"scope":"old/current geometry season consistency only; not approval of new layout, bridges or river","OS_input":false},"  "))
 h.village_ui.checkpoint();h.queue_free();await process_frame;quit(0)
