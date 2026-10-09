extends SceneTree
## 查开头哪一步读了一楼、二楼的底图（分批下载要把开头那批压小）
const Home=preload("res://ayu_home/v4/home.gd")
const Assets=preload("res://ayu_home/v2/assets.gd")
var h
func _initialize() -> void:call_deferred("run")
func show(tag:String) -> void:
	var big:=[]
	for p in Assets.used:if "approved-2" in p or "floor1.png" in p or "grove.png" in p:big.append(p.get_file())
	print(tag," 一共 ",Assets.used.size()," 个；楼里底图：",big," 现在在 ",h.area if h else "-")
func run() -> void:
	var vp:=SubViewport.new();vp.size=Vector2i(540,960);root.add_child(vp)
	var save:=OS.get_user_data_dir()+"/probe-boot.json";DirAccess.remove_absolute(save);Assets.used.clear()
	h=Home.new();h.town_profile={"id":"probe-boot","avatar":2};h.save_path=save;h.first_visit=true;vp.add_child(h);await process_frame;show("建好家")
	h.set_process(false)
	for i in 5:h._process(0.05);h.world._process(0.05)
	show("走 5 帧")
	for i in 200:h._process(0.05);h.world._process(0.05)
	show("走 200 帧")
	h.welcome();await process_frame;show("欢迎信")
	quit()
