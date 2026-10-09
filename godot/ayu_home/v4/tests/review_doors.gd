extends SceneTree
## 04 体验师 修好版复看：门、看不见的门、点隔壁房间。
## 跟真玩一样：阿鱼家直接挂在根视口上（手机竖屏 540×960），点屏幕用真的鼠标事件推进视口，方向键用真的按键事件。
## 门的冷却、过门判定一行没改；游戏按真时间跑（time_scale 加快走路）。
## 用法：Godot --headless --path godot --script res://review/doors.gd -- --out=文件 [--only=doors|ghost|wall] [--rooms=a,b]
const World=preload("res://ayu_home/v4/world.gd")
var h
var out:=""
var only:=""
var only_rooms:Array=[]
var lines:PackedStringArray=[]
func _initialize() -> void:call_deferred("run")
func log_line(s:String) -> void:print(s);lines.append(s)
func wait(sec:float) -> void:await create_timer(sec*Engine.time_scale).timeout
func tap(p:Vector2) -> void:
	for down in [true,false]:
		var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;e.position=p;e.global_position=p;e.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0
		root.push_input(e,true);await process_frame
func key(code:Key,down:bool) -> void:
	var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down;Input.parse_input_event(e);Input.flush_buffered_events()
func scr(p:Vector2) -> Vector2:return h.world.get_global_transform_with_canvas()*p
func on_screen(s:Vector2) -> bool:
	var size:Vector2=root.get_visible_rect().size
	return s.x>12 and s.x<size.x-12 and s.y>h.hud_bottom()+20 and s.y<size.y-90
func settle() -> void:
	# 关掉弹出的东西（不碰门和冷却）
	if h.games.root:h.games.close(false)
	if h.activities.root:h.activities.close()
	if h.immersive.root:h.immersive.close(false)
	if h.photo.root:h.photo.close(false)
	if h.modal:h.close_modal()
	h.clear_scene_controls();h.stand_up();h.dismiss_invite()
func put(room:String,at:Vector2) -> void:
	settle();h.enter_room(room,false);h.transition=false
	h.player.position=h.world.spawn() if at==Vector2.INF else h.world.nearest(at);h.camera=h.player.position-Vector2(0,65)
	await wait(0.6)
func idle_until(maxsec:float,room:String) -> float:
	var t0:=Time.get_ticks_msec()
	while (Time.get_ticks_msec()-t0)/1000.0*Engine.time_scale<maxsec:
		await process_frame
		if h.area!=room and not h.transition:return (Time.get_ticks_msec()-t0)/1000.0*Engine.time_scale
		if h.area==room and h.pending.is_empty() and h.player.route.is_empty() and h.after_door.is_empty() and h.key_axis==Vector2.ZERO:return -1.0
	return -2.0
