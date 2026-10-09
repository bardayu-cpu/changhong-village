extends Node2D
## v3 complete home: source-faithful rooms, bidirectional thresholds and tangible objects.
const UI=preload("res://ayu_home/v3/pixel_ui.gd")
const Assets=preload("res://ayu_home/v2/assets.gd")
const World=preload("res://ayu_home/v3/world.gd")
const Actor=preload("res://ayu_home/v3/actor.gd")
const Activities=preload("res://ayu_home/v3/activities.gd")
const Immersive=preload("res://ayu_home/v3/immersive.gd")
const Data=preload("res://ayu_home/home_data.gd")
const NAMES={"ayu":"阿鱼","father":"爸爸","mother":"妈妈","qiuqiu":"求求","luoluo":"落落","tiantian":"天天","xiduo":"喜多"}
const P="res://ayu_home/v3/assets/"
var definitions:Dictionary={}
var world
var player
var people:Dictionary={}
var scene_frame:Control
var hud:CanvasLayer
var ui:Control
var title:Label
var time_label:Label
var hint:Label
var modal:Control
var fade:ColorRect
var markers:Control
var toolbar:HBoxContainer
var near_button:Button
var area:="exterior"
var hour:=12.0
var month:=10
var day:=4
var weather:="clear"
var test_hour:=-1.0
var test_month:=0
var test_weather:=""
var test_panel_enabled:=false
var bootstrapped:=false
var is_owner:=false
var admitted:=false
var phase:="outside"
var pending:=""
var transition:=false
var cooldown:=0.0
var arrival_locks:Dictionary={}
var camera:=Vector2.ZERO
var view_scale:=2.0
var ui_scale:=1.0
var elapsed:=0.0
var clock_poll:=0.0
var last_slot:=""
var sound_on:=true
var amb:AudioStreamPlayer
var sfx:AudioStreamPlayer
var activities
var immersive
var rest_position:=Vector2.ZERO
var note:="点地面走动，也可以用方向键。走到门边，就能进出。"
var near_id:=""
var marker_nodes:Array=[]
var room_history:Array=[]
var transition_count:=0
var door_audio_count:=0
var effects_log:Array=[]
var room_state:Dictionary={}
var save_path:="user://ayu_home_life_v3.json"
var journal:Dictionary={"version":3,"found":[],"completed":{},"notes":[]}
var talk_label:Label
var talk_line:=""
var talk_chars:=0.0
var talk_next:Callable
var focus:=""
var map_group:="一楼"
var greeting_next:=8.0

func _ready() -> void:
	DisplayServer.window_set_title("阿鱼家 · v3 电脑试玩")
	definitions=JSON.parse_string(FileAccess.get_file_as_string(P+"rooms.json")).rooms
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ayu-hour="):test_hour=float(arg.get_slice("=",1))
		elif arg.begins_with("--ayu-month="):test_month=int(arg.get_slice("=",1))
		elif arg.begins_with("--ayu-weather="):test_weather=arg.get_slice("=",1)
		elif arg.begins_with("--ayu-area="):area=arg.get_slice("=",1)
		elif arg.begins_with("--ayu-save="):save_path=arg.substr(11)
		elif arg.begins_with("--ayu-focus="):focus=arg.get_slice("=",1)
		elif arg=="--ayu-test" and OS.is_debug_build():test_panel_enabled=true
		elif arg=="--ayu-owner=true" and OS.is_debug_build():is_owner=true
	if not definitions.has(area):area="exterior"
	load_journal();read_clock()
	scene_frame=Control.new();scene_frame.clip_contents=true;scene_frame.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(scene_frame)
	world=World.new();scene_frame.add_child(world)
	amb=AudioStreamPlayer.new();add_child(amb);sfx=AudioStreamPlayer.new();add_child(sfx)
	make_ui()
	activities=Activities.new();add_child(activities)
	activities.closed.connect(func():note="玩好了，慢慢逛。";stand_up())
	activities.completed.connect(complete)
	immersive=Immersive.new();add_child(immersive);immersive.closed.connect(func():note="还可以再来坐一会儿。";stand_up())
	immersive.completed.connect(complete)
	enter_room(area,false)
	if not focus.is_empty():
		var h:Dictionary=world.spot(focus)
		if not h.is_empty():player.position=world.nearest(World.v(h.approach));camera=player.position-Vector2(0,55)
	get_viewport().size_changed.connect(layout)
	bootstrapped=true
