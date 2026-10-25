extends CanvasLayer
const UI=preload("res://ayu_home/v4/pixel_ui.gd")
const C=preload("res://ayu_home/v4/core/config.gd")
const State=preload("res://ayu_home/v4/core/state.gd")
const Yard=preload("res://ayu_home/v4/core/yard.gd")
const Residents=preload("res://ayu_home/v4/core/residents.gd")
const InventoryView=preload("res://ayu_home/v4/core/inventory_view.gd")
var basket_memory:Dictionary={}
var state
var home
var opened:=false
var root:Control
var content:VBoxContainer
var status:Label
var heading:Label
var page:="田边"
var selected_crop:="radish"
var selected_furniture:=-1
var land_choice:=0
var timer:Timer
var counters:Array=[]
var hud_button:Button
var crop_button:Button
var order_button:Button
var notice:="先收动物带回的东西，再种三样菜。做客也能慢慢攒起自己的家。"
var yard
var farm_canvas
var preview_location:=""
var context_id:=""
var route_target:=""
var route_spot:=""
var overlay
var ticks:=0
var houses:Array=[]
var institution_room
var institution_game
var childhood_game
var street_actors:Array=[]
func setup(h:Node) -> void:
	home=h;layer=45;state=State.new()
	var override_path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--core-save="):override_path=arg.trim_prefix("--core-save=")
	state.open(home.profile,override_path)
	if not state.blocked:
		if state.data.village.household.is_empty():
			state.data.village.migration={"from":"ayu_home_v4","legacy_path":home.life.path,"at":state.now()}
			state.act("household",{"data":home.life.data})
		else:home.life.data=state.data.village.household.duplicate(true);home.life.base=home.life.data.duplicate(true)
		if not state.data.village.get("inventory_migrated",false):state.act("import_household_inventory",{"data":home.life.data})
		home.life.shared_state=state;home.life.sync_inventory();home.journal=home.life.data;home.room_state=home.life.data.effects.get("rooms",{}).duplicate(true)
		state.act("visit")
		if state.data.village.resident:
			notice="欢迎回家。成熟的菜和做好的东西都在等你，今天慢慢安排。"
		elif int(state.data.village.order_total)>=3:
			notice="已经帮过村里几回忙了，可以去找林伯，看看自己的院子。"
	houses=JSON.parse_string(FileAccess.get_file_as_string("res://ayu_home/v4/assets/village/houses.json"))
	state.changed.connect(update_hud)
	timer=Timer.new();timer.wait_time=1;timer.timeout.connect(tick);add_child(timer);timer.start()
	hud_button=UI.button("",func():show_page("日常"));hud_button.name="VillageLife";home.ui.add_child(hud_button)
	hud_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT);hud_button.offset_left=14;hud_button.offset_right=166;hud_button.offset_top=-136;hud_button.offset_bottom=-80
	crop_button=UI.button("",func():show_page("地图"));home.ui.add_child(crop_button)
	crop_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT);crop_button.offset_left=174;crop_button.offset_right=326;crop_button.offset_top=-136;crop_button.offset_bottom=-80
	order_button=UI.button("随身篮子",func():show_page("篮子"));home.ui.add_child(order_button)
	order_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT);order_button.offset_left=334;order_button.offset_right=514;order_button.offset_top=-136;order_button.offset_bottom=-80
	update_hud()
func update_hud() -> void:
	if state.blocked:hud_button.text="生活存档需要检查";return
	if home.life.shared_state!=null:home.life.sync_inventory()
	var ready:=0;var ripe:=0
	for pet in state.data.village.animals:if state.remaining(state.data.village.animals[pet].due)==0:ready+=1
	for crop in state.data.village.crops:if not crop.is_empty() and state.remaining(crop.due)==0:ripe+=1
	hud_button.text="日常";hud_button.tooltip_text="动物回 %d · 菜熟 %d"%[ready,ripe]
	crop_button.text="村庄地图"
	if is_instance_valid(overlay):overlay.queue_redraw()
