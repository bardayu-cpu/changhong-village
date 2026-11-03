extends Control
const UI=preload("res://ayu_home/v4/pixel_ui.gd")
const C=preload("res://ayu_home/v4/core/config.gd")
const Assets=preload("res://ayu_home/v2/assets.gd")
var ui
var game_id:=""
var run_id:=""
var progress:=0
var finished:=false
var meter:ProgressBar
var message:Label
var start_button:Button
var collect_button:Button
var exit_button:Button
var board
const HONEY_SEQUENCE=[0,3,1,4,2,5]
const CIVIC_SEQUENCE=[1,0,2]
const COPY={
 "mill":["沿亮起的推杆位置慢慢推三圈。完成后用谷子 2 份换谷粉 1 份。","握住推杆","收好谷粉","谷粉落满了粉槽，可以收好这一份。"],
 "honey":["按亮起的位置压好六块蜜脾，蜜会慢慢接进罐里。今天可收一瓶。","摆好蜜脾","封好这瓶蜜","这一瓶接满了，封好蜡口带回去吧。"],
 "civic":["读一读事务卡，把它放到灌渠、修桥或补路的对应格子。三张理齐可带走一份竹材。","摊开事务卡","收好修缮竹材","三张卡归好类了，收好这一份修缮竹材。"],
 "community":["洗净楼卜、切好海椒，再把它们拌匀。完成时用各 1 份食材做成一碗共桌菜。","摆出食材","端好这一碗","香气出来了，端上这碗海椒拌楼卜。"]}
func setup(owner,id:String) -> void:
	ui=owner;game_id=id;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);theme=UI.theme();mouse_filter=Control.MOUSE_FILTER_STOP
	var bg:=ColorRect.new();bg.color=UI.DEEP;bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(bg)
	var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(margin)
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,24)
	var col:=VBoxContainer.new();col.add_theme_constant_override("separation",14);margin.add_child(col)
	col.add_child(UI.label(str(C.INSTITUTION_GAMES[id].title),28))
	message=UI.paragraph(COPY[id][0],22);message.custom_minimum_size.y=78;col.add_child(message)
	meter=ProgressBar.new();meter.max_value=C.INSTITUTION_GAMES[id].steps;meter.custom_minimum_size.y=24;meter.show_percentage=false;col.add_child(meter)
	match id:
		"mill":board=MillBoard.new()
		"honey":board=HoneyBoard.new()
		"civic":board=CivicBoard.new()
		"community":board=CommunityBoard.new()
	board.game=self;board.size_flags_vertical=Control.SIZE_EXPAND_FILL;board.custom_minimum_size=Vector2(280,380);col.add_child(board)
	start_button=UI.button(COPY[id][1],begin,true);col.add_child(start_button)
	collect_button=UI.button(COPY[id][2],collect,true);collect_button.visible=false;col.add_child(collect_button)
	exit_button=UI.button("先放下，回屋里",cancel);col.add_child(exit_button)
	start_button.grab_focus()
func begin() -> void:
	var result:Dictionary=ui.state.act("institution_begin",{"game":game_id})
	message.text=result.message
	if not result.ok:return
	run_id=str(ui.state.data.village.active_institution.run);start_button.visible=false;board.refresh()
func expected_index() -> int:
	if game_id=="mill":return progress%4
	if game_id=="honey":return int(HONEY_SEQUENCE[mini(progress,5)])
	if game_id=="community":return mini(progress,2)
	return int(CIVIC_SEQUENCE[mini(progress,2)])
