extends CanvasLayer
const UI=preload("res://ayu_home/v4/pixel_ui.gd")
const Rules=preload("res://ayu_home/v4/core/childhood_rules.gd")
const C=preload("res://ayu_home/v4/core/config.gd")
const Assets=preload("res://ayu_home/v2/assets.gd")
var ui
var root:Control
var col:VBoxContainer
var status:Label
var clock:Label
var selected:=""
var selected_milk:=0
var press_time:=0.0
var finished:=false
var last_seconds:=-1
var last_catch:=""
var last_catch_at:=-10.0
const TITLES={"milk":"过期的牛奶","loach":"河里抓泥鳅","train":"一个人坐火车出远门","laundry":"下雨前收衣服","vegetables":"帮妈妈择菜"}
const INTRO={"milk":"小时候，我误喝了爸爸买回来的牛奶，全身过敏。大家急着送我去医院。现在回想起来，还是想把那盒牛奶先找出来。","loach":"小时候，我去河里抓过泥鳅。泥水遮住了它们的身影，水纹和小泡泡却会留下线索。","train":"小时候，我一个人坐火车去外地。出发前要采买东西，再把行囊一样样收好。","laundry":"家里留了一件小事：天气预报说雨快到了。把晾着的衣服收回来吧。","vegetables":"家里留了一件小事：帮妈妈择菜。把黄叶、虫叶挑出去，留下新鲜的菜叶。"}
func setup(owner) -> void:
	ui=owner;layer=75
	root=PanelContainer.new();root.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(root);root.add_theme_stylebox_override("panel",UI.card_box())
	var margin:=MarginContainer.new();margin.add_theme_constant_override("margin_left",20);margin.add_theme_constant_override("margin_right",20);margin.add_theme_constant_override("margin_top",24);margin.add_theme_constant_override("margin_bottom",24);root.add_child(margin)
	var scroll:=ScrollContainer.new();margin.add_child(scroll);scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	col=VBoxContainer.new();col.size_flags_horizontal=Control.SIZE_EXPAND_FILL;col.add_theme_constant_override("separation",10);scroll.add_child(col)
	menu()
func clear() -> void:
	for child in col.get_children():col.remove_child(child);child.queue_free()
	clock=null;status=null
func add_text(text:String) -> void:col.add_child(UI.paragraph(text))
func button(text:String,callback:Callable,primary:=false,parent:Node=null) -> Button:
	var b:=UI.button(text,callback,primary);b.custom_minimum_size.y=48;(col if parent==null else parent).add_child(b);return b
func menu() -> void:
	finished=true;clear();col.add_child(UI.label("小时候的事",28));add_text("阿鱼的旧本子 · 每段故事每天可完成一次，失败可以再试。")
	for id in ["milk","loach","train",Rules.daily_story(ui.state)]:button(TITLES[id],intro.bind(id))
	var pages:Array=ui.state.data.village.get("childhood",{}).get("pages",[])
	add_text("已收好的回忆："+str(pages.size())+" 页")
	button("合上本子",close)
func intro(id:String) -> void:
	clear();col.add_child(UI.label(TITLES[id],26));add_text(INTRO[id])
	if id=="loach" and ui.home.area!="village":button("带上竹篓，到村边小河去",func():var target=ui;close();target.travel("village","loach_memory"),true)
	else:button("开始这段回忆",begin.bind(id),true)
	button("返回本子",menu)
func begin(id:String) -> void:
	var result:Dictionary=ui.state.act("memory_begin",{"id":id})
	if not result.ok:add_text(str(result.message));return
	finished=false;selected="";render()
func close() -> void:
	if not finished:ui.state.act("memory_cancel")
	ui.opened=false;ui.home.ui.visible=true;ui.childhood_game=null;queue_free()
