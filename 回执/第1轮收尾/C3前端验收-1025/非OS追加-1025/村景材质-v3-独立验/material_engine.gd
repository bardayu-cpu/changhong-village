extends SceneTree
const Home=preload("res://ayu_home/v4/home.gd")
var h
var out:=""
var rows:Array=[]
var shots:Array=[]
func _initialize():
 for a in OS.get_cmdline_user_args():
  if a.begins_with("--qa-out="):out=a.trim_prefix("--qa-out=")
 root.set_meta("player_profile",{"id":"c3-v3-materials","openid":"c3-v3-materials","avatar":2,"nick":"C3 materials"});call_deferred("run")
func check(ok:bool,label:String,details:Dictionary={}):
 rows.append({"pass":ok,"check":label,"details":details});print("CHECK ",ok," ",label)
func snap(name:String,extra:Dictionary={}):
 for i in 4:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out+"/"+name+".png")
 var m={"name":name,"area":h.area,"hour":h.hour,"month":h.month,"weather":h.weather,"state_date":h.village_ui.state.date_key(),"state_season":h.village_ui.state.season(),"position":[h.player.position.x,h.player.position.y],"camera":[h.camera.x,h.camera.y],"view_scale":h.view_scale,"extra":extra}
 FileAccess.open(out+"/"+name+".json",FileAccess.WRITE).store_string(JSON.stringify(m,"  "));shots.append(m)
func map_in(n:Node):
 if n.get_script()!=null and n.get_script().resource_path=="res://ayu_home/v4/core/map_view.gd":return n
 for c in n.get_children():
  var v=map_in(c)
  if v!=null:return v
 return null
func run():
 root.size=Vector2i(540,960);Engine.max_fps=30;h=Home.new();root.add_child(h)
 var until=Time.get_ticks_msec()+30000
 while not h.bootstrapped and Time.get_ticks_msec()<until:await process_frame
 if not h.bootstrapped:quit(1);return
 root.title="C3 non-OS v3 materials"
 var geom:=""
 for month in [4,7,10,12]:
  h.village_ui.close();h.set_test_clock(13,month,"clear")
  h.village_ui.state.now_override=Time.get_unix_time_from_datetime_string("2027-%02d-15T13:00:00"%month)-int(Time.get_time_zone_from_system().bias)*60
  await h.enter_room("village",false)
  var g=h.world.village_ground
  var sig:String=var_to_str([g.polygons,g.field_rects,g.field_tiles.map(func(x):return x.polygon)])
  if geom.is_empty():geom=sig
  check(sig==geom,"same geometry four seasons month "+str(month))
  check(g.field_tiles.size()==5,"five rice fields mounted month "+str(month))
  var season_key:String=["spring","summer","autumn","winter"][g.season_index]
  for f in g.field_tiles:
   var file:String=f.spec.season_files[season_key]
   var tex=load("res://ayu_home/v2/assets.gd").texture(file)
   check(tex!=null and tex.get_size()==Vector2(256,256),"actual season texture "+str(f.spec.id)+" "+season_key,{"file":file})
  h.player.position=h.world.nearest(Vector2(3528,1304));h.camera=h.room_camera_target();h.layout()
  await snap("field-month"+str(month),{"selected_season":season_key})
  h.player.position=h.world.nearest(Vector2(4580,600));h.camera=h.room_camera_target();h.layout()
  await snap("north-month"+str(month),{"selected_season":season_key})
  h.village_ui.show_page("地图")
  for i in 3:await process_frame
  var map=map_in(h.village_ui.root)
  check(map!=null,"actual map mounted")
  if map!=null:
   var mg:String=var_to_str([map.terrain.polygons,map.terrain.field_rects,map.terrain.field_tiles.map(func(x):return x.polygon)])
   check(mg==sig,"map world same geometry")
   check(map.terrain.season_index==g.season_index,"map world same season")
  await snap("map-month"+str(month))
  h.village_ui.close();await h.enter_room("living",false);h.player.position=h.world.nearest(Vector2(385,338));h.camera=h.room_camera_target();h.layout();await snap("Ayu-month"+str(month))
 FileAccess.open(out+"/result.json",FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"shots":shots,"mode":"non-OS actual world and map rendering, explicit diagnostic clock/position; no production migration; geometry reused only after independent exact source comparison","OS_input":false,"whole_village_art_pass":false,"missing":["tree art/footprints","9 interiors"],"visual_review_pending":true},"  "))
 h.queue_free();await process_frame;quit(0)
