extends SceneTree
var h
func _initialize() -> void:call_deferred("run")
func run() -> void:
	await process_frame;root.size=Vector2i(1080,1920);await process_frame
	var save:=OS.get_user_data_dir()+"/probe-fam.json";DirAccess.remove_absolute(save)
	h=load("res://ayu_home/home.tscn").instantiate();h.town_profile={"id":"pf","avatar":2};h.save_path=save;root.add_child(h);await process_frame;h.close_modal()
	for hr in [6.5,7.6,9.5,12.3,15.0,18.3,21.0,23.5,2.0]:
		h.set_test_clock(hr);for i in 3:await process_frame
		var s:=[]
		for id in ["father","mother","ayu"]:
			var st=h.family_state[id];s.append("%s:%s@%s %s"%[id,st.action,st.room,str(Vector2(st.pos).round())])
		print("时间 ",hr," ",s)
	h.set_test_clock(23.5);h.enter_room("parents",false);for i in 5:await process_frame
	for id in ["father","mother"]:print(id," 可见=",h.people[id].visible," 位置",h.people[id].position.round()," 动作",h.people[id].action," lift=",h.people[id].lift)
	quit()
