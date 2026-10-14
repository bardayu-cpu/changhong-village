extends SceneTree
const Basket=preload("res://ayu_home/v4/core/inventory_view.gd")
const State=preload("res://ayu_home/v4/core/state.gd")
const C=preload("res://ayu_home/v4/core/config.gd")
var failures:=0
var rows:Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok:bool,label:String) -> void:
	rows.append({"check":label,"pass":ok});if not ok:failures+=1
	print("PASS " if ok else "FAIL ",label)
func settle() -> void:
	for i in 6:await process_frame
func mouse(at:Vector2,pressed:bool) -> void:
	var e:=InputEventMouseButton.new();e.position=at;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed;Input.parse_input_event(e)
func touch(at:Vector2,pressed:bool) -> void:
	var e:=InputEventScreenTouch.new();e.position=at;e.index=0;e.pressed=pressed;Input.parse_input_event(e)
func run() -> void:
	root.size=Vector2i(360,800);root.content_scale_size=Vector2i.ZERO
	var s:=State.new();s.now_override=1000;s.data={"wallet":{"coins":120},"village":{"items":{},"blueprints":[],"clock":1000}}
	for id in C.ITEMS:s.data.village.items[id]=12
	var before:Dictionary=s.data.duplicate(true)
	var view:=Basket.new();root.add_child(view);view.setup(s,{});await settle()
	var first:String=view.entries[0];var target:String=view.entries[1];view.select_item(first)
	var at:Vector2=view.cards[target].get_global_rect().get_center()
	mouse(at,true);await process_frame;mouse(at,false);await settle()
	check(view.selected==target,"native mouse tap selects through Window/Control dispatch")
	view.select_item(first);view.scroll.scroll_vertical=0;await settle()
	at=view.cards[target].get_global_rect().get_center()+Vector2(0,24)
	mouse(at,true);await process_frame;mouse(at-Vector2(0,50),false);await settle()
	check(view.selected==first and view.scroll.scroll_vertical>=48,"50px within-card release drag scrolls without selecting even if motion was coalesced")
	var old_scroll:int=view.scroll.scroll_vertical
	at=view.scroll.get_global_rect().get_center();touch(at,true);await process_frame
	var drag:=InputEventScreenDrag.new();drag.index=0;drag.position=at-Vector2(0,100);drag.relative=Vector2(0,-100);Input.parse_input_event(drag);await process_frame
	touch(at-Vector2(0,100),false);await settle()
	check(view.selected==first and view.scroll.scroll_vertical>=old_scroll+98,"ScreenTouch/ScreenDrag routed through input pipeline scroll without selecting")
	view.scroll.scroll_vertical=0;view.select_item(first);await settle()
	at=view.cards[target].get_global_rect().get_center();touch(at,true);await process_frame;touch(at,false);await settle()
	check(view.selected==target,"ScreenTouch tap still selects through native mouse emulation")
	old_scroll=view.scroll.scroll_vertical;touch(Vector2(12,20),true);await process_frame
	drag=InputEventScreenDrag.new();drag.index=0;drag.position=Vector2(12,80);drag.relative=Vector2(0,60);Input.parse_input_event(drag);touch(Vector2(12,80),false);await settle()
	check(view.scroll.scroll_vertical==old_scroll,"outside-grid touch leaves basket scroll untouched")
	view.cards[target].grab_focus();await settle();check(view.selected==target and not view.dragging and view.touch_index<0,"focus selection works after both drag types end")
	check(s.data==before and s.path.is_empty(),"gestures neither consume items nor open/write a save")
	FileAccess.open("res://../回执/第1轮返工/篮子触摸-派发核对.json",FileAccess.WRITE).store_string(JSON.stringify({"mode":"headless native Window/Control input dispatch; not real hardware touch","failures":failures,"checks":rows},"\t")+"\n")
	view.queue_free();await settle();quit(0 if failures==0 else 1)
