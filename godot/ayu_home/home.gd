extends Node2D
const Data = preload("res://ayu_home/home_data.gd")
const World = preload("res://ayu_home/world.gd")
const Actor = preload("res://ayu_home/actor.gd")
const Activities = preload("res://ayu_home/activities.gd")
const Art = preload("res://ayu_home/asset_store.gd")
const CloudRpc = preload("res://scripts/cloud.gd")
const SAVE := "user://ayu_home_life_v1.json"
const ACTION_NAMES := {"sleep":"睡得香甜", "eat":"一起吃饭", "cook":"准备饭菜", "clean":"收拾家", "work":"工具手作", "homework":"写作业", "computer":"用电脑", "game":"玩小游戏", "tv":"看电视", "guitar":"弹吉他", "record":"听唱片", "fish":"照料小鱼", "mahjong":"邻里麻将小聚", "garden":"照料后园", "read":"安静读书", "rest":"准备休息", "away":"外出中"}
var world
var player
var activities
var people: Dictionary = {}
var routes: Dictionary = {}
var states: Dictionary = {}
var actor_wait: Dictionary = {}
var departing: Dictionary = {}
var player_path := PackedVector2Array()
var pending := {}
var area := "exterior"
var is_owner := false
var admitted := false
var hour_override := -1.0
var month_override := 0
var hour := 12.0
var month := 4
var last_slot := ""
var poll := 0.0
var overview := false
var view_rect := Rect2()
var frame_scale := 1.0
var hud: CanvasLayer
var ui: Control
var title: Label
var clock_label: Label
var status: Label
var hint: Label
var buttons: HBoxContainer
var overlay: Control
var toast_timer := 0.0
var toast_text := ""
var journal: Dictionary = {"version":1,"entries":[],"completed":{},"garden_days":[],"notes":[],"garden_state":{},"garden_saved_harvest":0}
var save_path := SAVE
var resting := false
var return_position := Vector2.ZERO
var knock_host := ""
var capture_path := ""
var capture_delay := 2.5
var capture_elapsed := 0.0
var capture_exit := false
var dev_command := ""
var dev_focus := ""
var commands_done := false
var art_store: Node
var cloud_rpc: Node
var bootstrapped := false
var asset_test_config: Dictionary = {}

func _ready() -> void:
	set_process(false)
	_parse_args()
	_load_life()
	_read_clock()
	RenderingServer.set_default_clear_color(Color("263d37"))
	_make_ui()
	_layout()
	get_viewport().size_changed.connect(_layout)
	art_store = Art.new()
	if not asset_test_config.is_empty(): art_store.config = asset_test_config
	add_child(art_store)
	cloud_rpc = CloudRpc.new()
	add_child(cloud_rpc)
	art_store.progress.connect(func(current: int,total: int): status.text = "正在铺好家的角落  %d / %d" % [current,total])
	await _bootstrap()

func _bootstrap() -> void:
	_close_panel()
	buttons.visible = false
	status.text = "正在准备家的画面…"
	hint.text = "第一次回来会多等一会儿，之后就会更快。"
	var result: Dictionary = await art_store.ensure_all(cloud_rpc)
	if not result.get("ok",false):
		print("AYU_ASSET_LOAD_FAILED ",result)
		_show_panel("家的画面还没准备好","这一趟有点慢，画面暂时没有送到。可以再试一次，或者先回到镇上。",[["再试一次",_bootstrap],["先回到镇上",func(): get_tree().root.set_meta("ayu_home_skip",true); get_tree().change_scene_to_file("res://main.tscn")]])
		return
	buttons.visible = true
	world = World.new()
	world.area = area
	world.month = month
	world.hour = hour
	add_child(world)
	player = Actor.new()
	world.walkers.add_child(player)
	player.setup("ayu" if is_owner else "visitor")
	player.position = world.nearest(Data.spawn(area))
	if not dev_focus.is_empty():
		for item in Data.hotspots(area):
			if item.id == dev_focus: player.position = world.nearest(item.approach); break
	for id in Data.FAMILY + ["qiuqiu","luoluo","tiantian","xiduo","neighbor_a","neighbor_b"]:
		var actor = Actor.new()
		world.walkers.add_child(actor)
		actor.setup("father" if id == "neighbor_a" else ("mother" if id == "neighbor_b" else id))
		if id == "neighbor_a": actor.modulate = Color(.94,1.0,.83)
		if id == "neighbor_b": actor.modulate = Color(.88,.92,1.0)
		people[id] = actor
		actor_wait[id] = randf_range(2,6)
	activities = Activities.new()
	add_child(activities)
	activities.closed.connect(_activity_closed)
	activities.completed.connect(_activity_completed)
	_sync_family(true)
	_layout()
	bootstrapped = true
	set_process(true)
	_message("点地面散步，点亮点走近物件。来访请先敲门。" if area == "exterior" else "欢迎回家。点物件走近看看，所有房间都能探索。",6)

