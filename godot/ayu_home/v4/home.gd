extends Node2D
## v4 lived-in home: physical thresholds, saved consequences, gentle real-time life.
const UI=preload("res://ayu_home/v4/pixel_ui.gd")
const DSkin=preload("res://scripts/ui/dialog_skin.gd") # 罗曼山庄的对话框和冒泡皮（全游戏共用，组件库 v0.1）
const Page=preload("res://ayu_home/v4/paper_page.gd")
const Assets=preload("res://ayu_home/v2/assets.gd")
const World=preload("res://ayu_home/v4/world.gd")
const Actor=preload("res://ayu_home/v4/actor.gd")
const Activities=preload("res://ayu_home/v4/activities.gd")
const Immersive=preload("res://ayu_home/v4/immersive.gd")
const Life=preload("res://ayu_home/v4/life_state.gd")
const Games=preload("res://ayu_home/v4/life_games.gd")
const Photo=preload("res://ayu_home/v4/polaroid.gd")
const Data=preload("res://ayu_home/home_data.gd")
const NAMES={"ayu":"阿鱼","father":"爸爸","mother":"妈妈","qiuqiu":"求求","luoluo":"落落","tiantian":"天天","xiduo":"喜多"}
const P="res://ayu_home/v3/assets/"
var village_ui
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
var toolbar:VBoxContainer
var near_button:Button
var near_tag:Button
var actions_layer:Control
var task_button:Button
var tools_button:Button
var toast:PanelContainer
var toast_tween:Tween
var season_icon:TextureRect
var season_label:Label
var weather_icon:TextureRect
var shown_note:=""
var room_entries:=0
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
var water_audio:AudioStreamPlayer
var activities
var immersive
var rest_position:=Vector2.ZERO
var note:="点地面就能走，门边进出"
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
var life
var games
var photo
var profile:Dictionary={}
var family_state:Dictionary={}
var nav_cache:Dictionary={}
var scene_controls:PanelContainer
var cats_label:Label
var invite_panel:PanelContainer
var blocked_notice_until:=0.0
var scene_until:=0.0
var scene_action:=""
var scene_progress:=0.0
var ball_position:=Vector2(1000,719)
var ball_velocity:=Vector2.ZERO
var ball_phase:="idle"
var ball_return_count:=0
var ball_origin:=Vector2.ZERO
var meal_host:=""
var transition_log:Array=[]
var stair_steps:=0
var last_stair_distance:=0.0
var first_visit:=false
var last_note:=""
var player_preset:=2
var town_profile:Dictionary={}
var notification_pending:=false
var tracked_person:=""
var dog_play_wait:=2.0
var dog_near:=false
var bark_next:=0.0
var prop_images:Dictionary={}
var key_axis:=Vector2.ZERO
var after_door:Dictionary={}
var final_leg:=false


func _ready() -> void:
	DisplayServer.window_set_title("裳泓村 · 把日子住进来")
	RenderingServer.set_default_clear_color(UI.DEEP)
	definitions=JSON.parse_string(FileAccess.get_file_as_string("res://ayu_home/v4/assets/rooms.json")).rooms
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
	load_journal();read_clock();life.pack_seeds(month)
	scene_frame=Control.new();scene_frame.clip_contents=true;scene_frame.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(scene_frame)
	world=World.new();world.life=life;scene_frame.add_child(world)
	amb=AudioStreamPlayer.new();add_child(amb);sfx=AudioStreamPlayer.new();add_child(sfx);setup_water_audio()
	make_ui()
	activities=Activities.new();add_child(activities)
	activities.closed.connect(func():note="玩好了，慢慢逛";stand_up())
	activities.completed.connect(complete)
	immersive=Immersive.new();add_child(immersive);immersive.closed.connect(func():note="想坐再来坐会儿";stand_up())
	immersive.completed.connect(complete)
	games=Games.new();add_child(games);games.completed.connect(finish_life_game);games.closed.connect(func():note="做过的事，留在家里了")
	photo=Photo.new();add_child(photo);photo.kept.connect(func():note="这张收进生活册了")
	village_ui=preload("res://ayu_home/v4/core/interface.gd").new();add_child(village_ui);village_ui.setup(self)
	# 共用存档接入后再判断是否首次来访，避免只读到旧生活文件而重复播放开场。
	if not village_ui.state.blocked and not life.data.found.is_empty():first_visit=false
	if not village_ui.state.blocked and not first_visit:area=str(village_ui.state.data.village.get("last_area",area))
	await enter_room(area,false)
	if not focus.is_empty():
		var h:Dictionary=world.spot(focus)
		if not h.is_empty():player.position=world.nearest(World.v(h.approach));camera=player.position-Vector2(0,55)
	get_viewport().size_changed.connect(layout)
	bootstrapped=true
	life.changed.connect(refresh_life_hud);refresh_life_hud()
	if life.another_open:note="开了两个阿鱼家，关一个就好"
	if first_visit:call_deferred("welcome")
	elif life.data.resident and life.now()-float(life.data.last_seen)>14400:player.say("家里给你留了一碗汤。")
	life.data.last_seen=life.now();life.save()
func read_clock() -> void:
	var now:=Time.get_datetime_dict_from_system()
	hour=test_hour if test_hour>=0 else float(now.hour)+float(now.minute)/60.0
	month=test_month if test_month>0 else int(now.month);day=int(now.day)
	weather=test_weather if not test_weather.is_empty() else ("rain" if (month+day)%4==0 else "clear")
	if world:world.hour=hour;world.month=month;world.weather=weather
	if time_label:
		time_label.text="%02d:%02d"%[int(hour),int(hour*60)%60]
		season_label.text=Data.SEASONS[Data.season(month)] # 第二行只放图标和短数字（组件库第 7 条），试玩时钟不另标
		var season_key:String=["spring","summer","autumn","winter"][Life.season(month)];var weather_key:="rain" if weather=="rain" else "sun"
		if season_icon.get_meta("key","")!=season_key:season_icon.texture=UI.icon(season_key,26,Color(DSkin.PAL.text)).texture;season_icon.set_meta("key",season_key)
		if weather_icon.get_meta("key","")!=weather_key:weather_icon.texture=UI.icon(weather_key,26,Color(DSkin.PAL.text)).texture;weather_icon.set_meta("key",weather_key)
func set_test_clock(h:float,m:=10,w:="clear") -> void:
	test_hour=h;test_month=m;test_weather=w;read_clock();family_state.clear();sync_family(true);play_ambience();note="时间、季节、天气换好了"
func set_identity(owner:bool) -> void:is_owner=owner
func dir(face:String) -> Vector2:return {"up":Vector2.UP,"down":Vector2.DOWN,"left":Vector2.LEFT,"right":Vector2.RIGHT}.get(face,Vector2.DOWN)
func anchor(room:String,id:String) -> Vector2:
	var cfg:Dictionary=definitions[room]
	return World.v(cfg.anchors.get(id,cfg.spawn))
func enter_room(which:String,with_transition:=true,from:="") -> void:
	if not definitions.has(which):return
	if not await preload("res://ayu_home/v4/core/download_gate.gd").ensure(self,"room:"+which):transition=false;return
	if world and not world.cfg.is_empty():
		room_state[area]={"lamp":world.lamp_on,"tv":world.tv_on,"toggles":world.toggles.duplicate()}
		life.data.effects.rooms=room_state.duplicate(true);life.save()
	clear_scene_controls();area=which;pending="";people.clear();world.load_room(area);world.hour=hour;world.month=month;world.weather=weather;world.reactions.clear();world.toggles.clear()
	var state:Dictionary=room_state.get(area,{})
	world.lamp_on=state.get("lamp",true);world.tv_on=state.get("tv",hour>=6 and hour<22);world.toggles=state.get("toggles",{}).duplicate();world.life=life
	player=Actor.new();player.preset=player_preset;world.actors.add_child(player);player.setup("visitor");player.position=world.spawn()
	for d in world.cfg.doors:
		if d.target==from:
			player.face=d.face;player.position=world.nearest(World.v(d.approach)+dir(d.face)*(64 if world.cfg.get("outdoor",false) else 25));break
	if which=="village" and from=="my_yard" and village_ui!=null:
		var location:String=str(village_ui.state.data.village.location)
		if village_ui.C.LOCATION_POINTS.has(location):player.position=world.nearest(World.v(village_ui.C.LOCATION_POINTS[location])+Vector2(0,64))
	if not bootstrapped and not first_visit and village_ui!=null:
		var saved:Dictionary=village_ui.state.data.village
		var saved_position:Array=saved.get("last_position",[])
		if str(saved.get("last_area",""))==which and saved_position.size()==2:player.position=world.nearest(World.v(saved_position))
	for id in NAMES:
		var actor:=Actor.new();world.actors.add_child(actor);actor.setup(id);people[id]=actor
	arrival_locks.clear()
	if from.is_empty():
		for doorway in world.cfg.doors:
			var entrance:Vector2=world.nearest(World.v(doorway.approach))
			if player.position.distance_to(entrance)<28:
				player.position=world.nearest(entrance+dir(str(doorway.face))*34);break
	sync_family(false);cooldown=.45;room_history.append(area);life.discover("room:"+area);title.text="裳泓村 · "+("你的房间" if area=="guest" and life.data.resident else str(world.cfg.title)).replace("后花园 · 果园 · 菜地","后花园").replace("一楼楼梯与过道","一楼楼梯")
	camera=player.position-Vector2(0,65);world.parallax_origin=camera
	if village_ui!=null:village_ui.entered()
	room_entries+=1;note="走近东西，点气泡就能做事" if room_entries<=3 else "";make_markers();layout();play_ambience()
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
	elif action=="garden":room="garden";action="water" if id=="mother" else action
	elif action=="mahjong":room="mahjong";action="mahjong" if id=="mother" else "read"
	elif action in ["tv","record"]:room="living"
	elif action=="read":room="study" if id=="ayu" else "living"
	else:room="terrace"
	var key:=id+"_meal" if action=="eat" else (id+"_seat" if room=="living" and action in ["tv","record","read"] else ("fish" if action=="fish" else id))
	var at:Vector2=anchor(room,key)
	if id=="mother" and action=="mahjong":
		# 使用现有椅子的实际坐点，旧家人锚点在桌边地板上。
		for spot in definitions[room].hotspots:
			if str(spot.id)=="seat_1":at=World.v(spot.seat);break
	return {"area":room,"action":action,"pos":at,"face":old.face}
func sync_family(_force:=false) -> void:
	if people.is_empty():return
	for id in Data.FAMILY:
		var st:=schedule(id)
		if not family_state.has(id):family_state[id]={"reaction_until":0.0,"reaction":"","room":st.area,"pos":st.pos,"route":PackedVector2Array(),"goal":st.area,"action":st.action,"face":st.face,"door":""}
		var record:Dictionary=family_state[id];record.goal=st.area;record.final_action=st.action;record.final_pos=st.pos;record.final_face=st.face
		var actor=people[id];actor.visible=record.room==area
		if actor.visible:actor.position=world.nearest(record.pos) if record.action not in ["eat","sleep","tv","read","sit","mahjong"] else record.pos;actor.action=record.action;actor.face=record.face
	var cats:=["qiuqiu","luoluo","tiantian"]
	for id in cats+["xiduo"]:
		var a=people[id];a.visible=false
		var loc:String=dog_loc() if id=="xiduo" else ("cats" if hour<7 or hour>=22 or weather=="rain" else (["living","cats","study","terrace","ayu_room"][(day+cats.find(id))%5] if hour<18 else "living"))
		a.visible=area==loc
		if a.visible:
			var p:=anchor(loc,"dog" if id=="xiduo" else id) if not (id=="xiduo" and loc!="exterior") else World.v(world.cfg.spawn)+Vector2(46,-30)
			a.position=world.nearest(p);a.action="lie" if id!="xiduo" else "sniff";a.cooldown=12+maxi(0,cats.find(id))*4

## 第六轮第 11 条（阿鱼）：喜多只在屋外。大部分时间在院子里自己玩足球；每两个钟头里有一刻钟跑去别处
## （后园、院外小道、小桥、老屋、树林轮着来）；夜里在院子里趴着
func dog_loc() -> String:
	if hour<7 or hour>=22:return "exterior"
	var slot:=int(hour*4)
	if posmod(slot+day*3,8)==5:return ["garden","side_path","bridge","oldhouse","grove"][posmod(int(slot/8)+day,5)]
	return "exterior"
func busy() -> bool:return get_tree().root.get_meta("village_loading",false) or (village_ui!=null and village_ui.opened) or transition or modal!=null or activities.root!=null or immersive.root!=null or (games!=null and games.root!=null) or (photo!=null and photo.root!=null)
func _process(dt:float) -> void:
	if not bootstrapped:return
	elapsed+=dt;cooldown=maxf(0,cooldown-dt);clock_poll+=dt
	if clock_poll>=1:
		clock_poll=0;read_clock();var slot:=str(int(hour*4))
		if slot!=last_slot:last_slot=slot;sync_family(false)
		if int(elapsed)%5==0:life.touch_open()
		check_meal_invite()
	if talk_ui and talk_chars>=999:DSkin.finish(talk_ui.talk_box);talk_chars=0 # 截图、测试：字直接出完
	if not busy():
		var previous:Vector2=player.position
		# 记下这一步本来要去哪：点地面时只有目的地就在门槛上或门外，才算「朝门走」。
		var walk_goal:Vector2=player.route[player.route.size()-1] if not player.route.is_empty() else Vector2.INF
		player.move_along(dt,82 if pending in ["to_stairs1","to_stairs2"] else 135)
		var axis:=Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
		if Input.get_connected_joypads().size()>0:
			var joy:=Input.get_connected_joypads()[0];var stick:=Vector2(Input.get_joy_axis(joy,JOY_AXIS_LEFT_X),Input.get_joy_axis(joy,JOY_AXIS_LEFT_Y))
			if stick.length()>.2:axis=stick
		if axis.length()>0:
			if player.action!="idle":stand_up()
			player.route.clear();pending="";after_door={};axis=axis.normalized()*minf(dt,.12)*135
			for delta in [Vector2(axis.x,0),Vector2(0,axis.y)]:
				var steps:=maxi(1,int(ceil(delta.length()/3)))
				for step in steps:
					if world.passable(player.position+delta/steps):player.position+=delta/steps
					elif not slide_around(delta/steps):blocked_feedback()
			player.walking=true;player.face="right" if axis.x>0 else ("left" if axis.x<0 else ("down" if axis.y>0 else "up"))
			key_axis=axis.normalized()
		else:key_axis=Vector2.ZERO
		if pending in ["to_stairs1","to_stairs2"] and player.movement_distance-last_stair_distance>19:
			last_stair_distance=player.movement_distance;stair_steps+=1;play_sound("switch")
		var crossed:=false
		if cooldown<=0:
			# An interaction route belongs to this room. Ground walking and explicit door
			# choices still use the live swept doorway test; talking to a cat cannot exit.
			for d in world.cfg.doors:
				if not pending.is_empty() and pending!=d.id:continue
				if pending!=d.id and not heading_out(d,walk_goal):continue
				if world.crossed_door(d,previous,player.position):cross(d);crossed=true;break
		if not crossed and not pending.is_empty() and player.route.is_empty():
			var id:=pending;pending="";interact(id)
		update_scene_action(dt);update_tracking()
		if not after_door.is_empty() and pending.is_empty() and player.route.is_empty():continue_into_room()
		elif final_leg and player.route.is_empty():final_leg=false
	update_family_walk(dt);update_pets(dt);update_ball(dt);update_water_audio();update_bark()
	var target:Vector2=player.position-Vector2(0,65)
	camera=camera.lerp(target,1-exp(-dt*7));layout_world()
	var distance:=76.0;near_id=""
	for h in world.cfg.hotspots+world.cfg.doors:
		var d:float=player.position.distance_to(world.nearest(World.v(h.approach)))
		if d<distance:distance=d;near_id=h.id
	for id in people:
		if people[id].visible and people[id].position.distance_to(player.position)<minf(distance,68):distance=people[id].position.distance_to(player.position);near_id="person:"+id
	var caption:String="起身" if player.action in ["sit","sleep","lie","eat","read","tv","swing"] else ("和"+NAMES[near_id.substr(7)]+"说说话" if near_id.begins_with("person:") else str(world.spot(near_id).get("label","走近看看")))
	if near_button.text!=caption:near_button.text=caption
	near_button.disabled=near_id.is_empty() and player.action=="idle"
	if note!=shown_note:shown_note=note;show_toast(note)
	layout_markers()

