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
	actor.visible=not (record.id in ["xiaotao","kaikai","linbo"] and ui.home.hour>=5 and ui.home.hour<7)
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
	actor.action=str(s.action);actor.lift=ui.home.seat_lift(actor.position) if s.action in ["drink","read"] else 0.0;actor.position.y+=actor.lift;settled=true
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
	elif actor.action=="registry":
		work_layer.draw_rect(Rect2(-16,-40,32,19),Color("eedcb0"));work_layer.draw_line(Vector2(0,-40),Vector2(0,-21),Color("765037"),2)
	elif actor.action=="stamp":
		work_layer.draw_rect(Rect2(13,-35+phase*2,9,9),Color("a04a30"));work_layer.draw_rect(Rect2(15,-41+phase*2,5,8),Color("684530"))
	elif actor.action=="wash":
		for n in 5:work_layer.draw_rect(Rect2(-12+n*5,-30+phase,3,3),Color("a4dde1"))
	elif actor.action=="honey":
		work_layer.draw_rect(Rect2(-23,-44+phase,9,12),Color("e8b780"));work_layer.draw_rect(Rect2(-24,-35+phase,10,5),Color("b37c38"))
	elif actor.action=="mill":
		for x in [-19,12]:work_layer.draw_rect(Rect2(x,-46+phase,8,10),Color("d7a26e"))
	elif actor.action=="stir":
		work_layer.draw_line(Vector2(-13,-39),Vector2(-23+phase*2,-25),Color("b88853"),4);work_layer.draw_rect(Rect2(-28,-24,22,7),Color("d8bd87"))
func talk(id:String) -> bool:
	if id!="resident:"+str(record.id):return false
	actor.face="down";ui.home.dialogue(str(record.name),str(record.schedule[slot_index].line),str(record.portrait));return true
func handle(h:Dictionary) -> bool:
	if str(h.get("kind","")) in ["mill_game","honey_game","civic_game","community_game"]:ui.open_institution_game(str(ui.home.world.cfg.institution));return true
	if h.get("kind","")=="seat" and actor.visible and actor.action in ["drink","read"] and actor.position.distance_to(Vector2(h.pos[0],h.pos[1]))<60:
		ui.home.player.say(str(record.name)+"正坐着喝茶，桌边还有热茶。")
		return true
	var id:=str(h.get("action",h.id))
	if not id in ["sift","tea","sweep","wash","filter","bottle","register","counter","notice","bundle","weave","table","read","tidy"]:return false
	var copy:String={"sift":"谷壳簸开了，剩下金黄的谷粒。","tea":"续上一杯热茶，茶香慢慢冒起来。","sweep":"谷壳收进篮里，走道扫干净了。","wash":"水花带走碎蜡，蜂具洗得亮亮的。","filter":"滤布轻轻压下，细碎蜂蜡留在上面。","bottle":"蜜罐封好蜡口，留住花朵的香味。","register":"翻开名册，今天的住户记录核对好了。","counter":"申请表放在柜台了，材料齐了再请林伯确认。","notice":"意见条夹进篮里，晚些和大家一起商量。","bundle":"系上红记号，修缮包就不会拿错了。","weave":"横一条，竖一条，竹片编成一小块。","table":"每个座位都摆好碗了，等大家来坐。","read":"翻开图画，听方婆婆讲共桌的故事。","tidy":"球归球篮，棋盒收进格子，走道空出来了。"}[id]
	var result:Dictionary=ui.state.act("institution_effect",{"room":ui.home.area,"spot":id,"message":copy})
	if result.ok:changed_at[id]=elapsed;ui.home.player.face="up"
	ui.home.player.say(result.message);ui.home.note=result.message
	if id=="counter" and result.ok:ui.show_page("村长")
	if id=="read" and result.ok:open_story()
	return true
func _draw() -> void:
	if not is_instance_valid(ui):return
	var effects:Dictionary=ui.state.data.village.institutions.get(ui.home.area,{})
	if ui.home.area=="v_h5":draw_honey(effects);return
	if ui.home.area=="v_mayor":draw_civic(effects);return
	if ui.home.area=="my_cabin":draw_community(effects);return
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
		var level:=fmod(elapsed*.9,10.0);draw_rect(Rect2(240,352-level,13,level),Color("d6a338"))
	if int(effects.get("wash",0))>0 or slot_index==0:
		for n in 5:draw_rect(Rect2(Vector2(66+n*4,267+sin(elapsed*3+n)*3).round(),Vector2(3,2)),Color("bfe2db"))
	# honey-v2 的盆内为 (54,255)～(106,287)；清洗后碎蜡消失，不与早间水纹混淆。
	if int(effects.get("wash",0))==0:
		for p in [Vector2(60,279),Vector2(82,261),Vector2(93,279)]:draw_rect(Rect2(p,Vector2(3,2)),Color("c79b46"))
	if int(effects.get("filter",0))==0:
		for n in 5:draw_rect(Rect2(197+n*3,115+n%2*3,2,2),Color("705235"))
	else:
		draw_rect(Rect2(190,130,17,5),Color("ead7a8"));draw_rect(Rect2(190,134,17,2),Color("a8936f"))
	if int(effects.get("bottle",0))>0:
		# 右架下层左侧蜜罐口；旧 (425,284) 实为上一层架板边。
		draw_rect(Rect2(407,307,12,4),Color("a1352d"));draw_rect(Rect2(409,307,8,2),Color("df7957"));draw_rect(Rect2(413,311,3,5),Color("b44935"))
	if int(effects.get("tea",0))>0:
		for n in 4:
			# 右茶杯上沿 y=436，灰蓝外沿让蒸汽在米白桌布前仍可辨认。
			var rise:=fmod(elapsed*10+n*7,25.0);var steam:=Vector2(201+sin(elapsed+n)*3,435-rise).round();var opacity:float=(1-rise/25)*.9
			draw_rect(Rect2(steam+Vector2(-1,0),Vector2(4,5)),Color(.40,.54,.54,opacity*.65));draw_rect(Rect2(steam,Vector2(2,4)),Color(1,.96,.84,opacity))