func read_clock() -> void:
	var now:=Time.get_datetime_dict_from_system()
	hour=test_hour if test_hour>=0 else float(now.hour)+float(now.minute)/60.0
	month=test_month if test_month>0 else int(now.month);day=int(now.day)
	weather=test_weather if not test_weather.is_empty() else ("rain" if (month+day)%4==0 else "clear")
	if world:world.hour=hour;world.month=month;world.weather=weather
	if time_label:time_label.text="%02d:%02d  %s · %s%s"%[int(hour),int(hour*60)%60,Data.SEASONS[Data.season(month)],"雨" if weather=="rain" else "晴"," · 试玩" if test_hour>=0 else ""]
func set_test_clock(h:float,m:=10,w:="clear") -> void:
	test_hour=h;test_month=m;test_weather=w;read_clock();sync_family(true);play_ambience();note="时间、季节和天气已切换。"
func set_identity(owner:bool) -> void:is_owner=owner
func dir(face:String) -> Vector2:return {"up":Vector2.UP,"down":Vector2.DOWN,"left":Vector2.LEFT,"right":Vector2.RIGHT}.get(face,Vector2.DOWN)
func anchor(room:String,id:String) -> Vector2:
	var cfg:Dictionary=definitions[room]
	return World.v(cfg.anchors.get(id,cfg.spawn))
func enter_room(which:String,with_transition:=true,from:="") -> void:
	if not definitions.has(which):return
	if world and not world.cfg.is_empty():room_state[area]={"lamp":world.lamp_on,"tv":world.tv_on,"toggles":world.toggles.duplicate()}
	area=which;pending="";people.clear();world.load_room(area);world.hour=hour;world.month=month;world.weather=weather;world.reactions.clear();world.toggles.clear()
	var state:Dictionary=room_state.get(area,{})
	world.lamp_on=state.get("lamp",true);world.tv_on=state.get("tv",hour>=6 and hour<22);world.toggles=state.get("toggles",{}).duplicate()
	player=Actor.new();world.actors.add_child(player);player.setup("visitor");player.position=world.spawn()
	for d in world.cfg.doors:
		if d.target==from:
			player.face=d.face;player.position=world.nearest(World.v(d.approach)+dir(d.face)*25);break
	for id in NAMES:
		var actor:=Actor.new();world.actors.add_child(actor);actor.setup(id);people[id]=actor
	arrival_locks.clear()
	for doorway in world.cfg.doors:
		if player.position.distance_to(world.nearest(World.v(doorway.approach)))<46:arrival_locks[doorway.id]=true
	sync_family(true);cooldown=1.0;room_history.append(area);title.text="阿鱼家 · "+str(world.cfg.title).replace("后花园 · 果园 · 菜地","后花园").replace("一楼楼梯与过道","一楼楼梯")
	camera=player.position-Vector2(0,65);world.parallax_origin=camera
	note="走到门边自动进出，点气泡看看。";make_markers();layout();play_ambience()
	if with_transition:
		transition=true;transition_count+=1;door_audio_count+=1;play_sound("door");fade.color=Color(.16,.11,.08,.9)
		var tw:=create_tween();tw.tween_property(fade,"color:a",0,.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT);tw.finished.connect(func():transition=false)
