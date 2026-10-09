extends SceneTree
const Home=preload("res://ayu_home/v3/home.gd")
var h
var vp:SubViewport
var failures:Array=[]
var checks:=0
var visited:Dictionary={}
var route_log:Array=[]
var object_log:Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures.append(label);print("FAIL ",label)
func touch(p:Vector2) -> void:
	var e:=InputEventScreenTouch.new();e.position=p;e.pressed=true;vp.push_input(e,true);await process_frame
	e=InputEventScreenTouch.new();e.position=p;e.pressed=false;vp.push_input(e,true);await process_frame
func press(b:Button) -> void:
	check(b.size.x>=40 and b.size.y>=44,"touch size "+b.text)
	await touch(b.get_global_rect().get_center())
func close_all() -> void:
	h.close_modal()
	if h.activities.root:h.activities.close()
	if h.immersive.root:h.immersive.close()
	h.pending="";h.player.route.clear();h.stand_up()
func walk_to(id:String,target:="") -> void:
	# Wait for the real transition animation, as a player must; a timer can fire one frame before the tween.
	while h.transition:await process_frame
	var from:String=h.area;h.go(id)
	check(h.pending==id,"walk request accepted "+from+":"+id)
	for i in 2000:
		h._process(.08)
		if not target.is_empty() and h.area==target:break
		if target.is_empty() and h.pending.is_empty() and h.player.route.is_empty():break
		if i%40==0:await process_frame
		if i==1999:check(false,"walk timeout "+from+":"+id+" at "+str(h.player.position)+" pending="+h.pending+" transition="+str(h.transition))
	if not target.is_empty():
		check(h.area==target,"walk transition "+from+" -> "+target)
		await create_timer(.42).timeout
		h._process(1.5)
		check(h.area==target,"arrival does not bounce "+target)
		route_log.append([from,h.area,h.player.position.x,h.player.position.y,h.player.face])
func traverse(room:String) -> void:
	visited[room]=true
	var doors:Array=h.definitions[room].doors.duplicate(true)
	for d in doors:
		if visited.has(d.target):continue
		await walk_to(d.id,d.target)
		await traverse(d.target)
		await walk_to("to_"+room,room)
func test_activities() -> void:
	for kind in ["guitar","puzzle","album"]:
		h.activities.open(kind,{"v2_art":true});await process_frame;await process_frame;var a=h.activities
		if kind=="guitar":
			for n in a.melody:await press(a.note_buttons[n])
		elif kind=="puzzle":
			for i in 9:
				if a.order[i]!=i:
					var j:int=a.order.find(i);await press(a.tiles[i]);await press(a.tiles[j])
		else:
			for tile in a.album_tray:await press(tile);await press(a.album_slots[tile.index])
		check(a.finished,"touch completes "+kind);a.close();a.open(kind,{"v2_art":true});await process_frame
		for b in a.root.find_children("*","Button",true,false):
			if b.text=="关闭":await press(b);break
		check(a.root==null,"touch exits "+kind)
	h.immersive.open("fish");await process_frame;await process_frame;var a=h.immersive
	for n in 5:
		await touch(Vector2(260+n*8,220))
		for i in 160:a._process(.1)
	check(a.eaten>=12 and a.finished,"fish pursue and consume 12 pellets")
	check(a.fish.filter(func(f):return f.fed>0).size()>1,"several fish compete for food")
	a.close();a.open("tv");await process_frame
	for i in 220:a._process(.1)
	check(a.finished,"TV animated programme completes")
	var before:int=a.channel;await touch(Vector2(270,350));check(a.channel!=before,"TV screen tap changes programme");a.close()
	for kind in ["fish","tv","stars","detail","pet"]:
		a.open(kind,{"pet":"qiuqiu","name":"求求","hour":20.0});await process_frame;await process_frame
		for b in a.root.find_children("*","Button",true,false):
			if b.text in ["离开","起身"]:await press(b);break
		check(a.root==null,"touch exits immersive "+kind)
func run() -> void:
	vp=SubViewport.new();vp.size=Vector2i(540,960);root.add_child(vp)
	h=Home.new();h.test_panel_enabled=true;h.save_path="/private/tmp/ayu-v3-play-save.json";vp.add_child(h);await process_frame;h.set_process(false);h.set_test_clock(12.25);h.admitted=true
	for room in h.definitions:
		h.enter_room(room,false);h._process(3)
		check(h.area==room,"spawn stays in "+room)
	h.enter_room("exterior",false);await traverse("exterior")
	check(visited.size()==h.definitions.size(),"walk reaches all 26 locations")
	check(h.area=="exterior","walk returns home")
	for room in h.definitions:
		h.enter_room(room,false);h.cooldown=999
		check(h.world.cfg.hotspots.size()>=3,"three real objects "+room)
		for spot in h.definitions[room].hotspots:
			var count:int=h.effects_log.size();await walk_to(spot.id)
			check(h.area==room,"object approach remains in "+room+":"+spot.id)
			check(h.effects_log.size()==count+1,"object executes "+room+":"+spot.id)
			var kind:String=spot.get("kind","reaction")
			check(h.world.reactions.has(spot.id) or h.activities.root!=null or h.immersive.root!=null,"object visible effect "+room+":"+spot.id)
			object_log.append(room+":"+spot.id);close_all();await process_frame
	h.enter_room("living",false);h.set_test_clock(12.25);var light:bool=h.world.lamp_on;h.interact("lamp");check(h.world.lamp_on!=light,"lamp toggles in daylight")
	await test_activities()
	for hr in [7.75,12.25,18.5]:
		h.set_test_clock(hr)
		for who in Home.Data.FAMILY:check(h.schedule(who).area=="dining" and h.schedule(who).action=="eat","meal "+str(hr)+who)
	for hr in [9.5,10.5,14.5]:
		h.set_test_clock(hr);check(Home.Data.at_home(hr).size()==(0 if hr==9.5 else 2),"away schedule "+str(hr))
	for hr in range(0,24):
		h.set_test_clock(hr)
		for who in Home.Data.FAMILY:check(h.schedule(who).area=="away" or h.definitions.has(h.schedule(who).area),"schedule has physical room "+str(hr)+who)
	for m in [3,7,10,1]:h.set_test_clock(12.25,m,"rain");check(h.world.month==m and h.world.weather=="rain","instant season/weather "+str(m))
	check(not h.journal.has("coins") and not h.journal.has("wallet"),"no currency/reward loop")
	var f:=FileAccess.open("res://ayu_home/v3/evidence/playthrough.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures,"visited":visited.keys(),"walks":route_log,"objects":object_log},"  "));f.close()
	print("RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures.size()," walks=",route_log.size()," objects=",object_log.size());h.stop_audio();vp.queue_free();await process_frame;await process_frame;quit(failures.size())
