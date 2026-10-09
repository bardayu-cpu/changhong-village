extends SceneTree
const W=preload("res://ayu_home/v4/world.gd")
func _initialize() -> void:
	for spec in [["living","to_dining"],["stairs1","to_mahjong"],["stairs2","to_study"]]:
		var w=W.new();w.load_room(spec[0]);var d:Dictionary=w.spot(spec[1]);var path:PackedVector2Array=w.path(w.spawn(),w.v(d.approach));print(spec," ",d," last=",path.slice(maxi(0,path.size()-8))," plane=",w.door_plane(d));w.free()
	quit()
