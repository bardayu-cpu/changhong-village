extends RefCounted
## Ambient walkers: pause at each end, keep a continuous foot position, and
## give the player room. Coordinates are feet in the scene's world plane.
var states: Array[Dictionary] = []
var walkers: Array = []
func setup(config: Array) -> void:
	walkers = config
	states.clear()
	for w: Dictionary in walkers:
		var a := _point(w.a)
		var b := _point(w.b)
		var phase := fposmod(float(w.get("phase", 0)), 1.0)
		var returning := phase >= 0.5
		var fraction := (1.0 - phase) * 2.0 if returning else phase * 2.0
		states.append({"pos":a.lerp(b,fraction),"returning":returning,"pause":0.0,"distance":0.0,"heading":(a-b if returning else b-a).normalized(),"walking":false})
func advance(dt: float, player: Vector2, player_visible: bool) -> void:
	for i in range(states.size()):
		var state: Dictionary = states[i]
		var w: Dictionary = walkers[i]
		state.walking = false
		if state.pause > 0:
			state.pause = maxf(0, state.pause - dt)
			continue
		var target := _point(w.a if state.returning else w.b)
		var from: Vector2 = state.pos
		if from.distance_to(target) < 0.3:
			state.returning = not state.returning
			state.pause = float(w.get("pause", 1.2))
			continue
		var next := from.move_toward(target, float(w.get("speed", 30)) * dt)
		var personal_space := float(w.get("radius", 12))
		if player_visible and bool(w.get("avoidPlayer", true)) and next.distance_to(player) < personal_space and next.distance_to(player) < from.distance_to(player):
			continue
		# Scene authors give nearby walkers distinct lanes. This final guard
		# prevents rear-end overlap without teleporting a pedestrian sideways.
		var blocked := false
		for j in range(states.size()):
			if i == j: continue
			var other: Dictionary = states[j]
			if next.distance_to(other.pos) < personal_space and next.distance_to(other.pos) < from.distance_to(other.pos) and state.heading.dot(other.heading) > 0.5:
				blocked = true
				break
		if blocked: continue
		state.pos = next
		state.walking = true
		state.heading = (target - from).normalized()
		state.distance += from.distance_to(next)
func at(index: int) -> Dictionary:
	return states[index]
static func _point(value: Array) -> Vector2:
	return Vector2(float(value[0]),float(value[1]))
