extends SceneTree
## 只测真实布局方法；不启动游戏、不写正式存档，也不替代 C3 正常操作截图。
class LayoutHome extends "res://ayu_home/v4/home.gd":
	func _ready() -> void:pass
	func _process(_dt:float) -> void:pass
	func busy() -> bool:return false
	func outdoors() -> bool:return true
class LayoutWorld extends Node2D:
	var cfg:Dictionary={}
	func nearest(at:Vector2) -> Vector2:return at
class LayoutPlayer extends Node2D:
	var action:="idle"
	var lift:=0.0
	var pet:=false
	var bubble_time:=0.0
	var bubble_allowed:=true
	func head_top() -> float:return -84.0
var failures:Array[String]=[]
func check(ok:bool,label:String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok:failures.append(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	for height in [960,1200]:
		root.size=Vector2i(540,height)
		var h:=LayoutHome.new();root.add_child(h);h.set_process(false)
		h.world=LayoutWorld.new();h.add_child(h.world)
		h.player=LayoutPlayer.new();h.world.add_child(h.player)
		h.make_ui();h.layout()
		var bottom:=Button.new();h.ui.add_child(bottom)
		bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		bottom.offset_left=14;bottom.offset_right=514;bottom.offset_top=-136;bottom.offset_bottom=-80
		await process_frame
		var visible_size:=h.get_viewport_rect().size
		check(is_equal_approx(visible_size.y,height),"viewport %d"%height)
		h.player.position=Vector2(270,height-80)
		h.world.cfg={"hotspots":[],"doors":[{"id":"exit","target":"village","label":"出门回到村里","pos":[270,height-80],"approach":[270,height-80]}]}
		h.make_markers();h.layout_markers()
		await process_frame
		h.layout_markers()
		var hit:Control=h.near_tag.get_node("TagHit")
		check(h.near_tag.visible and h.marker_nodes[0].button.visible,"bottom door prompt visible %d"%height)
		check(hit.get_global_rect().end.y<=h.interaction_bottom()+.1,"entire label click area above safe edge %d"%height)
		check(not hit.get_global_rect().intersects(bottom.get_global_rect()),"label does not overlap bottom buttons %d"%height)
		h.player.action="sit";h.scene_buttons([["起身",func():pass]])
		await process_frame
		h.place_scene_controls(visible_size,h.hud_bottom()+4,h.interaction_bottom(),[Rect2(0,0,540,height-95)])
		check(h.scene_controls.get_global_rect().end.y<=h.interaction_bottom()+.1,"seated action stays above safe edge after speech avoidance %d"%height)
		check(not h.scene_controls.get_global_rect().intersects(bottom.get_global_rect()),"seated action does not overlap bottom buttons %d"%height)
		h.free()
	print("B2_LAYOUT "+("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
