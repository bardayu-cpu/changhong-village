extends Node2D
const Assets = preload("res://ayu_home/v2/assets.gd")
const World = preload("res://ayu_home/v2/world.gd")
const Actor = preload("res://ayu_home/v2/actor.gd")
const LegacyData = preload("res://ayu_home/home_data.gd")
const Activities = preload("res://ayu_home/activities.gd")
const FONT = preload("res://assets/fonts/fusion-pixel-12px-proportional-zh_hans.otf.woff2")
const NAMES := {"ayu":"阿鱼","father":"爸爸","mother":"妈妈","qiuqiu":"求求","luoluo":"落落","tiantian":"天天","xiduo":"喜多"}
const TITLES := {"exterior":"阿鱼家 · 门前院子","living":"阿鱼家 · 客厅","dining":"阿鱼家 · 餐厅"}
var world
var scene_frame: Control
var definitions: Dictionary = {}
var player
var people: Dictionary = {}
var area := "exterior"
var hour := 12.0
var month := 10
var day := 4
var weather := "clear"
var test_hour := -1.0
var test_month := 0
var test_weather := ""
var is_owner := false
var admitted := false
var phase := "outside"
var pending := ""
var transition := false
var camera := Vector2.ZERO
var view_scale := 1.35
var ui_scale := 1.0
var hud: CanvasLayer
var ui: Control
var title: Label
var time_label: Label
var hint: Label
var near_button: Button
var sound_button: Button
var modal: Control
var fade: ColorRect
var amb: AudioStreamPlayer
var sfx: AudioStreamPlayer
var sound_on := true
var activities
var save_path := "user://ayu_home_life_v2.json"
var journal: Dictionary = {"version":2,"notes":[],"found":[],"completed":{}}
var elapsed := 0.0
var clock_poll := 0.0
var last_slot := ""
var note := "点地面走动，走近门口敲门。"
var near_id := ""
var bootstrapped := false
var rest_position := Vector2.ZERO
var greeting_log: Array = []
var next_greeting:=0.0
var transition_count := 0
var door_audio_count := 0
var room_history: Array = []
var focus := ""

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ayu-hour="):test_hour = float(arg.get_slice("=",1))
		elif arg.begins_with("--ayu-month="):test_month = int(arg.get_slice("=",1))
		elif arg.begins_with("--ayu-weather="):test_weather = arg.get_slice("=",1)
		elif arg.begins_with("--ayu-area="):area = arg.get_slice("=",1)
		elif arg.begins_with("--ayu-save="):save_path = arg.substr(11)
		elif arg.begins_with("--ayu-focus="):focus = arg.get_slice("=",1)
		elif arg=="--ayu-owner=true" and OS.is_debug_build():is_owner = true
	if area not in TITLES:area = "exterior"
	admitted = area!="exterior"
	load_journal();read_clock()
	for room in TITLES:definitions[room]=JSON.parse_string(FileAccess.get_file_as_string("res://ayu_home/v2/assets/"+room+".json"))
	scene_frame=Control.new();scene_frame.clip_contents=true;scene_frame.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(scene_frame)
	world = World.new();scene_frame.add_child(world)
	amb = AudioStreamPlayer.new();add_child(amb)
	sfx = AudioStreamPlayer.new();add_child(sfx)
	make_ui()
	activities = Activities.new();add_child(activities)
	activities.closed.connect(func():note="随时可以再回来玩。")
	activities.completed.connect(func(kind: String):journal.completed[kind]=true;save_journal())
	enter_room(area,false)
	if not focus.is_empty():
		var h: Dictionary = world.spot(focus)
		if not h.is_empty():player.position = world.nearest(World.v(h.approach));camera=player.position-Vector2(0,float(world.cfg.get("camera_ahead",80)));layout()
	get_viewport().size_changed.connect(layout)
	bootstrapped = true

func read_clock() -> void:
	var was_night:=hour<6 or hour>=22
	var now := Time.get_datetime_dict_from_system()
	hour = test_hour if test_hour>=0 else float(now.hour)+float(now.minute)/60+float(now.second)/3600
	month = test_month if test_month>0 else int(now.month)
	day = int(now.day)
	# Deterministic fictional weather; the product does not claim live meteorological data.
	weather = test_weather if not test_weather.is_empty() else ("rain" if (day+month)%4==0 else "clear")
	if world:
		world.hour=hour;world.month=month;world.weather=weather
		var is_night:=hour<6 or hour>=22
		if was_night!=is_night:
			world.tv_on=not is_night
			if amb:play_ambience()
