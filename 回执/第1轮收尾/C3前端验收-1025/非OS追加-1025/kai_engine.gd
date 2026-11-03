extends SceneTree
const Home=preload("res://ayu_home/v4/home.gd")
const Actor=preload("res://ayu_home/v4/actor.gd")
const Residents=preload("res://ayu_home/v4/core/residents.gd")
var h
var probe
var out:=""
var rows:Array=[]
var shots:Array=[]
func _initialize():
 for a in OS.get_cmdline_user_args():
  if a.begins_with("--qa-out="):out=a.trim_prefix("--qa-out=")
 root.set_meta("player_profile",{"id":"c3-kai-engine-1025","openid":"c3-kai-engine-1025","avatar":2,"nick":"C3\u51ef\u51ef\u9694\u79bb"});call_deferred("run")
func check(ok:bool,label:String,info:Dictionary={}):
 rows.append({"pass":ok,"check":label,"details":info});print("CHECK ",ok," ",label)
func snap(name:String):
 for i in 4:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out+"/"+name+".png")
 var extra:Dictionary={}
 if is_instance_valid(probe):
  var tex=probe.sprite.texture
  extra={"position":[probe.position.x,probe.position.y],"face":probe.face,"action":probe.action,"walking":probe.walking,"lift":probe.lift,"sprite_position":[probe.sprite.position.x,probe.sprite.position.y],"texture_region":[tex.region.position.x,tex.region.position.y,tex.region.size.x,tex.region.size.y] if tex is AtlasTexture else [],"actor_screen":[probe.get_global_transform_with_canvas().origin.x,probe.get_global_transform_with_canvas().origin.y]}
 var meta={"name":name,"area":h.area,"hour":h.hour,"month":h.month,"weather":h.weather,"window":[root.size.x,root.size.y],"world_scale":[h.world.scale.x,h.world.scale.y],"actor":extra}
 FileAccess.open(out+"/"+name+".json",FileAccess.WRITE).store_string(JSON.stringify(meta,"  "));shots.append(meta)
func ayu_reference(name:String,action:String,face:String):
 var original=probe;original.visible=false
 var ayu=Actor.new();h.world.actors.add_child(ayu);ayu.setup("ayu");ayu.freeze=true;ayu.action=action;ayu.face=face;ayu.position=original.position;ayu.lift=original.lift;ayu.draw_hand_overlays=false;ayu.bubble_allowed=false;ayu.elapsed=0;ayu.pose()
 probe=ayu;await snap(name);probe=original;ayu.queue_free();original.visible=true
