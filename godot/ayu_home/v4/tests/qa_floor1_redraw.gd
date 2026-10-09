extends SceneTree
const Home=preload("res://ayu_home/v4/home.gd")
var h
var checks:Array=[]
var out:="res://ayu_home/v4/evidence/floor1-redraw/"
func _initialize() -> void:call_deferred("run")
func check(ok:bool,kind:String,data:Dictionary) -> void:
	data["pass"]=ok;data["check"]=kind;checks.append(data);print(JSON.stringify(data))
func close_ui() -> void:
	h.close_modal();h.games.close(false);h.activities.close();h.immersive.close(false);h.photo.close(false);h.clear_scene_controls();h.stand_up()
func tick(n:int) -> void:
	for i in n:
		h._process(.1)
		if i%20==0:await process_frame
func door_walk(room:String,d:Dictionary) -> void:
	close_ui();h.enter_room(room,false);await tick(15)
	var target:String=d.target;var start_cooldown:float=h.cooldown
	h.pending="";h.player.route=h.world.path(h.player.position,h.world.nearest(h.World.v(d.approach)));var n:=0
	while h.area==room and not h.player.route.is_empty() and n<1200:
		h._process(.1);n+=1
		if n%25==0:await process_frame
	if h.transition:await create_timer(.4).timeout
	check(h.area==target,"door",{"room":room,"door":d.id,"target":target,"arrived":h.area,"ticks":n,"cooldown_at_start":start_cooldown})
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var vp:=SubViewport.new();vp.size=Vector2i(540,960);root.add_child(vp)
	h=Home.new();h.town_profile={"id":"floor1-redraw-qa"};h.save_path="/private/tmp/ayu-floor1-redraw-qa.json";vp.add_child(h);await process_frame
	h.set_process(false);h.set_test_clock(12.25);h.admitted=true;h.close_modal();h.sound_on=false
	var floor_rooms:Array=[]
	for room in h.definitions:
		if int(h.definitions[room].floor)==1:floor_rooms.append(room)
	for room in floor_rooms:
		h.enter_room(room,false);await tick(15)
		var w=h.world;var cells:=0;var reached:Dictionary={};var queue:Array=[Vector2i(w.spawn()/w.CELL)];reached[queue[0]]=true;var qi:=0
		while qi<queue.size():
			var c:Vector2i=queue[qi];qi+=1
			for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var next:Vector2i=c+d
				if w.grid.is_in_boundsv(next) and not w.grid.is_point_solid(next) and not reached.has(next):reached[next]=true;queue.append(next)
		for y in w.grid.region.size.y:
			for x in w.grid.region.size.x:
				if not w.grid.is_point_solid(Vector2i(x,y)):cells+=1
		check(reached.size()==cells,"walkable_connected",{"room":room,"reachable_cells":reached.size(),"all_walkable_cells":cells})
		for spot in h.definitions[room].hotspots:
			close_ui();h.enter_room(room,false);await tick(15)
			var raw:Vector2=h.World.v(spot.approach);var displacement:float=h.world.nearest(raw).distance_to(raw)
			h.go(spot.id);var route_start:int=h.player.route.size();var n:=0
			while not h.pending.is_empty() and h.area==room and n<1400:
				h._process(.1);n+=1
				if n%25==0:await process_frame
			var opened:bool=h.area==room and h.pending.is_empty() and route_start>0 and h.effects_log.has(room+":"+spot.id)
			check(opened and displacement<=8,"interaction",{"room":room,"object":spot.id,"kind":spot.kind,"label":spot.label,"opened":opened,"approach_correction":displacement})
			close_ui();check(not h.busy(),"exit",{"room":room,"object":spot.id})
		for d in h.definitions[room].doors:await door_walk(room,d)
	# Exercise only reciprocal boundary entrances (not an outdoor/second-floor regression).
	for room in floor_rooms:
		for d in h.definitions[room].doors:
			if floor_rooms.has(d.target):continue
			for back in h.definitions[d.target].doors:
				if back.target==room:await door_walk(d.target,back)
	# Existing floor-one family actions which are not fixed furniture hotspots.
	close_ui();h.set_test_clock(23);h.enter_room("cats",false)
	for id in ["qiuqiu","luoluo","tiantian"]:
		close_ui();await tick(15);h.go("person:"+id);var n:=0
		while not h.pending.is_empty() and h.area=="cats" and n<600:h._process(.1);n+=1
		check(h.area=="cats" and h.pending.is_empty() and h.people[id].visible,"find_cat",{"cat":id,"room":"cats"})
	check(h.life.cats_today()==3,"find_three_cats",{"count":h.life.cats_today()})
	close_ui();h.life.data.resident=true;h.life.data.invites={};h.set_test_clock(12.25);h.enter_room("kitchen",false);h.check_meal_invite()
	check(h.invite_panel!=null,"meal_invitation",{"room":"kitchen"})
	if h.invite_panel:
		var arrival=h.invite_panel.get_child(0).get_child(1).get_child(0);arrival.pressed.emit()
		check(h.area=="dining" and h.player.action=="eat","accept_meal",{"room":h.area,"action":h.player.action})
	close_ui()
	var failed:Array=checks.filter(func(c):return not c.pass)
	var file:=FileAccess.open(out+"floor1-checks.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failed,"scope":"12 floor-one rooms, 53 existing hotspots, their doors and reciprocal boundary entrances; normal cooldown unchanged"},"  "));file.close()
	print("RESULT ","PASS" if failed.is_empty() else "FAIL"," checks=",checks.size()," failed=",failed.size());h.stop_audio();vp.queue_free();await process_frame;quit(0 if failed.is_empty() else 1)
