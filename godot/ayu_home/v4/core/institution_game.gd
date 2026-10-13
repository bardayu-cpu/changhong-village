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
func setup(owner,id:String) -> void:
	ui=owner;game_id=id;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);theme=UI.theme();mouse_filter=Control.MOUSE_FILTER_STOP
	var bg:=ColorRect.new();bg.color=UI.DEEP;bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(bg)
	var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(margin)
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,24)
	var col:=VBoxContainer.new();col.add_theme_constant_override("separation",14);margin.add_child(col)
	col.add_child(UI.label(str(C.INSTITUTION_GAMES[id].title),28))
	message=UI.paragraph("沿亮起的推杆位置慢慢推三圈。完成后用谷子 2 份换谷粉 1 份。",22);message.custom_minimum_size.y=78;col.add_child(message)
	meter=ProgressBar.new();meter.max_value=C.INSTITUTION_GAMES[id].steps;meter.custom_minimum_size.y=24;meter.show_percentage=false;col.add_child(meter)
	board=MillBoard.new();board.game=self;board.size_flags_vertical=Control.SIZE_EXPAND_FILL;board.custom_minimum_size=Vector2(280,380);col.add_child(board)
	start_button=UI.button("握住推杆",begin,true);col.add_child(start_button)
	collect_button=UI.button("收好谷粉",collect,true);collect_button.visible=false;col.add_child(collect_button)
	exit_button=UI.button("先放下，回磨坊",cancel);col.add_child(exit_button)
	start_button.grab_focus()
func begin() -> void:
	var result:Dictionary=ui.state.act("institution_begin",{"game":game_id})
	message.text=result.message
	if not result.ok:return
	run_id=str(ui.state.data.village.active_institution.run);start_button.visible=false;board.refresh()
func step(index:int) -> void:
	if run_id.is_empty() or finished or index!=progress%4:return
	var result:Dictionary=ui.state.act("institution_step",{"run":run_id,"step":progress})
	if not result.ok:message.text=result.message;return
	progress+=1;meter.value=progress;board.refresh()
	message.text="第 %d 圈 · 顺着亮起的位置继续推"%mini(3,progress/4+1)
	if progress>=int(C.INSTITUTION_GAMES[game_id].steps):message.text="谷粉落满了粉槽，可以收好这一份。";collect_button.visible=true;collect_button.grab_focus()
func collect() -> void:
	if finished:return
	var result:Dictionary=ui.state.act("institution_complete",{"run":run_id})
	message.text=result.message
	if not result.ok:return
	finished=true;collect_button.visible=false;exit_button.text="回磨坊";exit_button.grab_focus();board.refresh()
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
