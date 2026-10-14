extends SceneTree
const World=preload("res://ayu_home/v4/world.gd")
const Home=preload("res://ayu_home/v4/home.gd")
const Actor=preload("res://ayu_home/v4/actor.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var w:=World.new();root.add_child(w);w.set_process(false);w.load_room("v_h3")
	var h:=Home.new();h.world=w
	var actor:=Actor.new();w.actors.add_child(actor);actor.setup("visitor");actor.set_process(false);h.player=actor
	var at:=Vector2(90,415);var p:Dictionary=w.props[0]
	var checks:={"one_independent_chair_prop":w.props.size()==1 and p.config.id=="mill_tea_chair","existing_background_atlas_no_new_raster":p.sprite.texture is AtlasTexture and p.sprite.texture.region==Rect2(44,367,86,94),"actual_sprite_alpha_covers_original_seat":h.prop_covers(p,at),"actual_seat_lift_uses_chair_depth":is_equal_approx(h.seat_lift(at),47.0)}
	h.place_seated(at)
	checks["displayed_seat_anchor_unchanged"]=(actor.position-Vector2(0,actor.lift)).is_equal_approx(at)
	checks["seated_actor_sorted_after_chair_front"]=(actor.position.y>float(p.config.foot))
	var failures:=0
	for label in checks:
		print("PASS " if checks[label] else "FAIL ",label)
		if not checks[label]:failures+=1
	FileAccess.open("res://../回执/第1轮返工/磨坊椅子-遮挡核对.json",FileAccess.WRITE).store_string(JSON.stringify({"mode":"headless real sprite alpha/seat-depth; C3 actual sitting image pending","failures":failures,"checks":checks},"\t")+"\n")
	h.world=null;h.player=null;h.free();w.queue_free();await process_frame
	quit(0 if failures==0 else 1)
