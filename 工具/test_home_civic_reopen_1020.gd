extends SceneTree
const Home=preload("res://ayu_home/v4/home.gd")
var h
var folder:=""
var ayu_path:=""
var core_path:=""
var rows:Array=[]
var failed:=false
var phase:=""
var token:=""
var expected:Dictionary={}
func _initialize():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--phase="):phase=arg.trim_prefix("--phase=")
  elif arg.begins_with("--token="):token=arg.trim_prefix("--token=")
 if phase not in ["create","reopen"] or token.length()!=32 or not token.is_valid_hex_number(false):
  push_error("Explicit phase and 32-hex current-run token required");quit(1);return
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
 var base=ProjectSettings.globalize_path("res://../测试数据/Home重开-1020/").simplify_path()+"/"
 folder=ayu_path.get_base_dir()
 if not folder.begins_with(base) or core_path.get_base_dir()!=folder or ayu_path.get_file()!="life.json" or core_path.get_file()!="core":
  push_error("Both explicit isolated paths required");quit(1);return
 if not DirAccess.dir_exists_absolute(folder):push_error("Unique directory must already exist");quit(1);return
 if folder!=base+token or DirAccess.open(base).is_link(token):
  push_error("Run folder must match current-run token and not be a link");quit(1);return
 var profile={"id":"c2-reopen-"+token,"openid":"c2-reopen-"+token,"avatar":2,"nick":"隔离重开检查"}
 if phase=="create":
  for name in DirAccess.get_files_at(folder):
   push_error("Create requires an empty isolated directory: "+name);quit(1);return
 else:
  if not FileAccess.file_exists(folder+"/handoff.json"):
   push_error("Missing own-run handoff");quit(1);return
  var parsed=JSON.parse_string(FileAccess.get_file_as_string(folder+"/handoff.json"))
  if not parsed is Dictionary:
   push_error("Invalid handoff");quit(1);return
  expected=parsed
  var saved_profile=expected.get("profile",{})
  var profile_ok=saved_profile is Dictionary and saved_profile.size()==profile.size() and saved_profile.get("id")==profile.id and saved_profile.get("openid")==profile.openid and saved_profile.get("nick")==profile.nick and saved_profile.get("avatar")==profile.avatar
  if expected.get("token")!=token or expected.get("folder")!=folder or not profile_ok or not expected.get("ready",false) or expected.get("pid")==OS.get_process_id():
   push_error("Handoff does not match this separate process/run");quit(1);return
  if not FileAccess.file_exists(ayu_path) or not FileAccess.file_exists(core_path+".a") and not FileAccess.file_exists(core_path+".b"):
   push_error("Own-run saves missing; refusing fallback");quit(1);return
 root.set_meta("player_profile",profile)
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
 var f=FileAccess.open(folder+"/result-"+phase+".json",FileAccess.WRITE)
 if f==null:quit(1);return
 f.store_string(JSON.stringify({"rows":rows,"failed":failed,"mode":"full Home headless; normal go, no GUI"},"  "));f.close()
 print("HOME_CIVIC_REOPEN "+phase+" ","FAIL" if failed else "PASS"," ",rows.size());quit(1 if failed else 0)
func run():
 h=Home.new();root.add_child(h)
 if not await wait_until(func():return h.bootstrapped,30):record(false,"Home boot");await finish();return
 var paths_ok=h.life.path==ayu_path and h.village_ui.state.path==core_path
 record(paths_ok,"both runtime save paths equal explicit isolated paths")
 if not paths_ok:await finish();return
 record(not h.village_ui.state.blocked and h.profile==root.get_meta("player_profile"),"unblocked save with exact stable test profile")
 if failed:await finish();return
 if phase=="reopen":await reopen();return
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
 var old_run=game.run_id
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
 if not failed:
  var out=FileAccess.open(folder+"/handoff.json",FileAccess.WRITE)
  if out==null:record(false,"write own-run handoff")
  else:
   out.store_string(JSON.stringify({"token":token,"folder":folder,"profile":h.profile,"ready":true,"pid":OS.get_process_id(),"area":h.area,"position":[h.player.position.x,h.player.position.y],"bamboo":s.count("bamboo"),"before_bamboo":bamboo,"old_run":old_run}));out.close()
 await finish()
func reopen():
 var s=h.village_ui.state
 record(h.area==expected.area,"second process restores actual Home area")
 record(h.player.position.distance_to(Vector2(expected.position[0],expected.position[1]))<0.01,"second process restores actual player position before go")
 record(s.count("bamboo")==int(expected.bamboo) and int(expected.bamboo)==int(expected.before_bamboo)+1,"second process preserves exactly one bamboo reward")
 if failed:await finish();return
 record(not str(expected.old_run).is_empty(),"handoff contains original collected run ID")
 var result=s.act("institution_complete",{"run":expected.old_run})
 print("DUPLICATE_RESULT ",JSON.stringify(result)," PID ",OS.get_process_id())
 record(not result.ok and s.count("bamboo")==int(expected.bamboo),"old collected run rejected through normal completion interface")
 if failed:await finish();return
 var before=h.player.position
 h.go("visit_mayor")
 record(await wait_until(func():return h.area!="village" or h.player.position.distance_to(before)>12,10),"restored Home can continue normal walking")
 record(await wait_until(func():return h.area=="v_mayor" and not h.transition and h.pending.is_empty(),90),"restored normal walk enters village office")
 await finish()