func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ayu-hour="): hour_override = float(arg.get_slice("=",1))
		elif arg.begins_with("--ayu-month="): month_override = int(arg.get_slice("=",1))
		elif arg.begins_with("--ayu-area="): area = arg.get_slice("=",1); admitted = area != "exterior"
		elif arg.begins_with("--ayu-owner="): is_owner = arg.get_slice("=",1) in ["true","1"]
		elif arg.begins_with("--ayu-screenshot="): capture_path = arg.substr(17)
		elif arg.begins_with("--ayu-save="): save_path = arg.substr(11)
		elif arg.begins_with("--ayu-delay="): capture_delay = float(arg.get_slice("=",1))
		elif arg.begins_with("--ayu-script="): dev_command = arg.get_slice("=",1)
		elif arg.begins_with("--ayu-focus="): dev_focus = arg.get_slice("=",1)
		elif arg == "--ayu-capture-exit": capture_exit = true
		elif arg == "--ayu-close-view": overview = false
		elif arg == "--ayu-overview": overview = true
	if not Data.AREAS.has(area): area = "exterior"

func _read_clock() -> void:
	var now := Time.get_datetime_dict_from_system()
	hour = hour_override if hour_override >= 0 else float(now.hour)+float(now.minute)/60.0+float(now.second)/3600.0
	month = month_override if month_override > 0 else int(now.month)
	if world:
		world.hour = hour
		world.month = month
		world.modulate = Color(.70,.77,.90) if hour < 6 or hour >= 22 else (Color(.91,.83,.77) if hour >= 18 else Color.WHITE)

func set_test_clock(value_hour: float, value_month: int = 4) -> void:
	hour_override = value_hour
	month_override = value_month
	_read_clock()
	_sync_family(true)
	_update_hud()

func set_identity(value: bool) -> void:
	is_owner = value
	if player: player.setup("ayu" if is_owner else "visitor")
	_sync_family(true)
	_update_hud()

func _make_ui() -> void:
	hud = CanvasLayer.new()
	hud.layer = 10
	add_child(hud)
	ui = Control.new()
	ui.position = Vector2.ZERO
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(ui)
	var theme := Theme.new()
	var font_path := "res://assets/fonts/fusion-pixel-12px-proportional-zh_hans.otf.woff2"
	if ResourceLoader.exists(font_path): theme.default_font = load(font_path)
	theme.default_font_size = 20
	var style := _style(Color("f5e9d3"))
	theme.set_stylebox("normal","Button",style)
	theme.set_stylebox("hover","Button",_style(Color("f9efdd")))
	theme.set_stylebox("pressed","Button",_style(Color("d8c9a8")))
	theme.set_color("font_color","Button",Color("4c4033"))
	theme.set_color("font_hover_color","Button",Color("4c4033"))
	theme.set_color("font_pressed_color","Button",Color("4c4033"))
	ui.theme = theme
	var top := Panel.new()
	top.name = "Header"
	top.add_theme_stylebox_override("panel",_style(Color("f0e3cb"),0))
	ui.add_child(top)
	title = _label("阿鱼家",26)
	top.add_child(title)
	clock_label = _label("",18)
	top.add_child(clock_label)
	status = _label("",16)
	top.add_child(status)
	var bottom := Panel.new()
	bottom.name = "Footer"
	bottom.add_theme_stylebox_override("panel",_style(Color("f0e3cb"),0))
	ui.add_child(bottom)
	hint = _label("",18)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom.add_child(hint)
	buttons = HBoxContainer.new()
	buttons.add_theme_constant_override("separation",10)
	bottom.add_child(buttons)
	for spec in [["屋内导览",_navigation],["生活册",_life_book],["看全景",_toggle_view]]:
		var button := _button(spec[0],spec[1])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(button)

