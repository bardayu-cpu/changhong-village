extends Node2D
const C=preload("res://ayu_home/v4/core/config.gd")
const UI=preload("res://ayu_home/v4/pixel_ui.gd")
const Assets=preload("res://ayu_home/v2/assets.gd")
var ui
func _ready() -> void:
	z_index=2;texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	# 院子的不透明地面跟随现有 ground 重画，排在 actors 前；家具和提示仍留在原效果层。
	if ui.home.area=="my_yard":ui.home.world.ground.draw.connect(_draw_yard_ground.bind(ui.home.world.ground))
func _draw_yard_ground(surface:Node2D) -> void:
	var v:Dictionary=ui.state.data.village
	for y in 9:
		for x in 4:
			var at:=Vector2(665+x*28,530+y*25);var open:bool=float(v.land[y/3])>0
			surface.draw_rect(Rect2(at,Vector2(25,22)),Color("b89a6c") if open else Color("6f8244"))
	for n in 6:
		var at:=Vector2(75+(n%3)*100,635+(n/3)*85)
		surface.draw_rect(Rect2(at,Vector2(85,65)),Color("76563b"))
		for row in 4:surface.draw_rect(Rect2(at+Vector2(4,8+row*14),Vector2(77,4)),Color("98704b"))
func _draw() -> void:
	var s=ui.state;var h=ui.home;var v:Dictionary=s.data.village
	if h.area=="village":
		for p in h.world.cfg.hotspots:
			var id:=str(p.id);var at:=Vector2(p.approach[0],p.approach[1])
			if C.PRODUCERS.has(id) and not v.producers[id].is_empty() and s.remaining(v.producers[id].due)==0:
				draw_circle(at+Vector2(30,-42),6,Color("ffdc85"));draw_string(UI.FONT,at+Vector2(-22,-65),"可收",HORIZONTAL_ALIGNMENT_CENTER,44,16,Color("fff3d8"))
		for spot in h.world.cfg.hotspots:
			if spot.get("kind","")=="door_chore":
				var done:bool=v.chores.has(s.date_key()+":house:"+str(spot.house))
				preload("res://ayu_home/v4/core/doorstep_draw.gd").paint(self,str(spot.house),Vector2(spot.pos[0],spot.pos[1]),done)
		for id in C.LOCATION_POINTS:
			var a:Array=C.LOCATION_POINTS[id];var at:=Vector2(a[0],a[1])
			draw_string(UI.FONT,at+Vector2(-70,40),("你的家 · " if v.location==id else "空地 · ")+C.LOCATIONS[id],HORIZONTAL_ALIGNMENT_CENTER,150,18,Color("fff4cf"))
			if v.location==id:draw_texture_rect(Assets.texture("res://ayu_home/v4/assets/village/board.png"),Rect2(at-Vector2(28,80),Vector2(56,70)),false)
		# A working chicken coop: timber, roof slats and little hens use crisp native pixels.
		var c:=Vector2(1080,1300);draw_rect(Rect2(c-Vector2(80,70),Vector2(145,70)),Color("a97b49"));draw_rect(Rect2(c-Vector2(88,86),Vector2(160,24)),Color("5c6a72"))
		for i in 6:draw_line(c+Vector2(-78+i*27,-84),c+Vector2(-78+i*27,-64),Color("788286"),2)
		for i in 3:
			var q:=c+Vector2(-55+i*48,16);draw_rect(Rect2(q,Vector2(20,16)),Color("eee1b4"));draw_rect(Rect2(q+Vector2(15,-6),Vector2(9,12)),Color("f3e8c8"));draw_rect(Rect2(q+Vector2(15,-10),Vector2(8,5)),Color("b85442"));draw_rect(Rect2(q+Vector2(20,-3),Vector2(3,3)),Color("312c26"))
		if int(v.helped.get("honey",0))>0:draw_texture(Assets.texture("res://ayu_home/v3/assets/exterior_pot_window_left.png"),Vector2(830,1100))
	elif h.area=="my_yard":
		for f in v.furniture:
			if int(f.x)<0:continue
			var at:=Vector2(666+int(f.x)*28,516+int(f.y)*25)
			preload("res://ayu_home/v4/core/furniture_draw.gd").paint(self,str(f.kind),Rect2(at,Vector2(26,34)))
		for n in 6:
			var at:=Vector2(75+(n%3)*100,635+(n/3)*85)
			var crop:Dictionary=v.crops[n]
			if crop.is_empty():continue
			for j in 3:
				var q:=at+Vector2(16+j*24,35);var ripe:bool=s.remaining(crop.due)==0
				draw_rect(Rect2(q+Vector2(2,-16),Vector2(4,27)),Color("4e7940"));draw_rect(Rect2(q+Vector2(-5,-10),Vector2(19,6)),Color("8bad50"))
				if ripe:draw_rect(Rect2(q+Vector2(-2,2),Vector2(12,13)),{"radish":Color("edccab"),"pepper":Color("d55a44"),"grain":Color("e6bd5e")}[crop.crop])
	elif h.area.begins_with("v_"):
		var id:String=h.area.trim_prefix("v_").trim_suffix("_up")
		if not h.world.cfg.get("household_open",false) and int(v.helped.get("house:"+id,0))>0:draw_texture(Assets.texture("res://ayu_home/v3/assets/exterior_pot_window_left.png"),Vector2(430,330))
	if h.world.cfg.get("outdoor",false):
		var season:int=h.Data.season(h.month)
		for p in h.world.props:
			if p.config.get("plant_type","")=="fruit":
				var at:=Vector2(p.config.pos[0],p.config.pos[1])
				for i in 14:
					var q:=at+Vector2(25+posmod(i*31,110),15+posmod(i*19,100))
					if season==0:draw_rect(Rect2(q,Vector2(6,5)),Color("f8d7c6"));draw_rect(Rect2(q+Vector2(2,-2),Vector2(2,9)),Color("fff1d9"))
					elif season==2:draw_rect(Rect2(q+Vector2(0,130),Vector2(5,2)),Color("ad6a3e"))
func furniture_texture(id:String) -> String:
	return {"chair":"res://ayu_home/v4/assets/floor1-redraw/living-chair.png","table":"res://ayu_home/v4/assets/floor1-redraw/living-table.png","planter":"res://ayu_home/v3/assets/exterior_pot_window_left.png"}.get(id,"")
