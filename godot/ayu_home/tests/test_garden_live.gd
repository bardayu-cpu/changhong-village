extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var Activities = load("res://ayu_home/activities.gd")
	var panel = Activities.new()
	root.add_child(panel)
	var state := {}
	panel.open("garden", {"month":10, "garden_state":state})
	var garden = panel.garden_panel
	var start := Time.get_unix_time_from_system()
	garden.plant(0, "南瓜")
	garden.water_all()
	garden.harvest(0)
	assert(state.harvest_total == 0)
	panel.close()
	print("GARDEN_LIVE_STARTED real Unix=", start, " closed while growing")
	await create_timer(61).timeout
	panel.open("garden", {"month":10, "garden_state":state})
	panel.garden_panel.harvest(0)
	assert(state.harvest_total == 1 and state.basket["南瓜"] == 1)
	panel.garden_panel.harvest(0)
	assert(state.harvest_total == 1)
	panel.close()
	panel.queue_free()
	await process_frame
	print("GARDEN_LIVE_PASS real wait seconds=", Time.get_unix_time_from_system() - start, " offline growth / re-open / harvest once")
	quit()
