extends Node2D
const Assets=preload("res://ayu_home/v2/assets.gd")
const Actor=preload("res://ayu_home/v4/actor.gd")
const Residents=preload("res://ayu_home/v4/core/residents.gd")
const UI=preload("res://ayu_home/v4/pixel_ui.gd")
var ui
var actor
var record:Dictionary={}
var slot_index:=-1
var elapsed:=0.0
var greet_after:=0.0
var changed_at:Dictionary={}
var settled:=false
var work_layer:Node2D
func setup(owner) -> void:
	ui=owner;record=ui.home.world.cfg.npc.duplicate(true);record.schedule=ui.home.world.cfg.resident.schedule
	actor=Actor.new();actor.look_override=Residents.look(str(record.id));ui.home.world.actors.add_child(actor);actor.setup("visitor")
	actor.set_meta("display_name",str(record.name));ui.home.people["resident:"+str(record.id)]=actor
	var nameplate:=Label.new();nameplate.text=str(record.name);nameplate.add_theme_font_override("font",UI.FONT);nameplate.add_theme_font_size_override("font_size",12);nameplate.position=Vector2(-12,-102);actor.add_child(nameplate)
	work_layer=Node2D.new();actor.add_child(work_layer);work_layer.draw.connect(draw_work)
	sync_schedule(true);texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
func current_slot() -> int:return 0 if ui.home.hour<11 else (1 if ui.home.hour<17 else 2)
func sync_schedule(first:=false) -> void:
	var next:=current_slot()
	actor.visible=not (record.id in ["xiaotao","kaikai"] and ui.home.hour>=5 and ui.home.hour<7)
	if next==slot_index:return
	slot_index=next;settled=false;actor.lift=0;actor.action="idle"
	var s:Dictionary=record.schedule[slot_index];var goal:=Vector2(s.pos[0],s.pos[1])
	if first:
		actor.position=goal;settle();return
	var approach:Vector2=goal
	if s.has("approach"):approach=Vector2(s.approach[0],s.approach[1])
	actor.route=ui.home.world.path(actor.position,approach);actor.destination_action="idle";actor.destination_face=str(s.face)
func settle() -> void:
	var s:Dictionary=record.schedule[slot_index];actor.position=Vector2(s.pos[0],s.pos[1]);actor.face=str(s.face)
	actor.action=str(s.action);actor.lift=ui.home.seat_lift(actor.position) if s.action=="drink" else 0.0;actor.position.y+=actor.lift;settled=true
func _process(dt:float) -> void:
	if not is_instance_valid(ui) or not is_instance_valid(actor):return
	elapsed+=dt;sync_schedule()
	if not actor.route.is_empty():actor.move_along(dt,50)
	elif not settled:settle()
	if actor.visible and not ui.home.busy() and actor.position.distance_to(ui.home.player.position)<120 and elapsed>=greet_after:
		greet_after=elapsed+30;actor.face="right" if ui.home.player.position.x>actor.position.x else "left";actor.say(str(record.schedule[slot_index].line))
	elif actor.bubble_time<=0 and not actor.walking:actor.face=str(record.schedule[slot_index].face)
	work_layer.queue_redraw();queue_redraw()
func draw_work() -> void:
	if actor.walking or not actor.visible:return
	var phase:=roundf(sin(elapsed*4)*2)
	if actor.action=="sift":
		work_layer.draw_rect(Rect2(-19,-39+phase,38,11),Color("714a29"));work_layer.draw_rect(Rect2(-16,-39+phase,32,6),Color("d9ac51"))
		for n in 7:work_layer.draw_rect(Rect2(-13+n*4,-37+phase,2,2),Color("f7d56d"))
	elif actor.action=="wash":
		for n in 5:work_layer.draw_rect(Rect2(-12+n*5,-30+phase,3,3),Color("a4dde1"))
	elif actor.action=="honey":
		work_layer.draw_rect(Rect2(-23,-44+phase,9,12),Color("e8b780"));work_layer.draw_rect(Rect2(-24,-35+phase,10,5),Color("b37c38"))
	elif actor.action=="mill":
		for x in [-19,12]:work_layer.draw_rect(Rect2(x,-46+phase,8,10),Color("d7a26e"))
func talk(id:String) -> bool:
	if id!="resident:"+str(record.id):return false
	actor.face="down";ui.home.dialogue(str(record.name),str(record.schedule[slot_index].line),str(record.portrait));return true