func step(index:int) -> void:
	if run_id.is_empty() or finished:return
	if index!=expected_index():message.text="看看当前这张卡，再放进对应的格子。" if game_id=="civic" else "顺着亮起的那一处继续。";return
	var result:Dictionary=ui.state.act("institution_step",{"run":run_id,"step":progress})
	if not result.ok:message.text=result.message;return
	progress+=1;meter.value=progress;board.refresh()
	message.text=("第 %d 圈 · 顺着亮起的位置继续推"%mini(3,progress/4+1)) if game_id=="mill" else (("已压好 %d / 6 块蜜脾，蜜罐慢慢满起来了。"%progress) if game_id=="honey" else "这张归好类了，再看看下一张。")
	if game_id=="community":message.text=["食材摆好了。","楼卜洗净了，再切好海椒。","海椒切成细丁了，一起拌匀吧。","一碗共桌菜拌好了。"][progress]
	if progress>=int(C.INSTITUTION_GAMES[game_id].steps):message.text=COPY[game_id][3];collect_button.visible=true;collect_button.grab_focus()
func collect() -> void:
	if finished:return
	var result:Dictionary=ui.state.act("institution_complete",{"run":run_id})
	message.text=result.message
	if not result.ok:return
	finished=true;collect_button.visible=false;exit_button.text="回屋里";exit_button.grab_focus();board.refresh()
func cancel() -> void:
	if not run_id.is_empty() and not finished:
		var result:Dictionary=ui.state.act("institution_cancel",{"run":run_id})
		if not result.ok and not ui.state.data.village.active_institution.is_empty():message.text=result.message;return
	ui.opened=false;ui.home.ui.visible=true;ui.home.cooldown=.8;ui.institution_game=null;queue_free()
class MillBoard extends Control:
	var game
	var pushes:Array[Button]=[]
	var angle:=0.0
	func _ready() -> void:
		texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		for n in 4:
			var b:=UI.button("推",func():game.step(n),true);b.custom_minimum_size=Vector2(56,56);b.size=Vector2(56,56);add_child(b);pushes.append(b)
		resized.connect(refresh);refresh()
	func refresh() -> void:
		if pushes.is_empty():return
		var center:=pivot();var radius:=minf(size.x*.38,158)
		for n in 4:
			pushes[n].position=(center+Vector2(cos(n*PI*.5)*radius,sin(n*PI*.5)*72)-Vector2(28,28)).round()
			pushes[n].visible=not game.run_id.is_empty() and game.progress<int(C.INSTITUTION_GAMES[game.game_id].steps) and n==game.progress%4
		create_tween().tween_property(self,"angle",game.progress*PI*.5,.25)
		queue_redraw()
	func _process(_dt:float) -> void:queue_redraw()
	func pivot() -> Vector2:return Vector2(size.x*.5,110)
	func _draw() -> void:
		var axis:=pivot();var scale_factor:=1.55
		var origin:=axis-Vector2(80,43)*scale_factor
		var tex:=Assets.texture("res://ayu_home/v4/assets/institutions/mill-v2.png")
		draw_texture_rect_region(tex,Rect2(origin,Vector2(155,180)*scale_factor),Rect2(188,68,155,180))
		var rod:=Assets.texture("res://ayu_home/v4/assets/institutions/mill-rod-v1.png")
		# 只绕磨盘枢轴转透明木杆；透视缩短纵向，底图始终不动。
		var transform:=Transform2D(Vector2(cos(angle),sin(angle)*.55)*scale_factor,Vector2(-sin(angle),cos(angle)*.55)*scale_factor,axis)
		draw_set_transform_matrix(transform);draw_texture(rod,Vector2(-6,-17));draw_set_transform(Vector2.ZERO)
		var fill:=float(game.progress)/float(C.INSTITUTION_GAMES[game.game_id].steps)
		var trough:=origin+Vector2(51,143)*scale_factor
		if fill>0:draw_rect(Rect2(trough-Vector2(0,fill*15),Vector2(61*scale_factor,fill*15)),Color("f2dfb2"))
		if not game.run_id.is_empty() and not game.finished and game.progress>0 and game.progress<12:
			var seconds:=Time.get_ticks_msec()/1000.0
			for n in 6:draw_rect(Rect2((origin+Vector2(78+n%2,106+fmod(seconds*25+n*7,36))*scale_factor).round(),Vector2(3,4)),Color("f8dfb0"))