func tick() -> void:
	update_hud();ticks+=1
	if not state.blocked and home.player!=null:
		if ticks%30==0:checkpoint()
		follow_route()
		if is_instance_valid(overlay):overlay.queue_redraw()
	if not opened:return
	for item in counters:
		if not is_instance_valid(item.node):continue
		var left:int=state.remaining(item.due)
		item.node.text=item.prefix+("好了 · 点收取" if left==0 else time_text(left))
	if is_instance_valid(yard):yard.queue_redraw()
	if is_instance_valid(farm_canvas):farm_canvas.refresh()
func time_text(seconds:int) -> String:return "%d:%02d"%[seconds/60,seconds%60]
func close() -> void:
	if is_instance_valid(institution_game):institution_game.cancel();return
	if root:remove_child(root);root.queue_free();root=null
	opened=false;home.ui.visible=true;home.cooldown=.8;yard=null;counters.clear()
	if page=="篮子" and is_instance_valid(order_button):order_button.grab_focus()
func _unhandled_input(e:InputEvent) -> void:
	if opened and e.is_action_pressed("ui_cancel"):close();get_viewport().set_input_as_handled()
func show_page(which:String) -> void:
	if root:remove_child(root);root.queue_free()
	opened=true;home.close_modal();home.ui.visible=false;page=which;counters.clear();yard=null;farm_canvas=null
	if which=="篮子" and not state.blocked:
		root=InventoryView.new();add_child(root);root.setup(state,basket_memory)
		root.close_requested.connect(close);root.page_requested.connect(show_page);root.action_requested.connect(inventory_action)
		return
	root=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.theme=UI.theme();add_child(root)
	var bg:=ColorRect.new();bg.color=UI.DEEP;bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(bg)
	var outer:=MarginContainer.new();outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(outer)
	for side in ["left","right"]:outer.add_theme_constant_override("margin_"+side,16)
	outer.add_theme_constant_override("margin_top",28);outer.add_theme_constant_override("margin_bottom",26)
	var safe:=DisplayServer.get_display_safe_area();var win:=DisplayServer.window_get_size()
	if win.x>0 and win.y>0 and safe.size.x<=win.x and safe.size.y<=win.y:
		outer.add_theme_constant_override("margin_top",maxi(28,int(safe.position.y*get_viewport().get_visible_rect().size.y/win.y)))
		outer.add_theme_constant_override("margin_bottom",maxi(26,int((win.y-safe.end.y)*get_viewport().get_visible_rect().size.y/win.y)))
	var col:=VBoxContainer.new();outer.add_child(col)
	var top:=HBoxContainer.new();col.add_child(top)
	heading=UI.label("裳泓村 · "+which,30);heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL;top.add_child(heading)
	var back:=UI.button("返回",close);top.add_child(back)
	if state.blocked:col.add_child(UI.paragraph(state.error));back.grab_focus();return
	col.add_child(UI.label("金币 %d · %s · %s"%[state.data.wallet.coins,state.date_key(),"赶场日" if state.isMarketDay() else "歇场日"]))
	var tabs:=GridContainer.new();tabs.columns=3;col.add_child(tabs)
	for title in ["日常","地图","篮子"]:
		var b:=UI.button(title,show_page.bind(title),title==page);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;tabs.add_child(b)
	status=UI.paragraph(notice,20);status.custom_minimum_size.y=56;status.add_theme_color_override("font_color",UI.NAME);col.add_child(status)
	var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;col.add_child(scroll)
	content=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content.add_theme_constant_override("separation",14);scroll.add_child(content)
	match page:
		"日常":daily()
		"地图":map_page()
		"选址预览":location_preview()
		"村民":neighbour()
		"生产":producer()
		"货郎":market()
		"生活册":diary()
		"风物":weather_page()
		"田边":farm()
		"灶屋":kitchen()
		"牌子":orders()
		"村长":mayor()
		"院子":my_yard()
		"开地":land_confirmation()
	back.grab_focus();tick()
func text(copy:String) -> void:content.add_child(UI.paragraph(copy))
func title(copy:String) -> void:content.add_child(UI.stamp(copy))
func button(copy:String,cb:Callable,primary:=false,parent:Node=null) -> Button:
	var b:=UI.button(copy,cb,primary);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	(parent if parent!=null else content).add_child(b);return b