func _unhandled_input(event:InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode in [KEY_W,KEY_A,KEY_S,KEY_D,KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT] and village_ui!=null:
			village_ui.route_target="";village_ui.route_spot=""
		if event.keycode==KEY_ESCAPE:
			if photo.root:photo.close()
			elif games.root:games.close()
			elif immersive.root:immersive.close()
			elif activities.root:activities.close()
			elif modal:close_modal()
			else:settings_page()
			return
		if talk_ui and event.keycode in [KEY_ENTER,KEY_KP_ENTER,KEY_SPACE]:advance_dialogue();return # 原来回车按「继续」，现在照样往下走
		if event.keycode==KEY_M and not busy():navigation();return
		if event.keycode==KEY_J and not busy():life_book();return
		if event.keycode==KEY_C and not busy():take_photo();return
		if event.keycode==KEY_E and not busy() and not near_id.is_empty():go(near_id);return
		if event.keycode==KEY_F2 and test_panel_enabled:testing_panel();return
	if busy():return
	var at:=Vector2.ZERO;var pressed:=false
	if toolbar and toolbar.visible and ((event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)):toggle_tools(false)
	if event is InputEventScreenTouch:at=event.position;pressed=event.pressed
	elif event is InputEventMouseButton:at=event.position;pressed=event.pressed and event.button_index==MOUSE_BUTTON_LEFT
	if not pressed:return
	tracked_person="";after_door={};final_leg=false
	if village_ui!=null:village_ui.route_target=""
	var p:Vector2=world.get_global_transform_with_canvas().affine_inverse()*at
	for id in people:
		var a=people[id]
		if a.visible and Rect2(a.position-Vector2(25,48 if a.pet else 84),Vector2(50,48 if a.pet else 84)).has_point(p):go("person:"+id);get_viewport().set_input_as_handled();return
	# 点到几样东西挨在一起时，选离手指最近的那样（衣柜门和抽屉叠在一起，点门原来打开的是抽屉）
	# 点在门洞里（门槛线上、往外 20 以内）就是走门，不让旁边的抽屉、柜子抢了
	var in_door:=door_in_opening(p,20.0)
	if not in_door.is_empty():go(in_door);get_viewport().set_input_as_handled();return
	var hit:Dictionary={};var hit_d:=22.0
	for h in world.cfg.hotspots+world.cfg.doors:
		var hd:float=p.distance_to(World.v(h.pos))
		if h.has("target") and not marker_shown(str(h.id)):continue # 门的提示泡没出来（屋里房间之间的门、不是最近的那个）就不算点到门
		if str(h.get("kind",""))=="seat" and near_door(p):continue # 门口的台阶：点上去是往门走；要坐得点「坐一会儿」的气泡
		if hd<hit_d or (hd<=hit_d+4 and h.has("target") and not hit.has("target")):hit=h;hit_d=hd
	if not hit.is_empty():go(hit.id);get_viewport().set_input_as_handled();return
	if player.action in ["sit","sleep","lie","eat","read","tv","swing"]:stand_up()
	player.destination_action="idle";pending="";clear_scene_controls()
	if not world.passable(p):
		if walk_into_room(p):get_viewport().set_input_as_handled();return
		var beyond:=door_beyond(p)
		if not beyond.is_empty():go(beyond);get_viewport().set_input_as_handled();return
		blocked_feedback();final_leg=true # 点到走不到的地方：走到最近能站的地方就停，路上不过门
	else:
		# 第六轮第 24 条（总策划定）：点屋里、院里自己的地面永远不算出门，人只走到点的地方；
		# 只有点在门洞里面（门槛线上或门槛外、门洞那么宽的一段）才出门
		var out_id:=door_in_opening(p)
		final_leg=out_id.is_empty()
		if not out_id.is_empty():
			go(out_id);get_viewport().set_input_as_handled();return
		out_id=""
		if not out_id.is_empty():
			var dd:Dictionary=world.spot(out_id);var tgt:String=str(dd.get("target",""))
			if definitions.has(tgt) and canvas_key(tgt)==canvas_key(area) and nav(tgt).passable(from_canvas(tgt,to_canvas(area,p))):
				after_door={"room":tgt,"point":from_canvas(tgt,to_canvas(area,p))};go(out_id);get_viewport().set_input_as_handled();return
	player.route=world.path(player.position,p)
	get_viewport().set_input_as_handled()
func go(id:String) -> void:
	if transition or photo.root or games.root:return
	close_modal()
	if player.action!="idle":stand_up()
	var goal:Vector2
	if id.begins_with("person:"):
		if not people.has(id.substr(7)) or not people[id.substr(7)].visible:return
		goal=people[id.substr(7)].position+Vector2(24,12)
	else:
		var h:Dictionary=world.spot(id)
		if h.is_empty():return
		goal=World.v(h.approach)
	# 已经站在互动点时，寻路会返回空路径；仍应直接做事。
	if player.position.distance_to(world.nearest(goal))<10:
		player.route.clear();pending="";interact(id);return
	var route:PackedVector2Array=world.path(player.position,goal)
	if id in ["to_stairs1","to_stairs2"] and world.cfg.has("stair_path"):
		var steps:Array=world.cfg.stair_path;route=world.path(player.position,World.v(steps[0]))
		for step in steps:route.append(World.v(step))
	if route.is_empty():
		if outdoors():note="这里过不去，绕空地走";player.say("这里过不去")
		return
	player.route=route;player.destination_action="idle";pending=id;note="慢慢走近…"

## 只有真的朝门走才过门：点了这扇门、方向键往门外推，或者点地面的目的地就在门槛上 / 门外。
## 路过门槛去房间别处（比如车库左下角）不算。门的位置以后会变，这里只看判定，不看坐标。
## 方向键顶到门框、家具角时，往旁边让一点点再走（贴着门洞边往外推也出得去，不用对得很准）
func slide_around(step:Vector2) -> bool:
	if step.length()<.01:return false
	var side:=Vector2(-step.y,step.x).normalized()
	for k in range(2,26,2):
		for sgn in [1,-1]:
			var off:Vector2=side*k*sgn
			if not world.passable(player.position+off+step):continue
			var clear:=true
			for j in range(1,k+1):
				if not world.passable(player.position+side*j*sgn):clear=false;break
			if clear:player.position+=side*sgn*minf(2.0,k)+(step if k<=2 else Vector2.ZERO);return true
	return false
func heading_out(d:Dictionary,goal:Vector2) -> bool:
	var plane:Dictionary=world.door_plane(d);var n:Vector2=plane.normal;var p:Vector2=plane.point
	if key_axis.length()>0:return key_axis.dot(n)>.3
	if final_leg:return false
	if goal==Vector2.INF:return false
	var tangent:=Vector2(-n.y,n.x)
	return (goal-p).dot(n)>=-4 and absf((goal-p).dot(tangent))<=plane.width*.5+8
## 一楼、二楼、屋外同一张画上的几块：点到画上看得见的隔壁房间，就自己走过门、进去走到点的地方，
## 不用先找门。点到墙、家具上才说「这里过不去」。（阿鱼 10/5：每扇门都要顺，走过去自然进下一间）
func canvas_key(room:String) -> String:
	var c:Dictionary=definitions[room];var f:=int(c.get("floor",0))
	if f in [1,2]:return "floor"+str(f)
	# 院子的底图跟院外小道、小桥、老屋是同一张画的同一套坐标（院子那张只是抠掉了房子），算同一张画
	return "outdoor0" if str(c.get("background","")).get_file() in ["approved-0.png","exterior_floor.png"] else room
func to_canvas(room:String,at:Vector2) -> Vector2:
	var c:Dictionary=definitions[room];return at+World.v(c.get("source_crop",[0,0]))-World.v(c.get("source_offset",[0,0]))
func from_canvas(room:String,at:Vector2) -> Vector2:
	var c:Dictionary=definitions[room];return at-World.v(c.get("source_crop",[0,0]))+World.v(c.get("source_offset",[0,0]))
func walk_into_room(p:Vector2) -> bool:
	var key:=canvas_key(area);var at:=to_canvas(area,p);var best:="";var best_q:=Vector2.ZERO;var best_n:=99
	# 同一个点几间房都能走（门口一带）时，选隔得最少的那间，不多穿一间
	for room in definitions:
		if room==area or canvas_key(room)!=key:continue
		var q:=from_canvas(room,at);var w=nav(room)
		if not w.passable(q):
			# 第六轮第 25 条：点在隔壁那块能走的地方边上一点点（老屋门前那条路的边），就走到离点最近的能站处
			var near:Vector2=w.nearest(q)
			if near.distance_to(q)>28 or not w.passable(near):continue
			q=near
		var n:=room_distance(area,room)
		if n>0 and n<best_n:best=room;best_q=q;best_n=n
	if best.is_empty():
		# 一楼画上屋子南边门外那段石板路、院子（不是哪间屋）：从最近的出门那扇门走出去
		if key=="floor1" and at.y>826:
			var out:="exterior";var hop_out:=room_hop(area,out)
			if hop_out==area:return false
			after_door={"room":out,"point":Vector2.INF};go("to_"+hop_out);return not pending.is_empty()
		return false
	var hop:=room_hop(area,best)
	if hop==area:return false
	after_door={"room":best,"point":best_q};go("to_"+hop);return not pending.is_empty()
## 点在门外（门槛外边、门洞那么宽的一段里）但那里不是这间房能站的地方：就是要出这扇门
func door_beyond(p:Vector2) -> String:
	for d in world.cfg.doors:
		var plane:Dictionary=world.door_plane(d);var n:Vector2=plane.normal;var t:=Vector2(-n.y,n.x);var rel:Vector2=p-plane.point
		if rel.dot(n)>-14 and rel.dot(n)<110 and absf(rel.dot(t))<=plane.width*.5+10:return str(d.id)
	return ""
func door_in_opening(p:Vector2,depth:=110.0) -> String:
	for d in world.cfg.doors:
		var plane:Dictionary=world.door_plane(d);var nn:Vector2=plane.normal;var t:=Vector2(-nn.y,nn.x);var rel:Vector2=p-plane.point
		if rel.dot(nn)>=0 and rel.dot(nn)<depth and absf(rel.dot(t))<=plane.width*.5:return str(d.id)
	return ""
func marker_shown(id:String) -> bool:
	for m in marker_nodes:
		if str(m.hot.id)==id:return m.button.visible
	return false
func near_door(p:Vector2) -> bool:
	for d in world.cfg.doors:
		if p.distance_to(World.v(d.approach))<80:return true
	return false
func room_distance(start:String,finish:String) -> int:
	var queue:Array=[start];var seen:Dictionary={start:0}
	while not queue.is_empty():
		var room:String=queue.pop_front()
		if room==finish:return int(seen[room])
		for doorway in definitions[room].doors:
			if not seen.has(doorway.target):seen[doorway.target]=int(seen[room])+1;queue.append(doorway.target)
	return 99
func continue_into_room() -> void:
	if after_door.is_empty():return
	if str(after_door.room)==area:
		if after_door.point==Vector2.INF:after_door={};return
		var goal:Vector2=after_door.point;after_door={};player.route=world.path(player.position,goal);player.destination_action="idle";final_leg=true;return # 最后一段只是走到点的地方，不再算朝门走
	var hop:=room_hop(area,str(after_door.room))
	if hop==area:after_door={};return
	go("to_"+hop)
func cross(d:Dictionary) -> void:
	if transition:return
	if d.target=="my_cabin" and village_ui!=null and float(village_ui.state.data.village.land[0])<=0:
		village_ui.show_page("院子");return
	pending="";player.route.clear()
	if area=="exterior" and d.target=="living" and not admitted and not life.data.resident:knock();cooldown=2;return
	transition_log.append({"from":area,"to":d.target,"at":elapsed,"position":[player.position.x,player.position.y],"steps":stair_steps})
	var from:=area;enter_room(d.target,true,from)
	# 下一扇门等换房间的淡入结束后再接着走（_process 里），不然这一步会被「正在换房间」挡掉

func interact(id:String) -> void:
	if id.begins_with("person:"):talk(id.substr(7));return
	var h:Dictionary=world.spot(id)
	if h.is_empty():return
	if h.has("target"):cross(h);return
	effects_log.append(area+":"+id);life.discover(area+":"+id)
	var kind:String=h.get("kind","reaction");var fx:String=h.get("effect","")
	if village_ui!=null:
		if village_ui.interact(h):return
		if area=="exterior" and id=="today":village_ui.show_page("牌子");return
		if area=="exterior" and id=="xiduo":village_ui.show_page("田边");return
		if area=="kitchen" and id=="stove":village_ui.show_page("灶屋");return
		if area=="garden" and id in ["vegetables","garden_play"]:village_ui.show_page("田边");return
	if kind in ["guitar","puzzle","album"]:activities.open(kind,{"month":month,"v2_art":true});return
	if kind=="fish":immersive.open("fish",{"hour":hour,"month":month,"fish":life.data.fish});return
	if Games.TITLES.has(kind):games.open(kind,life,{"hour":hour,"month":month,"weather":weather,"sound":sound_on,"area":area});return
	match kind:
		"today":today();return
		"seedbox":life.pack_seeds(month);games.open("garden",life,{"hour":hour,"month":month,"weather":weather,"sound":sound_on});return
		"stay":stay_choices(h);return
		"bed":lie_down(h);return
		"seat":sit_at(h);return
		"swing":
			if not sit_at(h):return
			player.action="swing";scene_buttons([["看天空",func():games.open("stars",life,{"hour":hour,"month":month,"weather":weather,"sound":sound_on,"area":area})],["起身",stand_up]]);return
		"meal":eat_together(h);return
		"tv_scene":watch_tv(h);return
		"drink":drink_water(h);return
		"tap":
			world.toggles[id]=not world.toggles.get(id,false);scene_action="wash_hands";scene_until=elapsed+3;player.action="wash";player.say("洗干净啦" if world.toggles[id] else "把水关好了");note="水开着，再点一下关好" if world.toggles[id] else "水声停下了";life.event("wash_hands");mother_reaction("wash")
		"shower":bath(h)
		"pet_scene","pet_play":
			var pet:="xiduo" if area=="exterior" else nearest_pet()
			pet_scene(pet,kind=="pet_play");return
		"pet_food":
			for cat in ["qiuqiu","luoluo","tiantian"]:
				if people[cat].visible:people[cat].route=world.path(people[cat].position,World.v(h.approach));people[cat].destination_action="sniff"
			life.event("pet_food");life.data.effects.pet_food=true;life.save();player.say("水和猫粮都添好了")
		"football":start_ball();return
		"read":read_book(h);return
		"recipe":recipe();return
		"work":start_work(h);return
		"music":scene_action="music";scene_until=elapsed+24;player.say("听一段原创的小旋律");life.event("music");scene_buttons([["停下音乐",func():scene_until=0;scene_action="";games.sound.stop();clear_scene_controls()]]);return
		"pick_flowers":pick_flowers();return
		"pantry":pantry();return
		"drying":
			if life.data.effects.get("laundry",false):life.data.effects.laundry=false;life.data.effects.clean_clothes=true;life.card("rain") if weather=="rain" else life.event("drying");player.say("衣服都收好了");mother_reaction("laundry")
			else:player.say("先洗一筐衣服，再挂到这里")
		"leaf":
			if Life.season(month)==2:life.card("autumn");player.say("这一片秋叶，夹进生活册。")
			else:player.say("先看叶子慢慢长，秋天再来夹一片落叶。")
		"fireflies":life.card("summer") if Life.season(month)==1 and hour>=18 else life.event("grove");player.say("夏夜里，这里会有萤火虫")
		"knock_old":play_sound("knock");player.say("在老屋前，歇一歇脚")
		"bell":play_sound("knock");player.say("叮铃——")
		"bees":life.event("bees");player.say("蜜蜂正从花里带回花粉")
		"tend":
			if area=="terrace" and Life.season(month)==3:life.card("winter");player.say("捧一小团雪，指尖凉凉的。")
			elif area=="exterior" and weather=="rain":life.card("snail");player.say("叶子下有一只小蜗牛，轻轻绕过它吧。")
			else:player.say(str(h.get("copy","把水浇在根边，让叶子慢慢舒展。")))
		_:
			player.say(str(h.get("copy",h.label)))
			life.data.effects[area+":"+id]=true
			if kind=="tidy":life.event("tools" if id=="tools" or (area=="garage" and id=="shelf") else "tidy")
			elif kind=="fold":life.event("fold")
			elif fx=="lamp":
				note="灯关好了" if world.lamp_on else "灯亮起来了"
				if hour>=20 and not world.lamp_on:
					for cat in ["qiuqiu","luoluo","tiantian"]:
						if people[cat].visible:life.card("night")
			else:life.event(kind)
	if kind not in ["tap","shower"]:world.react(h)
	play_sound("switch");life.data.effects[area+":"+id]=true;life.save()

func stand_up() -> void:
	if player and player.action in ["sit","sleep","lie","drink","eat","read","computer","tv","swing"]:
		player.position=world.nearest(rest_position);player.action="idle";player.route.clear();player.destination_action="idle";player.rotation=0;player.visible=true;player.lift=0;player.head_down=false
	clear_scene_controls();scene_action="";scene_until=0

func knock() -> void:
	play_sound("knock");player.face="up"
	if is_owner:
		phase="owner_home";dialogue("到家了","钥匙轻轻转动，家就在这里。", "",admit);return
	var hosts:=Data.at_home(hour)
	if hosts.is_empty():
		# 家人出门时也不把客人关在门外（地图本来就能进，敲门要一致）：门没锁，桌上留了字条。
		phase="absent";dialogue("门上的字条","我们出门一小会儿，十点前后陆续回来。门没锁，先进屋坐，桌上有水。——阿鱼", "",func():journal.notes.append("来拜访过");save_journal();admit());return
	phase="invited";dialogue(NAMES[hosts[0]],"来啦，请进。家里的东西可以慢慢看看。",hosts[0],admit)
func admit() -> void:
	admitted=true;phase="inside";close_modal();enter_room("living",true,"exterior")
func talk(id:String) -> void:
	if people[id].pet:pet_scene(id);return
	var text:="欢迎回来，房间还是给你留着的。" if life.data.resident else "来做客不用拘束，想做什么就慢慢试。"
	for task in life.daily_tasks():
		if task.host!=id or task.thanked:continue
		if task.done and task.accepted:
			text=task.thanks;task.thanked=true;life.card("task:"+life.date_key()+":"+id)
		elif task.accepted:text="不着急，有空再帮我"+str(task.text)+"。"
		else:text="今天愿不愿意帮我"+str(task.text)+"？做好再来找我，我想听听你怎么做的。";task.accepted=true
		life.save();break
	if life.data.effects.has("fruit_to_share"):
		text={"ayu":"你摘的果子呀？我们一人一半吧。","father":"果园的甜，吃得出来。给你留一块。","mother":"谢谢你惦记着，洗好放在桌上一起吃。"}[id];life.data.effects.erase("fruit_to_share");life.save()
	family_state[id].reaction_until=elapsed+6;family_state[id].reaction="talk";people[id].action="talk";dialogue(NAMES[id],text,id)

func mother_reaction(action:String,duration:=4.0) -> void:
	if not family_state.has("mother") or not people.has("mother"):return
	var st:Dictionary=family_state.mother
	if st.room!=area or not st.get("route",PackedVector2Array()).is_empty() or st.action in ["sleep","rest","away"]:return
	st.reaction=action;st.reaction_until=elapsed+duration
	people.mother.action=action;people.mother.pose()

func remember(copy:String) -> void:life.discover(copy)

func complete(kind:String) -> void:
	life.event(kind)
	if kind=="fish":note="鱼都吃到了，新鱼也在这"

func load_journal() -> void:
	life=Life.new()
	profile=town_profile.duplicate(true) if not town_profile.is_empty() else get_tree().root.get_meta("player_profile",{}).duplicate(true)
	var local_profile:="user://ayu_home_local_player.json"
	if profile.is_empty() and FileAccess.file_exists(local_profile):
		var saved=JSON.parse_string(FileAccess.get_file_as_string(local_profile))
		if saved is Dictionary:profile=saved
	if profile.is_empty():
		profile={"id":Crypto.new().generate_random_bytes(16).hex_encode(),"avatar":2,"nick":"来做客的你"};first_visit=true
		var file:=FileAccess.open(local_profile,FileAccess.WRITE)
		if file:file.store_string(JSON.stringify(profile));file.close()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ayu-profile="):profile.id=arg.get_slice("=",1);first_visit=false
		elif arg.begins_with("--ayu-preset="):profile.avatar=int(arg.get_slice("=",1))
	player_preset=clampi(int(profile.get("avatar",2)),0,7)
	var override_path:="" if save_path=="user://ayu_home_life_v3.json" else save_path
	life.open(profile,override_path);journal=life.data
	if override_path.is_empty() and life.data.found.is_empty():first_visit=true
	room_state=life.data.effects.get("rooms",{}).duplicate(true)
	sound_on=bool(life.data.settings.sound)

func save_journal() -> void:
	if life:life.save()

func play_sound(which:String) -> void:
	if not sound_on:return
	sfx.stream=Assets.sound("res://ayu_home/v2/assets/"+which+".wav");sfx.play()
func play_fx(which:String) -> void:
	if not sound_on:return
	sfx.stream=preload("res://ayu_home/v4/sfx.gd").get_sound(which);sfx.play()
func play_ambience() -> void:
	if not sound_on:amb.stop();return
	var track:="rain" if weather=="rain" else ("outdoor" if world.cfg.get("outdoor",false) else ("living" if area=="living" else "dining"))
	var file:="res://ayu_home/v4/assets/rain.wav" if track=="rain" else "res://ayu_home/v2/assets/"+("yard" if track=="outdoor" else track)+"_amb.wav"
	if not FileAccess.file_exists(file):file="res://ayu_home/v2/assets/living_amb.wav"
	amb.stream=Assets.sound(file)
	if amb.stream:amb.stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;amb.volume_db=-15;amb.play()
## 界面（阿鱼 10/5）：屏幕上大部分是阿鱼家的画。顶上只留一行地点、一行小图标和一行今日小事，
## 不要大框；提示在上方亮一下就收；相机、生活册、地图收进右下角的小包；要点的操作出现在人旁边。
func make_ui() -> void:
	hud=CanvasLayer.new();hud.layer=20;add_child(hud);ui=Control.new();hud.add_child(ui);ui.theme=UI.theme();ui.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var top:=Control.new();top.name="Top";top.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(top)
	# 村-6 顶栏（组件库第 7 条）：左上一块深褐小牌（名字牌那一家），最多两行：第一行「阿鱼家 · 房间名」，
	# 第二行一排时钟、季节、天气、猫 0/3、「小事 0/3」（点了打开今日小事看全文，那句话不常驻顶栏）；米白字 24、米白图标（第 5 条那套）。右上齿轮是图标按钮
	var plate:=PanelContainer.new();plate.name="Words";plate.add_theme_stylebox_override("panel",UI.card_box());plate.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;plate.mouse_filter=Control.MOUSE_FILTER_IGNORE;top.add_child(plate)
	var words:=VBoxContainer.new();words.add_theme_constant_override("separation",2);words.mouse_filter=Control.MOUSE_FILTER_IGNORE;plate.add_child(words)
	var cream:=Color(DSkin.PAL.text)
	title=UI.label("阿鱼家",24);title.add_theme_color_override("font_color",cream);words.add_child(title)
	var chips:=HBoxContainer.new();chips.add_theme_constant_override("separation",4);chips.mouse_filter=Control.MOUSE_FILTER_IGNORE;words.add_child(chips)
	chips.add_child(UI.icon("clock",26,cream));time_label=UI.label("",24);chips.add_child(time_label)
	chips.add_child(gap(10));season_icon=UI.icon("autumn",26,cream);chips.add_child(season_icon);season_label=UI.label("",24);chips.add_child(season_label)
	chips.add_child(gap(10));weather_icon=UI.icon("sun",26,cream);chips.add_child(weather_icon);chips.add_child(gap(10))
	chips.add_child(UI.icon("cat",26,cream));cats_label=UI.label("0/3",24);chips.add_child(cats_label)
	for l in [time_label,season_label,cats_label]:l.add_theme_color_override("font_color",cream)
	task_button=Button.new();task_button.flat=true;task_button.focus_mode=Control.FOCUS_NONE;task_button.alignment=HORIZONTAL_ALIGNMENT_LEFT;task_button.custom_minimum_size.y=30;task_button.text="小事 0/3"
	for key in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:task_button.add_theme_color_override(key,Color(DSkin.PAL.name)) # 名字黄：能点
	task_button.add_theme_font_size_override("font_size",24)
	for state in ["normal","hover","pressed","focus"]:task_button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	task_button.pressed.connect(func():if not busy():today());chips.add_child(gap(10));chips.add_child(task_button)
	# 能点的范围至少 44×44（组件库，002）：字和框不变，外面罩一层透明的往上下左右各扩一点，点到也开今日小事
	var hit:=Button.new();hit.flat=true;hit.focus_mode=Control.FOCUS_NONE;hit.name="TaskHit"
	for state in ["normal","hover","pressed","focus"]:hit.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);hit.offset_left=-6;hit.offset_right=6;hit.offset_top=-8;hit.offset_bottom=8
	hit.pressed.connect(func():if not busy():today());task_button.add_child(hit)
	var gear:=UI.icon_button("gear",settings_page,44);gear.name="Settings";top.add_child(gear)
	markers=Control.new();markers.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(markers)
	actions_layer=Control.new();actions_layer.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(actions_layer)
	# 物件名字小牌：深褐小牌、米白字 24（组件库第 5 条）
	near_tag=Button.new();near_tag.focus_mode=Control.FOCUS_NONE;near_tag.add_theme_font_size_override("font_size",24);near_tag.custom_minimum_size=Vector2(0,40);near_tag.visible=false
	for key in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:near_tag.add_theme_color_override(key,UI.TEXT)
	var tag_box:StyleBoxTexture=DSkin.pixel_box(UI.DEEP,UI.OUTER,UI.GOLD,2,2,1);tag_box.set_content_margin(SIDE_LEFT,12);tag_box.set_content_margin(SIDE_RIGHT,12);tag_box.set_content_margin(SIDE_TOP,4);tag_box.set_content_margin(SIDE_BOTTOM,6)
	for state in ["normal","hover","pressed","focus"]:near_tag.add_theme_stylebox_override(state,tag_box)
	near_tag.pressed.connect(func():if not busy():go(str(near_tag.get_meta("hot",near_id))));actions_layer.add_child(near_tag)
	# 能点的范围至少 44 高（组件库）：牌子样子不变，外面透明罩上下各扩 4
	var tag_hit:=Button.new();tag_hit.flat=true;tag_hit.focus_mode=Control.FOCUS_NONE;tag_hit.name="TagHit"
	for state in ["normal","hover","pressed","focus"]:tag_hit.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	tag_hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);tag_hit.offset_top=-4;tag_hit.offset_bottom=4
	tag_hit.pressed.connect(func():if not busy():go(str(near_tag.get_meta("hot",near_id))));near_tag.add_child(tag_hit)
	# 提示：在上方亮出来，几秒后自己收起（原来压在最底下，容易看漏）
	# 提示条（村-6）：深褐底、金棕线、米白字 24，顶栏下面亮一下自己收；只占一行，框宽跟着字走、不铺满屏宽（组件库第 7 条，第八轮）
	toast=PanelContainer.new();toast.mouse_filter=Control.MOUSE_FILTER_IGNORE;toast.add_theme_stylebox_override("panel",UI.card_box());toast.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;toast.modulate.a=0;ui.add_child(toast)
	hint=UI.label(note,24);hint.autowrap_mode=TextServer.AUTOWRAP_OFF;hint.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;hint.add_theme_color_override("font_color",Color(DSkin.PAL.text));toast.add_child(hint)
	var bottom:=Control.new();bottom.name="Bottom";bottom.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(bottom)
	toolbar=VBoxContainer.new();toolbar.name="Tools";toolbar.alignment=BoxContainer.ALIGNMENT_END;toolbar.add_theme_constant_override("separation",6);toolbar.visible=false;bottom.add_child(toolbar)
	for item in [["相机","camera",take_photo],["生活册","note",life_book],["地图","map",func():navigation()]]+([["试玩","gear",testing_panel]] if test_panel_enabled else []):
		var b:=UI.button(item[0],func():toggle_tools(false);item[2].call());b.custom_minimum_size=Vector2(150,48);b.alignment=HORIZONTAL_ALIGNMENT_LEFT
		var img:Image=UI.icon(item[1],26,Color(DSkin.PAL.icon)).texture.get_image();img.resize(26,26,Image.INTERPOLATE_NEAREST);b.icon=ImageTexture.create_from_image(img);b.expand_icon=false;b.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;b.add_theme_constant_override("h_separation",8);toolbar.add_child(b)
	tools_button=UI.icon_button("bag",func():toggle_tools(),56);tools_button.name="Bag";bottom.add_child(tools_button)
	near_button=UI.button("走近看看",func():
		if player.action in ["sit","sleep","lie","eat","read","tv","swing"]:stand_up()
		elif not near_id.is_empty():go(near_id))
	near_button.visible=false;bottom.add_child(near_button)
	fade=ColorRect.new();fade.mouse_filter=Control.MOUSE_FILTER_IGNORE;fade.color=Color(0,0,0,0);ui.add_child(fade)
