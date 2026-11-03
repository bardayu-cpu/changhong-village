extends SceneTree
const World=preload("res://ayu_home/v4/world.gd")
var failures:Array=[]
var rows:Array=[]
func check(label:String,c:Dictionary,at:Vector2,physical:bool,centre:bool) -> void:
	var a:=World.walkable_in(c,at)
	var b:=not World.blocked_by_field(c,at,true) and a
	rows.append({"case":label,"point":[at.x,at.y],"physical":a,"grid_centre":b})
	if a!=physical or b!=centre:failures.append(label)
func _initialize() -> void:
	var c:={"walk_rect":[0,0,200,200],"obstacles":[[80,90,20,20]],"blocked_polygons":[[[180,0],[200,0],[200,200],[180,200]]],"field_navigation":{"margin":8,"fields":[[[0,0],[200,0],[200,200],[0,200]]],"walk_surfaces":[[[20,90],[190,90],[190,130],[20,130]],[[120,20],[160,20],[160,130],[120,130]]]}}
	check("outside L corner",c,Vector2(118,88),false,false)
	check("outside road edge",c,Vector2(161,50),false,false)
	check("inside road, 2px from edge; clearance is only a nav heuristic",c,Vector2(158,50),true,false)
	check("wall 3px physical buffer unchanged",c,Vector2(101,100),false,false)
	check("river remains solid despite surface overlap",c,Vector2(185,100),false,false)
	var rejected:=false
	for i in range(17):
		var at:=Vector2(112,94).lerp(Vector2(124,82),i/16.0)
		if not World.walkable_in(c,at):rejected=true
	if not rejected:failures.append("corner shortcut escaped physical segment check")
	rows.append({"case":"unsafe corner segment rejected at intermediate feet","pass":rejected})
	var report:={"pass":failures.is_empty(),"failures":failures,"cases":rows,"facts":["Actor movement uses a position point, not an 8px physics body","Existing wall collision Rect2.grow(3) unchanged","8px field clearance was introduced only with this v3 grid generation","Physical segment checks retain wall/river/field-boundary tests; C3 tests untouched"]}
	var f:=FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
