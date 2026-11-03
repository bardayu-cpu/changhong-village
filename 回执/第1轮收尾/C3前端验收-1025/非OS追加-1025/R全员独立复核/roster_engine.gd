extends SceneTree
const Home=preload("res://ayu_home/v4/home.gd")
const Actor=preload("res://ayu_home/v4/actor.gd")
var h
var probe
var out:=""
var rows:Array=[]
var shots:Array=[]
var role:=""
func _initialize():
 for a in OS.get_cmdline_user_args():
  if a.begins_with("--qa-out="):out=a.trim_prefix("--qa-out=")
 root.set_meta("player_profile",{"id":"c3-R-roster-engine","openid":"c3-R-roster-engine","avatar":2,"nick":"C3 R isolated"})
 call_deferred("run")
func check(ok:bool,label:String,details:Dictionary={}):
 rows.append({"id":role,"pass":ok,"check":label,"details":details});print("CHECK ",role," ",ok," ",label)
func frame_image():
 await process_frame
 await RenderingServer.frame_post_draw
 return root.get_texture().get_image()
func snap(name:String,extra:Dictionary={}):
 for i in 3:await process_frame
 var img=await frame_image();img.save_png(out+"/"+name+".png")
 var meta={"name":name,"role":role,"area":h.area,"hour":h.hour,"month":h.month,"weather":h.weather,"actor_position":[probe.position.x,probe.position.y],"face":probe.face,"action":probe.action,"lift":probe.lift,"sprite_position":[probe.sprite.position.x,probe.sprite.position.y],"screen":[probe.get_global_transform_with_canvas().origin.x,probe.get_global_transform_with_canvas().origin.y],"extra":extra}
 FileAccess.open(out+"/"+name+".json",FileAccess.WRITE).store_string(JSON.stringify(meta,"  "));shots.append(meta)
func capture_pose():
 var img=await frame_image()
 var t:Transform2D=probe.sprite.get_global_transform_with_canvas()
 var rect:=Rect2(t.origin,Vector2(64,84)*t.get_scale()).abs()
 var r:=Rect2i(Vector2i(rect.position.round()),Vector2i(rect.size.round()))
 check(Rect2i(Vector2i.ZERO,img.get_size()).encloses(r),"pose viewport crop fully inside",{"rect":[r.position.x,r.position.y,r.size.x,r.size.y]})
 var crop=img.get_region(r);crop.resize(64,84,Image.INTERPOLATE_NEAREST)
 return crop
func poses():
 var contact:=Image.create(256,504,false,Image.FORMAT_RGBA8);contact.fill(Color("27292d"))
 probe.freeze=true;probe.bubble_allowed=false;probe.draw_hand_overlays=false
 var origin:Vector2=probe.position
 for d in 4:
  probe.face=["down","left","right","up"][d];probe.action="idle";probe.walking=false;probe.lift=0;probe.elapsed=0;probe.pose()
  check(int(probe.pose_texture.region.position.x/64)==d*4,"idle direction "+str(d))
  contact.blit_rect(await capture_pose(),Rect2i(0,0,64,84),Vector2i(d*64,0))
  probe.freeze=false;probe.walking=true
  var seen:Dictionary={};var heights:Dictionary={}
  for tick in 24:
   await process_frame
   seen[int(probe.pose_texture.region.position.x/64)]=true;heights[str(probe.sprite.position.y)]=true
  check(seen.size()==4,"natural animation four walk frames direction "+str(d),{"seen":seen.keys()})
  check(heights.size()==1,"walk vertical anchor constant direction "+str(d),{"y":heights.keys()})
  probe.freeze=true
  for phase in 4:
   probe.elapsed=float(phase)/8.0+.001;probe.pose()
   check(int(probe.pose_texture.region.position.x/64)==d*4+phase,"walk mapping "+str(d)+"/"+str(phase))
   contact.blit_rect(await capture_pose(),Rect2i(0,0,64,84),Vector2i(phase*64,(d+1)*84))
 probe.walking=false;probe.action="sit"
 for d in 4:
  probe.face=["down","left","right","up"][d];probe.pose()
  check(int(probe.pose_texture.region.position.x/64)==16+d,"sit mapping direction "+str(d))
  contact.blit_rect(await capture_pose(),Rect2i(0,0,64,84),Vector2i(d*64,420))
 contact.save_png(out+"/"+role+"-engine-24poses-contact.png")
 check(probe.position.distance_to(origin)<.01,"preview fixture anchored; no movement injection")
func ayu_seat(name:String):
 var orig=probe;orig.visible=false
 var ayu=Actor.new();h.world.actors.add_child(ayu);ayu.setup("ayu");ayu.freeze=true;ayu.action="sit";ayu.face=orig.face;ayu.position=orig.position;ayu.lift=orig.lift;ayu.bubble_allowed=false;ayu.pose()
 probe=ayu;await snap(name,{"reference_fixture":"same scene, position, seat lift and direction as original actor; actual Ayu assets"});probe=orig;ayu.queue_free();orig.visible=true
