extends SceneTree
## 量包体用：把阿鱼家能去的地方都走一遍（每间房、白天晚上、四季），小游戏、近看、活动、面板都开一遍，
## 最后把真用到的图和声音（Assets.used）列出来：--out=文件 写成一行一个 res:// 路径
const Home=preload("res://ayu_home/v4/home.gd")
const Assets=preload("res://ayu_home/v2/assets.gd")
const Games=preload("res://ayu_home/v4/life_games.gd")
var h
func _initialize() -> void:call_deferred("run")
func tick(n:=20) -> void:
	for i in n:h._process(0.05);h.world._process(0.05)
	await process_frame
func run() -> void:
	var out:="";for a in OS.get_cmdline_user_args():if a.begins_with("--out="):out=a.substr(6)
	var vp:=SubViewport.new();vp.size=Vector2i(540,960);root.add_child(vp)
	var save:=OS.get_user_data_dir()+"/asset-tour.json";DirAccess.remove_absolute(save)
	h=Home.new();h.town_profile={"id":"asset-tour","avatar":2};h.save_path=save;h.first_visit=true;vp.add_child(h);await process_frame;h.set_process(false);h.sound_on=true;h.admitted=true
	h.welcome();await tick(2);h.close_modal()
	for month in [4,7,10,1]:
		for hour in [8.0,12.2,18.5,22.5]:
			h.set_test_clock(hour,month,"rain" if month==7 else "clear")
			for room in h.definitions:h.enter_room(room,false);await tick(6)
	h.set_test_clock(14.5,10)
	for kind in Games.TITLES:h.games.open(kind,h.life,{"hour":14.5,"month":10,"sound":true});await tick(4);h.games.close(false)
	h.games.open("stars",h.life,{"hour":21.0,"month":10,"sound":true});await tick(4);h.games.close(false)
	for kind in ["fish","tv","pet","stars","detail","room_detail"]:
		h.immersive.open(kind,{"hour":20.0,"month":10,"fish":[],"pet":"qiuqiu","room":"study","title":"书房","cfg":h.definitions.get("study",{})});await tick(4);h.immersive.close(false)
	for kind in ["guitar","puzzle","album"]:h.activities.open(kind,{"month":10,"v2_art":true});await tick(4);h.activities.close()
	for f in [h.family_page,h.life_book,h.today,h.settings_page,h.calendar_page,h.collection_page,h.album_page]:f.call();await tick(2);h.close_modal()
	for g in ["一楼","二楼","屋外"]:h.navigation(g);await tick(2);h.close_modal()
	for id in ["ayu","father","mother"]:h.family_card(id);await tick(2);h.close_modal();h.dialogue("x","y",id);await tick(2);h.close_modal()
	h.take_photo();await tick(4)
	var paths:Array=Assets.used.keys();paths.sort()
	if not out.is_empty():
		var fh:=FileAccess.open(out,FileAccess.WRITE);for p in paths:fh.store_line(p)
	print("USED ",paths.size());print("RESULT PASS")
	h.stop_audio();quit()