func _style(color: Color, rounding := 12) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.corner_radius_top_left = rounding
	box.corner_radius_top_right = rounding
	box.corner_radius_bottom_left = rounding
	box.corner_radius_bottom_right = rounding
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box

func _label(text_value: String, font_size := 20) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color("4c4033"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _button(text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0,54)
	button.pressed.connect(callback)
	return button

func _layout() -> void:
	var size := get_viewport_rect().size
	var unit := maxf(1.0,size.x/540.0)
	ui.scale = Vector2.ONE*unit
	var logical := size/unit
	ui.size = logical
	var top: Control = ui.get_node("Header")
	top.size = Vector2(logical.x,112)
	title.position = Vector2(20,16)
	title.size = Vector2(logical.x-40,34)
	clock_label.position = Vector2(20,53)
	clock_label.size = Vector2(logical.x-40,27)
	status.position = Vector2(20,84)
	status.size = Vector2(logical.x-40,24)
	var bottom: Control = ui.get_node("Footer")
	bottom.position = Vector2(0,logical.y-152)
	bottom.size = Vector2(logical.x,152)
	hint.position = Vector2(18,13)
	hint.size = Vector2(logical.x-36,66)
	buttons.position = Vector2(18,85)
	buttons.size = Vector2(logical.x-36,54)
	buttons.get_child(2).text = "走近看" if overview else "看全景"
	view_rect = Rect2(Vector2(0,112*unit),Vector2(size.x,size.y-264*unit))
	_camera(true)
	_update_hud()

func _camera(immediate := false) -> void:
	if not world or not player: return
	var desired_scale: float = minf(view_rect.size.x/Data.SIZE.x,view_rect.size.y/Data.SIZE.y) if overview else view_rect.size.x/560.0
	frame_scale = desired_scale
	world.scale = Vector2.ONE*frame_scale
	var target: Vector2 = view_rect.get_center()-player.position*frame_scale
	if overview: target = view_rect.get_center()-Data.SIZE*frame_scale/2.0
	else:
		target.x = clampf(target.x,view_rect.end.x-Data.SIZE.x*frame_scale,view_rect.position.x)
		if Data.SIZE.y*frame_scale >= view_rect.size.y: target.y = clampf(target.y,view_rect.end.y-Data.SIZE.y*frame_scale,view_rect.position.y)
		else: target.y = view_rect.get_center().y-Data.SIZE.y*frame_scale/2.0
	world.position = target if immediate else world.position.lerp(target,.13)

func _process(dt: float) -> void:
	poll += dt
	if poll >= 1.0:
		poll = 0
		_read_clock()
		_sync_family()
		_update_hud()
	if not resting: _move_player(dt)
	_move_npcs(dt)
	_camera()
	if toast_timer > 0:
		toast_timer -= dt
		if toast_timer <= 0: _update_hud()
	if not dev_command.is_empty() and not commands_done and capture_elapsed > .4:
		commands_done = true
		_run_dev_command()
	capture_elapsed += dt
	if not capture_path.is_empty() and capture_elapsed >= capture_delay:
		var output := capture_path
		capture_path = ""
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output)
		var metadata := FileAccess.open(output+".json",FileAccess.WRITE)
		if metadata:
			metadata.store_string(JSON.stringify({"scene":"ayu_home","time":"%02d:%02d" % [int(hour),int((hour-int(hour))*60)],"month":month,"area":area,"dimensions":str(get_viewport_rect().size),"state":inspect_state(),"baseline":"deca36c2ae7a5434cbfa13c398e1990e47edf9d9"}))
		print("AYU_CAPTURE ",output," hour=",hour," month=",month," area=",area)
		if capture_exit: get_tree().quit()

