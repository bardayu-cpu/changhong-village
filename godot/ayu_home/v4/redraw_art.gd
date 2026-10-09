extends RefCounted
## Rendering only. Artwork is deliberately sampled to coarse, hard-edged pixels.
const Assets=preload("res://ayu_home/v2/assets.gd")
const ROOT="res://ayu_home/v4/assets/floor1-redraw/"
const DISHES={"春笋豆腐":0,"豌豆蒸蛋":1,"萝卜清汤":2,"番茄炒蛋":3,"清拌黄瓜":4,"冬瓜汤":5,"南瓜小盅":6,"胡萝卜焖饭":7,"菌菇清汤":8,"白菜炖豆腐":9,"清炒菠菜":10,"热乎萝卜汤":11,"葱香煎蛋":12,"家常豆腐":13,"清蒸时蔬":14,"一起煮的家常汤":15}
static func sprite(canvas:CanvasItem,name:String,area:Rect2,alpha:=1.0) -> void:
	var tex=Assets.texture(ROOT+name+".png")
	if not tex:return
	var ratio:=minf(area.size.x/tex.get_width(),area.size.y/tex.get_height())
	var size:Vector2=(tex.get_size()*ratio).round()
	canvas.draw_texture_rect(tex,Rect2((area.get_center()-size*.5).round(),size),false,Color(1,1,1,alpha))
static func scene(canvas:CanvasItem,name:String) -> void:
	var tex=Assets.texture(ROOT+name+".png")
	if tex:canvas.draw_texture_rect(tex,Rect2(0,0,460,563),false)
static func dish(canvas:CanvasItem,name:String,at:Vector2) -> void:
	# 菜名对应哪张菜图由 life_state.gd 的 DISHES 决定（Claude 10/5 把菜单从 3 套扩到每天不一样）
	sprite(canvas,"meal-"+str(preload("res://ayu_home/v4/life_state.gd").dish_picture(name)),Rect2(at-Vector2(23,17),Vector2(46,34)))
