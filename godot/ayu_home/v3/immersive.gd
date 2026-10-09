extends CanvasLayer
## Full-screen one-finger activities. Simulation stays independent from render/UI.
signal closed
signal completed(kind:String)
const UI=preload("res://ayu_home/v3/pixel_ui.gd")
const Assets=preload("res://ayu_home/v2/assets.gd")
const P="res://ayu_home/v3/assets/"
var root:Control
var canvas:Control
var status:Label
var kind:=""
var context:Dictionary={}
var elapsed:=0.0
var fish:Array=[]
var food:Array=[]
var ripples:Array=[]
var eaten:=0
var dropped:=0
var finished:=false
var channel:=0
var power:=true
var pet_count:=0
var detail_lamp:=true
var camera_offset:=Vector2.ZERO
var drag_start:=Vector2.ZERO
var dragged:=false
var last_tap_frame:=-1
var active_point:=Vector2.ZERO
var reaction_until:=0.0
var audio:AudioStreamPlayer
var melody_step:=-1
var note_cache:Dictionary={}
var texture:Texture2D
var bottom:HBoxContainer
func _ready() -> void:
	layer=40;audio=AudioStreamPlayer.new();add_child(audio)
func open(which:String,data:Dictionary={}) -> void:
	close(false);kind=which;context=data;elapsed=0;fish.clear();food.clear();ripples.clear();eaten=0;dropped=0;finished=false;pet_count=0;power=true;channel=0;camera_offset=Vector2.ZERO;detail_lamp=true
	root=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.theme=UI.theme();add_child(root)
	canvas=Control.new();canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);canvas.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;canvas.draw.connect(draw_scene);canvas.gui_input.connect(input_scene);root.add_child(canvas)
	var head:=PanelContainer.new();head.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE);head.offset_left=14;head.offset_right=-14;head.offset_top=14;head.offset_bottom=91;root.add_child(head)
	var row:=HBoxContainer.new();head.add_child(row);var words:=VBoxContainer.new();words.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(words)
	var title:=UI.label({"fish":"鱼缸边的一点安静","tv":"一家人 · 看会儿电视","stars":"露台 · 看一会儿天空","pet":context.get("name","猫咪"),"detail":"阿鱼的书桌","room_detail":context.get("title","房间细看"),"rest":"在客房好好歇一会儿"}.get(kind,"慢慢待一会儿"),22);words.add_child(title)
	status=UI.label("",17);status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;words.add_child(status)
	var exit_button:=UI.button("起身" if kind in ["tv","rest"] else "离开",close);row.add_child(exit_button);exit_button.grab_focus()
	bottom=HBoxContainer.new();bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);bottom.offset_top=-80;bottom.offset_bottom=-24;bottom.offset_left=22;bottom.offset_right=-22;root.add_child(bottom)
	match kind:
		"fish":
			texture=Assets.texture(P+"aquarium.png");status.text="点水面投一小撮鱼食，鱼儿会自己游过来。"
			for i in 7:fish.append({"pos":Vector2(.18+i*.1,.30+fmod(i*.13,.38)),"dir":1.0,"phase":i*1.3,"fed":0})
			add_button("轻轻投食",func():drop_food(Vector2(.5,.24)*canvas.size));add_button("听听水声",func():play_note(4))
		"tv":texture=Assets.texture(P+"tv-room.png");status.text="从沙发后面，看一个家的小节目。";add_button("换台",func():channel=(channel+1)%3;status.text=["小院的一天","猫咪日记","雨落在花园"][channel]);add_button("关电视",func():power=not power)
		"pet":texture=Assets.texture(P+str(context.pet)+".png");status.text="轻轻摸摸它，别吵醒睡得香的时候。";add_button("摸摸头",pet_touch);add_button("躺一会儿",func():pet_count=0)
		"stars":status.text="天空跟着家里的时间变化。点亮一颗星，连成小小的星座。";add_button("找下一颗星",star_touch)
		"detail":texture=Assets.texture(P+"study-detail.png");status.text="点台灯、电脑、书架和地毯上的猫。";add_button("台灯",func():detail_lamp=not detail_lamp);add_button("原创音乐",func():power=not power;play_note(0))
		"room_detail","rest":
			texture=Assets.texture(P+str(context.cfg.background));status.text="拖动画面细看 · 直接点物件" if kind=="room_detail" else "慢慢呼吸。歇好了点「起身」，家里的时间照常走。"
			if kind=="rest":add_button("深呼吸",func():pet_count+=1;status.text="吸气… 呼气…";finish("rest") if pet_count>=4 else play_note(0))
	set_process(true)
