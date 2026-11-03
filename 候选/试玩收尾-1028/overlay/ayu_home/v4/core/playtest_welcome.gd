extends Control
signal started
const UI=preload("res://ayu_home/v4/pixel_ui.gd")
const Assets=preload("res://ayu_home/v2/assets.gd")
const Music=preload("res://ayu_home/v4/core/playtest_music.gd")
var grid:GridContainer
var art:TextureRect
var menu_scroll:ScrollContainer
var primary:Button
var music_button:Button
var status:Label
var music
var save_status:="new"
static func read_saved(path:String):
	var parser:=JSON.new()
	return parser.data if parser.parse(FileAccess.get_file_as_string(path))==OK else null
static func current_save() -> String:
	var isolated:=preload("res://ayu_home/v4/core/playtest_paths.gd").data_root()
	if not isolated.is_empty():return isolated.path_join("life.json")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ayu-save="):return arg.substr(11)
	var profile_path:="user://ayu_home_local_player.json"
	if not FileAccess.file_exists(profile_path):return ""
	var profile=read_saved(profile_path)
	if not profile is Dictionary or str(profile.get("id","")).is_empty():return ""
	return "user://ayu_home_v4_"+str(profile.id).sha256_text().substr(0,20)+".json"
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var theme_resource:=Theme.new();theme_resource.default_font=UI.FONT;theme=theme_resource
	music=Music.ensure(get_tree())
	var bg:=ColorRect.new();bg.color=UI.DEEP;bg.mouse_filter=Control.MOUSE_FILTER_IGNORE;bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(bg)
	var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,20)
	add_child(margin)
	grid=GridContainer.new();grid.columns=2;grid.add_theme_constant_override("h_separation",28);grid.add_theme_constant_override("v_separation",14);margin.add_child(grid)
	art=TextureRect.new();art.texture=Assets.texture("res://ayu_home/v3/assets/thumb_exterior.png");art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;art.size_flags_horizontal=Control.SIZE_EXPAND_FILL;art.size_flags_vertical=Control.SIZE_EXPAND_FILL;grid.add_child(art)
	menu_scroll=ScrollContainer.new();menu_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;menu_scroll.follow_focus=true;menu_scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL;menu_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;grid.add_child(menu_scroll)
	var menu:=VBoxContainer.new();menu.size_flags_horizontal=Control.SIZE_EXPAND_FILL;menu.size_flags_vertical=Control.SIZE_SHRINK_CENTER;menu.add_theme_constant_override("separation",14);menu_scroll.add_child(menu)
	var title:=UI.label("裳泓村",42);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;menu.add_child(title)
	var edition:=UI.label("试玩版",22);edition.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;menu.add_child(edition)
	var path:=current_save()
	if not path.is_empty() and FileAccess.file_exists(path):
		var data=read_saved(path)
		save_status="continue" if data is Dictionary and int(data.get("version",0))==4 else "unreadable"
	primary=UI.button("继续试玩" if save_status=="continue" else "开始试玩",begin,true);primary.custom_minimum_size.y=56;menu.add_child(primary)
	music_button=UI.button(music.caption(),func():music.toggle_from_gesture());music_button.custom_minimum_size.y=52;menu.add_child(music_button)
	music.changed.connect(func():music_button.text=music.caption())
	status=UI.paragraph("点地面走路，走近人和东西再互动。",20);menu.add_child(status)
	var note:=UI.paragraph("本试玩单独存档，不影响原进度。\n电脑与手机存档不互通。\n村庄画面与内容仍在制作中。",18);menu.add_child(note)
	if save_status=="unreadable":primary.disabled=true;status.text="试玩存档暂未读出，原文件已保留。"
	get_viewport().size_changed.connect(adapt);adapt();primary.grab_focus()
	print("PLAYTEST_WELCOME save=",save_status," music=",music.enabled," source=",path)
func adapt() -> void:
	var size:=get_viewport_rect().size;var vertical:bool=size.x<760 or size.y>size.x
	grid.columns=1 if vertical else 2
	art.size_flags_vertical=Control.SIZE_SHRINK_CENTER if vertical else Control.SIZE_EXPAND_FILL
	art.custom_minimum_size=Vector2(0,minf(220,size.y*.28)) if vertical else Vector2(size.x*.42,0)
func begin() -> void:
	if primary.disabled:return
	music.unlock_from_gesture();primary.disabled=true;primary.text="正在准备…";started.emit()
func progress(copy:String) -> void:status.text=copy
func failed(copy:String) -> void:status.text=copy;primary.text="再试一次";primary.disabled=false
