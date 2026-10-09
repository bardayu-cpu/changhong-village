extends SceneTree
const Home=preload("res://ayu_home/v4/home.gd")
var h
var vp:SubViewport
var out:="res://ayu_home/v4/evidence/visual/"
func _initialize() -> void:call_deferred("run")
func shot(tag:String) -> void:
	await process_frame;await process_frame;await process_frame;RenderingServer.force_draw(false)
	vp.get_texture().get_image().save_png(out+tag+".png");print("SHOT ",tag)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	vp=SubViewport.new();vp.size=Vector2i(540,960);vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp)
	h=Home.new();h.town_profile={"id":"visual-test","avatar":2};h.save_path="/private/tmp/ayu-v4-visual.json";vp.add_child(h);await process_frame;h.set_test_clock(12.25);h.admitted=true;h.close_modal();h.set_process(false)
	for room in h.definitions:
		h.enter_room(room,false);h._process(.016);await shot(room)
	for kind in ["tea","soup","wood","garden","stars"]:
		h.games.open(kind,h.life,{"hour":20.0,"month":10});await shot("play-"+kind);h.games.close()
	h.enter_room("living",false);h.take_photo();await shot("photo");h.photo.close();h.talk("ayu");h.talk_chars=1000;h._process(.016);await shot("talk")
	h.stop_audio();vp.queue_free();await process_frame;quit()