func add_button(copy:String,call:Callable) -> void:
	var b:=UI.button(copy,call);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;bottom.add_child(b)
func close(emit:=true) -> void:
	if audio:audio.stop();audio.stream=null
	if root:remove_child(root);root.queue_free();root=null;canvas=null
	set_process(false)
	if emit:closed.emit()
func finish(which:String) -> void:
	if finished:return
	finished=true;completed.emit(which)
func drop_food(at:Vector2) -> void:
	if food.size()>24:return
	var p:=at/canvas.size;p.y=clampf(p.y,.16,.60)
	for i in 3:food.append({"pos":p+Vector2((i-1)*.012,0),"age":0.0})
	ripples.append({"pos":p,"age":0.0});dropped+=3;play_note(4)
func pet_touch() -> void:
	pet_count+=1;reaction_until=elapsed+3;status.text=str(context.get("name","它"))+"眯起眼睛，发出轻轻的呼噜声。";play_note(1)
	if pet_count>=4:finish("pet")
func star_touch() -> void:
	pet_count=min(pet_count+1,7);play_note(pet_count%4)
	if pet_count==7:status.text="七颗星，连成今晚的小路。";finish("stars")
func input_scene(e:InputEvent) -> void:
	if e is InputEventMouseButton:
		if e.pressed:
			drag_start=e.position;dragged=false
			if kind!="room_detail":tap(e.position)
		elif not dragged and kind=="room_detail":tap(e.position)
	elif e is InputEventMouseMotion and e.button_mask&MOUSE_BUTTON_MASK_LEFT:
		if kind=="room_detail":camera_offset+=e.relative;dragged=drag_start.distance_to(e.position)>8
	elif e is InputEventScreenTouch and e.pressed:tap(e.position)
func tap(p:Vector2) -> void:
	if Engine.get_process_frames()==last_tap_frame:return
	last_tap_frame=Engine.get_process_frames()
	if p.y<102 or p.y>canvas.size.y-90:return
	match kind:
		"fish":drop_food(p)
		"pet":pet_touch()
		"stars":star_touch()
		"tv":channel=(channel+1)%3;status.text=["小院的一天","猫咪日记","雨落在花园"][channel]
		"detail":
			var n:=p/canvas.size;active_point=p;reaction_until=elapsed+4
			if n.y<.39:status.text="书架上的摆件还在原来的位置。"
			elif n.x<.28 and n.y<.57:detail_lamp=not detail_lamp;status.text="台灯亮起来了。" if detail_lamp else "关好台灯。"
			elif n.y<.65:status.text="三块屏幕轻轻闪动，按下键盘又写了一行。";play_note(2)
			else:status.text="地毯上的猫翻了个身。";pet_count+=1
		"room_detail":
			var cfg:Dictionary=context.cfg;var transform:=detail_transform();var local:Vector2=(p-transform.position)/transform.size.x
			for h in cfg.hotspots:
				if local.distance_to(Vector2(h.pos[0],h.pos[1]))<40:
					active_point=p;reaction_until=elapsed+3;status.text=h.get("copy",h.label)
					if status.text.is_empty():status.text=h.label+" · 回到走动层就能玩。"
					play_note(1);break