func _update_hud() -> void:
	if not title: return
	title.text = "阿鱼家   ·   " + Data.AREAS[area]
	clock_label.text = "%s日  %02d:%02d   ·   %s" % [Data.SEASONS[Data.season(month)],int(hour),int((hour-int(hour))*60),"主人回家" if is_owner else "来家里做客"]
	var home := Data.at_home(hour)
	status.text = "一家人都在外面散步，10:00 后欢迎来访" if home.is_empty() else "  ·  ".join(home.map(func(id): return Data.NAMES[id]))+"在家"
	if toast_timer <= 0:
		hint.text = "正在休息，点「起身」继续散步。" if resting else ("点亮点与物件互动，或用屋内导览选择目的地。" if admitted else "院子可以自由散步。到正门亮点敲门，听听家里的回应。")

func _unhandled_input(event: InputEvent) -> void:
	if not bootstrapped: return
	if overlay or resting or is_instance_valid(activities.root): return
	var position_at := Vector2.ZERO
	var clicked := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		position_at = event.position; clicked = true
	elif event is InputEventScreenTouch and event.pressed:
		position_at = event.position; clicked = true
	if not clicked or not view_rect.has_point(position_at): return
	var point: Vector2 = (position_at-world.position)/frame_scale
	var item: Dictionary = world.hotspot_at(point,maxf(65*Data.WORLD_SCALE,26/frame_scale))
	if not item.is_empty(): _visit(item)
	else:
		pending.clear()
		world.selected = ""
		player_path = world.path(player.position,point)
		if player_path.is_empty(): _message("从门洞和走道绕过去吧。",3)
	get_viewport().set_input_as_handled()

func _visit(item: Dictionary) -> void:
	_close_panel()
	if area in ["floor1","floor2"] and not admitted: _message("先敲门，等家人邀请再进去。",4); return
	pending = item
	world.selected = item.id
	player_path = world.path(player.position,item.approach)
	if player_path.is_empty():
		pending.clear()
		_message("那边暂时走不过去，试试从走道绕行。",4)
	else: _message("走近「%s」…" % item.label,10)

func _move_player(dt: float) -> void:
	if player_path.is_empty(): player.set_walking(false); return
	var target: Vector2 = player_path[0]
	var delta: Vector2 = target-player.position
	if delta.length() < 4*Data.WORLD_SCALE:
		player.position = target
		player_path.remove_at(0)
		if player_path.is_empty():
			player.set_walking(false)
			if not pending.is_empty():
				var item := pending.duplicate(); pending.clear(); _interact(item.id)
		return
	player.set_walking(true)
	player.set_direction(_direction(delta))
	player.position = player.position.move_toward(target,210*Data.WORLD_SCALE*dt)

func _direction(delta: Vector2) -> String:
	if abs(delta.x) > abs(delta.y): return "right" if delta.x > 0 else "left"
	return "down" if delta.y > 0 else "up"

func _sync_family(force := false) -> void:
	var slot := "%s:%s" % [int(hour*4),area]
	if not force and last_slot == slot: return
	last_slot = slot
	for id in Data.FAMILY:
		var next: Dictionary = Data.state(id,hour)
		var old: Dictionary = states.get(id,{})
		states[id] = next
		var actor = people[id]
		var present: bool = next.area == area and not (is_owner and id == "ayu")
		if not force and not present and old.get("area","") == area and actor.visible:
			var destination := Data.p(.615,.77)
			if area == "floor2": destination = Data.p(.565,.385)
			elif area == "garden": destination = Data.p(.51,.825)
			elif next.area == "floor2": destination = Data.p(.66,.40)
			routes[id] = world.path(actor.position,destination)
			departing[id] = true
			actor.set_activity("walk")
			continue
		actor.visible = present
		actor.z_index = 2 if next.action == "sleep" else 0
		departing.erase(id)
		if not present: routes[id] = PackedVector2Array(); continue
		var target: Vector2 = world.nearest(next.pos)
		if force or old.get("area","") != next.area:
			actor.position = world.nearest(Data.spawn(area)) if not force else target
			if force and next.action == "sleep": actor.position = next.bed
			actor.set_activity("walk" if not force else next.action)
			actor.set_direction(next.face)
			routes[id] = world.path(actor.position,target) if not force else PackedVector2Array()
		elif old.get("action","") != next.action:
			routes[id] = world.path(actor.position,target)
			actor.set_activity(next.action)
		else:
			actor.set_activity(next.action)
			if routes.get(id,PackedVector2Array()).is_empty(): actor.set_direction(next.face)
	for id in ["qiuqiu","luoluo","tiantian","xiduo"]:
		var actor = people[id]
		actor.visible = area == ("exterior" if id == "xiduo" else "floor1")
		if actor.visible and (force or not states.has(id)):
			actor.position = world.nearest(Data.p(.79,.92) if id == "xiduo" else Data.p(.53+(0.025*["qiuqiu","luoluo","tiantian"].find(id)),.23))
			actor.set_activity("rest" if hour < 6 or hour >= 22 else "pet")
		states[id] = {"action":"pet","area":"exterior" if id == "xiduo" else "floor1"}
	var gathering := area == "floor1" and ((hour >= 13 and hour < 14) or (hour >= 19 and hour < 20))
	for id in ["neighbor_a","neighbor_b"]:
		people[id].visible = gathering
		people[id].position = world.nearest(Data.p(.855,.15 if id == "neighbor_a" else .325))
		people[id].set_activity("mahjong")
		people[id].set_direction("down" if id == "neighbor_a" else "up")