func _unhandled_input(event:InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):close();get_viewport().set_input_as_handled()
func send(command:String,args:Dictionary={}) -> void:
	var result:Dictionary=ui.state.act(command,args)
	if result.get("outcome","") in ["complete","hospital","rain"]:
		finished=true;clear();col.add_child(UI.label({"complete":"一页回忆","hospital":"暖色的回忆","rain":"雨点落下了"}[result.outcome],26))
		var path:="res://ayu_home/v4/assets/childhood/hospital.png"
		if result.outcome=="hospital" and FileAccess.file_exists(path):
			var art:=TextureRect.new();art.texture=Assets.texture(path);art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;art.custom_minimum_size=Vector2(220,180);col.add_child(art)
		add_text(str(result.message));button("回到旧本子",menu,true);return
	if result.has("catch"):last_catch=str(result.catch);last_catch_at=Time.get_ticks_msec()/1000.0
	if result.ok:render()
	if is_instance_valid(status):status.text=str(result.message)
func render() -> void:
	clear();last_seconds=-1
	var session:Dictionary=ui.state.data.village.childhood.active
	if session.is_empty():menu();return
	var id:=str(session.id);col.add_child(UI.label(TITLES[id],26));clock=UI.label("",20);col.add_child(clock)
	match id:
		"milk":milk(session)
		"loach":loach(session)
		"train":train(session)
		"laundry","vegetables":daily(session)
	status=UI.paragraph("");col.add_child(status);button("先放下（不领取奖励）",close)
	for child in col.get_children():
		if child is Button:child.grab_focus();break
func _process(_dt:float) -> void:
	if finished or not is_instance_valid(clock):return
	var session:Dictionary=ui.state.data.village.get("childhood",{}).get("active",{})
	if session.is_empty():return
	var limits:Dictionary={"milk":C.CHILDHOOD.milk_seconds,"loach":C.CHILDHOOD.loach_seconds,"laundry":C.CHILDHOOD.laundry_seconds}
	if not limits.has(str(session.id)):clock.text="";return
	var limit:=int(limits[session.id])
	var left:=maxi(0,int(ceil(limit-(ui.state.now()-float(session.started)))))
	if left==last_seconds:return
	last_seconds=left;clock.text=({"milk":"小阿鱼走到桌边还有 ","loach":"剩余 ","laundry":"雨点落下还有 "}[session.id])+str(left)+" 秒"
	if left==0:send({"milk":"milk_finish","loach":"loach_finish","laundry":"daily_finish"}[session.id])
func scene_board(kind:String,session:Dictionary) -> Control:
	var frame:=AspectRatioContainer.new();frame.ratio=16.0/9.0;frame.custom_minimum_size.y=250;col.add_child(frame)
	var board:=SceneBoard.new();board.kind=kind;board.session=session;board.owner_game=self;frame.add_child(board);return board
func milk(session:Dictionary) -> void:
	add_text("第 %d / 3 关 · 今天 %s · 剩 %d 次检查"%[int(session.level)+1,ui.state.date_key(),int(C.CHILDHOOD.milk_checks)-int(session.checks)])
	add_text("点桌上的牛奶看包装，把不能喝的放到右边。")
	scene_board("milk",session)
	selected_milk=clampi(selected_milk,0,session.cards.size()-1)
	var card:Dictionary=session.cards[selected_milk]
	add_text("选中第 %d 盒 · 生产 %s · 保质期 %d 天"%[selected_milk+1,card.made,int(card.days)])
	if card.swollen:add_text("包装鼓胀了。")
	if card.leaking:add_text("包装有渗漏。")
	if session.revealed.has(str(selected_milk)+":date"):add_text(("已经开封，" if card.opened else "未开封，")+("一直冷藏" if card.cold else "没有放进冰箱"))
	if session.revealed.has(str(selected_milk)+":colour"):add_text("倒出后："+("结块、颜色不匀" if card.bad else "颜色均匀"))
	if session.revealed.has(str(selected_milk)+":smell"):add_text("气味："+("有酸味" if card.bad else "没有异常气味"))
	var row:=HFlowContainer.new();col.add_child(row)
	for pair in [["看存放","date"],["倒出看颜色","colour"],["闻气味","smell"]]:button(pair[0],send.bind("milk_check",{"index":selected_milk,"kind":pair[1]}),false,row)
	button("放回桌上" if selected_milk in session.isolated else "把这盒放到一边",send.bind("milk_isolate",{"index":selected_milk}),false,row)
	button("确认，给小阿鱼留好牛奶",send.bind("milk_finish"),true)