class HoneyBoard extends Control:
	var game
	var cells:Array[Button]=[]
	var elapsed:=0.0
	var jar_art:HoneyJar
	func _ready() -> void:
		texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		for n in 6:
			var b:=UI.button("压蜜",func():game.step(n),true);b.custom_minimum_size=Vector2(96,78);b.size=Vector2(96,78);add_child(b);cells.append(b)
		jar_art=HoneyJar.new();jar_art.size=Vector2(84,78);add_child(jar_art)
		resized.connect(refresh);refresh()
	func refresh() -> void:
		if cells.is_empty():return
		jar_art.position=Vector2(size.x*.5-42,280);jar_art.update_state(game.progress,game.finished)
		for n in 6:
			var done:bool=game.HONEY_SEQUENCE.find(n)<game.progress
			cells[n].position=Vector2(size.x*.5-164+(n%3)*116,58+(n/3)*98)
			cells[n].text="压好了" if done else "压蜜"
			cells[n].disabled=game.run_id.is_empty() or done or n!=game.expected_index() or game.finished
		queue_redraw()
	func _process(dt:float) -> void:elapsed+=dt;queue_redraw()
	func _draw() -> void:
		for n in 6:
			var corner:=Vector2(size.x*.5-164+(n%3)*116,20+(n/3)*98)
			for i in 5:
				var c:=corner+Vector2(9+i*17,16);var points:=PackedVector2Array([c+Vector2(-7,-5),c+Vector2(0,-9),c+Vector2(7,-5),c+Vector2(7,5),c+Vector2(0,9),c+Vector2(-7,5)])
				draw_colored_polygon(points,Color("8e542d") if game.HONEY_SEQUENCE.find(n)<game.progress else Color("e3a43b"))
		var jar:=Vector2(size.x*.5-42,280)
		if game.progress>0 and game.progress<6 and not game.run_id.is_empty():
			for n in 4:draw_rect(Rect2(jar+Vector2(40,-33+fmod(elapsed*35+n*9,38)),Vector2(5,7)),Color("ffd665"))


class HoneyJar extends Control:
	const TEXTURE_PATH="res://ayu_home/v4/assets/institutions/honey-jar-v3.png"
	const FRAME=Rect2(77,87,796,693)
	const FILL=Rect2(909,304,548,432)
	const SEAL=Rect2(347,847,842,88)
	var progress:=0
	var sealed:=false
	func _ready() -> void:
		mouse_filter=Control.MOUSE_FILTER_IGNORE
		texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		texture_repeat=CanvasItem.TEXTURE_REPEAT_DISABLED
		var shader:=Shader.new()
		shader.code="shader_type canvas_item; render_mode unshaded; void fragment(){if(COLOR.a<=0.8){discard;} COLOR.a=1.0;}"
		var alpha_material:=ShaderMaterial.new();alpha_material.shader=shader;material=alpha_material
	func update_state(step:int,finished:bool) -> void:
		progress=clampi(step,0,6);sealed=finished;queue_redraw()
	static func layers_for_state(step:int,finished:bool) -> Array[Dictionary]:
		# Match the reviewed four-state preview: preserve each sprite's aspect
		# ratio and the jar/honey bottom anchors; only the honey is revealed.
		var layers:Array[Dictionary]=[]
		var fill_ratio:=clampf(step/6.0,0.0,1.0)
		var fill_size:Vector2=FILL.size*(66.0/FILL.size.x)
		if fill_ratio>0.0:
			var shown_height:=fill_size.y*fill_ratio
			layers.append({"kind":"honey","source":Rect2(FILL.position+Vector2(0,FILL.size.y*(1.0-fill_ratio)),Vector2(FILL.size.x,FILL.size.y*fill_ratio)),"target":Rect2(Vector2(9,68-shown_height),Vector2(fill_size.x,shown_height))})
		var frame_size:Vector2=FRAME.size*(84.0/FRAME.size.x)
		layers.append({"kind":"frame","source":FRAME,"target":Rect2(Vector2(0,78-frame_size.y),frame_size)})
		if finished and step>=6:
			var seal_size:Vector2=SEAL.size*(64.0/SEAL.size.x)
			layers.append({"kind":"seal","source":SEAL,"target":Rect2(Vector2(10,7),seal_size)})
		return layers
	func _draw() -> void:
		var texture:=Assets.texture(TEXTURE_PATH)
		if texture==null:return
		for layer in layers_for_state(progress,sealed):
			draw_texture_rect_region(texture,layer.target,layer.source)

