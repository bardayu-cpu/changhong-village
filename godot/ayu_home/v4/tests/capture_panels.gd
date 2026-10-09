extends SceneTree
const Home=preload("res://ayu_home/v4/home.gd")
const Page=preload("res://ayu_home/v4/paper_page.gd")
const Old=preload("res://ayu_home/v3/home.gd")
var out:="res://ayu_home/v4/evidence/panels/"
var records:Array=[]
func _initialize() -> void:call_deferred("run")
func snap(vp:SubViewport,h,file:String) -> void:
	for i in 8:await process_frame
	await process_frame;RenderingServer.force_draw(false)
	vp.get_texture().get_image().save_png(out+file+".png")
	if h.modal and h.modal is Page:
		var page=h.modal;records.append({"file":file,"sheet":[page.panel.position.x,page.panel.position.y,page.panel.size.x,page.panel.size.y],"content_height":page.body.get_combined_minimum_size().y,"visible_content_height":page.scroll.size.y,"inside_viewport":page.panel.position.y>=0 and page.panel.position.y+page.panel.size.y<=h.get_viewport_rect().size.y+1})
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	for height in [960,1168]:
		var vp:=SubViewport.new();vp.size=Vector2i(540,height);vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp)
		if height==1168:vp.size=Vector2i(1170,2532);vp.size_2d_override=Vector2i(540,1168);vp.size_2d_override_stretch=true
		var h=Home.new();h.town_profile={"id":"panels-v4-"+str(height),"avatar":2};h.save_path="/private/tmp/ayu-v4-panels-"+str(height)+".json";vp.add_child(h);await process_frame;h.set_process(false);h.set_test_clock(12.25);h.admitted=true;h.close_modal();h.enter_room("dining",false);h.player.position=Vector2(262,318);h.camera=Vector2(185,253);h.layout();h._process(.016)
		await snap(vp,h,"dining-v4-"+str(height))
		for method in ["welcome","today","life_book","family_page","calendar_page","collection_page","album_page","settings_page","navigation","choose_avatar","recipe","pantry"]:
			h.call(method);await snap(vp,h,method+"-"+str(height));h.close_modal()
		for group in ["一楼","二楼","屋外"]:h.navigation(group);await snap(vp,h,"map-"+group+"-"+str(height));h.close_modal()
		h.test_panel_enabled=true;h.testing_panel();await snap(vp,h,"testing-"+str(height));h.close_modal();h.test_panel_enabled=false
		h.life.data.resident=true;h.life.data.invites={};h.check_meal_invite();await snap(vp,h,"meal-invite-"+str(height));h.dismiss_invite()
		h.family_card("mother");await snap(vp,h,"person-card-"+str(height));h.close_modal()
		for person in ["mother","father","ayu"]:
			h.dialogue(h.NAMES[person],"今天愿不愿意帮我煮一锅热汤？做好再来找我，我想听听你怎么做的。",person);h.talk_chars=999;h._process(.016);await snap(vp,h,"dialogue-"+person+"-"+str(height));h.close_modal()
		for kind in h.Games.TITLES:
			h.games.open(kind,h.life,{"hour":20.0,"month":10});await snap(vp,h,"play-"+kind+"-"+str(height))
			if kind=="stars":h.games.show_wish();await snap(vp,h,"wish-"+str(height))
			h.games.close(false)
		for kind in ["guitar","puzzle","album"]:h.activities.open(kind,{"v2_art":true});await snap(vp,h,"play-"+kind+"-"+str(height));h.activities.close()
		h.immersive.open("fish",{"fish":[]});await snap(vp,h,"play-fish-"+str(height));h.immersive.close(false)
		h.take_photo();await snap(vp,h,"polaroid-"+str(height));h.photo.close(false)
		h.stop_audio();vp.remove_child(h);h.queue_free();await process_frame
		var old=Old.new();old.save_path="/private/tmp/ayu-v3-compare.json";vp.add_child(old);await process_frame;old.set_process(false);old.set_test_clock(12.25);old.admitted=true;old.close_modal();old.enter_room("dining",false);old.player.position=Vector2(262,318);old.camera=old.player.position-Vector2(0,65);old.layout();await snap(vp,old,"dining-v3-"+str(height));old.stop_audio();vp.queue_free();await process_frame
	var f:=FileAccess.open(out+"audit.json",FileAccess.WRITE);f.store_string(JSON.stringify(records,"  "));f.close();print("RESULT PASS panel captures ",records.size());quit()