func _process(dt:float) -> void:
	if not root:return
	elapsed+=dt
	if kind=="fish":
		for f in food:f.age+=dt;f.pos.y+=dt*.022
		for i in fish.size():
			var f:Dictionary=fish[i];var destination:=Vector2(.5+sin(elapsed*.25+f.phase)*.34,.46+sin(elapsed*.36+f.phase)*.19);var closest:=-1;var distance:=INF
			for j in food.size():
				var d:float=f.pos.distance_squared_to(food[j].pos)
				if d<distance:distance=d;closest=j
			if closest>=0:destination=food[closest].pos
			var diff:Vector2=destination-f.pos
			f.dir=1.0 if diff.x>=0 else -1.0;f.pos=f.pos.move_toward(destination,dt*(.14 if closest>=0 else .045))
			if closest>=0 and f.pos.distance_to(destination)<.014:
				food.remove_at(closest);eaten+=1;f.fed+=1;ripples.append({"pos":f.pos,"age":0.0})
				status.text="吃到了 %d 小粒 · %d 条小鱼吃过饭"%[eaten,fish.filter(func(x):return x.fed>0).size()]
				if eaten>=12:status.text="鱼儿吃饱了，慢慢看它们游一会儿。";finish("fish")
		food=food.filter(func(f):return f.pos.y<.82 and f.age<22)
	for r in ripples:r.age+=dt
	ripples=ripples.filter(func(r):return r.age<1.8)
	if kind=="tv" and power and int(elapsed*2)!=melody_step:
		melody_step=int(elapsed*2)
		if melody_step%3==0:play_note([0,2,1,3,2,0,1,2][(melody_step/3)%8])
		if elapsed>20:finish("tv")
	canvas.queue_redraw()
func draw_scene() -> void:
	if not canvas:return
	var s:=canvas.size
	canvas.draw_rect(Rect2(Vector2.ZERO,s),Color("4d4e3b"))
	if kind in ["fish","tv","detail"] and texture:canvas.draw_texture_rect(texture,Rect2(Vector2.ZERO,s),false)
	match kind:
		"fish":draw_aquarium(s)
		"tv":draw_tv(s)
		"pet":draw_pet(s)
		"stars":draw_stars(s)
		"detail":draw_desk(s)
		"room_detail","rest":draw_detail(s)
	if reaction_until>elapsed and kind in ["detail","room_detail"]:
		for i in 8:
			var p:=active_point+Vector2(sin(i*2+elapsed)*23,-fmod(elapsed*24+i*8,60));canvas.draw_rect(Rect2(p,Vector2(4,4)),Color("ffe8a7"))
func draw_aquarium(s:Vector2) -> void:
	for i in 26:
		var p:=Vector2(fposmod(i*37+sin(elapsed+i)*7,s.x),s.y-fposmod(elapsed*(20+i%3*8)+i*63,s.y))
		canvas.draw_arc(p,2+i%3,0,TAU,8,Color(.8,.98,1,.43),1)
	for r in ripples:canvas.draw_arc(r.pos*s,8+r.age*23,0,TAU,18,Color(.84,1,1,1-r.age/1.8),2)
	for f in food:canvas.draw_rect(Rect2((f.pos*s).round(),Vector2(4,5)),Color("ddb66c"))
	for i in fish.size():
		var f:Dictionary=fish[i];var p:Vector2=(f.pos*s).round();var d:float=f.dir;var tail:=sin(elapsed*8+f.phase)*3;var colors:=[Color("edac51"),Color("ea815c"),Color("abd9db"),Color("f4ca67")]
		var color:Color=colors[i%4];var body:=PackedVector2Array([p+Vector2(-17*d,0),p+Vector2(-10*d,-9),p+Vector2(9*d,-8),p+Vector2(17*d,0),p+Vector2(9*d,8),p+Vector2(-10*d,7)])
		canvas.draw_colored_polygon(PackedVector2Array([p+Vector2(-13*d,0),p+Vector2(-27*d,-9+tail),p+Vector2(-26*d,10+tail)]),color.darkened(.13));canvas.draw_colored_polygon(body,color)
		canvas.draw_rect(Rect2(p+Vector2(7*d-2,-5),Vector2(5,5)),Color("fff8d8"));canvas.draw_rect(Rect2(p+Vector2(9*d-1,-4),Vector2(2,3)),Color("263b3b"))
		canvas.draw_line(p+Vector2(-6,-5),p+Vector2(-6,5),color.lightened(.3),2)
		if f.fed>0 and fmod(elapsed,4)<.5:canvas.draw_rect(Rect2(p+Vector2(16,-15),Vector2(3,3)),Color("fff5a0"))