func _move_npcs(dt: float) -> void:
	for id in people:
		var actor = people[id]
		if not actor.visible: continue
		var route: PackedVector2Array = routes.get(id,PackedVector2Array())
		if not route.is_empty():
			var delta: Vector2 = route[0]-actor.position
			actor.set_walking(true)
			actor.set_direction(_direction(delta))
			actor.position = actor.position.move_toward(route[0],150*Data.WORLD_SCALE*dt)
			if delta.length() < 5*Data.WORLD_SCALE: route.remove_at(0)
			routes[id] = route
			if route.is_empty():
				actor.set_walking(false)
				if departing.get(id,false): actor.visible = false; departing.erase(id)
				else:
					actor.set_activity("greeting" if id == knock_host and area == "exterior" else states.get(id,{}).get("action","pet"))
					actor.set_direction(states.get(id,{}).get("face","down"))
					if states.get(id,{}).get("action","") == "sleep": actor.position = states[id].bed
			continue
		actor_wait[id] = float(actor_wait.get(id,4))-dt
		if actor_wait[id] > 0: continue
		actor_wait[id] = randf_range(6,12)
		var action: String = states.get(id,{}).get("action","mahjong")
		if action in ["sleep","eat","mahjong","read","tv","computer","homework","game","rest","guitar","record"]: continue
		var base: Vector2 = Data.state(id,hour).pos if id in Data.FAMILY else actor.position
		var target: Vector2 = world.nearest(base+Vector2(randf_range(-50,50)*Data.WORLD_SCALE,randf_range(-38,38)*Data.WORLD_SCALE))
		routes[id] = world.path(actor.position,target)

func _switch_area(next: String, position_at := Vector2(-1,-1)) -> void:
	_close_panel()
	player_path.clear()
	pending.clear()
	knock_host = ""
	area = next
	world.set_area(area)
	player.position = world.nearest(Data.spawn(area) if position_at.x < 0 else position_at)
	player.set_activity("walk")
	player.set_walking(false)
	player.set_direction("down")
	departing.clear()
	_sync_family(true)
	_read_clock()
	_camera(true)
	_message("到了「%s」。慢慢逛，不着急。" % Data.AREAS[area],4)
	_update_hud()

