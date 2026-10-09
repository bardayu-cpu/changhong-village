extends Control
## 原生像素院子：三块地、家具点击/拖动；不依赖额外远程贴图。
signal cell_pressed(x:int,y:int)
signal furniture_selected(id:int)
signal dropped(id:int,x:int,y:int)
const C=preload("res://ayu_home/v4/core/config.gd")
const UI=preload("res://ayu_home/v4/pixel_ui.gd")
var state
var selected:=-1
var dragging:=-1
var origin:=Vector2.ZERO
func _ready() -> void:
	custom_minimum_size=Vector2(0,540);mouse_filter=Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
func cell_rect(x:int,y:int) -> Rect2:
	var w:float=(size.x-32)/4;var h:float=(size.y-42)/9
	return Rect2(16+x*w,24+y*h,w,h)
func cell_at(p:Vector2) -> Vector2i:
	var w:float=(size.x-32)/4;var h:float=(size.y-42)/9
	return Vector2i(int(floor((p.x-16)/w)),int(floor((p.y-24)/h)))
func furniture_at(c:Vector2i) -> int:
	for f in state.data.village.furniture:
		if int(f.x)==c.x and int(f.y)==c.y:return int(f.id)
	return -1
func _gui_input(e:InputEvent) -> void:
	var press:=false;var release:=false;var p:=Vector2.ZERO
	if e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_LEFT:press=e.pressed;release=not e.pressed;p=e.position
	elif e is InputEventScreenTouch:press=e.pressed;release=not e.pressed;p=e.position
	else:return
	if press:origin=p;dragging=furniture_at(cell_at(p))
	if release:
		var c:=cell_at(p)
		if dragging>=0 and origin.distance_to(p)>12:dropped.emit(dragging,c.x,c.y)
		elif furniture_at(c)>=0:furniture_selected.emit(furniture_at(c))
		else:cell_pressed.emit(c.x,c.y)
		dragging=-1
	accept_event()
func _can_drop_data(_p:Vector2,data:Variant) -> bool:return data is Dictionary and data.has("furniture")
func _drop_data(p:Vector2,data:Variant) -> void:
	var c:=cell_at(p);dropped.emit(int(data.furniture),c.x,c.y)
func _draw() -> void:
	if state==null or state.data.is_empty():return
	var v:Dictionary=state.data.village
	var ground:Color={"lake":Color("8fbbac"),"bamboo":Color("79945c"),"hill":Color("aeac73"),"garden":Color("a4b67a")}.get(v.location,Color("a4b67a"))
	draw_rect(Rect2(Vector2.ZERO,size),ground)
	for n in range(120):
		var p:=Vector2(posmod(n*73+19,int(size.x)),posmod(n*109+31,int(size.y)))
		draw_rect(Rect2(p,Vector2(4,3)),ground.darkened(.10))
	for y in 9:
		for x in 4:
			var r:=cell_rect(x,y).grow(-2);var ready:bool=float(v.land[y/3])>0 and state.remaining(v.land[y/3])==0
			draw_rect(r,Color("d4b27a") if ready else Color("788050"))
			draw_rect(Rect2(r.position,Vector2(r.size.x,4)),Color("a38259") if ready else Color("5c6945"))
			if not ready:
				var clearing:bool=float(v.land[y/3])>0
				var p:=r.get_center()+Vector2(sin(Time.get_ticks_msec()/70.0)*4,0) if clearing else r.get_center();draw_rect(Rect2(p-Vector2(9,1),Vector2(18,7)),Color("8c9481"));draw_rect(Rect2(p-Vector2(5,7),Vector2(10,8)),Color("b1b29a"))
				for i in 3:draw_rect(Rect2(r.position+Vector2(12+i*7,16-i%2*4),Vector2(3,12)),Color("a2ac62"))
	for f in v.furniture:
		if int(f.x)<0:continue
		var r:=cell_rect(f.x,f.y);var p:=r.get_center()
		if int(f.id)==selected:draw_rect(r.grow(-4),Color("f9e4a6"),false,3)
		draw_rect(Rect2(p+Vector2(-23,12),Vector2(46,8)),Color(.2,.2,.1,.25))
		preload("res://ayu_home/v4/core/furniture_draw.gd").paint(self,str(f.kind),Rect2(p-Vector2(30,32),Vector2(60,58)))

func _process(_delta:float) -> void:
	if state==null:return
	for due in state.data.village.land:
		if float(due)>0 and state.remaining(due)>0:queue_redraw();return
