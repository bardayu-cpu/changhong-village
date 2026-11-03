extends SceneTree
const World=preload("res://ayu_home/v4/world.gd")
const Home=preload("res://ayu_home/v4/home.gd")
const Actor=preload("res://ayu_home/v4/actor.gd")
const Institution=preload("res://ayu_home/v4/core/institution_room.gd")

class FixtureUI extends Node:
	var home
	var opened:=false
	var state:Dictionary={"data":{"village":{"institutions":{}}}}

func _initialize() -> void:call_deferred("run")

func run() -> void:
	var rows:Array=[]
	var failures:=0
	for room in ["v_h3","v_h5","v_mayor","my_cabin"]:
		var world:=World.new();root.add_child(world);world.set_process(false);world.load_room(room)
		var home:=Home.new();home.world=world;home.area=room;home.hour=9.0
		var owner:=FixtureUI.new();owner.home=home;root.add_child(owner)
		var institution:=Institution.new();root.add_child(institution);institution.set_process(false);institution.setup(owner)
		institution.actor.set_process(false)
		for hour in [9.0,13.0,19.0]:
			home.hour=hour;institution.sync_schedule(true);institution.actor.pose()
			var slot:Dictionary=world.cfg.resident.schedule[institution.current_slot()]
			var actor=institution.actor
			var checks:={
				"scheduled_action_retained":actor.action==str(slot.action),
				"scheduled_face_retained":actor.face==str(slot.face),
				"visual_anchor_retained":(actor.position-Vector2(0,actor.lift)).is_equal_approx(Vector2(slot.pos[0],slot.pos[1])),
				"settled_visible_resident":institution.settled and actor.visible,
				"existing_resident_texture_loaded":actor.sheet!=null and actor.sheet.get_width()>0 and actor.sprite.texture!=null,
				"institution_hand_overlays_disabled":not actor.draw_hand_overlays,
				"work_layer_still_connected":institution.work_layer.draw.is_connected(institution.draw_work)
			}
			for value in checks.values():
				if not value:failures+=1
			rows.append({"room":room,"hour":hour,"action":actor.action,"checks":checks})
			print(room," ",hour," ",actor.action," ",checks)
		institution.queue_free();owner.queue_free();world.queue_free();home.world=null;home.free()
		await process_frame
	var ordinary:=Actor.new()
	var ordinary_unchanged:bool=ordinary.draw_hand_overlays
	ordinary.free()
	if not ordinary_unchanged:failures+=1
	var result:={"mode":"Headless native institution setup/schedule/pose check; not visual acceptance or a C3 playtest.","failures":failures,"schedule_cases":rows,"non_institution_overlay_default_preserved":ordinary_unchanged,"no_game_state_or_save_instantiated":true}
	FileAccess.open("res://../回执/第1轮返工/A1-二修-机构活动预检.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n")
	print("A1_SECOND_FIX failures=",failures," schedule_cases=",rows.size())
	quit(0 if failures==0 else 1)
