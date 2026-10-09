extends CanvasLayer
## Gesture-driven, replayable household games. No reward/currency or accelerated growth.
signal closed
signal completed(kind:String,result:Dictionary)
const Art=preload("res://ayu_home/v4/redraw_art.gd")
const UI=preload("res://ayu_home/v4/pixel_ui.gd")
const State=preload("res://ayu_home/v4/life_state.gd")
const TITLES={"garden":"六畦慢慢长大的日子","flower_garden":"把一朵花种进日常","tree":"种一棵陪你长大的树","fruit":"果园 · 摘下当季的甜","tea":"烧水，慢慢沏一壶茶","soup":"一锅家常汤","laundry":"阳光里的衣服","wood":"把木头磨成小鸟","fishing":"溪边 · 等一尾鱼","net":"浅水里的小鱼","flowers":"把花带回家","pairs":"花纹翻翻乐","stars":"秋千上 · 今晚的天空"}
var root:Control
var canvas:Control
var status:Label
var footer:HBoxContainer
var life
var kind:=""
var context:Dictionary={}
var elapsed:=0.0
var stage:=0
var progress:=0.0
var holding:=false
var pointer:=Vector2.ZERO
var previous:=Vector2.ZERO
var drag_id:=-1
var items:Array=[]
var placed:Array=[]
var finished:=false
var result:Dictionary={}
var tool:="till"
var selected_crop:=""
var selected_plot:=-1
var water_level:=0.0
var steep:=0.0
var tension:=.35
var bite_at:=0.0
var reel:=0.0
var fish_name:=""
var net_fish:Array=[]
var pairs:Array=[]
var flipped:Array=[]
var matched:Array=[]
var turn_back:=-1.0
var stars:Array=[]
var found_stars:=0
var meteor_at:=10.0
var meteor_until:=0.0
# Claude 10/5 玩法加深（只改玩法不改画）：摘果接篮、捞鱼要慢、翻牌先记后翻再加一局、认星星要自己点亮
var fruits:Array=[]
var basket_x:=230.0
var dragging_basket:=false
var caught:=0
var net_speed:=0.0
var net_last:=Vector2.ZERO
var pair_round:=1
var peek_until:=0.0
var streak:=0
var hint_until:=0.0
var wished_meteor:=false
var constellation:=0
var clouds:Array=[]
var last_scrub:=-1.0
var scrub_time:=0.0
var wish_input:LineEdit
var sound:AudioStreamPlayer
var note_cache:Dictionary={}
var last_pointer_frame:=-1
var prop_sheet:Texture2D
var scene_sheet:Texture2D
const Sfx=preload("res://ayu_home/v4/sfx.gd")
var fx:AudioStreamPlayer
func _ready() -> void:layer=42;sound=AudioStreamPlayer.new();add_child(sound);fx=AudioStreamPlayer.new();add_child(fx);set_process(false)
func open(which:String,state,info:Dictionary={}) -> void:
	if not await preload("res://ayu_home/v4/core/download_gate.gd").ensure(self,"game:"+which):return
	close(false);prop_sheet=preload("res://ayu_home/v2/assets.gd").texture("res://ayu_home/v4/assets/life-props.png");scene_sheet=preload("res://ayu_home/v2/assets.gd").texture("res://ayu_home/v4/assets/life-scenes.png");life=state;context=info;kind=which;elapsed=0;stage=0;progress=0;holding=false;drag_id=-1;placed=[];finished=false;result={};water_level=0;steep=0;reel=0;tension=.35;flipped=[];matched=[];found_stars=0;wish_input=null;scrub_time=0.0;last_scrub=-1.0;meteor_at=10.0;meteor_until=0.0;hint_until=0.0;wished_meteor=false;peek_until=0.0 # 每次打开都从头算，不带上一次的流星和提示
	root=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.theme=UI.theme(true);add_child(root)
	var bg:=ColorRect.new();bg.color=Color(.18,.13,.09,.92);bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(bg)
	var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right"]:margin.add_theme_constant_override("margin_"+side,18)
	for side in ["top","bottom"]:margin.add_theme_constant_override("margin_"+side,18)
	root.add_child(margin);var workbench:=PanelContainer.new();workbench.size_flags_vertical=Control.SIZE_SHRINK_CENTER;workbench.add_theme_stylebox_override("panel",UI.paper("wood"));margin.add_child(workbench);var column:=VBoxContainer.new();column.add_theme_constant_override("separation",10);workbench.add_child(column)
	var panel:=PanelContainer.new();column.add_child(panel);var heading:=HBoxContainer.new();panel.add_child(heading)
	var heading_copy:String=TITLES.get(kind,"家的小事")
	if kind=="stars":
		var is_night:bool=float(context.get("hour",20))>=18 or float(context.get("hour",20))<6
		heading_copy=("秋千上" if str(context.get("area","grove"))=="grove" else "躺椅上")+" · "+("今晚的天空" if is_night else "白天的云")
	var title:=UI.label(heading_copy,23);title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;heading.add_child(title)
	var exit_button:=UI.button("收起",close);heading.add_child(exit_button);exit_button.grab_focus()
	status=UI.label("",19);status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;status.custom_minimum_size.y=54;column.add_child(status)
	canvas=Control.new();canvas.custom_minimum_size.y=(get_viewport().get_visible_rect().size.x-72)*570.0/460.0;canvas.size_flags_vertical=Control.SIZE_SHRINK_CENTER;canvas.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;canvas.draw.connect(draw_game);canvas.gui_input.connect(input_game);column.add_child(canvas)
	footer=HBoxContainer.new();column.add_child(footer)
	var month:int=int(context.get("month",10));var season:=State.season(month)
	match kind:
		"garden","flower_garden","tree":
			life.pack_seeds(month);tool="till";selected_crop=life.available(month,"tree" if kind=="tree" else ("flower" if kind=="flower_garden" else "vegetable"))[0]
			for entry in [["翻土","till"],["播种","seed"],["浇水","water"],["收成","harvest"]]:button(entry[0],func():tool=entry[1];update_status())
			button("换种子",cycle_seed);update_status()
		"fruit":
			status.text="点一颗熟透的果子，它会掉下来；左右拖篮子把它接住。青的还没熟，留在树上。"
			items=[Vector2(132,201),Vector2(288,173),Vector2(350,287)];fruits=[];caught=0;basket_x=230
			for i in 9:
				# 九颗分开挂在树冠上，三颗青的散在不同的地方
				var at:=Vector2(112+(i%3)*118+[0,14,-10,8,-14,10,-6,12,-8][i],138+int(i/3)*74+[6,-8,10,-6,4,-10,8,-4,6][i])
				fruits.append({"pos":at,"home":at,"ripe":not i in [1,5,6],"state":"hang","vel":Vector2.ZERO,"wiggle":0.0})
			button("送一份给家人",gift_fruit);button("自己尝一口",eat_fruit)
		"tea":status.text="第一步 · 按住水壶烧水，听水滚起来。";button("按住水壶",noop_hold).button_down.connect(func():holding=true;sfx("boil" if stage==0 else "pour",.5));footer.get_child(0).button_up.connect(func():pointer_up(pointer);holding=false)
		"soup":status.text="把三样蔬菜拖进锅里，再绕着锅慢慢搅拌。";items=[Vector2(90,115),Vector2(225,110),Vector2(367,120)];button("看看菜篮",func():status.text="妈妈备好了三样菜；你收的蔬菜也会变成饭桌的一道菜。")
		"laundry":status.text="把三件衣服拖进滚筒，关门后按住开关。";items=[Vector2(70,135),Vector2(213,104),Vector2(371,132)]
		"wood":status.text="按住木块来回磨，沿小鸟轮廓慢慢划。";button("换个角度",func():stage=(stage+1)%3;tone(2))
		"fishing":status.text="从岸边往水面划一下，甩出鱼线。";bite_at=5.5+float(absi(life.date_key().hash())%4);fish_name=[["桃花鱼","青鳉"],["溪鲤","小鲫鱼"],["金鳞鱼","麦穗鱼"],["银鳞鱼","冬溪鲫"]][season][absi(str(life.now()).hash())%2]
		"net":
			status.text="拖动小网兜，轻轻靠近三条小鱼。";net_fish=[];pointer=Vector2(230,470) # 网兜一开始就在水里，不画到画布外
			status.text="把网兜慢慢移到小鱼底下，停一停它们才会游进来；动得太快会把鱼吓跑。"
			net_last=pointer;net_speed=0
			for i in 5:net_fish.append({"pos":Vector2(75+i*74,190+(i%2)*140),"caught":false,"phase":i*1.7,"under":0.0,"flee":Vector2.ZERO,"size":[.7,.9,.8,1.0,.75][i]})
		"flowers":
			status.text="把三枝花拖进花瓶，自由摆出高低。最后留在家里。";items=[]
			for id in life.data.basket:
				if State.CROPS.has(id) and State.CROPS[id].type=="flower":
					if int(life.data.basket[id])>0 and items.size()<3:items.append({"crop":id,"pos":Vector2(80+items.size()*142,135)})
			if items.size()<3:
				for id in life.data.basket:
					if State.CROPS.has(id) and State.CROPS[id].type=="flower":
						for i in mini(maxi(0,int(life.data.basket[id])-1),3-items.size()):items.append({"crop":id,"pos":Vector2(80+items.size()*142,135)})
			if items.size()<3:status.text="花还不够三枝。老屋旁可以摘花，花畦的花也可以带回来。"
		"pairs":
			pair_round=1;start_pairs()
		"stars":
			var night:bool=float(context.get("hour",20))>=18 or float(context.get("hour",20))<6
			status.text="沿着微亮的星认出今晚的星座。流星经过时点一下，许个愿。" if night else "白天先看云。找到三朵像小动物的云，夜里再来认星座。"
			stars=[[Vector2(114,135),Vector2(204,116),Vector2(257,162),Vector2(333,248),Vector2(168,239),Vector2(114,135)],[Vector2(92,193),Vector2(217,177),Vector2(327,149),Vector2(217,177),Vector2(187,82),Vector2(258,312)],[Vector2(111,128),Vector2(270,137),Vector2(285,280),Vector2(135,266),Vector2(111,128),Vector2(67,76)],[Vector2(153,117),Vector2(278,103),Vector2(260,191),Vector2(238,208),Vector2(220,226),Vector2(315,299)]][season]
			constellation=0;clouds=[]
			if night:status.text="一颗颗点亮今晚的星座：轻轻闪着的那颗就是下一颗。流星经过时点一下，许个愿。"
			else:
				status.text="天上的云在慢慢变。点一点你觉得像小动物的云，找三朵。"
				for c in [[Vector2(95,62),"像一只伸懒腰的猫"],[Vector2(392,150),"像一条小船"],[Vector2(105,228),"像一只兔子竖着耳朵"],[Vector2(190,348),"像喜多趴着"],[Vector2(372,262),"像一只胖胖的小鸟"]]:clouds.append({"pos":c[0],"name":c[1],"found":false})
			button("提示一下",star_hint)
	set_process(true)