func action(command:String,args:Dictionary={}) -> void:
	var result:Dictionary=state.act(command,args);notice=result.message
	if result.ok:home.play_sound("switch")
	show_page(page)
func countdown(node:Button,prefix:String,due:float) -> void:counters.append({"node":node,"prefix":prefix,"due":due})
func farm() -> void:
	title("院门口 · 动物和自留地")
	var seeds:=HBoxContainer.new();content.add_child(seeds)
	for crop in C.CROPS:
		button(C.CROPS[crop].name+" %d"%state.count(C.CROPS[crop].seed),func():selected_crop=crop;notice="选好了"+C.CROPS[crop].name+"，点空地种下";show_page(page),selected_crop==crop,seeds)
	farm_canvas=preload("res://ayu_home/v4/core/farm_view.gd").new();farm_canvas.state=state;content.add_child(farm_canvas)
	farm_canvas.collect_pet.connect(func(id):action("animal",{"id":id}))
	farm_canvas.plot_pressed.connect(func(i):
		if state.data.village.crops[i].is_empty():action("plant",{"plot":i,"crop":selected_crop})
		else:action("harvest",{"plot":i})
	)
	var waiting:=0
	for order in state.orders():if not order.done:waiting+=1
	button("门口牌子 · 还有 %d 件"%waiting,show_page.bind("牌子"),true)
	text("阿鱼家的四只动物每天替你跑腿，仍住在阿鱼家。每只每趟 5 分钟带回 4 件，连续五趟没工具，第六趟保底。熟菜等你收，离线最多一趟。")
	button("和喜多玩一会儿",func():close();home.pet_scene("xiduo"))
func kitchen() -> void:
	for station in ["mill","stove"]:
		title("石磨" if station=="mill" else "灶台")
		var job:Dictionary=state.data.village.stations[station]
		if job.is_empty():
			for recipe in C.RECIPES:
				var cfg:Dictionary=C.RECIPES[recipe]
				if cfg.station!=station:continue
				text(cfg.name+"："+state.describe(cfg.input)+" · "+time_text(cfg.seconds))
				button("开始做"+cfg.name,action.bind("produce",{"recipe":recipe}))
		else:
			var b:=button("",action.bind("collect",{"station":station}),true)
			countdown(b,C.RECIPES[job.recipe].name+" · ",job.due)
	text("每处一个位，做完等你来收。谷粉接谷香粥，家常菜拿去帮忙。")
	button("一起煮家常汤",func():close();home.games.open("soup",home.life,{"hour":home.hour,"month":home.month,"sound":home.sound_on}))
	button("去村里的生产场所",show_page.bind("地图"))

func orders() -> void:
	title("门口的小牌子 · "+state.date_key())
	for order in state.orders():
		text("%s · %s\n想要 %s，酬谢 %d 金币%s"%[order.who,order.title,state.describe(order.items),order.coins," · 记人情簿" if order.family else ""])
		var b:=button("今天已交" if order.done else "交给"+order.who,action.bind("order",{"id":order.id}),not order.done);b.disabled=order.done
	title("家人的人情簿")
	if state.data.renqing.is_empty():text("帮家人交了订单，这里就留下一行来往。")
	for entry in state.data.renqing.slice(-12):text(str(entry["with"])+" · "+str(entry.what))
	for event in state.data.calendar.events:text(str(event.get("date",""))+" · "+str(event.get("who","邻居"))+" · "+str(event.get("kind","办席")))
func mayor() -> void:
	var v:Dictionary=state.data.village
	title("林伯 · 村长")
	if not v.resident:
		text("阿鱼说你常来帮忙。住下需要三件邻里订单，再备好一点起家物资。客房仍可以住。")
		text("已交 %d / %d 件订单\n入驻：%d 金币、%s"%[v.order_total,C.RESIDENCY.orders,C.RESIDENCY.coins,state.describe(C.RESIDENCY.items)])
		text("还缺材料："+(state.missing_text(C.RESIDENCY.items) if not state.has_items(C.RESIDENCY.items) else "材料已齐")+"。楼卜自己种，竹材让动物带回，或在村委会整理事务卡。")
		button("提交物资，申请入驻",action.bind("reside"),true)
		button("去看邻里订单",show_page.bind("牌子"))
	elif v.location.is_empty():
		title("先看看，再决定住哪里")
		text("这几处空地都是村里预留的。阿鱼家的动物仍住阿鱼家，会继续替你带东西；自留地和库存沿用你做客时的积累。第一块地开好后就能摆放家具。")
		for id in C.LOCATIONS:button("预览 · "+C.LOCATIONS[id],func():preview_location=id;show_page("选址预览"))
	else:
		text("你的家在"+C.LOCATIONS[v.location]+"。生活过的地方都会记着你；有空也来村委会坐坐。")
		button("沿村路回自己的地",func():travel("village","home_site"))
	button("先回村里走走",close)
