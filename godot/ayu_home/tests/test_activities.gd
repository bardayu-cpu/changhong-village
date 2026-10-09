extends SceneTree
var done_count := 0
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var Actor = load("res://ayu_home/actor.gd")
	var Activities = load("res://ayu_home/activities.gd")
	assert(Actor != null and Activities != null)
	var actor = Actor.new()
	root.add_child(actor)
	actor.setup("ayu")
	actor.set_direction("up")
	actor.set_walking(true)
	await process_frame
	actor.set_walking(false)
	actor.set_activity("sleep")
	await process_frame
	assert(actor.activity == "sleep")
	actor.set_activity("rest")
	actor.set_activity("mahjong")
	actor.set_activity("fish")
	assert(actor.activity == "feed_fish")
	var panel = Activities.new()
	root.add_child(panel)
	panel.completed.connect(func(_kind): done_count += 1)
	panel.open("puzzle")
	await process_frame
	assert(panel.order.size() == 9)
	for target in range(9):
		if panel.order[target] != target:
			var index = panel.order.find(target)
			panel._pick_tile(target)
			panel._pick_tile(index)
	assert(panel.finished and done_count == 1)
	panel._pick_tile(0)
	panel._pick_tile(0)
	assert(done_count == 1)
	panel.open("album")
	await process_frame
	for slot in [1, 4, 7]:
		panel.album_piece = slot
		panel._place_album(slot)
	assert(panel.finished and done_count == 2)
	panel.open("guitar")
	await process_frame
	panel._strum(panel.melody[0])
	panel.close()
	assert(not panel.clock_running and not panel.player.playing and panel.root == null)
	panel.open("guitar")
	await process_frame
	for note in panel.melody:
		panel._strum(note)
	assert(panel.finished and done_count == 3)
	for kind in ["relax", "fish", "tv", "record", "workbench"]:
		panel.open(kind)
		await process_frame
		for i in range(4): panel._fun_action()
		assert(panel.finished)
		panel.close()
	for season in range(4):
		var garden_state := {}
		panel.open("garden", {"season_index": season, "garden_state": garden_state})
		await process_frame
		var garden = panel.garden_panel
		garden.now_override = 1000.0
		assert(garden.season == season)
		for i in range(3): garden.plant(i, garden.Data.CROPS[season][i])
		garden.water_all()
		garden.harvest(0)
		assert(garden_state.harvest_total == 0)
		garden.now_override = 1061.0
		for i in range(3): garden.harvest(i)
		assert(garden_state.harvest_total == 3)
		panel.close()
		panel.open("garden", {"season_index": season, "garden_state": garden_state})
		await process_frame
		assert(panel.garden_panel.state.harvest_total == 3)
		panel.garden_panel.now_override = 1061.0
		panel.garden_panel.fruit_index = 2
		panel.garden_panel._fruit_action()
		var count = garden_state.harvest_total
		panel.garden_panel._fruit_action()
		assert(garden_state.harvest_total == count)
		panel.close()
	panel.queue_free()
	actor.queue_free()
	await process_frame
	await create_timer(0.25).timeout
	print("ACTIVITIES_PASS puzzle solve + once, album solve, guitar finish/exit, bed/action APIs, six panels")
	quit(0)