func noop_hold() -> void:pass
func button(text:String,call:Callable) -> Button:
	var b:=UI.button(text,call);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;footer.add_child(b);return b
func close(emit:=true) -> void:
	if root:remove_child(root);root.queue_free();root=null;canvas=null
	if sound:sound.stop();sound.stream=null
	if fx:fx.stop()
	holding=false;set_process(false)
	if emit:closed.emit()
func finish(message:String,payload:Dictionary={}) -> void:
	status.text=message
	if finished:return
	finished=true;result=payload;completed.emit(kind,result);tone(4)
func scale_factor() -> float:return minf(canvas.size.x/460.0,canvas.size.y/570.0)
func offset() -> Vector2:return (canvas.size-Vector2(460,570)*scale_factor())*.5
func input_game(e:InputEvent) -> void:
	var pressed:=false;var released:=false;var moved:=false;var p:=pointer
	if e is InputEventScreenTouch:p=(e.position-offset())/scale_factor();pressed=e.pressed;released=not e.pressed
	elif e is InputEventScreenDrag:p=(e.position-offset())/scale_factor();moved=true
	elif e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_LEFT:p=(e.position-offset())/scale_factor();pressed=e.pressed;released=not e.pressed
	elif e is InputEventMouseMotion and e.button_mask&MOUSE_BUTTON_MASK_LEFT:p=(e.position-offset())/scale_factor();moved=true
	else:return
	if pressed and Engine.get_process_frames()==last_pointer_frame:return
	if pressed:last_pointer_frame=Engine.get_process_frames()
	previous=pointer;pointer=p
	if pressed:holding=true;pointer_down(p)
	if moved and holding:pointer_move(previous,p)
	if released:pointer_up(p);holding=false;drag_id=-1
	canvas.accept_event()