func location_preview() -> void:
	if preview_location.is_empty():show_page("村长");return
	title(C.LOCATIONS[preview_location]+" · 地块预览")
	var m=preload("res://ayu_home/v4/core/map_view.gd").new();m.state=state;m.houses=houses;m.chosen=preview_location;m.custom_minimum_size.y=350;content.add_child(m)
	text({"lake":"近水，出门可照料池塘，也适合钓鱼。","bamboo":"竹影在院边，留一片清静做手工。","hill":"稍高一些，能看村里的屋顶和暮色。","garden":"花果近在身旁，回家一路都是四季。"}[preview_location])
	text("确认后位置固定。第一块地仍是荒地，需要金币、石头、竹材和动物带回的工具。")
	button("确认在这里住下",func():page="村长";action("location",{"id":preview_location}),true)
	button("返回，再看别处",show_page.bind("村长"))
func my_yard() -> void:
	var v:Dictionary=state.data.village
	if v.location.is_empty():text("先向村长申请入驻，再选住处。这里会从荒地开始。 ");button("沿村路去找村长",func():travel("village","mayor"),true);return
	title(C.LOCATIONS[v.location]+" · 你的院子")
	text("点家具选中，再点空格挪动；也能按住家具拖动。下方选家具可摆入院子。")
	yard=Yard.new();yard.state=state;yard.selected=selected_furniture;content.add_child(yard)
	yard.furniture_selected.connect(func(id):selected_furniture=id;notice="选中家具，点空格挪动或在下面收起";show_page(page))
	yard.cell_pressed.connect(func(x,y):
		if x<0 or x>=4 or y<0 or y>=9:return
		if float(v.land[y/3])<=0:confirm_land(y/3)
		elif selected_furniture>=0:action("place",{"id":selected_furniture,"x":x,"y":y})
	)
	yard.dropped.connect(func(id,x,y):selected_furniture=id;action("place",{"id":id,"x":x,"y":y}))
	for i in C.LAND.size():
		var cost:Dictionary=C.LAND[i]
		if float(v.land[i])<=0:
			text("第 %d 块：%d 金币、%s"%[i+1,cost.coins,state.describe(cost.items)])
			button("开第 %d 块地"%[i+1],confirm_land.bind(i))
		else:text("第 %d 块 · %s"%[i+1,"已开好" if state.remaining(v.land[i])==0 else "正在开地…"])
	title("家具库")
	if v.furniture.is_empty():text("先在篮子里开图纸，备好材料做一件家具。")
	for f in v.furniture:
		button(C.FURNITURE[f.kind].name+" · "+("已摆" if f.x>=0 else "待摆"),func():selected_furniture=int(f.id);notice="选好家具，点上面开好的空格放下";show_page(page),int(f.id)==selected_furniture)
	if selected_furniture>=0:button("收起选中的家具",action.bind("store",{"id":selected_furniture}))
	button("去看图纸与材料",show_page.bind("篮子"))
func inventory_action(command:String,args:Dictionary) -> void:
	var result:Dictionary=state.act(command,args);notice=result.message
	if result.ok:home.play_sound("switch")
	if is_instance_valid(root) and root is InventoryView:root.show_feedback(result.message)

class FurnitureSample extends Control:
	var kind:="chair"
	func _draw() -> void:
		texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		preload("res://ayu_home/v4/core/furniture_draw.gd").paint(self,kind,Rect2(4,4,68,68))

func confirm_land(index:int) -> void:
	land_choice=index;notice="先看看要用的东西，够了再开这块地。";show_page("开地")
