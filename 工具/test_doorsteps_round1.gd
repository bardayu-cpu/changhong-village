extends SceneTree
## 隔离预检，直接调用不算十四张正常截图或H6。
const Home=preload("res://ayu_home/v4/home.gd")
const C=preload("res://ayu_home/v4/core/config.gd")
const S=preload("res://ayu_home/v4/core/state.gd")
var failed:=false
var checks:=0
func check(ok:bool,label:String) -> void:
	checks+=1;failed=failed or not ok;print(("PASS " if ok else "FAIL ")+label)
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ayu-save=") or arg.begins_with("--core-save="):DirAccess.make_dir_recursive_absolute(arg.split("=",true,1)[1].get_base_dir())
	root.set_meta("player_profile",{"id":"c2-doorsteps","openid":"c2-doorsteps","avatar":2,"nick":"制作预检"});call_deferred("run")
func run() -> void:
	var h:=Home.new();root.add_child(h)
	for n in 600:
		await process_frame
		if h.bootstrapped:break
	if not h.bootstrapped:check(false,"home boots");quit(1);return
	await h.enter_room("village",false)
	var s=h.village_ui.state;var before_items:Dictionary=s.data.village.items.duplicate(true);var before_coins:int=s.data.wallet.coins;var before_relationships:int=s.data.renqing.size()
	check(C.DOOR_CHORES.size()==14,"exactly 14 doorstep households")
	var index:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://ayu_home/v4/assets/rooms.json"))
	for id in ["my_cabin","my_yard","village"]:
		check(index.rooms[id]==JSON.parse_string(FileAccess.get_file_as_string("res://ayu_home/v4/assets/"+id+".json")),"navigation index equals runtime room "+id)
	check(h.room_hop("my_cabin","village")=="village" and h.room_hop("village","my_cabin")=="my_cabin","community map graph uses direct public route both ways")
	var replies:Dictionary={};var rows:PackedStringArray=["住户,小事,门边便签,回应,位置"]
	for id in C.DOOR_CHORES:
		var chore:Dictionary=C.DOOR_CHORES[id];var spot:Dictionary=h.world.spot("visit_"+id)
		check(not spot.is_empty() and not spot.has("target") and spot.kind=="door_chore","door replaced by visible outside chore "+id)
		var goal:=Vector2(spot.approach[0],spot.approach[1]);check(not h.world.path(h.player.position,goal).is_empty() and h.world.nearest(goal).distance_to(goal)<18,"real doorstep approach "+id)
		h.interact("visit_"+id);check(h.area=="village" and s.data.village.chores.has(s.date_key()+":house:"+id),"interaction remains outside and persists "+id)
		replies[chore.response]=true
		var count_before:int=s.data.renqing.size();h.interact("visit_"+id);check(s.data.renqing.size()==count_before,"same-day repeat gives no duplicate relationship "+id)
		rows.append("%s,%s,%s,%s,%d / %d"%[id,chore.label,chore.closed,chore.response,spot.approach[0],spot.approach[1]])
	check(replies.size()==14,"14 distinct spoken or written responses")
	check(s.data.renqing.size()==before_relationships+14 and s.data.wallet.coins==before_coins and s.data.village.items==before_items,"all 14 award only one relationship each, no coins/items")
	check(not s.act("door_chore",{"id":"unknown"}).ok,"unknown household cannot mint relationships")
	var open_targets:Array=[]
	for d in h.world.cfg.doors:open_targets.append(d.target)
	check(open_targets.has("v_h3") and open_targets.has("v_h5") and open_targets.has("v_mayor") and open_targets.has("my_cabin") and open_targets.has("exterior") and open_targets.has("v_laowu"),"four institutions plus approved Ayu and old home still connected")
	await h.enter_room("v_h2_up",false)
	check(h.area=="village" and h.player.position.distance_to(h.world.nearest(Vector2(h.world.spot("visit_h2").approach[0],h.world.spot("visit_h2").approach[1])))<40,"legacy closed interior resumes at its own doorstep")
	var reopened:=S.new();reopened.now_override=s.now_override;reopened.open(s.data.profile,s.path);check(reopened.data==JSON.parse_string(JSON.stringify(s.data)),"all doorstep progress and actual room checkpoint survive reopen")
	var out:=FileAccess.open("res://../回执/第1轮/十四户门口-文案与位置.csv",FileAccess.WRITE);out.store_string("\ufeff"+"\n".join(rows)+"\n");out.close()
	h.queue_free();await process_frame;print("DOORSTEPS_ROUND1 ","FAIL" if failed else "PASS"," ",checks," checks");quit(1 if failed else 0)
