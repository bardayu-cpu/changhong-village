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
 room_id="v_daba";await h.enter_room("v_daba",false)
 var before:Vector2=h.player.position
 h.world.cfg.entry_camera_bias=JSON.parse_string(FileAccess.get_file_as_string(out+"/../daba_camera_value.json"))
 for i in 6:await process_frame
 check(h.player.position==before and h.view_scale==2,"normal spawn and scale unchanged")
 await snap("v_daba-entry-camera2-13")
 FileAccess.open(out+"/result.json",FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"shots":shots,"OS_input":false,"mode":"nine candidate actual entry/help at13 and normal room-init evening seating at19; no whole-day path or real desktop input; narrow solid center/approach/source-mapping checks only, not full furniture collision/swept QA","whole_nine_pass":false,"fourteen_real_object_states":"missing, not passed"},"  "))
 h.queue_free();await process_frame;quit(0)
