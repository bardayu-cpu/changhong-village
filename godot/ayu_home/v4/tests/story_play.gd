extends "res://ayu_home/v4/tests/play_gestures.gd"
var travel_log:Array=[]
var frame_times:Array=[]
var last_sample:=0.0
func walk_to(id:String) -> void:
	h.go(id);var until:=Time.get_ticks_msec()+90000
	while not h.pending.is_empty() and h.modal==null and Time.get_ticks_msec()<until:await wait_for(.4)
	if h.transition:await wait_for(.55)
	check(h.pending.is_empty(),"步行操作 "+h.area+" / "+id)
func travel(room:String) -> void:
	var count:=0
	while h.area!=room and count<20:
		var hop:String=h.room_hop(h.area,room);await walk_to("to_"+hop);count+=1
		if h.modal:await close_talk()
	check(h.area==room,"实际穿门到 "+room);travel_log.append({"room":room,"seconds":(Time.get_ticks_msec()-started)/1000.0})
## 第七轮起对话框照罗曼：一句话的对话没有「跳过」，点框往下走、说完就收（村-1）。这里照玩家那样一下下点框
func close_talk() -> void:
	var guard:=0
	while h.talk_ui!=null and guard<30:
		var box:Control=h.talk_ui.talk_box
		if not h.DSkin.typing(box) and not h.DSkin.last_page(box):
			var down:Button=box.find_child("page_down",true,false);down.pressed.emit() # 一页放不下：点右边的下三角翻页
		else:h.advance_dialogue()
		guard+=1;await wait_for(.2)
	check(h.talk_ui==null,"点框把对话说完收起")
func close_all() -> void:
	h.games.close(false);h.activities.close();h.immersive.close(false);h.photo.close(false);h.close_modal();h.clear_scene_controls();h.stand_up();h.dismiss_invite()
func run() -> void:
	started=Time.get_ticks_msec();DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var file:="/private/tmp/ayu-v4-story-flow-final.json" if OS.get_cmdline_user_args().has("--story-flow-only") else "/private/tmp/ayu-v4-story-play.json"
	if FileAccess.file_exists(file):DirAccess.remove_absolute(file)
	vp=SubViewport.new();vp.size=Vector2i(540,960);vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;vp.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST;root.add_child(vp)
	h=Home.new();h.town_profile={"id":"story-first-time","avatar":2};h.save_path=file;h.first_visit=true;vp.add_child(h);await process_frame;await process_frame;h.set_test_clock(12.25);begin("first-visit");await wait_for(1);await button("看看今日小事");await wait_for(2);await button("收起")
	await walk_to("to_living");if h.modal:await close_talk()
	await wait_for(1);check(h.admitted and h.area=="living","第一次敲门获邀进家")
	await travel("guest");begin("stay-and-sleep");await walk_to("bed");await button("留宿住下");await close_talk();await wait_for(2);check(h.life.data.resident and h.player.action=="sleep","留宿且真正躺下")
	await button("醒来");await wait_for(1.2)
	begin("meal-invitation");h.check_meal_invite();await wait_for(1);check(h.invite_panel!=null,"饭点由在家的人邀请");await button("这就下楼");await wait_for(1);await button("给家人夹菜");await wait_for(1);await button("碰个杯");await wait_for(2);check(h.player.action in ["drink","eat"],"端杯吃饭动作");await button("起身")
	begin("chores");await walk_to("person:mother");await wait_for(1);await close_talk();check(h.life.daily_tasks()[0].accepted,"接下家人的小事")
	await travel("kitchen");begin("running-water");await walk_to("sink");await wait_for(2);check(h.water_audio.playing,"开水龙头持续有水声");await walk_to("sink");await wait_for(.5);check(not h.water_audio.playing,"关水即停")
	await travel("guest_bath");begin("shower");await walk_to("shower");await wait_for(7);check(h.life.data.completed.has("shower"),"洗澡暗场与热气");close_all()
	await travel("cats");h.set_test_clock(23);begin("pets")
	for id in ["qiuqiu","luoluo","tiantian"]:
		await walk_to("person:"+id);await wait_for(.4);await button("喂猫条");await button("逗一逗");await wait_for(1.4);check(h.area=="cats","找猫不被门传走 "+id)
	check(h.life.cats_today()==3,"三猫场景交互复测");close_all()
	h.set_test_clock(20);await travel("living");begin("family-tv");await walk_to("tv");await wait_for(1);await button("换个节目");await wait_for(1);await button("换个节目");await wait_for(1);await button("起身")
	await travel("grove");h.set_test_clock(20,7);begin("swing");await walk_to("swing");await wait_for(5);check(h.player.action=="swing","在真正树林秋千上坐着荡");await button("看天空");await wait_for(3);await button("收起");await button("起身")
	begin("polaroid-reload");h.take_photo();await wait_for(.5);await button("咔嚓，拍一张");await wait_for(3.2);await button("收进相册");await button("收起");h.life.save();var saved=Home.Life.new();saved.open(h.profile,file);check(saved.data.resident and saved.data.photos.size()==1,"重新读档保留住下身份与相片")
	h.photo.open(h.life,h.life.data.photos.back(),true);await wait_for(2);await button("收起")
	segment="";close_all();h.set_test_clock(11.95,10);h.enter_room("kitchen",false);var before:Dictionary=h.family_state.duplicate(true);h.test_hour=12.1;h.read_clock();h.sync_family(false);begin("family-walking")
	await wait_for(8);await travel("dining");await wait_for(8);var moved:=false
	for id in h.Data.FAMILY:
		if h.family_state[id].pos.distance_to(before[id].pos)>20 or h.family_state[id].room!=before[id].room:moved=true
	check(moved,"作息变动后沿房间路线走动");segment=""
	# Sustained real-time traversal and repeatable interactions. This measures durability,
	# not a claim that a human found thirty minutes entertaining.
	var sequence:Array=["oldhouse","garden","grove","kitchen","dining","cats","study","ayu_room","terrace","guest","workshop","garage","exterior","living"]
	var flow_only:bool=OS.get_cmdline_user_args().has("--story-flow-only")
	var round:=0
	while not flow_only and Time.get_ticks_msec()-started<1800000:
		close_all();var room:String=sequence[round%sequence.size()];await travel(room)
		var spots:Array=h.world.cfg.hotspots
		if not spots.is_empty():
			await walk_to(str(spots[round%spots.size()].id));await create_timer(2).timeout;close_all()
		for n in 20:
			await process_frame;frame_times.append(h.get_process_delta_time())
		if round%4==0:
			begin("thirty-minute-route");frame_no=round;await shot();segment=""
		print("SOAK ",JSON.stringify({"seconds":(Time.get_ticks_msec()-started)/1000.0,"room":h.area,"round":round,"saved":h.life.save(),"steps":h.stair_steps}));round+=1
		await create_timer(5).timeout
	var elapsed_seconds:=(Time.get_ticks_msec()-started)/1000.0
	var output_path:="res://ayu_home/v4/evidence/story-flow-final.json" if flow_only else "res://ayu_home/v4/evidence/story-play.json"
	var f:=FileAccess.open(output_path,FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures,"real_seconds":elapsed_seconds,"room_visits":travel_log,"repeat_rounds":round,"frame_seconds":frame_times,"identity":"isolated test player; automatic real input and real wall clock","not_a_human_fun_rating":true},"\t"));f.close()
	print("RESULT ","PASS" if failures.is_empty() else "FAIL", " story ",elapsed_seconds," seconds ",JSON.stringify(failures));h.stop_audio();vp.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
