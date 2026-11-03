extends SceneTree
const Home=preload("res://ayu_home/v4/home.gd")
var h
var obs
var out:=""
func _initialize():
 for a in OS.get_cmdline_user_args():
  if a.begins_with("--qa-out="):out=a.trim_prefix("--qa-out=")
 root.set_meta("player_profile",{"id":"c3-front-occlusion-1025","openid":"c3-front-occlusion-1025","avatar":2,"nick":"C3\u524d\u7aef\u72ec\u7acbQA"})
 call_deferred("run")
func run():
 root.size=Vector2i(540,960);Engine.max_fps=30
 h=Home.new();root.add_child(h)
 var deadline=Time.get_ticks_msec()+30000
 while not h.bootstrapped and Time.get_ticks_msec()<deadline:await process_frame
 if not h.bootstrapped:quit(1);return
 root.title="C3\u524d\u7aefQA \u00b7 \u4e09\u573a\u666f\u8fde\u7eed\u906e\u6321"
 obs=Observer.new();obs.h=h;obs.out=out;root.add_child(obs)
 await obs.setup_case(1)
 root.close_requested.connect(finish)
 print("C3_FRONT_READY")
 await create_timer(600).timeout
 finish()
func finish():
 h.village_ui.checkpoint()
 if obs!=null:obs.flush()
 quit(0)
class Observer extends Node:
 var h
 var out:String
 var rows:Array=[]
 var elapsed:=0.0
 var n:=0
 var current:=0
 var changing:=false
 var shot:=0
 func setup_case(which:int):
  changing=true;current=which;h.village_ui.close();h.close_modal();h.set_test_clock(13,10,"clear")
  var scene=["exterior","village","v_h3","living"][which-1]
  await h.enter_room(scene,false)
  var point=[Vector2(976,650),Vector2(1304,650),Vector2(142,490),Vector2(385,338)][which-1]
  h.player.position=h.world.nearest(point);h.camera=h.room_camera_target();h.layout();h.player.route.clear();h.pending=""
  rows.append({"type":"fixture setup, not normal travel","case":current,"area":h.area,"requested":[point.x,point.y],"position":[h.player.position.x,h.player.position.y],"wall":Time.get_unix_time_from_system(),"frame":Engine.get_process_frames(),"hour":h.hour,"month":h.month,"weather":h.weather})
  var line:Array=[]
  var a=h.player.position
  for i in 100:
   var q=a-Vector2(0,i)
   line.append({"point":[q.x,q.y],"passable":h.world.passable(q)})
  FileAccess.open(out+"/case%d-preflight.json"%current,FileAccess.WRITE).store_string(JSON.stringify(line,"  "))
  changing=false
  capture.call_deferred("start")
 func _input(e:InputEvent):
  if e is InputEventKey or e is InputEventMouseButton:
   rows.append({"type":"OS event","event":e.as_text(),"pressed":e.pressed,"case":current,"area":h.area,"position":[h.player.position.x,h.player.position.y],"wall":Time.get_unix_time_from_system(),"frame":Engine.get_process_frames()})
   if e is InputEventKey and e.pressed:
    if e.keycode in [KEY_F1,KEY_F2,KEY_F3,KEY_F4]:
     setup_case.call_deferred([KEY_F1,KEY_F2,KEY_F3,KEY_F4].find(e.keycode)+1);get_viewport().set_input_as_handled()
    elif e.keycode==KEY_F10:capture.call_deferred("keyframe");get_viewport().set_input_as_handled()
    elif e.keycode==KEY_F9:get_tree().finish.call_deferred();get_viewport().set_input_as_handled()
 func flush():
  FileAccess.open(out+"/trace.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
 func capture(label:String):
  await get_tree().process_frame
  RenderingServer.force_draw();shot+=1
  var file="case%d-shot%03d-%s.png"%[current,shot,label]
  h.get_viewport().get_texture().get_image().save_png(out+"/"+file)
  var meta={"case":current,"area":h.area,"position":[h.player.position.x,h.player.position.y],"walking":h.player.walking,"hour":h.hour,"month":h.month,"weather":h.weather,"window":[get_window().size.x,get_window().size.y],"world_scale":[h.world.scale.x,h.world.scale.y],"frame":Engine.get_process_frames(),"wall":Time.get_unix_time_from_system(),"file":file}
  FileAccess.open(out+"/"+file.replace(".png",".json"),FileAccess.WRITE).store_string(JSON.stringify(meta,"  "))
  rows.append(meta);flush()
 func _process(dt):
  elapsed+=dt
  if elapsed<.2 or changing:return
  elapsed=0;n+=1
  rows.append({"type":"frame sample","case":current,"area":h.area,"position":[h.player.position.x,h.player.position.y],"walking":h.player.walking,"wall":Time.get_unix_time_from_system(),"frame":Engine.get_process_frames()})
  if n%2==0:capture.call_deferred("sample")
  flush()
