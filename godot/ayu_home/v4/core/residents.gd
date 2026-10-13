extends RefCounted
const Assets=preload("res://ayu_home/v2/assets.gd")
const XIAOTAO_ANIM={
	"down":{"idle":0,"walk":[1,0,2,0]},
	"up":{"idle":3,"walk":[4,3,5,3]},
	"right":{"idle":6,"walk":[7,6,8,6]},
	"left":{"idle":6,"walk":[7,6,8,6],"flip":true}}
const STANDARD_ANIM={"down":{"idle":0,"walk":[0,1,2,3]},"left":{"idle":4,"walk":[4,5,6,7]},"right":{"idle":8,"walk":[8,9,10,11]},"up":{"idle":12,"walk":[12,13,14,15]}}
static func look(id:String) -> Dictionary:
	if id=="xiaotao":return {"tex":Assets.texture("res://ayu_home/v4/assets/residents/xiaotao-v1.png"),"frame_w":64,"frame_h":84,"anim":XIAOTAO_ANIM}
	if id in ["kaikai"]:return {"tex":Assets.texture("res://ayu_home/v4/assets/residents/"+id+"-v1.png"),"frame_w":64,"frame_h":84,"anim":STANDARD_ANIM}
	return {}