func gap(width:float) -> Control:
	var c:=Control.new();c.custom_minimum_size.x=width;c.mouse_filter=Control.MOUSE_FILTER_IGNORE;return c
func toggle_tools(open=null) -> void:
	toolbar.visible=(not toolbar.visible) if open==null else bool(open)
	if toolbar.visible:
		toolbar.modulate.a=0;toolbar.create_tween().tween_property(toolbar,"modulate:a",1.0,.14)
	layout()
## 顶栏下沿：话泡、气泡、操作都不往这上面放。
func hud_bottom() -> float:
	var words:Control=ui.get_node("Top/Words")
	return 10+words.get_combined_minimum_size().y+4
## 底栏实际顶边留出间隙；气泡、文字牌和坐姿操作共用这一条边界。
func interaction_bottom() -> float:
	var edge:=get_viewport_rect().size.y-136.0
	if is_instance_valid(village_ui) and is_instance_valid(village_ui.hud_button):
		edge=minf(edge,village_ui.hud_button.get_global_rect().position.y)
	return edge-16.0
func layout() -> void:
	if not ui:return
	var size:=get_viewport_rect().size;ui.size=size;ui_scale=size.x/540.0
	var top=ui.get_node("Top");top.position=Vector2.ZERO;top.size=Vector2(size.x,hud_bottom())
	var words:Control=top.get_node("Words");words.position=Vector2(10,10);words.size=Vector2(size.x-80,words.get_combined_minimum_size().y)
	var gear:Control=top.get_node("Settings");gear.position=Vector2(size.x-58,12);gear.size=Vector2(44,44)
	var bottom=ui.get_node("Bottom");bottom.position=Vector2.ZERO;bottom.size=size
	tools_button.size=Vector2(56,56);tools_button.position=Vector2(size.x-70,size.y-74)
	toolbar.size=Vector2(150,toolbar.get_combined_minimum_size().y);toolbar.position=Vector2(size.x-164,tools_button.position.y-10-toolbar.size.y)
	var text_w:float=hint.get_theme_font("font").get_string_size(hint.text,HORIZONTAL_ALIGNMENT_LEFT,-1,24).x
	var width:=minf(ceilf(text_w)+28,size.x-48);hint.custom_minimum_size.x=width-28;toast.size=Vector2(width,0);toast.reset_size();toast.position=Vector2((size.x-toast.size.x)*.5,hud_bottom()+10) # 万一字太长，一行放不下就收成「…」
	fade.size=size;markers.size=size;actions_layer.size=size;layout_world()
