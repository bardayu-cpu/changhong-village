extends SceneTree
var h
func _initialize() -> void:call_deferred("run")
func run() -> void:
	await process_frame;root.size=Vector2i(1080,1920);await process_frame
	var save:=OS.get_user_data_dir()+"/probe-c2.json";DirAccess.remove_absolute(save)
	h=load("res://ayu_home/home.tscn").instantiate();h.town_profile={"id":"pc2","avatar":2};h.save_path=save;root.add_child(h);await process_frame;h.close_modal();h.sound_on=false;h.admitted=true
	h.enter_room("closet2",false,"stairs2");for i in 20:await process_frame
	print("door nearest ",h.world.nearest(Vector2(216,169))," player ",h.player.position)
	for i in 30:await process_frame
	var shown:=[]
	for m in h.marker_nodes:
		if m.button.visible:shown.append(m.hot.id)
	print("气泡 ",shown," near ",h.near_id)
	var p:Vector2=h.world.get_global_transform_with_canvas()*Vector2(216,169)
	for down in [true,false]:
		var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;e.position=p;e.global_position=p;root.push_input(e,true);await process_frame
	print("点门后 pending=",h.pending," route=",h.player.route.size())
	var t:=0
	while t<600 and h.area=="closet2":await process_frame;t+=1
	print("结果 area=",h.area," pending=",h.pending," pos=",h.player.position)
	quit()