func schedule(id:String) -> Dictionary:
	var old:Dictionary=Data.state(id,hour);var room:="";var action:String=old.action
	if action=="away":return {"area":"away","action":"away","pos":Vector2.ZERO,"face":"down"}
	if action=="eat":room="dining"
	elif action=="sleep" or action=="rest":room="ayu_room" if id=="ayu" else "parents"
	elif action=="fish":room="living"
	elif action=="cook":room="kitchen"
	elif action=="clean":room="living" if id=="ayu" else ("laundry" if id=="mother" else "garage")
	elif action=="work":room="workshop"
	elif action in ["computer","homework","game","guitar"]:room="study";action="computer" if action=="homework" else action
	elif action=="garden":room="garden"
	elif action=="mahjong":room="mahjong";action="read"
	elif action in ["tv","record"]:room="living"
	elif action=="read":room="study" if id=="ayu" else "living"
	else:room="terrace"
	var key:=id+"_meal" if action=="eat" else (id+"_seat" if room=="living" and action in ["tv","record","read"] else ("fish" if action=="fish" else id))
	return {"area":room,"action":action,"pos":anchor(room,key),"face":old.face}
func sync_family(force:=false) -> void:
	if people.is_empty():return
	for id in Data.FAMILY:
		var st:=schedule(id);var a=people[id];a.visible=st.area==area
		if a.visible:
			a.destination_action=st.action;a.destination_face=st.face;a.target=st.pos
			if force:a.position=st.pos;a.action=st.action;a.face=st.face;a.route.clear()
			elif a.position.distance_to(st.pos)>8:a.route=world.path(a.position,st.pos)
	var cats:=["qiuqiu","luoluo","tiantian"]
	for id in cats+["xiduo"]:
		var a=people[id];a.visible=false
		if id=="xiduo":
			a.visible=area=="exterior"
			if force and a.visible:a.position=anchor("exterior","dog");a.action="sniff";a.cooldown=12
		else:
			var loc:String="cats" if hour<7 or hour>=22 else (["living","cats","study"][(day+cats.find(id))%3] if hour<18 else "living")
			a.visible=area==loc
			if a.visible and force:
				var p:=anchor(loc,id)
				if loc=="study":p=world.spawn()+Vector2(cats.find(id)*35,-8)
				a.position=p;a.action="lie";a.cooldown=12+cats.find(id)*4
func busy() -> bool:return transition or modal!=null or activities.root!=null or immersive.root!=null
func _process(dt:float) -> void:
	if not bootstrapped:return
	elapsed+=dt;cooldown=maxf(0,cooldown-dt);clock_poll+=dt
	if clock_poll>=1:
		clock_poll=0;read_clock();var slot:=str(int(hour*4))
		if slot!=last_slot:last_slot=slot;sync_family(false)
	if talk_label and is_instance_valid(talk_label):talk_chars+=dt*28;talk_label.visible_characters=int(talk_chars)
	if not busy():
		player.move_along(dt,135)
		var axis:=Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
		if axis.length()>0:
			if player.action=="sit":stand_up()
			player.route.clear();pending="";axis=axis.normalized()*dt*135
			# Slide along an obstacle rather than stop on a diagonal corner.
			for delta in [Vector2(axis.x,0),Vector2(0,axis.y)]:
				if world.walkable(player.position+delta):player.position+=delta
			player.walking=true;player.face="right" if axis.x>0 else ("left" if axis.x<0 else ("down" if axis.y>0 else "up"))
		if not pending.is_empty() and player.route.is_empty():
			var id:=pending;pending="";interact(id)
		elif cooldown<=0 and pending.is_empty():
			for d in world.cfg.doors:
				var distance_to_door:float=player.position.distance_to(world.nearest(World.v(d.approach)))
				if arrival_locks.has(d.id):
					if distance_to_door>42:arrival_locks.erase(d.id)
					else:continue
				if distance_to_door<12:
					cross(d);break
	for id in people:
		var a=people[id]
		if not a.visible:continue
		a.move_along(dt,34 if a.pet else 62)
		if a.pet and a.route.is_empty() and a.cooldown<=0:
			var p:Vector2=a.position+Vector2(sin(elapsed+id.length())*30,cos(elapsed+id.length())*16)
			if area=="exterior":p=p.clamp(Vector2(900,687),Vector2(1060,768))
			a.route=world.path(a.position,p);a.destination_action="lie" if id!="xiduo" else "sniff";a.cooldown=18
		if not a.pet and elapsed>greeting_next and a.position.distance_to(player.position)<105 and not busy():
			a.say({"ayu":"来啦，慢慢逛。","father":"要不要坐一会儿？","mother":"家里有热茶。"}[id]);greeting_next=elapsed+28
		if a.action in ["eat","tv","read","sleep"]:a.z_index=1
	var target:Vector2=player.position-Vector2(0,65)
	camera=camera.lerp(target,1-exp(-dt*7));layout_world();layout_markers()
	var distance:=76.0;near_id=""
	for h in world.cfg.hotspots+world.cfg.doors:
		var d:float=player.position.distance_to(world.nearest(World.v(h.approach)))
		if d<distance:distance=d;near_id=h.id
	near_button.text="起身" if player.action=="sit" else (str(world.spot(near_id).get("label","走近看看")))
	near_button.disabled=near_id.is_empty() and player.action!="sit"
	hint.text=note
