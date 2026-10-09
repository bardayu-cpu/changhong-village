extends Control
signal collect_pet(id:String)
signal plot_pressed(index:int)
const C=preload("res://ayu_home/v4/core/config.gd")
const UI=preload("res://ayu_home/v4/pixel_ui.gd")
const Actor=preload("res://ayu_home/v4/actor.gd")
var state
var pets:Array=[]
var plots:Array=[]
var actors:Array=[]
func _ready() -> void:
	custom_minimum_size=Vector2(0,440)
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var i:=0
	for id in C.PETS:
		var b:=UI.button("",func():collect_pet.emit(id));add_child(b);pets.append(b)
		var a:=Actor.new();a.bubble_allowed=false;add_child(a);a.setup(id);a.set_process(false);actors.append(a);i+=1
	for n in 6:
		var b:=UI.button("",func():plot_pressed.emit(n));add_child(b);plots.append(b)
	resized.connect(refresh);refresh()
func refresh() -> void:
	var w:float=(size.x-32)/4
	for i in 4:
		var id:String=C.PETS.keys()[i];var left:int=state.remaining(state.data.village.animals[id].due)
		var b:Button=pets[i];b.position=Vector2(12+i*w,10);b.size=Vector2(w-4,48);b.text=C.PETS[id]
		var a=actors[i];a.position=Vector2(12+(i+.5)*w,128);a.modulate=Color.WHITE if left==0 else Color(.65,.65,.65,.7)
		b.tooltip_text="回来了，点一下收取" if left==0 else "还在外面，%d秒后回来"%left
	var cw:float=(size.x-24)/3
	for n in 6:
		var p:Dictionary=state.data.village.crops[n];var b:Button=plots[n]
		b.position=Vector2(10+(n%3)*cw,252+(n/3)*118);b.size=Vector2(cw-6,52)
		b.text="种这里" if p.is_empty() else ("收"+C.CROPS[p.crop].name if state.remaining(p.due)==0 else "%d:%02d"%[state.remaining(p.due)/60,state.remaining(p.due)%60])
	queue_redraw()
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("879a60"))
	for i in 65:draw_rect(Rect2(Vector2(posmod(i*79,int(size.x)),posmod(i*67,440)),Vector2(4,3)),Color("a5b774"))
	draw_rect(Rect2(0,147,size.x,28),Color("cfb98a"))
	for i in 4:
		var w:float=(size.x-32)/4;var id:String=C.PETS.keys()[i];var left:int=state.remaining(state.data.village.animals[id].due)
		var label:="可收取" if left==0 else "%d:%02d"%[left/60,left%60]
		draw_string(UI.FONT,Vector2(17+i*w,148),label,HORIZONTAL_ALIGNMENT_CENTER,w-8,24,Color("423827"))
	for n in 6:
		var cw:float=(size.x-24)/3;var p:=Vector2(12+(n%3)*cw,188+(n/3)*118);var plot:Dictionary=state.data.village.crops[n]
		draw_rect(Rect2(p,Vector2(cw-10,60)),Color("73513a"))
		for row in 4:draw_rect(Rect2(p+Vector2(4,6+row*13),Vector2(cw-18,3)),Color("956744"))
		if not plot.is_empty():
			var ready:bool=state.remaining(plot.due)==0
			for j in 3:
				var plant:=p+Vector2(15+j*(cw-34)/3,31)
				draw_rect(Rect2(plant+Vector2(4,-12),Vector2(4,22)),Color("5b873e"));draw_rect(Rect2(plant+Vector2(-3,-5),Vector2(18,5)),Color("91b658"))
				if ready:
					var color:Color={"radish":Color("efcaa7"),"pepper":Color("d86445"),"grain":Color("e5bb58")}[plot.crop]
					draw_rect(Rect2(plant+Vector2(0,4),Vector2(12,12)),color)

func _gui_input(e:InputEvent) -> void:
	var p:=Vector2.ZERO
	if e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_LEFT and not e.pressed:p=e.position
	elif e is InputEventScreenTouch and not e.pressed:p=e.position
	else:return
	if p.y>=58 and p.y<147:
		var i:=int((p.x-12)/((size.x-32)/4))
		if i>=0 and i<4:collect_pet.emit(C.PETS.keys()[i])
	elif p.y>=188 and p.y<422:
		var x:=int((p.x-10)/((size.x-24)/3));var y:=int((p.y-188)/118)
		if x>=0 and x<3 and y>=0 and y<2:plot_pressed.emit(y*3+x)
	accept_event()