func set_test_clock(h: float,m:=10,w:="clear") -> void:
	test_hour=h;test_month=m;test_weather=w;read_clock();sync_family(true)
func set_identity(owner_mode: bool) -> void:
	is_owner=owner_mode
	# Production caller supplies authenticated ownership; no in-game identity toggle.
	if player:
		var p: Vector2=player.position;player.queue_free();player=Actor.new();world.actors.add_child(player);player.setup("ayu" if is_owner else "visitor");player.position=p
	sync_family(true)
func anchor(room: String,id: String) -> Vector2:
	return World.v(definitions[room].anchors[id])

func schedule(id: String) -> Dictionary:
	var old: Dictionary = LegacyData.state(id,hour)
	var st := {"area":"offstage","action":old.action,"pos":Vector2.ZERO,"face":old.face}
	if old.action=="away":st.area="away";return st
	if old.action=="eat":
		st.area="dining";st.pos=anchor("dining",id+"_meal");st.face={"father":"right","mother":"left","ayu":"up"}[id];return st
	if old.action in ["fish","clean"] and id=="ayu":st.area="living";st.pos=anchor("living",old.action);st.face="left" if old.action=="fish" else "down"
	elif old.action=="cook":st.area="dining";st.pos=anchor("dining","cook");st.face="left"
	elif hour>=8.25 and hour<9:
		st.area="dining";st.pos=anchor("dining","clean");st.face="up"
	elif old.action in ["tv","read","record"] and old.area=="floor1":
		st.area="living";st.action="tv" if old.action=="tv" else "read";st.pos=anchor("living",id+"_seat");st.face="right"
	elif hour>=10 and hour<11 and id=="mother":st.area="dining";st.action="read";st.pos=anchor("dining","mother_read");st.face="left"
	elif hour>=13 and hour<14 and id in ["father","mother"]:
		st.area="dining";st.action="read";st.pos=anchor("dining",id+"_read");st.face="right" if id=="father" else "left"
	elif hour>=14 and hour<15 and id=="father":st.area="exterior";st.action="work";st.pos=anchor("exterior","work");st.face="up"
	elif hour>=19 and hour<20 and id=="father":st.area="living";st.action="read";st.pos=anchor("living","father_seat");st.face="right"
	return st

func enter_room(which: String,with_transition:=true) -> void:
	if which!="exterior" and not admitted:return
	area=which;pending="";people.clear();world.load_room(area);world.hour=hour;world.month=month;world.weather=weather
	if hour>=22 or hour<6:world.tv_on=false
	player=Actor.new();world.actors.add_child(player);player.setup("ayu" if is_owner else "visitor");player.position=world.spawn()
	for id in NAMES:
		var actor:=Actor.new();world.actors.add_child(actor);actor.setup(id);people[id]=actor
	sync_family(true)
	camera=player.position-Vector2(0,float(world.cfg.get("camera_ahead",80)));world.parallax_origin=camera
	room_history.append(area)
	title.text=TITLES[area]
	note={"exterior":"先敲门，再进去看看。喜多在院子里。","living":"鱼缸在北侧，沙发朝着电视。","dining":"圆桌旁留着一个空位。"}[area]
	play_ambience();layout()
	if with_transition:
		transition_count+=1;door_audio_count+=1;play_sound("door");transition=true;fade.color=Color(0.07,0.07,0.11,.92)
		var tween:=create_tween();tween.tween_property(fade,"color:a",0,.65);tween.finished.connect(func():transition=false)

