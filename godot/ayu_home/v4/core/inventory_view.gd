extends Control
## C4 basket v2: local responsive containers, real state, existing commands only.
signal close_requested
signal page_requested(page:String)
signal action_requested(command:String,args:Dictionary)
const UI=preload("res://ayu_home/v4/pixel_ui.gd")
const C=preload("res://ayu_home/v4/core/config.gd")
const Icons=preload("res://ayu_home/v4/core/inventory_icon_draw.gd")
var state
var memory:Dictionary
var group:="items"
var selected:=""
var feedback:=""
var basket_font:FontVariation
var col:VBoxContainer
var outer:MarginContainer
var heading:Label
var wallet:Label
var summary:Label
var date:Label
var scroll:ScrollContainer
var grid:GridContainer
var details:PanelContainer
var back:Button
var action_button:Button
var cards:Dictionary={}
var controls:Dictionary={}
var entries:Array[String]=[]
var refreshing:=false
var refresh_queued:=false
var generation:=0
var signature:=""
var dragging:=false
var touch_index:=-1
var touch_origin:=Vector2.ZERO

class ItemIcon extends Control:
	var item:=""
	func _draw() -> void:
		Icons.paint(self,item,Rect2(Vector2.ZERO,size))

class BoundedCopy extends ScrollContainer:
	var copy:RichTextLabel
	var limit:=48.0
	func _init(text:String,maximum:float) -> void:
		limit=maximum;horizontal_scroll_mode=SCROLL_MODE_DISABLED
		copy=RichTextLabel.new();copy.bbcode_enabled=true;copy.fit_content=true;copy.scroll_active=false
		copy.size_flags_horizontal=SIZE_EXPAND_FILL;copy.text=text;add_child(copy)
		copy.minimum_size_changed.connect(fit_height);copy.resized.connect(fit_height)
		custom_minimum_size.y=24;focus_mode=FOCUS_ALL
	func fit_height() -> void:
		custom_minimum_size.y=clampf(copy.get_content_height(),24,limit)

class ItemCard extends Button:
	var stack:VBoxContainer
	var chosen:=false
	func _init() -> void:
		custom_minimum_size=Vector2(44,120);size_flags_horizontal=SIZE_EXPAND_FILL
		var margin:=MarginContainer.new();margin.mouse_filter=MOUSE_FILTER_IGNORE
		add_child(margin);margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		for side in ["left","right"]:margin.add_theme_constant_override("margin_"+side,4)
		for side in ["top","bottom"]:margin.add_theme_constant_override("margin_"+side,6)
		stack=VBoxContainer.new();stack.mouse_filter=MOUSE_FILTER_IGNORE;stack.add_theme_constant_override("separation",6);margin.add_child(stack)
		margin.minimum_size_changed.connect(func():custom_minimum_size.y=maxf(120,margin.get_combined_minimum_size().y))
	func _draw() -> void:
		if chosen:
			var rim:=StyleBoxFlat.new();rim.draw_center=false;rim.border_color=UI.NAME;rim.set_border_width_all(2)
			draw_style_box(rim,Rect2(Vector2.ZERO,size))
		if has_focus():
			var focus:=StyleBoxFlat.new();focus.draw_center=false;focus.border_color=UI.TEXT;focus.set_border_width_all(1)
			draw_style_box(focus,Rect2(Vector2(4,4),size-Vector2(8,8)))

