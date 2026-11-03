extends RefCounted
## C4 native vector artwork. C2 copies this file and the JSON mechanically.
## Existing PNGs are reused without pixel edits; no gameplay state is stored here.
const ICON_FILE="res://ayu_home/v4/assets/ui/inventory-icons-v1.json"
const Assets=preload("res://ayu_home/v2/assets.gd")
static var definitions:Dictionary={}
static func paint(node:CanvasItem,id:String,rect:Rect2) -> void:
	if definitions.is_empty():definitions=JSON.parse_string(FileAccess.get_file_as_string(ICON_FILE))
	var entry:Dictionary=definitions.get(id,{})
	if entry.has("source"):
		var tex:Texture2D=Assets.texture(entry.source)
		if tex==null:return
		var ratio:float=minf(rect.size.x/tex.get_width(),rect.size.y/tex.get_height())
		var fit:Vector2=(tex.get_size()*ratio).round()
		node.draw_texture_rect(tex,Rect2((rect.get_center()-fit*.5).round(),fit),false);return
	if not entry.has("blocks"):return
	var canvas:Array=entry.canvas
	var ratio:float=minf(rect.size.x/canvas[0],rect.size.y/canvas[1])
	var origin:Vector2=(rect.get_center()-Vector2(canvas[0],canvas[1])*ratio*.5).round()
	for b in entry.blocks:
		var a:Vector2=(origin+Vector2(b[0],b[1])*ratio).round()
		var z:Vector2=(origin+Vector2(b[0]+b[2],b[1]+b[3])*ratio).round()
		node.draw_rect(Rect2(a,z-a),Color(b[4]))
