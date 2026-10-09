extends SceneTree
## Deterministic acceptance reel, rendered by Godot Movie Maker; overrides only this QA scene.
const Home = preload("res://ayu_home/home.gd")
const Data = preload("res://ayu_home/home_data.gd")
var home

func _initialize() -> void:
	call_deferred("run")

func wait_frames(seconds: float) -> void:
	for frame in range(int(seconds * 20)): await process_frame

func show(area: String, hour: float, month: int, focus := "") -> void:
	home._close_panel()
	if is_instance_valid(home.activities.root): home.activities.close()
	home.set_test_clock(hour,month)
	home.admitted = area in ["floor1","floor2"]
	home._switch_area(area)
	for spot in Data.hotspots(area):
		if spot.id == focus: home.player.position = home.world.nearest(spot.approach)
	home._camera(true)

func run() -> void:
	root.size = Vector2i(540,960)
	home = Home.new()
	home.save_path = "/private/tmp/ayu-reel-life.json"
	home.hour_override = 12.5
	home.month_override = 10
	root.add_child(home)
	await wait_frames(.5)
	show("exterior",12.5,10,"door")
	await wait_frames(2)
	home._knock()
	await wait_frames(2)
	show("floor1",12.5,10,"meal")
	await wait_frames(3)
	show("floor1",13.5,10,"mahjong")
	await wait_frames(3)
	show("floor2",13.5,10,"guitar")
	await wait_frames(2)
	home._open_activity("guitar")
	for note in home.activities.melody:
		home.activities._strum(note)
		await wait_frames(.2)
	await wait_frames(1)
	show("floor2",13.5,10,"relax")
	home._interact("relax")
	await wait_frames(2)
	home._activity_closed()
	await wait_frames(1)
	show("floor2",11.5,10,"puzzle")
	home._open_activity("puzzle")
	for i in range(8):
		home.activities._hint()
		await wait_frames(.25)
	await wait_frames(1)
	show("floor1",20.5,10,"album")
	home._open_activity("album")
	await wait_frames(2)
	for month in [4,7,10,1]:
		show("garden",15.5,month,"fruit")
		home.overview = true
		home._camera(true)
		await wait_frames(2)
	home._open_activity("garden")
	for i in range(3): home.activities.garden_panel.plant(i,Data.CROPS[3][i])
	home.activities.garden_panel.water_all()
	await wait_frames(3)
	home.activities.close()
	home._life_book()
	await wait_frames(2)
	quit()