class CivicBoard extends Control:
	var game
	var card:Label
	var bins:Array[Button]=[]
	const TITLES=["灌渠","修桥","补路"]
	const CARDS=["小桥的木板松了\n请把这张卡交到修桥格","菜地渠口堵住了\n请把这张卡交到灌渠格","村口路面有个小坑\n请把这张卡交到补路格"]
	func _ready() -> void:
		texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		card=UI.paragraph("等你把事务卡摊开",24);card.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;add_child(card)
		for n in 3:
			var b:=UI.button(TITLES[n],func():game.step(n),true);b.custom_minimum_size=Vector2(124,74);b.size=Vector2(124,74);add_child(b);bins.append(b)
		resized.connect(refresh);refresh()
	func refresh() -> void:
		if bins.is_empty():return
		card.position=Vector2(20,60);card.size=Vector2(size.x-40,100)
		card.text="三张事务卡都收好了" if game.progress>=3 else (CARDS[game.progress] if not game.run_id.is_empty() else "等你把事务卡摊开")
		for n in 3:
			bins[n].position=Vector2(size.x*.5-198+n*136,245);bins[n].disabled=game.run_id.is_empty() or game.progress>=3
			bins[n].text=TITLES[n]+(" · 已收" if game.CIVIC_SEQUENCE.find(n)<game.progress else "")
		queue_redraw()
	func _draw() -> void:
		draw_rect(Rect2(12,20,size.x-24,196),Color("75513b"));draw_rect(Rect2(18,26,size.x-36,184),Color("e8d6aa"))
		var ink:=Color("668367")
		for n in 3:
			var p:=Vector2(size.x*.5-150+n*136,335)
			if game.CIVIC_SEQUENCE.find(n)<game.progress:
				draw_rect(Rect2(p,Vector2(30,20)),Color("ebd5a2"));draw_line(p+Vector2(5,10),p+Vector2(13,15),ink,3);draw_line(p+Vector2(13,15),p+Vector2(25,4),ink,3)

class CommunityBoard extends Control:
	var game
	var steps:Array[Button]=[]
	var elapsed:=0.0
	var ingredients:CommunityIngredients
	const LABELS=["洗楼卜","切海椒","拌匀"]
	func _ready() -> void:
		texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		ingredients=CommunityIngredients.new();ingredients.board=self;add_child(ingredients)
		for n in 3:
			var b:=UI.button(LABELS[n],func():game.step(n),true);b.custom_minimum_size=Vector2(124,72);b.size=Vector2(124,72);add_child(b);steps.append(b)
		resized.connect(refresh);refresh()
	func refresh() -> void:
		if ingredients!=null:
			ingredients.position=Vector2(size.x*.5-144,86)
			ingredients.visible=game.progress<3
			ingredients.queue_redraw()
		for n in steps.size():
			steps[n].position=Vector2(size.x*.5-198+n*136,296);steps[n].disabled=game.run_id.is_empty() or game.progress!=n or game.finished;steps[n].text="做好了" if game.progress>n else LABELS[n]
		queue_redraw()
	func _process(dt:float) -> void:
		elapsed+=dt;queue_redraw()
		if ingredients!=null:ingredients.queue_redraw()
	func _draw() -> void:
		var c:=Vector2(size.x*.5,140)
		draw_rect(Rect2(c+Vector2(-177,-105),Vector2(354,232)),Color("68482f"));draw_rect(Rect2(c+Vector2(-171,-99),Vector2(342,220)),Color("b78350"))
		for n in 7:draw_rect(Rect2(c+Vector2(-165,-91+n*32),Vector2(330,3)),Color("a47043"))
		if game.progress>=3:
			# 复用阿鱼家已有透明餐盘，按原像素整数倍显示成品菜。
			var meal:=Assets.texture("res://ayu_home/v4/assets/floor1-redraw/meal-14.png")
			var meal_size:Vector2=meal.get_size()*6.0
			draw_texture_rect(meal,Rect2((c+Vector2(0,8)-meal_size*.5).round(),meal_size),false)
			for n in 4:draw_rect(Rect2((c+Vector2(-55+n*35,-68-fmod(elapsed*15+n*7,28))).round(),Vector2(4,8)),Color("ead9b0"))