## 提示亮一下：换了新提示才出来，3.5 秒后淡出。走路途中的「慢慢走近…」和撞墙不弹（人头上已经说了）。
func show_toast(copy:String) -> void:
	if not toast or copy.is_empty() or copy in ["慢慢走近…","墙和家具过不去，绕着走"]:return
	hint.text=copy;layout()
	if toast_tween:toast_tween.kill()
	toast.modulate.a=0;toast.position.y=hud_bottom()+2
	toast_tween=create_tween();toast_tween.set_parallel(true);toast_tween.tween_property(toast,"modulate:a",1.0,.18);toast_tween.tween_property(toast,"position:y",hud_bottom()+10,.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	toast_tween.chain().tween_interval(3.4);toast_tween.chain().tween_property(toast,"modulate:a",0.0,.5)
func layout_world() -> void:
	if not world or world.cfg.is_empty():return
	var screen:=get_viewport_rect().size
	var top_area:=hud_bottom()+8
	scene_frame.position=Vector2(0,top_area);screen.y=maxf(180,screen.y-top_area-156);scene_frame.size=screen
	var size:Vector2=World.v(world.cfg.size)
	view_scale=float(world.cfg.get("view_scale",2.0))

	var visible_world:=screen/view_scale
	var center:=Vector2(size.x*.5 if size.x<visible_world.x else clampf(camera.x,visible_world.x*.5,size.x-visible_world.x*.5),size.y*.5 if size.y<visible_world.y else clampf(camera.y,visible_world.y*.5,size.y-visible_world.y*.5))
	if int(world.cfg.get("floor",0)) in [1,2]:
		var origin:=World.v(world.cfg.source_offset)-World.v(world.cfg.source_crop)
		var art_size:=Vector2(world.base_sprite.texture.get_size())
		center=camera.clamp(origin+visible_world*.5,origin+art_size-visible_world*.5)
	world.scale=Vector2.ONE*view_scale;world.position=(screen*.5-center*view_scale).round();world.camera_center=center
func make_markers() -> void:
	for n in markers.get_children():n.queue_free()
	marker_nodes.clear()
	for h in world.cfg.hotspots+world.cfg.doors:
		var b:=Button.new();b.flat=true;b.custom_minimum_size=Vector2(48,54);b.size=Vector2(48,54);b.tooltip_text=h.label;b.focus_mode=Control.FOCUS_NONE
		var bubble:=UI.Bubble.new();bubble.size=b.size;b.add_child(bubble)
		bubble.icon="door" if h.has("target") else str(h.get("kind","detail"))
		if h.has("target"):bubble.turn={"down":0,"left":1,"up":2,"right":3}.get(str(h.get("face","down")),0) # 门外在 face 的反方向
		if not UI.Bubble.ICONS.has(bubble.icon):bubble.icon={"garden":"water","workbench":"tools","wood":"tools","tea":"tea","soup":"tea","flowers":"water","football":"pet","tree":"water","stay":"relax","bed":"relax","seat":"relax","meal":"tea"}.get(bubble.icon,"detail")
		if bubble.icon=="reaction":bubble.icon={"steam":"tea","water":"water","wash":"water","lamp":"lamp","open":"open","fold":"fold","tools":"tools","pet":"pet","food":"pet","sit":"relax","bunny":"pet","book":"album"}.get(str(h.get("effect","")),"detail")
		b.pressed.connect(go.bind(h.id));markers.add_child(b);marker_nodes.append({"button":b,"bubble":bubble,"hot":h})
	for id in people:
		var b:=Button.new();b.flat=true;b.size=Vector2(48,54);b.focus_mode=Control.FOCUS_NONE
		var bubble:=UI.Bubble.new();bubble.size=b.size;bubble.icon="！";b.add_child(bubble);b.pressed.connect(go.bind("person:"+id));markers.add_child(b)
		marker_nodes.append({"button":b,"bubble":bubble,"hot":{"id":"person:"+id,"pos":[0,0],"approach":[0,0]}})
const DOOR_NEAR:=64.0 # 门前几步：人走一步约 16 画布像素，四步以内
func layout_markers() -> void:
	if not markers:return
	var size:=get_viewport_rect().size;var candidates:Array=[];var used:Array[Rect2]=[];var top_limit:=hud_bottom()+4;var bottom_limit:=interaction_bottom()
	if toast and toast.modulate.a>.05:top_limit=maxf(top_limit,toast.position.y+toast.size.y+6) # 上面的提示亮着时，话泡往下让
	for m in marker_nodes:
		if str(m.hot.id).begins_with("person:"):
			var actor=people[m.hot.id.substr(7)]
			if not actor.visible:continue
			# 「!」挂在头顶上面（按画出来的头顶算，坐、躺、睡、宠物都对），不压在脸上
			var crown:float=actor.position.y+actor.head_top();m.hot.pos=[actor.position.x,crown];m.hot.approach=[actor.position.x,actor.position.y]
		var h:Dictionary=m.hot;var distance:float=player.position.distance_to(world.nearest(World.v(h.approach)))
		# 门的气泡远一点也出、排在前面（二楼阿鱼衣柜去浴室的门原来被抽屉和衣架挤掉）
		var is_door:bool=h.has("target")
		# 屋里房间之间不出门的箭头；屋里通屋外的门（进家门、车库、手作房、去后花园）照旧有
		if is_door and not outdoors() and not area.begins_with("v_") and not bool(definitions.get(str(h.target),{}).get("outdoor",false)):continue
		if distance<(110 if is_door else 82):candidates.append({"m":m,"distance":distance*(.6 if is_door else 1.0)})
	candidates.sort_custom(func(a,b):return a.distance<b.distance)
	var speaking:=false;var speakers:Array=[]
	player.bubble_allowed=not busy()
	for id in people:
		people[id].bubble_allowed=false
		if not busy() and people[id].visible and people[id].bubble_time>0 and player.position.distance_to(people[id].position)<160:speakers.append(people[id])
	speakers.sort_custom(func(a,b):return a.position.distance_to(player.position)<b.position.distance_to(player.position))
	var speech:Array[Rect2]=[]
	for actor in speakers.slice(0,1):
		actor.bubble_allowed=true;speaking=true;speech.append(place_speech(actor,top_limit,bottom_limit))
	if player.bubble_time>0 and player.bubble_allowed:speech.append(place_speech(player,top_limit,bottom_limit))
	var xf:Transform2D=world.get_global_transform_with_canvas();var player_screen:Vector2=xf*player.position
	var player_rect:=Rect2(player_screen-Vector2(35,(84+player.lift)*view_scale*.5+70),Vector2(70,(84+player.lift)*view_scale*.5+76))
	# 第六轮第 7 条（阿鱼）：一个画面同一时间只出 1 个可点的提示，只留离玩家最近的那个；名字牌只挂在它下面
	# 第七轮补（01）：门前几步（DOOR_NEAR 画布像素）以内，门的提示一定出，不被旁边的物件、人挤掉
	var pick:Array=[]
	var best_d:=INF;var door_d:=INF;var door_pick:Array=[]
	for c in candidates:
		var real:float=player.position.distance_to(world.nearest(World.v(c.m.hot.approach)))
		if real<best_d:best_d=real;pick=[c]
		if c.m.hot.has("target") and real<DOOR_NEAR and real<door_d:door_d=real;door_pick=[c]
	if not door_pick.is_empty():pick=door_pick
	# 每个人的头和脸（屏幕上）：提示泡不压别人的头和脸
	var faces:Dictionary={}
	for a in [player]+people.values():
		if a.visible:faces[a]=face_rect(a,xf)
	var tag_for:Button=null;var tag_hot:Dictionary={};var visible_marker:Button=null
	for item in pick:
		var m:Dictionary=item.m;var h:Dictionary=m.hot;var b:Button=m.button;var is_person:=str(h.id).begins_with("person:")
		var raw:Vector2=xf*World.v(h.pos)
		var show_marker:bool=not busy() and raw.x>4 and raw.x<size.x-4 and raw.y>top_limit+14 and (raw.y<bottom_limit or (h.has("target") and raw.y<size.y+20)) # 门在屏幕最下沿也给气泡
		if not show_marker:continue
		var owner=people[str(h.id).substr(7)] if is_person else null
		# 第 22、23 条：「!」尖对着主人头顶，挨着主人；压到别人的头或脸就往左右挪一点（不超过一个泡宽），不往上飘到别人头上
		var base:Vector2=(raw-Vector2(b.size.x*.5,b.size.y+(2 if is_person else 14)))
		var p:Vector2=base
		for dx in [0.0,-30.0,30.0,-52.0,52.0,-74.0,74.0]:
			var q:=base+Vector2(dx,0)
			if q.x<6 or q.x>size.x-54:continue
			var clash:=false
			for a in faces:
				if a!=owner and faces[a].intersects(Rect2(q,b.size).grow(-3)):clash=true
			if not clash:p=q;break
		var behind_speech:=false
		for other in speech:
			if other.grow(4).intersects(Rect2(p,b.size)):behind_speech=true
		if behind_speech:continue # 有人在说话时，压在话泡上的提示先藏一下
		var tag_height:=0.0
		if not is_person and player.action=="idle":
			near_tag.text=str(h.get("label",""));near_tag.reset_size()
			tag_height=near_tag.get_combined_minimum_size().y+2.0 # 名字牌与气泡重叠2px，点击区再向外4px。
		b.position=p.clamp(Vector2(6,top_limit),Vector2(size.x-54,maxf(top_limit,bottom_limit-b.size.y-tag_height)));m.bubble.selected=true;m.bubble.queue_redraw()
		visible_marker=b
		if not is_person and player.action=="idle":tag_for=b;tag_hot=h
	# 只在最终状态变化时切换可见性，避免每帧隐藏按钮取消正在进行的按下/松开。
	for m in marker_nodes:m.button.visible=m.button==visible_marker
	# 名字牌只挂在这唯一的提示泡下面
	if tag_for:
		near_tag.text=str(tag_hot.get("label",""));near_tag.set_meta("hot",str(tag_hot.id));near_tag.reset_size();near_tag.size=near_tag.get_combined_minimum_size()
		near_tag.position=Vector2(clampf(tag_for.position.x+24-near_tag.size.x*.5,6,size.x-near_tag.size.x-6),tag_for.position.y+tag_for.size.y-2)
	near_tag.visible=tag_for!=null and near_tag.text.length()>0
	if scene_controls:place_scene_controls(size,top_limit,bottom_limit,speech)
## 一个人的头和脸在屏幕上占哪块（头顶往下 34、宽 30，坐、躺、宠物的头顶各按自己的算）
func face_rect(a,xf:Transform2D) -> Rect2:
	var w:=(20.0 if a.pet else 30.0);var hgt:=(24.0 if a.pet else 34.0)
	return Rect2(xf*(a.position+Vector2(-w*.5,a.head_top())),Vector2(w,hgt)*view_scale)
## 话泡整个放在说话的人头顶上，不压身体；头顶放不下（快碰到顶栏）就放到人身旁。返回屏幕上的位置。
## 第六轮第 9 条：话泡宽度随字数变、限在左右安全区里，不压任何人的头和脸（说话的、旁边的、后面的、玩家）。
## 先放说话的人头顶正上方；压到谁的头脸就左右挪（尾巴还对着说话的人）；再不行往上抬一点；再不行放到说话的人身旁（不要尾巴）
func place_speech(actor,top_limit:float,bottom_limit:float) -> Rect2:
	var size:=get_viewport_rect().size;var xf:Transform2D=world.get_global_transform_with_canvas();var label:Label=actor.bubble
	var safe_w:float=(size.x-16.0)/view_scale
	var head:Vector2=xf*(actor.position+Vector2(0,actor.head_top()))
	var faces:Array[Rect2]=[]
	for a in [player]+people.values():
		if a.visible:faces.append(face_rect(a,xf).grow(2))
	var half:=(14.0 if actor.pet else 20.0)*view_scale
	var chosen:Array=[];var s:=Vector2.ZERO
	# 挤的时候先试窄一点的泡（多换几行），再往上抬、往旁边挪，找一处谁的头脸都不压的地方
	for max_w in [minf(actor.BUBBLE_MAX,safe_w),100.0,76.0]:
		actor.fit_bubble(max_w);s=label.size*view_scale
		var tries:Array=[]
		for lift in [0.0,16.0,32.0,48.0,64.0,80.0]:
			for dx in [0.0,-.3,.3,-.5,.5]:
				tries.append([Vector2(head.x-s.x*.5+dx*s.x,head.y-s.y-12-lift),true])
		for dy in [0.0,-16.0,-32.0,-48.0,-64.0,-80.0,16.0,32.0]:
			tries.append([Vector2(head.x+half,head.y+dy),false]);tries.append([Vector2(head.x-half-s.x,head.y+dy),false])
		for t in tries:
			var p:Vector2=t[0]
			if p.x<8 or p.x+s.x>size.x-8 or p.y<top_limit or p.y+s.y>bottom_limit:continue
			var clash:=false
			for fr in faces:
				if fr.intersects(Rect2(p,s)):clash=true;break
			if not clash:chosen=t;break
		if not chosen.is_empty():break
	if chosen.is_empty():
		actor.fit_bubble(minf(actor.BUBBLE_MAX,safe_w));s=label.size*view_scale
		var p0:=Vector2(head.x-s.x*.5,head.y-s.y-12)
		chosen=[Vector2(clampf(p0.x,8,size.x-s.x-8),clampf(p0.y,top_limit,maxf(top_limit,bottom_limit-s.y))),true]
	var p:Vector2=chosen[0]
	label.position=xf.affine_inverse()*p-actor.position
	actor.set_tail((head.x-p.x)/view_scale,chosen[1] and absf(head.x-(p.x+s.x*.5))<s.x*.5-10)
	return Rect2(p,s)
## 坐下、躺下、踢球这些要点的按钮，排在人脚边一小排，不在屏幕最底下。
func place_scene_controls(size:Vector2,top_limit:float,bottom_limit:float,speech:Array) -> void:
	var xf:Transform2D=world.get_global_transform_with_canvas();var feet:Vector2=xf*(player.position-Vector2(0,0.0 if player.action in ["sleep","lie"] else player.lift)) # 按坐点摆，不按抬高后的脚
	scene_controls.reset_size();var s:Vector2=scene_controls.get_combined_minimum_size();scene_controls.size=s
	var p:=Vector2(feet.x-s.x*.5,feet.y+10)
	if p.y+s.y>bottom_limit:p.y=(xf*(player.position+Vector2(0,player.head_top()))).y-s.y-8
	for r in speech:
		if r.intersects(Rect2(p,s)):p.y=r.end.y+6
	scene_controls.position=Vector2(clampf(p.x,8,size.x-s.x-8),clampf(p.y,top_limit,maxf(top_limit,bottom_limit-s.y))).round()

func close_modal() -> void:
	if modal:modal.queue_free();modal=null
	if ui and ui.has_node("Bottom"):ui.get_node("Bottom").visible=true
	talk_label=null;talk_ui=null;talk_next=Callable();cooldown=.8
func modal_shell(heading:String,kind:="paper") -> VBoxContainer:
	close_modal();var page:=Page.new();modal=page;ui.add_child(page)
	return page.build(heading,close_modal,kind)

## 对话框（第七轮 村-1）：换成罗曼那套（组件库第 3 条）。框、头像、名字牌、字一个个出、一页 2 行和翻页三角，
## 都用共用的 scripts/ui/dialog_skin.gd（build_talk 和 Typer，跟罗曼同一份，改一处两边都变），这里只接上阿鱼家的人：
##   人物卡：点头像或名字牌打开；继续：点框任何地方（字还在出先出完，出完了下一句）；
##   跳过：剩 2 句以上没说时，框右上角骑在上边框上出一块「跳过」小牌（名字牌那一家），只剩 1 句时不出。
## 头像先用 portraits.png 顶着：画的立绘做图时已平滑缩成头像格那么大（tools/make_talk_faces.py），这里按 1 倍贴。
class TalkUI extends Control:
	const DS=preload("res://scripts/ui/dialog_skin.gd")
	var talk_box:PanelContainer
	var portrait:TextureRect
	var line_label:Label
	var hint_label:Label
	var choices:HBoxContainer
	var name_plate:PanelContainer
	var name_label:Label
	var card_btn:Button
	var talk_id:=""
	var talk_cv=null
	var talk_info:={}
	var m=null
	var home
	var skip:PanelContainer
	func open_card(id:String) -> void:home.talk_card(id)
	func life_of(_id:String):return null
	func _process(_dt:float) -> void:
		if not talk_box:return
		# Typer 照罗曼的像素小人放大 3 倍摆头像；阿鱼家的是已经缩好的立绘，按 1 倍贴回头像格
		if portrait.texture:
			portrait.stretch_mode=TextureRect.STRETCH_SCALE;portrait.size=portrait.texture.get_size()
			portrait.position=Vector2(roundf((DS.FACE.x-portrait.size.x)*.5),DS.FACE.y-portrait.size.y)
		if skip:
			skip.reset_size();skip.position=Vector2(talk_box.size.x-skip.size.x-DS.PAD,-skip.size.y*.5)
var talk_lines:Array=[]
var talk_index:=0
var talk_who:=""
var talk_face:=""
var talk_ui:TalkUI
func dialogue(who:String,line:String,portrait:="",next:Callable=Callable()) -> void:say_lines(who,[line],portrait,next)
func say_lines(who:String,lines:Array,portrait:="",next:Callable=Callable(),from:=0) -> void:
	close_modal()
	var t:=TalkUI.new();t.home=self;t.process_priority=1;t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);t.mouse_filter=Control.MOUSE_FILTER_STOP;modal=t;talk_ui=t;ui.add_child(t)
	DSkin.build_talk(t,UI.FONT)
	t.talk_box.gui_input.connect(func(e):
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:advance_dialogue();t.talk_box.accept_event())
	t.gui_input.connect(func(e):
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:advance_dialogue())
	t.talk_id=portrait;t.name_label.text=who;t.name_plate.visible=not portrait.is_empty() # 字条、旁白没有人：不出名字牌，名字写在话前面
	var typer:Node=t.talk_box.get_node_or_null("typer")
	if typer and typer.shown:typer.shown.add_theme_font_size_override("font_size",24) # 罗曼按它的整倍字体写 26（出来是 24）；阿鱼家的字体不整倍，直接用 24（村-7）
	var icon:Node=t.name_plate.find_child("card_icon",true,false)
	if icon:icon.visible=not portrait.is_empty()
	t.portrait.texture=Assets.texture("res://ayu_home/v4/assets/talk-faces/"+portrait+".png") if not portrait.is_empty() else null
	t.portrait.visible=t.portrait.texture!=null
	t.hint_label.text="点一下继续"
	# 跳过：名字牌那一家（深褐底、金棕双线）、米白字 24，点的范围不小于 88×44
	t.skip=PanelContainer.new();t.skip.name="skip";var sb:StyleBoxTexture=DSkin.plate_frame().duplicate()
	for side in [SIDE_LEFT,SIDE_RIGHT]:sb.set_content_margin(side,22)
	for side in [SIDE_TOP,SIDE_BOTTOM]:sb.set_content_margin(side,6)
	t.skip.add_theme_stylebox_override("panel",sb);t.skip.custom_minimum_size=Vector2(88,44);t.skip.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;t.skip.mouse_filter=Control.MOUSE_FILTER_STOP
	var sl:=DSkin.lbl("跳过",UI.FONT,24,Color(DSkin.PAL.text));sl.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;sl.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;t.skip.add_child(sl)
	t.skip.gui_input.connect(func(e):
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:t.skip.accept_event();finish_dialogue())
	t.talk_box.add_child(t.skip)
	talk_who=who;talk_face=portrait;talk_lines=lines;talk_index=clampi(from,0,maxi(lines.size()-1,0));talk_next=next
	t.talk_box.visible=true;ui.get_node("Bottom").visible=false
	show_talk_line()