func land_confirmation() -> void:
	var cost:Dictionary=C.LAND[land_choice]
	title("第 %d 块荒地"%[land_choice+1])
	text("要用 %d 金币、%s。\n工具和材料由动物带回，金币来自订单。"%[cost.coins,state.describe(cost.items)])
	text("目前还缺："+state.missing_text(cost.items) if not state.has_items(cost.items) else "材料和工具已经齐了。")
	button("确认开这块地",func():page="院子";action("land",{"plot":land_choice}),true)
	button("先留着",show_page.bind("院子"))

func checkpoint() -> void:
	if not state.blocked and is_instance_valid(home.player):state.act("checkpoint",{"area":home.area,"position":[home.player.position.x,home.player.position.y]})
func entered() -> void:
	if state.blocked:return
	institution_room=null;street_actors.clear()
	var cfg:Dictionary=home.world.cfg
	if home.area=="village" and not state.data.village.location.is_empty():
		var xy:Array=C.location_points()[state.data.village.location]
		for h in cfg.hotspots:
			if h.id=="home_site":h.approach=xy;h.pos=[xy[0],xy[1]-30]
	for record in cfg.get("npcs",[cfg.npc] if cfg.has("npc") else []):
		if cfg.has("resident"):continue # 机构主人交给作息组件，只创建一次。
		if record.get("id","")=="market" and not state.isMarketDay():continue
		if record.get("character_id","") in ["xiaotao","kaikai","linbo"] and not (home.hour>=5 and home.hour<7):continue
		var actor=preload("res://ayu_home/v4/actor.gd").new();actor.preset=int(record.get("preset",0));actor.look_override=Residents.look(str(record.get("character_id",record.get("id",""))));home.world.actors.add_child(actor);actor.setup("visitor");actor.position=Vector2(record.pos[0],record.pos[1]);actor.action="idle";actor.draw_hand_overlays=false;street_actors.append({"actor":actor,"origin":actor.position,"next":8.0,"leg":0,"id":str(record.get("character_id",record.get("id","")))})
		var nameplate:=Label.new();nameplate.text=str(record.name);nameplate.add_theme_font_override("font",UI.FONT);nameplate.add_theme_font_size_override("font_size",16);nameplate.add_theme_color_override("font_shadow_color",Color("392f24"));nameplate.add_theme_constant_override("shadow_offset_x",1);nameplate.add_theme_constant_override("shadow_offset_y",1);nameplate.position=Vector2(-24,-108);actor.add_child(nameplate)
	if cfg.has("resident"):
		institution_room=preload("res://ayu_home/v4/core/institution_room.gd").new();home.world.add_child(institution_room);home.world.move_child(institution_room,home.world.actors.get_index());institution_room.setup(self)
	overlay=preload("res://ayu_home/v4/core/world_life.gd").new();overlay.ui=self;home.world.add_child(overlay)
	checkpoint()
func open_institution_game(id:String) -> void:
	if is_instance_valid(institution_game):return
	home.close_modal();opened=true;home.ui.visible=false
	institution_game=preload("res://ayu_home/v4/core/institution_game.gd").new();add_child(institution_game);institution_game.setup(self,id)
func talk_resident(id:String) -> bool:
	return is_instance_valid(institution_room) and institution_room.talk(id)
func resident_card(id:String) -> bool:
	if not id in ["xiaotao","kaikai","linbo","fang"]:return false
	var name:String={"xiaotao":"小涛","kaikai":"凯凯","linbo":"林伯","fang":"方婆婆"}[id]
	var col:VBoxContainer=home.modal_shell(name+"的小卡片")
	if id=="fang":
		col.add_child(UI.label("方婆婆 · 活动中心值日",26));col.add_child(UI.paragraph("早上洗菜摆桌，中午招呼大家拌菜，晚上收好共用品坐下翻故事册。这里第一天就能来。"));return true
	if id=="linbo":
		col.add_child(UI.label("林伯 · 村委会",26));col.add_child(UI.paragraph("早上核对住户名册，中午办理村务，傍晚到议事桌听大家的意见。"));return true
	if id=="kaikai":
		col.add_child(UI.label("凯凯 · 蜂蜜小院",26));col.add_child(UI.paragraph("清早洗净蜂具，中午摇蜜装瓶，傍晚在窗下留一杯蜜茶。"));return true
	col.add_child(UI.label("小涛 · 小涛磨坊",26));col.add_child(UI.paragraph("早上簸谷，中午推磨，傍晚在茶席歇脚。五点到七点在村路上转一圈，其余时间能在磨坊找到他。"))
	return true
