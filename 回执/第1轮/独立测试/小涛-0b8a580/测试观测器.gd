extends SceneTree
var h
var evidence:=""
var request_path:=""
var seq:=0
var logfile:FileAccess
var last_state:=""
var last_area:=""
var image_count:=0
func _initialize() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--c3-evidence="):evidence=arg.trim_prefix("--c3-evidence=")
 request_path=evidence.path_join("capture-request.json")
 logfile=FileAccess.open(evidence.path_join("正常输入与状态轨迹.jsonl"),FileAccess.WRITE)
 root.window_input.connect(record_input)
 root.close_requested.connect(func():
  if h!=null and is_instance_valid(h.village_ui):h.village_ui.checkpoint()
  logfile.flush();quit())
 call_deferred("run")
func record_input(event:InputEvent) -> void:
 if event is InputEventMouseButton or event is InputEventKey:
  var d={"at":Time.get_unix_time_from_system(),"type":"native_input","event":event.as_text(),"pressed":event.pressed}
  if event is InputEventMouseButton:d["position"]=[event.position.x,event.position.y]
  logfile.store_line(JSON.stringify(d));logfile.flush()
func run() -> void:
 root.add_child(load("res://ayu_home/v4/phone_boot.tscn").instantiate())
 for i in 600:
  await process_frame
  for child in root.get_children():
   if child.get_script()!=null and child.get_script().resource_path=="res://ayu_home/v4/home.gd":h=child
  if h!=null and h.bootstrapped:break
 if h==null:print("C3_NO_HOME");quit(1);return
 print("C3_READY ",OS.get_user_data_dir())
 while true:
  await create_timer(.5).timeout
  var obs:=observe()
  var sig:String=JSON.stringify([obs.area,obs.position,obs.action,obs.hour,obs.items,obs.effects,obs.active,obs.game,obs.page])
  if sig!=last_state:
   last_state=sig;logfile.store_line(JSON.stringify(obs));logfile.flush()
  if h.area!=last_area:
   last_area=h.area;await capture("H6-入区-"+str(h.area))
  if not FileAccess.file_exists(request_path):continue
  var request=JSON.parse_string(FileAccess.get_file_as_string(request_path))
  if not request is Dictionary or int(request.get("seq",0))<=seq:continue
  seq=int(request.seq)
  if request.get("command","")=="clock":
   var old_hour:float=h.hour;h.set_test_clock(float(request.hour),10,"clear")
   logfile.store_line(JSON.stringify({"at":Time.get_unix_time_from_system(),"type":"authorized_visual_clock","from":old_hour,"to":request.hour,"area":h.area,"player":[h.player.position.x,h.player.position.y],"method":"原home.set_test_clock；无玩家位置/库存/共用生产时间注入"}));logfile.flush()
  await capture(str(request.get("name","capture")))
func observe() -> Dictionary:
 var v:Dictionary=h.village_ui.state.data.village
 var game:Dictionary={}
 if is_instance_valid(h.village_ui.institution_game):
  var g=h.village_ui.institution_game;game={"run":g.run_id,"progress":g.progress,"finished":g.finished,"message":g.message.text}
 var resident:Dictionary={}
 if is_instance_valid(h.village_ui.institution_room):
  var room=h.village_ui.institution_room;var a=room.actor
  resident={"position":[a.position.x,a.position.y],"action":a.action,"face":a.face,"walking":a.walking,"bubble":a.bubble.text,"bubble_visible":a.bubble.visible,"slot":room.slot_index,"lift":a.lift}
 return {"at":Time.get_unix_time_from_system(),"type":"state","area":h.area,"position":[snappedf(h.player.position.x,.1),snappedf(h.player.position.y,.1)],"action":h.player.action,"lift":h.player.lift,"hour":h.hour,"fps":Engine.get_frames_per_second(),"items":v.items,"coins":h.village_ui.state.data.wallet.coins,"effects":v.institutions,"active":v.active_institution,"game":game,"resident":resident,"page":h.village_ui.page if h.village_ui.opened else "world"}
func capture(label:String) -> void:
 image_count+=1
 var prefix:="小涛-0b8a580-%03d-"%image_count+label
 await process_frame;RenderingServer.force_draw()
 root.get_texture().get_image().save_png(evidence.path_join(prefix+".png"))
 var controls:Array=[];read_controls(root,controls)
 var xf:Transform2D=h.world.get_global_transform_with_canvas();var targets:Array=[]
 for hot in h.world.cfg.hotspots+h.world.cfg.doors:
  var q:Vector2=xf*Vector2(hot.approach[0],hot.approach[1])
  targets.append({"id":hot.id,"label":hot.label,"approach_screen":[q.x,q.y]})
 var obs:=observe();var f:=FileAccess.open(evidence.path_join(prefix+".json"),FileAccess.WRITE)
 f.store_string(JSON.stringify({"observation":obs,"controls":controls,"targets":targets,"seq":seq,"player_raw":[h.player.position.x,h.player.position.y],"world_scale":[h.world.scale.x,h.world.scale.y],"core":h.village_ui.state.data}));f.close()
 var latest:=FileAccess.open(evidence.path_join("最新观测.json"),FileAccess.WRITE);latest.store_string(JSON.stringify({"file":prefix,"observation":obs,"controls":controls,"targets":targets}));latest.close()
func read_controls(node:Node,out:Array) -> void:
 if node is Control and node.is_visible_in_tree() and (node is Button or node is Label):
  out.append({"type":node.get_class(),"text":node.text,"rect":[node.global_position.x,node.global_position.y,node.size.x,node.size.y]})
 for child in node.get_children():read_controls(child,out)