func show_talk_line() -> void:
	if not talk_ui:return
	talk_line=str(talk_lines[talk_index]) if talk_index<talk_lines.size() else ""
	talk_ui.line_label.text=("“"+talk_line+"”") if not talk_face.is_empty() else (talk_who+"："+talk_line if not talk_who.is_empty() else talk_line);talk_label=talk_ui.line_label;talk_chars=0
	talk_ui.skip.visible=talk_lines.size()-1-talk_index>=2
## 人物卡：从对话里点头像、名字牌打开，「继续聊天」回到刚才那一句
func talk_card(id:String) -> void:
	var who:=talk_who;var lines:=talk_lines;var at:=talk_index;var next:=talk_next
	family_card(id,func():say_lines(who,lines,id,next,at))
func advance_dialogue() -> void:
	if not talk_ui:return
	var box:=talk_ui.talk_box
	if DSkin.typing(box):DSkin.finish(box);return
	if not DSkin.last_page(box):return # 一页放不下时点右边的上下三角翻页，点框不翻（罗曼就是这样）
	if talk_index+1<talk_lines.size():talk_index+=1;show_talk_line();return
	finish_dialogue()
func finish_dialogue() -> void:
	var cb:=talk_next;close_modal()
	if cb.is_valid():cb.call()
func portrait_image(id:String,width:=94,height:=132,bust:=false) -> TextureRect:
	var image:=TextureRect.new();image.custom_minimum_size=Vector2(width,height);image.size_flags_vertical=Control.SIZE_SHRINK_END;image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;image.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	if id=="mother":
		# 与当前行走同一形象的像素站姿；人物卡与对话共用，避免冒出旧立绘。
		var mother_portrait:=AtlasTexture.new();mother_portrait.atlas=Assets.texture("res://ayu_home/v2/assets/chr_mother.png")
		mother_portrait.region=Rect2(0,84,64,40 if bust else 84)
		image.texture=mother_portrait;return image
	var crop:=AtlasTexture.new();crop.atlas=Assets.texture("res://ayu_home/v4/assets/portraits.png");crop.region={"ayu":Rect2(90,55,370,535),"father":Rect2(580,18,385,572),"mother":Rect2(1048,50,413,550)}[id]
	if bust:crop.region=Rect2(crop.region.position+Vector2(crop.region.size.x*.12,0),Vector2(crop.region.size.x*.76,crop.region.size.y*.42)) # 只要头和肩，头像大一点
	image.texture=crop;return image

func navigation(group:="") -> void:
	if not await preload("res://ayu_home/v4/core/download_gate.gd").ensure(self,"panels"):return
	if village_ui!=null and group.is_empty():village_ui.show_page("地图");return
	if not group.is_empty():map_group=group
	var box:=modal_shell("家的地图")
	var tabs:=HBoxContainer.new();box.add_child(tabs)
	for tab in ["一楼","二楼","屋外"]:
		var b:=UI.button(tab,navigation.bind(tab));b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;tabs.add_child(b)
	var grid:=GridContainer.new();grid.columns=3;grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;grid.add_theme_constant_override("h_separation",8);grid.add_theme_constant_override("v_separation",8);box.add_child(grid)
	for id in definitions:
		var cfg:Dictionary=definitions[id]
		if cfg.group!=map_group:continue
		var card:=VBoxContainer.new();card.size_flags_horizontal=Control.SIZE_EXPAND_FILL;grid.add_child(card)
		var b:=UI.button("",func():admitted=true;close_modal();enter_room(id));b.custom_minimum_size=Vector2(132,92);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;card.add_child(b)
		# 小图在格子里居中、裁满（002）：盖满格子、多的裁掉，不再靠左留半格空；四边让出框线
		var thumb:=TextureRect.new();thumb.texture=Assets.texture("res://ayu_home/v4/assets/grove.png" if id=="grove" else (("res://ayu_home/v4/assets/floor1-redraw/" if int(definitions[id].floor)==1 else P)+"thumb_"+id+".png"));thumb.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;thumb.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;thumb.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;thumb.mouse_filter=Control.MOUSE_FILTER_IGNORE
		thumb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);thumb.offset_left=5;thumb.offset_top=5;thumb.offset_right=-5;thumb.offset_bottom=-5;b.add_child(thumb)
		var label:=UI.label(short_room(id).replace("后花园 · 果园 · 菜地","花园 / 果园 / 菜地"),16);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;card.add_child(label) # 短写法（跟「家里的人」一样），一格里不吊字
	box.add_child(UI.label("点房间就到门口",16))
func testing_panel() -> void:
	if not test_panel_enabled:return
	var box:=modal_shell("电脑试玩 · 时光与天气")
	box.add_child(UI.label("选完马上看变化，关闭面板继续走。",18))
	for group in ["时段","季节","天气"]:
		box.add_child(UI.label(group,23));var grid:=GridContainer.new();grid.columns=2;box.add_child(grid)
		var labels:Array;var values:Array
		if group=="时段":labels=["清晨 06:30","午间 12:15","傍晚 18:30","深夜 23:00"];values=[6.5,12.25,18.5,23.0]
		elif group=="季节":labels=["春 · 三月","夏 · 七月","秋 · 十月","冬 · 一月"];values=[3,7,10,1]
		else:labels=["晴天","阴天","雨天","雪天"];values=["clear","cloud","rain","snow"]
		for i in labels.size():
			var val=values[i];var b:=UI.button(labels[i],func():set_test_clock(float(val) if group=="时段" else hour,int(val) if group=="季节" else month,str(val) if group=="天气" else weather);close_modal());b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;grid.add_child(b)
	var row:=HBoxContainer.new();box.add_child(row)
	row.add_child(UI.button("现实时间",func():test_hour=-1;test_month=0;test_weather="";read_clock();sync_family(true);close_modal()))
	row.add_child(UI.button("生活册",life_book))
	var absences:=HBoxContainer.new();box.add_child(absences)
	for item in [["全家外出",9.5],["爸爸外出",10.5],["妈妈外出",14.5]]:absences.add_child(UI.button(item[0],func():set_test_clock(item[1],month,weather);close_modal()))
func life_book() -> void:
	if not await preload("res://ayu_home/v4/core/download_gate.gd").ensure(self,"panels"):return
	var box:=modal_shell("家的生活册")
	box.add_child(UI.stamp("你的房间一直留着" if life.data.resident else "从今天起，收好在这里的日子"))
	var chapters:=GridContainer.new();chapters.columns=2;box.add_child(chapters)
	for item in [["家的收集",collection_page],["今日小事",today],["拍立得相册",album_page],["这个月的日历",calendar_page],["家里的人",family_page],["阿鱼的来信",welcome]]:
		var b:=UI.button(item[0],item[1]);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;chapters.add_child(b)
	box.add_child(UI.divider());box.add_child(UI.label("留在家里的小记",22))
	var count:=0
	for id in life.data.cards:
		if Life.SPECIAL.has(id):box.add_child(UI.paragraph("✦ "+Life.SPECIAL[id],19));count+=1
	for wish in life.data.wishes:box.add_child(UI.paragraph("星空愿望 · "+str(wish.text),18));count+=1
	for plot in life.data.plots+life.data.trees:
		if plot.has("crop"):box.add_child(UI.paragraph(Life.CROPS[plot.crop].name+" · "+life.stage(plot),19));count+=1
	if not life.data.photos.is_empty():box.add_child(UI.paragraph("拍立得相册里，已经收好 %d 张合影。"%life.data.photos.size(),19));count+=1
	for entry in [["tea","沏过的茶，暖意留在杯子里。"],["soup","煮好的汤，给家里添了一道菜。"],["laundry","洗过的衣服，正在晾衣处等风。"],["wood","磨好的小木鸟，留在窗台边。"]]:
		if int(life.data.completed.get(entry[0],0))>0:box.add_child(UI.paragraph(entry[1],19));count+=1
	if life.cats_today()>0:count+=1
	if count==0:box.add_child(UI.paragraph("这一页还等着第一件小事：浇一畦菜、陪猫坐一会儿，或给今天拍一张照片。",20))
	box.add_child(UI.paragraph("今天找到的猫 · "+str(life.cats_today())+" / 3",18))