func pointer_down(p:Vector2) -> void:
	if kind=="tea" and stage in [0,1,3]:
		holding=Rect2(37,30,210,190).has_point(p)
		if holding:sfx("boil" if stage==0 else "pour",.5)
	if kind=="laundry" and stage==1:holding=Rect2(100,170,268,257).has_point(p)
	match kind:
		"garden","flower_garden","tree":
			var count:=2 if kind=="tree" else 6
			for i in count:
				if plot_rect(i).has_point(p):plot_action(i);break
		"fruit":fruit_down(p)
		"soup","laundry":
			for i in items.size():
				if not placed.has(i) and p.distance_to(items[i])<65:drag_id=i;break
			if kind=="soup" and stage==3 and p.distance_to(Vector2(230,295))<130:drag_id=3
			if kind=="laundry" and stage==2:
				for i in 3:
					if not placed.has(i) and p.distance_to(Vector2(145+i*82,316))<48:drag_id=i;break
		"tea":
			if stage==2 and p.distance_to(Vector2(90,156))<70:drag_id=0
			if stage==5 and Rect2(272,379,176,150).has_point(p):finish("端起杯子，吹一吹。茶香还在，沏好的这一壶留在桌上。",{"tea":true})
		"flowers":
			for i in items.size():
				if not placed.has(i) and p.distance_to(items[i].pos)<65:drag_id=i;break
		"pairs":
			if elapsed<peek_until:return
			for i in pairs.size():
				if card_rect(i).has_point(p) and not matched.has(i) and not flipped.has(i) and flipped.size()<2:
					flipped.append(i);sfx("flip",.6)
					if flipped.size()==2:
						if pairs[flipped[0]]==pairs[flipped[1]]:
							matched.append_array(flipped);flipped=[];streak+=1;tone(1+mini(streak,3))
							status.text=["配上了！","又一对！","连着三对，记性真好。","一对接一对，都记住啦。"][mini(streak,4)-1]
						else:turn_back=elapsed+1.1;streak=0;status.text="不一样，记住它们的位置，再翻翻看。"
					if matched.size()==pairs.size():pairs_done()
		"stars":
			var near_star:bool=night_sky() and found_stars<stars.size() and p.distance_to(stars[found_stars])<46
			# 流星只在夜里有；先认星星，点在别处才是许愿；一颗流星只许一次愿
			if elapsed<meteor_until and night_sky() and not near_star and not wished_meteor:wished_meteor=true;show_wish()
			elif not night_sky():
				for c in clouds:
					if not c.found and p.distance_to(cloud_pos(c))<70:c.found=true;sfx("leaf",.5);star_next(c.name);break
			elif found_stars<stars.size():
				if p.distance_to(stars[found_stars])<46:star_next()
				else:status.text="不是这颗。找那颗轻轻一闪一闪的。";hint_until=elapsed+1.5
func pointer_move(a:Vector2,b:Vector2) -> void:
	match kind:
		"wood":
			# 进度条照实走：要来回磨上好一阵才到 100%，不再划一下就满、再干等 7 秒（体验师小毛病 3）
			if Rect2(80,160,300,220).has_point(b):last_scrub=elapsed;progress=minf(progress+minf(a.distance_to(b),45)/3900.0,scrub_time/6.5);sfx("sand",.35,true) # 至少要真的来回磨 6 秒多
			if progress>=1:finish("小木鸟磨好了。它会留在手作房的窗台，等你下次回来。",{"wood":true})
		"soup":
			if stage==1 and b.distance_to(Vector2(230,294))<125:sfx("stir",.45,true);progress+=absf(wrapf((b-Vector2(230,294)).angle()-(a-Vector2(230,294)).angle(),-PI,PI))/(TAU*2.4)
			if stage==1 and progress>=1:stage=2;progress=0;sfx("bubble",.45);status.text="小火咕嘟一会儿，汤会慢慢变浓。"
		"fruit":
			if dragging_basket:basket_x=clampf(b.x,70,390)
func pointer_up(p:Vector2) -> void:
	dragging_basket=false
	match kind:
		"soup":
			if drag_id>=0 and stage==0 and p.distance_to(Vector2(230,295))<130:placed.append(drag_id);sfx("plop")
			if placed.size()==3 and stage==0:stage=1;progress=0;status.text="蔬菜都进锅了。按住锅里绕两圈搅匀。"
			if stage==3 and drag_id==3 and p.distance_to(Vector2(346,464))<88:sfx("pour",.45);finish("盛好一碗热汤。灶上和饭桌上都会记得这一锅。",{"soup":true})
		"laundry":
			if drag_id>=0 and stage==0 and p.distance_to(Vector2(232,311))<98:placed.append(drag_id);sfx("cloth",.6)
			if placed.size()==3 and stage==0:stage=1;progress=0;status.text="衣服装好了。按住圆开关，让滚筒转起来。"
			if drag_id>=0 and stage==2 and p.y>400:placed.append(drag_id);sfx("cloth",.6)
			if placed.size()==3 and stage==2:finish("衣服挂好了，晾衣架上留下三件衣服。下雨记得收回来。",{"laundry":true})
		"tea":
			if stage==2 and drag_id==0 and p.distance_to(Vector2(231,296))<80:stage=3;sfx("leaf",.6);status.text="第四步 · 按住水壶冲水，到右边的水位刻线就松手。";progress=0;tone(2)
			if stage in [1,3] and water_level>=.65:
				if water_level>1.02:water_level=0;sfx("splash",.4);status.text="满出来一点啦。慢慢再倒一次，到右边的水位刻线就松手。"
				elif stage==1:stage=2;water_level=0;status.text="第三步 · 杯子温好了，把左边的茶叶拖进壶里。"
				else:stage=4;steep=0;status.text="第五步 · 茶叶慢慢舒展，茶色也变深了。"
		"fishing":
			if stage==0 and p.y<350:stage=1;progress=elapsed;status.text="浮漂站稳了。等它一沉，按住水面收线。";sfx("cast",.55)
		"flowers":
			if drag_id>=0 and p.x>110 and p.x<350 and p.y>240 and p.y<420:
				items[drag_id].pos=Vector2(clampf(p.x,140,320),clampf(p.y,250,345));placed.append(drag_id);sfx("leaf",.6)
			if placed.size()==3 and not finished:
				var stems:Array=[]
				for item in items:life.take(item.crop);stems.append({"crop":item.crop,"x":item.pos.x,"y":item.pos.y})
				finish("三枝花，各有高低。这一瓶会摆在家里，下次来还在。",{"flowers":stems})
func _process(dt:float) -> void:
	if not canvas:return
	elapsed+=dt
	if kind=="tea" and not finished:
		if stage==0 and holding:progress+=dt*.25
		if stage==0 and progress>=1:stage=1;holding=false;progress=0;sfx("kettle",.4);status.text="第二步 · 按住倒水温杯，到右边的水位刻线就松手。"
		if stage in [1,3] and holding:water_level+=dt*.23
		if stage==4:
			steep=minf(1,steep+dt*.2)
			if steep>=1:stage=5;status.text="第六步 · 出汤进杯，点茶杯喝一口。"
	if kind=="soup" and stage==2:
		progress+=dt*.22
		if progress>=1:stage=3;status.text="汤煮好了。用勺子从锅里拖向右下的小碗，盛出来。"
	if kind=="laundry" and stage==1 and holding:
		sfx("wash",.5,true);progress+=dt*.25
		if progress>=1:stage=2;progress=0;placed=[];holding=false;status.text="衣服洗好啦。把滚筒里的三件衣服拖到下方晾衣绳。"
	if kind=="fishing" and not finished:
		if stage==1 and elapsed-progress>=bite_at:stage=2;status.text="咬钩啦！按住收线，靠近红边时松一松。";sfx("plop",.6)
		if stage==2:
			tension=clampf(tension+dt*(.28 if holding else -.22)+sin(elapsed*3)*dt*.09,0,1)
			if holding and tension>.15 and tension<.83:reel+=dt*.14;sfx("reel",.4,true)
			elif tension>.91:reel=maxf(0,reel-dt*.08)
			if reel>=1:
				stage=3;holding=false;sfx("splash",.6);status.text="是一尾"+fish_name+"！想让它去哪里？";button("放回小溪",func():finish("轻轻松手，"+fish_name+"游回水草边。",{"fish":fish_name,"keep":false}));button("带回鱼缸",func():finish(fish_name+"住进客厅鱼缸，下次喂鱼也能看到它。",{"fish":fish_name,"keep":true}))
	if kind=="wood" and holding and elapsed-last_scrub<.25:scrub_time+=dt
	if kind=="net":net_step(dt)
	if kind=="fruit":fruit_step(dt)
	if kind=="pairs" and flipped.size()==2 and elapsed>=turn_back:flipped=[]
	if kind=="stars" and night_sky() and elapsed>=meteor_at and wish_input==null:
		meteor_until=elapsed+3;meteor_at=elapsed+15;wished_meteor=false;sfx("twinkle",.5)
	canvas.queue_redraw()
