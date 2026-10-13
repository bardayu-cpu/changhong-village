extends SceneTree
const World=preload("res://ayu_home/v4/world.gd")
var failed:=false
var checks:=0
func check(ok:bool,label:String) -> void:
	checks+=1;failed=failed or not ok;print(("PASS " if ok else "FAIL ")+label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var viewport:=SubViewport.new();root.add_child(viewport)
	var host:=Node2D.new();viewport.add_child(host);host.position=Vector2(91,67)
	var world:=World.new();host.add_child(world)
	for screen in [Vector2i(540,960),Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1600),Vector2i(540,960)]:
		viewport.size=screen
		for zoom in [1.0,2.0,2.8]:
			world.scale=Vector2.ONE*zoom;world.position=Vector2(-473,-292);await process_frame
			var view:Rect2=world.weather_view();var transform:Transform2D=world.get_global_transform_with_canvas()
			var covered:=Rect2(transform*view.position,view.size*zoom)
			check(covered.encloses(Rect2(Vector2.ZERO,screen)),"all viewport edges covered %s zoom%.1f"%[screen,zoom])
			var plain_area:float=screen.x*screen.y/(zoom*zoom)
			check(absf(view.size.x-screen.x/zoom-40)<.01 and absf(view.size.y-screen.y/zoom-40)<.01,"range follows actual window and canvas, no fixed phone mask")
			check(world.weather_count(110)>=mini(1600,roundi(110*plain_area/156000)),"rain density scales with visible area")
			var bins:Dictionary={}
			for i in world.weather_count(110):
				var point:=view.position+Vector2(fposmod(i*29.0-17*60,view.size.x),fposmod(i*47.0+17*420,view.size.y));var pixel:Vector2=transform*point
				if Rect2(Vector2.ZERO,screen).has_point(pixel):bins[clampi(int(pixel.x/(screen.x/3.0)),0,2)]=true
			check(bins.size()==3,"rain reaches left centre and right bands")
	viewport.queue_free();await process_frame;print("WEATHER_VIEWPORT ","FAIL" if failed else "PASS"," ",checks," checks; headless geometry, desktop screenshots remain C3");quit(1 if failed else 0)