func draw_tv(s:Vector2) -> void:
	var tv:=Rect2(s*Vector2(.235,.197),s*Vector2(.527,.16))
	if power:
		var tex:Texture2D=Assets.texture(P+("approved-0.png" if channel==0 else "garden.png"))
		var source:=Rect2(Vector2(80+sin(elapsed*.13)*70,150),Vector2(1190,660))
		canvas.draw_texture_rect_region(tex,tv,source)
		if channel==1:
			for i in 3:
				var pet:Texture2D=Assets.texture(P+["qiuqiu","luoluo","tiantian"][i]+".png");canvas.draw_texture_rect_region(pet,Rect2(tv.position+Vector2(28+i*74,25+sin(elapsed+i)*5),Vector2(68,68)),Rect2((1+int(elapsed*4)%2)*64,0,64,64))
		if channel==2:
			for i in 25:
				var p:=tv.position+Vector2(fposmod(i*29+elapsed*12,tv.size.x),fposmod(i*39+elapsed*55,tv.size.y));canvas.draw_line(p,p+Vector2(-2,8),Color(.7,.89,1,.7),1)
		canvas.draw_rect(tv,Color(.45,.7,.9,.05+.04*sin(elapsed*2)))
	else:canvas.draw_rect(tv,Color("18202a"))
	# The three family sprites face AWAY from the camera; sofa back occludes legs.
	for i in 3:
		var id:String=["father","ayu","mother"][i];var tex:Texture2D=Assets.texture("res://ayu_home/v2/assets/chr_"+id+".png")
		var frame:=26+int(elapsed*.8)%2;var region:=Rect2((frame%16)*64,(frame/16)*84,64,66)
		canvas.draw_texture_rect_region(tex,Rect2(Vector2(s.x*(.26+i*.24)-48,s.y*.645),Vector2(96,99)),region)
	# Actual original sofa texture masks lower sprite edge, preserving visible back support.
	if texture:canvas.draw_texture_rect_region(texture,Rect2(0,s.y*.747,s.x,s.y*.253),Rect2(0,texture.get_height()*.747,texture.get_width(),texture.get_height()*.253))
func draw_pet(s:Vector2) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO,s),Color("d9cba9"))
	for y in range(0,int(s.y),36):canvas.draw_line(Vector2(0,y),Vector2(s.x,y),Color("baa180"),2)
	canvas.draw_style_box(UI.box(Color("f1dbb9")),Rect2(s*.14,s*Vector2(.72,.66)))
	var col:=3 if pet_count==0 else (0 if pet_count%3 else 1)
	canvas.draw_texture_rect_region(texture,Rect2(s*Vector2(.10,.25),Vector2(s.x*.8,s.x*.8)),Rect2(col*64,0,64,64))
	if reaction_until>elapsed:
		for i in 5:
			var p:=s*Vector2(.2+i*.15,.28)+Vector2(0,-fposmod(elapsed*25+i*11,50));canvas.draw_string(UI.FONT,p,"♥",HORIZONTAL_ALIGNMENT_CENTER,40,24,Color("b66c62"))