func setup(s,preferences:Dictionary) -> void:
	state=s;memory=preferences
	for key in ["selection","scroll"]:
		if not memory.has(key):memory[key]={}
	group=str(memory.get("group","items"));theme=UI.theme();texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	# C4 specifies 24px line boxes; keep the 24px glyphs while removing this font's extra 8px leading locally.
	basket_font=FontVariation.new();basket_font.base_font=UI.FONT;basket_font.spacing_top=-4;basket_font.spacing_bottom=-4
	theme.default_font=basket_font
	var bg:=ColorRect.new();bg.color=UI.DEEP;bg.mouse_filter=MOUSE_FILTER_IGNORE;add_child(bg);bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	outer=MarginContainer.new();add_child(outer);outer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side in ["left","right"]:outer.add_theme_constant_override("margin_"+side,16)
	col=VBoxContainer.new();col.add_theme_constant_override("separation",6);outer.add_child(col)
	var header:=HBoxContainer.new();header.add_theme_constant_override("separation",8);col.add_child(header)
	heading=label("随身篮子",36);header.add_child(heading)
	wallet=label("");wallet.size_flags_horizontal=SIZE_EXPAND_FILL;wallet.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	wallet.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;wallet.add_theme_color_override("font_color",UI.NAME);header.add_child(wallet)
	back=make_button("返回",func():close_requested.emit(),"back");header.add_child(back)
	var nav:=GridContainer.new();nav.columns=3;nav.add_theme_constant_override("h_separation",8);col.add_child(nav)
	for title in ["日常","地图","篮子"]:
		var b:=make_button(title,func():page_requested.emit(title),"nav:"+title);nav.add_child(b)
		if title=="篮子":b.add_theme_color_override("font_color",UI.NAME)
	var groups:=GridContainer.new();groups.columns=3;groups.add_theme_constant_override("h_separation",8);col.add_child(groups)
	for pair in [["items","物品"],["seeds","换种子"],["plans","图纸"]]:
		var b:=make_button(pair[1],switch_group.bind(pair[0]),"group:"+pair[0]);groups.add_child(b)
	var row:=HBoxContainer.new();col.add_child(row)
	summary=label("");summary.size_flags_horizontal=SIZE_EXPAND_FILL;row.add_child(summary)
	date=label("");row.add_child(date)
	scroll=ScrollContainer.new();scroll.size_flags_vertical=SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus=true;scroll.scroll_deadzone=8;col.add_child(scroll)
	var inset:=MarginContainer.new();inset.size_flags_horizontal=SIZE_EXPAND_FILL;inset.add_theme_constant_override("margin_right",12);scroll.add_child(inset)
	grid=GridContainer.new();grid.columns=4;grid.size_flags_horizontal=SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",8);grid.add_theme_constant_override("v_separation",8);inset.add_child(grid)
	details=PanelContainer.new();var skin:=UI.card_box()
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:skin.set_content_margin(side,8)
	details.add_theme_stylebox_override("panel",skin);col.add_child(details)
	scroll.get_v_scroll_bar().value_changed.connect(func(value):
		if not refreshing:memory.scroll[group]=value
	)
	get_viewport().size_changed.connect(fit_viewport);fit_viewport()
	state.changed.connect(on_state_changed);refresh(false)

func fit_viewport() -> void:
	# Compensate the existing canvas stretch on this page only, retaining 24px text/48px touch targets.
	var factor:=get_viewport().get_final_transform().get_scale()
	if factor.x<=0 or factor.y<=0:return
	scale=Vector2.ONE/factor;size=(get_viewport().get_visible_rect().size*factor).round()
	var safe:=DisplayServer.get_display_safe_area();var win:=DisplayServer.window_get_size()
	var top:=28;var bottom:=26
	if win.x>0 and win.y>0 and safe.position.y>=0 and safe.size.y>0 and safe.size.y<=win.y:
		top=maxi(top,int(safe.position.y*size.y/win.y));bottom=maxi(bottom,int((win.y-safe.end.y)*size.y/win.y))
	outer.add_theme_constant_override("margin_top",top);outer.add_theme_constant_override("margin_bottom",bottom)
	grid.columns=3 if size.x-32-12<420 else 4
	heading.text="篮子" if size.x-32<420 else "随身篮子"
	wire_focus.call_deferred()

func label(text:String,point_size:=24) -> Label:
	var l:=UI.label(text,point_size);l.add_theme_font_override("font",basket_font);l.add_theme_constant_override("line_spacing",0);return l

func paragraph(text:String) -> Label:
	var l:=label(text);l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;return l

func make_button(text:String,callback:Callable,key:String,primary:=false) -> Button:
	var b:=UI.button(text,callback,primary);b.add_theme_font_override("font",basket_font);b.size_flags_horizontal=SIZE_EXPAND_FILL;b.custom_minimum_size=Vector2(44,48)
	# Keep the original skin with compact, local margins.
	if not primary:
		for mode in ["normal","hover","pressed","disabled","focus"]:
			var skin:=UI.secondary_box(mode=="pressed")
			skin.set_content_margin(SIDE_LEFT,8);skin.set_content_margin(SIDE_RIGHT,8);b.add_theme_stylebox_override(mode,skin)
	b.set_meta("basket_key",key);controls[key]=b;return b

func icon(id:String) -> Control:
	var n:Control
	if not Icons.definitions.has(id):
		if Icons.definitions.is_empty():Icons.definitions=JSON.parse_string(FileAccess.get_file_as_string(Icons.ICON_FILE))
	if Icons.definitions.has(id):n=ItemIcon.new();n.item=id
	else:n=UI.icon("bag",48)
	n.custom_minimum_size=Vector2(48,48);n.size_flags_horizontal=SIZE_SHRINK_CENTER;n.mouse_filter=MOUSE_FILTER_IGNORE;return n

func list_entries() -> Array[String]:
	var ids:Array[String]=[]
	match group:
		"items":
			for id in C.ITEMS:if state.count(id)>0:ids.append(id)
			for id in state.data.village.items:if not id in C.ITEMS and state.count(id)>0:ids.append(id)
		"seeds":
			for crop in C.CROPS:ids.append(C.CROPS[crop].seed)
		"plans":
			ids.append("box")
			for id in C.FURNITURE:ids.append(id)
	return ids