func cycle_seed() -> void:
	var list:Array=life.available(int(context.get("month",10)),"tree" if kind=="tree" else ("flower" if kind=="flower_garden" else "vegetable"))
	selected_crop=list[(list.find(selected_crop)+1)%list.size()];update_status();tone(1)
func plot_rect(i:int) -> Rect2:
	return Rect2(30+(i%2)*224,351,174,151) if kind=="tree" else Rect2(46+(i%2)*200,91+int(i/2)*119,170,94)
func plot_action(i:int) -> void:
	var tree:bool=kind=="tree";selected_plot=i;var ok:=false
	match tool:
		"till":ok=life.till(i,tree)
		"seed":ok=life.plant(i,selected_crop,int(context.get("month",10)),tree)
		"water":ok=life.water(i,tree)
		"harvest":
			var got:Dictionary=life.harvest(i,tree);ok=not got.is_empty()
			if ok:
				# 收成的话留在状态栏上，不被种子盒说明立刻盖掉（体验师小毛病 2）
				finished=false;finish("收下两份"+State.CROPS[got.crop].name+"，留下一份种子。菜去厨房，花去花瓶，果子可以分享。",got);tone(3);return
	update_status()
	if ok:sfx({"till":"dig","seed":"seed","water":"pour","harvest":"pick"}[tool],.55)
	else:tone(0)
	if not ok:status.text+="\n先选对应工具：翻土 → 播种 → 浇水。未成熟时不用重复浇。"
	elif tool=="water" and not finished:finish("已经种好并浇水。它按真实时间生长，关掉游戏也会长，不会枯萎。",{"planted":true})
func update_status() -> void:
	status.text="种子盒 · "+State.CROPS[selected_crop].name+" ×"+str(int(life.data.seeds.get(selected_crop,0)))+"　当前："+{"till":"翻土","seed":"播种","water":"浇水","harvest":"收成"}[tool]+"\n点一块地。菜花约 2–4 小时，果树 3 天；不腐烂，不来也不罚。"
func gift_fruit() -> void:
	var id:String=life.available(int(context.get("month",10)),"tree")[0]
	if life.take(id):status.text="留好一份，等见到家人就分给他们。生活册记下了这份心意。";life.data.effects.fruit_to_share=id;life.event("fruit_gift");tone(4)
	else:status.text="篮子里还没有果子，先在树下摘一篮吧。"
func eat_fruit() -> void:
	var id:String=life.available(int(context.get("month",10)),"tree")[0]
	if life.take(id):status.text="咬一口，甜甜的。剩下的收好，下次也能慢慢吃。";life.event("fruit_eat");tone(3)
	else:status.text="篮子里还没有果子，先摘一篮吧。"
func night_sky() -> bool:return float(context.get("hour",20))>=18 or float(context.get("hour",20))<6
func star_next(found_name:="") -> void:
	var night:=night_sky()
	if night:
		found_stars=mini(found_stars+1,stars.size());tone(found_stars%5)
		if found_stars<stars.size():status.text="点亮了 %d / %d 颗。下一颗在轻轻闪。"%[found_stars,stars.size()]
	else:
		found_stars+=1;status.text="这一朵"+found_name+"。还差 %d 朵。"%(3-found_stars) if found_stars<3 else "这一朵"+found_name+"。"
	if found_stars>=(stars.size() if night else 3):
		var names:Array=[["春夜 · 狮子座","春夜 · 牧夫座"],["夏夜 · 天鹅座","夏夜 · 天蝎座"],["秋夜 · 飞马座","秋夜 · 仙后座"],["冬夜 · 猎户座","冬夜 · 双子座"]][State.season(int(context.get("month",10)))]
		finish(names[constellation]+"。连好了，它会一直在那里。" if night else "像猫、像船、像一只小兔子。白天的天空也有故事。",{"sky":true})
		if night and constellation==0:button("再认一个星座",next_constellation)
## 认完一个，再换同一季的另一个星座（不同的连法）
func next_constellation() -> void:
	constellation=1;found_stars=0;tone(4)
	var other:Array=[[Vector2(120,100),Vector2(190,140),Vector2(250,120),Vector2(320,170),Vector2(300,260),Vector2(210,250)],[Vector2(100,260),Vector2(160,210),Vector2(230,190),Vector2(290,150),Vector2(340,110),Vector2(380,180)],[Vector2(90,120),Vector2(150,170),Vector2(220,120),Vector2(290,170),Vector2(350,120)],[Vector2(140,90),Vector2(150,190),Vector2(150,290),Vector2(260,90),Vector2(270,190),Vector2(270,290)]][State.season(int(context.get("month",10)))]
	stars=other;status.text="另一个星座。还是从轻轻闪的那颗开始。"
	for b in footer.get_children():
		if b is Button and b.text=="再认一个星座":b.queue_free()
func star_hint() -> void:
	hint_until=elapsed+2.5;tone(0,.08)
	if not night_sky():
		for c in clouds:
			if not c.found:status.text="看看那朵——它"+str(c.name).substr(1)+"？点它。";break
func cloud_pos(c:Dictionary) -> Vector2:return c.pos+Vector2(sin(elapsed*.15+c.pos.y)*10,0)
## 摘果：熟的点一下会掉，拖篮子接；青的只会晃一晃。掉在草上的可以再点起来，不扣东西
func fruit_down(p:Vector2) -> void:
	if p.y>430 and absf(p.x-basket_x)<90:dragging_basket=true;return
	for f in fruits:
		if f.state=="hang" and p.distance_to(f.pos)<34:
			if f.ripe:f.state="fall";f.vel=Vector2(0,-60);sfx("pick",.6);status.text="掉下来了，拖篮子去接！"
			else:f.wiggle=1.0;status.text="这颗还青着，留着它再长几天。";tone(0,.06)
			return
		if f.state=="ground" and p.distance_to(f.pos)<40:f.state="basket";caught+=1;sfx("pick",.6);status.text="从草里捡起来，也放进篮子。";check_fruit();return
func fruit_step(dt:float) -> void:
	var left:=dt
	while left>0.0001:
		var piece:=minf(left,.02);left-=piece;fruit_substep(piece)
