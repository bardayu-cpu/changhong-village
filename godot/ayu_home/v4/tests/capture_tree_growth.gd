extends SceneTree
const Home=preload("res://ayu_home/v4/home.gd")
var vp:SubViewport
var h
func _initialize() -> void:call_deferred("run")
func shot(name:String) -> void:
 for i in 8:await process_frame
 await process_frame;RenderingServer.force_draw(false)
 vp.get_texture().get_image().save_png("res://ayu_home/v4/evidence/panels/tree-"+name+".png")
func run() -> void:
 vp=SubViewport.new();vp.size=Vector2i(540,960);vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp)
 h=Home.new();h.save_path="/private/tmp/ayu-tree-growth-final.json";h.town_profile={"id":"tree-growth-final","avatar":2};vp.add_child(h);await process_frame;h.set_process(false);h.close_modal();h.enter_room("grove",false)
 h.life.now_override=1000000;h.life.data.trees=[{},{}];h.life.pack_seeds(10);h.life.data.seeds.apple=2
 assert(h.life.till(0,true));assert(h.life.plant(0,"apple",10,true));assert(h.life.water(0,true))
 h.games.open("tree",h.life,{"month":10,"sound":false});await shot("sapling")
 h.life.now_override+=130000;await shot("growing")
 h.life.now_override+=130000;await shot("ripe")
 assert(h.life.harvest(0,true).size()>0);assert(h.life.data.trees[0].grown);await shot("after-harvest")
 h.stop_audio();vp.queue_free();await process_frame;print("RESULT PASS tree growth appearance, mature tree retained after harvest");quit()
