extends SceneTree
## 第七轮补（01）：门前几步（64 画布像素）以内，门的提示一定出（客厅大门、手作房门原来被别的东西挤掉，要走很近才出）。
## 每间房、每扇该出提示的门（屋里房间之间的门本来就不出），门前能站的点都站一遍，看出的那一个提示是不是这扇门
var h
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var vp:=SubViewport.new();vp.size=Vector2i(540,960);root.add_child(vp)
	h=load("res://ayu_home/v4/home.gd").new();h.town_profile={"id":"dh"};h.save_path=OS.get_user_data_dir()+"/dh.json";vp.add_child(h);await process_frame;h.set_process(false);h.admitted=true;h.close_modal();h.sound_on=false;h.set_test_clock(14.5)
	var bad:=0;var n:=0;var named:={}
	for room in h.definitions:
		h.enter_room(room,false,"");h.transition=false;h.fade.color.a=0
		for d in h.world.cfg.doors:
			if not h.outdoors() and not bool(h.definitions.get(str(d.target),{}).get("outdoor",false)):continue
			var ap:Vector2=h.world.nearest(Vector2(d.approach[0],d.approach[1]))
			for r in [8.0,24.0,40.0,56.0]:
				for k in 8:
					var q:Vector2=ap+Vector2.from_angle(k*TAU/8)*r
					if not h.world.passable(q) or h.world.nearest(q).distance_to(ap)>=62.0:continue
					h.player.position=q;h.player.route.clear();h.camera=q-Vector2(0,65)
					for i in 3:h._process(.016)
					var m=h.marker_nodes.filter(func(x):return x.hot.id==d.id)
					var raw:Vector2=h.world.get_global_transform_with_canvas()*Vector2(d.pos[0],d.pos[1])
					if raw.x<4 or raw.x>536 or raw.y<h.hud_bottom()+18:continue # 门在屏幕外，本来就不出
					n+=1
					if m.is_empty() or not m[0].button.visible:
						bad+=1
						if not named.has(room+d.id):named[room+d.id]=1;print("门前没出提示 ",room," ",d.id,"「",d.get("label",""),"」 站在 ",q.round())
	print("RESULT ","PASS" if bad==0 else "FAIL"," 门前站了 %d 处，门的提示没出 %d 处"%[n,bad]);quit()