func sync_family(force:=false) -> void:
	if not world or people.is_empty():return
	for id in LegacyData.FAMILY:
		var st:=schedule(id);var a=people[id];var shown:bool=st.area==area and not (id=="ayu" and is_owner)
		if not shown and a.visible and not force:
			# Leave by the same doorway; remove only on reaching its approach.
			if not a.has_meta("departing"):
				a.set_meta("departing",true);a.route=world.path(a.position,world.spawn());a.destination_action="idle"
			continue
		a.remove_meta("departing")
		a.visible=shown
		if shown:
			a.destination_action=st.action;a.destination_face=st.face;a.target=st.pos
			if force:a.position=st.pos;a.action=st.action;a.face=st.face;a.route.clear()
			elif a.position.distance_to(st.pos)>4:a.route=world.path(a.position,st.pos)
	var spots:Dictionary={}
	if area=="exterior":spots={"xiduo":anchor("exterior","dog")}
	elif area=="living":
		var cats:=["qiuqiu","luoluo","tiantian"]
		for i in 3:spots[cats[i]]=anchor("living",cats[(i+day+month)%3]+("_evening" if hour>=20 and hour<21 else ""))
	elif area=="dining":spots={"qiuqiu":anchor("dining","qiuqiu")}
	for id in ["qiuqiu","luoluo","tiantian","xiduo"]:
		var a=people[id];a.visible=spots.has(id)
		if a.visible and force:a.position=spots[id];a.action="sniff" if id=="xiduo" else "lie";a.cooldown=8+float(id.length())

func _process(dt: float) -> void:
	if not bootstrapped:return
	elapsed+=dt;clock_poll+=dt
	if clock_poll>=1:
		clock_poll=0;read_clock()
		var slot:=str(int(hour*12))
		if slot!=last_slot:last_slot=slot;sync_family(false)
	if not transition and modal==null and activities.root==null:
		player.move_along(dt,145)
		var axis:=Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
		if axis.length()>0:
			if player.action=="sit":stand_up()
			player.route.clear();pending="";var pos:Vector2=player.position+axis.normalized()*dt*145
			if world.walkable(pos):player.position=pos;player.walking=true;player.face="right" if axis.x>0 else ("left" if axis.x<0 else ("down" if axis.y>0 else "up"))
		if not pending.is_empty() and player.route.is_empty():
			var id:=pending;pending="";interact(id)
	for id in people:
		var a=people[id]
		if not a.visible:continue
		a.move_along(dt,48 if a.pet else 76)
		if a.pet:a.z_index=1 if a.action=="lie" and not a.walking else 0
		else:a.z_index=1 if area=="living" and a.action in ["tv","read","record"] and not a.walking else 0
		if a.has_meta("departing") and a.route.is_empty():a.visible=false;a.remove_meta("departing");continue
		if not a.pet and a.route.is_empty() and a.position.distance_to(a.target)<20:a.position=a.position.move_toward(a.target,dt*80)
		if a.pet and a.route.is_empty() and a.cooldown<=0:
			var roam:Vector2=a.position+Vector2(sin(elapsed+id.length())*65,cos(elapsed*.7+id.length())*28)
			if area=="exterior":
				var r:Array=world.cfg.dog_roam;roam=Vector2(clampf(roam.x,r[0],r[0]+r[2]),clampf(roam.y,r[1],r[1]+r[3]))
			a.route=world.path(a.position,roam);a.destination_action="sniff" if id=="xiduo" else "lie";a.destination_face="left";a.cooldown=18+id.length()
		if not a.pet and a.cooldown<=0 and elapsed>=next_greeting and a.position.distance_to(player.position)<100 and modal==null:
			a.say({"ayu":"来啦，坐一会儿。","father":"慢慢走，不着急。","mother":"饿了就来餐桌边。"}[id]);a.cooldown=30;greeting_log.append(id);next_greeting=elapsed+8;note=NAMES[id]+"："+a.bubble.text
	player.z_index=1 if player.action=="sit" else 0
	var target:Vector2=player.position-Vector2(0,float(world.cfg.get("camera_ahead",80)))
	camera=camera.lerp(target,1-exp(-dt*5));layout_world();layout_bubbles()
	var closest:Dictionary={};var distance:=92.0
	for h in world.cfg.hotspots:
		var d:float=player.position.distance_to(World.v(h.approach))
		if d<distance:distance=d;closest=h
	near_id=str(closest.get("id",""));near_button.text="起身" if player.action=="sit" else str(closest.get("label","走近物件看看"));near_button.disabled=near_id.is_empty() and player.action!="sit"
	time_label.text="%02d:%02d · %s · %s"%[int(hour),int(hour*60)%60,LegacyData.SEASONS[LegacyData.season(month)],"雨" if weather=="rain" else "晴"]
	hint.text=note