func _unhandled_input(event:InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode==KEY_ESCAPE:
			if immersive.root:immersive.close()
			elif activities.root:activities.close()
			elif modal:close_modal()
			return
		if event.keycode==KEY_M and not busy():navigation();return
		if event.keycode==KEY_E and not busy() and not near_id.is_empty():go(near_id);return
		if event.keycode==KEY_F2 and test_panel_enabled:testing_panel();return
	if busy():return
	var at:=Vector2.ZERO;var pressed:=false
	if event is InputEventScreenTouch:at=event.position;pressed=event.pressed
	elif event is InputEventMouseButton:at=event.position;pressed=event.pressed and event.button_index==MOUSE_BUTTON_LEFT
	if not pressed:return
	var p:Vector2=world.get_global_transform_with_canvas().affine_inverse()*at
	for id in people:
		var a=people[id]
		if a.visible and Rect2(a.position-Vector2(25,48 if a.pet else 84),Vector2(50,48 if a.pet else 84)).has_point(p):go("person:"+id);get_viewport().set_input_as_handled();return
	for h in world.cfg.hotspots+world.cfg.doors:
		if p.distance_to(World.v(h.pos))<22:go(h.id);get_viewport().set_input_as_handled();return
	if player.action=="sit":stand_up()
	player.destination_action="idle";pending="";player.route=world.path(player.position,p)
	get_viewport().set_input_as_handled()
func go(id:String) -> void:
	if transition:return
	close_modal()
	if player.action=="sit":stand_up()
	var goal:Vector2
	if id.begins_with("person:"):goal=people[id.substr(7)].position+Vector2(30,12)
	else:
		var h:Dictionary=world.spot(id)
		if h.is_empty():return
		goal=World.v(h.approach)
	var route:PackedVector2Array=world.path(player.position,goal)
	if route.is_empty():note="试试沿物件旁的空地走过去。";return
	player.route=route;player.destination_action="idle";pending=id;note="慢慢走近…"
func cross(d:Dictionary) -> void:
	if transition:return
	if area=="exterior" and d.target=="living" and not admitted:knock();cooldown=2;return
	var from:=area;enter_room(d.target,true,from)
func interact(id:String) -> void:
	if id.begins_with("person:"):talk(id.substr(7));return
	var h:Dictionary=world.spot(id)
	if h.is_empty():return
	if h.has("target"):cross(h);return
	effects_log.append(area+":"+id)
	var kind:String=h.get("kind","reaction")
	if kind in ["fish","tv","stars","detail"]:
		immersive.open(kind,{"hour":hour,"month":month,"weather":weather,"room":area,"title":world.cfg.title});return
	if kind in ["guitar","puzzle","album","workbench","garden","relax"]:
		if kind=="relax":
			rest_position=player.position;player.action="sit";immersive.open("rest",{"cfg":world.cfg,"hour":hour});return
		activities.open(kind,{"month":month,"v2_art":true});return
	world.react(h);play_sound("switch")
	var fx:String=h.get("effect","spark")
	if fx=="sit":
		rest_position=player.position;player.action="sit";player.face="down"
		if area=="living":player.position=anchor("living","guest_seat")
		elif area=="dining":player.position=anchor("dining","guest_meal")
	if fx=="pet":
		for pet in ["qiuqiu","luoluo","tiantian","xiduo"]:
			if people[pet].visible:people[pet].action="idle";people[pet].say("汪！" if pet=="xiduo" else "呼噜…")
	if fx=="food":
		for cat in ["qiuqiu","luoluo","tiantian"]:
			if people[cat].visible:people[cat].route=world.path(people[cat].position,World.v(h.approach));people[cat].destination_action="sniff"
	note=str(h.get("copy",""))
	if fx=="lamp":note="灯亮起来了。" if world.lamp_on else "灯关好了，房间安静下来。"
	if note.is_empty():note="在这里慢慢待一会儿。"
	remember(area+" · "+str(h.label))
func stand_up() -> void:
	if player and player.action=="sit":player.position=world.nearest(rest_position);player.action="idle";player.route.clear()
func knock() -> void:
	play_sound("knock");player.face="up"
	if is_owner:
		phase="owner_home";dialogue("到家了","钥匙轻轻转动，家就在这里。", "",admit);return
	var hosts:=Data.at_home(hour)
	if hosts.is_empty():
		phase="absent";dialogue("轻轻敲了三下","屋里暂时没有回应。先在院子和小路逛逛吧，十点后家人陆续回来。", "",func():journal.notes.append("来拜访过");save_journal());return
	phase="invited";dialogue(NAMES[hosts[0]],"来啦，请进。家里的东西可以慢慢看看。",hosts[0],admit)
func admit() -> void:
	admitted=true;phase="inside";close_modal();enter_room("living",true,"exterior")
func talk(id:String) -> void:
	if people[id].pet:
		people[id].action="idle";people[id].say("汪！" if id=="xiduo" else "呼噜…")
		immersive.open("pet",{"pet":id,"name":NAMES[id],"hour":hour});return
	var line:=""
	match schedule(id).action:
		"eat":line="饭还热着，坐下来一起吃吧。"
		"sleep":line="嘘，家里已经安静下来了。"
		"cook":line="锅里还咕嘟着，先洗洗手。"
		"work":line="这只小木鸟快做好了，你也可以试试。"
		"computer","game":line="先把这一点做完，一会儿就去陪猫玩。"
		"guitar":line="试试这段小旋律，慢一点也没关系。"
		_:line={"ayu":"家里处处都可以慢慢看看。","father":"忙了一会儿，坐下来歇歇。","mother":"杯子里有温水，自己倒就好。"}[id]
	dialogue(NAMES[id],line,id)
func remember(copy:String) -> void:
	if not journal.found.has(copy):journal.found.append(copy);save_journal()
func complete(kind:String) -> void:journal.completed[kind]=true;save_journal()
func load_journal() -> void:
	if FileAccess.file_exists(save_path):
		var d=JSON.parse_string(FileAccess.get_file_as_string(save_path))
		if d is Dictionary:
			for k in ["found","completed","notes"]:
				if d.has(k) and typeof(d[k])==typeof(journal[k]):journal[k]=d[k]
func save_journal() -> void:
	var f:=FileAccess.open(save_path+".tmp",FileAccess.WRITE)
	if f:f.store_string(JSON.stringify(journal));f.close();DirAccess.rename_absolute(save_path+".tmp",save_path)
func play_sound(which:String) -> void:
	if not sound_on:return
	sfx.stream=Assets.sound("res://ayu_home/v2/assets/"+which+".wav");sfx.play()
func play_ambience() -> void:
	if not sound_on:amb.stop();return
	var track:="rain" if weather=="rain" else ("outdoor" if world.cfg.get("outdoor",false) else ("living" if area=="living" else "dining"))
	var file:="res://ayu_home/v2/assets/"+("yard" if track in ["rain","outdoor"] else track)+"_amb.wav"
	if not FileAccess.file_exists(file):file="res://ayu_home/v2/assets/living_amb.wav"
	amb.stream=Assets.sound(file)
	if amb.stream:amb.stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;amb.volume_db=-15;amb.play()
func make_ui() -> void:
	hud=CanvasLayer.new();hud.layer=20;add_child(hud);ui=Control.new();hud.add_child(ui);ui.theme=UI.theme();ui.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var top:=PanelContainer.new();top.name="Top";ui.add_child(top)
	var row:=HBoxContainer.new();top.add_child(row);var words:=VBoxContainer.new();words.size_flags_horizontal=Control.SIZE_EXPAND_FILL;words.add_theme_constant_override("separation",2);row.add_child(words)
	title=UI.label("阿鱼家",21);words.add_child(title);time_label=UI.label("",16);words.add_child(time_label)
	row.add_child(UI.button("地图",navigation));row.add_child(UI.button("♪",func():sound_on=not sound_on;play_ambience()))
	markers=Control.new();markers.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(markers)
	var bottom:=VBoxContainer.new();bottom.name="Bottom";ui.add_child(bottom)
	hint=UI.label(note,17);hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;hint.custom_minimum_size.y=40;hint.add_theme_stylebox_override("normal",UI.box(Color("fff1d3")));bottom.add_child(hint)
	toolbar=HBoxContainer.new();bottom.add_child(toolbar)
	near_button=UI.button("走近看看",func():
		if player.action=="sit":stand_up()
		elif not near_id.is_empty():go(near_id))
	near_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;toolbar.add_child(near_button)
	toolbar.add_child(UI.button("细看",detail_view))
	if test_panel_enabled:toolbar.add_child(UI.button("试玩",testing_panel))
	else:toolbar.add_child(UI.button("生活册",life_book))
	fade=ColorRect.new();fade.mouse_filter=Control.MOUSE_FILTER_IGNORE;fade.color=Color(0,0,0,0);ui.add_child(fade)
func layout() -> void:
	if not ui:return
	var size:=get_viewport_rect().size;ui.size=size;ui_scale=size.x/540.0
	var top=ui.get_node("Top");top.position=Vector2(12,14);top.size=Vector2(size.x-24,74)
	var bottom=ui.get_node("Bottom");bottom.position=Vector2(12,size.y-114);bottom.size=Vector2(size.x-24,102)
	fade.size=size;markers.size=size;layout_world()
func layout_world() -> void:
	if not world or world.cfg.is_empty():return
	var screen:=get_viewport_rect().size;scene_frame.position=Vector2.ZERO;scene_frame.size=screen
	var size:Vector2=World.v(world.cfg.size)
	view_scale=2.0
	if world.cfg.get("outdoor",false):view_scale=maxf(1.45,maxf(screen.x/size.x,screen.y/size.y))
	else:view_scale=maxf(2.0,maxf(screen.x/size.x,screen.y/size.y))
	var visible_world:=screen/view_scale
	var center:=camera.clamp(visible_world*.5,size-visible_world*.5)
	world.scale=Vector2.ONE*view_scale;world.position=(screen*.5-center*view_scale).round();world.camera_center=center
func make_markers() -> void:
	for n in markers.get_children():n.queue_free()
	marker_nodes.clear()
	for h in world.cfg.hotspots+world.cfg.doors:
		var b:=Button.new();b.flat=true;b.custom_minimum_size=Vector2(48,54);b.size=Vector2(48,54);b.tooltip_text=h.label;b.focus_mode=Control.FOCUS_NONE
		var bubble:=UI.Bubble.new();bubble.size=b.size;b.add_child(bubble)
		bubble.icon="door" if h.has("target") else str(h.get("kind","detail"))
		if bubble.icon=="reaction":bubble.icon={"steam":"tea","water":"water","wash":"water","lamp":"lamp","open":"open","fold":"fold","tools":"tools","pet":"pet","food":"pet","sit":"relax","bunny":"pet","book":"album"}.get(str(h.get("effect","")),"detail")
		b.pressed.connect(go.bind(h.id));markers.add_child(b);marker_nodes.append({"button":b,"bubble":bubble,"hot":h})
func layout_markers() -> void:
	if not markers:return
	var size:=get_viewport_rect().size;var used:Array[Rect2]=[]
	for m in marker_nodes:
		var h:Dictionary=m.hot;var b:Button=m.button
		var raw:Vector2=world.get_global_transform_with_canvas()*World.v(h.pos)
		var p:=raw-Vector2(24,61)+Vector2(0,round(sin(elapsed*2+float(h.pos[0]))*2))
		b.visible=modal==null and activities.root==null and immersive.root==null and raw.x>4 and raw.x<size.x-4 and raw.y>110 and raw.y<size.y-140
		if not b.visible:continue
		p=p.clamp(Vector2(6,95),size-Vector2(54,178))
		for other in used:
			if other.intersects(Rect2(p,b.size)):p.y=other.position.y-57
		b.position=p;used.append(Rect2(p,b.size));m.bubble.selected=near_id==h.id;m.bubble.queue_redraw()
func close_modal() -> void:
	if modal:modal.queue_free();modal=null
	talk_label=null;talk_next=Callable();cooldown=.8
func modal_shell(heading:String) -> VBoxContainer:
	close_modal();modal=Control.new();modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);ui.add_child(modal)
	var shade:=ColorRect.new();shade.color=Color(.16,.1,.06,.65);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);modal.add_child(shade)
	var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right"]:margin.add_theme_constant_override("margin_"+side,18)
	for side in ["top","bottom"]:margin.add_theme_constant_override("margin_"+side,50)
	modal.add_child(margin);var panel:=PanelContainer.new();margin.add_child(panel);var box:=VBoxContainer.new();panel.add_child(box)
	var row:=HBoxContainer.new();box.add_child(row);var label:=UI.label(heading,25);label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(label);var close:=UI.button("收起",close_modal);row.add_child(close);close.grab_focus()
	return box