func full_name(id:String) -> String:
	if group=="plans":return "金币盲盒" if id=="box" else str(C.FURNITURE[id].name)+"图纸"
	return state.item_name(id)

func quantity(id:String,short:=false) -> String:
	if group=="plans":
		if id=="box":return "%d金币"%C.BOX_COST
		return "已学会" if id in state.data.village.blueprints else "未获得"
	var amount:int=state.count(id)
	return ("×9999+" if amount>9999 else "×"+str(amount)) if short else str(amount)+"件"

func save_view() -> void:
	if memory.is_empty() or not is_instance_valid(scroll):return
	memory.group=group;memory.selection[group]=selected
	if not refreshing:memory.scroll[group]=scroll.scroll_vertical
	var focused:=get_viewport().gui_get_focus_owner()
	if focused and is_ancestor_of(focused):memory.focus=str(focused.get_meta("basket_key",""))

func _exit_tree() -> void:save_view()

func switch_group(next:String) -> void:
	if next==group:return
	save_view();group=next;memory.group=group;feedback="";memory.focus="group:"+group;refresh(false)

func on_state_changed() -> void:
	var next:=JSON.stringify([state.data.village.items,state.data.wallet.coins,state.data.village.blueprints])
	if signature==next or refresh_queued:return
	refresh_queued=true;refresh.call_deferred()

func refresh(capture:=true) -> void:
	if not is_inside_tree():return
	if capture:save_view()
	refreshing=true;refresh_queued=false;generation+=1
	signature=JSON.stringify([state.data.village.items,state.data.wallet.coins,state.data.village.blueprints])
	for card in grid.get_children():grid.remove_child(card);card.queue_free()
	for key in controls.keys():if str(key).begins_with("entry:"):controls.erase(key)
	cards.clear();entries=list_entries();selected=str(memory.selection.get(group,""))
	if not selected in entries:selected=(str(C.FURNITURE.keys()[0]) if group=="plans" else entries[0]) if not entries.is_empty() else ""
	memory.selection[group]=selected
	wallet.text="金币 %d"%int(state.data.wallet.coins);wallet.tooltip_text=wallet.text
	var d:Dictionary=state.local_date();date.text="%d月%d日"%[d.month,d.day]
	summary.text="%d种物品"%entries.size() if group=="items" else ("%d种种子"%C.CROPS.size() if group=="seeds" else "%d张图纸"%C.FURNITURE.size())
	for name in ["items","seeds","plans"]:
		controls["group:"+name].add_theme_color_override("font_color",UI.NAME if name==group else UI.TEXT)
	for id in entries:
		var card:=ItemCard.new();card.set_meta("basket_key","entry:"+id);card.tooltip_text=full_name(id)+" · "+quantity(id)
		var n:=icon("parcel" if group=="plans" and id=="box" else id);card.stack.add_child(n)
		var name_label:=paragraph(full_name(id));name_label.max_lines_visible=2;name_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;name_label.mouse_filter=MOUSE_FILTER_IGNORE;card.stack.add_child(name_label)
		var badge:=label(quantity(id,true));badge.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;badge.mouse_filter=MOUSE_FILTER_IGNORE;card.stack.add_child(badge)
		card.pressed.connect(func():if not dragging:select_item(id))
		card.focus_entered.connect(func():
			# Pointer press may start a scroll; selection occurs on release instead.
			if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and touch_index<0:select_item(id)
			card.queue_redraw()
		)
		card.focus_exited.connect(card.queue_redraw);cards[id]=card;controls["entry:"+id]=card;grid.add_child(card)
	if entries.is_empty():
		var empty:=paragraph("篮子里暂时没有物品。");empty.size_flags_horizontal=SIZE_EXPAND_FILL;grid.add_child(empty)
	update_details();finish_refresh.call_deferred(generation)

func finish_refresh(version:int) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree() or version!=generation:return
	wire_focus();scroll.scroll_vertical=int(memory.scroll.get(group,0));refreshing=false
	var key:=str(memory.get("focus","entry:"+selected))
	var target:Control=controls.get(key,cards.get(selected,back))
	if target is BaseButton and target.disabled:target=cards.get(selected,back)
	target.grab_focus()

func select_item(id:String) -> void:
	if not id in entries:return
	if id==selected:return
	selected=id;memory.selection[group]=id;feedback="";update_details()

func bb(text:String) -> String:return text.replace("[","[lb]")

func box_info() -> String:
	return "%d%%出旧锄头，其余出图纸；连续%d次没工具，下一次保底。已有图纸换%d根竹材。"%[roundi(C.BOX_TOOL_CHANCE*100),C.BOX_TOOL_MISSES,C.DUPLICATE_BLUEPRINT_BAMBOO]