func layout_bubbles() -> void:
	var bounds:=Rect2(-world.position/view_scale,scene_frame.size/view_scale).grow(-4)
	for a in people.values():
		if not a.visible or not a.bubble.visible:continue
		var extent:Vector2=a.bubble.get_combined_minimum_size()
		var selected:=Vector2.ZERO;var best:=INF
		for shift in [Vector2(-72,-130),Vector2(35,-132),Vector2(-180,-132),Vector2(-72,-175),Vector2(35,-75),Vector2(-180,-75)]:
			var p:Vector2=a.position+shift
			p=p.clamp(bounds.position,bounds.end-extent)
			var rect:=Rect2(p,extent);var overlap:=0.0
			var all_people:Array=people.values()+[player]
			for other in all_people:
				if other.visible:overlap+=rect.intersection(Rect2(other.position-Vector2(23,84 if not other.pet else 34),Vector2(46,84 if not other.pet else 34))).get_area()
			if overlap<best:best=overlap;selected=p-a.position
		if best>0:a.bubble.visible=false
		else:a.bubble.position=selected

func _unhandled_input(event: InputEvent) -> void:
	if transition or modal!=null or activities.root!=null:return
	var at:=Vector2.ZERO;var pressed:=false
	if event is InputEventScreenTouch:at=event.position;pressed=event.pressed
	elif event is InputEventMouseButton:at=event.position;pressed=event.pressed and event.button_index==MOUSE_BUTTON_LEFT
	if not pressed:return
	if at.y<80*ui_scale or at.y>get_viewport_rect().size.y-118*ui_scale:return
	var p:Vector2=world.get_global_transform_with_canvas().affine_inverse()*at
	for id in people:
		var a=people[id]
		if a.visible and Rect2(a.position-Vector2(24,84 if not a.pet else 38),Vector2(48,84 if not a.pet else 38)).has_point(p):
			go("person:"+id);get_viewport().set_input_as_handled();return
	for h in world.cfg.hotspots:
		if p.distance_to(World.v(h.pos))<34:go(h.id);get_viewport().set_input_as_handled();return
	if player.action=="sit":stand_up()
	pending="";player.destination_action="idle";player.route=world.path(player.position,p);get_viewport().set_input_as_handled()

func go(id: String) -> void:
	if transition:return
	close_modal()
	if player.action=="sit":stand_up()
	var target:Vector2
	if id.begins_with("person:"):target=people[id.substr(7)].position+Vector2(36,20)
	else:
		var h:Dictionary=world.spot(id)
		if h.is_empty():return
		target=World.v(h.approach)
	var route:PackedVector2Array=world.path(player.position,target)
	if route.is_empty():note="这里暂时走不过去，换一侧试试。";return
	player.route=route;player.destination_action="idle";pending=id;note="慢慢走近…"

func interact(id: String) -> void:
	if id.begins_with("person:"):talk(id.substr(7));return
	match id:
		"door":knock()
		"dining":enter_room("dining")
		"living":enter_room("living")
		"exit":enter_room("exterior")
		"gate":show_panel("院门","要回到镇上吗？",[["继续逛院子",close_modal],["回到镇上",func():save_journal();get_tree().root.set_meta("ayu_home_skip",true);get_tree().change_scene_to_file("res://main.tscn")]])
		"xiduo":people.xiduo.say("汪！");people.xiduo.action="sniff";note="喜多摇摇尾巴，又在自己的院子里闻了闻。"
		"bench":rest_position=player.position;player.position=anchor("exterior","bench");player.action="sit";player.face="down";note="坐在门前台阶上，听一会儿小溪。"
		"sofa":
			rest_position=player.position;player.position=anchor("living","guest_seat");player.action="sit";player.face="down";note="坐在原来的沙发上，歇一会儿。"
		"meal":rest_position=player.position;player.position=anchor("dining","guest_meal");player.action="sit";player.face="down";note="坐在空位上。三餐时，一家人都会回来吃饭。"
		"fish":world.food_until=world.elapsed+6;player.action="fish";note="撒下一小撮鱼食，小鱼游过来，水里冒着细泡。";remember("鱼缸边的一点安静")
		"tv":world.tv_on=not world.tv_on;note="电视轻轻响了起来。" if world.tv_on else "电视关上了，屋里安静下来。";play_ambience()
		"lamp":world.lamp_on=not world.lamp_on;play_sound("switch");note="灯打开了。" if world.lamp_on else "灯关上了。"
		"album":show_panel("茶几上的相册","这一页是阿鱼家原图里的院子。旁边的题字留空，等阿鱼亲手写。",[["修复这一页",func():close_modal();activities.open("album",{"month":month,"v2_art":true})],["合上相册",close_modal]])
		"recipe":
			remember("一张叶脉书签")
			show_panel("食谱里的一片叶子","翻页时掉出一片叶脉书签，已收进生活册。今天的菜单："+["青菜豆腐汤","番茄炒蛋","南瓜杂粮粥","萝卜菌菇汤"][LegacyData.season(month)]+"。",[["拼一幅小院图",func():close_modal();activities.open("puzzle",{"month":month,"v2_art":true})],["夹好书签",close_modal]])
		"cook":people.mother.say("汤还热着呢。") if people.mother.visible else pass_noop();note="厨房门边传来细细热气。"+["嫩豌豆是春天的颜色。","今天有番茄。","今天炖南瓜。","今天是萝卜菌菇汤。"][LegacyData.season(month)]
		"tea":play_sound("switch");note="拿起水壶倒一杯温水，又把杯子轻轻放好。";remember("餐桌边的一杯温水")
		"flowers":show_panel("院子里的花",LegacyData.SEASON_COPY[LegacyData.season(month)],[["收起一片落叶",func():remember("院前的"+LegacyData.SEASONS[LegacyData.season(month)]+"日叶片");close_modal();note="夹进生活册里了。"],["继续散步",close_modal]])