func _interact(id: String) -> void:
	match id:
		"door": _knock()
		"stairs_up": _switch_area("floor2",Data.p(.565,.385))
		"stairs_down": _switch_area("floor1",Data.p(.66,.40))
		"exit": admitted = false; _switch_area("exterior",Data.p(.55,.64))
		"garden": _switch_area("garden")
		"return": _switch_area("exterior",Data.p(.075,.68))
		"guitar","puzzle","album","fish","tv","record","workbench": _open_activity(id)
		"garden_play","fruit","bees","pond":
			_show_panel("%s天的后园" % Data.SEASONS[Data.season(month)],Data.SEASON_COPY[Data.season(month)]+"\n\n菜地："+"、".join(Data.CROPS[Data.season(month)])+"\n果园："+"、".join(Data.FRUITS[Data.season(month)])+"\n小动物："+"、".join(Data.WILDLIFE[Data.season(month)]),[["动手照料",func(): _open_activity("garden")],["再走走",_close_panel]])
		"relax":
			return_position = player.position
			player.position = Data.p(.307,.255)
			resting = true
			player.set_walking(false)
			player.set_activity("sleep")
			player.z_index = 2
			_show_bed_rest()
		"meal":
			var eating: bool = Data.state("ayu",hour).action == "eat"
			_show_panel("圆桌边的家常饭", "一家三口已经坐在桌边。饭菜冒着热气，慢慢坐一会儿。" if eating else "早餐 07:30–08:15\n午餐 12:00–13:00\n晚餐 18:00–19:00\n\n到了饭点，阿鱼、爸爸、妈妈都会回来吃饭。",[["坐一会儿",func(): _open_activity("relax")],["知道了",_close_panel]])
		"mahjong": _show_panel("邻里小聚","牌落桌的轻响里，大家轮流摸牌、出牌，偶尔说几句笑话。你可以坐在边上看看。",[["坐旁边看看",func(): _open_activity("relax")],["继续逛",_close_panel]])
		"computer": _show_panel("书桌上的小世界","窗外风很轻。电脑上可以玩一盘小拼图，也可以打开生活册记下今天。",[["玩小拼图",func(): _open_activity("puzzle")],["翻生活册",_life_book],["继续逛",_close_panel]])
		"cook": _show_panel("厨房的香气","热水壶咕嘟响着，案板上摆着时令蔬菜。饭前把餐具归好，让桌边更整洁。",[["整理餐具",func(): _open_activity("workbench")],["继续逛",_close_panel]])
		"laundry": _show_panel("晾一件衣服","洗衣机轻轻转，衣架排得整整齐齐。窗边晒过的布有阳光的味道。",[["帮忙归置",func(): _open_activity("workbench")],["继续逛",_close_panel]])
		"cats": _show_panel("楼梯下的小窝","求求、落落和天天各占了一角。猫咪会散步、理毛，也会蜷起来打盹。",[["陪猫咪待会儿",func(): _open_activity("relax")],["继续逛",_close_panel]])
		"xiduo": _show_panel("喜多守着小院","喜多在院子里闻闻花、巡巡小路。它的小窝留在院外，屋里是三只猫的地盘。",[["陪喜多看看院子",func(): _open_activity("relax")],["继续逛",_close_panel]])
		"relax_sofa","terrace","read": _open_activity("relax")
		"flowers","stream": _show_panel("微小的好时光","花叶晃动，水面映着天色。今天也可以把心事放慢一点。",[["记一笔风景",func(): _append_entry("在"+Data.AREAS[area]+"留了一会儿。"); _close_panel(); _message("这一刻留在生活册里了。",4)],["继续逛",_close_panel]])
		"parents","ayu_room","guest_closet","guest_bath","closet","bath","garage":
			var copy := {"parents":"床铺柔软，爸爸妈妈的书和小物各归原位。", "ayu_room":"粉色床铺、兔子玩偶与梳妆台，是阿鱼安静的小天地。", "guest_closet":"客房衣帽间里留着空衣架，为来做客的人预备着。", "guest_bath":"客房浴室有干净毛巾和温暖的灯。", "closet":"衣柜里是日常衣物，门旁的小架收着折好的衣服。", "bath":"洗手、整理一下，再带着轻松的心情继续逛。", "garage":"车库停着家里的车和自行车，留出通道，出门就方便了。"}
			_show_panel("家里的小角落",copy[id],[["整理一下",func(): _open_activity("workbench")],["继续逛",_close_panel]])
		"gate": _show_panel("小院门口","谢谢你来做客。今天的小事已经收进生活册，下次回来接着逛。",[["回到镇上",_return_to_town],["继续散步",_close_panel]])

func _return_to_town() -> void:
	_save_life()
	get_tree().root.set_meta("ayu_home_skip",true)
	get_tree().change_scene_to_file("res://main.tscn")

