extends RefCounted
## Match the complete archived script signature before interpreting a beat index.
## Unknown signatures are deliberately left to Player's safe scene restart.
static func _archived(baseline: Dictionary, full_id: String, signature: String) -> Array:
	var original: Array = baseline.get(full_id, [])
	if signature == "": return original # legacy pre-signature baseline only
	if not original.is_empty() and signature == str(JSON.stringify(original).hash()): return original
	for version: Dictionary in baseline.get("_versions", {}).get(full_id, []):
		var beats: Array = version.get("beats", [])
		if signature == str(JSON.stringify(beats).hash()): return beats
	return []

static func _key(beat: Dictionary) -> String:
	for name in ["game", "go", "material", "card", "button"]:
		if beat.has(name): return name+":"+str(beat[name])
	for name in ["say", "narrate"]:
		if beat.has(name): return "copy:"+str(beat[name])
	return ""

static func _find_key(beats: Array, key: String, occurrence := 0) -> int:
	for i in range(beats.size()):
		if _key(beats[i]) == key:
			if occurrence == 0: return i
			occurrence -= 1
	return -1

static func _same_beat(old: Array, index: int, current: Array) -> int:
	var key := _key(old[index])
	if key != "":
		var occurrence := 0
		for i in range(index):
			if _key(old[i]) == key: occurrence += 1
		var matched := _find_key(current,key,occurrence)
		if matched < 0 and key.begins_with("copy:"):
			for i in range(current.size()):
				if key.trim_prefix("copy:") in current[i].get("memory", []): return i
		return matched
	# Setup-only beats are not resumable interactions. Follow the next semantic
	# beat so repeated hide/show/background dictionaries cannot map backwards.
	for i in range(index+1,old.size()):
		if _key(old[i]) != "": return _same_beat(old,i,current)
	return -1

static func _new_entry(old: Array,index: int,current: Array,new_index: int) -> int:
	# An old awarded token remains awarded, but newly required play is not skipped.
	var care := _find_key(current,"game:care")
	if care >= 0 and _find_key(old,"game:care") < 0 and new_index > care:
		# Include the new instruction card and its scene setup before care.
		return maxi(0,care-2)
	var registry := _find_key(current,"game:registration")
	if registry >= 0 and _find_key(old,"game:registration") < 0:
		if _key(old[index]) in ["copy:A4-3a","copy:A4-3b","material:stamp"]:
			return registry
	# The old HK photo is the first photo, never one of the added Disney/campus
	# photos. Saves after it replay the newly added travel sequence before reward.
	var first_photo := _find_key(current,"game:photo")
	var second_photo := _find_key(current,"game:photo",1)
	if second_photo >= 0 and _find_key(old,"game:photo",1) < 0 and new_index > first_photo:
		return first_photo+1
	# Already underway later games keep their position; a save at an old walkway
	# starts at its newly required approach, rather than teleporting through it.
	if _key(old[index]) == "go:seat" and _find_key(old,"go:gangway_foot") < 0:
		var approach := _find_key(current,"go:gangway_foot")
		if approach >= 0: return approach
	if _key(old[index]) == "go:exit" and _find_key(old,"go:security") < 0:
		var security := _find_key(current,"go:security")
		if security >= 0: return security
	return new_index

static func migrate(state: Dictionary, shot: Dictionary) -> bool:
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://hongyuan/scene_migrations.json"))
	var old := _archived(baseline,str(shot.fullId),str(state.get("sceneSig", "")))
	var current: Array = shot.scene.get("beats", [])
	var index := int(state.get("sceneBeat", 0))
	if old.is_empty() or index < 0 or index >= old.size(): return false
	var snapshot: Dictionary = state.get("sceneSnapshot", {}).duplicate(true)
	var beat: Dictionary = old[index]
	var new_index := _same_beat(old,index,current)
	# Registration now owns the same original two memory lines.
	if new_index < 0 and _key(beat) in ["copy:A4-3a","copy:A4-3b"]:
		new_index = _find_key(current,"game:registration")
	if new_index >= 0: new_index = _new_entry(old,index,current,new_index)
	if str(shot.chapterId) == "finale":
		var guest: Dictionary = state.get("guest", snapshot.get("result", {}))
		var game: Dictionary = snapshot.get("game", {})
		var name := str(game.get("name", guest.get("name", "")))
		if name.length() >= 2:
			new_index = _find_key(current,"game:finale")
			var old_phase := str(game.get("phase", ""))
			var phase := old_phase if old_phase in ["name", "seal"] else "write"
			if old_phase in ["stamped", "done"] or not guest.is_empty(): phase = "ready_send"
			var look := int(game.get("look", int(str(guest.get("look", "01"))) - 1))
			game = {"phase": phase, "name": name, "look": look, "typed": 0.0, "hold": 0.0, "t": 0.0}
			snapshot = {"mode": "game", "game": game, "result": guest}
	elif new_index >= 0:
		var target: Dictionary = current[new_index]
		if _key(beat) == "" or _key(beat) != _key(target):
			# Keep identity/result, but never reuse another activity's mode/game state.
			snapshot = {"result": snapshot.get("result", {}).duplicate(true)}
		elif beat.has("game") and beat.has("lines") and target.has("lines") and snapshot.has("game"):
			var line_index := int(snapshot.game.get("li",0))
			if line_index >= 0 and line_index < beat.lines.size():
				var copy_id := str(beat.lines[line_index].get("say",""))
				var mapped_line := -1
				for i in range(target.lines.size()):
					if str(target.lines[i].get("say","")) == copy_id: mapped_line=i;break
				if mapped_line >= 0: snapshot.game.li=mapped_line
				else: snapshot={"result":snapshot.get("result",{}).duplicate(true)}
	if new_index < 0: return false
	state.sceneBeat = new_index
	snapshot.beat = new_index
	state.sceneSnapshot = snapshot
	return true
