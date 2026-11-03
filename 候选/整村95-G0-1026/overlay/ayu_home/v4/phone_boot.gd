extends Node
## 阿鱼家手机预览的开头（村C2 10/5）：先把阿鱼家的画从云上下到手机里（第一次约 31MB，之后读手机里的），
## 带进度条，下完打开阿鱼家。电脑上跑：工程里有原图，一张都不下，直接进。
const CloudRpc=preload("res://scripts/cloud.gd")
const CloudAssets=preload("res://ayu_home/v4/cloud_assets.gd")
const DS=preload("res://scripts/ui/dialog_skin.gd")
const UI=preload("res://ayu_home/v4/pixel_ui.gd")
const NativeCanvas=preload("res://ayu_home/v4/core/game_viewport.gd")
## 版本号（阿鱼 10/5 的规矩：总号 V大.中.小.版，所有发给阿鱼的码排一条线；模块号单记）
const VERSION:="1027 · 构图预览 · 地面未验"
var cloud:Node
var loader:Node
var line:Label
var count:Label
var bar:Control
var retry:Button
var done:=0
var total:=1
func _ready() -> void:
	if ProjectSettings.get_setting("application/config/candidate_enabled",false):
		var expected:=str(ProjectSettings.get_setting("application/config/candidate_os_userdata",""))
		if expected.is_empty() or OS.get_user_data_dir()!=expected:
			push_error("Candidate OS userdata identity mismatch; no gameplay opened");get_tree().quit(2);return
		print("CANDIDATE_BOOT build=",ProjectSettings.get_setting("application/config/candidate_build_id","")," executable=",OS.get_executable_path()," userdata=",OS.get_user_data_dir())
	NativeCanvas.configure_window(get_window())
	var layer:=CanvasLayer.new();add_child(layer)
	var bg:=ColorRect.new();bg.color=Color(DS.PAL.box.fill);bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);layer.add_child(bg)
	var col:=VBoxContainer.new();col.set_anchors_and_offsets_preset(Control.PRESET_CENTER);col.custom_minimum_size=Vector2(420,0);col.position-=Vector2(210,90);col.add_theme_constant_override("separation",16);layer.add_child(col)
	var title:=UI.label("裳泓村",36);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.add_theme_color_override("font_color",Color(DS.PAL.name));col.add_child(title)
	var version:=str(ProjectSettings.get_setting("application/config/candidate_build_id",VERSION))
	var ver:=UI.label(version,24);ver.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;ver.add_theme_color_override("font_color",Color(DS.PAL.box.rim));col.add_child(ver)
	line=UI.paragraph("正在打开裳泓村…",24);line.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;line.add_theme_color_override("font_color",Color(DS.PAL.text));col.add_child(line)
	bar=Control.new();bar.custom_minimum_size=Vector2(420,20);bar.draw.connect(draw_bar);col.add_child(bar)
	count=UI.label("",24);count.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;count.add_theme_color_override("font_color",Color(DS.PAL.text));col.add_child(count)
	retry=UI.button("再试一次",start,true);retry.visible=false;retry.size_flags_horizontal=Control.SIZE_SHRINK_CENTER;col.add_child(retry)
	cloud=CloudRpc.new();get_tree().root.add_child.call_deferred(cloud)
	loader=CloudAssets.new();loader.name="VillageDownloads";get_tree().root.add_child.call_deferred(loader)
	call_deferred("start")
## 进度条：深褐底里一条金色，像素硬边
func draw_bar() -> void:
	bar.draw_rect(Rect2(Vector2.ZERO,bar.size),Color(DS.PAL.box.edge))
	bar.draw_rect(Rect2(Vector2(2,2),bar.size-Vector2(4,4)),Color(DS.PAL.box.rim).darkened(.5))
	bar.draw_rect(Rect2(Vector2(2,2),Vector2((bar.size.x-4)*done/float(maxi(total,1)),bar.size.y-4)).abs(),Color(DS.PAL.name))
func start() -> void:
	retry.visible=false
	loader.setup(cloud)
	if loader.missing_cloud()>0:line.text="先下载院门口需要的画\n其他房间走到时再准备"
	var result:Dictionary=await loader.wait_group("boot",func(i:int,n:int):done=i;total=n;count.text="%d / %d"%[i,n];bar.queue_redraw())
	if not result.get("ok",false):
		print("[ayu] 下载没成功 ",result)
		line.text="没下载下来，网好一点再试试";count.text=str(result.get("reason",""));retry.visible=true;return
	loader.start_background()
	var home:Node=load("res://ayu_home/v4/home.tscn").instantiate()
	# 缓存齐了不用等时 start() 在 _ready 里同步跑完，这时根节点还在建子节点，直接 add_child 会失败（C3 10/5）：延后加
	var canvas:=NativeCanvas.new();canvas.game=home
	get_tree().root.set_meta("g0_review_build",true)
	get_tree().root.add_child.call_deferred(canvas);queue_free.call_deferred()