func _knock() -> void:
	if is_owner:
		admitted = true
		_append_entry("回到家里。")
		_show_panel("欢迎回家，阿鱼","钥匙轻轻一转。屋里的灯、三只猫和熟悉的角落都在等你。",[["进家里",func(): _switch_area("floor1")],["先逛院子",_close_panel]])
		return
	var present := Data.at_home(hour)
	if present.is_empty():
		_show_panel("笃、笃、笃…","屋里暂时没有人回应。一家人一起出门散步了。\n\n今天 10:00 后有人回来，三顿饭也都会聚齐。你可以先逛后花园，或者留张小纸条。",[["留下来访纸条",func(): journal.notes.append({"time":Time.get_datetime_string_from_system(),"message":"今天来过，愿你们有个好天气。"}); _save_life(); _close_panel(); _message("纸条放在门边的小盒子里。10:00 后再敲门吧。",6)],["去后花园散步",func(): _switch_area("garden")],["继续逛院子",_close_panel]])
		return
	knock_host = "father" if "father" in present else ("mother" if "mother" in present else "ayu")
	var actor = people[knock_host]
	actor.visible = true
	actor.position = world.nearest(Data.p(.55,.575))
	actor.set_activity("walk")
	actor.set_direction("down")
	routes[knock_host] = world.path(actor.position,Data.p(.55,.622))
	_append_entry("敲门来访，"+Data.NAMES[knock_host]+"来应门。")
	var text_value: String = Data.NAMES[knock_host]+"走到门边，轻轻打开门：\n「来啦，进来坐一会儿吧。」"
	if hour >= 22 or hour < 6: text_value = Data.NAMES[knock_host]+"披着暖灯的光，轻声来应门：\n「夜深啦，进来歇一会儿，小声一点就好。」"
	_show_panel("笃笃…门开了",text_value,[["进门做客",func(): admitted = true; _switch_area("floor1")],["再逛逛院子",_close_panel]])

func _open_activity(kind: String) -> void:
	_close_panel()
	player_path.clear()
	player.set_walking(false)
	activities.open(kind,{"season":Data.SEASONS[Data.season(month)],"month":month,"hour":hour,"area":area,"journal":journal,"garden_state":journal.garden_state})

func _show_bed_rest() -> void:
	_close_panel()
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(overlay)
	var logical := get_viewport_rect().size/ui.scale
	var panel := PanelContainer.new()
	panel.position = Vector2(18,logical.y-310)
	panel.size = Vector2(logical.x-36,148)
	panel.add_theme_stylebox_override("panel",_style(Color("f7eddb"),16))
	overlay.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",9)
	panel.add_child(box)
	box.add_child(_label("被子很软，听听屋子。",22))
	box.add_child(_label("现实时间照常流动，随时可以起来。",16))
	box.add_child(_button("起身，继续散步",func(): _close_panel(); _activity_closed()))
	_update_hud()

func _activity_closed() -> void:
	_save_life()
	if resting:
		_close_panel()
		resting = false
		player.position = world.nearest(return_position)
		player.z_index = 0
	player.set_activity("walk")
	player.set_walking(false)
	_update_hud()

func _activity_completed(kind: String) -> void:
	if kind == "garden":
		var total := int(journal.garden_state.get("harvest_total",0))
		var before := int(journal.get("garden_saved_harvest",0))
		journal.garden_saved_harvest = total
		if total > before:
			journal.completed.garden = int(journal.completed.get("garden",0))+(total-before)
			_append_entry("在后园收获了 %d 份时令蔬菜。" % (total-before))
		else: _save_life()
		return
	journal.completed[kind] = int(journal.completed.get(kind,0))+1
	var names := {"guitar":"弹完一段自创小曲", "puzzle":"拼好一幅小拼图", "album":"修复一幅原创相册画", "fish":"照料小鱼", "tv":"看了一会儿电视", "record":"听过原创小唱片", "workbench":"整理好小物件", "garden":"照料时令植物", "relax":"安静歇了一会儿"}
	_append_entry(names.get(kind,"留下一段家的时光"))
	_message("这一小段时光收进生活册了。",4)

func _navigation() -> void:
	var options := []
	for item in Data.hotspots(area):
		var captured: Dictionary = item
		options.append([item.label,func(): _visit(captured)])
	options.append(["继续散步",_close_panel])
	_show_panel(Data.AREAS[area],"选一处想去的地方，会沿着地面和门洞走过去。",options)

func _life_book() -> void:
	var copy := "今天的时光都留在这一本里。\n\n"
	var entries: Array = journal.entries
	if entries.is_empty(): copy += "还没有记录。弹一段吉他、拼一幅画，或者在花边停一会儿吧。"
	else:
		for entry: Dictionary in entries.slice(maxi(0,entries.size()-24)):
			copy += entry.time+"  "+entry.text+"\n"
	_show_panel("阿鱼家的生活册",copy,[["看看一天的作息",func(): _show_panel("一家人的一天",Data.schedule_text(),[["回生活册",_life_book],["继续散步",_close_panel]])],["写下这一刻",_write_note],["继续散步",_close_panel]])

