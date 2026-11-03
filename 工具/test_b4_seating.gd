extends SceneTree
class SeatHome extends "res://ayu_home/v4/home.gd":
	func _ready() -> void:pass
	func _process(_dt:float) -> void:pass
class SeatWorld extends Node2D:
	var props:Array=[]
var failures:Array[String]=[]
func check(ok:bool,label:String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok:failures.append(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var h:=SeatHome.new();root.add_child(h);h.set_process(false)
	h.world=SeatWorld.new();h.add_child(h.world)
	h.player=Node2D.new();h.player.set_script(load("res://ayu_home/v4/actor.gd"));h.world.add_child(h.player)
	var im:=Image.create(20,10,false,Image.FORMAT_RGBA8);im.fill(Color.TRANSPARENT);im.fill_rect(Rect2i(12,2,4,4),Color.WHITE)
	var atlas:=AtlasTexture.new();atlas.atlas=ImageTexture.create_from_image(im);atlas.region=Rect2(10,0,10,10)
	var base:=Node2D.new();base.position=Vector2(0,140);h.world.add_child(base)
	var sp:=Sprite2D.new();sp.centered=false;sp.texture=atlas;sp.scale=Vector2(2,2);sp.position=Vector2(100,-40);base.add_child(sp)
	var prop:={"sprite":sp,"root":base,"config":{"pos":[100,100],"foot":140}}
	h.world.props=[prop]
	check(h.prop_covers(prop,Vector2(106,106)),"scaled atlas opaque seat")
	check(not h.prop_covers(prop,Vector2(101,101)),"atlas transparent margin ignored")
	check(not h.prop_covers(prop,Vector2(140,106)),"outside furniture ignored")
	sp.position.x+=12
	check(h.prop_covers(prop,Vector2(118,106)),"moving chair uses rendered transform")
	check(not h.prop_covers(prop,Vector2(106,106)),"old chair position no longer covers")
	h.place_seated(Vector2(118,106))
	check(h.player.position.y>float(prop.config.foot),"seated character sorted in front of chair")
	check((h.player.position-Vector2(0,h.player.lift)).is_equal_approx(Vector2(118,106)),"seat visual foot remains anchored")
	# 真实老屋竹椅原始坐点与原图，继续覆盖普通非图集家具。
	sp.scale=Vector2.ONE;sp.position=Vector2(315,392)-base.position
	sp.texture=load("res://ayu_home/v3/assets/exterior_bench.png")
	prop.config={"pos":[315,392],"foot":425}
	check(h.prop_covers(prop,Vector2(345,415)),"actual old-house bench seat is opaque")
	h.place_seated(Vector2(345,415))
	check(h.player.position.y>425 and is_equal_approx(h.player.position.y-h.player.lift,415),"actual bench sort and foot anchor")
	h.free()
	print("B4_SEATING "+("PASS" if failures.is_empty() else "FAIL"));quit(0 if failures.is_empty() else 1)
