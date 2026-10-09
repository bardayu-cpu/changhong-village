extends SceneTree
const Home=preload("res://ayu_home/v2/home.gd")
var h
var surface:SubViewport
var checks:=0
var failures:=0
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures+=1;print("FAIL ",label)
func _initialize() -> void:call_deferred("run")
func touch(p:Vector2) -> void:
	var e:=InputEventScreenTouch.new();e.pressed=true;e.position=p;surface.push_input(e,true);await process_frame
	e=InputEventScreenTouch.new();e.pressed=false;e.position=p;surface.push_input(e,true);await process_frame
func press(text:String) -> void:
	for b in h.ui.find_children("*","Button",true,false):
		if b.text==text and b.is_visible_in_tree():
			check(b.size.y>=48*surface.size.x/540.0,"finger target "+text)
			await touch(b.get_global_rect().get_center());return
	check(false,"missing visible button "+text)
func wait_for_walk() -> void:
	for i in range(1400):
		if h.pending.is_empty() and h.player.route.is_empty():return
		h._process(1.0/30.0);await process_frame
	check(false,"walk timeout")
func run() -> void:
	for dim in [Vector2i(540,960),Vector2i(1170,2532)]:
		surface=SubViewport.new();surface.size=dim;surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(surface)
		h=Home.new();h.save_path="/private/tmp/ayu-v2-touch-%d.json"%dim.x;surface.add_child(h)
		await process_frame;await process_frame;h.set_test_clock(12.5)
		h.player.position=Home.World.v(h.world.spot("door").approach)+Vector2(0,60);h.camera=h.player.position-Vector2(0,170);h.layout()
		var door:Vector2=h.world.get_global_transform_with_canvas()*Home.World.v(h.world.spot("door").pos)
		await touch(door);check(h.pending=="door","real tap selects door");await wait_for_walk();await create_timer(.9).timeout
		check(h.phase=="invited" and not h.admitted,"door waits for invitation")
		await press("进屋");await create_timer(.7).timeout;check(h.area=="living","touch enters room")
		await press("看看屋里");check(h.modal!=null,"touch opens navigation")
		var before:Vector2=h.player.position;await touch(Vector2(4,400)*float(dim.x)/540);check(h.player.position==before and h.player.route.is_empty(),"modal prevents background walking")
		await press("去餐厅");await wait_for_walk();await create_timer(.7).timeout;check(h.area=="dining","touch navigation walks to door")
		await press("看看屋里");await press("倒一杯温水");await wait_for_walk();check(h.journal.found.has("餐桌边的一杯温水"),"touch object has durable response")
		await press("生活册");check(h.modal!=null,"journal accessible");await press("收起")
		# All three small games: real single-finger inputs, start-to-finish and early exit.
		for kind in ["guitar","puzzle","album"]:
			h.activities.open(kind,{"v2_art":true});await process_frame;await process_frame
			var a=h.activities
			if kind=="guitar":
				for idx in a.melody:await touch(a.note_buttons[idx].get_global_rect().get_center())
			elif kind=="puzzle":
				for i in range(9):
					if a.order[i]!=i:
						var j:int=a.order.find(i);await touch(a.tiles[i].get_global_rect().get_center());await touch(a.tiles[j].get_global_rect().get_center())
			else:
				for tile in a.album_tray:
					await touch(tile.get_global_rect().get_center());await touch(a.album_slots[tile.index].get_global_rect().get_center())
			check(a.finished,kind+" single finger complete")
			a.close();a.open(kind,{"v2_art":true});await process_frame;check(a.root!=null,kind+" restart");a.close();check(a.root==null,kind+" early exit")
		check(not h.journal.has("coins") and h.hour==12.5,"games no wallet/time mutation")
		h.stop_audio();await create_timer(.15).timeout
		surface.queue_free();await process_frame
	print("RESULT ","PASS" if failures==0 else "FAIL"," checks=",checks," failures=",failures);quit(failures)
