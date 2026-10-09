extends SceneTree
# Native-window review fixture. Ctrl+P records this game viewport; Ctrl+Q writes
# frame timing and exits. Its isolated save never touches the player's game.
const Home=preload("res://ayu_home/v4/home.gd")
var h
var frame_ms:Array=[]
var shot_index:=0
var capturing:=false
class Hotkeys extends Node:
	func _input(event:InputEvent) -> void:
		if event is InputEventKey and event.pressed and not event.echo and event.ctrl_pressed:
			if event.keycode==KEY_P:get_tree().call("record");get_viewport().set_input_as_handled()
			elif event.keycode==KEY_Q:get_tree().call("finish");get_viewport().set_input_as_handled()
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(540,960)
	root.position=Vector2i(120,60)
	root.content_scale_size=Vector2i(540,960)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://ayu_home/v4/evidence/manual"))
	h=Home.new();h.save_path="/private/tmp/ayu-v4-manual-review-final.json";h.town_profile={"id":"manual-review-final","avatar":2};root.add_child(h)
	h.set_test_clock(12.25);h.test_panel_enabled=true
	root.add_child(Hotkeys.new())
func _process(dt:float) -> bool:
	if h==null:return false
	if not capturing:frame_ms.append(dt*1000)
	return false
func record() -> void:
	capturing=true
	await process_frame;RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://ayu_home/v4/evidence/manual/native-%02d.png"%shot_index)
	shot_index+=1;capturing=false
func finish() -> void:
	frame_ms.sort()
	var f:=FileAccess.open("res://ayu_home/v4/evidence/manual/frame-timing.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"samples":frame_ms.size(),"median_ms":frame_ms[int(frame_ms.size()*.5)],"p95_ms":frame_ms[int(frame_ms.size()*.95)],"maximum_ms":frame_ms[-1],"screenshots":shot_index,"note":"Native window manual review, measured between screenshot captures; other machine tasks may still run. No FPS guarantee."},"  "));f.close();h.stop_audio();quit()
