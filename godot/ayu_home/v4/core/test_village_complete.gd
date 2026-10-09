extends SceneTree
const S=preload("res://ayu_home/v4/core/state.gd")
const C=preload("res://ayu_home/v4/core/config.gd")
const Life=preload("res://ayu_home/v4/life_state.gd")
const World=preload("res://ayu_home/v4/world.gd")
var checks:Array=[]
var failures:Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok:bool,label:String) -> void:
	checks.append({"ok":ok,"label":label})
	if not ok:failures.append(label);print("FAIL ",label)
func run() -> void:
	var folder=ProjectSettings.globalize_path("res://../测试数据/边界验收/");DirAccess.make_dir_recursive_absolute(folder)
	var path=folder+"shared"
	for ext in [".a",".b"]:DirAccess.remove_absolute(path+ext)
	var s=S.new();s.now_override=1791327600;check(s.open({"id":"boundary"},path),"独立测试存档可建立")
	var life=Life.new();life.open({"id":"boundary"},folder+"legacy.json")
	life.data.basket={"radish":3,"tomato":2};life.data.seeds={"radish":6,"tomato":4};life.base=life.data.duplicate(true)
	check(s.act("import_household_inventory",{"data":life.data}).ok,"旧家庭库存迁入")
	var count=s.count("radish");check(not s.act("import_household_inventory",{"data":life.data}).ok and s.count("radish")==count,"迁移重复执行不复制库存")
	life.shared_state=s;life.sync_inventory();life.data.basket.tomato-=1;check(life.save() and s.count("tomato")==1,"旧厨房消耗写入共同库存")
	check(s.act("sell",{"id":"radish"}).ok,"新玩法能消耗旧篮子的萝卜")
	life.sync_inventory();var old=s.count("radish");life.data.notes.append("边界测试留言");check(life.save() and s.count("radish")==old,"生活册保存不重复增减物品")
	check(life.data.basket.radish==s.count("radish"),"两处萝卜数量一致")
	# Synthetic inputs and clock belong only to this boundary file, never the graphic playthrough.
	s.put("grain",30);s.put("flour",3);s.put("fruit",8);s.put("egg",8);s.persist()
	for id in C.PRODUCERS:
		check(s.act("producer_start",{"id":id}).ok,id+"可开始生产")
		var items=s.data.village.items.duplicate(true)
		check(not s.act("producer_start",{"id":id}).ok and items==s.data.village.items,id+"重复开工不扣物品")
		check(not s.act("producer_collect",{"id":id}).ok,id+"不能提前收取")
	s.now_override+=300
	for id in C.PRODUCERS:
		check(s.act("producer_collect",{"id":id}).ok,id+"完成可收")
		var items=s.data.village.items.duplicate(true)
		check(not s.act("producer_collect",{"id":id}).ok and items==s.data.village.items,id+"不能重复收取")
	for id in C.NEIGHBOURS:
		check(s.act("neighbour",{"id":id}).ok,id+"邻居需求可完成")
		var coins=s.data.wallet.coins
		check(not s.act("neighbour",{"id":id}).ok and coins==s.data.wallet.coins,id+"同日不重复奖励")
	check(s.data.renqing.size()==2,"两位普通居民均记人情")
	check(s.act("season_help",{"weather":"rain","season":"秋"}).ok,"雨天留谷子有结果")
	check(not s.act("season_help",{"weather":"clear","season":"秋"}).ok,"换天气不能重领当天小事")
	var req=s.neighbour_request("honey");check(req.has("fruit"),"帮过阿禾后换下一条需求")
	s.now_override+=86400;check(s.act("neighbour",{"id":"honey"}).ok,"第二天邻居仍记得前次帮助并可继续")
	check(s.data.village.helped.honey==2 and s.neighbour_request("honey").has("egg"),"第三次回访的需求不同")
	check(s.act("fishing_reward",{"id":"boundary-fish"}).ok and not s.act("fishing_reward",{"id":"boundary-fish"}).ok,"钓鱼奖励唯一")
	var snap=JSON.parse_string(JSON.stringify(s.data))
	for i in 2:
		var reopened=S.new();reopened.now_override=s.now_override;check(reopened.open({"id":"boundary"},path) and reopened.data==snap,"完整生活状态重开"+str(i+1));s=reopened
	for ext in [".a",".b"]:FileAccess.open(path+ext,FileAccess.WRITE).store_string("broken")
	var damaged=S.new();check(not damaged.open({"id":"boundary"},path) and damaged.blocked,"两槽都损坏会保护旧文件并停止写入")
	life.close_open()
	# Geometry validation executes the same pathfinder used by normal gameplay.
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://ayu_home/v4/assets/rooms.json"))
	var hs=JSON.parse_string(FileAccess.get_file_as_string("res://ayu_home/v4/assets/village/houses.json"))
	check(hs.size()==19,"十九处建筑完整覆盖")
	for id in manifest.rooms:
		var w=World.new();w.nav_only=true;root.add_child(w);w.load_room(id)
		var start=w.nearest(World.v(w.cfg.spawn))
		for dr in w.cfg.doors:
			check(manifest.rooms.has(dr.target),id+":"+dr.id+"目标存在")
			var target=w.nearest(World.v(dr.approach));var route=w.path(start,target)
			check(start.distance_to(target)<8 or not route.is_empty(),id+":"+dr.id+"步行可到")
		for spot in w.cfg.hotspots:
			var target=w.nearest(World.v(spot.approach));var route=w.path(start,target)
			check(start.distance_to(target)<8 or not route.is_empty(),id+":"+spot.id+"互动点可到")
		for prop in w.cfg.props:check(FileAccess.file_exists(w.asset_path(prop.file)),id+":"+prop.id+"素材存在")
		w.queue_free();await process_frame
	var result={"kind":"isolated_boundary_and_navigation_not_real_time_play","passed":checks.size()-failures.size(),"total":checks.size(),"failures":failures,"checks":checks}
	FileAccess.open(ProjectSettings.globalize_path("res://../交付/完整村庄-1006/边界与全屋通路验收.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("RESULT ","PASS" if failures.is_empty() else "FAIL"," ",checks.size()," ",failures)
	quit(0 if failures.is_empty() else 1)