func portrait(native_room):
 var ok:bool=native_room.talk("resident:"+role)
 await process_frame
 check(ok and h.talk_face==role and is_instance_valid(h.talk_ui) and h.talk_ui.portrait.visible,"actual resident talk opens own portrait")
 if is_instance_valid(h.talk_ui):
  check(h.talk_ui.portrait.texture.get_width()==112 and h.talk_ui.portrait.texture.get_height()==129,"actual portrait dimensions")
  await snap(role+"-actual-dialogue")
 h.close_modal()
func run():
 root.size=Vector2i(540,960);Engine.max_fps=30;h=Home.new();root.add_child(h)
 var until=Time.get_ticks_msec()+30000
 while not h.bootstrapped and Time.get_ticks_msec()<until:await process_frame
 if not h.bootstrapped:quit(1);return
 root.title="C3 non-OS R roster actual engine"
 var data=JSON.parse_string(FileAccess.get_file_as_string(out+"/../角色房间绑定.json"))
 for rec in data.npcs:
  role=str(rec.id)
  if role=="market":continue
  h.village_ui.close();h.set_test_clock(13,10,"clear");await h.enter_room(str(data.rooms[role]),false)
  var room=h.village_ui.institution_room
  check(is_instance_valid(room) and str(room.record.id)==role,"actual room creates expected resident")
  if not is_instance_valid(room):continue
  room.greet_after=1e9;room.set_process(false);probe=room.actor;h.player.visible=false
  check(probe.sheet.get_size()==Vector2(1280,84),"production Residents lookup resolves full strip")
  # Kai full engine suite already passed. Only missing portrait is added here.
  if role=="kaikai":
   await portrait(room);continue
  probe.position=h.world.nearest(Vector2(h.world.cfg.spawn[0],h.world.cfg.spawn[1]));probe.route.clear()
  h.player.position=probe.position;h.camera=h.room_camera_target();h.layout()
  await poses()
  # Production schedule transition from noon to actual evening seat (not forcing actor.action).
  probe.freeze=false;probe.walking=false;probe.action="idle";probe.lift=0
  room.set_process(true);room.greet_after=1e9;h.set_test_clock(19,10,"clear");await process_frame
  var tick:=0
  while (room.slot_index!=2 or not room.settled) and tick<600:await process_frame;tick+=1
  check(room.slot_index==2 and room.settled,"actual evening schedule route settles",{"ticks":tick})
  room.set_process(false);probe.freeze=true;probe.pose()
  var slot:Dictionary=room.record.schedule[2]
  var seat:=Vector2(slot.pos[0],slot.pos[1])
  var lift:float=h.seat_lift(seat) if str(slot.action) in ["sit","read","drink"] else 0.0
  check(probe.action==str(slot.action) and probe.face==str(slot.face),"actual evening action and direction",slot)
  check(probe.position.distance_to(seat+Vector2(0,lift))<.1 and absf(probe.lift-lift)<.1,"actual seat anchor and production lift",{"lift":lift})
  h.player.position=seat;h.camera=h.room_camera_target();h.layout()
  await snap(role+"-actual-evening-seat");await ayu_seat(role+"-Ayu-evening-same-seat")
  h.set_test_clock(13,10,"clear");await portrait(room)
 # Market uses actual street actor and world_life's four-leg sit cycle.
 role="market";h.village_ui.close();h.set_test_clock(13,10,"clear")
 h.village_ui.state.now_override=Time.get_unix_time_from_datetime_string("2026-10-25T13:00:00")-int(Time.get_time_zone_from_system().bias)*60
 await h.enter_room("village",false)
 var row:Dictionary={}
 for v in h.village_ui.street_actors:
  if v.id=="market":row=v;break
 check(not row.is_empty(),"market day production spawns merchant")
 if not row.is_empty():
  probe=row.actor;var overlay=h.village_ui.overlay;overlay.set_process(false);h.player.visible=false;h.player.position=probe.position;h.camera=h.room_camera_target();h.layout()
  await poses()
  probe.freeze=false;probe.walking=false;probe.action="idle"
  for leg in 4:
   overlay.street_time=float(row.next)+.01;overlay._process(1.0/30)
   var ticks:=0
   while not probe.route.is_empty() and ticks<300:overlay._process(1.0/30);await process_frame;ticks+=1
   check(probe.route.is_empty(),"actual market street leg "+str(leg),{"ticks":ticks})
  probe.freeze=true;probe.pose()
  check(probe.action=="sit","actual merchant street cycle produces sitting")
  h.player.position=probe.position;h.camera=h.room_camera_target();h.layout()
  await snap("market-actual-street-sit");await ayu_seat("market-Ayu-same-ground")
  check(false,"market portrait has no production dialogue entry found; shop page only",{"material_exists":true,"source":"interface.handle market opens shop; no resident talk binding"})
 var fails=rows.filter(func(x):return not x.pass)
 FileAccess.open(out+"/result.json",FileAccess.WRITE).store_string(JSON.stringify({"mode":"non-OS actual Home/Residents/Actor rendering; preview pose fixture; normal evening schedule paths; street time accelerated for actual market four-leg cycle","OS_input":false,"Kai_full_rerun":false,"rows":rows,"failed":fails,"shots":shots,"R_overall_pass":false},"  "))
 h.queue_free();await process_frame;quit(0)
