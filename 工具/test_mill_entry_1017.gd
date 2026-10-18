extends SceneTree
const World=preload("res://ayu_home/v4/world.gd")
const Actor=preload("res://ayu_home/v4/actor.gd")
const Room=preload("res://ayu_home/v4/core/institution_room.gd")
const State=preload("res://ayu_home/v4/core/state.gd")
class Harness extends "res://ayu_home/v4/home.gd":
	var header:=88.0
	func _ready() -> void:pass
	func _process(_dt:float) -> void:pass
	func _exit_tree() -> void:pass
	func hud_bottom() -> float:return header
class Owner extends RefCounted:
	var home
	var state
	var opened:=false
	var opened_game:=""
	func open_institution_game(id:String) -> void:opened_game=id
var failures:Array=[]
var checks:=0
var report:Dictionary={"mode":"offline native geometry, navigation, resource and room interaction checks; not GUI"}
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures.append(label)
	print(("PASS " if ok else "FAIL ")+label)
func arr(v:Vector2) -> Array:return [v.x,v.y]
func box(r:Rect2) -> Array:return [r.position.x,r.position.y,r.size.x,r.size.y]
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var vp:=SubViewport.new();root.add_child(vp)
	var h:=Harness.new();vp.add_child(h);h.area="v_h3";h.hour=13
	h.scene_frame=Control.new();h.add_child(h.scene_frame)
	h.world=World.new();h.scene_frame.add_child(h.world);h.world.load_room("v_h3");h.world.set_process(false)
	h.player=Actor.new();h.world.actors.add_child(h.player);h.player.setup("visitor");h.player.face="up"
	var door:Dictionary=h.world.spot("outside")
	var arrival:Vector2=h.world.nearest(World.v(door.approach)+Vector2(0,-25));h.player.position=arrival
	check(arrival.distance_to(Vector2(254,493))<=3,"door arrival unchanged apart from existing grid snap")
	check(h.world.passable(arrival),"door arrival passable")
	var owner:=Owner.new();owner.home=h;owner.state=State.new()
	var folder:=ProjectSettings.globalize_path("res://../测试数据/A4磨坊预检-1017/")
	check(owner.state.open({"openid":"c2-mill-offline"},folder+"state-"+str(Time.get_ticks_usec())),"isolated room state opens")
	var room:=Room.new();h.world.add_child(room);room.setup(owner);room.set_process(false)
	check(room.actor.position.distance_to(World.v(h.world.spot("mill").approach))>64,"noon NPC has distinct operating position")
	check(h.world.passable(room.actor.position),"noon NPC stand point passable")
	var points:Array=[{"id":"outside","approach":door.approach}]+h.world.cfg.hotspots+[h.world.spot("upstairs")]
	var routes:Array=[]
	for point in points:
		var target:Vector2=h.world.nearest(World.v(point.approach));var path:PackedVector2Array=h.world.path(arrival,target)
		var clear:bool=not path.is_empty()
		for i in range(1,path.size()):
			for n in 5:
				if not h.world.passable(path[i-1].lerp(path[i],n/4.0)):clear=false
		check(target.distance_to(World.v(point.approach))<=3,"approach retained "+str(point.id))
		check(clear,"door route clear "+str(point.id))
		check(not h.world.path(target,arrival).is_empty(),"return route clear "+str(point.id))
		routes.append({"id":point.id,"approach":arr(target),"clear":clear})
	for id in ["sift","sweep","tea"]:
		var point:Dictionary=h.world.spot(id);h.player.position=h.world.nearest(World.v(point.approach))
		check(room.handle(point),"normal room handler "+id)
		check(int(owner.state.data.village.institutions.get("v_h3",{}).get(id,0))==1,"normal persisted effect "+id)
	check(room.handle(h.world.spot("mill")) and owner.opened_game=="mill","mill hotspot opens existing game")
	for p in h.world.props:
		var sp:Sprite2D=p.sprite;var tex:=sp.texture as AtlasTexture
		check(tex!=null and tex.atlas.get_size()==Vector2(1153,1364),"HD atlas source "+str(p.config.id))
		check((tex.region.position*h.world.base_sprite.scale+h.world.base_sprite.position-World.v(p.config.pos)).length()<0.01,"atlas source origin aligned "+str(p.config.id))
		check(sp.scale==h.world.base_sprite.scale,"atlas scale aligned "+str(p.config.id))
	var frames:Array=[];h.player.position=arrival
	for screen in [Vector2i(540,960),Vector2i(1280,720)]:
		vp.size=screen;await process_frame
		for header in [88.0,100.0]:
			h.header=header;h.camera=h.room_camera_target();h.layout_world()
			var frame:=Rect2(Vector2.ZERO,h.scene_frame.size)
			var subject:=Rect2(h.world.position+Vector2(286,312)*2,Vector2(166,179)*2)
			var player:=Rect2(h.world.position+(arrival-Vector2(32,84))*2,Vector2(128,168))
			var npc:=Rect2(h.world.position+(room.actor.position-Vector2(32,84))*2,Vector2(128,168))
			check(frame.encloses(subject),"full machine visible "+str(screen)+" hud "+str(header))
			check(frame.encloses(player),"full player visible "+str(screen)+" hud "+str(header))
			check(frame.encloses(npc),"noon NPC visible "+str(screen)+" hud "+str(header))
			frames.append({"window":[screen.x,screen.y],"header":header,"scene_position":arr(h.scene_frame.position),"scene_size":arr(h.scene_frame.size),"world_position":arr(h.world.position),"center":arr(h.world.camera_center),"machine":box(subject),"player":box(player)})
	await process_frame
	h.player.sprite.texture.get_image().save_png(folder+"player-frame.png")
	room.actor.sprite.texture.get_image().save_png(folder+"npc-frame.png")
	report.merge({"checks":checks,"failures":failures,"arrival":arr(arrival),"routes":routes,"frames":frames,"player_frame_position":arr(h.player.sprite.position),"player_frame_scale":arr(h.player.sprite.scale),"npc_position":arr(room.actor.position),"npc_frame_position":arr(room.actor.sprite.position),"npc_frame_scale":arr(room.actor.sprite.scale),"background_scale":arr(h.world.base_sprite.scale),"background_offset":arr(h.world.base_sprite.position)})
	var file:=FileAccess.open("res://../回执/第1轮返工/A4磨坊接入-1017/定向检查.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t")+"\n");file.close()
	h.queue_free();vp.queue_free();await process_frame
	print("MILL_ENTRY ","PASS" if failures.is_empty() else "FAIL"," ",checks);quit(0 if failures.is_empty() else 1)
