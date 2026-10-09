extends SceneTree
## 分批下载用：量每个入口各要哪些图和声音（Assets.used 按入口清零再记）。
## boot＝打开阿鱼家就要的（人物、界面、面板、地图小图、对话头像）；room:房间＝进这间要的（四季早晚都走）；
## game:/immersive:/activity:＝打开这个小游戏要的。写成 JSON：--out=文件
const Home=preload("res://ayu_home/v4/home.gd")
const Assets=preload("res://ayu_home/v2/assets.gd")
const Games=preload("res://ayu_home/v4/life_games.gd")
var h;var groups:={}
func _initialize() -> void:call_deferred("run")
func tick(n:=6) -> void:
	for i in n:h._process(0.05);h.world._process(0.05)
	await process_frame
func take(name:String) -> void:
	if not groups.has(name):groups[name]={}
	for p in Assets.used:groups[name][p]=true
	Assets.used.clear()
func run() -> void:
	var out:="";for a in OS.get_cmdline_user_args():if a.begins_with("--out="):out=a.substr(6)
	var vp:=SubViewport.new();vp.size=Vector2i(540,960);root.add_child(vp)
	var save:=OS.get_user_data_dir()+"/asset-groups.json";DirAccess.remove_absolute(save)
	Assets.used.clear()
	h=Home.new();h.town_profile={"id":"asset-groups","avatar":2};h.save_path=save;h.first_visit=true;vp.add_child(h);await process_frame;h.set_process(false);h.sound_on=true;h.admitted=true
	h.welcome();await tick(20);h.close_modal()
	take("boot") # 开家、进院子、欢迎信、人和猫狗、顶栏
	for f in [h.family_page,h.life_book,h.today,h.settings_page,h.calendar_page,h.collection_page,h.album_page]:f.call();await tick(2);h.close_modal()
	for g in ["一楼","二楼","屋外"]:h.navigation(g);await tick(2);h.close_modal()
	for id in ["ayu","father","mother"]:h.family_card(id);await tick(2);h.close_modal();h.dialogue("x","y",id);await tick(2);h.close_modal()
	h.toggle_tools(true);await tick(2);h.toggle_tools(false)
	take("panels") # 地图、生活册、家里的人、对话头像这些面板
	var start:String=h.area
	for month in [4,7,10,1]:
		for hour in [8.0,12.2,18.5,22.5]:
			h.set_test_clock(hour,month,"rain" if month==7 else "clear");take("clock") # 换时间季节天气本身要的（雨声这些）
			for room in h.definitions:Assets.used.clear();h.enter_room(room,false);await tick(6);take("room:"+room)
	h.set_test_clock(14.5,10);Assets.used.clear()
	for kind in Games.TITLES:h.games.open(kind,h.life,{"hour":14.5,"month":10,"sound":true});await tick(4);h.games.close(false);take("game:"+kind)
	h.games.open("stars",h.life,{"hour":21.0,"month":10,"sound":true});await tick(4);h.games.close(false);take("game:stars")
	for kind in ["fish","tv","pet","stars","detail","room_detail"]:
		h.immersive.open(kind,{"hour":20.0,"month":10,"fish":[],"pet":"qiuqiu","room":"study","title":"书房","cfg":h.definitions.get("study",{})});await tick(4);h.immersive.close(false);take("immersive:"+kind)
	for kind in ["guitar","puzzle","album"]:h.activities.open(kind,{"month":10,"v2_art":true});await tick(4);h.activities.close();take("activity:"+kind)
	h.take_photo();await tick(4);take("photo")
	var result:={"start":start,"groups":{}}
	for g in groups:var ps:Array=groups[g].keys();ps.sort();result.groups[g]=ps
	if not out.is_empty():FileAccess.open(out,FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("GROUPS ",groups.size()," start=",start);print("RESULT PASS")
	h.stop_audio();quit()
