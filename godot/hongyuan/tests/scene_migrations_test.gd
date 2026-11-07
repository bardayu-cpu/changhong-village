extends SceneTree
const Migration := preload("res://hongyuan/scene_migrations.gd")
var failures := 0
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures += 1
func _initialize() -> void:
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://hongyuan/scene_migrations.json"))
	for chapter in ["chengdu","call","shizuoka","hainan","hongkong"]:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://hongyuan/chapters/%s.json" % chapter))
		for shot: Dictionary in data.steps:
			if not shot.has("scene"): continue
			shot.fullId = chapter + "/" + str(shot.id)
			shot.chapterId = chapter
			var baseline: Array = old[shot.fullId]
			var game_index := -1
			for i in range(baseline.size()):
				if baseline[i].has("game"): game_index=i;break
			if game_index < 0: continue
			var state := {"sceneSig":str(JSON.stringify(baseline).hash()),"sceneBeat":game_index,"sceneSnapshot":{"beat":game_index,"mode":"game","feet":[122,440],"game":{"phase":"wait","t":0.4}}}
			check(Migration.migrate(state,shot),chapter+" old beat maps after inserted goal card")
			check(shot.scene.beats[state.sceneBeat] == baseline[game_index] and state.sceneSnapshot.feet == [122,440],chapter+" preserves active game and location")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://hongyuan/chapters/finale.json"))
	var finale: Dictionary = data.steps[0]
	finale.fullId="finale/finale";finale.chapterId="finale"
	var state := {"sceneBeat":2,"sceneSnapshot":{"beat":2,"mode":"game","game":{"phase":"look","name":"旧朋友","look":5}}}
	check(Migration.migrate(state,finale),"old finale identity migrates")
	check(state.sceneSnapshot.game.name == "旧朋友" and state.sceneSnapshot.game.phase == "write" and state.sceneSnapshot.game.look == 5, "old unfinished invitation preserves name and reaches writing")
	print("FAILURES ",failures)
	quit(failures)