class CommunityIngredients extends Control:
	const TEXTURE_PATH="res://ayu_home/v4/assets/institutions/community-prep-v2.png"
	# Reviewed source partitions and bottom-aligned targets, in a 264 x 120 canvas.
	const STAGES=[
		[
			[Rect2(43,33,523,304),Rect2(4.0,21.265774378585093,125.0,72.65774378585085)],
			[Rect2(43,337,518,84),Rect2(4.0,93.92351816443595,123.80497131931166,20.076481835564053)],
			[Rect2(561,172,307,59),Rect2(175.0,41.814332247557005,79.0,15.182410423452769)],
			[Rect2(566,231,302,56),Rect2(176.28664495114006,56.99674267100977,77.71335504885994,14.410423452768729)],
			[Rect2(561,287,307,115),Rect2(175.0,71.4071661237785,79.0,29.592833876221498)],
		],
		[
			[Rect2(972,33,524,303),Rect2(4.0,21.44274809160305,125.0,72.28053435114504)],
			[Rect2(972,336,518,85),Rect2(4.0,93.72328244274809,123.56870229007635,20.27671755725191)],
			[Rect2(1490,172,307,60),Rect2(175.0,41.814332247557005,79.0,15.439739413680782)],
			[Rect2(1496,232,301,53),Rect2(176.54397394136808,57.25407166123779,77.45602605863192,13.63843648208469)],
			[Rect2(1490,285,307,117),Rect2(175.0,70.89250814332247,79.0,30.107491856677523)],
		],
		[
			[Rect2(456,451,516,375),Rect2(4.0,23.156976744186053,125.0,90.84302325581395)],
			[Rect2(981,568,428,241),Rect2(166.0,36.82710280373832,82.0,46.17289719626168)],
		],
	]
	var board
	func _ready() -> void:
		mouse_filter=Control.MOUSE_FILTER_IGNORE
		texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		texture_repeat=CanvasItem.TEXTURE_REPEAT_DISABLED
		var shader:=Shader.new()
		shader.code="shader_type canvas_item; render_mode unshaded; void fragment(){if(COLOR.a<=0.8){discard;} COLOR.a=1.0;}"
		var alpha_material:=ShaderMaterial.new();alpha_material.shader=shader;material=alpha_material
	func _draw() -> void:
		if board==null or board.game.progress>=3:return
		var texture:=Assets.texture(TEXTURE_PATH)
		if texture==null:return
		for part in STAGES[clampi(board.game.progress,0,2)]:
			# Clip UVs to each source region; no antialiased polygon edge or global render changes.
			draw_texture_rect_region(texture,part[1],part[0],Color.WHITE,false,true)
		if board.game.progress==1:
			var c:=Vector2(144,54)
			var elapsed:float=board.elapsed
			for n in 8:draw_rect(Rect2((c+Vector2(-132+n*13,-33+sin(elapsed*4+n)*5)).round(),Vector2(4,4)),Color("cee6d3"))