func dialogue(who:String,line:String,portrait:="",next:Callable=Callable()) -> void:
	close_modal();modal=Control.new();modal.mouse_filter=Control.MOUSE_FILTER_IGNORE;modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);ui.add_child(modal)
	var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);margin.offset_top=-236;margin.offset_bottom=-20;margin.offset_left=12;margin.offset_right=-12;modal.add_child(margin)
	var panel:=PanelContainer.new();margin.add_child(panel);var row:=HBoxContainer.new();panel.add_child(row)
	if not portrait.is_empty():
		var image:=TextureRect.new();image.custom_minimum_size=Vector2(104,155);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var tex:Texture2D=Assets.texture("res://ayu_home/v2/assets/portrait_"+portrait+".png");var crop:=AtlasTexture.new();crop.atlas=tex;crop.region=Rect2(0,0,tex.get_width(),tex.get_height()*.57);image.texture=crop;row.add_child(image)
	var words:=VBoxContainer.new();words.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(words);words.add_child(UI.label(who,24));talk_label=UI.label(line,21);talk_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;talk_label.size_flags_vertical=Control.SIZE_EXPAND_FILL;words.add_child(talk_label)
	talk_line=line;talk_chars=0;talk_next=next;talk_label.visible_characters=0
	var buttons:=HBoxContainer.new();words.add_child(buttons);var next_button:=UI.button("继续 ▸",advance_dialogue);next_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;buttons.add_child(next_button);buttons.add_child(UI.button("跳过",finish_dialogue));next_button.grab_focus()
	panel.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:advance_dialogue())
