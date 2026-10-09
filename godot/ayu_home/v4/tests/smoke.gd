extends SceneTree
const Home=preload("res://ayu_home/v4/home.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var vp:=SubViewport.new();vp.size=Vector2i(540,960);root.add_child(vp)
	var h=Home.new();h.town_profile={"id":"v4-smoke-isolated","avatar":2,"nick":"试玩客人"};h.save_path="/private/tmp/ayu-v4-smoke-life.json";vp.add_child(h);await process_frame
	h.set_test_clock(12.25);h.admitted=true;h.close_modal();await create_timer(1).timeout
	for room in h.definitions:
		h.enter_room(room,false);await process_frame;await process_frame;h._process(.016);print("ROOM ",room," ",h.player.position)
	for kind in h.Games.TITLES:
		h.games.open(kind,h.life,{"hour":20.0,"month":10});await process_frame;await process_frame;h.games.close();print("GAME ",kind)
	h.enter_room("living",false);h.take_photo();await process_frame;await process_frame;h.photo.close();print("PHOTO READY")
	h.stop_audio();vp.queue_free();await process_frame;print("SMOKE COMPLETE");quit()