func fruit_substep(dt:float) -> void:
	for f in fruits:
		f.wiggle=maxf(0,f.wiggle-dt*2)
		if f.state=="fall":
			# 掉落按小步算：画面卡一下也不会「穿过」篮子
			var was:float=f.pos.y;f.vel.y+=520*dt;f.pos+=f.vel*dt
			if was<470 and f.pos.y>=470 and absf(f.pos.x-basket_x)<62:f.state="basket";caught+=1;sfx("plop",.4);status.text="接住了！"+(" 还差 %d 颗。"%(3-caught) if caught<3 else "");check_fruit()
			elif f.pos.y>530:f.pos.y=530;f.state="ground";status.text="掉在草上了，点一下捡起来。"
func check_fruit() -> void:
	if caught>=3 and not finished:
		var got:Dictionary=life.fruit_pick(int(context.get("month",10)))
		finish("接住了一篮当季的果子。可以吃一份，也可以送给家人。" if not got.is_empty() else "今天这一篮已经采过啦，留一些给明天和鸟儿。",got)
## 捞鱼：网兜慢慢停在鱼下面约半秒，鱼才游进来；动得快，近处的鱼会一下游开
func net_step(dt:float) -> void:
	net_speed=lerpf(net_speed,pointer.distance_to(net_last)/maxf(dt,.001),.3);net_last=pointer
	var scared:=false
	for f in net_fish:
		if f.caught:continue
		var drift:Vector2=Vector2(sin(elapsed*.8+f.phase),cos(elapsed*.65+f.phase))*18
		var d:float=f.pos.distance_to(pointer)
		if holding and net_speed>420 and d<110:f.flee=(f.pos-pointer).normalized()*170;scared=true
		f.flee=f.flee.lerp(Vector2.ZERO,dt*2.5);f.pos=(f.pos+(drift+f.flee)*dt).clamp(Vector2(40,90),Vector2(420,470))
		if holding and d<38 and net_speed<160:f.under+=dt
		else:f.under=maxf(0,f.under-dt*2)
		if f.under>=.45:f.caught=true;placed.append(f);sfx("splash",.5);status.text="捞到一条！还差 %d 条。"%maxi(0,3-placed.size())
	if scared and not finished:status.text="慢一点……它们被吓跑了，等它们游回来。"
	if placed.size()>=3 and not finished:finish("小网兜里有三条小鱼。看清它们的花纹，再轻轻放回溪水。",{"released":3})
## 翻牌：开局先把牌面亮 1.5 秒让你记一记；配完一局可以再来一局十二张
func start_pairs() -> void:
	var count:=4 if pair_round==1 else 6;pairs=[]
	for i in count:pairs.append_array([i,i])
	pairs.shuffle();matched=[];flipped=[];streak=0;peek_until=elapsed+1.6
	status.text=("先记一记花纹的位置，马上翻过去。" if pair_round==1 else "十二张，六对。先记一记。")+"没有输赢，慢慢找。"
func pairs_done() -> void:
	if pair_round==1:
		finish("四对花纹，都找到了。还想多翻一会儿的话，再来一局十二张。")
		button("再来一局 · 十二张",second_pairs)
	else:status.text="六对都找到了，记性真好！";tone(4)
func second_pairs() -> void:
	pair_round=2;start_pairs()
	for b in footer.get_children():b.queue_free()
func show_wish() -> void:
	if wish_input:return
	var row:=HBoxContainer.new();root.add_child(row);row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);row.offset_left=22;row.offset_right=-22;row.offset_top=-155;row.offset_bottom=-95
	wish_input=LineEdit.new();wish_input.placeholder_text="留一句愿望（也可以留白）";wish_input.max_length=80;wish_input.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(wish_input)
	row.add_child(UI.button("记在生活册",func():life.wish(wish_input.text if not wish_input.text.is_empty() else "愿下次回来，还能看见这片星空。",life.moon_phase());row.queue_free();wish_input=null;status.text="愿望记好了，留在这一天的星空旁。";tone(4)))
func card_rect(i:int) -> Rect2:return Rect2(21+(i%4)*111,173+int(i/4)*165,89,133) if pairs.size()<=8 else Rect2(56+(i%4)*90,128+int(i/4)*132,72,108) # 第二局十二张都在桌面里

func rect(r:Rect2,color:Color) -> void:canvas.draw_rect(Rect2(r.position.round(),r.size.round()),color)
func text(at:Vector2,copy:String,sz:=24,color:=Color("725338")) -> void:canvas.draw_string(UI.FONT,at,copy,HORIZONTAL_ALIGNMENT_LEFT,-1,sz,color)
func block(at:Vector2,size:Vector2,color:Color) -> void:
	rect(Rect2(at+Vector2(0,4),size),color.darkened(.22));rect(Rect2(at,size),color);rect(Rect2(at+Vector2(3,3),Vector2(size.x-6,3)),color.lightened(.18))
func flower(at:Vector2,color:Color,scale:=1.0) -> void:
	for i in 8:
		var p:=at+Vector2.from_angle(i*TAU/8)*12*scale
		rect(Rect2(p-Vector2(4,4)*scale,Vector2(13,13)*scale),color.darkened(.18))
		rect(Rect2(p-Vector2(4,5)*scale,Vector2(10,10)*scale),color)
		rect(Rect2(p-Vector2(3,5)*scale,Vector2(5,3)*scale),color.lightened(.22))
	rect(Rect2(at-Vector2(3,3)*scale,Vector2(13,13)*scale),Color("b88940"));rect(Rect2(at-Vector2(2,3)*scale,Vector2(8,7)*scale),Color("f2cf68"))
func fish(at:Vector2,color:Color,scale:=1.0) -> void:
	for y in range(-9,10,3):
		var w:=int(sqrt(maxf(0,1-pow(y/10.0,2)))*19)
		rect(Rect2(at+Vector2(-w,y)*scale,Vector2(w*2,3)*scale),color.darkened(.15) if y>3 else color)
	for y in range(-8,9,3):rect(Rect2(at+Vector2(-26,y)*scale,Vector2(12-abs(y)*.7,3)*scale),color.darkened(.22))
	rect(Rect2(at+Vector2(9,-4)*scale,Vector2(3,3)*scale),Color("344941"));rect(Rect2(at+Vector2(-8,-7)*scale,Vector2(13,3)*scale),color.lightened(.32))
func fruit(at:Vector2,color:Color) -> void:
	Art.sprite(canvas,"botanical-"+str(6 if color.r>color.g*1.6 else 7),Rect2(at-Vector2(21,25),Vector2(42,45)))
## 青果子：把苹果图里的红换成青绿，个头小一点
var green_tex:Texture2D
func green_fruit(at:Vector2) -> void:
	if green_tex==null:
		var img:Image=preload("res://ayu_home/v2/assets.gd").texture("res://ayu_home/v4/assets/floor1-redraw/botanical-6.png").get_image().duplicate()
		for y in img.get_height():
			for x in img.get_width():
				var c:=img.get_pixel(x,y)
				if c.a>0 and c.r>c.g+.15:img.set_pixel(x,y,Color(c.g*.9+.25,c.r*.85,c.b*.6+.08,c.a))
		green_tex=ImageTexture.create_from_image(img)
	canvas.draw_texture_rect(green_tex,Rect2((at-Vector2(16,19)).round(),Vector2(32,34)),false)
