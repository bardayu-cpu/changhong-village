extends Node
## Dedicated BGM player. It never changes the Master/SFX volume or gameplay saves.
signal changed
var enabled:=true
var unlocked:=false
var player:AudioStreamPlayer
var prefs_path:="user://village_music.cfg"
static func ensure(tree:SceneTree):
	var service=tree.root.get_node_or_null("VillageMusic")
	if service==null:
		service=load("res://ayu_home/v4/core/playtest_music.gd").new()
		service.name="VillageMusic";tree.root.add_child(service)
	return service
func _ready() -> void:
	var root:=preload("res://ayu_home/v4/core/playtest_paths.gd").data_root()
	if not root.is_empty():prefs_path=root.path_join("music.cfg")
	var prefs:=ConfigFile.new()
	if prefs.load(prefs_path)==OK:enabled=bool(prefs.get_value("music","enabled",true))
	player=AudioStreamPlayer.new();player.name="BackgroundMusic";add_child(player)
	player.stream=load("res://assets/splash/title_bgm.wav");player.volume_db=-18
	player.finished.connect(_play)
	unlocked=not OS.has_feature("web")
	_play()
func available() -> bool:return player!=null and player.stream!=null
func caption() -> String:return "背景音乐 · "+("开" if enabled else "关") if available() else "背景音乐 · 未配置音轨"
func unlock_from_gesture() -> void:unlocked=true;_play()
func toggle_from_gesture() -> void:
	unlocked=true;enabled=not enabled
	var prefs:=ConfigFile.new();prefs.set_value("music","enabled",enabled)
	var result:=prefs.save(prefs_path)
	if result!=OK:push_warning("BGM preference could not be saved: "+str(result))
	_play();changed.emit()
func _play() -> void:
	if player==null:return
	if not enabled or not unlocked:player.stop();return
	if available() and not player.playing:player.play()
