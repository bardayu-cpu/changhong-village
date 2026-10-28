extends Control
## One native game canvas uses the actual window, without a second scale.
var game:Node
var holder:SubViewportContainer
var play:SubViewport
var game_rect:=Rect2()
var trace_input:=false
class InputTrace extends Node:
	func _input(event:InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:print("G0_INPUT mouse=",event.button_index," canvas_pos=",event.position)
		elif event is InputEventKey and event.pressed and not event.echo:print("G0_INPUT key=",event.keycode)
static func configure_window(window:Window) -> void:
	window.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	window.content_scale_factor=1.0
	window.content_scale_size=Vector2i.ZERO
func _ready() -> void:
	configure_window(get_window())
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	holder=SubViewportContainer.new();holder.name="NativeGameCanvas"
	holder.stretch=false;holder.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	holder.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(holder)
	play=SubViewport.new();play.name="NativeGameViewport"
	play.disable_3d=true;play.handle_input_locally=true
	play.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	play.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	holder.add_child(play)
	trace_input="--g0-input-trace" in OS.get_cmdline_user_args()
	if trace_input:
		play.add_child(InputTrace.new())
		get_tree().node_added.connect(trace_new_button)
	get_viewport().size_changed.connect(resize_canvas);resize_canvas()
	if game!=null:play.add_child.call_deferred(game)
func trace_new_button(button:Node) -> void:
	if button is BaseButton and play.is_ancestor_of(button):button.pressed.connect(func():print("G0_BUTTON ",str(button.get("text"))))
func resize_canvas() -> void:
	var host:=Vector2i(get_viewport_rect().size)
	var logical:=Vector2i(maxi(1,host.x),maxi(1,host.y))
	play.size=logical
	holder.position=Vector2(floori((host.x-logical.x)*.5),0)
	holder.size=Vector2(logical)
	game_rect=Rect2(holder.position,Vector2(logical))
func canvas_snapshot() -> Dictionary:
	return {"host":get_viewport_rect().size,"game_buffer":play.size,"game_rect":game_rect,"root_scale_mode":get_window().content_scale_mode,"root_scale_factor":get_window().content_scale_factor,"input":"native SubViewportContainer routing; no duplicated manual mouse transform"}
