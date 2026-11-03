extends SceneTree
const Home=preload("res://ayu_home/v4/home.gd")
var h
var out:=""
func _initialize():
 for a in OS.get_cmdline_user_args():
  if a.begins_with("--qa-out="):out=a.trim_prefix("--qa-out=")
 root.set_meta("player_profile",{"id":"c3-winding-preview","openid":"c3-winding-preview","avatar":2,"nick":"C3 winding lanes"});call_deferred("run")
func snap(name:String):
 for i in 5:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out+"/"+name+".png")
 FileAccess.open(out+"/"+name+".json",FileAccess.WRITE).store_string(JSON.stringify({"area":h.area,"hour":h.hour,"month":h.month,"scale":h.view_scale,"position":[h.player.position.x,h.player.position.y],"fixture":"same normal scale; isolated candidate; player seed position explicitly chosen for review"},"  "))
func run():
 root.size=Vector2i(540,960);Engine.max_fps=30;h=Home.new();root.add_child(h)
 var until=Time.get_ticks_msec()+30000
 while not h.bootstrapped and Time.get_ticks_msec()<until:await process_frame
 if not h.bootstrapped:quit(1);return
 h.close_modal();h.set_test_clock(13,7,"clear")
 h.village_ui.state.now_override=Time.get_unix_time_from_datetime_string("2027-07-15T13:00:00")-int(Time.get_time_zone_from_system().bias)*60
 await h.enter_room("village",false)
 var points=JSON.parse_string(FileAccess.get_file_as_string(out+"/../查看坐标.json"))
 var pos:Array=points.main_road_view
 h.player.position=h.world.nearest(Vector2(pos[0],pos[1]));h.camera=h.room_camera_target();h.layout()
 await snap("curved-main-lane-13")
 h.village_ui.show_page("地图");await snap("curved-map-13");h.village_ui.close()
 h.player.position=h.world.nearest(Vector2(600,4100));h.camera=h.room_camera_target();h.layout()
 await snap("curved-south-lane-13")
 await h.enter_room("living",false);h.player.position=h.world.nearest(Vector2(385,338));h.camera=h.room_camera_target();h.layout();await snap("Ayu-13")
 # Restore the normal-scale curved main lane, leave it visible for review.
 await h.enter_room("village",false);h.player.position=h.world.nearest(Vector2(pos[0],pos[1]));h.camera=h.room_camera_target();h.layout()
 root.title="裳泓村 · 蜿蜒小路候选"
 root.close_requested.connect(func():quit())
 print("WINDING_PREVIEW_READY")

