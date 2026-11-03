extends SceneTree
## C2隔离逻辑与寻路预检；不作为正常键鼠实走/H6证据。
const Home=preload("res://ayu_home/v4/home.gd")
var failed:=false
func check(ok:bool,label:String) -> void:
	print(("PASS " if ok else "FAIL ")+label);failed=failed or not ok
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ayu-save=") or arg.begins_with("--core-save="):DirAccess.make_dir_recursive_absolute(arg.split("=",true,1)[1].get_base_dir())
	root.set_meta("player_profile",{"id":"c2-community","openid":"c2-community","avatar":2,"nick":"制作预检"});call_deferred("run")
func run() -> void:
	var h:=Home.new();root.add_child(h)
	for n in 600:
		await process_frame
		if h.bootstrapped:break
	if not h.bootstrapped:check(false,"home boots");quit(1);return
	var state=h.village_ui.state
	check(not state.data.village.resident and float(state.data.village.land[0])<=0,"fresh public visitor without residency or land")
	await h.enter_room("village",false)
	var gate=h.world.spot("visit_community");check(not gate.is_empty() and h.world.path(Vector2(990,3580),Vector2(1280,3780)).size()>0,"public village approach has a path")
	h.cross(gate);await create_timer(1.1).timeout
	check(h.area=="my_cabin" and not state.data.village.resident,"public entrance cross permits first-day visitor")
	check(h.player.position.distance_to(Vector2(347,499))<5,"public entrance arrival matches right-bottom door")
	for spot in h.world.cfg.hotspots+h.world.cfg.doors:
		var goal:=Vector2(spot.approach[0],spot.approach[1]);check(h.world.nearest(goal).distance_to(goal)<5 and not h.world.path(h.player.position,goal).is_empty(),"approach path: "+str(spot.id))
	var positions:Array=[];var actions:Array=[]
	for hour in [9.0,13.0,19.0]:
		h.set_test_clock(hour);h.village_ui.institution_room.sync_schedule(true);positions.append(h.village_ui.institution_room.actor.position);actions.append(h.village_ui.institution_room.actor.action)
	check(positions[0]!=positions[1] and positions[1]!=positions[2] and actions==["wash","stir","read"],"three duty zones and actions")
	for spot in h.world.cfg.hotspots:
		if spot.has("action"):
			h.village_ui.institution_room.handle(spot);check(int(state.data.village.institutions.my_cabin.get(spot.action,0))==1,"visible effect persisted: "+str(spot.action));h.close_modal()
	h.village_ui.institution_room.open_story(1);check(h.modal!=null,"picture story opens its own second page");h.close_modal()
	state.data.village.items.radish=2;state.data.village.items.pepper=2
	var before:Dictionary=state.data.village.items.duplicate(true)
	h.village_ui.open_institution_game("community");await process_frame
	var game=h.village_ui.institution_game;game.begin();check(not game.run_id.is_empty(),"meal session begins");game.step(0);game.cancel();await process_frame
	check(state.data.village.items==before and h.ui.visible,"cancel preserves both inputs and gives no meal")
	h.village_ui.open_institution_game("community");await process_frame;game=h.village_ui.institution_game;game.begin();game.step(2);check(game.progress==0,"cannot stir unwashed food")
	for n in 3:game.step(n)
	check(game.progress==3 and game.collect_button.visible,"wash chop stir enables completion")
	game.collect();check(game.finished and state.count("radish")==1 and state.count("pepper")==1 and state.count("meal")==int(before.get("meal",0))+1,"completion atomically trades real crops for shared meal")
	game.collect();check(state.count("meal")==int(before.get("meal",0))+1,"repeat collection cannot duplicate meal");game.cancel();await process_frame
	await h.enter_room("village",false,"my_cabin");print("PUBLIC_EXIT_ACTUAL ",h.player.position," goal ",h.world.nearest(Vector2(1280,3780)));check(h.player.position.distance_to(Vector2(1288,3784))<1,"exit returns to its public outside entrance")
	await h.enter_room("my_yard",false)
	var private_door:=false
	for door in h.world.cfg.doors:private_door=private_door or door.target=="my_cabin"
	check(not private_door,"private yard has no route gating the public institution")
	h.queue_free();await process_frame;print("COMMUNITY_RUNTIME "+("FAIL" if failed else "PASS"));quit(1 if failed else 0)
