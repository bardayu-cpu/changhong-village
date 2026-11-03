extends SceneTree
const State=preload("res://ayu_home/v4/core/state.gd")
const C=preload("res://ayu_home/v4/core/config.gd")
const Interface=preload("res://ayu_home/v4/core/interface.gd")
var failures:Array[String]=[]
var checks:=0
var api
var state
var view
var measurements:Array=[]
class HomeStub extends Node:
	var ui:=Control.new()
	var cooldown:=0.0
	func _init() -> void:add_child(ui)
	func close_modal() -> void:pass
	func play_sound(_name:String) -> void:pass
func _initialize() -> void:call_deferred("run")
func check(ok:bool,label:String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok:failures.append(label)
func settle() -> void:
	for i in 8:await process_frame
func emit_action() -> void:
	check(is_instance_valid(view.action_button) and not view.action_button.disabled,"context action available")
	if is_instance_valid(view.action_button):
		var final_size:Vector2=view.action_button.get_global_rect().size*root.get_final_transform().get_scale()
		check(final_size.x>=44 and final_size.y>=44 and view.details.size.y<=264 and view.outer.get_combined_minimum_size().y<=view.size.y,"action and detail fit narrow screen without shrinking touch targets")
	if is_instance_valid(view.action_button) and not view.action_button.disabled:view.action_button.pressed.emit()
	await settle()
func inspect_layout(screen:Vector2i) -> void:
	root.size=screen;await settle();view.fit_viewport();await settle()
	var factor:=root.get_final_transform().get_scale();var rectangle:Rect2=view.get_global_rect()
	check((rectangle.size*factor).distance_to(Vector2(screen))<1,"basket alone matches final window "+str(screen))
	check(view.grid.columns==(3 if screen.x-44<420 else 4),"columns from final usable width "+str(screen))
	check(view.outer.get_combined_minimum_size().x<=view.size.x and view.outer.get_combined_minimum_size().y<=view.size.y,"no page overflow "+str(screen))
	var bounds:=Rect2(Vector2.ZERO,view.size)
	var end:Vector2=view.get_global_transform().affine_inverse()*view.details.get_global_rect().end
	check(end.x<=bounds.end.x and end.y<=bounds.end.y-25,"details above bottom safe edge "+str(screen))
	var touch_ok:=true
	for b in view.controls.values():
		if not b is BaseButton:continue
		var final_size:Vector2=b.get_global_rect().size*factor
		if final_size.x<44 or final_size.y<44:touch_ok=false
	check(touch_ok,"all button touch targets at least 44px "+str(screen))
	view.back.grab_focus();view.scroll.scroll_vertical=0;await settle()
	var visible_cards:=0;var visible:Rect2=view.scroll.get_global_rect()
	for card in view.cards.values():
		if visible.encloses(card.get_global_rect()):visible_cards+=1
	if screen==Vector2i(540,960):check(visible_cards>=16,"540 first screen shows at least sixteen complete cards")
	if screen==Vector2i(360,800):check(visible_cards>=9,"360 first screen shows at least nine complete cards")
	var before:Vector2=view.details.global_position
	view.scroll.scroll_vertical=100000;await settle()
	var last:Control=view.cards[view.entries[-1]]
	check(visible.encloses(last.get_global_rect()),"last card scrolls fully into view "+str(screen))
	check(view.details.global_position==before and view.scroll.get_global_rect().end.y<=before.y,"scroll never moves/overlaps fixed details "+str(screen))
	measurements.append({"screen":[screen.x,screen.y],"basket_size":[view.size.x,view.size.y],"columns":view.grid.columns,"first_screen_complete_cards":visible_cards,"details_height":view.details.size.y,"scroll_height":view.scroll.size.y})
	print("GEOMETRY ",JSON.stringify(measurements[-1]))
func run() -> void:
	# These are isolated headless boundary fixtures, never a user's save or C3 N6 evidence.
	var path:="res://../测试数据/C2-basket-v2"
	for ext in [".a",".b"]:DirAccess.remove_absolute(path+ext)
	state=State.new();check(state.open({"id":"c2-basket-v2"},path),"isolated state opens")
	for id in C.ITEMS:state.data.village.items[id]=12
	state.data.wallet.coins=120;state.data.village.blueprints=["chair"];state.persist()
	var host:=HomeStub.new();root.add_child(host);api=Interface.new();api.state=state;api.home=host;root.add_child(api)
	api.order_button=Button.new();host.ui.add_child(api.order_button)
	root.content_scale_size=Vector2i(540,960);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
	api.show_page("篮子");view=api.root;await settle()
	check(view.entries.size()==C.ITEMS.size(),"all positive real inventory keys listed")
	check(view.action_button==null,"ordinary food has no invented action")
	for screen in [Vector2i(540,960),Vector2i(540,1200),Vector2i(360,800),Vector2i(320,720)]:await inspect_layout(screen)
	view.cards.radish.grab_focus();await settle()
	var key:=InputEventAction.new();key.action="ui_down";key.pressed=true;Input.parse_input_event(key);await settle()
	check(root.gui_get_focus_owner()==view.cards.radish_seed and view.selected=="radish_seed","keyboard moves by current columns and updates selected detail")
	key=InputEventAction.new();key.action="ui_down";key.pressed=false;Input.parse_input_event(key)
	var inventory_before:Dictionary=state.data.duplicate(true)
	view.select_item("parcel");await settle();check(state.data==inventory_before,"selection never consumes")
	var old_scroll:int=view.scroll.scroll_vertical;view.cards.parcel.grab_focus();await settle();old_scroll=view.scroll.scroll_vertical
	await emit_action();check(state.count("parcel")==11 and state.data.wallet.coins==120,"animal parcel consumes exactly one, no coins")
	check(view.selected=="parcel" and view.scroll.scroll_vertical==old_scroll,"action preserves valid selection and scroll")
	check(root.gui_get_focus_owner()==view.cards.parcel,"action restores card focus")
	view.switch_group("seeds");await settle();view.select_item("pepper_seed");await settle()
	var old_seed:int=state.count("pepper_seed");await emit_action()
	check(state.count("pepper_seed")==old_seed+1 and state.data.wallet.coins==120-C.SEED_COST,"seed command uses selected crop and real price")
	view.switch_group("plans");await settle();check(view.selected=="chair" and view.entries.size()==13,"twelve plans plus virtual box; default first furniture")
	var bamboo:int=state.count("bamboo");var furniture:int=state.data.village.furniture.size();await emit_action()
	check(state.count("bamboo")==bamboo-C.FURNITURE.chair.items.bamboo and state.data.village.furniture.size()==furniture+1,"craft consumes exact materials and adds one furniture")
	view.select_item("notice_easel");await settle();check(view.action_button.disabled,"unknown blueprint disabled")
	view.select_item("box");await settle();var coins:int=state.data.wallet.coins;await emit_action()
	check(state.data.wallet.coins==coins-C.BOX_COST,"box command charges original price only on button")
	check(not state.data.village.items.has("box") and not "box" in state.data.village.blueprints,"virtual service never becomes inventory or blueprint")
	state.data.village.items.bamboo=0;state.data.wallet.coins=0;state.persist();state.changed.emit();await settle()
	check(view.action_button.disabled,"box disabled when funds insufficient")
	view.select_item("chair");await settle();check(view.action_button.disabled,"learned blueprint with missing materials disabled")
	view.switch_group("seeds");await settle();check(view.selected=="pepper_seed" and view.action_button.disabled,"group restores selection and insufficient seed funds disabled")
	state.data.village.items["庭院修缮用的整捆长节竹材"]=999999;state.persist();state.changed.emit();await settle()
	view.switch_group("items");await settle();view.select_item("庭院修缮用的整捆长节竹材");await settle()
	check(view.cards.has(view.selected) and view.quantity(view.selected,true)=="×9999+" and view.quantity(view.selected)=="999999件","unknown long saved key retained and exact quantity available")
	await inspect_layout(Vector2i(360,800))
	var selected_before:String=view.selected
	var down:=InputEventScreenTouch.new();down.index=0;down.pressed=true;down.position=Vector2(80,300);view._input(down)
	var drag:=InputEventScreenDrag.new();drag.index=0;drag.position=Vector2(80,340);view._input(drag)
	view.cards.radish.pressed.emit();check(view.selected==selected_before,"drag gesture cannot select another card")
	view.clear_touch();view.cards.radish.pressed.emit();check(view.selected=="radish","tap selects without consuming")
	view.select_item("honey");view.cards.honey.grab_focus();await settle();api.close();await settle()
	check(root.gui_get_focus_owner()==api.order_button,"closing returns focus to basket launcher")
	api.show_page("篮子");view=api.root;await settle();check(view.selected=="honey","reopen restores valid selected item")
	state.data.village.items={};state.persist();state.changed.emit();await settle()
	check(view.entries.is_empty() and view.selected.is_empty() and view.action_button==null,"empty inventory has no fake cards or empty action row")
	view.switch_group("seeds");await settle();check(view.entries.size()==3,"zero seed counts still visible")
	view.switch_group("plans");await settle();check(view.entries.size()==13,"empty inventory retains plan/service group")
	check(measurements.size()==5,"all five geometry cases completed without early abort")
	var output:={"scope":"headless boundary fixtures only; C3 actual N6 pending","checks":checks,"failures":failures,"measurements":measurements}
	FileAccess.open("res://../回执/第1轮/篮子v2-布局与操作预检.json",FileAccess.WRITE).store_string(JSON.stringify(output,"  "))
	api.close();api.queue_free();host.queue_free();await settle()
	print("BASKET_V2 ","PASS" if failures.is_empty() else "FAIL"," ",checks," checks ",failures);quit(0 if failures.is_empty() else 1)