func advance_dialogue() -> void:
	if talk_chars<talk_line.length():talk_chars=talk_line.length();return
	finish_dialogue()
func finish_dialogue() -> void:
	var cb:=talk_next;close_modal()
	if cb.is_valid():cb.call()
func navigation(group:="") -> void:
	if not group.is_empty():map_group=group
	var box:=modal_shell("家的地图")
	var tabs:=HBoxContainer.new();box.add_child(tabs)
	for tab in ["一楼","二楼","屋外"]:
		var b:=UI.button(tab,navigation.bind(tab));b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;tabs.add_child(b)
	var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;box.add_child(scroll)
	var grid:=GridContainer.new();grid.columns=3;grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;grid.add_theme_constant_override("h_separation",8);grid.add_theme_constant_override("v_separation",8);scroll.add_child(grid)
	for id in definitions:
		var cfg:Dictionary=definitions[id]
		if cfg.group!=map_group:continue
		var card:=VBoxContainer.new();card.size_flags_horizontal=Control.SIZE_EXPAND_FILL;grid.add_child(card)
		var b:=UI.button("",func():admitted=true;close_modal();enter_room(id));b.custom_minimum_size=Vector2(132,92);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;b.expand_icon=true;b.icon=Assets.texture(P+"thumb_"+id+".png");card.add_child(b)
		var label:=UI.label(str(cfg.title).replace("后花园 · 果园 · 菜地","花园 / 果园 / 菜地"),16);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;card.add_child(label)
	box.add_child(UI.label("点房间就到门口 · M 打开地图",16))
