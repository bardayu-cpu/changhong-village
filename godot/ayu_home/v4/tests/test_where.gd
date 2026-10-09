extends SceneTree
## 第六轮第 3 条：「家里的人」写的位置跟家人此刻真的在的房间一致
var h
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var vp:=SubViewport.new();vp.size=Vector2i(540,960);root.add_child(vp)
	h=load("res://ayu_home/v4/home.gd").new();h.town_profile={"id":"wh"};h.save_path=OS.get_user_data_dir()+"/wh.json";vp.add_child(h);await process_frame;h.set_process(false);h.admitted=true;h.close_modal()
	var bad:=0
	for hr in [7.0,9.5,12.3,15.0,19.5,21.0,23.5]:
		h.set_test_clock(hr);h.enter_room("living",false,"exterior")
		for i in 1200:h._process(.05)
		var line:=[]
		for id in ["ayu","father","mother"]:
			var st:Dictionary=h.family_state[id];var said:String=h.where_is(id);line.append(id+"="+said+"（真在 "+str(st.room)+" "+str(st.action)+"）")
			var real:String=str(st.room)
			var ok:bool=(said=="外出" and (real=="away" or h.schedule(id).area=="away")) or (h.definitions.has(real) and said.split("\n")[0]=="在"+h.short_room(real))
			# 第 29 条：睡觉、歇着写法一样（第二行「睡觉」）；每行最多 5 个字，头像下面那列排得下
			if said.ends_with("睡觉") and str(st.action) not in ["sleep","rest"]:ok=false
			for ln in said.split("\n"):
				if ln.length()>5:ok=false
			if not ok:bad+=1
		print(hr," ",line)
	h.family_page();await process_frame;await process_frame
	print("RESULT ","PASS" if bad==0 else "FAIL"," ",bad);quit()
