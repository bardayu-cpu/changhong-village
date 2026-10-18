extends SceneTree
const Home=preload("res://ayu_home/v4/home.gd")
var h
var folder:=""
var ayu_path:=""
var core_path:=""
var rows:Array=[]
var failed:=false
func _initialize():
 var ayu_count:=0;var core_count:=0
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--ayu-save="):
   ayu_count+=1;ayu_path=arg.trim_prefix("--ayu-save=")
  elif arg.begins_with("--core-save="):
   core_count+=1;core_path=arg.trim_prefix("--core-save=")
  elif arg.begins_with("--ayu-"):push_error("Unexpected Home override");quit(1);return
 if ayu_count!=1 or core_count!=1:
  push_error("Exactly one of each save argument required");quit(1);return
 for path in [ayu_path,core_path]:
  if not path.is_absolute_path() or path.simplify_path()!=path:
   push_error("Save paths must be absolute and canonical without dot segments");quit(1);return
 var base=ProjectSettings.globalize_path("res://../测试数据/Home闭环-1017/").simplify_path()+"/"
 folder=ayu_path.get_base_dir()
 if not folder.begins_with(base) or core_path.get_base_dir()!=folder or ayu_path.get_file()!="life.json" or core_path.get_file()!="core":
  push_error("Both explicit isolated paths required");quit(1);return
 if not DirAccess.dir_exists_absolute(folder):push_error("Unique directory must already exist");quit(1);return
 for path in [ayu_path,ayu_path+".bak",core_path,core_path+".a",core_path+".b"]:
  if FileAccess.file_exists(path):push_error("Refuse reused test save");quit(1);return
 root.set_meta("player_profile",{"id":"c2-home-loop-"+str(Time.get_ticks_usec()),"openid":"c2-home-loop-"+str(Time.get_ticks_usec()),"avatar":2,"nick":"隔离衔接检查"})
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
 var ok=await wait_until(func():return h.area==target and not h.transition and h.pending.is_empty(),90)
 record(ok,"normal go "+id+" reaches "+target)
 return ok
func finish():
 if is_instance_valid(h):h.queue_free();await process_frame
 var f=FileAccess.open(folder+"/result.json",FileAccess.WRITE)
 if f==null:quit(1);return
 f.store_string(JSON.stringify({"rows":rows,"failed":failed,"mode":"full Home headless; normal go, no GUI"},"  "));f.close()
 print("HOME_CIVIC_LOOP ","FAIL" if failed else "PASS"," ",rows.size());quit(1 if failed else 0)
func run():
 h=Home.new();root.add_child(h)
 if not await wait_until(func():return h.bootstrapped,30):record(false,"Home boot");await finish();return
 var paths_ok=h.life.path==ayu_path and h.village_ui.state.path==core_path
 record(paths_ok,"both runtime save paths equal explicit isolated paths")
 if not paths_ok:await finish();return
 record(h.area=="exterior","normal fresh Home starts at Ayu courtyard")
 if failed:await finish();return
 if not await walk_to("to_side_path","village"):await finish();return
 if not await walk_to("visit_mayor","v_mayor"):await finish();return
 var s=h.village_ui.state;var bamboo=s.count("bamboo");var start=h.player.position
 h.go("village_tasks")
 var opened=await wait_until(func():return is_instance_valid(h.village_ui.institution_game),45)
 record(opened and h.player.position.distance_to(start)>1,"normal go walks to civic table and opens game")
 if not opened:await finish();return
 var game=h.village_ui.institution_game;game.begin()
 for category in game.CIVIC_SEQUENCE:game.step(category)
 record(game.progress==3 and game.collect_button.visible,"three normal category steps enable collection")
 if failed:await finish();return
 game.collect();record(game.finished and s.count("bamboo")==bamboo+1,"normal collect awards exactly one bamboo")
 h.village_ui.close();await process_frame
 record(h.ui.visible and not h.village_ui.opened and h.village_ui.institution_game==null,"close restores actual Home HUD")
 var before=h.player.position
 h.go("outside")
 var moved=await wait_until(func():return h.area!="v_mayor" or h.player.position.distance_to(before)>12,10)
 record(moved,"actual Home resumes walking after closing game")
 var returned=await wait_until(func():return h.area=="village" and not h.transition and h.pending.is_empty(),90)
 record(returned,"normal exit returns to village")
 if not returned:await finish();return
 h.village_ui.checkpoint()
 record(s.data.village.last_area=="village" and s.data.village.last_position==[h.player.position.x,h.player.position.y] and s.count("bamboo")==bamboo+1,"final checkpoint preserves real village position and one reward")
 await finish()
