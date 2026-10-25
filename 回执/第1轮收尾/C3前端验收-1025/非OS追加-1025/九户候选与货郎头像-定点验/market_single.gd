extends SceneTree
const Home=preload("res://ayu_home/v4/home.gd")
const Actor=preload("res://ayu_home/v4/actor.gd")
var h
var out:=""
var room_id:=""
var rows:Array=[]
var shots:Array=[]
func _initialize():
 for a in OS.get_cmdline_user_args():
  if a.begins_with("--qa-out="):out=a.trim_prefix("--qa-out=")
 root.set_meta("player_profile",{"id":"c3-nine-rooms","openid":"c3-nine-rooms","avatar":2,"nick":"C3 nine"});call_deferred("run")
func check(ok:bool,label:String,data:Dictionary={}):
 rows.append({"room":room_id,"pass":ok,"check":label,"details":data});print("CHECK ",room_id," ",ok," ",label)
func snap(name:String):
 for i in 4:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out+"/"+name+".png")
 var actor=h.village_ui.institution_room.actor if is_instance_valid(h.village_ui.institution_room) else null
 var extra:Dictionary={}
 if actor!=null:extra={"position":[actor.position.x,actor.position.y],"face":actor.face,"action":actor.action,"lift":actor.lift,"screen":[actor.get_global_transform_with_canvas().origin.x,actor.get_global_transform_with_canvas().origin.y]}
 var m={"name":name,"room":h.area,"hour":h.hour,"month":h.month,"weather":h.weather,"view_scale":h.view_scale,"player_position":[h.player.position.x,h.player.position.y],"background":h.world.cfg.background,"actor":extra}
 FileAccess.open(out+"/"+name+".json",FileAccess.WRITE).store_string(JSON.stringify(m,"  "));shots.append(m)
func run():
 root.size=Vector2i(540,960);Engine.max_fps=30;h=Home.new();root.add_child(h)
 var until=Time.get_ticks_msec()+30000
 while not h.bootstrapped and Time.get_ticks_msec()<until:await process_frame
 if not h.bootstrapped:quit(1);return
 root.title="C3 non-OS nine room targeted checks"
 h.set_test_clock(13,10,"clear");await h.enter_room("living",false);await snap("Ayu-entry-13")
 var geo=JSON.parse_string(FileAccess.get_file_as_string(out+"/../c4geometry.json"))
 for item in []:
  room_id=str(item.id);h.set_test_clock(13,10,"clear");await h.enter_room(room_id,false)
  check(h.area==room_id and h.world.cfg.background.contains("households-closeout-1025"),"actual candidate room/background loaded")
  check(h.view_scale==2 and h.world.cfg.background_scale==[.5,.5],"same normal scale and background source scale")
  check(h.world.passable(h.player.position),"actual entry spawn passable")
  await snap(room_id+"-entry-13")
  # Actual obstruction check, independently use C4 solid rectangles, excluding documented C2 split for erba.
  var blocked:=0
  for b in h.world.cfg.obstacles:
   var center:=Vector2(b[0]+b[2]*.5,b[1]+b[3]*.5)
   if not h.world.passable(center):blocked+=1
  check(blocked==h.world.cfg.obstacles.size(),"new solid furniture centers blocked",{"blocked":blocked,"count":h.world.cfg.obstacles.size()})
  var actual:Array=h.world.cfg.obstacles
  if room_id!="v_erba":
   check(item.obstacles.all(func(x):return x.rect in actual) and actual.size()==item.obstacles.size(),"all old obstacle list replaced by exact C4 new solids")
  var c4regions:Array=item.foreground_regions
  check(h.world.cfg.props.size()==c4regions.size(),"new foreground count matches C4")
  for expected in c4regions:
   var found:bool=h.world.cfg.props.any(func(x):return x.atlas_region==expected.atlas_region_fullres and x.foot==expected.foot)
   check(found,"new foreground source region and foot "+str(expected.id))
  # Narrow candidate only: approach endpoints and interpolated road to 3 hotspots + door.
  for hot in h.world.cfg.hotspots+h.world.cfg.doors:
   var target:=Vector2(hot.approach[0],hot.approach[1]);var path:PackedVector2Array=h.world.path(h.player.position,target)
   check(path.size()>0 and path[path.size()-1].distance_to(target)<6,"candidate approach reachable "+str(hot.id))
  if room_id=="v_daba":
   var free:Array=[]
   for pt in [Vector2(330,300),Vector2(390,300),Vector2(450,300),Vector2(390,340)]:free.append(h.world.passable(pt))
   check(free.all(func(x):return x),"central rug no old table ghost collision",{"samples":free})
  var help:Dictionary=h.world.spot("house_help");h.player.position=h.world.nearest(Vector2(help.approach[0],help.approach[1]));h.camera=h.room_camera_target();h.layout()
  await snap(room_id+"-help-13")
  # Normal room initial schedule at evening, not a forced actor sit or full-day transition.
  h.set_test_clock(19,10,"clear");await h.enter_room(room_id,false)
  var native=h.village_ui.institution_room;native.set_process(false);native.greet_after=1e9
  var actor=native.actor;actor.freeze=true;actor.bubble_allowed=false
  h.player.visible=false;h.player.position=actor.position-Vector2(0,actor.lift);h.camera=h.room_camera_target();h.layout()
  check(actor.action in ["sit","read","drink"],"actual evening native schedule is seated")
  await snap(room_id+"-actual-seat-19")
  actor.visible=false
  var ayu=Actor.new();h.world.actors.add_child(ayu);ayu.setup("ayu");ayu.position=actor.position;ayu.lift=actor.lift;ayu.action="sit";ayu.face=actor.face;ayu.freeze=true;ayu.bubble_allowed=false;ayu.pose()
  await snap(room_id+"-Ayu-same-seat-19");ayu.queue_free();actor.visible=true
 room_id="market";h.set_test_clock(13,10,"clear");await h.enter_room("village",false)
 h.village_ui.state.now_override=Time.get_unix_time_from_datetime_string("2027-10-25T13:00:00")-int(Time.get_time_zone_from_system().bias)*60
 h.village_ui.interact(h.world.spot("market"))
 for i in 4:await process_frame
 var portrait=h.village_ui.content.find_child("MarketPortrait",true,false)
 check(portrait!=null and portrait.is_visible_in_tree(),"ordinary market page entry shows merchant portrait")
 if portrait!=null:check(portrait.texture.get_size()==Vector2(112,129),"actual merchant portrait uses supplied dimensions")
 await snap("market-normal-shop-portrait-13")
 FileAccess.open(out+"/result.json",FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"shots":shots,"OS_input":false,"mode":"nine candidate actual entry/help at13 and normal room-init evening seating at19; no whole-day path or real desktop input; narrow solid center/approach/source-mapping checks only, not full furniture collision/swept QA","whole_nine_pass":false,"fourteen_real_object_states":"missing, not passed"},"  "))
 h.queue_free();await process_frame;quit(0)
