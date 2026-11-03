extends SceneTree
var h
var evidence:=""
var capture_file:=""
var last_sequence:=0
var trace_file:FileAccess
var frames:=0
var started:=0.0
func _initialize() -> void:
 evidence=ProjectSettings.globalize_path("res://../../../..//回执/第1轮/独立测试")
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--c3-evidence="):evidence=arg.trim_prefix("--c3-evidence=")
 capture_file=evidence.path_join("capture-request.json")
 trace_file=FileAccess.open(evidence.path_join("基线-正常输入轨迹.jsonl"),FileAccess.WRITE)
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
  if not FileAccess.file_exists(capture_file):continue
  var request=JSON.parse_string(FileAccess.get_file_as_string(capture_file))
  if not request is Dictionary or int(request.get("seq",0))<=last_sequence:continue
  last_sequence=int(request.seq)
  await process_frame
  RenderingServer.force_draw()
  var image=root.get_texture().get_image()
  image.save_png(str(request.path))
  var controls:Array=[];read_controls(root,controls)
  var f:=FileAccess.open(evidence.path_join("基线-窗口观测.json"),FileAccess.WRITE)
  f.store_string(JSON.stringify({"seq":last_sequence,"observation":obs,"controls":controls,"size":[root.size.x,root.size.y]}));f.close()
func read_controls(node:Node,out:Array) -> void:
 if node is Control and node.is_visible_in_tree() and (node is Button or node is Label):
  out.append({"type":node.get_class(),"text":node.text,"rect":[node.global_position.x,node.global_position.y,node.size.x,node.size.y]})
 for child in node.get_children():read_controls(child,out)
