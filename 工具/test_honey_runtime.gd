extends SceneTree
## 隔离的引擎/事务预检，直接调用功能；正常输入及画面由C3另验。
const Home=preload("res://ayu_home/v4/home.gd")
var failed:=false
func check(ok:bool,label:String) -> void:
	print(("PASS " if ok else "FAIL ")+label);failed=failed or not ok
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ayu-save=") or arg.begins_with("--core-save="):
			DirAccess.make_dir_recursive_absolute(arg.split("=",true,1)[1].get_base_dir())
	root.set_meta("player_profile",{"id":"c2-honey-runtime","openid":"c2-honey-runtime","avatar":2,"nick":"制作预检"});call_deferred("run")
func run() -> void:
	var h:=Home.new();root.add_child(h)
	for n in 600:
		await process_frame
		if h.bootstrapped:break
	if not h.bootstrapped:check(false,"home boots");quit(1);return
	await h.enter_room("v_h5",false)
	for spot in h.world.cfg.hotspots+h.world.cfg.doors:
		var goal:=Vector2(spot.approach[0],spot.approach[1])
		check(h.world.nearest(goal).distance_to(goal)<5 and not h.world.path(h.player.position,goal).is_empty(),"real approach path: "+str(spot.id))
	var positions:Array=[];var actions:Array=[]
	for hour in [9.0,13.0,19.0]:
		h.set_test_clock(hour);h.village_ui.institution_room.sync_schedule(true)
		positions.append(h.village_ui.institution_room.actor.position);actions.append(h.village_ui.institution_room.actor.action)
	check(positions[0]!=positions[1] and positions[1]!=positions[2],"host moves among three zones")
	check(actions==["wash","honey","drink"],"three distinct host activities")
	var state=h.village_ui.state
	for spot in h.world.cfg.hotspots:
		if spot.has("action"):
			var handled:bool=h.village_ui.institution_room.handle(spot)
			check(handled and int(state.data.village.institutions.get("v_h5",{}).get(spot.action,0))==1,"saved visible effect: "+str(spot.action)+" / "+h.note)
	h.village_ui.open_institution_game("honey");await process_frame
	var game=h.village_ui.institution_game;var before:Dictionary=state.data.village.items.duplicate(true)
	game.begin();check(not game.run_id.is_empty(),"honey begins with persisted session");game.step(0);game.cancel();await process_frame
	check(state.data.village.items==before and h.ui.visible,"honey cancel has no reward and restores room")
	h.village_ui.open_institution_game("honey");await process_frame;game=h.village_ui.institution_game;game.begin()
	game.step(5);check(game.progress==0,"wrong comb cannot advance")
	for index in game.HONEY_SEQUENCE:game.step(index)
	check(game.progress==6 and game.collect_button.visible,"six combs expose collect")
	game.collect();check(game.finished and state.count("honey")==int(before.get("honey",0))+1,"bottled honey in shared inventory")
	game.collect();check(state.count("honey")==int(before.get("honey",0))+1,"collect cannot duplicate honey")
	game.cancel();await process_frame
	h.village_ui.open_institution_game("honey");await process_frame;game=h.village_ui.institution_game;game.begin()
	check(game.run_id.is_empty(),"same date cannot start second bottle");game.cancel();await process_frame
	h.queue_free();await process_frame
	print("HONEY_RUNTIME "+("FAIL" if failed else "PASS"));quit(1 if failed else 0)
