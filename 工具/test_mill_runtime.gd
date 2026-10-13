extends SceneTree
## 引擎集成预检；使用隔离存档与直接调用，不冒充正常输入 H6 证据。
const Home=preload("res://ayu_home/v4/home.gd")
var failed:=false
func check(ok:bool,label:String) -> void:
	print(("PASS " if ok else "FAIL ")+label);failed=failed or not ok
func _initialize() -> void:
	root.set_meta("player_profile",{"id":"c2-mill-runtime","openid":"c2-mill-runtime","avatar":2,"nick":"制作预检"});call_deferred("run")
func run() -> void:
	var h:=Home.new();root.add_child(h)
	for i in 600:
		await process_frame
		if h.bootstrapped:break
	if h.bootstrapped:await h.enter_room("v_h3",false)
	check(h.bootstrapped and h.area=="v_h3","actual Home booted in mill")
	if not h.bootstrapped:quit(1);return
	for spot in h.world.cfg.hotspots+h.world.cfg.doors:
		var goal:=Vector2(spot.approach[0],spot.approach[1])
		check(h.world.nearest(goal).distance_to(goal)<5,"approach is on real walkable floor: "+str(spot.id))
		check(not h.world.path(h.world.spawn(),goal).is_empty(),"entrance path to "+str(spot.id))
	var positions:Array=[]
	for hour in [9.0,13.0,19.0]:
		h.set_test_clock(hour);h.village_ui.institution_room.sync_schedule(true)
		positions.append(h.village_ui.institution_room.actor.position)
	check(positions[0]!=positions[1] and positions[1]!=positions[2] and positions[0]!=positions[2],"three daily positions differ")
	check(h.village_ui.institution_room.actor.action=="drink","evening owner actually sits and drinks")
	check(h.village_ui.talk_resident("resident:xiaotao"),"owner dialogue opens")
	h.talk_card("xiaotao");check(h.modal!=null,"male portrait card opens without family lookup")
	h.close_modal()
	var state=h.village_ui.state;state.put("grain",4);state.persist()
	var before:Dictionary=state.data.village.items.duplicate(true)
	h.village_ui.open_institution_game("mill");await process_frame
	var game=h.village_ui.institution_game;game.begin();game.step(0);game.cancel();await process_frame
	check(state.data.village.items==before and h.ui.visible and not h.village_ui.opened,"full-screen cancel restores room with unchanged inventory")
	h.village_ui.open_institution_game("mill");await process_frame;game=h.village_ui.institution_game;game.begin()
	for i in 12:game.step(i%4)
	check(game.collect_button.visible,"completion shows collect button")
	game.collect();check(game.finished and state.count("flour")==int(before.get("flour",0))+1,"full-screen finish saves one flour")
	game.cancel();await process_frame
	check(h.ui.visible and not h.village_ui.opened,"completion returns to room")
	await h.enter_room("v_h3_up",false,"v_h3")
	check(h.area=="v_h3_up" and h.world.cfg.background.ends_with("mill-up-v2.png"),"dedicated upstairs loads")
	check(h.world.nearest(h.player.position).distance_to(h.player.position)<5,"upstairs arrival on walkable landing")
	for spot in h.world.cfg.hotspots+h.world.cfg.doors:
		var goal:=Vector2(spot.approach[0],spot.approach[1])
		check(h.world.nearest(goal).distance_to(goal)<5 and not h.world.path(h.player.position,goal).is_empty(),"upstairs path to "+str(spot.id))
	await h.enter_room("v_h3",false,"v_h3_up")
	check(h.player.position.distance_to(Vector2(439,301))<8,"downstairs returns beside correct staircase")
	h.queue_free();await process_frame
	print("MILL_RUNTIME "+("FAIL" if failed else "PASS"));quit(1 if failed else 0)
