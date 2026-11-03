extends Node
const CloudRpc=preload("res://scripts/cloud.gd")
const CloudAssets=preload("res://ayu_home/v4/cloud_assets.gd")
const NativeCanvas=preload("res://ayu_home/v4/core/game_viewport.gd")
const Welcome=preload("res://ayu_home/v4/core/playtest_welcome.gd")
var cloud:Node
var loader:Node
var welcome:Control
func _ready() -> void:
	if not preload("res://ayu_home/v4/core/playtest_paths.gd").prepare():
		push_error("Playtest save folder unavailable; existing saves were not opened");get_tree().quit(2);return
	if ProjectSettings.get_setting("application/config/candidate_enabled",false):
		var expected:=str(ProjectSettings.get_setting("application/config/candidate_os_userdata",""))
		if expected.is_empty() or OS.get_user_data_dir()!=expected:
			push_error("Candidate OS userdata identity mismatch; no gameplay opened");get_tree().quit(2);return
		print("CANDIDATE_BOOT build=",ProjectSettings.get_setting("application/config/candidate_build_id","")," executable=",OS.get_executable_path()," userdata=",OS.get_user_data_dir())
	NativeCanvas.configure_window(get_window())
	cloud=CloudRpc.new();get_tree().root.add_child.call_deferred(cloud)
	loader=CloudAssets.new();loader.name="VillageDownloads";get_tree().root.add_child.call_deferred(loader)
	call_deferred("show_welcome")
func show_welcome() -> void:
	var layer:=CanvasLayer.new();add_child(layer)
	welcome=Welcome.new();layer.add_child(welcome);welcome.started.connect(start)
func start() -> void:
	loader.setup(cloud)
	welcome.progress("正在准备院子…")
	var result:Dictionary=await loader.wait_group("boot",func(i:int,n:int):welcome.progress("正在准备 %d / %d"%[i,n]))
	if not result.get("ok",false):
		welcome.failed("没准备好，网络恢复后可再试。原存档不会清除。");return
	loader.start_background()
	var home:Node=load("res://ayu_home/v4/home.tscn").instantiate()
	var canvas:=NativeCanvas.new();canvas.game=home
	get_tree().root.add_child.call_deferred(canvas);queue_free.call_deferred()
