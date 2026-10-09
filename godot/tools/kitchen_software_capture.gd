extends RefCounted
## Actual runtime CanvasItem tree and TextServer glyph images, rendered into Image without a GPU/window.
## Diagnostic offscreen rendering; it is not a native GPU screenshot or device verification.
var canvas: Image
var text_server = TextServerManager.get_primary_interface()
var glyph_images: Dictionary = {}

func capture(root: Node, dimensions := Vector2i(540,960)) -> Image:
    canvas = Image.create(dimensions.x,dimensions.y,false,Image.FORMAT_RGBA8)
    canvas.fill(Color("241e22"))
    _walk(root)
    return canvas

func _walk(node: Node) -> void:
    if node is CanvasItem:
        if not node.is_visible_in_tree() or node.is_queued_for_deletion(): return
        if node is TextureRect: _texture(node)
        elif node is ColorRect: _solid(node,node.color)
        elif node is Panel: _panel(node)
        elif node is Label: _label(node)
        elif node is Button and not str(node.text).is_empty(): _button_label(node)
        elif node is Line2D: _line(node)
    for child in node.get_children(): _walk(child)

func _modulate(node: CanvasItem) -> Color:
    var color: Color = node.self_modulate
    var current: Node = node
    while current is CanvasItem:
        color *= current.modulate
        current = current.get_parent()
    return color

func _screen_rect(node: Control) -> Rect2:
    var transform: Transform2D = node.get_global_transform_with_canvas()
    return Rect2(transform.origin,node.size*Vector2(transform.x.length(),transform.y.length()))

func _blend(image: Image, position: Vector2, tint := Color.WHITE) -> void:
    var copy: Image = image.duplicate()
    copy.convert(Image.FORMAT_RGBA8)
    if tint != Color.WHITE:
        for y in copy.get_height():
            for x in copy.get_width(): copy.set_pixel(x,y,copy.get_pixel(x,y)*tint)
    canvas.blend_rect(copy,Rect2i(Vector2i.ZERO,copy.get_size()),Vector2i(position.round()))

func _texture(node: TextureRect) -> void:
    if node.texture == null: return
    var texture: Texture2D = node.texture
    var image: Image
    if texture is AtlasTexture:
        image = texture.atlas.get_image().get_region(Rect2i(texture.region))
    else: image = texture.get_image()
    if image == null or image.is_empty(): return
    var rect := _screen_rect(node)
    var target := rect.size
    var at := rect.position
    if node.stretch_mode in [TextureRect.STRETCH_KEEP_ASPECT,TextureRect.STRETCH_KEEP_ASPECT_CENTERED,TextureRect.STRETCH_KEEP_ASPECT_COVERED]:
        var factor := minf(target.x/image.get_width(),target.y/image.get_height())
        if node.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED: factor = maxf(target.x/image.get_width(),target.y/image.get_height())
        target = Vector2(image.get_size())*factor
        if node.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT: at += (rect.size-target)/2.0
    image = image.duplicate()
    image.resize(maxi(1,roundi(target.x)),maxi(1,roundi(target.y)),Image.INTERPOLATE_NEAREST)
    if node.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED:
        image = image.get_region(Rect2i(Vector2i((rect.size-target)/-2.0),Vector2i(rect.size.round())))
        at = rect.position
    _blend(image,at,_modulate(node))

func _rect_image(size: Vector2i, color: Color, radius := 0.0) -> Image:
    var out := Image.create(maxi(1,size.x),maxi(1,size.y),false,Image.FORMAT_RGBA8)
    out.fill(color)
    var r := mini(roundi(radius),mini(out.get_width()/2,out.get_height()/2))
    for y in r:
        for x in r:
            if Vector2(r-x-0.5,r-y-0.5).length() > r:
                out.set_pixel(x,y,Color.TRANSPARENT)
                out.set_pixel(out.get_width()-x-1,y,Color.TRANSPARENT)
                out.set_pixel(x,out.get_height()-y-1,Color.TRANSPARENT)
                out.set_pixel(out.get_width()-x-1,out.get_height()-y-1,Color.TRANSPARENT)
    return out

func _solid(node: ColorRect, color: Color) -> void:
    var rect := _screen_rect(node)
    _blend(_rect_image(Vector2i(rect.size.round()),color),rect.position,_modulate(node))