func loach(session:Dictionary) -> void:
	add_text("看水纹，按住再松手捞一下；握得太久会滑走。竹篓里：%d 条"%int(session.caught))
	scene_board("loach",session)
	add_text("六十秒结束才会把泥鳅带回家；石头、螃蟹不扣分。")
func train(session:Dictionary) -> void:
	add_text("回忆里的货摊 · 妈妈的清单：车票、证件、水。\n先采买，再把物品拖进 5 × 3 的格子箱。车票、证件、水必须装进去。\n这段回忆的零花钱：%d / %d（仅在回忆里使用）"%[int(session.budget),int(C.CHILDHOOD.train_budget)])
	scene_board("train",session)
	var shop:=GridContainer.new();shop.columns=2;col.add_child(shop)
	for item in Rules.PACK:
		var info:Dictionary=Rules.PACK[item]
		if not item in session.bought:
			var offer:=button(str(info.name)+" · %d"%int(info.cost),send.bind("train_buy",{"item":item}),false,shop)
			offer.icon=object_icon(item);offer.expand_icon=true;offer.add_theme_constant_override("icon_max_width",40)
	var palette:=HFlowContainer.new();col.add_child(palette)
	for item in session.bought:
		var info:Dictionary=Rules.PACK[item];var b:=LuggageItem.new();b.item=item;b.owner_game=self;b.icon=object_icon(item);b.expand_icon=true;b.add_theme_constant_override("icon_max_width",40);b.text=str(info.name)+" %d×%d"%[info.size[0],info.size[1]];b.custom_minimum_size=Vector2(112,50);b.pressed.connect(func():selected=item;status.text="选好"+str(info.name)+"，点箱格放下，也可以直接拖动");palette.add_child(b)
	var board:=LuggageBoard.new();board.owner_game=self;board.session=session;board.custom_minimum_size=Vector2(280,180);board.size_flags_horizontal=Control.SIZE_EXPAND_FILL;col.add_child(board)
	for item in session.packed:button("拿出"+str(Rules.PACK[item].name),send.bind("train_pack",{"item":item,"x":-1,"y":-1}))
	button("带好行李，出发",send.bind("train_finish"),true)
func daily(session:Dictionary) -> void:
	add_text("天气预报说雨快到了，%d 秒内把衣服一件件收进篮里。"%int(C.CHILDHOOD.laundry_seconds) if session.id=="laundry" else "挑走黄叶和虫叶，绿叶留给妈妈。")
	scene_board(str(session.id),session)
	add_text("已收好 %d 件"%session.picked.size());button("收拾好了",send.bind("daily_finish"),true)
const OBJECTS=["milk_good","milk_swollen","milk_leak","bowl","loach","stone","crab","basket","ticket","document","water","coat","snack","book","shirt","trousers","scarf","towel","socks","leaf_green","leaf_yellow","leaf_bug","bubble","ripple","mud_splash"]
static func object_icon(id:String) -> Texture2D:
	var path:="res://ayu_home/v4/assets/childhood/objects.png"
	if not FileAccess.file_exists(path):return null
	var index:=OBJECTS.find(id)
	if index<0:return null
	var texture:=AtlasTexture.new();texture.atlas=preload("res://ayu_home/v2/assets.gd").texture(path);texture.region=Rect2(index%8*64,index/8*64,64,64);texture.filter_clip=true;return texture
