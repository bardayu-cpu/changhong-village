extends SceneTree
const Home=preload("res://ayu_home/v4/home.gd")
var h
var out:=""
func _initialize():
 for a in OS.get_cmdline_user_args():
  if a.begins_with("--qa-out="):out=a.trim_prefix("--qa-out=")
 root.set_meta("player_profile",{"id":"c3-g2-views-1025","openid":"c3-g2-views-1025","avatar":2,"nick":"C3\u5171\u684c\u9694\u79bb"});call_deferred("run")
func run():
 root.size=Vector2i(540,960);h=Home.new();root.add_child(h)
 var deadline=Time.get_ticks_msec()+30000
 while not h.bootstrapped and Time.get_ticks_msec()<deadline:await process_frame
 if not h.bootstrapped:quit(1);return
 h.set_test_clock(13,10,"clear");await h.enter_room("my_cabin",false)
 h.player.position=h.world.nearest(Vector2(380,530));h.player.route.clear();h.pending="";h.camera=h.room_camera_target();h.layout()
 for i in 8:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out+"/stage3-full-easel.png")
 var xf:Transform2D=h.world.get_global_transform_with_canvas();var object_rect:=Rect2(xf*Vector2(340,348),Vector2(36,54)*h.world.scale)
 var actor_rect:=Rect2(xf*(h.player.position-Vector2(32,84)),Vector2(64,84)*h.world.scale)
 FileAccess.open(out+"/result.json",FileAccess.WRITE).store_string(JSON.stringify({"mode":"non-OS additional view angle only, reopens own normal stage3 checkpoint; no stage or reward write","stage":h.village_ui.state.data.village.community_stage,"position":[h.player.position.x,h.player.position.y],"easel_screen":[object_rect.position.x,object_rect.position.y,object_rect.size.x,object_rect.size.y],"inside_window":object_rect.position.x>=0 and object_rect.end.x<=540 and object_rect.position.y>=110 and object_rect.end.y<=804,"not_intersecting_player_quad":not object_rect.intersects(actor_rect),"hour":h.hour,"month":h.month,"weather":h.weather,"window":[root.size.x,root.size.y]},"  "))
 h.village_ui.checkpoint();h.queue_free();await process_frame;quit(0)