func handle(h:Dictionary) -> bool:
	if str(h.get("kind","")) in ["mill_game","honey_game"]:ui.open_institution_game(str(ui.home.world.cfg.institution));return true
	if h.get("kind","")=="seat" and actor.visible and actor.action=="drink" and actor.position.distance_to(Vector2(h.pos[0],h.pos[1]))<60:
		ui.home.player.say(str(record.name)+"正坐着喝茶，桌边还有热茶。")
		return true
	var id:=str(h.get("action",h.id))
	if not id in ["sift","tea","sweep","wash","filter","bottle"]:return false
	var copy:String={"sift":"谷壳簸开了，剩下金黄的谷粒。","tea":"续上一杯热茶，茶香慢慢冒起来。","sweep":"谷壳收进篮里，走道扫干净了。","wash":"水花带走碎蜡，蜂具洗得亮亮的。","filter":"滤布轻轻压下，细碎蜂蜡留在上面。","bottle":"蜜罐封好蜡口，留住花朵的香味。"}[id]
	var result:Dictionary=ui.state.act("institution_effect",{"room":ui.home.area,"spot":id,"message":copy})
	if result.ok:changed_at[id]=elapsed;ui.home.player.face="up"
	ui.home.player.say(result.message);ui.home.note=result.message;return true
func _draw() -> void:
	if not is_instance_valid(ui):return
	var effects:Dictionary=ui.state.data.village.institutions.get(ui.home.area,{})
	if ui.home.area=="v_h5":draw_honey(effects);return
	if ui.home.area!="v_h3":return
	if int(effects.get("sweep",0))==0:
		for n in 16:draw_rect(Rect2(288+(n*13)%29,430+(n*7)%39,3,2),Color("d9b464"))
	if int(effects.get("tea",0))>0:
		for n in 4:
			var rise:=fmod(elapsed*10+n*7,27.0);draw_rect(Rect2(Vector2(113+sin(elapsed+n)*3,353-rise).round(),Vector2(2,4)),Color(1,.94,.78,(1-rise/27)*.8))
	var sifting:bool=elapsed-float(changed_at.get("sift",-20.0))<4 or (slot_index==0 and actor.visible and not actor.walking)
	if sifting:
		for n in 7:draw_rect(Rect2(Vector2(100+n*3+sin(elapsed*6)*4,182+fmod(elapsed*18+n*3,18)).round(),Vector2(2,2)),Color("f1c65c"))
	var working:bool=slot_index==1 and actor.visible and not actor.walking and not ui.opened
	var rod:=Assets.texture("res://ayu_home/v4/assets/institutions/mill-rod-v1.png")
	draw_set_transform(Vector2(268,111),sin(elapsed*1.8)*.17 if working else 0.0)
	draw_texture(rod,Vector2(-6,-17));draw_set_transform(Vector2.ZERO)
	if working:
		for n in 7:draw_rect(Rect2(264+n%3,173+fmod(elapsed*26+n*6,44),2,3),Color("f8dfb0"))

func draw_honey(effects:Dictionary) -> void:
	var working:bool=slot_index==1 and actor.visible and not actor.walking and not ui.opened
	if working:
		for n in 5:
			var a:=elapsed*1.6+n*TAU/5
			draw_line(Vector2(247,245),(Vector2(247,245)+Vector2(cos(a)*33,sin(a)*17)).round(),Color("716451"),3)
		for n in 4:draw_rect(Rect2(245,318+fmod(elapsed*20+n*5,18),3,3),Color("ffd461"))
	if int(effects.get("wash",0))>0 or slot_index==0:
		for n in 5:draw_rect(Rect2(Vector2(66+n*4,267+sin(elapsed*3+n)*3).round(),Vector2(3,2)),Color("bfe2db"))
	if int(effects.get("filter",0))==0:
		for n in 5:draw_rect(Rect2(197+n*3,115+n%2*3,2,2),Color("705235"))
	else:draw_rect(Rect2(197,131,11,5),Color("ead7a8"))
	if int(effects.get("bottle",0))>0:
		draw_rect(Rect2(425,284,10,4),Color("a1352d"));draw_rect(Rect2(428,288,4,3),Color("cf6741"))
	if int(effects.get("tea",0))>0:
		for n in 4:
			var rise:=fmod(elapsed*10+n*7,23.0);draw_rect(Rect2(Vector2(202+sin(elapsed+n)*3,443-rise).round(),Vector2(2,4)),Color(1,.94,.78,(1-rise/23)*.8))