func interact(h:Dictionary) -> bool:
	if h.get("kind","")=="loach_memory":open_childhood();childhood_game.intro("loach");return true
	if h.get("kind","")=="closed_house":home.play_sound("knock");home.player.say(str(h.copy));return true
	if h.get("kind","")=="childhood":open_childhood();return true
	if is_instance_valid(institution_room) and institution_room.handle(h):return true
	var id:=str(h.id)
	if h.get("kind","")=="door_chore":
		var result:Dictionary=state.act("door_chore",{"id":h.house})
		var message:String="今日不便拜访，下次再来。\n"+str(result.message)
		home.player.face="up";home.player.say(message);home.note=message
		if is_instance_valid(overlay):overlay.queue_redraw()
		return true
	if h.get("kind","")=="community_growth":
		var col:VBoxContainer=home.modal_shell("一起张罗活动中心")
		var stage:=int(state.data.village.community_stage)
		col.add_child(UI.paragraph("已经添置 %d / 3 处，留下的物件会一直在这里。"%stage))
		if stage<C.COMMUNITY_STAGES.size():
			var next:Dictionary=C.COMMUNITY_STAGES[stage]
			col.add_child(UI.paragraph(str(next.name)+" · 需要 "+state.describe(next.items)))
			col.add_child(UI.button("交材料并摆好",func():var result:Dictionary=state.act("community_grow");home.close_modal();home.player.say(result.message);institution_room.queue_redraw(),true))
		return true
	if h.get("kind","")=="house_task":
		var result:Dictionary=state.act("house_help",{"id":h.house,"title":home.world.cfg.title,"text":h.copy,"repeat_text":h.repeat_copy,"label":h.label})
		home.player.say(result.message);home.note=result.message
		if is_instance_valid(overlay):overlay.queue_redraw()
		return true
	if h.get("kind","")=="house_display":
		var result:Dictionary=state.act("house_display",{"id":h.house})
		home.player.say(str(h.copy) if result.ok else str(result.message))
		if is_instance_valid(overlay):overlay.queue_redraw()
		return true
	if h.get("kind","")!="village":return false
	context_id=id
	match id:
		"map":show_page("地图")
		"mayor":show_page("村长")
		"mill":home.dialogue("小涛",C.NEIGHBOURS.mill.first,"xiaotao",func():show_page("村民"))
		"honey":home.dialogue("凯凯",C.NEIGHBOURS.honey.first,"kaikai",func():show_page("村民"))
		"pond","chicken","orchard":show_page("生产")
		"market":show_page("货郎")
		"yard":show_page("院子")
		"farm":show_page("田边")
		"diary":show_page("生活册")
		"home_site":
			if state.data.village.location.is_empty():notice="先找林伯申请，再比较四处空地。";show_page("日常")
			else:home.enter_room("my_yard",true,"village")
		"house_help":
			var result:Dictionary=state.act("house_help",{"id":h.get("house",home.area),"title":home.world.cfg.title,"text":h.get("copy",""),"repeat_text":h.get("repeat_copy",""),"label":h.get("label","")});home.player.say(result.message);home.note=result.message
		_:
			home.player.say(str(h.get("copy","慢慢来，坐一会儿。")));home.note=str(h.get("copy",""))
	return true
