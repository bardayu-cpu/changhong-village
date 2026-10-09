extends SceneTree
const Home=preload("res://ayu_home/v4/home.gd")
var h
func _initialize() -> void:call_deferred("run")
func run() -> void:
	h=Home.new();h.town_profile={"id":"core-ui-qa","avatar":2};h.save_path="/tmp/village-ui-old.json";root.add_child(h)
	await create_timer(1).timeout
	h.close_modal();h.village_ui.show_page("田边")
	await create_timer(.5).timeout
	for page in ["田边","灶屋","牌子","村长","院子","篮子"]:
		h.village_ui.show_page(page);await create_timer(.3).timeout
		if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../交付/界面-"+page+".png"))
		print("PAGE ",page," buttons=",h.village_ui.root.find_children("*","Button",true,false).size())
	h.village_ui.close();h.stop_audio();h.queue_free();await process_frame
	print("RESULT PASS UI");quit()