func backdrop(index:int) -> void:
	if not scene_sheet:return
	var source:Rect2=[Rect2(0,0,560,673),Rect2(562,0,560,673),Rect2(0,676,560,724),Rect2(562,676,560,724)][index]
	canvas.draw_texture_rect_region(scene_sheet,Rect2(0,0,460,563),source)
func basket(at:Vector2) -> void:
	Art.sprite(canvas,"botanical-5",Rect2(at-Vector2(0,37),Vector2(132,104)))
func cup(at:Vector2,fill:float,color:Color) -> void:
	block(at,Vector2(82,76),Color("eeddb5"));rect(Rect2(at+Vector2(9,9),Vector2(64,54)),Color("8c6744"));rect(Rect2(at+Vector2(11,61-fill*50),Vector2(60,fill*50)),color);rect(Rect2(at+Vector2(82,15),Vector2(17,34)),Color("ddc89b"));rect(Rect2(at+Vector2(84,22),Vector2(9,17)),Color("e3cba8"))
## 空碗：把汤碗图里的汤换成碗里白瓷的颜色（开局碗是空的）
static var empty_bowl_tex:Texture2D
func empty_bowl() -> Texture2D:
	if empty_bowl_tex:return empty_bowl_tex
	var img:Image=preload("res://ayu_home/v2/assets.gd").texture("res://ayu_home/v4/assets/floor1-redraw/household-3.png").get_image().duplicate()
	for y in img.get_height():
		for x in img.get_width():
			var c:=img.get_pixel(x,y)
			if pow((x-17.5)/14.5,2)+pow((y-21.5)/9.0,2)<=1.0 and c.a>0 and not (c.r>.85 and c.g>.82 and c.b>.75):
				var shade:=.86+.1*clampf((y-13)/16.0,0,1)
				img.set_pixel(x,y,Color(.95*shade,.92*shade,.86*shade,1))
	empty_bowl_tex=ImageTexture.create_from_image(img);return empty_bowl_tex
func fit_texture(tex:Texture2D,area:Rect2) -> void:
	var ratio:=minf(area.size.x/tex.get_width(),area.size.y/tex.get_height());var size:Vector2=(tex.get_size()*ratio).round()
	canvas.draw_texture_rect(tex,Rect2((area.get_center()-size*.5).round(),size),false)
func art(index:int,area:Rect2,alpha:=1.0) -> void:
	var ids:Dictionary={0:0,1:1,2:2,3:3,4:4,5:5,8:6}
	Art.sprite(canvas,"household-"+str(ids.get(index,index)),area,alpha)
