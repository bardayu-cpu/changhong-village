extends SceneTree
var h
var evidence:=""
var capture_file:=""
var last_sequence:=0
var trace_file:FileAccess
var frames:=0
var best_bounds:Dictionary={}
var width_label:="540x960"
var started:=0.0
func _initialize() -> void:
 evidence=ProjectSettings.globalize_path("res://../../../..//回执/第1轮/独立测试")
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--c3-evidence="):evidence=arg.trim_prefix("--c3-evidence=")
  if arg.begins_with("--c3-size="):width_label=arg.trim_prefix("--c3-size=")
 capture_file=evidence.path_join("capture-request.json")
 trace_file=FileAccess.open(evidence.path_join("输入轨迹-540x960.jsonl"),FileAccess.WRITE)
 started=Time.get_unix_time_from_system()
 root.window_input.connect(record_input)
 root.close_requested.connect(func():
  if h!=null and is_instance_valid(h.village_ui):h.village_ui.checkpoint()
  trace_file.flush()
  quit())
 call_deferred("run")
func record_input(event:InputEvent) -> void:
 if event is InputEventMouseButton or event is InputEventKey:
  trace_file.store_line(JSON.stringify({"at":Time.get_unix_time_from_system(),"type":"input","event":event.as_text()}));trace_file.flush()
func run() -> void:
 var boot=load("res://ayu_home/v4/phone_boot.tscn").instantiate();root.add_child(boot)
 for i in 600:
  await process_frame
  for child in root.get_children():
   if child.get_script()!=null and child.get_script().resource_path=="res://ayu_home/v4/home.gd":h=child
  if h!=null and h.bootstrapped:break
 if h==null:print("C3_NO_HOME");quit(1);return
 print("C3_OBSERVER_READY ",OS.get_user_data_dir())
 while true:
  await create_timer(1).timeout
  var obs={"at":Time.get_unix_time_from_system(),"elapsed":Time.get_unix_time_from_system()-started,"type":"observation","area":h.area,"position":[h.player.position.x,h.player.position.y],"note":h.note,"route_size":h.player.route.size(),"fps":Engine.get_frames_per_second(),"memory":OS.get_static_memory_usage(),"wallet":h.village_ui.state.data.wallet,"items":h.village_ui.state.data.village.items,"page":h.village_ui.page if h.village_ui.opened else "world"}
  trace_file.store_line(JSON.stringify(obs));trace_file.flush()
  await sample_bounds()
  if not FileAccess.file_exists(capture_file):continue
  var request=JSON.parse_string(FileAccess.get_file_as_string(capture_file))
  if not request is Dictionary or int(request.get("seq",0))<=last_sequence:continue
  last_sequence=int(request.seq)
  await process_frame
  RenderingServer.force_draw()
  var image=root.get_texture().get_image()
  image.save_png(str(request.path))
  var controls:Array=[];read_controls(root,controls)
  var f:=FileAccess.open(evidence.path_join("窗口观测-540x960.json"),FileAccess.WRITE)
  f.store_string(JSON.stringify({"seq":last_sequence,"observation":obs,"controls":controls,"size":[root.size.x,root.size.y]}));f.close()
func read_controls(node:Node,out:Array) -> void:
 if node is Control and node.is_visible_in_tree() and (node is Button or node is Label):
  out.append({"type":node.get_class(),"text":node.text,"rect":[node.global_position.x,node.global_position.y,node.size.x,node.size.y]})
 for child in node.get_children():read_controls(child,out)

func rect_data(c:Control) -> Array:
 var r:=c.get_global_rect();return [r.position.x,r.position.y,r.size.x,r.size.y]
func sample_bounds() -> void:
 var tag_visible:bool=h.near_tag.is_visible_in_tree()
 var sit_visible:bool=h.scene_controls!=null and is_instance_valid(h.scene_controls) and h.scene_controls.is_visible_in_tree()
 var key:=""
 var bottom:=-1.0
 if tag_visible:
  key="文字牌-"+str(h.near_tag.text);bottom=h.near_tag.get_node("TagHit").get_global_rect().end.y
 elif sit_visible and h.player.action=="sit":
  key="起身";bottom=h.scene_controls.get_global_rect().end.y
 if key.is_empty() or bottom<=float(best_bounds.get(key,-1)):return
 best_bounds[key]=bottom
 var row={"at":Time.get_unix_time_from_system(),"viewport":width_label,"area":h.area,"key":key,"action":h.player.action,"player":[h.player.position.x,h.player.position.y],"interaction_bottom":h.interaction_bottom(),"buttons":[rect_data(h.village_ui.hud_button),rect_data(h.village_ui.crop_button),rect_data(h.village_ui.order_button)],"tag":rect_data(h.near_tag),"tag_hit":rect_data(h.near_tag.get_node("TagHit")),"tag_visible":tag_visible,"scene_visible":sit_visible}
 if sit_visible:row["scene_controls"]=rect_data(h.scene_controls)
 var f:=FileAccess.open(evidence.path_join("最近底沿-"+width_label+"-"+key+".json"),FileAccess.WRITE);f.store_string(JSON.stringify(row));f.close()
 await process_frame;RenderingServer.force_draw()
 root.get_texture().get_image().save_png(evidence.path_join("最近底沿-"+width_label+"-"+key+".png"))