func daily() -> void:
	var v:Dictionary=state.data.village
	title("这是你来村里的第 %d 个日子"%state.day_number())
	if v.order_total<3:
		text("阿鱼：先种菜、做点吃的。三件订单交好，我就介绍你去找林伯。动物趁你串门时往返一趟，收获不着急。")
	elif not v.resident:text("阿鱼：大家都认识你了。村委会就在院门往南的路上，林伯等你聊安家的事。")
	elif v.location.is_empty():text("今天可以慢慢选一处喜欢的位置。看完预览，再把家安下来。")
	else:text("你的小院在"+C.LOCATIONS[v.location]+"。昨天留下的收获都还在，今天想开地、做家具，还是串门，由你安排。")
	button("照料动物与自留地",show_page.bind("田边"),true)
	button("做饭、磨谷粉",show_page.bind("灶屋"))
	button("看看今日订单",show_page.bind("牌子"))
	button("去找村长林伯",func():travel("village","mayor"))
	if not v.location.is_empty():button("走回自己的地",func():travel("village","home_site"))
	title("前七天，慢慢来")
	text(C.FIRST_WEEK[mini(6,maxi(0,state.day_number()-1))])
	for who in C.FRIEND_UNLOCKS:
		var reward:Dictionary=C.FRIEND_UNLOCKS[who]
		text(who+" · 人情 %d / %d"%[state.friendship(who),int(reward.threshold)])
		if v.friend_unlocks.has(who):button(str(reward.label)+" · 已学会，去制作",show_page.bind("篮子"))
		else:button("学习"+str(reward.label),action.bind("friend_claim",{"who":who}))
	button("去活动中心添置共用物件",func():travel("my_cabin"))
	title("十分钟之外，随便走走")
	button("沿村路拜访邻居",show_page.bind("地图"))
	button("去溪边钓鱼",func():travel("bridge","fishing"))
	button("回阿鱼家玩拼图",func():travel("study","puzzle"))
	button("看看四季风物",show_page.bind("风物"))
	button("翻生活册",show_page.bind("生活册"))
func producer() -> void:
	var id:=context_id
	if not C.PRODUCERS.has(id):id="honey"
	var c:Dictionary=C.PRODUCERS[id];var job:Dictionary=state.data.village.producers[id]
	title(c.name)
	text("照料需要："+(state.describe(c.input) if not c.input.is_empty() else "清理、添水，不消耗材料")+"。收获 "+str(c.yield)+" 份"+C.ITEMS[c.output]+"。")
	if job.is_empty():button("照料"+c.name,action.bind("producer_start",{"id":id}),true)
	else:
		var b:=button("",action.bind("producer_collect",{"id":id}),true);countdown(b,c.name+" · ",job.due)
	text("离开也会继续，完成后停着等你。果树会换季结果，蜂箱在冬天用保温箱照料。")
	if id=="pond":button("去溪边钓一会儿",func():travel("bridge","fishing"))
	button("多余收获放食材柜",show_page.bind("货郎"))
func neighbour() -> void:
	var c:Dictionary=C.NEIGHBOURS[context_id].duplicate(true);c.request=state.neighbour_request(context_id);var v:Dictionary=state.data.village
	title(c.name)
	text(c.again if int(v.helped.get(context_id,0))>0 else c.first)
	text("帮忙次数：%d。今天想要 %s，这份来往记在人情簿里。"%[int(v.helped.get(context_id,0)),state.describe(c.request)])
	button("把东西交给"+c.name,action.bind("neighbour",{"id":context_id}),true)
	if context_id=="mill":button("借用石磨",show_page.bind("灶屋"))
	else:button("照料蜂蜜箱",show_page.bind("生产"))
	title("窗外的小事")
	text("雨雪天给鸟留一把谷子；晴阴天分享一个当季果子。邻居记着这份人情。每天任选一回。")
	button("做今天的小事",action.bind("season_help",{"weather":home.weather,"season":home.Data.SEASONS[home.Data.season(home.month)]}))
	button("坐会儿再走",func():close();home.player.action="sit";home.note="坐一会儿，点地面起身。")