func draw_game() -> void:
	if not canvas:return
	var f:=scale_factor();canvas.draw_set_transform(offset(),0,Vector2.ONE*f)
	block(Vector2(0,0),Vector2(460,563),Color("f5e9c9"))
	for y in range(15,550,28):rect(Rect2(12,y,436,1),Color("f1e3c2"))
	match kind:
		"garden","flower_garden","tree":draw_garden()
		"fruit":
			backdrop(0)
			var color:=Color(State.CROPS[life.available(int(context.get("month",10)),"tree")[0]].color)
			for fr in fruits:
				if fr.state=="basket":continue
				if fr.ripe:fruit(fr.pos+Vector2(sin(elapsed*30)*fr.wiggle*4,0),color)
				else:green_fruit(fr.pos+Vector2(sin(elapsed*30)*fr.wiggle*4,0))
			basket(Vector2(basket_x-66,468))
			for i in caught:fruit(Vector2(basket_x-45+i*43,462),color)
		"tea":
			Art.scene(canvas,"tea");art(0,Rect2(37,30,210,190))
			art(1,Rect2(153,226,166,151))
			block(Vector2(333,253),Vector2(20,105),Color("c5b792"));rect(Rect2(337,350-91*clampf(water_level if stage<4 else 1,0,1),12,91*clampf(water_level if stage<4 else 1,0,1)),Color("adcac3").lerp(Color("a36e35"),steep))
			if stage>=2:Art.sprite(canvas,"household-13",Rect2((Vector2(80,168) if drag_id<0 else pointer)-Vector2(24,18),Vector2(48,36)))
			if stage in [1,3] and holding:rect(Rect2(202,127,6,130),Color("bfdde0"))
			for i in 8:
				if i%2==0:rect(Rect2(332+i*3,289,3,2),Color("fff1cd"))
			if stage>=4:art(1,Rect2(272,379,176,150))
			for i in 4:
				if stage==0 or stage>=4:rect(Rect2(115+sin(elapsed+i)*8,63-fmod(elapsed*17+i*11,44),3,9),Color("fff8df"))
			# 步骤用小方块 + 短字（组件库第 2 条：画上的字也是 24）：做过的深、正在做的金、没做的浅；右边写「第三步 · 放茶」
			block(Vector2(22,494),Vector2(416, 40),Color("ead8b1"))
			var step:=clampi(stage,0,5)
			for i in 6:rect(Rect2(36+i*26,505,18,18),Color("75593e") if i<step else (Color("d9a441") if i==step else Color("cbb48a")))
			text(Vector2(204,523),"第%s步 · %s"%["一二三四五六"[step],["烧水","温杯","放茶","冲水","出汤","品茶"][step]],24) # 跟上面那行说明同一种写法（002：中文数字）
		"soup":
			Art.scene(canvas,"soup");art(2,Rect2(50,204,362,282))
			# 还没下菜时锅里是一锅清水，搅匀、咕嘟以后才慢慢变成汤（锅的图本身是满满一锅汤）
			var clear:=1.0 if stage==0 else (1.0-progress*.5 if stage==1 else (maxf(0,.5-progress*.5) if stage==2 else 0.0))
			if clear>0:
				# 一整块椭圆水面（不再用小方块拼，搅的时候不会露格子），盖住锅里原来的汤
				var rim:=PackedVector2Array();var inner:=PackedVector2Array()
				for k in 48:
					var ang:=TAU*k/48.0
					rim.append(Vector2(232,299)+Vector2(cos(ang)*152,sin(ang)*56));inner.append(Vector2(232,301)+Vector2(cos(ang)*138,sin(ang)*46))
				# 清水：透一点的青绿，锅里能看出是水（原来偏灰、像锅盖）；一圈圈水纹和往上冒的小气泡
				var deep:=Color("6f9f9c");deep.a=.92*clear;var face:=Color("9fc9c2");face.a=.86*clear
				canvas.draw_colored_polygon(rim,deep);canvas.draw_colored_polygon(inner,face)
				for k in 3:
					var r:=fmod(elapsed*18+k*30,90.0)
					canvas.draw_arc(Vector2(232,301),r*1.5,0,TAU,40,Color(.92,1,1,.35*clear*(1-r/90.0)),2)
				for k in 5:
					var y:=284+k*9;var x:=176+fmod(elapsed*14+k*37,110)
					rect(Rect2(x,y,22-k*3,3),Color(1,1,1,.6*clear))
				for k in 6:
					var t:=fmod(elapsed*.9+k*.37,1.0)
					rect(Rect2(150+fmod(k*53.0,160),300-t*20,3,3),Color(1,1,1,.7*clear*(1-t)))
			for i in 3:
				var p:Vector2=items[i] if not placed.has(i) else Vector2(156+i*58,274+sin(elapsed+i)*8)
				if drag_id==i:p=pointer
				Art.sprite(canvas,"household-"+str(10+i),Rect2(p-Vector2(7,7),Vector2(57,51)))
			if stage>=1:rect(Rect2(225+sin(elapsed)*32,260,8,140),Color("9f7548"))
			if finished:art(3,Rect2(289,411,171,141)) # 盛好以后碗里才有汤
			else:fit_texture(empty_bowl(),Rect2(289,411,171,141))
			for i in 5:rect(Rect2(132+i*42,245-fmod(elapsed*19+i*11,72),4,11),Color("fff4d6"))
		"laundry":
			Art.scene(canvas,"laundry");art(8,Rect2(100,170,268,257))
			for i in 3:
				var p:Vector2=items[i]
				if stage==1:p=Vector2(205+sin(elapsed*4+i*2)*45,304+cos(elapsed*4+i*2)*32)
				elif stage==2:p=Vector2(145+i*82,316) if not placed.has(i) else Vector2(92+i*124,446)
				elif placed.has(i):p=Vector2(165+i*51,306)
				if drag_id==i:p=pointer
				Art.sprite(canvas,"household-"+str(7+i),Rect2(p-Vector2(9,3),Vector2( 66, 66)))
			rect(Rect2(28,438,403,4),Color("8c7050"))
		"wood":
			Art.scene(canvas,"wood")
			var k:=clampf(progress,0,1)
			art(4,Rect2(43,124,377,334),1-k);art(5,Rect2(43,124,377,334),k)
			for i in int(k*32):rect(Rect2(73+fmod(i*43.0,317),378+fmod(i*17.0,39),10,4),Color("eccf9b"))
			if holding:block(pointer-Vector2(25,12),Vector2(61,24),Color("7f9a88"))
			block(Vector2(36,468),Vector2(388,44),Color("ead8b1"));text(Vector2(55,499),"木纹一点点露出来 · "+str(int(k*100))+"%",24)
		"fishing","net":draw_water()
		"flowers":
			Art.scene(canvas,"flowers")
			for i in items.size():
				var p:Vector2=pointer if drag_id==i else items[i].pos
				var base:=Vector2(235,398) if placed.has(i) else p+Vector2(0,119)
				canvas.draw_line(p+Vector2(0,13),base,Color("486d39"),4)
				Art.sprite(canvas,"botanical-4",Rect2(p+Vector2(-23,15),Vector2(46,maxf(44,base.y-p.y))))
				Art.sprite(canvas,"botanical-"+str(i%3),Rect2(p-Vector2(38,35),Vector2(76, 70)))
			Art.sprite(canvas,"botanical-3",Rect2(181,345,108,112))
		"pairs":
			Art.scene(canvas,"pairs")
			for i in pairs.size():
				var r:=card_rect(i);var shown:bool=flipped.has(i) or matched.has(i) or elapsed<peek_until
				if shown and pairs[i]>=4:
					# 第二局多出来的两种花纹：用同一套牌框（蕨叶那张的框），中间换成苹果、菊花
					Art.sprite(canvas,"botanical-13",r);var inner:=Rect2(r.position+r.size*Vector2(.2,.16),r.size*Vector2(.6,.68))
					rect(inner,Color("f3e3c0"));Art.sprite(canvas,"botanical-"+str([6,1][pairs[i]-4]),inner.grow(-3))
				else:Art.sprite(canvas,"botanical-"+str(10+pairs[i] if shown else 9),r)
				if matched.has(i):rect(Rect2(r.position+Vector2(4,r.size.y-10),Vector2(r.size.x-8,4)),Color("8fbf7a"))
		"stars":draw_sky()
	if finished and kind not in ["stars","garden","flower_garden","tree"] and not (kind=="pairs" and pair_round==2):
		block(Vector2(100,18),Vector2(260,48),Color("749b75"));text(Vector2(122,52),"这一刻，留在家里了",24,Color("fff8dd"))
	canvas.draw_set_transform(Vector2.ZERO)
func draw_garden() -> void:
	backdrop(0 if kind=="tree" else 3)
	block(Vector2(20,17),Vector2(420,44),Color("f5e9c9"));text(Vector2(33,48),"妈妈每季备一包，收成还能留种",24)
	var rows:Array=life.data.trees if kind=="tree" else life.data.plots
	for i in rows.size():
		var r:=plot_rect(i);var p:Dictionary=rows[i]
		if kind=="tree":Art.sprite(canvas,"botanical-8",r)
		if not p.is_empty():
			for n in 5:rect(Rect2(r.position+Vector2(12,12+n*11),Vector2(r.size.x-24,2)),Color("664a38") if p.get("watered",false) else Color("b7905b"))
		else:
			for n in 3:rect(Rect2(r.position+Vector2(27+n*39,21),Vector2(3,9)),Color("9baf61"))
		if p.has("crop"):
			var grow:float=life.growth(p);var center:=r.get_center()-Vector2(0,15)
			if kind=="tree":draw_planted_tree(center+Vector2(0,29),1.0 if p.get("grown",false) else grow,Color(State.CROPS[p.crop].color),grow>=.65)
			for j in (0 if kind=="tree" else 3):
				var at:=center+Vector2((j-1)*38 if kind!="tree" else 0,0);var size:=.4+grow*.7
				rect(Rect2(at,Vector2(4,18+grow*18)),Color("6d874f"))
				for n in 4:
					var q:=at+Vector2(-12 if n%2==0 else 3,n*6-5);rect(Rect2(q,Vector2(13,6)),Color("789c4f"));rect(Rect2(q+Vector2(2,-2),Vector2(8,3)),Color("a2c66d"))
				if grow>.65:flower(at-Vector2(4,12),Color(State.CROPS[p.crop].color),size)
			# 格子下面一行字 24 号：「萝卜 发芽」（菜名 2～3 字 + 短的长到哪一步），没种的只写「要翻土」「能播种」这样
		block(r.position+Vector2(2,r.size.y-31),Vector2(r.size.x-4,30),Color("75593e"))
		text(r.position+Vector2(8,r.size.y-8),(State.CROPS[p.crop].name+" " if p.has("crop") else "")+life.stage_short(p),24,Color("fff1d1"))