func _write_note() -> void:
	_show_panel("写下今天的小事","只存在你自己的设备上。",[["存进生活册",func():
		var input: TextEdit = overlay.find_child("LifeNote",true,false)
		if input and not input.text.strip_edges().is_empty(): _append_entry(input.text.strip_edges().substr(0,240))
		_life_book()
	],["取消",_life_book]])
	var box: VBoxContainer = overlay.find_child("Contents",true,false)
	var field := TextEdit.new()
	field.name = "LifeNote"
	field.placeholder_text = "窗边的光很好，猫咪睡得香…"
	field.custom_minimum_size.y = 110
	box.add_child(field)
	box.move_child(field,2)

func _show_panel(heading: String, text_value: String, actions: Array) -> void:
	_close_panel()
	player_path.clear()
	if player: player.set_walking(false)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.08,.12,.10,.63)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",_style(Color("f7eddb"),18))
	var logical := get_viewport_rect().size/ui.scale
	var lines := 0
	var chars_per_line := maxi(16,int((logical.x-68)/20))
	for line in text_value.split("\n"): lines += maxi(1,int(ceil(float(line.length())/chars_per_line)))
	var height := clampf(95+lines*28+actions.size()*68,240,logical.y-288)
	panel.position = Vector2(18,maxf(120,(logical.y-height)/2.0))
	panel.size = Vector2(logical.x-36,height)
	overlay.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.name = "Contents"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",14)
	scroll.add_child(box)
	box.add_child(_label(heading,26))
	var body := _label(text_value,20)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(body)
	for action in actions: box.add_child(_button(action[0],action[1]))

func _close_panel() -> void:
	if overlay: overlay.queue_free(); overlay = null

func _toggle_view() -> void:
	overview = not overview
	buttons.get_child(2).text = "走近看" if overview else "看全景"
	_camera(true)

func _message(text_value: String, seconds := 4.0) -> void:
	toast_text = text_value
	toast_timer = seconds
	if hint: hint.text = text_value

func _append_entry(text_value: String) -> void:
	journal.entries.append({"time":"%02d:%02d" % [int(hour),int((hour-int(hour))*60)],"date":Time.get_date_string_from_system(),"text":text_value})
	if journal.entries.size() > 240: journal.entries.pop_front()
	_save_life()

func _load_life() -> void:
	if not FileAccess.file_exists(save_path): return
	var file := FileAccess.open(save_path,FileAccess.READ)
	if not file: return
	var saved = JSON.parse_string(file.get_as_text())
	if saved is Dictionary and saved.get("version",0) == 1:
		for key in journal:
			if not saved.has(key): continue
			if typeof(journal[key]) == TYPE_INT and typeof(saved[key]) in [TYPE_INT,TYPE_FLOAT]: journal[key] = int(saved[key])
			elif typeof(saved[key]) == typeof(journal[key]): journal[key] = saved[key]

func _save_life() -> void:
	var file := FileAccess.open(save_path,FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(journal))

func _run_dev_command() -> void:
	if dev_command.begins_with("walk:"):
		for item in Data.hotspots(area):
			if item.id == dev_command.substr(5): _visit(item); pending.clear(); break
	elif dev_command == "knock": _knock()
	elif dev_command == "enter":
		_knock()
		if is_owner or not Data.at_home(hour).is_empty(): admitted = true; _switch_area("floor1")
	elif dev_command == "book": _life_book()
	elif dev_command in ["guitar","puzzle","album","relax","garden","fish","tv","record","workbench"]: _interact(dev_command if dev_command != "garden" else "garden_play")
	elif dev_command == "exit": admitted = false; _switch_area("exterior",Data.p(.55,.64))

func inspect_state() -> Dictionary:
	return {"area":area,"hour":hour,"month":month,"season":Data.SEASONS[Data.season(month)],"family":states.duplicate(true),"admitted":admitted,"owner":is_owner,"resting":resting,"player":player.position,"completed":journal.completed.duplicate()}