func market() -> void:
	title("村口货郎 · "+("今日赶场" if state.isMarketDay() else "今天歇场"))
	var introduction:=HBoxContainer.new();introduction.add_theme_constant_override("separation",14);content.add_child(introduction)
	var portrait:=TextureRect.new();portrait.name="MarketPortrait"
	portrait.texture=preload("res://ayu_home/v2/assets.gd").texture("res://ayu_home/v4/assets/talk-faces/market.png")
	portrait.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;portrait.custom_minimum_size=Vector2(112,129)
	portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE;introduction.add_child(portrait)
	var greeting:=UI.paragraph("按公历逢单日赶场，每次轮换货物。歇场时，邻里食材柜仍收多余菜果。")
	greeting.size_flags_horizontal=Control.SIZE_EXPAND_FILL;introduction.add_child(greeting)
	if state.isMarketDay():
		for id in state.market_goods():button(C.ITEMS[id]+" · %d 金币"%state.market_goods()[id],action.bind("market_buy",{"id":id}))
	title("邻里食材柜 · 随时能放")
	for id in ["radish","pepper","grain","honey","fish","egg","fruit"]:
		if state.count(id)>0:button("放一份"+C.ITEMS[id]+" · 收 12 金币（有 %d）"%state.count(id),action.bind("sell",{"id":id}))
	button("看普通种子与家具图纸",show_page.bind("篮子"))
func diary() -> void:
	title("村子记得你来过")
	text("来访 %d 天 · 交过 %d 张订单 · 人情 %d 条"%[state.day_number(),state.data.village.order_total,state.data.renqing.size()])
	for m in state.data.village.memories.slice(-15):text(str(m.date)+" · "+str(m.place)+"\n"+str(m.text))
	for n in C.NEIGHBOURS:
		var c:Dictionary=C.NEIGHBOURS[n];text(c.name+"记着你帮过 %d 回"%int(state.data.village.helped.get(n,0)))
	text("下次回来，成熟的菜、做好的东西和家具会原样等你。没有缺席惩罚。")
	button("阿鱼家的生活册与相册",func():close();home.life_book())
func weather_page() -> void:
	title("同一处地方，慢慢看四季")
	text("这里只换眼前的风物，不改变真实生产等待。返回后可继续散步；选现实季节恢复当地日期。")
	for pair in [["春 · 新芽与花",3],["夏 · 现有本色",7],["秋 · 黄橙与果",10],["冬 · 雪与常绿",1]]:
		button(pair[0],func():home.set_test_clock(home.hour,int(pair[1]),home.weather);close())
	for pair in [["晴","clear"],["阴","cloud"],["雨","rain"],["雪","snow"]]:button(pair[0],func():home.set_test_clock(home.hour,home.month,pair[1]);close())
	button("恢复现实季节与天气",func():home.test_month=0;home.test_weather="";home.test_hour=-1;home.read_clock();close())
func map_page() -> void:
	title("村路把各家连在一起")
	var m=preload("res://ayu_home/v4/core/map_view.gd").new();m.state=state;m.houses=houses;m.current=home.player.position if home.area=="village" else Vector2.ZERO;content.add_child(m)
	m.house_selected.connect(func(id:String):travel("village","visit_"+id))
	text("点图上的房屋或下方地点，就会沿路步行。途中点地面可改道；屋内先走到门，再接着往村路上走。")
	for h in houses:button(h.title+" · "+h.subtitle,func():travel("village","visit_"+h.id))
	for item in [["凯凯的蜂箱","honey"],["小涛的小石磨","mill"],["池塘","pond"],["鸡圈","chicken"],["果园","orchard"],["村口货郎","market"],["自己的地","home_site"]]:button(item[0],func():travel("village",item[1]))
	button("阿鱼家楼层图",func():close();home.navigation("一楼"))
func travel(room:String,spot:="") -> void:
	close();route_target=room;route_spot=spot;home.note="沿路慢慢走。点地面或方向键可停下。";follow_route()
func follow_route() -> void:
	if route_target.is_empty() or home.busy() or not home.pending.is_empty() or not home.player.route.is_empty():return
	if home.area==route_target:
		var wanted:=route_spot;route_target="";route_spot=""
		if not wanted.is_empty():home.go(wanted)
		return
	var hop:String=home.room_hop(home.area,route_target)
	for d in home.world.cfg.doors:
		if d.target==hop:home.go(d.id);return
	home.note="这段路暂时没连上，请从门口返回。";route_target=""

func open_childhood() -> void:
	if is_instance_valid(childhood_game):return
	home.close_modal();close();opened=true;home.ui.visible=false
	childhood_game=preload("res://ayu_home/v4/core/childhood_game.gd").new();add_child(childhood_game);childhood_game.setup(self)
