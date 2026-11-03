extends SceneTree
## 隔离引擎预检；直接调用不冒充正常实走或H6。
const Home=preload("res://ayu_home/v4/home.gd")
var failed:=false
func check(ok:bool,label:String) -> void:
	print(("PASS " if ok else "FAIL ")+label);failed=failed or not ok
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ayu-save=") or arg.begins_with("--core-save="):DirAccess.make_dir_recursive_absolute(arg.split("=",true,1)[1].get_base_dir())
	root.set_meta("player_profile",{"id":"c2-civic-runtime","openid":"c2-civic-runtime","avatar":2,"nick":"制作预检"});call_deferred("run")
func run() -> void:
	var h:=Home.new();root.add_child(h)
	for n in 600:
		await process_frame
		if h.bootstrapped:break
	if not h.bootstrapped:check(false,"home boots");quit(1);return
	await h.enter_room("v_mayor",false,"village")
	check(h.player.position.distance_to(Vector2(136,440))<4,"front entry arrives inside doorway")
	for spot in h.world.cfg.hotspots+h.world.cfg.doors:
		var goal:=Vector2(spot.approach[0],spot.approach[1]);check(h.world.nearest(goal).distance_to(goal)<5 and not h.world.path(h.player.position,goal).is_empty(),"approach path: "+str(spot.id))
	var state=h.village_ui.state;var positions:Array=[];var actions:Array=[]
	for hour in [9.0,13.0,19.0]:
		h.set_test_clock(hour);h.village_ui.institution_room.sync_schedule(true);positions.append(h.village_ui.institution_room.actor.position);actions.append(h.village_ui.institution_room.actor.action)
	check(positions[0]!=positions[1] and positions[1]!=positions[2] and actions==["registry","stamp","read"],"three host positions and activities")
	for spot in h.world.cfg.hotspots:
		if spot.has("action"):
			h.village_ui.institution_room.handle(spot)
			check(int(state.data.village.institutions.get("v_mayor",{}).get(spot.action,0))==1,"visible effect saved: "+str(spot.action))
	check(not state.data.village.resident and int(state.data.wallet.coins)==0,"opening counter does not submit residency or spend")
	h.village_ui.close();h.village_ui.open_institution_game("civic");await process_frame
	var game=h.village_ui.institution_game;var before:Dictionary=state.data.village.items.duplicate(true)
	game.begin();check(not game.run_id.is_empty(),"civic session persists");game.step(1);game.cancel();await process_frame
	check(before==state.data.village.items and h.ui.visible,"cancel has no material reward")
	h.village_ui.open_institution_game("civic");await process_frame;game=h.village_ui.institution_game;game.begin()
	game.step(0);check(game.progress==0,"wrong category does not advance")
	for category in game.CIVIC_SEQUENCE:game.step(category)
	check(game.progress==3 and game.collect_button.visible,"three sorted cards allow completion")
	game.collect();check(game.finished and state.count("bamboo")==int(before.get("bamboo",0))+1,"repair bamboo joins shared inventory")
	game.collect();check(state.count("bamboo")==int(before.get("bamboo",0))+1,"no duplicate material");game.cancel();await process_frame
	await h.enter_room("v_mayor_up",false,"v_mayor")
	check(h.player.position.distance_to(Vector2(164,307))<4,"upstairs arrival uses open corridor")
	for spot in h.world.cfg.hotspots+h.world.cfg.doors:
		var goal:=Vector2(spot.approach[0],spot.approach[1]);check(h.world.nearest(goal).distance_to(goal)<5 and not h.world.path(h.player.position,goal).is_empty(),"upstairs path: "+str(spot.id))
	await h.enter_room("v_mayor",false,"v_mayor_up")
	check(h.player.position.distance_to(Vector2(130,226))<4,"returns to correct left staircase")
	h.village_ui.open_institution_game("civic");await process_frame;game=h.village_ui.institution_game;game.begin();check(game.run_id.is_empty(),"civic reward limited to one per date");game.cancel();await process_frame
	await h.enter_room("v_mayor_up",false);h.read_book(h.world.spot("archive_read"));check(h.player.bubble.text.begins_with("资料室"),"archive uses its own book pages");h.stand_up()
	await h.enter_room("v_h3_up",false);h.read_book(h.world.spot("up_book"));check(h.player.bubble.text.begins_with("粮账"),"MILL-01 grain ledger replaces generic bird text");h.book_page();check(h.player.bubble.text.contains("谷壳"),"MILL-01 second ledger page");h.stand_up()
	h.queue_free();await process_frame;print("CIVIC_RUNTIME "+("FAIL" if failed else "PASS"));quit(1 if failed else 0)
