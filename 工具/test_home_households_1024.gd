extends SceneTree
const Home=preload("res://ayu_home/v4/home.gd")
var h
var folder:=""
var ayu_path:=""
var core_path:=""
var rows:Array=[]
var failed:=false
var households:Array[String]=[]
var capture_entry:=false
var capture_only:=false
const TABLE_POINTS={"daba":Vector2(396,285),"flower":Vector2(570,277),"h2":Vector2(534,148),"h8":Vector2(390,280),"erba":Vector2(610,245),"h6":Vector2(580,326),"h7":Vector2(380,144),"h4":Vector2(350,186),"h1":Vector2(580,278),"whitebrick":Vector2(620,280),"grape":Vector2(610,285),"sunflower":Vector2(375,254),"persimmon":Vector2(484,245),"rose":Vector2(596,295)}
func _initialize():
 var ayu_count:=0;var core_count:=0
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--ayu-save="):
   ayu_count+=1;ayu_path=arg.trim_prefix("--ayu-save=")
  elif arg.begins_with("--core-save="):
   core_count+=1;core_path=arg.trim_prefix("--core-save=")
  elif arg=="--capture-entry":capture_entry=true
  elif arg=="--capture-only":capture_entry=true;capture_only=true
  elif arg.begins_with("--houses="):
   for id in arg.trim_prefix("--houses=").split(","):households.append(id)
  elif arg.begins_with("--ayu-"):push_error("Unexpected Home override");quit(1);return
 if households.is_empty():push_error("Explicit --houses list required");quit(1);return
 if ayu_count!=1 or core_count!=1:
  push_error("Exactly one of each save argument required");quit(1);return
 for path in [ayu_path,core_path]:
  if not path.is_absolute_path() or path.simplify_path()!=path:
   push_error("Save paths must be absolute and canonical without dot segments");quit(1);return
 var base=ProjectSettings.globalize_path("res://../测试数据/Home新户-1024/").simplify_path()+"/"
 folder=ayu_path.get_base_dir()
 if not folder.begins_with(base) or core_path.get_base_dir()!=folder or ayu_path.get_file()!="life.json" or core_path.get_file()!="core":
  push_error("Both explicit isolated paths required");quit(1);return
 if not DirAccess.dir_exists_absolute(folder):push_error("Unique directory must already exist");quit(1);return
 for path in [ayu_path,ayu_path+".bak",core_path,core_path+".a",core_path+".b"]:
  if FileAccess.file_exists(path):push_error("Refuse reused test save");quit(1);return
 root.set_meta("player_profile",{"id":"household-tour-"+str(Time.get_ticks_usec()),"openid":"household-tour-"+str(Time.get_ticks_usec()),"avatar":2,"nick":"隔离衔接检查"})
 call_deferred("run")
func record(ok:bool,label:String):
 rows.append({"check":label,"pass":ok,"area":h.area if is_instance_valid(h) else "","position":[h.player.position.x,h.player.position.y] if is_instance_valid(h) and is_instance_valid(h.player) else []})
 failed=failed or not ok;print(("PASS " if ok else "FAIL ")+label)
func wait_until(condition:Callable,seconds:float) -> bool:
 var deadline=Time.get_ticks_msec()+int(seconds*1000)
 while Time.get_ticks_msec()<deadline:
  await process_frame
  if condition.call():return true
 return false
func walk_to(id:String,target:String) -> bool:
 var distance=h.player.movement_distance
 h.go(id)
 if capture_entry and id=="to_living":
  if await wait_until(func():return h.modal!=null or h.area=="living",45):
   if h.modal!=null:h.finish_dialogue()
 var ok=await wait_until(func():return h.area==target and not h.transition and h.pending.is_empty(),90)
 record(ok,"normal go "+id+" reaches "+target)
 return ok
