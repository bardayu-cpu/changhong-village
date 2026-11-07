extends RefCounted
## Preserve old beat snapshots when tutorial cards or the letter sequence move.
static func migrate(state: Dictionary, shot: Dictionary) -> bool:
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://hongyuan/scene_migrations.json"))
	var old: Array = baseline.get(str(shot.fullId), [])
	var current: Array = shot.scene.get("beats", [])
	var index := int(state.get("sceneBeat", 0))
	if old.is_empty() or index < 0 or index >= old.size():
		return false
	var saved_sig := str(state.get("sceneSig", ""))
	if saved_sig != "" and saved_sig != str(JSON.stringify(old).hash()):
		return false
	var snapshot: Dictionary = state.get("sceneSnapshot", {}).duplicate(true)
	var beat: Dictionary = old[index]
	var new_index := current.find(beat)
	if str(shot.chapterId) == "finale":
		# A previously filled invitation keeps identity; it still gets sent and opened.
		var guest: Dictionary = state.get("guest", snapshot.get("result", {}))
		var game: Dictionary = snapshot.get("game", {})
		var name := str(game.get("name", guest.get("name", "")))
		if name.length() >= 2:
			for i in range(current.size()):
				if str(current[i].get("game", "")) == "finale": new_index = i
			var old_phase := str(game.get("phase", ""))
			var phase := old_phase if old_phase in ["name", "seal"] else "write"
			if old_phase in ["stamped", "done"] or not guest.is_empty(): phase = "ready_send"
			var look := int(game.get("look", int(str(guest.get("look", "01"))) - 1))
			game = {"phase": phase, "name": name, "look": look, "typed": 0.0, "hold": 0.0, "t": 0.0}
			snapshot = {"mode": "game", "game": game, "result": guest}
	if new_index < 0:
		return false
	state.sceneBeat = new_index
	snapshot.beat = new_index
	state.sceneSnapshot = snapshot
	return true
