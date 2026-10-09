from pathlib import Path
R=Path(__file__).resolve().parents[1];p=R/'godot/ayu_home/v4/core/interface.gd';s=p.read_text()
s=s.replace('var farm_canvas','var farm_canvas\nvar preview_location:=""\nvar context_id:=""\nvar route_target:=""\nvar route_spot:=""\nvar overlay\nvar ticks:=0\nvar houses:Array=[]',1)
s=s.replace('if not state.blocked:state.act("visit")','''if not state.blocked:
		if state.data.village.household.is_empty():
			state.data.village.migration={"from":"ayu_home_v4","legacy_path":home.life.path,"at":state.now()}
			state.act("household",{"data":home.life.data})
		else:home.life.data=state.data.village.household.duplicate(true);home.life.base=home.life.data.duplicate(true)
		home.life.shared_state=state;home.journal=home.life.data;home.room_state=home.life.data.effects.get("rooms",{}).duplicate(true)
		state.act("visit")
	houses=JSON.parse_string(FileAccess.get_file_as_string("res://ayu_home/v4/assets/village/houses.json"))''',1)
s=s.replace('hud_button=UI.button("",func():show_page("田边"))','hud_button=UI.button("",func():show_page("日常"))').replace('crop_button=UI.button("",func():show_page("田边"))','crop_button=UI.button("",func():show_page("地图"))').replace('order_button=UI.button("门口牌子",func():show_page("牌子"))','order_button=UI.button("随身篮子",func():show_page("篮子"))')
s=s.replace('hud_button.text="动物回 %d"%ready\n\tcrop_button.text="菜熟 %d"%ripe','hud_button.text="日常 · 回 %d"%ready\n\tcrop_button.text="村庄地图"\n\tif is_instance_valid(overlay):overlay.queue_redraw()')
s=s.replace('func tick() -> void:\n\tupdate_hud()','''func tick() -> void:
	update_hud();ticks+=1
	if not state.blocked and home.player!=null:
		if ticks%30==0:checkpoint()
		follow_route()
		if is_instance_valid(overlay):overlay.queue_redraw()''')