func pass_noop() -> void:pass
func stand_up() -> void:
	player.position=world.nearest(rest_position);player.action="idle";player.route.clear();note="起来活动活动。"

func knock() -> void:
	play_sound("knock");player.face="up"
	if is_owner:
		phase="owner_home";show_panel("到家了","钥匙轻轻一转，家里的灯在等你。",[["开门回家",admit],["再逛逛院子",close_modal]]);return
	var hosts:=LegacyData.at_home(hour)
	if hosts.is_empty():
		phase="absent";show_panel("轻轻敲了三下","屋里暂时没有回应。一家人 10:00 后陆续回来，午饭时都会在。喜多在院子里陪你。",[["留一张来访便笺",func():
			if not journal.notes.has("来拜访过"):journal.notes.append("来拜访过");save_journal()
			close_modal();note="便笺放好了，下次再来。"],["在院子等一会儿",close_modal]]);return
	phase="answering";note="屋里有脚步声，稍等一下…";transition=true
	await get_tree().create_timer(.8).timeout
	transition=false;phase="invited"
	var host:String=hosts[0]
	show_panel(NAMES[host],"来啦，请进。" if hour>=6 and hour<22 else "这么晚啦，轻一点，进来歇歇。",[["进屋",admit],["一会儿再进",close_modal]],host)
func admit() -> void:
	if phase not in ["invited","owner_home"]:return
	admitted=true;phase="inside";close_modal();enter_room("living")
func talk(id: String) -> void:
	if people[id].pet:people[id].say("喵。" if id!="xiduo" else "汪！");people[id].cooldown=0;note="它抬起头，换个地方继续歇着。";return
	var line: String={"ayu":"来啦。喂喂鱼、翻翻相册，都可以。","father":"手里的小活做完了，正好歇会儿。","mother":"坐吧，给你倒杯温水。"}[id]
	if schedule(id).action=="eat":line="饭正热着，一起坐坐。"
	people[id].say(line)
	show_panel(NAMES[id],line,[["看看身份卡",func():show_panel(NAMES[id],"一家人的日常 · "+{"ayu":"长黑发、白 T、黑裤、红绳。","father":"蓝色 POLO、深色长裤。","mother":"粉色开衫、米白上衣、藏青裙。"}[id],[["收起",close_modal]],id,true)],["继续逛逛",close_modal]],id)

func play_ambience() -> void:
	amb.stop()
	if not sound_on:return
	if area=="living" and not world.tv_on:return
	var name:String={"exterior":"yard_amb","living":"living_amb","dining":"dining_amb"}[area]
	var stream:AudioStreamWAV=Assets.sound("res://ayu_home/v2/assets/"+name+".wav")
	stream=stream.duplicate();stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;stream.loop_end=int(stream.mix_rate*4)
	amb.stream=stream;amb.volume_db=-8 if hour>=22 or hour<6 else -3;amb.play()