func update_details() -> void:
	for old in details.get_children():details.remove_child(old);old.queue_free()
	for key in ["action","detail_name","detail_copy"]:controls.erase(key)
	action_button=null
	for id in cards:cards[id].chosen=id==selected;cards[id].queue_redraw()
	var box:=VBoxContainer.new();box.add_theme_constant_override("separation",6);details.add_child(box)
	if selected.is_empty():box.add_child(paragraph("暂无选中物品"));wire_focus.call_deferred();return
	var head:=HBoxContainer.new();head.custom_minimum_size.y=48;head.add_theme_constant_override("separation",12);box.add_child(head)
	head.add_child(icon("parcel" if group=="plans" and selected=="box" else selected))
	var copy:=BoundedCopy.new("[color=#"+UI.NAME.to_html(false)+"]"+bb(full_name(selected))+"[/color]  "+bb(quantity(selected)),72)
	copy.size_flags_horizontal=SIZE_EXPAND_FILL;copy.set_meta("basket_key","detail_name");controls.detail_name=copy;head.add_child(copy)
	var description:="在订单或对应场所使用。";var command:="";var args:Dictionary={};var action_text:="";var enabled:=true
	if group=="seeds":
		for crop in C.CROPS:
			if C.CROPS[crop].seed!=selected:continue
			command="seed";args={"crop":crop};action_text="换一包"+state.item_name(selected)+" · %d金币"%C.SEED_COST
			enabled=int(state.data.wallet.coins)>=C.SEED_COST
			description=("金币不足。" if not enabled else "")+"在空的自留地种下。"
	elif group=="plans":
		if selected=="box":
			command="box";action_text="买盲盒 · %d金币"%C.BOX_COST;enabled=int(state.data.wallet.coins)>=C.BOX_COST
			description=("金币不足。" if not enabled else "")+box_info()
		else:
			var cfg:Dictionary=C.FURNITURE[selected];command="craft";args={"id":selected};action_text="制作"+cfg.name
			var learned:bool=selected in state.data.village.blueprints;enabled=learned and state.has_items(cfg.items)
			description="先从动物包或金币盲盒取得图纸。" if not learned else ("材料不足。" if not enabled else "制作后收进家具库。")
			var counts:Array[String]=[]
			for material in cfg.items:counts.append("%s %d/%d"%[state.item_name(material),state.count(material),int(cfg.items[material])])
			description+=" "+" · ".join(counts)
	elif selected=="parcel":
		command="parcel";action_text="打开动物包";enabled=state.count("parcel")>0;description=box_info()
	elif selected in ["bamboo","stone","tool"]:description="用于开地或家具制作。"
	elif selected.ends_with("_seed"):description="在空的自留地种下。"
	var info:=BoundedCopy.new(bb((feedback+"\n" if not feedback.is_empty() else "")+description),48);info.set_meta("basket_key","detail_copy");controls.detail_copy=info;box.add_child(info)
	if not command.is_empty():
		action_button=make_button(action_text,func():action_requested.emit(command,args),"action",true)
		action_button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;action_button.disabled=not enabled;box.add_child(action_button)
	wire_focus.call_deferred()

func show_feedback(message:String) -> void:
	feedback=message
	if not refresh_queued:update_details()

func wire_focus() -> void:
	if not is_inside_tree() or not is_instance_valid(grid):return
	var order:Array[Control]=[]
	for key in controls:
		var b:Control=controls[key]
		if not is_instance_valid(b):continue
		if b is BaseButton and b.disabled:continue
		if b is BoundedCopy and b.copy.get_content_height()<=b.size.y:continue
		order.append(b)
	for i in order.size():
		order[i].focus_next=order[i].get_path_to(order[(i+1)%order.size()]);order[i].focus_previous=order[i].get_path_to(order[(i-1+order.size())%order.size()])
	for i in entries.size():
		var b:Control=cards[entries[i]];var lower:Control=action_button if is_instance_valid(action_button) and not action_button.disabled else back
		b.focus_neighbor_left=b.get_path_to(cards[entries[i-1]] if i%grid.columns>0 else b)
		b.focus_neighbor_right=b.get_path_to(cards[entries[i+1]] if i%grid.columns<grid.columns-1 and i+1<entries.size() else b)
		b.focus_neighbor_top=b.get_path_to(cards[entries[i-grid.columns]] if i>=grid.columns else controls["group:"+group])
		b.focus_neighbor_bottom=b.get_path_to(cards[entries[i+grid.columns]] if i+grid.columns<entries.size() else lower)

func _input(event:InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and touch_index<0:touch_index=event.index;touch_origin=event.position;dragging=false
		elif not event.pressed and event.index==touch_index:clear_touch.call_deferred()
	elif event is InputEventScreenDrag and event.index==touch_index:
		if event.position.distance_to(touch_origin)>8:dragging=true

func clear_touch() -> void:touch_index=-1;dragging=false