s=s.replace('if root:root.queue_free();root=null','if root:remove_child(root);root.queue_free();root=null').replace('if root:root.queue_free()','if root:remove_child(root);root.queue_free()')
s=s.replace('bg.color=Color("374d3a")','bg.color=UI.DEEP').replace('"阿鱼家 · "+which,36','"裳泓村 · "+which,30').replace('UI.button("回家",close)','UI.button("返回",close)')
s=s.replace('var tabs:=HBoxContainer.new();col.add_child(tabs)\n\tfor title in ["田边","灶屋","牌子","村长","院子","篮子"]:', 'var tabs:=HBoxContainer.new();col.add_child(tabs)\n\tfor title in ["日常","地图","篮子"]:')
s=s.replace('match page:\n','''match page:
		"日常":daily()
		"地图":map_page()
		"选址预览":location_preview()
		"村民":neighbour()
		"生产":producer()
		"货郎":market()
		"生活册":diary()
		"风物":weather_page()
''',1)
s=s.replace('text("每处一个位，做完等你来收。试玩先用谷粉接谷香粥订单；豆花食谱需要后续豆类材料。")','text("每处一个位，做完等你来收。谷粉接谷香粥，家常菜拿去帮忙。")')
a=s.index('\ttitle("以后再添的家务")');b=s.index('\nfunc orders()',a);s=s[:a]+'''\tbutton("去村里的生产场所",show_page.bind("地图"))
'''+s[b:]
a=s.index('func mayor()');b=s.index('func my_yard()',a);s=s[:a]+'''func mayor() -> void:
	var v:Dictionary=state.data.village
	title("林伯 · 村长")
	if not v.resident:
		text("阿鱼说你常来帮忙。住下需要三件邻里订单，再备好一点起家物资。客房仍可以住。")
		text("已交 %d / %d 件订单\\n入驻：%d 金币、%s"%[v.order_total,C.RESIDENCY.orders,C.RESIDENCY.coins,state.describe(C.RESIDENCY.items)])
		text("还缺材料："+(state.missing_text(C.RESIDENCY.items) if not state.has_items(C.RESIDENCY.items) else "材料已齐")+"。楼卜自己种，竹材让动物带回，或帮阿禾收蜜。")
		button("提交物资，申请入驻",action.bind("reside"),true)
		button("去看邻里订单",show_page.bind("牌子"))
	elif v.location.is_empty():
		title("先看看，再决定住哪里")
		text("这几处空地都是村里预留的。阿鱼家的动物仍住阿鱼家，会继续替你带东西；自留地和库存沿用你做客时的积累。第一块地开好才搭起小屋。")
		for id in C.LOCATIONS:button("预览 · "+C.LOCATIONS[id],func():preview_location=id;show_page("选址预览"))
	else:
		text("你的家在"+C.LOCATIONS[v.location]+"。生活过的地方都会记着你；有空也来公所坐坐。")
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
''' +s[b:]
s=s.replace('25% 出旧锄头，75% 出一张随机图纸。已有图纸换 3 根竹材；没有现金购买。','25% 出旧锄头，其余出图纸；连续三次没工具，第四次保底。已有图纸换 3 根竹材。')
s=s.replace('button("去找村长",show_page.bind("村长"),true)','button("沿村路去找村长",func():travel("village","mayor"),true)')
s=s.replace('text("每只每趟 5 分钟带回 4 件。熟菜等你收，离线不腐烂。")','text("阿鱼家的四只动物每天替你跑腿，仍住在阿鱼家。每只每趟 5 分钟带回 4 件，连续五趟没工具，第六趟保底。熟菜等你收，离线最多一趟。")')
s+='''
func checkpoint() -> void:
	if not state.blocked and is_instance_valid(home.player):state.act("checkpoint",{"area":home.area,"position":[home.player.position.x,home.player.position.y]})
func entered() -> void:
	if state.blocked:return
	var cfg:Dictionary=home.world.cfg
	for d in cfg.doors:
		if d.target=="my_cabin" and float(state.data.village.land[0])<=0:d.label="先开第一块地，搭起小屋"
	if home.area=="village" and not state.data.village.location.is_empty():
		var xy:Array=C.LOCATION_POINTS[state.data.village.location]
		for h in cfg.hotspots:
			if h.id=="home_site":h.approach=xy;h.pos=[xy[0],xy[1]-30]
	for record in cfg.get("npcs",[cfg.npc] if cfg.has("npc") else []):
		if record.get("id","")=="market" and not state.isMarketDay():continue
		var actor=preload("res://ayu_home/v4/actor.gd").new();actor.preset=int(record.preset);home.world.actors.add_child(actor);actor.setup("visitor");actor.position=Vector2(record.pos[0],record.pos[1]);actor.action="idle";actor.set_process(false)
		var nameplate:=Label.new();nameplate.text=str(record.name);nameplate.add_theme_font_override("font",UI.FONT);nameplate.add_theme_font_size_override("font_size",16);nameplate.add_theme_color_override("font_shadow_color",Color("392f24"));nameplate.add_theme_constant_override("shadow_offset_x",1);nameplate.add_theme_constant_override("shadow_offset_y",1);nameplate.position=Vector2(-24,-108);actor.add_child(nameplate)
	overlay=preload("res://ayu_home/v4/core/world_life.gd").new();overlay.ui=self;home.world.add_child(overlay)
	checkpoint()
func interact(h:Dictionary) -> bool:
	var id:=str(h.id)
	if h.get("kind","")!="village":return false
	context_id=id
	match id:
		"map":show_page("地图")
		"mayor":show_page("村长")
		"mill","honey":show_page("村民")
		"pond","chicken","orchard":show_page("生产")
		"market":show_page("货郎")
		"yard":show_page("院子")
		"farm":show_page("田边")
		"diary":show_page("生活册")
		"home_site":
			if state.data.village.location.is_empty():notice="先找林伯申请，再比较四处空地。";show_page("日常")
			else:home.enter_room("my_yard",true,"village")
		"house_help":
			var result:Dictionary=state.act("house_help",{"id":h.get("house",home.area),"title":home.world.cfg.title,"text":h.get("copy","")});home.player.say(result.message);home.note=result.message
		_:
			home.player.say(str(h.get("copy","慢慢来，坐一会儿。")));home.note=str(h.get("copy",""))
	return true
func daily() -> void:
	var v:Dictionary=state.data.village
	title("这是你来村里的第 %d 个日子"%state.day_number())
	if v.order_total<3:
		text("阿鱼：先种菜、做点吃的。三件订单交好，我就介绍你去找林伯。动物趁你串门时往返一趟，收获不着急。")
	elif not v.resident:text("阿鱼：大家都认识你了。村公所就在院门往南的路上，林伯等你聊安家的事。")
	elif v.location.is_empty():text("今天可以慢慢选一处喜欢的位置。看完预览，再把家安下来。")
	else:text("你的小院在"+C.LOCATIONS[v.location]+"。昨天留下的收获都还在，今天想开地、做家具，还是串门，由你安排。")
	button("照料动物与自留地",show_page.bind("田边"),true)
	button("做饭、磨谷粉",show_page.bind("灶屋"))
	button("看看今日订单",show_page.bind("牌子"))
	button("去找村长林伯",func():travel("village","mayor"))
	if not v.location.is_empty():button("走回自己的地",func():travel("village","home_site"))
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
	var c:Dictionary=C.NEIGHBOURS[context_id];var v:Dictionary=state.data.village
	title(c.name)
	text(c.again if int(v.helped.get(context_id,0))>0 else c.first)
	text("帮忙次数：%d。今天想要 %s，酬谢 %d 金币和 %s。"%[int(v.helped.get(context_id,0)),state.describe(c.request),c.coins,state.describe(c.gift)])
	button("把东西交给"+c.name,action.bind("neighbour",{"id":context_id}),true)
	if context_id=="mill":button("借用石磨",show_page.bind("灶屋"))
	else:button("照料蜂蜜箱",show_page.bind("生产"))
	title("窗外的小事")
	text("雨雪天给鸟留一把谷子；晴阴天分享一个当季果子。帮完收到 25 金币和一根竹材。每天任选一回。")
	button("做今天的小事",action.bind("season_help",{"weather":home.weather,"season":home.Data.SEASONS[home.Data.season(home.month)]}))
	button("坐会儿再走",func():close();home.player.action="sit";home.note="坐一会儿，点地面起身。")
func market() -> void:
	title("村口货郎 · "+("今日赶场" if state.isMarketDay() else "今天歇场"))
	text("按公历逢单日赶场，每次轮换货物。歇场时，邻里食材柜仍收多余菜果。")
	if state.isMarketDay():
		for id in state.market_goods():button(C.ITEMS[id]+" · %d 金币"%state.market_goods()[id],action.bind("market_buy",{"id":id}))
	title("邻里食材柜 · 随时能放")
	for id in ["radish","pepper","grain","honey","fish","egg","fruit"]:
		if state.count(id)>0:button("放一份"+C.ITEMS[id]+" · 收 12 金币（有 %d）"%state.count(id),action.bind("sell",{"id":id}))
	button("看普通种子与家具图纸",show_page.bind("篮子"))
func diary() -> void:
	title("村子记得你来过")
	text("来访 %d 天 · 交过 %d 张订单 · 人情 %d 条"%[state.day_number(),state.data.village.order_total,state.data.renqing.size()])
	for m in state.data.village.memories.slice(-15):text(str(m.date)+" · "+str(m.place)+"\\n"+str(m.text))
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
	text("点下方地点会沿路步行。途中点地面可改道；屋内先走到门，再接着往村路上走。")
	for h in houses:button(h.title+" · "+h.subtitle,func():travel("village","visit_"+h.id))
	for item in [["池塘","pond"],["鸡圈","chicken"],["果园","orchard"],["村口货郎","market"],["自己的地","home_site"]]:button(item[0],func():travel("village",item[1]))
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
'''
p.write_text(s)
