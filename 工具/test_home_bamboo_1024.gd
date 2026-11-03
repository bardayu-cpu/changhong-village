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
 var base=ProjectSettings.globalize_path("res://../测试数据/Home竹编-1024/").simplify_path()+"/"
 folder=ayu_path.get_base_dir()
 if not folder.begins_with(base) or core_path.get_base_dir()!=folder or ayu_path.get_file()!="life.json" or core_path.get_file()!="core":
  push_error("Both explicit isolated paths required");quit(1);return
 if not DirAccess.dir_exists_absolute(folder):push_error("Unique directory must already exist");quit(1);return
 if folder!=base+token or DirAccess.open(base).is_link(token):
  push_error("Run folder must match current-run token and not be a link");quit(1);return
 var profile={"id":"c2-bamboo-"+token,"openid":"c2-bamboo-"+token,"avatar":2,"nick":"隔离重开检查"}
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
 print("HOME_BAMBOO "+phase+" ","FAIL" if failed else "PASS"," ",rows.size());quit(1 if failed else 0)
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
 if not await walk_to("visit_daba","v_daba"):await finish();return
 check_table_navigation()
 if failed:await finish();return
 var s=h.village_ui.state
 var items=s.data.village.items.duplicate(true);var coins=s.data.wallet.coins;var relations=s.data.renqing.size()
 var start=h.player.position
 h.go("house_help")
 record(await wait_until(func():return int(s.data.village.helped.get("house:daba",0))==1 and h.pending.is_empty(),45),"normal walking reaches workbench and collects bamboo strips once")
 record(h.player.position.distance_to(start)>1 and s.data.renqing.size()==relations+1,"walking interaction adds one relationship memory")
 record(not "今日不便拜访" in h.note and not "竹帘放下" in h.note,"open house uses indoor wording")
 h.go("house_help");await process_frame
 record(int(s.data.village.helped.get("house:daba",0))==1 and s.data.renqing.size()==relations+1,"repeat workbench shares original daily cap")
 h.go("tea_seat")
 record(await wait_until(func():return h.player.action=="sit" and h.pending.is_empty(),45),"normal walking sits on bamboo seat")
 if failed:await finish();return
 if not await walk_to("outside","village"):await finish();return
 record(h.player.action=="idle" and h.player.position.distance_to(Vector2(2528,1327))<150,"exit stands up and returns beside original village door")
 record(s.data.village.items==items and s.data.wallet.coins==coins,"visit and help change no inventory or coins")
 # Save the actual inside position too: an opened household must survive the old forced-return rule.
 if not await walk_to("visit_daba","v_daba"):await finish();return
 h.village_ui.checkpoint()
 record(s.data.village.last_area==h.area and s.data.village.last_position==[h.player.position.x,h.player.position.y],"checkpoint records actual interior position")
 if not failed:
  var out=FileAccess.open(folder+"/handoff.json",FileAccess.WRITE)
  if out==null:record(false,"write own-run handoff")
  else:
   out.store_string(JSON.stringify({"token":token,"folder":folder,"profile":h.profile,"ready":true,"pid":OS.get_process_id(),"area":h.area,"position":[h.player.position.x,h.player.position.y],"items":items,"coins":coins,"relations":s.data.renqing.size(),"helped":s.data.village.helped.get("house:daba",0)}));out.close()
 await finish()
func reopen():
 var s=h.village_ui.state
 record(h.area==expected.area and h.area=="v_daba","second process restores opened household without redirect")
 record(h.player.position.distance_to(Vector2(expected.position[0],expected.position[1]))<0.01,"second process restores real interior position")
 record(s.data.wallet.coins==expected.coins and s.data.village.items==expected.items and s.data.renqing.size()==int(expected.relations),"second process preserves inventory coins and relationship")
 if failed:await finish();return
 h.go("house_help")
 record(await wait_until(func():return h.pending.is_empty() and "记着" in h.note,45),"saved daily workbench remains completed")
 record(int(s.data.village.helped.get("house:daba",0))==1 and s.data.renqing.size()==int(expected.relations),"reopen cannot repeat daily relationship award")
 if not await walk_to("outside","village"):await finish();return
 var before=h.player.position
 h.go("visit_erba")
 record(await wait_until(func():return h.pending.is_empty() and "今日不便拜访，下次再来。" in h.note,90),"unopened neighbour retains fixed closed-door wording")
 record(h.area=="village" and h.player.position.distance_to(before)>1,"unopened neighbour remains outside after real walking")
 record(s.data.wallet.coins==expected.coins and s.data.village.items==expected.items,"closed neighbour also gives no coins or inventory")
 await finish()
func check_table_navigation():
 var probe:=Vector2(398,380);var blocked:=false
 for i in 60:
  var next:=probe+Vector2(0,-1)
  if not h.world.passable(next):blocked=true;break
  probe=next
 record(blocked and probe.y>=359,"central table front blocks one-pixel walking steps")
 record(not h.world.passable(Vector2(390,275)),"central tabletop is not walkable")
 var route:PackedVector2Array=h.world.path(h.player.position,Vector2(317,199))
 var clear:=not route.is_empty();var previous:Vector2=h.player.position
 for point in route:
  var steps:=maxi(1,int(ceil(previous.distance_to(point))))
  for i in range(1,steps+1):
   if not h.world.passable(previous.lerp(point,float(i)/steps)):clear=false
  previous=point
 record(clear,"workbench bypass route is passable at every one-pixel step")
