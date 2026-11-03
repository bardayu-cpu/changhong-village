extends SceneTree
const World=preload("res://ayu_home/v4/world.gd")
class FrameHarness:
	extends "res://ayu_home/v4/home.gd"
	func _ready() -> void:pass
	func _process(_dt:float) -> void:pass
	func _exit_tree() -> void:pass
	func hud_bottom() -> float:return 100.0

func _initialize() -> void:call_deferred("run")

func run() -> void:
	var viewport:=SubViewport.new();root.add_child(viewport)
	var home:=FrameHarness.new();viewport.add_child(home)
	home.scene_frame=Control.new();home.add_child(home.scene_frame)
	home.world=World.new();home.scene_frame.add_child(home.world);home.world.set_process(false);home.world.load_room("my_cabin");home.area="my_cabin"
	var at:Vector2=home.world.nearest(World.v(home.world.cfg.doors[0].arrival))
	var player_box:=Rect2(at-Vector2(32,84),Vector2(64,84))
	# Covers the table, dishes and both benches in the existing 508 x 600 art.
	var table_box:=Rect2(150,216,210,165)
	var corners:={"prep":Vector2(76,207),"weave":Vector2(333,123),"read":Vector2(148,487),"tidy":Vector2(454,310)}
	var rows:Array=[]
	for screen in [Vector2i(540,960),Vector2i(1280,720)]:
		viewport.size=screen;await process_frame
		var safe:=Rect2(20,125,screen.x-40,screen.y-310)
		for mode in ["existing_entry","table_first_candidate"]:
			home.camera=at-Vector2(0,65) if mode=="existing_entry" else Vector2(256,350)
			home.layout_world()
			var transform:Transform2D=home.world.get_global_transform_with_canvas()
			var table_screen:Rect2=transform*table_box
			var player_screen:Rect2=transform*player_box
			var visible_corners:Array=[]
			var corner_screen:Dictionary={}
			for id in corners:
				var projected:Vector2=transform*corners[id]
				corner_screen[id]=[projected.x,projected.y]
				if safe.has_point(projected):visible_corners.append(id)
			rows.append({"mode":mode,"window":[screen.x,screen.y],"scale":home.view_scale,"nominal_actor_height":84*home.view_scale,"actual_center":[home.world.camera_center.x,home.world.camera_center.y],"safe_rect":[safe.position.x,safe.position.y,safe.size.x,safe.size.y],"table_screen":[table_screen.position.x,table_screen.position.y,table_screen.size.x,table_screen.size.y],"player_screen":[player_screen.position.x,player_screen.position.y,player_screen.size.x,player_screen.size.y],"whole_table_in_safe_area":safe.encloses(table_screen),"whole_player_in_safe_area":safe.encloses(player_screen),"visible_corner_centers":visible_corners,"corner_screen":corner_screen})
	var candidates:Array=[]
	var required:Rect2=table_box.merge(player_box)
	var keys:Array=corners.keys()
	# A weaker test than showing entire furniture: even the two corner centers must fit.
	for i in keys.size():
		for j in range(i+1,keys.size()):
			var bounds:Rect2=required.expand(corners[keys[i]]).expand(corners[keys[j]])
			var needed:Vector2=bounds.size*2.0
			candidates.append({"corners":[keys[i],keys[j]],"minimum_screen_span":[needed.x,needed.y],"fits_500_by_650_safe_area":needed.x<=500 and needed.y<=650})
	var output:={"mode":"Read-only native layout_world projection. Fixed HUD bottom 100; C4 safe region is 20..520 / 125..775 at 540x960. No game state/save, GUI window or production edit.","arrival":[at.x,at.y],"samples":rows,"two_corner_feasibility":candidates,"visual_acceptance":false}
	FileAccess.open("res://../回执/第1轮返工/A4-二修-入口视野核对.json",FileAccess.WRITE).store_string(JSON.stringify(output,"\t")+"\n")
	home.free();viewport.free()
	print("A4_ENTRY_MEASUREMENT_COMPLETE samples=",rows.size()," corner_pairs=",candidates.size())
	quit()
