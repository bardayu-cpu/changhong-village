extends SceneTree
const Home=preload("res://ayu_home/v4/home.gd")
const C=preload("res://ayu_home/v4/core/config.gd")
var h
var s
var out:=""
var rows:Array=[]
func _initialize():
 for a in OS.get_cmdline_user_args():
  if a.begins_with("--qa-out="):out=a.trim_prefix("--qa-out=")
 root.set_meta("player_profile",{"id":"c3-g2-views-1025","openid":"c3-g2-views-1025","avatar":2,"nick":"C3\u5171\u684c\u9694\u79bb"});call_deferred("run")
func check(ok:bool,label:String,data:Dictionary={}):rows.append({"pass":ok,"check":label,"details":data});print("CHECK ",ok," ",label)
func snap(name:String):
 for i in 6:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out+"/"+name+".png")
 var xf:Transform2D=h.world.get_global_transform_with_canvas()
 var objects:Array=[]
 for r in [Rect2(105,355,64,38),Rect2(255,270,30,24),Rect2(340,348,36,54)]:
  var rect=Rect2(xf*r.position,r.size*h.world.scale);objects.append([rect.position.x,rect.position.y,rect.size.x,rect.size.y])
 FileAccess.open(out+"/"+name+".json",FileAccess.WRITE).store_string(JSON.stringify({"name":name,"stage":int(s.data.village.community_stage),"position":[h.player.position.x,h.player.position.y],"hour":h.hour,"month":h.month,"weather":h.weather,"area":h.area,"window":[root.size.x,root.size.y],"world_scale":[h.world.scale.x,h.world.scale.y],"growth_object_screen_rects":objects,"items":s.data.village.items},"  "))
func angle(x:float):
 h.player.position=h.world.nearest(Vector2(x,470));h.player.route.clear();h.pending="";h.camera=h.room_camera_target();h.layout()
func run():
 root.size=Vector2i(540,960);h=Home.new();root.add_child(h)
 var deadline=Time.get_ticks_msec()+30000
 while not h.bootstrapped and Time.get_ticks_msec()<deadline:await process_frame
 if not h.bootstrapped:quit(1);return
 root.title="C3\u975eOS \u00b7 G2\u65e0\u906e\u6321\u89c6\u89d2"
 h.set_test_clock(13,10,"clear");await h.enter_room("living",false);s=h.village_ui.state
 s.now_override=Time.get_unix_time_from_datetime_string("2026-10-25T13:00:00")-int(Time.get_time_zone_from_system().bias)*60
 await snap("Ayu-13")
 check(s.act("visit").ok,"normal visit")
 for pet in C.PETS:check(s.act("animal",{"id":pet}).ok,"normal supply "+pet)
 check(s.act("plant",{"plot":0,"crop":"radish"}).ok,"normal radish plant");check(s.act("plant",{"plot":1,"crop":"pepper"}).ok,"normal pepper plant")
 s.now_override+=300;check(s.act("harvest",{"plot":0}).ok,"normal radish harvest");check(s.act("harvest",{"plot":1}).ok,"normal pepper harvest")
 var tries:=0
 while (s.count("bamboo")<5 or s.count("stone")<1) and tries<20:
  s.now_override+=300
  for pet in C.PETS:s.act("animal",{"id":pet})
  tries+=1
 check(tries<20,"normal resource supply bounded",{"loops":tries})
 await h.enter_room("my_cabin",false)
 angle(235);await snap("stage0-left")
 angle(260);await snap("stage0-right")
 for stage in 3:
  var r:Dictionary=s.act("community_grow");check(r.ok,"normal community_grow "+str(stage+1),r)
  check(int(s.data.village.community_stage)==stage+1,"visible stage state "+str(stage+1))
  h.village_ui.institution_room.queue_redraw();angle(235 if stage<2 else 260)
  await snap("stage%d-full-target"%[stage+1])
 FileAccess.open(out+"/result.json",FileAccess.WRITE).store_string(JSON.stringify({"mode":"non-OS Home scene rendering, normal supply/plant/harvest/community_grow transactions; explicit view-position fixture, no awards or stages injected","rows":rows,"scope":"three new objects full visible angle only; not whole scene or NPC art approval","OS_input":false},"  "))
 h.village_ui.checkpoint();h.queue_free();await process_frame;quit(0)
