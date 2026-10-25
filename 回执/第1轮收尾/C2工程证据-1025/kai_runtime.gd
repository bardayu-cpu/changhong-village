extends SceneTree
const Actor=preload("res://ayu_home/v4/actor.gd")
const Residents=preload("res://ayu_home/v4/core/residents.gd")
var failures:Array=[]
var sampled:Array=[]
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var actor:=Actor.new();actor.look_override=Residents.look("kaikai");root.add_child(actor);actor.setup("visitor")
	if not actor.chosen_look.has("sit") or actor.sheet.get_size()!=Vector2(1280,84):failures.append("wrong resident sheet")
	for direction in 4:
		actor.face=Actor.DIRS[direction];actor.walking=true;actor.action="idle"
		for frame in 4:
			actor.elapsed=(frame+.1)/8.0;actor.pose()
			var wanted:=(direction*4+frame)*64
			if actor.pose_texture.region!=Rect2(wanted,0,64,84):failures.append("walk frame "+str(direction)+":"+str(frame))
			sampled.append(actor.pose_texture.region.position.x/64)
		actor.walking=false;actor.pose()
		if actor.pose_texture.region.position.x!=direction*4*64:failures.append("idle direction")
		actor.action="sit";actor.lift=12;actor.pose()
		if actor.pose_texture.region!=Rect2((16+direction)*64,0,64,84):failures.append("seat crop")
		if actor.sprite.position!=Vector2(-32,-96):failures.append("seat lift")
		actor.lift=0
	print(JSON.stringify({"pass":failures.is_empty(),"walk_frames":sampled,"sit_directions":4,"failures":failures,"boundary":"frame selection and offsets only; chair visual and real movement still C3"}))
	actor.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