func family_page() -> void:
	if not await preload("res://ayu_home/v4/core/download_gate.gd").ensure(self,"panels"):return
	var box:=modal_shell("家里的人")
	for id in Data.FAMILY:
		var panel:=PanelContainer.new();box.add_child(panel);var row:=HBoxContainer.new();panel.add_child(row)
		# 第六轮第 3 条（阿鱼）：头像下面写现在在哪，跟家人真的在的地方一致，每次打开都是最新的
		var face_col:=VBoxContainer.new();face_col.add_theme_constant_override("separation",4);row.add_child(face_col);face_col.add_child(portrait_image(id,86,116))
		var where:=UI.label(where_is(id),24);where.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;where.custom_minimum_size.x=124;face_col.add_child(where) # 5 个字一行（「在」+ 最多 4 个字的房间名），不再自己折行
		var words:=VBoxContainer.new();words.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(words);words.add_child(UI.label(NAMES[id],24))
		words.add_child(UI.paragraph({"ayu":"喜欢读书、音乐和猫。\n把慢日子留在这个家。","father":"常在手作房与果园。\n木头磨亮了，心也静了。","mother":"照看厨房，也照看每个人。\n一锅热汤，是小小心意。"}[id],18))
		var target:String=id;var b:=UI.button("去找"+NAMES[id],func():close_modal();tracked_person=target);b.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;words.add_child(b)
## 家人现在在哪：外出 / 在睡觉 / 在某个房间（读的是家人此刻真的在的房间）
func where_is(id:String) -> String:
	var st:Dictionary=family_state.get(id,{})
	var room:String=str(st.get("room",schedule(id).area))
	var action:String=str(st.get("action",schedule(id).action))
	if room=="away" or schedule(id).area=="away" and room=="exterior" and not st.get("route",PackedVector2Array()).is_empty():return "外出"
	if not definitions.has(room):return "外出"
	# 第 29 条：头像下面那一列窄，房间名用短写法（最多 4 个字，「在」+ 名字一行放得下，不吊着一个字）；
	# 躺下歇着和睡觉写法一样，都是两行：「在爸妈卧室」「睡觉」
	var where:="在"+short_room(room)
	if action in ["sleep","rest"] and st.get("route",PackedVector2Array()).is_empty() and room==str(st.get("goal","")):return where+"\n睡觉"
	return where
const SHORT_ROOM:={"laundry":"卫生间","cats":"猫窝走道","mahjong":"麻将室","workshop":"手作房","closet1":"东侧过道","bath1":"爸妈浴室","guest_closet":"衣帽间","stairs2":"二楼过道","closet2":"阿鱼衣柜","bath2":"阿鱼浴室","garden":"后花园","grove":"树林"}
func short_room(room:String) -> String:return str(SHORT_ROOM.get(room,definitions[room].title))
func family_card(id:String,back:Callable=Callable()) -> void:
	var box:=modal_shell(NAMES[id]+"的小卡片")
	var row:=HBoxContainer.new();box.add_child(row);row.add_child(portrait_image(id,146,209));var words:=VBoxContainer.new();words.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(words)
	words.add_child(UI.stamp("阿鱼家的家人"));words.add_child(UI.label(NAMES[id],28))
	words.add_child(UI.paragraph({"ayu":"喜欢猫、书和窗边小曲。","father":"爱做手作，也照料果树。","mother":"照看一锅汤，也记得照看每个人。"}[id],20))
	var st:Dictionary=schedule(id);words.add_child(UI.paragraph("现在出门了，回来再聊。" if st.area=="away" else "这会儿在家，慢慢聊。",17))
	box.add_child(UI.divider())
	for task in life.daily_tasks():
		if task.host==id:box.add_child(UI.paragraph("今天的小事 · "+task.text+"\n"+("你做的这份心意，已经好好收到了。" if task.thanked else "有空再做，也没关系。"),20))
	box.add_child(UI.button("继续聊天" if back.is_valid() else "收好卡片",back if back.is_valid() else close_modal))
func calendar_page() -> void:
	if not await preload("res://ayu_home/v4/core/download_gate.gd").ensure(self,"panels"):return
	var box:=modal_shell("家里的挂历")
	var now:=Time.get_datetime_dict_from_system();var year:int=now.year
	box.add_child(UI.stamp("%d 年 %d 月 · %s"%[year,month,Data.SEASONS[Data.season(month)]]))
	var grid:=GridContainer.new();grid.columns=7;grid.add_theme_constant_override("h_separation",4);grid.add_theme_constant_override("v_separation",5);box.add_child(grid)
	for name in ["日","一","二","三","四","五","六"]:var l:=UI.label(name,18);l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;l.custom_minimum_size=Vector2(56,28);grid.add_child(l)
	var date:=Time.get_unix_time_from_datetime_dict({"year":year,"month":month,"day":1,"hour":12,"minute":0,"second":0});var first:int=Time.get_datetime_dict_from_unix_time(date).weekday
	for i in first:var empty:=Control.new();empty.custom_minimum_size=Vector2(56,42);grid.add_child(empty)
	var days:int=[31,29 if year%4==0 and (year%100!=0 or year%400==0) else 28,31,30,31,30,31,31,30,31,30,31][month-1]
	for n in range(1,days+1):
		var l:=UI.label(str(n),20);l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;l.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;l.custom_minimum_size=Vector2(56,42)
		if n==day:l.add_theme_stylebox_override("normal",UI.card_box());l.add_theme_color_override("font_color",Color(DSkin.PAL.name)) # 今天：金棕双线小框、名字黄
		grid.add_child(l)
	box.add_child(UI.divider());box.add_child(UI.paragraph("今日饭桌 · "+"、".join(life.meal_menu(month)),20));box.add_child(UI.paragraph("这一季能种："+"、".join(life.available(month,"vegetable").map(func(x):return Life.CROPS[x].name))+"。种子在后园等你，离线也会慢慢长。",18));box.add_child(UI.button("看看今天的小事",today))

func detail_view() -> void:
	immersive.open("detail" if area=="study" else "room_detail",{"room":area,"title":world.cfg.title,"hour":hour,"month":month,"weather":weather,"cfg":world.cfg})
func stop_audio() -> void:
	for a in [amb,sfx,water_audio]:
		if a:a.stop();a.stream=null
func _exit_tree() -> void:
	if is_instance_valid(village_ui):village_ui.checkpoint()
	stop_audio()
	if life:life.close_open()
	if life:
		if world and not world.cfg.is_empty():room_state[area]={"lamp":world.lamp_on,"tv":world.tv_on,"toggles":world.toggles.duplicate()}
		life.data.effects.rooms=room_state.duplicate(true);life.data.last_seen=life.now();life.save()
	for key in nav_cache:nav_cache[key].free()

func nav(room:String):
	if room==area:return world
	if not nav_cache.has(room):
		var w=World.new();w.nav_only=true;w.load_room(room);w.set_process(false);nav_cache[room]=w # 只算路，不读图
	return nav_cache[room]
func room_hop(start:String,finish:String) -> String:
	if start==finish:return finish
	var queue:Array=[start];var seen:Dictionary={start:""}
	while not queue.is_empty():
		var room:String=queue.pop_front()
		for doorway in definitions[room].doors:
			var next:String=doorway.target
			if seen.has(next):continue
			seen[next]=room
			if next==finish:
				while seen[next]!=start:next=seen[next]
				return next
			queue.append(next)
	return start
func update_family_walk(dt:float) -> void:
	for id in Data.FAMILY:
		if not family_state.has(id):continue
		var record:Dictionary=family_state[id];var goal:String=record.goal
		if record.room=="away":
			people[id].visible=false
			if goal!="away":record.room="exterior";record.pos=nav("exterior").nearest(Vector2(743,989));record.route=PackedVector2Array()
			else:continue
		var destination:String="exterior" if goal=="away" else goal
		var w=nav(record.room)
		if record.route.is_empty():
			if record.room!=destination:
				var hop:=room_hop(record.room,destination);record.door="to_"+hop
				var doorway:Dictionary=w.spot(record.door)
				if not doorway.is_empty():
					record.route=w.path(record.pos,World.v(doorway.approach));record.action="walk"
					if record.door in ["to_stairs1","to_stairs2"] and w.cfg.has("stair_path"):
						record.route=w.path(record.pos,World.v(w.cfg.stair_path[0]))
						for step in w.cfg.stair_path:record.route.append(World.v(step))
			elif goal=="away":
				if record.pos.distance_to(Vector2(743,989))<16:record.room="away";continue
				record.route=w.path(record.pos,Vector2(743,989));record.door="";record.action="walk"
			elif record.pos.distance_to(w.nearest(record.final_pos))>8 and record.action!=record.final_action:
				record.route=w.path(record.pos,record.final_pos);record.door="";record.action="walk"
			else:record.action=record.final_action;record.face=record.final_face
		var budget:float=minf(dt,.15)*60
		while budget>0 and not record.route.is_empty():
			var next:Vector2=record.route[0];var diff:Vector2=next-record.pos
			if diff.length()<=budget:budget-=diff.length();record.pos=next;record.route.remove_at(0)
			else:record.pos+=diff.normalized()*budget;budget=0
			if diff.length()>.1:record.face="right" if absf(diff.x)>absf(diff.y) and diff.x>0 else ("left" if absf(diff.x)>absf(diff.y) else ("down" if diff.y>0 else "up"))
		if record.route.is_empty() and not str(record.door).is_empty():
			var doorway:Dictionary=w.spot(record.door);var old:String=record.room
			if not doorway.is_empty():
				record.room=doorway.target;var target_nav=nav(record.room);var reciprocal:Dictionary=target_nav.spot("to_"+old)
				record.pos=target_nav.nearest(World.v(reciprocal.approach)+dir(str(reciprocal.face))*28) if not reciprocal.is_empty() else target_nav.spawn()
				record.door=""
		var a=people[id];a.visible=record.room==area
		if a.visible:
			a.position=record.pos;a.face=record.face;a.action=record.action;a.walking=not record.route.is_empty()
			if a.action=="eat":a.position=anchor(area,id+"_meal");a.face=schedule(id).face
			elif a.action in ["sleep","tv","read","mahjong"] and record.room==record.goal:a.position=record.final_pos
			if elapsed<float(record.get("reaction_until",0)):a.action=record.get("reaction","talk")
			var lying:bool=a.action in ["sleep","rest"] and record.room==record.goal and record.route.is_empty()
			if lying:put_in_bed(id,a)
			else:
				if a.in_bed:a.in_bed=false
				# 家人坐下（沙发上看书看电视、饭桌、书桌）也跟玩家一样：排到家具前面，再抬回坐垫上
				var seated:bool=a.action in ["tv","read","eat","computer","record","guitar","sit","drink","mahjong"] and record.route.is_empty()
				a.lift=seat_lift(a.position) if seated else 0.0
				a.position+=Vector2(0,a.lift)
func update_pets(dt:float) -> void:
	for id in ["qiuqiu","luoluo","tiantian","xiduo"]:
		var a=people[id]
		if not a.visible:continue
		if id=="xiduo" and ball_phase!="idle":continue
		if id=="xiduo" and area=="exterior" and dog_play_wait<2.5:continue # 快去追球了，先别乱走
		a.move_along(dt,35)
		if a.route.is_empty() and a.cooldown<=0:
			var p:Vector2=world.nearest(a.position+Vector2(sin(elapsed+id.length())*44,cos(elapsed+id.length())*24))
			a.route=world.path(a.position,p);a.destination_action="lie" if id!="xiduo" else "sniff";a.cooldown=18
func clear_scene_controls() -> void:
	if scene_controls:scene_controls.queue_free();scene_controls=null
func scene_buttons(actions:Array) -> void:
	# 一小排按钮跟在人脚边（每帧在 place_scene_controls 里摆），不再横在屏幕最底下
	clear_scene_controls();scene_controls=PanelContainer.new();scene_controls.add_theme_stylebox_override("panel",StyleBoxEmpty.new());scene_controls.mouse_filter=Control.MOUSE_FILTER_IGNORE;actions_layer.add_child(scene_controls)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",6);scene_controls.add_child(row)
	for item in actions:
		var b:=UI.button(item[0],item[1],item==actions[0]);b.custom_minimum_size=Vector2(88 if item==actions[0] else 0,48);row.add_child(b) # 头一个是主按钮（红），别的是次按钮
	scene_controls.modulate.a=0;scene_controls.create_tween().tween_property(scene_controls,"modulate:a",1.0,.15)
	if bootstrapped:layout_markers()
## 家具在这个点上真的画着东西吗（看贴图透明度）。用来判断坐下、躺下时人该排在哪件家具前面。
func prop_covers(p:Dictionary,at:Vector2) -> bool:
	var tex:Texture2D=p.sprite.texture
	if tex==null:return false
	# 床面取色仍缓存原贴图；图集、缩放、翻转和家具轻微位移按 Sprite2D 的真实像素检测。
	if not tex is AtlasTexture and not prop_images.has(tex.get_instance_id()):prop_images[tex.get_instance_id()]=tex.get_image()
	return p.sprite.is_pixel_opaque(p.sprite.to_local(world.to_global(at)))
## 坐点被哪件家具画着、而那件家具的前沿比坐点靠下：人要排到它前面，再把画面抬回坐点。
func seat_lift(at:Vector2) -> float:
	var lift:=0.0
	for p in world.props:
		var foot:float=float(p.config.foot)
		if foot>at.y and prop_covers(p,at):lift=maxf(lift,foot-at.y+2)
	return minf(lift,240)
## 物件自己没写坐点时，用旁边最近的座位（沙发、书桌前的椅子、茶桌边的椅子）。
func seat_point(h:Dictionary) -> Dictionary:
	if h.has("seat"):return {"at":World.v(h.seat),"face":str(h.get("face","down"))}
	var best:={};var distance:=100.0
	for other in world.cfg.hotspots:
		if other.has("seat") and other.id!=h.id:
			var d:float=World.v(other.seat).distance_to(World.v(h.pos))
			if d<distance:distance=d;best={"at":World.v(other.seat),"face":str(other.get("face","down"))}
	return best if not best.is_empty() else {"at":World.v(h.pos),"face":str(h.get("face","down"))}
func place_seated(at:Vector2) -> void:
	var lift:=seat_lift(at);player.lift=lift;player.position=at+Vector2(0,lift)
## 躺下：头枕在这张床的枕头上，被子颜色取自床面。
func bed_pose(h:Dictionary) -> Dictionary:
	var at:=World.v(h.pos);var best:={};var size:=0.0
	for p in world.props:
		if prop_covers(p,at):
			var s:Vector2=p.sprite.texture.get_size()
			if s.x*s.y>size:size=s.x*s.y;best=p
	if best.is_empty():return {"at":at,"lift":seat_lift(at),"color":Color(0,0,0,0)}
	var r:=Rect2(World.v(best.config.pos),best.sprite.texture.get_size())
	# 床头在上（枕头在上半截）还是床头在下（新一楼爸妈的床，枕头在下半截）：物件上写 head_dir
	var head_down:=str(h.get("head_dir","up"))=="down"
	var head:=Vector2(round(r.get_center().x),round(r.position.y+r.size.y*(.5 if head_down else .34)))
	var color:=Color(0,0,0,0);var img:Image=prop_images.get(best.sprite.texture.get_instance_id())
	if img:color=img.get_pixelv(Vector2i(Vector2(r.size.x*.5,r.size.y*(.3 if head_down else .62))).clamp(Vector2i.ZERO,img.get_size()-Vector2i.ONE))
	# 被子直接用这张床被面的一截（贴在人肩膀上），花色跟床一样
	var strip:=Rect2(Vector2(r.size.x*.5-25,r.size.y*(.22 if head_down else .6)).round(),Vector2(50,12))
	return {"at":head,"lift":float(best.config.foot)-head.y+2,"color":color,"down":head_down,"quilt_tex":best.sprite.texture,"quilt_region":strip}
