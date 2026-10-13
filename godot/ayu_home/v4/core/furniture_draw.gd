extends RefCounted
const C=preload("res://ayu_home/v4/core/config.gd")
const Assets=preload("res://ayu_home/v2/assets.gd")
## 家具的实际摆放形象，以整数像素小块绘制，院子和布置页共用。
static func paint(node:CanvasItem,kind:String,rect:Rect2) -> void:
	if C.FURNITURE.has(kind) and C.FURNITURE[kind].has("texture"):
		var tex:=Assets.texture(C.FURNITURE[kind].texture);var scale_factor:=minf(rect.size.x/tex.get_width(),rect.size.y/tex.get_height());var fit:=tex.get_size()*scale_factor
		node.draw_texture_rect(tex,Rect2((rect.position+Vector2((rect.size.x-fit.x)/2,rect.size.y-fit.y)).round(),fit),false);return
	var unit:=rect.size/Vector2(48,48)
	var blocks:Array=[]
	if kind=="table":
		blocks=[[5,14,38,20,"4e3428"],[8,31,6,13,"71472e"],[34,31,6,13,"71472e"],[7,12,34,18,"b8874b"],[9,14,30,4,"d4aa65"],[9,23,30,2,"976137"]]
	elif kind=="chair":
		blocks=[[10,4,28,27,"5a3d2b"],[14,7,20,18,"b18147"],[10,28,5,16,"71472e"],[33,28,5,16,"71472e"],[8,24,32,10,"b8874b"],[10,24,28,4,"d4aa65"]]
	else:
		blocks=[[13,28,24,17,"774635"],[10,26,29,6,"b87853"],[16,32,18,11,"a96345"],[21,12,5,18,"4c6936"],[10,15,15,8,"648d41"],[25,8,13,9,"82a451"],[17,5,9,13,"92b456"],[8,12,7,6,"f1c858"],[29,5,7,7,"d98290"]]
	for b in blocks:
		node.draw_rect(Rect2(rect.position+Vector2(b[0],b[1])*unit,Vector2(b[2],b[3])*unit),Color(b[4]))
