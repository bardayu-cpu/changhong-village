extends SceneTree
const Home=preload("res://ayu_home/v2/home.gd")
var checks:=0
var failures:=0
func check(ok: bool,what: String) -> void:
	checks+=1
	if not ok:failures+=1;print("FAIL ",what)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var h:=Home.new();h.save_path="/private/tmp/ayu-v2-tests.json";root.add_child(h)
	await process_frame
	h.set_test_clock(12.5);h.admitted=true
	for room in ["exterior","living","dining"]:
		h.enter_room(room,false)
		check(h.world.cfg.source_crop.size()==4,room+" uses explicit original crop")
		for hotspot in h.world.cfg.hotspots:
			var at:Vector2=h.world.v(hotspot.approach)
			check(h.world.walkable(at),room+" approach "+hotspot.id)
			var path:PackedVector2Array=h.world.path(h.world.spawn(),at)
			check(not path.is_empty(),room+" route "+hotspot.id)
			for p in path:check(h.world.walkable(p),room+" path stays outside furniture")
		check(h.world.actors.y_sort_enabled,room+" real y sorting")
		for a in h.people.values():check(a.sheet!=null,"code texture loaded")
	for hour in range(0,240):
		h.set_test_clock(float(hour)/10)
		var home: Array=Home.LegacyData.at_home(h.hour)
		if (h.hour>=7.5 and h.hour<8.25) or (h.hour>=12 and h.hour<13) or (h.hour>=18 and h.hour<19):
			for id in Home.LegacyData.FAMILY:
				var s:Dictionary=h.schedule(id);check(s.area=="dining" and s.action=="eat","all three return for meals")
		if h.hour>=9 and h.hour<10:check(home.is_empty(),"family all out")
		if h.hour>=10 and h.hour<12:check(not home.has("father") and home.has("mother"),"father alone out")
		if h.hour>=14 and h.hour<15:check(not home.has("mother") and home.has("father"),"mother alone out")
	# Entry cannot bypass knocking, including someone else's absent home.
	h.enter_room("exterior",false);h.admitted=false;h.phase="outside";h.enter_room("living",false);check(h.area=="exterior","gate refuses unauthorized entry")
	h.set_test_clock(9.5);h.knock();check(h.phase=="absent","absent knock");h.admit();check(not h.admitted,"absent cannot enter");h.close_modal()
	h.set_test_clock(12.5);h.knock();await create_timer(.9).timeout;check(h.phase=="invited","present knock invitation");h.admit();await create_timer(.7).timeout;check(h.area=="living" and h.admitted,"entry completes without bounce");check(h.door_audio_count==1 and h.transition_count==1,"door sound and fade triggered")
	h.interact("dining");await create_timer(.7).timeout;check(h.area=="dining","living to dining")
	for id in Home.LegacyData.FAMILY:check(h.people[id].visible and h.people[id].action=="eat","meal seated "+id)
	h.interact("living");await create_timer(.7).timeout;h.interact("exit");await create_timer(.7).timeout;check(h.area=="exterior","round trip outside")
	h.admitted=false;h.set_identity(true);h.set_test_clock(9.5);h.knock();check(h.phase=="owner_home","owner key entry");h.admit();await create_timer(.7).timeout;check(h.area=="living","owner can enter absent house")
	h.set_identity(false);check(h.player.id=="visitor","existing distinct player preset")
	# Changes affect world state and durable collection only, never clocks/coins.
	h.set_test_clock(20);h.interact("tv");check(not h.world.tv_on,"tv switches off");h.interact("tv");check(h.world.tv_on,"tv switches on")
	h.interact("lamp");check(not h.world.lamp_on,"lamp switches off");h.interact("lamp");check(h.world.lamp_on,"lamp switches on")
	h.interact("fish");check(h.world.food_until>h.world.elapsed,"fish food emitted")
	h.interact("sofa");check(h.player.action=="sit","player sits");h.stand_up();check(h.player.action=="idle" and h.world.walkable(h.player.position),"player stands on safe floor")
	h.remember("test_leaf");h.remember("test_leaf");check(h.journal.found.count("test_leaf")==1,"no collectible farming")
	check(h.hour==20 and not h.journal.has("coins"),"rest never advances time or credits wallet")
	h.enter_room("dining",false);h.interact("recipe");check(h.journal.found.has("一张叶脉书签"),"hidden collectible");h.close_modal()
	h.set_test_clock(7);var morning:Vector2=h.world.sun_vector();h.set_test_clock(17);check(morning.x*h.world.sun_vector().x<0,"shadow direction follows sun")
	h.set_test_clock(23);h.world.update_light();check(h.world.lights[0].energy>0,"night light remains");check(h.world.lights[1].energy==0,"deep night one lamp")
	h.enter_room("exterior",false);var dog=h.people.xiduo;check(dog.position.x>834 and dog.position.x<1146 and dog.position.y<810,"dog inside courtyard wall")
	for i in 50:
		h._process(.4);check(dog.position.x>834 and dog.position.x<1146 and dog.position.y<810,"roaming dog stays inside")
	h.stop_audio();await create_timer(.15).timeout
	h.queue_free();await process_frame;await process_frame
	print("RESULT ","PASS" if failures==0 else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