func finish():
 if is_instance_valid(h):h.queue_free();await process_frame
 var f=FileAccess.open(folder+"/result.json",FileAccess.WRITE)
 if f==null:quit(1);return
 f.store_string(JSON.stringify({"rows":rows,"failed":failed,"mode":"full Home normal go; automated graphical entry capture" if capture_entry else "full Home headless; normal go, no GUI"},"  "));f.close()
 print("HOME_HOUSEHOLD_TOUR ","FAIL" if failed else "PASS"," ",rows.size());quit(1 if failed else 0)
func capture_room(id:String):
 if not capture_entry:return
 DirAccess.make_dir_recursive_absolute(folder+"/frames")
 for size in ([Vector2i(540,960),Vector2i(1280,720)] if id in ["flower","erba","h4","living"] else [Vector2i(540,960)]):
  root.size=size
  for i in 4:await process_frame
  await RenderingServer.frame_post_draw
  var path=folder+"/frames/"+id+"_"+str(size.x)+"x"+str(size.y)+".png"
  print("ENTRY_FRAME ",path," error=",root.get_texture().get_image().save_png(path))
 root.size=Vector2i(540,960)
 for i in 4:await process_frame
func run():
 if capture_entry:root.size=Vector2i(540,960)
 h=Home.new();root.add_child(h)
 if not await wait_until(func():return h.bootstrapped,30):record(false,"Home boot");await finish();return
 var paths_ok=h.life.path==ayu_path and h.village_ui.state.path==core_path
 record(paths_ok,"both runtime save paths equal explicit isolated paths")
 if not paths_ok:await finish();return
 record(h.area=="exterior","normal fresh Home starts at Ayu courtyard")
 if failed:await finish();return
 if capture_entry:
  if not await walk_to("to_living","living"):await finish();return
  await capture_room("living")
  if not await walk_to("to_exterior","exterior"):await finish();return
 var state=h.village_ui.state
 var items=state.data.village.items.duplicate(true);var coins=state.data.wallet.coins;var relations=state.data.renqing.size()
 if not await walk_to("to_side_path","village"):await finish();return
 for id in households:
  if not await walk_to("visit_"+id,"v_"+id):await finish();return
  await capture_room(id)
  if capture_only:
   if not await walk_to("outside","village"):await finish();return
   continue
  record(bool(h.world.cfg.get("household_open",false)),id+" has approved room configuration open")
  if TABLE_POINTS.has(id):record(not h.world.passable(TABLE_POINTS[id]),id+" main table blocks navigation")
  var before_help=int(state.data.village.helped.get("house:"+id,0));var before_relations=state.data.renqing.size()
  h.go("house_help")
  record(await wait_until(func():return h.pending.is_empty() and int(state.data.village.helped.get("house:"+id,0))==before_help+1,45),id+" actual walking completes indoor household help")
  record(state.data.renqing.size()==before_relations+1 and not "今日不便拜访" in h.note,id+" indoor help adds one relationship with indoor wording")
  h.go("house_help");await process_frame
  record(int(state.data.village.helped.get("house:"+id,0))==before_help+1 and state.data.renqing.size()==before_relations+1,id+" repeat help retains original daily cap")
  h.go("tea_seat")
  record(await wait_until(func():return h.player.action=="sit" and h.pending.is_empty(),45),id+" actual walking reaches seat")
  if failed:await finish();return
  if not await walk_to("outside","village"):await finish();return
  record(h.player.action=="idle",id+" exit stands up and returns to village")
  record(state.data.village.items==items and state.data.wallet.coins==coins,id+" interactions preserve inventory and coins")
 h.village_ui.checkpoint()
 record(state.data.village.last_area=="village" and state.data.village.last_position==[h.player.position.x,h.player.position.y],"batch checkpoint records actual final village position")
 record(state.data.renqing.size()==relations+(0 if capture_only else households.size()),"entry capture preserves relationships" if capture_only else "batch awards exactly one relationship per household")
 await finish()