func draw_civic(effects:Dictionary) -> void:
	if int(effects.get("register",0))>0:
		draw_rect(Rect2(296,128,30,16),Color("e4d1a5"));draw_line(Vector2(311,128),Vector2(311,144),Color("714c33"),2);draw_rect(Rect2(315,137,5,4),Color("a44333"))
	if int(effects.get("counter",0))>0:draw_rect(Rect2(201,199,11,14),Color("f2e0b1"));draw_rect(Rect2(205,204,4,4),Color("a44333"))
	if int(effects.get("notice",0))>0:
		for n in 3:draw_rect(Rect2(133+n*6,329-n*2,5,12),Color("edcf8b"))
	if int(effects.get("bundle",0))>0:draw_rect(Rect2(424,391,12,5),Color("af4733"));draw_rect(Rect2(428,393,5,11),Color("b84c35"))

func draw_community(effects:Dictionary) -> void:
	var woven:int=mini(7,int((elapsed-float(changed_at.get("weave",-20.0)))*2)) if int(effects.get("weave",0))>0 else 0
	for n in 7:
		draw_rect(Rect2(312+n*4,137,2,18),Color("b89851"))
		if n<woven:draw_rect(Rect2(310,138+n*2,31,1),Color("ead39a"))
	var laid:bool=int(effects.get("table",0))>0
	for n in 4:
		var p:=Vector2(213+n*24,281) if laid else Vector2(293+n%2*14,274+n/2*11)
		draw_rect(Rect2(p,Vector2(10,6)),Color("eadbbe"));draw_rect(Rect2(p+Vector2(2,1),Vector2(6,2)),Color("a9bdb2"))
	var tidy:bool=int(effects.get("tidy",0))>0
	for n in 3:
		var p:=Vector2(438+n*10,316) if tidy else Vector2(393+n*9,360+n%2*9)
		draw_rect(Rect2(p,Vector2(7,7)),[Color("bd6650"),Color("d8b868"),Color("76a295")][n])
	if int(effects.get("read",0))>0:
		draw_rect(Rect2(130,450,26,16),Color("e5cfa5"));draw_line(Vector2(143,450),Vector2(143,466),Color("916a45"),2)
	if slot_index==0 and actor.visible:
		for n in 5:draw_rect(Rect2(Vector2(64+n*5,224+sin(elapsed*4+n)*3).round(),Vector2(3,3)),Color("b8ded2"))

func open_story(page:=0) -> void:
	var col:VBoxContainer=ui.home.modal_shell("方婆婆的共桌故事")
	var picture:=StoryPicture.new();picture.page=page;picture.custom_minimum_size=Vector2(360,210);col.add_child(picture)
	col.add_child(UI.paragraph(["第一回 · 春天\n大家把小苗栽在渠边，轮流提水，等第一片嫩叶长出来。","第二回 · 夏天\n青菜和海椒洗净了，长桌摆上碗，谁路过都可以坐下吃一口。","第三回 · 秋天\n果子装满竹篮，孩子把风筝收回来，明天还在这张桌边见。"][page]))
	var row:=HBoxContainer.new();col.add_child(row)
	row.add_child(UI.button("翻到下一页",func():open_story((page+1)%3),true));row.add_child(UI.button("合上故事册",func():ui.home.close_modal()))
class StoryPicture extends Control:
	var page:=0
	func _draw() -> void:
		draw_rect(Rect2(6,8,size.x-12,190),Color("7e593d"));draw_rect(Rect2(12,14,size.x-24,178),Color("e6d0a1"));draw_rect(Rect2(size.x*.5-2,16,4,174),Color("b7976b"))
		var start:=Vector2(34,125)
		for n in 5:
			var p:=start+Vector2(n*26,0)
			if page==0:
				draw_rect(Rect2(p,Vector2(19,5)),Color("947349"));draw_rect(Rect2(p+Vector2(7,-25),Vector2(4,25)),Color("698c51"));draw_rect(Rect2(p+Vector2(1,-20),Vector2(17,5)),Color("85a458"))
			elif page==1:
				draw_rect(Rect2(p+Vector2(0,-28),Vector2(25,9)),Color("a77848"));draw_rect(Rect2(p+Vector2(4,-35),Vector2(15,6)),Color("f0e0b6"));draw_rect(Rect2(p+Vector2(1,-19),Vector2(4,22)),Color("875d39"))
			else:
				draw_rect(Rect2(p+Vector2(0,-20),Vector2(23,20)),Color("ad8450"));draw_rect(Rect2(p+Vector2(3,-27),Vector2(7,8)),Color("d59146"));draw_rect(Rect2(p+Vector2(12,-30),Vector2(8,10)),Color("c8793e"))
		for n in 3:
			var p:=Vector2(size.x*.5+29+n*37,105+n%2*10)
			draw_rect(Rect2(p,Vector2(12,12)),Color("d7aa76"));draw_rect(Rect2(p+Vector2(-2,12),Vector2(17,22)),[Color("688c7d"),Color("bd7659"),Color("9585a2")][n]);draw_rect(Rect2(p+Vector2(0,34),Vector2(5,12)),Color("645746"));draw_rect(Rect2(p+Vector2(9,34),Vector2(5,12)),Color("645746"))