func _panel(node: Panel) -> void:
    var style = node.get_theme_stylebox("panel")
    if not style is StyleBoxFlat: return
    var rect := _screen_rect(node)
    var scale: float = node.get_global_transform_with_canvas().x.length()
    var radius: float = style.corner_radius_top_left*scale
    _blend(_rect_image(Vector2i(rect.size.round()),style.border_color,radius),rect.position,_modulate(node))
    var left: float = style.border_width_left*scale
    var top: float = style.border_width_top*scale
    var inside := rect.size-Vector2(left+style.border_width_right*scale,top+style.border_width_bottom*scale)
    _blend(_rect_image(Vector2i(inside.round()),style.bg_color,maxf(0,radius-left)),rect.position+Vector2(left,top),_modulate(node))

func _label(node: Label) -> void:
    var text := node.text
    var font := node.get_theme_font("font")
    var font_size := node.get_theme_font_size("font_size")
    if node.clip_text and node.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS and font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x > node.size.x:
        while not text.is_empty() and font.get_string_size(text+"…",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x > node.size.x:
            text = text.left(text.length()-1)
        text += "…"
    _text(node,text,font,font_size,node.get_theme_color("font_color"),node.horizontal_alignment,node.vertical_alignment,node.autowrap_mode != TextServer.AUTOWRAP_OFF)

func _button_label(node: Button) -> void:
    _text(node,node.text,node.get_theme_font("font"),node.get_theme_font_size("font_size"),node.get_theme_color("font_color"),HORIZONTAL_ALIGNMENT_CENTER,VERTICAL_ALIGNMENT_CENTER,false)

func _text(node: Control, text: String, font: Font, font_size: int, color: Color, horizontal: int, vertical: int, wrap: bool) -> void:
    if font == null: return
    var lines: Array[String] = []
    for paragraph in text.split("\n"):
        var line := ""
        for letter in paragraph:
            if wrap and not line.is_empty() and font.get_string_size(line+letter,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x > node.size.x:
                lines.append(line)
                line = ""
            line += letter
        lines.append(line)
    var line_height := font.get_height(font_size)
    var y := 0.0
    if vertical == VERTICAL_ALIGNMENT_CENTER: y = (node.size.y-lines.size()*line_height)/2.0
    elif vertical == VERTICAL_ALIGNMENT_BOTTOM: y = node.size.y-lines.size()*line_height
    var scale: Vector2 = Vector2(node.get_global_transform_with_canvas().x.length(),node.get_global_transform_with_canvas().y.length())
    for line in lines:
        var line_width := font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
        var x := 0.0
        if horizontal == HORIZONTAL_ALIGNMENT_CENTER: x = (node.size.x-line_width)/2.0
        elif horizontal == HORIZONTAL_ALIGNMENT_RIGHT: x = node.size.x-line_width
        for letter in line:
            var rid: RID
            var glyph := 0
            for font_rid in font.get_rids():
                glyph = text_server.font_get_glyph_index(font_rid,font_size,letter.unicode_at(0),0)
                if glyph != 0:
                    rid = font_rid
                    break
            if not rid.is_valid():
                x += font.get_string_size(letter,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
                continue
            var cache := Vector2i(font_size,0)
            var index: int = text_server.font_get_glyph_texture_idx(rid,cache,glyph)
            if index >= 0:
                var atlas: Image = text_server.font_get_texture_image(rid,cache,index)
                var uv: Rect2 = text_server.font_get_glyph_uv_rect(rid,cache,glyph)
                if atlas != null and uv.size.x > 0 and uv.size.y > 0:
                    var image := atlas.get_region(Rect2i(uv))
                    var size: Vector2 = text_server.font_get_glyph_size(rid,cache,glyph)*scale
                    image.resize(maxi(1,roundi(size.x)),maxi(1,roundi(size.y)),Image.INTERPOLATE_NEAREST)
                    var offset: Vector2 = text_server.font_get_glyph_offset(rid,cache,glyph)
                    var point := node.get_global_transform_with_canvas()*Vector2(x+offset.x,y+font.get_ascent(font_size)+offset.y)
                    _blend(image,point,color*_modulate(node))
            x += text_server.font_get_glyph_advance(rid,font_size,glyph).x
        y += line_height

func _line(node: Line2D) -> void:
    if node.points.size() < 2: return
    var transform := node.get_global_transform_with_canvas()
    var a: Vector2 = transform*node.points[0]
    var b: Vector2 = transform*node.points[-1]
    var size := Vector2(absf(b.x-a.x),maxf(1,node.width*transform.y.length()))
    _blend(_rect_image(Vector2i(size.round()),node.default_color),Vector2(minf(a.x,b.x),minf(a.y,b.y)),_modulate(node))