## 家人睡觉：头枕在这张床的枕头上，爸妈一左一右，盖同一床被子
func put_in_bed(id:String,a) -> void:
	var bed_spot:Dictionary={}
	for h in world.cfg.hotspots:
		if str(h.get("kind","")) in ["bed","stay"]:bed_spot=h;break
	if bed_spot.is_empty():return
	var bed:=bed_pose(bed_spot);var side:float={"father":-22.0,"mother":22.0}.get(id,0.0)
	a.in_bed=true;a.lift=bed.lift;a.head_down=bed.get("down",false);a.blanket=bed.color;a.quilt_tex=bed.get("quilt_tex");a.quilt_region=bed.get("quilt_region",Rect2());a.position=bed.at+Vector2(side,bed.lift);a.face="down"
func sit_at(h:Dictionary) -> bool:
	var spot:=seat_point(h);var seat:Vector2=spot.at
	for id in Data.FAMILY:
		if people[id].visible and people[id].position.distance_to(seat)<28:player.say(NAMES[id]+"正坐在这里，旁边还有位置。" );return false
	rest_position=player.position;player.route.clear();player.action="sit";player.face=spot.face;place_seated(seat);player.destination_action="sit"
	player.say("坐一会儿，慢慢来。" );scene_buttons([["起身",stand_up]]);life.event("sit");return true
func lie_down(h:Dictionary) -> void:
	var bed:=bed_pose(h)
	rest_position=player.position;player.route.clear();player.action="sleep";player.face="down";player.destination_action="sleep";player.lift=bed.lift;player.blanket=bed.color;player.quilt_tex=bed.get("quilt_tex");player.quilt_region=bed.get("quilt_region",Rect2());player.head_down=bed.get("down",false);player.position=bed.at+Vector2(0,bed.lift)
	note="睡一小觉，时间照常走";scene_buttons([["醒来",func():player.say("醒来啦，慢慢伸个懒腰");stand_up();life.event("sleep")]])
	fade.color=Color(.08,.08,.15,.8);create_tween().tween_property(fade,"color:a",0,1.4);life.event("lie")
func stay_choices(h:Dictionary) -> void:
	if life.data.resident:lie_down(h);return
	scene_buttons([["留宿住下",func():clear_scene_controls();life.data.resident=true;life.card("stay");life.save();dialogue("阿鱼","客房以后就是你的房间啦。到了饭点，我们叫你下来吃饭。","ayu",func():lie_down(h))],["先躺一会儿",func():lie_down(h)],["再逛逛",clear_scene_controls]])
	player.say("房间收拾好了，想留下来住吗？")
func drink_water(h:Dictionary) -> void:
	if not sit_at(h):return
	player.action="drink";scene_until=elapsed+6;scene_action="drink";player.say("吹一吹，温度刚刚好。" );life.event("drink")
func eat_together(h:Dictionary) -> void:
	rest_position=player.position;player.position=anchor("dining","guest_meal");player.action="eat";player.face="down";player.route.clear();world.food_until=world.elapsed+120;life.card("meal");life.event("meal")
	note="菜上桌啦，慢慢吃";player.say("今天有"+"、".join(life.meal_menu(month))) # 菜名长，放进话泡（会折行），提示条只占一行
	scene_buttons([["给家人夹菜",serve_family],["碰个杯",cheers],["起身",stand_up]])
func serve_family() -> void:
	var hosts:Array=[]
	for id in Data.FAMILY:
		if people[id].visible:hosts.append(id)
	if hosts.is_empty():player.say("留好一份，等家人回来一起吃。" );return
	var host:String=hosts[int(scene_progress)%hosts.size()];scene_progress+=1;player.action="eat";family_state[host].reaction_until=elapsed+4;family_state[host].reaction="eat";people[host].say({"ayu":"谢谢你，也夹一块给你。","father":"这道菜香，趁热吃。","mother":"慢慢吃，锅里还有呢。"}[host]);life.event("serve")
func cheers() -> void:
	player.action="drink";scene_until=elapsed+4;scene_action="meal_drink"
	for id in Data.FAMILY:
		if people[id].visible:people[id].say("为今天这顿热饭，碰个杯。" );people[id].action="drink";family_state[id].reaction="drink";family_state[id].reaction_until=elapsed+4
	life.event("cheers");play_sound("switch")
func watch_tv(h:Dictionary) -> void:
	rest_position=player.position;place_seated(anchor("living","guest_seat"));player.action="tv";player.face="right";player.route.clear();world.tv_on=true;scene_action="tv";scene_until=elapsed+120
	scene_buttons([["换个节目",change_channel],["关电视",func():world.tv_on=false;stand_up()],["起身",stand_up]]);change_channel()
func change_channel() -> void:
	world.tv_channel=(world.tv_channel+1)%3;var title:String=["院子的一天","猫咪日记","雨落在花园"][world.tv_channel]
	note="电视在播 · "+title
	for id in Data.FAMILY:
		if people[id].visible:people[id].say({"ayu":["这个小院子，想慢慢看完。","它又藏到花盆后面啦。","雨声很好听。"],"father":["树下那张椅子挺舒服。","猫走得比我们轻。","明天去看看园子。"],"mother":["今天也有个晴朗的午后。","等会儿看看猫粮够不够。","衣服记得收回来。"]}[id][world.tv_channel])
	life.event("tv")
func bath(h:Dictionary) -> void:
	world.toggles[h.id]=true;scene_action="shower";scene_until=elapsed+5;player.action="wash";player.say("关好门，洗个暖暖的澡。" );fade.color=Color(.1,.13,.17,.82)
	var tw:=create_tween();tw.tween_interval(1.4);tw.tween_property(fade,"color:a",0,1);life.event("shower")
	scene_buttons([["关好淋浴",func():world.toggles[h.id]=false;scene_until=0;scene_action="";player.action="idle";world.steam_player_until=world.elapsed+9;clear_scene_controls()]])
func nearest_pet() -> String:
	var best:="qiuqiu";var distance:=INF
	for id in ["qiuqiu","luoluo","tiantian"]:
		if people[id].visible and people[id].position.distance_to(player.position)<distance:best=id;distance=people[id].position.distance_to(player.position)
	return best
func pet_scene(id:String,play:=false) -> void:
	if not people.has(id) or not people[id].visible:player.say("它这会儿在别的房间，去找找吧。" );return
	var a=people[id];a.route.clear();a.action="happy";a.cooldown=25;life.pet(id)
	a.say({"qiuqiu":"先闻闻你的手……呼噜。","luoluo":"喵！翻个肚皮给你看。","tiantian":"尾巴慢悠悠地晃一下。","xiduo":"汪！尾巴摇起来了。"}[id]);player.face="up";player.action="pet";scene_until=elapsed+4;scene_action="pet"
	if play:a.route=world.path(a.position,player.position+Vector2(28,12));a.destination_action="happy";life.event("pet_play")
	scene_buttons([["喂狗零食" if id=="xiduo" else "喂猫条",func():a.route=world.path(a.position,player.position+Vector2(24,0));a.destination_action="sniff";a.say("好吃！" );life.event("pet_food");player.action="pet"],["踢球" if id=="xiduo" else "逗一逗",func():start_ball() if id=="xiduo" else pet_scene(id,true)],["继续逛",clear_scene_controls]])
func start_ball() -> void:
	if area!="exterior":return
	if ball_phase in ["dog_chase","dog_roll"]:ball_phase="idle";people.xiduo.route.clear() # 你来陪它玩，它就停下自己那一局
	if ball_phase=="idle":ball_position=world.nearest(player.position+Vector2(40,0));ball_origin=player.position
	people.xiduo.action="sniff";people.xiduo.say("汪！球来啦。" );note="踢一脚，喜多会叼回来"
	scene_buttons([["踢一脚",kick_ball],["摸摸喜多",func():pet_scene("xiduo")],["继续逛",clear_scene_controls]])
func kick_ball() -> void:
	if ball_phase!="idle" or player.position.distance_to(ball_position)>100:player.say("走近一点，再轻轻踢。" );return
	var direction:Vector2=dir(player.face)
	if not world.walkable(ball_position+direction*75):direction=Vector2.LEFT if ball_position.x>900 else Vector2.RIGHT
	ball_velocity=direction*210;ball_phase="roll";ball_origin=player.position;play_fx("kick")
## 第六轮第 12 条（阿鱼）：走近喜多偶尔叫一声——不是每次（走近时三成机会、叫过 25 秒内不再叫），声音小；关了声音就不响
func update_bark() -> void:
	var dog=people.get("xiduo")
	var near:bool=dog!=null and dog.visible and player.position.distance_to(dog.position)<70
	if near and not dog_near and elapsed>=bark_next:
		bark_next=elapsed+25.0
		if randf()<.35:play_fx("bark")
	dog_near=near
func update_ball(dt:float) -> void:
	world.ball_visible=area=="exterior";world.ball_position=ball_position
	if area!="exterior":return
	var dog=people.xiduo
	if ball_phase=="idle" and not world.walkable(ball_position):ball_position=world.nearest(ball_position) # 球原来摆在花坛边上，挪到能走到的地上
	# 喜多自己玩球：走到球边、用鼻子轻轻一拱，球慢慢滚出去，它再小跑着去追（动作温和）
	if ball_phase=="idle" and dog.visible and not (hour<7 or hour>=22) and scene_action!="pet" and player.position.distance_to(ball_position)>70:
		dog_play_wait-=dt
		if dog_play_wait<=0:ball_phase="dog_chase";dog.route=world.path(dog.position,world.nearest(ball_position+Vector2(-16,4)));dog.destination_action="sniff"
	if ball_phase=="dog_chase":
		dog.move_along(dt,70)
		if dog.route.is_empty():
			var dirv:=Vector2.from_angle(randf()*TAU)
			for k in 8:
				if world.walkable(ball_position+dirv*60):break
				dirv=dirv.rotated(TAU/8)
			ball_velocity=dirv*95;ball_phase="dog_roll";dog.action="happy"
	elif ball_phase=="dog_roll":
		var mv:Vector2=ball_velocity*minf(dt,.12);var cnt:=maxi(1,int(ceil(mv.length()/3)))
		for i in cnt:
			if world.walkable(ball_position+mv/cnt):ball_position+=mv/cnt
			else:ball_velocity=-ball_velocity*.3;break
		ball_velocity*=exp(-dt*2.4)
		if ball_velocity.length()<10:ball_phase="idle";dog_play_wait=3.0+randf()*4.0
	if ball_phase=="roll":
		var motion:Vector2=ball_velocity*minf(dt,.12);var count:=maxi(1,int(ceil(motion.length()/3)))
		for i in count:
			if world.walkable(ball_position+motion/count):ball_position+=motion/count
			else:ball_velocity=-ball_velocity*.25;break
		ball_velocity*=exp(-dt*2.2)
		if ball_velocity.length()<15:ball_phase="fetch";dog.route=world.path(dog.position,ball_position)
	elif ball_phase=="fetch":
		dog.move_along(dt,118)
		if dog.route.is_empty():ball_phase="return";dog.route=world.path(dog.position,player.position+Vector2(26,0))
	elif ball_phase=="return":
		dog.move_along(dt,108);ball_position=dog.position+Vector2(14,-9)
		if dog.route.is_empty():ball_position=world.nearest(player.position+Vector2(27,8));ball_phase="idle";ball_return_count+=1;dog.say("汪！再来一次？" );life.event("football")
func read_book(h:Dictionary) -> void:
	if not sit_at(h):return
	player.action="read";scene_progress=0;book_page()
func book_page() -> void:
	var pages:=["窗边的观察笔记：一只麻雀落在枝头，歪着头看了一会儿。","把一颗种子放进土里，也把一点期待留给了明天。","树影慢慢挪过地板，猫把自己翻到另一面晒太阳。","不赶时间的时候，连一杯水都能慢慢喝完。"]
	player.say(pages[int(scene_progress)%pages.size()]);scene_progress+=1
	scene_buttons([["翻下一页",book_page],["夹好书签",func():life.event("read");life.data.effects.bookmark=int(scene_progress);life.save();stand_up()]])
func start_work(h:Dictionary) -> void:
	if not sit_at(h):return
	player.action="computer";scene_action="computer";scene_until=elapsed+18;scene_progress=0;note="在电脑前整理小文档"
	scene_buttons([["敲下一行",func():scene_progress+=1;play_sound("switch");player.say(["整理今天的材料。","记下一点新的想法。","把文件分好类别。","保存好了。"] [mini(3,int(scene_progress)-1)]);if scene_progress>=4:life.event("work");life.data.effects.work=true;life.save()],["起身",stand_up]])
