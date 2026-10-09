extends SceneTree
## 能点的东西点击区都至少 44×44（组件库，002 10/5）：540×960 下顶栏、小包、提示泡、名字小牌、场景按钮、叫吃饭、各面板里的按钮都量一遍
## （透明罩子算在里面：一个按钮连同它下面的透明按钮，取合起来的范围）；再真点一下「小事」罩子边上，看能不能开今日小事
const Home=preload("res://ayu_home/v4/home.gd")
var h;var vp:SubViewport;var bad:Array=[];var n:=0
func _initialize() -> void:call_deferred("run")
func tick(k:=10) -> void:
	for i in k:h._process(0.05);h.world._process(0.05)
	await process_frame;await process_frame
func area(b:Control) -> Rect2:
	var r:=b.get_global_rect()
	for c in b.get_children():
		if c is Button and c.mouse_filter!=Control.MOUSE_FILTER_IGNORE:r=r.merge(c.get_global_rect())
	return r
func scan(tag:String,node:Node) -> void:
	if node is Button and node.is_visible_in_tree() and node.mouse_filter!=Control.MOUSE_FILTER_IGNORE and not (node.get_parent() is Button):
		var r:=area(node);n+=1
		if r.size.x<44-0.5 or r.size.y<44-0.5:bad.append("%s：「%s」%d×%d"%[tag,node.text if not node.text.is_empty() else node.name,r.size.x,r.size.y])
	for c in node.get_children():scan(tag,c)
func run() -> void:
	vp=SubViewport.new();vp.size=Vector2i(540,960);root.add_child(vp)
	var save:=OS.get_user_data_dir()+"/tap-targets.json";DirAccess.remove_absolute(save)
	h=Home.new();h.town_profile={"id":"tap-targets","avatar":2};h.save_path=save;vp.add_child(h);await process_frame;h.set_process(false);h.sound_on=false;h.admitted=true;h.close_modal();h.set_test_clock(14.5)
	h.enter_room("living",false);h.player.position=h.world.nearest(Vector2(200,300));h.camera=h.player.position;await tick(20)
	scan("客厅",h.ui)
	h.toggle_tools(true);await tick(2);scan("小包打开",h.ui);h.toggle_tools(false)
	h.enter_room("guest",false);var bed:Dictionary=h.world.spot("bed");h.player.position=h.world.nearest(Vector2(200,250));await tick(10)
	if not bed.is_empty():h.stay_choices(bed);await tick(3);scan("客房床边",h.ui);h.clear_scene_controls()
	h.life.data.resident=true;h.life.data.invites.clear();h.set_test_clock(12.1);h.enter_room("living",false);h.check_meal_invite();await tick(3);scan("叫吃饭",h.ui);h.dismiss_invite()
	for pair in [["家里的人",h.family_page],["今日小事",h.today],["生活册",h.life_book],["设置",h.settings_page],["地图",func():h.navigation("一楼")],["挂历",h.calendar_page],["收集册",h.collection_page],["人物卡",func():h.family_card("father")]]:
		pair[1].call();await tick(2);scan(pair[0],h.ui);h.close_modal()
	# 真点「小事」罩子的上沿（字本身外面那一截）
	h.set_test_clock(14.5);h.enter_room("living",false);await tick(4)
	var tb:Button=h.task_button;var hit:Control=tb.get_node("TaskHit");var p:=Vector2(tb.get_global_rect().get_center().x,hit.get_global_rect().position.y+2)
	check_click(p)
	for down in [true,false]:
		var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;e.position=p;vp.push_input(e,true);await process_frame
	await tick(2)
	if h.modal==null:bad.append("点「小事」字外面上沿 %s 没开今日小事"%str(p))
	print("量了 %d 个能点的；小事能点 %s"%[n,str(area(tb).size)])
	for b in bad:print("不行 ",b)
	print("RESULT PASS" if bad.is_empty() and n>30 else "RESULT FAIL")
	h.stop_audio();quit()
func check_click(p:Vector2) -> void:
	if h.task_button.get_global_rect().has_point(p):bad.append("点的地方还在字的框里，没测到罩子")