func play_sound(name: String) -> void:
	if not sound_on:return
	sfx.stream=Assets.sound("res://ayu_home/v2/assets/"+name+".wav");sfx.play()
func remember(item: String) -> void:
	if not journal.found.has(item):journal.found.append(item);save_journal()
func load_journal() -> void:
	if FileAccess.file_exists(save_path):
		var data=JSON.parse_string(FileAccess.get_file_as_string(save_path))
		if data is Dictionary:
			for key in ["notes","found","completed"]:
				if data.has(key) and typeof(data[key])==typeof(journal[key]):journal[key]=data[key]
func save_journal() -> void:
	var f:=FileAccess.open(save_path+".tmp",FileAccess.WRITE)
	if f:f.store_string(JSON.stringify(journal));f.close();DirAccess.rename_absolute(save_path+".tmp",save_path)

func style(c: Color) -> StyleBoxFlat:
	var box:=StyleBoxFlat.new();box.bg_color=c;box.border_color=Color("8c7751");box.set_border_width_all(2);box.set_corner_radius_all(5);box.content_margin_left=12;box.content_margin_right=12;box.content_margin_top=9;box.content_margin_bottom=9;return box
func label(text: String,size:=20) -> Label:
	var l:=Label.new();l.text=text;l.add_theme_font_override("font",FONT);l.add_theme_font_size_override("font_size",int(size*ui_scale));l.add_theme_color_override("font_color",Color("4a3b2e"));return l
func button(text: String,callback: Callable) -> Button:
	var b:=Button.new();b.text=text;b.custom_minimum_size=Vector2(0,50)*ui_scale;b.add_theme_font_override("font",FONT);b.add_theme_font_size_override("font_size",int(20*ui_scale));b.add_theme_color_override("font_color",Color("4a3b2e"));b.add_theme_stylebox_override("normal",style(Color("f0e3c8")));b.add_theme_stylebox_override("pressed",style(Color("c9d0a0")));b.add_theme_stylebox_override("hover",style(Color("f8eacb")));b.pressed.connect(callback);return b
func make_ui() -> void:
	ui_scale=get_viewport_rect().size.x/540.0
	hud=CanvasLayer.new();hud.layer=20;add_child(hud)
	ui=Control.new();ui.mouse_filter=Control.MOUSE_FILTER_IGNORE;hud.add_child(ui)
	var top:=Panel.new();top.name="Top";top.add_theme_stylebox_override("panel",style(Color("f0e3c8")));ui.add_child(top)
	title=label("阿鱼家",22);top.add_child(title);time_label=label("",16);top.add_child(time_label)
	sound_button=button("声音",func():sound_on=not sound_on;sound_button.text="声音" if sound_on else "静音";play_ambience());top.add_child(sound_button)
	var bottom:=Panel.new();bottom.name="Bottom";bottom.add_theme_stylebox_override("panel",style(Color("f0e3c8")));ui.add_child(bottom)
	hint=label("",17);hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;bottom.add_child(hint)
	var row:=HBoxContainer.new();row.name="Row";row.add_theme_constant_override("separation",8);bottom.add_child(row)
	near_button=button("走近看看",func():
		if player.action=="sit":stand_up()
		elif not near_id.is_empty():go(near_id))
	near_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(near_button)
	row.add_child(button("看看屋里",navigation));row.add_child(button("生活册",life_book))
	fade=ColorRect.new();fade.color=Color(0,0,0,0);fade.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(fade)
func layout() -> void:
	if not ui:return
	var size:=get_viewport_rect().size;ui.size=size;ui_scale=size.x/540.0
	var top=ui.get_node("Top");top.position=Vector2(10,8)*ui_scale;top.size=Vector2(520,65)*ui_scale
	title.position=Vector2(12,7)*ui_scale;time_label.position=Vector2(12,37)*ui_scale;sound_button.position=Vector2(430,6)*ui_scale;sound_button.size=Vector2(77,50)*ui_scale
	var bottom=ui.get_node("Bottom");bottom.position=Vector2(10*ui_scale,size.y-111*ui_scale);bottom.size=Vector2(520,101)*ui_scale
	hint.position=Vector2(12,5)*ui_scale;hint.size=Vector2(496,42)*ui_scale;var row=bottom.get_node("Row");row.position=Vector2(10,47)*ui_scale;row.size=Vector2(500,50)*ui_scale
	fade.size=size;layout_world()