class SceneBoard extends Control:
	var kind:=""
	var session:Dictionary
	var owner_game
	var down_index:=-1
	var pressed_at:=0.0
	var age:=0.0
	var ayu_texture:Texture2D
	var ayu_frames:Array=[]
	func _ready() -> void:
		texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;mouse_filter=Control.MOUSE_FILTER_STOP
		if kind=="milk":
			ayu_texture=preload("res://ayu_home/v2/assets.gd").texture("res://ayu_home/v2/assets/chr_ayu.png")
			ayu_frames=JSON.parse_string(FileAccess.get_file_as_string("res://ayu_home/v2/assets/chr_ayu.json")).frames.left
	func _process(dt:float) -> void:age+=dt;queue_redraw()
	func at(index:int) -> Vector2:
		if kind=="milk":
			var slot:int=session.isolated.find(index)
			return Vector2(.80+slot%2*.10,.50+int(slot/2)*.16) if slot>=0 else Vector2(.18+index%3*.20,.52+int(index/3)*.27)
		if kind=="loach":return Vector2(.27+index%3*.23,.40+int(index/3)*.18)
		if kind=="laundry":return Vector2(.34+index*.065,.36)
		return Vector2(.30+index%4*.13,.60+int(index/4)*.15)
	func pixel_size(extent:Vector2) -> Vector2:return extent*size/Vector2(640,360)
	func icon(id:String,point:Vector2,extent:=Vector2(54,54)) -> void:
		var texture:Texture2D=owner_game.object_icon(id)
		var scaled:=pixel_size(extent)
		if texture:draw_texture_rect(texture,Rect2(point-scaled*.5,scaled),false)
	func _draw() -> void:
		var file:String={"milk":"milk_table","loach":"mudflat","train":"train_room","laundry":"laundry","vegetables":"vegetables"}.get(kind,kind)
		var path:="res://ayu_home/v4/assets/childhood/"+file+".png"
		if FileAccess.file_exists(path):draw_texture_rect(preload("res://ayu_home/v2/assets.gd").texture(path),Rect2(Vector2.ZERO,size),false)
		if kind=="milk":
			for i in session.cards.size():
				var card:Dictionary=session.cards[i];icon("milk_swollen" if card.swollen else ("milk_leak" if card.leaking else "milk_good"),at(i)*size,Vector2(42,58))
				if i==owner_game.selected_milk:draw_rect(Rect2(at(i)*size-pixel_size(Vector2(25,32)),pixel_size(Vector2(50,64))),Color("b38653"),false,2)
				# Packaging dates stay available without spending a storage/colour/smell inspection.
				draw_string(UI.FONT,at(i)*size+Vector2(-24,42),str(i+1),HORIZONTAL_ALIGNMENT_CENTER,48,15,Color("43392c"))
			var fraction:=clampf(float(owner_game.ui.state.now()-float(session.started))/float(C.CHILDHOOD.milk_seconds),0,1)
			var frame:=int(ayu_frames[int(age*5)%ayu_frames.size()]);draw_texture_rect_region(ayu_texture,Rect2(Vector2(.94-fraction*.24,.30)*size,pixel_size(Vector2(32,42))),Rect2(frame%16*64,int(frame/16)*84,64,84))
		elif kind=="loach":
			var target:=posmod(int(session.casts)*5+3,9);var point:=at(target)*size
			icon("ripple",point,Vector2(64+sin(age*4)*8,40));icon("bubble",point+Vector2(0,-12+sin(age*4)*3),Vector2(28,28))
			icon("basket",Vector2(.91,.86)*size,Vector2(60,60))
			if not owner_game.last_catch.is_empty() and Time.get_ticks_msec()/1000.0-owner_game.last_catch_at<2:icon(owner_game.last_catch,Vector2(.77,.70)*size,Vector2(58,58))
			for i in mini(5,int(session.caught)):icon("loach",Vector2(.89+i*.012,.85-i*.015)*size,Vector2(28,28))
			if down_index>=0:icon("basket",at(down_index)*size,Vector2(64,64));icon("mud_splash",at(down_index)*size+Vector2(0,-15),Vector2(64,64))
		elif kind in ["laundry","vegetables"]:
			for i in 8:
				if i in session.picked:continue
				var id:String=["coat","shirt","scarf","trousers","towel","shirt","socks","towel"][i] if kind=="laundry" else ["leaf_green","leaf_yellow","leaf_bug"][i%3]
				icon(id,at(i)*size,Vector2(52,62))
			icon("basket",Vector2(.92,.85)*size,Vector2(54,54))
			for i in mini(5,session.picked.size()):icon("shirt" if kind=="laundry" else "leaf_yellow",Vector2(.90+i*.01,.80-i*.015)*size,Vector2(22,22))
	func index_at(point:Vector2) -> int:
		var count:int=session.cards.size() if kind=="milk" else (9 if kind=="loach" else 8)
		var best:=-1;var distance:=INF
		for i in count:
			if kind in ["laundry","vegetables"] and i in session.picked:continue
			var d:=point.distance_to(at(i)*size)
			if d<distance:distance=d;best=i
		return best if distance<maxf(45,size.x*.14) else -1
	func _gui_input(event:InputEvent) -> void:
		var pressed:=false;var released:=false;var point:=Vector2.ZERO
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:pressed=event.pressed;released=not event.pressed;point=event.position
		elif event is InputEventScreenTouch:pressed=event.pressed;released=not event.pressed;point=event.position
		else:return
		var index:=index_at(point)
		if pressed:
			down_index=index;pressed_at=Time.get_ticks_msec()/1000.0
			if index>=0:
				if kind=="milk":owner_game.selected_milk=index;owner_game.render()
				elif kind in ["laundry","vegetables"]:owner_game.send("daily_pick",{"index":index})
		elif released and kind=="loach" and down_index>=0:owner_game.send("loach_cast",{"target":down_index,"hold":Time.get_ticks_msec()/1000.0-pressed_at});down_index=-1
		accept_event()