func draw_stars(s:Vector2) -> void:
	var h:float=context.get("hour",12.0);var night:bool=h<6 or h>=18
	canvas.draw_rect(Rect2(Vector2.ZERO,s),Color("1c2849") if night else Color("94cfd7"))
	for i in 90:
		var p:=Vector2(fmod(i*73.0,s.x),fmod(i*117.0,s.y*.70));canvas.draw_rect(Rect2(p,Vector2(2,2)),Color(1,.91,.67,.4+.3*sin(elapsed+i)) if night else Color(1,1,1,.24))
	var points:Array=[Vector2(.2,.3),Vector2(.32,.38),Vector2(.47,.31),Vector2(.6,.42),Vector2(.76,.32),Vector2(.67,.52),Vector2(.43,.55)]
	for i in pet_count:
		var p:Vector2=points[i]*s;canvas.draw_circle(p,4,Color("ffe4a1"))
		if i>0:canvas.draw_line(points[i-1]*s,p,Color("edcc8f"),2)
	var ext:Texture2D=Assets.texture(P+"approved-0.png");canvas.draw_texture_rect_region(ext,Rect2(0,s.y*.73,s.x,s.y*.27),Rect2(0,0,1448,550),Color(.38,.44,.6) if night else Color.WHITE)
func draw_desk(s:Vector2) -> void:
	var night:bool=float(context.get("hour",12.0))>=18 or float(context.get("hour",12.0))<6
	if not night:canvas.draw_rect(Rect2(Vector2.ZERO,s),Color(1,.89,.62,.10))
	if not detail_lamp:canvas.draw_rect(Rect2(Vector2.ZERO,s),Color(.05,.05,.13,.36))
	for i in 3:
		var rect:=Rect2(s*Vector2(.314+i*.211,.365),s*Vector2(.15,.052));canvas.draw_rect(rect,Color(.3,.6,1,.06+.05*sin(elapsed*3+i)))
	if pet_count>0:
		var cat:Texture2D=Assets.texture(P+"tiantian.png");canvas.draw_texture_rect_region(cat,Rect2(s*Vector2(.13,.68),Vector2(96,96)),Rect2((1+int(elapsed*3)%2)*64,0,64,64))
	for i in 15:
		var p:=Vector2(fposmod(i*43+elapsed*2,s.x),fposmod(i*83-elapsed*5,s.y));canvas.draw_rect(Rect2(p,Vector2(2,2)),Color(1,.89,.54,.3))
func detail_transform() -> Rect2:
	var sz:=texture.get_size();var scale:float=maxf(canvas.size.x/sz.x,canvas.size.y/sz.y)
	var p:Vector2=(canvas.size-sz*scale)*.5+camera_offset;p=p.clamp(canvas.size-sz*scale,Vector2.ZERO)
	return Rect2(p,Vector2(scale,scale))
func draw_detail(s:Vector2) -> void:
	var cfg:Dictionary=context.cfg;var transform:=detail_transform();var sc:=transform.size.x;var offset:=transform.position
	canvas.draw_texture_rect(texture,Rect2(offset,texture.get_size()*sc),false)
	for p in cfg.props:
		var tex:Texture2D=Assets.texture(P+p.file);canvas.draw_texture_rect(tex,Rect2(offset+Vector2(p.pos[0],p.pos[1])*sc,tex.get_size()*sc),false)
	if kind=="rest":
		canvas.draw_rect(Rect2(Vector2.ZERO,s),Color(.14,.12,.18,.30));canvas.draw_string(UI.FONT,s*.5,"…",HORIZONTAL_ALIGNMENT_CENTER,100,30,Color("fff1d1"))
	else:
		for h in cfg.hotspots:
			var p:Vector2=offset+Vector2(h.pos[0],h.pos[1])*sc;canvas.draw_circle(p,5,Color("fff0ba"))
func play_note(index:int) -> void:
	if not note_cache.has(index):
		var w:=AudioStreamWAV.new();w.mix_rate=22050;w.format=AudioStreamWAV.FORMAT_16_BITS;var data:=PackedByteArray();data.resize(11024)
		var hz:float=[261.63,329.63,392.0,440.0,784.0][index%5]
		for i in 5512:
			var t:=float(i)/22050;data.encode_s16(i*2,int((sin(TAU*hz*t)+.17*sin(TAU*hz*2*t))*exp(-t*17)*minf(t*160,1)*5000))
		w.data=data;note_cache[index]=w
	audio.stream=note_cache[index];audio.volume_db=-12;audio.play()