func run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):out=a.substr(6)
		elif a.begins_with("--only="):only=a.substr(7)
		elif a.begins_with("--rooms="):only_rooms=Array(a.substr(8).split(","))
	await process_frame
	root.size=Vector2i(1080,1920);await process_frame;await process_frame
	log_line("屏幕 "+str(root.get_visible_rect().size))
	assert(root.get_visible_rect().size==Vector2(540,960))
	Engine.time_scale=3.0
	var save:=OS.get_user_data_dir()+"/review-doors.json";DirAccess.remove_absolute(save);DirAccess.remove_absolute(save+".bak")
	h=load("res://ayu_home/home.tscn").instantiate();h.town_profile={"id":"review-doors","avatar":2,"nick":"体验师"};h.save_path=save
	root.add_child(h);await process_frame;await process_frame
	h.set_test_clock(14.5);h.admitted=true;h.close_modal();h.sound_on=false
	await wait(0.5)
	var rooms:Array=only_rooms if not only_rooms.is_empty() else h.definitions.keys()
	if only in ["","doors"]:
		log_line("=== A 每扇门三种走法：点门的气泡 / 点门外看得见的地方（或门槛） / 方向键朝门外一直按 ===")
		var total:=0;var bad:=0
		for room in rooms:
			for d in h.definitions[room].doors:
				var inward:Vector2=h.dir(str(d.face));var appr:Vector2=World.v(d.approach)
				for mode in ["气泡","点门外","方向键"]:
					h.enter_room(room,false);h.transition=false
					var start:Vector2=h.world.nearest(appr+inward*70)
					await put(room,start)
					var ok_start:=true;var note:=""
					match mode:
						"气泡":
							var btn:Button=null
							for m in h.marker_nodes:
								if str(m.hot.id)==str(d.id) and m.button.visible:btn=m.button
							if btn==null:
								# 气泡没出来：退一步点门本身（世界里门的位置，离 22 像素内算点到门）
								var s:=scr(World.v(d.pos))
								note="气泡没出来，改点门的位置"
								if on_screen(s):await tap(s)
								else:ok_start=false;note="气泡没出来，门也不在屏上"
							else:await tap(btn.get_global_rect().get_center())
						"点门外":
							var plane:Dictionary=h.world.door_plane(d);var beyond:Vector2=plane.point+plane.normal*40
							var s:=scr(beyond)
							if h.canvas_key(room)==h.canvas_key(str(d.target)) and on_screen(s):await tap(s);note="点门外 40 像素"
							else:
								s=scr(plane.point)
								if on_screen(s):await tap(s);note="点门槛"
								else:ok_start=false;note="门槛不在屏上"
						"方向键":
							var outward:Vector2=-inward;var code:Key=KEY_RIGHT if outward.x>0.5 else (KEY_LEFT if outward.x<-0.5 else (KEY_DOWN if outward.y>0.5 else KEY_UP))
							key(code,true);await wait(0.25)
							var r:=await idle_until(8.0,room)
							key(code,false)
							if h.area==room:
								# 按到底没过：记录停在哪
								note="停在"+str(h.player.position.round())+" 门站位"+str(h.world.nearest(appr).round())
					var took:float=-3.0
					if mode!="方向键" and ok_start:took=await idle_until(25.0,room)
					await wait(0.3)
					var ok:bool=h.area==str(d.target)
					# 到了以后 2 秒内不被弹回去
					var bounce:=false
					if ok:
						var arrived:String=h.area;await wait(1.5)
						if h.area!=arrived:bounce=true;ok=false
					var stuck:=false
					if ok:
						# 到了的地方能走回房间中间
						var route:PackedVector2Array=h.world.path(h.player.position,h.world.spawn())
						stuck=route.is_empty() and h.player.position.distance_to(h.world.spawn())>8
					total+=1
					var tag:="过" if ok and not stuck else "没过"
					if not ok or stuck:bad+=1
					log_line("%s %s→%s [%s] %s 到了 %s %s%s%s"%[tag,room,d.target,d.id,mode,h.area,note," 被弹回" if bounce else ""," 到了卡住" if stuck else ""])
		log_line("A 合计 %d 次，没过 %d 次"%[total,bad])
	if only in ["","ghost"]:
		log_line("=== B 点屏幕上随便一处地面：本间的地面不被门带走；隔壁的地面能自己穿门过去 ===")
		var rng:=RandomNumberGenerator.new();rng.seed=1005
		var ghosts:=0;var walks:=0;var through_ok:=0;var through_bad:=0;var blocked:=0
		for room in rooms:
			var n:=0;var tries:=0;var room_ghost:=0;var room_through:=0;var room_tbad:=0
			await put(room,Vector2.INF)
			while n<30 and tries<400:
				tries+=1
				if h.area!=room:await put(room,Vector2.INF)
				var size:Vector2=root.get_visible_rect().size
				var s:=Vector2(rng.randf_range(20,size.x-20),rng.randf_range(h.hud_bottom()+30,size.y-100))
				var p:Vector2=h.world.get_global_transform_with_canvas().affine_inverse()*s
				var mine:bool=h.world.passable(p)
				var near_door:=false
				for d in h.world.cfg.doors:
					if p.distance_to(h.world.nearest(World.v(d.approach)))<70:near_door=true
				if near_door:continue
				# 点到人、物件上的跳过（那是点物件）
				var on_hot:=false
				for hh in h.world.cfg.hotspots+h.world.cfg.doors:
					if p.distance_to(World.v(hh.pos))<26:on_hot=true
				for id in h.people:
					if h.people[id].visible and h.people[id].position.distance_to(p)<50:on_hot=true
				if on_hot:continue
				var other:="";var other_pt:=Vector2.ZERO
				if not h.world.walkable(p):
					var key_c:String=h.canvas_key(room);var at:Vector2=h.to_canvas(room,p)
					for r2 in h.definitions:
						if r2==room or h.canvas_key(r2)!=key_c:continue
						var q:Vector2=h.from_canvas(r2,at)
						if h.nav(r2).passable(q):other=r2;other_pt=q;break
				if not mine and other.is_empty():continue
				n+=1;walks+=1
				var start:Vector2=h.player.position
				await tap(s)
				var r:=await idle_until(40.0,room)
				if not other.is_empty():
					# 期望：穿门进隔壁（可能隔几间），最后停在点的地方附近
					var t0:=Time.get_ticks_msec()
					var still:=0.0
					while (Time.get_ticks_msec()-t0)/1000.0*Engine.time_scale<40:
						await process_frame
						if h.pending.is_empty() and h.player.route.is_empty() and not h.transition:
							if still==0.0:still=Time.get_ticks_msec()
							elif (Time.get_ticks_msec()-still)/1000.0*Engine.time_scale>1.5:break
						else:still=0.0
					var dist:float=h.player.position.distance_to(h.world.nearest(other_pt)) if h.area==other else 9999.0
					if h.area==other and dist<16:through_ok+=1;room_through+=1
					else:
						through_bad+=1;room_tbad+=1
						log_line("  点隔壁不顺 %s 点了 %s 的地面 %s → 到了 %s 离点的地方 %.0f"%[room,other,str(other_pt.round()),h.area,dist])
					await put(room,start)
				else:
					if h.area!=room:
						ghosts+=1;room_ghost+=1
						var last:Dictionary=h.transition_log.back() if not h.transition_log.is_empty() else {}
						log_line("  看不见的门 %s 从%s 点地面去%s 半路在%s 被带到 %s"%[room,str(start.round()),str(p.round()),str(last.get("position","?")),h.area])
						await put(room,start)
			log_line("%s 点了 %d 次：本间地面被带走 %d 次；点隔壁顺 %d 次、不顺 %d 次"%[room,n,room_ghost,room_through,room_tbad])
		log_line("B 合计 %d 次；本间地面被门带走 %d 次；点隔壁顺 %d / 不顺 %d"%[walks,ghosts,through_ok,through_bad])
	if only in ["","wall"]:
		log_line("=== C 点墙、家具、水：有没有「这里过不去」 ===")
		for room in rooms:
			await put(room,Vector2.INF)
			var said:=0;var tried:=0;var silent:=0
			var rng:=RandomNumberGenerator.new();rng.seed=7
			for i in 200:
				if tried>=8:break
				var size:Vector2=root.get_visible_rect().size
				var s:=Vector2(rng.randf_range(20,size.x-20),rng.randf_range(h.hud_bottom()+30,size.y-100))
				var p:Vector2=h.world.get_global_transform_with_canvas().affine_inverse()*s
				if h.world.walkable(p) or h.world.passable(p):continue
				var on_hot:=false
				for hh in h.world.cfg.hotspots+h.world.cfg.doors:
					if p.distance_to(World.v(hh.pos))<26:on_hot=true
				if on_hot:continue
				var key_c:String=h.canvas_key(room);var at:Vector2=h.to_canvas(room,p);var other:=false
				for r2 in h.definitions:
					if r2!=room and h.canvas_key(r2)==key_c and h.nav(r2).passable(h.from_canvas(r2,at)):other=true
				if other:continue
				tried+=1;h.player.bubble.text="";await tap(s);await wait(0.2)
				if h.player.bubble.text.contains("过不去"):said+=1
				else:silent+=1
				await put(room,Vector2.INF)
			log_line("%s 点了 %d 处墙/家具/水：说「过不去」%d 次，没说 %d 次"%[room,tried,said,silent])
	if only in ["","spots"]:
		log_line("=== D 每样东西点一遍（点气泡）：点了有什么反应、会不会被带走 ===")
		var none:=0;var moved:=0;var cnt:=0
		for room in rooms:
			for spot in h.definitions[room].hotspots:
				await put(room,Vector2.INF);h.player.bubble.text="";h.note="";var before_note:String=h.shown_note
				h.go(str(spot.id));var r:=await idle_until(25.0,room);await wait(0.5)
				var what:=""
				if h.games.root:what="小游戏「"+str(h.games.TITLES.get(h.games.kind,h.games.kind))+"」"
				elif h.activities.root:what="小游戏 "+h.activities.kind
				elif h.immersive.root:what="全屏 "+h.immersive.kind
				elif h.photo.root:what="拍立得"
				elif h.modal:
					var texts:=[]
					for l in h.modal.find_children("*","Label",true,false).slice(0,2):texts.append(l.text.left(18))
					what="页面"+str(texts)
				var talk:=""
				for id in h.people:
					if h.people[id].visible and h.people[id].bubble_time>0:talk+=id+"「"+h.people[id].bubble.text+"」"
				var btns:=[]
				if h.scene_controls:
					for b in h.scene_controls.find_children("*","Button",true,false):btns.append(b.text)
				cnt+=1
				var react:bool=not what.is_empty() or h.player.bubble_time>0 or not talk.is_empty() or not btns.is_empty() or not h.note.is_empty()
				if not react:none+=1
				if h.area!=room:moved+=1
				log_line("%s %s「%s」→ %s 人说「%s」%s 按钮%s 提示「%s」%s%s"%[room,spot.id,spot.label,what,h.player.bubble.text if h.player.bubble_time>0 else "",talk,str(btns),h.note,"" if react else " 【没反应】"," 【被带到"+h.area+"】" if h.area!=room else ""])
		log_line("D 合计 %d 样，没反应 %d，被带走 %d"%[cnt,none,moved])
	var f:=FileAccess.open(out,FileAccess.WRITE);f.store_string("\n".join(lines));f.close()
	h.stop_audio();h.queue_free();await process_frame;quit()