class LuggageItem extends Button:
	var item:=""
	var owner_game
	func _get_drag_data(_position:Vector2):
		var preview:=Label.new();preview.text=text;set_drag_preview(preview);return {"luggage":item}
class LuggageBoard extends Control:
	var owner_game
	var session:Dictionary
	var cursor:=Vector2i.ZERO
	func _ready() -> void:focus_mode=Control.FOCUS_ALL
	func _draw() -> void:
		var cell:=Vector2(size.x/5.0,size.y/3.0)
		draw_style_box(UI.card_box(),Rect2(Vector2.ZERO,size))
		for x in 6:draw_line(Vector2(x*cell.x,0),Vector2(x*cell.x,size.y),Color("a58b68"),1)
		for y in 4:draw_line(Vector2(0,y*cell.y),Vector2(size.x,y*cell.y),Color("a58b68"),1)
		if has_focus():draw_rect(Rect2(Vector2(cursor)*cell,cell),Color("b98748"),false,3)
		for item in session.packed:
			var at:Array=session.packed[item];var shape:Array=Rules.PACK[item].size;var rect:=Rect2(Vector2(at[0]*cell.x,at[1]*cell.y)+Vector2(3,3),Vector2(shape[0]*cell.x,shape[1]*cell.y)-Vector2(6,6))
			draw_style_box(UI.card_box(),rect)
			var icon:Texture2D=owner_game.object_icon(item)
			if icon:draw_texture_rect(icon,Rect2(rect.get_center()-Vector2(22,22),Vector2(44,44)),false)
			draw_string(UI.FONT,rect.position+Vector2(4,rect.size.y-4),str(Rules.PACK[item].name),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("433c32"))
	func _can_drop_data(_pos:Vector2,data) -> bool:return data is Dictionary and data.has("luggage")
	func _drop_data(pos:Vector2,data) -> void:place(pos,str(data.luggage))
	func place(pos:Vector2,item:String) -> void:
		if item.is_empty():return
		owner_game.send("train_pack",{"item":item,"x":int(pos.x/(size.x/5)),"y":int(pos.y/(size.y/3))})
	func _gui_input(event:InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:grab_focus();place(event.position,owner_game.selected);accept_event()
		if event is InputEventKey and event.pressed:
			if event.is_action_pressed("ui_left"):cursor.x=maxi(0,cursor.x-1)
			elif event.is_action_pressed("ui_right"):cursor.x=mini(4,cursor.x+1)
			elif event.is_action_pressed("ui_up"):cursor.y=maxi(0,cursor.y-1)
			elif event.is_action_pressed("ui_down"):cursor.y=mini(2,cursor.y+1)
			elif event.is_action_pressed("ui_accept"):place((Vector2(cursor)+Vector2(.5,.5))*Vector2(size.x/5,size.y/3),owner_game.selected)
			queue_redraw();accept_event()