func run():
 root.size=Vector2i(540,960);Engine.max_fps=30;h=Home.new();root.add_child(h)
 var deadline=Time.get_ticks_msec()+30000
 while not h.bootstrapped and Time.get_ticks_msec()<deadline:await process_frame
 if not h.bootstrapped:quit(1);return
 root.title="C3\u975eOS \u00b7 Kai\u5355\u89d2\u8272\u5f15\u64ce"
 h.set_test_clock(13,10,"clear");await h.enter_room("v_h5",false)
 var room=h.village_ui.institution_room;room.set_process(false);room.greet_after=1e9
 probe=room.actor;probe.freeze=true;probe.bubble_allowed=false;probe.draw_hand_overlays=false;h.player.visible=false
 h.player.position=h.world.nearest(Vector2(330,350));h.camera=h.room_camera_target();h.layout()
 check(probe.sheet.get_width()==1280 and probe.sheet.get_height()==84,"actual Residents.look loads Kai v3 sheet")
 var expected={"down":0,"left":4,"right":8,"up":12}
 for direction in ["down","left","right","up"]:
  probe.action="idle";probe.face=direction;probe.walking=false;probe.lift=0;probe.elapsed=0;probe.pose()
  check(int(probe.pose_texture.region.position.x/64)==int(expected[direction]),"idle frame "+direction)
  await snap("idle-"+direction);await ayu_reference("Ayu-idle-"+direction,"idle",direction)
  probe.freeze=false;probe.walking=true
  var seen:Dictionary={};var y_values:Dictionary={}
  for tick in 24:
   await process_frame
   seen[int(probe.pose_texture.region.position.x/64)]=true;y_values[str(probe.sprite.position.y)]=true
  check(seen.size()==4,"natural engine animation visits all 4 frames "+direction,{"frames":seen.keys()})
  check(y_values.size()==1,"no vertical sprite anchor change during walk "+direction,{"sprite_y":y_values.keys()})
  probe.freeze=true
  for phase in 4:
   probe.elapsed=float(phase)/8.0+.001;probe.pose()
   check(int(probe.pose_texture.region.position.x/64)==int(expected[direction])+phase,"selected engine walk frame "+direction+" "+str(phase))
   await snap("walk-"+direction+"-"+str(phase))
 probe.walking=false;probe.action="sit";probe.lift=0
 for direction in ["down","left","right","up"]:
  probe.face=direction;probe.pose()
  check(int(probe.pose_texture.region.position.x/64)==16+["down","left","right","up"].find(direction),"sit frame engine mapping "+direction)
  await snap("pose-only-sit-"+direction)
 # Actual institution schedule, normal engine route to the evening chair.
 probe.freeze=false;probe.walking=false;probe.action="idle";probe.face="left";probe.lift=0
 room.set_process(true);room.greet_after=1e9
 h.player.position=h.world.nearest(Vector2(310,515));h.camera=h.room_camera_target();h.layout();h.set_test_clock(19,10,"clear")
 await process_frame
 var waited:=0
 while (room.slot_index!=2 or not room.settled) and waited<600:await process_frame;waited+=1
 check(room.slot_index==2 and room.settled,"actual 19h institution schedule reaches chair",{"frames":waited})
 room.set_process(false);probe.freeze=true;probe.bubble_allowed=false
 var seat=Vector2(263,475);var expected_lift:float=h.seat_lift(seat)
 check(probe.action=="drink" and probe.face=="left","actual evening drink uses left sit frame")
 check(absf(probe.position.y-probe.lift-seat.y)<.1 and absf(probe.lift-expected_lift)<.1,"seat logical anchor and lift match production seat_lift",{"position":[probe.position.x,probe.position.y],"lift":probe.lift,"expected_lift":expected_lift})
 await snap("Kai-honey-19-actual-seat");await ayu_reference("Ayu-honey-19-same-seat","sit","left")
 # New texture in an actual y-sorted furniture edge; fixture scene, not Kai's story location.
 await h.enter_room("v_h3",false);h.player.visible=false
 if is_instance_valid(h.village_ui.institution_room):h.village_ui.institution_room.actor.visible=false;h.village_ui.institution_room.set_process(false)
 probe=Actor.new();probe.look_override=Residents.look("kaikai");probe.draw_hand_overlays=false;h.world.actors.add_child(probe);probe.setup("visitor");probe.bubble_allowed=false
 h.set_test_clock(13,10,"clear");h.player.position=h.world.nearest(Vector2(280,470));h.camera=h.room_camera_target();h.layout()
 probe.position=h.world.nearest(Vector2(282,448));probe.action="idle";probe.face="down";probe.lift=0
 await snap("Kai-mill-bucket-behind");await ayu_reference("Ayu-mill-bucket-behind","idle","down")
 probe.route=h.world.path(probe.position,Vector2(282,498));probe.destination_action="idle";probe.destination_face="down"
 var crossings:Array=[];var ticks:=0
 while not probe.route.is_empty() and ticks<180:
  probe.move_along(1.0/30.0,100);crossings.append([probe.position.x,probe.position.y]);await process_frame;ticks+=1
 check(probe.position.y>471 and crossings.any(func(v):return v[1]<471),"engine path crosses bucket foot line",{"start_y":crossings[0][1] if crossings.size()>0 else -1,"end_y":probe.position.y})
 await snap("Kai-mill-bucket-front");await ayu_reference("Ayu-mill-bucket-front","idle","down")
 FileAccess.open(out+"/result.json",FileAccess.WRITE).store_string(JSON.stringify({"mode":"non-OS actual Home/Residents/Actor engine rendering and schedule; explicit test fixture scene/pose control, not desktop input or full R release","rows":rows,"shots":shots,"engine_path":crossings,"scope":"Kai only; 4idle/16walk/4sit engine frames, evening honey chair, mill furniture edge fixture","OS_input":false},"  "))
 h.village_ui.checkpoint();h.queue_free();await process_frame;quit(0)