func testing_panel() -> void:
	if not test_panel_enabled:return
	var box:=modal_shell("电脑试玩 · 时光与天气")
	box.add_child(UI.label("选完马上看变化，关闭面板继续走。",18))
	for group in ["时段","季节","天气"]:
		box.add_child(UI.label(group,23));var grid:=GridContainer.new();grid.columns=2;box.add_child(grid)
		var labels:Array;var values:Array
		if group=="时段":labels=["清晨 06:30","午间 12:15","傍晚 18:30","深夜 23:00"];values=[6.5,12.25,18.5,23.0]
		elif group=="季节":labels=["春 · 三月","夏 · 七月","秋 · 十月","冬 · 一月"];values=[3,7,10,1]
		else:labels=["晴天","雨天"];values=["clear","rain"]
		for i in labels.size():
			var val=values[i];var b:=UI.button(labels[i],func():set_test_clock(float(val) if group=="时段" else hour,int(val) if group=="季节" else month,str(val) if group=="天气" else weather);close_modal());b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;grid.add_child(b)
	var row:=HBoxContainer.new();box.add_child(row)
	row.add_child(UI.button("现实时间",func():test_hour=-1;test_month=0;test_weather="";read_clock();sync_family(true);close_modal()))
	row.add_child(UI.button("生活册",life_book))
	var absences:=HBoxContainer.new();box.add_child(absences)
	for item in [["全家外出",9.5],["爸爸外出",10.5],["妈妈外出",14.5]]:absences.add_child(UI.button(item[0],func():set_test_clock(item[1],month,weather);close_modal()))
func life_book() -> void:
	var box:=modal_shell("生活册")
	var sc:=ScrollContainer.new();sc.size_flags_vertical=Control.SIZE_EXPAND_FILL;box.add_child(sc)
	var copy:="去过 %d 处 · 玩完 %d 样\n\n"%[room_history.size(),journal.completed.size()]+"\n".join(journal.found)+"\n\n"+Data.schedule_text().replace("写作业","电脑工作").replace("麻将小聚","喝茶聊天")
	var text:=UI.label(copy,19);text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;text.size_flags_horizontal=Control.SIZE_EXPAND_FILL;sc.add_child(text)
func detail_view() -> void:
	immersive.open("detail" if area=="study" else "room_detail",{"room":area,"title":world.cfg.title,"hour":hour,"month":month,"weather":weather,"cfg":world.cfg})
func stop_audio() -> void:
	for a in [amb,sfx]:
		if a:a.stop();a.stream=null
func _exit_tree() -> void:stop_audio()