func recipe() -> void:
	var box:=modal_shell("今天的家常菜")
	for dish in life.meal_menu(month):box.add_child(UI.label("● "+str(dish),24))
	var ingredients:=UI.label(["萝卜、豌豆、豆腐","番茄、黄瓜、鸡蛋","南瓜、胡萝卜、菌菇","白菜、菠菜、豆腐"][Life.season(month)]+"
调味：一小撮盐，一勺清水。",20);ingredients.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(ingredients)
	var words:=UI.label("洗净蔬菜，切小块，小火慢煮。去厨房动手煮一锅汤，饭桌上就会多一份你做的味道。",21);words.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(words)
func pantry() -> void:
	var shell:=modal_shell("厨房里的收成")
	var box:=VBoxContainer.new();box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;shell.add_child(box)
	for crop in life.data.basket:
		if int(life.data.basket[crop])>0:box.add_child(UI.label(Life.CROPS[crop].name+" × "+str(int(life.data.basket[crop])),22))
	box.add_child(UI.label("妈妈的备菜和你收的菜，都留在这里。",18))
func pick_flowers() -> void:
	var key:String="flowers_"+life.date_key()
	if not life.data.effects.has(key):
		for crop in life.available(month,"flower"):life.data.basket[crop]=int(life.data.basket.get(crop,0))+1
		life.data.effects[key]=true;life.save();player.say("各摘一枝就好，留一些给风和蜜蜂。" )
	else:player.say("今天的三枝已经在篮子里，回家插一瓶吧。" )
	if Life.season(month)==0:life.card("spring")
	life.event("pick_flowers");scene_buttons([["在这里试试插花",func():games.open("flowers",life,{"month":month,"sound":sound_on})],["收好回家",clear_scene_controls]])
func update_scene_action(dt:float) -> void:
	if scene_until>0 and elapsed>=scene_until:
		if scene_action=="shower":
			for id in world.toggles:
				if world.spot(id).get("kind","")=="shower":world.toggles[id]=false
			player.say("暖暖的水汽，还在头顶。" );world.steam_player_until=world.elapsed+9;player.action="idle";clear_scene_controls()
		elif scene_action=="meal_drink":player.action="eat"
		elif scene_action not in ["computer","tv"]:player.action="idle"
		if scene_action=="music":games.sound.stop();clear_scene_controls()
		scene_until=0;scene_action=""
	if scene_action=="music" and int(elapsed*2)!=int((elapsed-dt)*2):games.tone(int(elapsed*2)%5,.11)
func finish_life_game(kind:String,outcome:Dictionary) -> void:
	life.event(kind)
	for key in ["soup","laundry","wood","tea"]:
		if outcome.get(key,false):life.data.effects[key]=true
	if outcome.get("soup",false):life.data.effects.soup_date=life.date_key() # 只有煮汤这天，饭桌上的汤才是这锅汤
	if outcome.has("flowers"):life.data.flower_vase=outcome.flowers;life.event("flowers")
	if outcome.get("keep",false):
		life.data.fish.append({"name":outcome.fish,"at":life.now()})
		if village_ui!=null:village_ui.state.act("fishing_reward",{"id":str(life.data.fish.size())+":"+str(life.data.fish[-1].at)})
	if kind=="tea":rest_position=player.position;player.action="drink";scene_action="drink";scene_until=elapsed+8;mother_reaction("drink",8)
	elif outcome.get("laundry",false):mother_reaction("laundry",6)
	elif not outcome.is_empty():mother_reaction("happy")
	if kind=="stars":life.card("moon")
	life.save()
func check_meal_invite() -> void:
	if not life.data.resident or invite_panel or busy():return
	var key:String=life.invite_key(hour)
	if key.is_empty() or life.data.invites.has(key):return
	var hosts:=Data.at_home(hour)
	if hosts.is_empty():return
	meal_host=hosts[randi()%hosts.size()];mother_reaction("call",6);life.data.invites[key]={"offered":true,"at":life.now()};life.save()
	invite_panel=PanelContainer.new();invite_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE);invite_panel.offset_left=18;invite_panel.offset_right=-18;invite_panel.offset_top=hud_bottom()+8;invite_panel.offset_bottom=hud_bottom()+114;ui.add_child(invite_panel)
	var col:=VBoxContainer.new();invite_panel.add_child(col);col.add_child(UI.label(NAMES[meal_host]+"叫你吃饭啦，菜还热着。",21));var row:=HBoxContainer.new();col.add_child(row)
	row.add_child(UI.button("这就下楼",func():dismiss_invite();enter_room("dining",false);eat_together(world.spot("meal")),true))
	row.add_child(UI.button("等会儿来",func():dismiss_invite();note="不急，桌上给你留一份"))
func dismiss_invite() -> void:
	if invite_panel:invite_panel.queue_free();invite_panel=null
## 屋外（院子、小道、后园、小桥、老屋、树林）才说「这里过不去」、才给屋里房间之间的门出箭头（阿鱼 10/5 第六轮第 4 条）
func outdoors() -> bool:return bool(world.cfg.get("outdoor",false))
func blocked_feedback() -> void:
	if not outdoors():return
	if elapsed<blocked_notice_until:return
	blocked_notice_until=elapsed+3;player.say("这里过不去，沿小路绕一绕。" );note="墙和家具过不去，绕着走"
func season_discovery() -> void:
	if life and area in ["garden","grove","terrace","exterior"]:life.card(["spring","summer","autumn","winter"][Life.season(month)])
	if life and weather=="rain" and area=="exterior":life.card("snail")
func refresh_life_hud() -> void:
	if cats_label:cats_label.text=str(life.cats_today())+"/3"
	if task_button:
		var left:Array=life.daily_tasks().filter(func(t):return not t.thanked)
		task_button.text="小事 %d/3"%(3-left.size()) # 只放短数字；谁想请你做什么，点开今日小事看
	if not life.last_error.is_empty():note=life.last_error
func welcome() -> void:
	var box:=modal_shell("给来做客的你","letter")
	var art:=TextureRect.new();art.texture=Assets.texture(P+"thumb_exterior.png");art.custom_minimum_size.y=146;art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;art.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;box.add_child(art)
	box.add_child(UI.paragraph("欢迎来到裳泓村。\n先收喜多和猫猫带回的东西，种下几样菜，再进阿鱼家做客。帮大家交三件订单，阿鱼就会介绍你去找村长。",21))
	box.add_child(UI.paragraph("二楼客房给你留着。以后也可以在村里选一处荒地，慢慢搭起自己的家。",20))
	var sign:=UI.label("饭菜热着，慢慢来。　阿鱼 留",18);sign.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;sign.add_theme_color_override("font_color",Color("7a4b2c"));box.add_child(sign)
	box.add_child(UI.button("看看今日小事",today));var row:=HBoxContainer.new();box.add_child(row)
	for item in [["进院子看看",close_modal],["选我的形象",choose_avatar]]:var b:=UI.button(item[0],item[1],item[0]=="进院子看看");b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(b)

func choose_avatar() -> void:
	var box:=modal_shell("你的形象")
	var grid:=GridContainer.new();grid.columns=4;box.add_child(grid)
	for preset in Actor.Spr.pickable_presets():
		var chosen:int=preset;var button:=UI.button("",func():profile.avatar=chosen;player_preset=chosen;life.data.profile=profile;life.save();var file:=FileAccess.open("user://ayu_home_local_player.json",FileAccess.WRITE);if file:file.store_string(JSON.stringify(profile));file.close();close_modal();enter_room(area,false))
		var look:Dictionary=Actor.Spr.gpt_look(chosen)
		if not look.is_empty():
			var atlas:=AtlasTexture.new();atlas.atlas=look.tex;atlas.region=Rect2(look.anim.down.idle*look.frame_w,0,look.frame_w,look.frame_h);button.icon=atlas
		else:button.icon=Actor.Spr.portrait(chosen,3)
		button.expand_icon=true;button.custom_minimum_size=Vector2(98,156);grid.add_child(button)
	box.add_child(UI.label("选好后会记住，拍立得里也是这个你。",18))
func today() -> void:
	if not await preload("res://ayu_home/v4/core/download_gate.gd").ensure(self,"panels"):return
	var box:=modal_shell("门上的今日小事","board")
	box.add_child(UI.stamp("%d 月 %d 日 · %s · 三件小事，不赶时间"%[month,day,Data.SEASONS[Data.season(month)]]))
	box.add_child(UI.paragraph(["春天适合把新种子放进土里。","夏夜的树林里，等一会儿会有微光。","秋天的果子熟了，留一份给家人。","冬天也能种菜，露台的雪等你来看。"][Life.season(month)],19))
	for task in life.daily_tasks():
		# 一张便签：左边家人的大头像，右边名字章、要做的事，最下面一行状态和「去找」按钮，不空一截
		var panel:=PanelContainer.new();panel.add_theme_stylebox_override("panel",UI.card_box());box.add_child(panel)
		var row:=HBoxContainer.new();row.add_theme_constant_override("separation",12);panel.add_child(row)
		var face:=portrait_image(task.host,92,96,true);face.size_flags_vertical=Control.SIZE_SHRINK_CENTER;row.add_child(face)
		var words:=VBoxContainer.new();words.size_flags_horizontal=Control.SIZE_EXPAND_FILL;words.add_theme_constant_override("separation",4);row.add_child(words)
		var head:=HBoxContainer.new();words.add_child(head);head.add_child(UI.stamp(NAMES[task.host]+"想请你"))
		if task.thanked:head.add_child(UI.label("✓ 已道谢",15))
		words.add_child(UI.paragraph(str(task.text),22))
		var foot:=HBoxContainer.new();words.add_child(foot)
		var state:=UI.paragraph("家人已经谢过你" if task.thanked else ("做好了，去说一声" if task.done else "走近聊聊就知道怎么做"),15);state.add_theme_color_override("font_color",Color(DSkin.PAL.box.rim));state.size_flags_horizontal=Control.SIZE_EXPAND_FILL;state.size_flags_vertical=Control.SIZE_SHRINK_CENTER;foot.add_child(state)
		var host:String=task.host;var b:=UI.button("去找"+NAMES[host],func():close_modal();tracked_person=host;note="去找"+NAMES[host]+"，点地面可停下");b.custom_minimum_size=Vector2(0,48);foot.add_child(b)
	var row:=HBoxContainer.new();box.add_child(row);row.add_child(UI.icon("pet",42));row.add_child(UI.label("今天找到的猫 · "+str(life.cats_today())+" / 3",20));box.add_child(UI.button("看家的地图",navigation))

func collection_page() -> void:
	if not await preload("res://ayu_home/v4/core/download_gate.gd").ensure(self,"panels"):return
	var box:=modal_shell("家的收集册")
	var col:=VBoxContainer.new();col.size_flags_horizontal=Control.SIZE_EXPAND_FILL;box.add_child(col)
	for room in definitions:
		var count:=0
		for h in definitions[room].hotspots:
			if life.data.found.has(room+":"+h.id):count+=1
		col.add_child(UI.label(str(definitions[room].title)+"  "+str(count)+" / "+str(definitions[room].hotspots.size()),21))
		var grid:=GridContainer.new();grid.columns=2;grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;col.add_child(grid) # 字放大到 24 以后三列会吊字，改两列
		var seats:=0;var seated:=0
		for h in definitions[room].hotspots:
			if str(h.id).begins_with("seat_"):
				seats+=1;seated+=int(life.data.found.has(room+":"+h.id));continue
			var done:bool=life.data.found.has(room+":"+h.id);var card:=PanelContainer.new();card.custom_minimum_size=Vector2(0,56);card.size_flags_horizontal=Control.SIZE_EXPAND_FILL;grid.add_child(card)
			# 「？」「✓」单放一列，名字占满剩下的宽：7 个字一行放得下，不吊字
			var line:=HBoxContainer.new();line.add_theme_constant_override("separation",4);card.add_child(line);line.add_child(UI.label("✓" if done else "？",24))
			var copy:=UI.label(two_lines(str(h.label),7),24);copy.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;copy.size_flags_horizontal=Control.SIZE_EXPAND_FILL;line.add_child(copy)
		# 「坐在这里」不再一格一格列（119 格里原来有 39 格是它），合成一行。
		if seats>0:col.add_child(UI.label("坐过的位置 · %d / %d"%[seated,seats],16))
## 一行放不下（超过 per_line 个字）就分成差不多长的两行，挑「的」、标点后面断，不让第二行只剩一个字
func two_lines(copy:String,per_line:int) -> String:
	if copy.length()<=per_line:return copy
	var mid:=ceili(copy.length()/2.0)
	for i in [mid,mid+1,mid-1]:
		if copy[i-1] in "的，、":return copy.substr(0,i)+"\n"+copy.substr(i)
	return copy.substr(0,mid)+"\n"+copy.substr(mid)
func take_photo() -> void:
	if not await preload("res://ayu_home/v4/core/download_gate.gd").ensure(self,"panels"):return
	if busy():return
	var actors:Array=[]
	for a in [player]+people.values():
		if a.visible:actors.append({"id":a.id,"pos":[a.position.x,a.position.y],"face":"down" if a.id=="mother" and not a.in_bed else a.face,"action":"photo" if a.id=="mother" and not a.in_bed else a.action,"lift":a.lift,"blanket":a.blanket.to_html(),"in_bed":a.in_bed,"head_down":a.head_down})
	photo.open(life,{"room":area,"title":"裳泓村 · 阿鱼家 · "+str(world.cfg.title),"date":life.date_key(),"at":life.now(),"hour":hour,"month":month,"weather":weather,"center":[player.position.x,player.position.y-61],"player":[player.position.x,player.position.y],"actors":actors,"effects":life.data.effects.duplicate(true),"trees":life.data.trees.duplicate(true),"plots":life.data.plots.duplicate(true),"flower_vase":life.data.flower_vase.duplicate(true),"harvest_history":life.data.harvest_history.duplicate(true),"preset":player_preset,"pose":0,"zoom":1.8})
func album_page() -> void:
	if not await preload("res://ayu_home/v4/core/download_gate.gd").ensure(self,"panels"):return
	var box:=modal_shell("拍立得相册")
	if life.data.photos.is_empty():box.add_child(UI.label("走到喜欢的地方，点「相机」留一张。",20));return
	var col:=VBoxContainer.new();col.size_flags_horizontal=Control.SIZE_EXPAND_FILL;box.add_child(col)
	for record in life.data.photos:
		var snapshot:Dictionary=record.duplicate(true);var b:=UI.button(str(record.title)+"\n"+str(record.date),func():close_modal();photo.open(life,snapshot,true));b.custom_minimum_size.y=92;col.add_child(b)
func settings_page() -> void:
	var box:=modal_shell("慢慢玩的设置")
	box.add_child(UI.button("声音 · "+("开" if sound_on else "关"),func():sound_on=not sound_on;life.data.settings.sound=sound_on;life.save();play_ambience();settings_page()))
	box.add_child(UI.button("轻松节奏 · 已开启",func():note="没有倒计时，也不会枯萎"))
	# 手机上没有键盘：只有电脑版才写按键（体验师小毛病 5）
	var help:=UI.label(("方向键 / WASD：走路\nE：走近并操作　M：地图\nJ：生活册　C：拍立得\nEsc：收起当前页面\n" if OS.has_feature("pc") and not OS.has_feature("web") else "点地面走路；走近东西，点冒出来的气泡就能做。\n右下角的小包里有相机、生活册和地图。\n")+"进度自动保存在这位玩家自己的家里。",20);help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(help)
	box.add_child(UI.button("选我的形象",choose_avatar))
	box.add_child(UI.button("保存并继续",func():life.save();close_modal(),true))
	box.add_child(UI.button("保存并回到桌面",func():life.save();get_tree().quit()))

func setup_water_audio() -> void:
	water_audio=AudioStreamPlayer.new();add_child(water_audio)
	var wave:=AudioStreamWAV.new();wave.format=AudioStreamWAV.FORMAT_16_BITS;wave.mix_rate=22050;wave.loop_mode=AudioStreamWAV.LOOP_FORWARD;wave.loop_begin=0;wave.loop_end=22050
	var bytes:=PackedByteArray();bytes.resize(44100);var previous:=0.0
	for i in 22050:
		var noise:float=sin(i*12.9898+78.233)*43758.5453;noise=(noise-floor(noise))*2-1;previous=previous*.55+noise*.45;bytes.encode_s16(i*2,int(previous*6800))
	wave.data=bytes;water_audio.stream=wave;water_audio.volume_db=-21
func update_water_audio() -> void:
	if not water_audio:return
	var active:=false
	for id in world.toggles:
		if world.toggles[id] and world.spot(id).get("kind","") in ["tap","shower"]:active=true
	if active and sound_on:
		if not water_audio.playing:water_audio.play()
	elif water_audio.playing:water_audio.stop()

func update_tracking() -> void:
	if tracked_person.is_empty() or busy() or not pending.is_empty() or not player.route.is_empty():return
	if people[tracked_person].visible:
		var id:=tracked_person;tracked_person="";go("person:"+id);return
	var target:String=family_state[tracked_person].room
	if target=="away":note=NAMES[tracked_person]+"出门了，回来再聊";tracked_person="";return
	var hop:=room_hop(area,target)
	if hop!=area:go("to_"+hop)