func draw_planted_tree(at:Vector2,growth:float,fruit_color:Color,has_fruit:bool) -> void:
	var height:=38+growth*124
	rect(Rect2(at-Vector2(5,height*.55),Vector2(10,height*.55)),Color("795536"))
	rect(Rect2(at-Vector2(1,height*.52),Vector2(4,height*.52)),Color("bd914e"))
	for y in range(-int(height),-int(height*.33),6):
		for x in range(-int(height*.38),int(height*.38),6):
			var n:=Vector2(float(x)/(height*.38),(y+height*.67)/(height*.34))
			if n.length_squared()>1+sin(y*.18)*.12:continue
			var shade:=posmod(x*13+y*17,5)
			rect(Rect2(at+Vector2(x,y),Vector2(6,6)),[Color("365b35"),Color("477238"),Color("668d3c"),Color("82a548"),Color("a4c85c")][shade])
	if has_fruit:
		for i in 5:fruit(at+Vector2(sin(i*2.3)*height*.23,-height*.63+cos(i*1.7)*height*.16),fruit_color)
func draw_water() -> void:
	backdrop(1)
	for i in 31:rect(Rect2(fmod(i*83.0+elapsed*6,419)+14,64+fmod(i*51.0,393),28,3),Color("9bc5be"))

	if kind=="net":
		for f in net_fish:
			if not f.caught:fish(f.pos,Color("dfc991"),.8*float(f.get("size",1.0)))
			if not f.caught and f.get("under",0.0)>0:canvas.draw_arc(f.pos,20,-PI*.5,-PI*.5+TAU*minf(1,f.under/.45),16,Color(1,.97,.8,.8),2)
		canvas.draw_arc(pointer,36,0,TAU,20,Color("eed9a9"),4);canvas.draw_line(pointer+Vector2(25,25),pointer+Vector2(80,99),Color("957b54"),7)
	else:
		canvas.draw_line(Vector2(357,542),Vector2(296,292),Color("98704b"),7)
		if stage>0:
			canvas.draw_line(Vector2(296,292),Vector2(218,236),Color("eee5cb"),2);block(Vector2(214,225+sin(elapsed*5)*(8 if stage==2 else 2)),Vector2(8,18),Color("e7bd72"))
		if stage==2:
			block(Vector2(40,74),Vector2(380,27),Color("96735f"));rect(Rect2(50,79,300,13),Color("bad093"));rect(Rect2(51+tension*350,70,8,33),Color("fff3cc"));text(Vector2(44,149),"收线 "+str(int(reel*100))+"%",24,Color("fff4d5"))
		if stage==3:fish(Vector2(193,373),Color("edc77d"),2.1);text(Vector2(167,441),fish_name,24,Color("fff4d5"))
func draw_sky() -> void:
	var night:bool=float(context.get("hour",20))>=18 or float(context.get("hour",20))<6
	Art.scene(canvas,"stars-night" if night else "stars-day")
	if night:
		draw_moon(Vector2(374,63),27,life.moon_phase())
		for i in stars.size():
			var p:Vector2=stars[i];var color:=Color("ffe5a1") if i<found_stars else Color("91a9bd")
			if i==found_stars:
				# 下一颗：轻轻一闪一闪；点「提示一下」时闪得更明显
				var glow:float=.5+.5*sin(elapsed*(9.0 if elapsed<hint_until else 4.0))
				color=Color("91a9bd").lerp(Color("fff4c8"),glow)
				if elapsed<hint_until:canvas.draw_arc(p,14+glow*6,0,TAU,16,Color(1,.95,.75,.6),2)
			rect(Rect2(p-Vector2(2,6),Vector2(4,12)),color);rect(Rect2(p-Vector2(6,2),Vector2(12,4)),color)
			if i>0 and i<found_stars:canvas.draw_line(stars[i-1],p,Color("acbda3"),2)
		if elapsed<meteor_until:
			var x:float=60+(3-(meteor_until-elapsed))*93
			for i in 14:rect(Rect2(roundf((x-i*6)/3)*3,roundf((96-i*3.3)/3)*3,3,3),Color("f8e4bc").lerp(Color("657399"),float(i)/14))
	if not night:
		for c in clouds:
			var cp:Vector2=cloud_pos(c)
			if c.found:
				for k in 6:rect(Rect2(cp+Vector2.from_angle(k*TAU/6+elapsed)*34-Vector2(2,2),Vector2(4,4)),Color(1,.97,.8,.9))
			elif elapsed<hint_until:canvas.draw_arc(cp,40,0,TAU,20,Color(1,1,1,.55),2)
	var sway:float=sin(elapsed*.85)*17
	canvas.draw_line(Vector2(139,353),Vector2(158+sway,498),Color("bd9b6a"),4)
	canvas.draw_line(Vector2(304,353),Vector2(317+sway,498),Color("bd9b6a"),4)
	Art.sprite(canvas,"household-15",Rect2(147+sway,475,180,62))
	if State.season(int(context.get("month",10)))==1 and night:
		for i in 15:rect(Rect2(20+fmod(i*79.0+sin(elapsed+i)*8,410),400+sin(elapsed*.8+i)*35,3,3),Color("e3e99a"))
func draw_moon(center:Vector2,radius:int,phase:float) -> void:
	# Orthographic illuminated hemisphere, waxing right / waning left.
	var light:=Vector3(sin(TAU*phase),0,-cos(TAU*phase))
	for y in range(-radius,radius,2):
		for x in range(-radius,radius,2):
			var n:=Vector3(float(x)/radius,float(y)/radius,0)
			if n.length_squared()>1:continue
			n.z=sqrt(1-n.length_squared())
			var lit:=n.dot(light)>0
			var color:=Color("eee3b8") if lit else Color("263655")
			if lit:
				if n.z<.55:color=Color("d1c59c")
				for crater in [Vector3(-9,-8,6),Vector3(8,11,5),Vector3(10,-12,4),Vector3(-12,9,3)]:
					if Vector2(x-crater.x,y-crater.y).length()<crater.z:color=Color("c4bd9a") if y<crater.y else Color("dbd2ac")
			rect(Rect2(center+Vector2(x,y),Vector2(2,2)),color)
## 动作声（烧水、倒水、收线……）。busy 为真时，正在响就不打断（磨木、收线这种连续的）。
func sfx(name:String,volume:=.5,busy:=false) -> void:
	if not context.get("sound",true) or not fx:return
	if busy and fx.playing:return
	fx.stream=Sfx.get_sound(name);fx.volume_db=linear_to_db(volume);fx.play()
func tone(note:int,volume:=.12) -> void:
	if not context.get("sound",true) or not sound:return
	if sound.playing and volume<.05:return
	if not note_cache.has(note):
		var wave:=AudioStreamWAV.new();wave.format=AudioStreamWAV.FORMAT_16_BITS;wave.mix_rate=22050;var bytes:=PackedByteArray();bytes.resize(6615*2)
		var hz:float=[261.63,329.63,392.0,440.0,523.25][posmod(note,5)]
		for i in 6615:bytes.encode_s16(i*2,int(sin(TAU*hz*i/22050.0)*exp(-float(i)/1600)*9000))
		wave.data=bytes;note_cache[note]=wave
	sound.stream=note_cache[note];sound.volume_db=linear_to_db(volume);sound.play()