func layout_world() -> void:
	if not world or world.cfg.is_empty():return
	var screen:=get_viewport_rect().size
	scene_frame.position=Vector2(0,80*ui_scale)
	scene_frame.size=Vector2(screen.x,screen.y-198*ui_scale)
	var size:=scene_frame.size
	var full:=World.v(world.cfg.size)
	view_scale=maxf(size.x/full.x,size.y/float(world.cfg.get("phone_world_height",full.y)))
	var visible_world:=size/view_scale
	var center:=Vector2(clampf(camera.x,visible_world.x/2,full.x-visible_world.x/2),clampf(camera.y,visible_world.y/2,full.y-visible_world.y/2))
	world.scale=Vector2.ONE*view_scale;world.position=(size/2-center*view_scale).round();world.camera_center=center
func close_modal() -> void:
	if modal:modal.queue_free();modal=null
func show_panel(heading: String,copy: String,options: Array,portrait:="",full_body:=false) -> void:
	close_modal()
	modal=Control.new();modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);ui.add_child(modal)
	var shade:=ColorRect.new();shade.color=Color(.09,.08,.10,.46);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);modal.add_child(shade)
	var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right"]:margin.add_theme_constant_override("margin_"+side,int(22*ui_scale))
	margin.add_theme_constant_override("margin_top",int(180*ui_scale));margin.add_theme_constant_override("margin_bottom",int(130*ui_scale));modal.add_child(margin)
	var panel:=PanelContainer.new();panel.add_theme_stylebox_override("panel",style(Color("f5e9ce")));margin.add_child(panel)
	var box:=VBoxContainer.new();box.add_theme_constant_override("separation",int(14*ui_scale));panel.add_child(box)
	box.add_child(label(heading,26))
	var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;box.add_child(scroll)
	var content:=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(content)
	if not portrait.is_empty():
		var tex:Texture2D=Assets.texture("res://ayu_home/v2/assets/portrait_"+portrait+".png")
		var row:=HBoxContainer.new();content.add_child(row)
		var image:=TextureRect.new();image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;image.custom_minimum_size=Vector2(145,250 if full_body else 180)*ui_scale
		if full_body:image.texture=tex
		else:
			var crop:=AtlasTexture.new();crop.atlas=tex;crop.region=Rect2(0,0,tex.get_width(),tex.get_height()*.54);image.texture=crop
		row.add_child(image);var words:=label(copy,20);words.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;words.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(words)
	else:
		var words:=label(copy,20);words.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;content.add_child(words)
	var choices:Container=GridContainer.new() if options.size()>4 else VBoxContainer.new()
	if choices is GridContainer:choices.columns=2
	choices.add_theme_constant_override("h_separation",8);choices.add_theme_constant_override("v_separation",8);box.add_child(choices)
	for item in options:
		var choice:=button(item[0],item[1]);choice.size_flags_horizontal=Control.SIZE_EXPAND_FILL;choices.add_child(choice)
func navigation() -> void:
	var options:=[]
	for h in world.cfg.hotspots:options.append([h.label,go.bind(h.id)])
	options.append(["继续散步",close_modal])
	show_panel("这一间的角落","选个地方，慢慢走过去。",options)
func life_book() -> void:
	var copy:="捡到的小东西\n"+("还没收集，慢慢逛。" if journal.found.is_empty() else "\n".join(journal.found))+"\n\n便笺：%d 张\n小游戏完成：%d 项\n\n作息与日常对白是游戏创作。天气是游戏里的天气，时钟跟着现实走。"%[journal.notes.size(),journal.completed.size()]
	show_panel("生活册",copy,[["一家人的作息",func():show_panel("一天的日常",LegacyData.schedule_text().replace("麻将小聚","喝茶聊天"),[["收起",close_modal]])],["收起",close_modal]])

func stop_audio() -> void:
	for audio in [amb,sfx]:
		if is_instance_valid(audio):audio.stop();audio.stream=null
	if is_instance_valid(activities) and is_instance_valid(activities.player):activities.player.stop();activities.player.stream=null
func _exit_tree() -> void:stop_audio()
