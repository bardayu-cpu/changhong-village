extends Control
## A responsive physical page. The sheet hugs its contents; long pages scroll.
const UI=preload("res://ayu_home/v4/pixel_ui.gd")
var panel:PanelContainer
var body:VBoxContainer
var scroll:ScrollContainer
var column:VBoxContainer
var heading:HBoxContainer
var bottom:=false
var page_kind:="paper"
var settle_frames:=0
func build(title:String,close:Callable,kind:="paper",at_bottom:=false) -> VBoxContainer:
	page_kind=kind;bottom=at_bottom;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);theme=UI.theme(kind=="letter");texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var shade:=ColorRect.new();shade.color=Color(.13,.10,.07,.18 if bottom else .47);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(shade)
	panel=PanelContainer.new();panel.name="FittedPaper";add_child(panel)
	if kind=="letter":
		# 信就是一张纸：纸的纤维、两道折痕、几道褶皱、毛边和一个折角（阿鱼 10/4 晚）
		var empty:=StyleBoxEmpty.new()
		for side in [SIDE_LEFT,SIDE_RIGHT]:empty.set_content_margin(side,30)
		empty.set_content_margin(SIDE_TOP,26);empty.set_content_margin(SIDE_BOTTOM,28)
		panel.add_theme_stylebox_override("panel",empty);panel.draw.connect(draw_letter);panel.resized.connect(panel.queue_redraw)
	else:panel.add_theme_stylebox_override("panel",UI.panel_box()) # 村-5：面板跟对话框同一个框（信纸不换）
	column=VBoxContainer.new();column.add_theme_constant_override("separation",12);panel.add_child(column)
	if not title.is_empty():
		var letter:=kind=="letter"
		heading=HBoxContainer.new();column.add_child(heading);heading.add_child(UI.icon({"board":"tools","letter":"note"}.get(kind,"album"),26 if not letter else 34,UI.INK if letter else Color(UI.DS.PAL.box.rim)))
		var words:=VBoxContainer.new();words.size_flags_horizontal=SIZE_EXPAND_FILL;words.size_flags_vertical=SIZE_SHRINK_CENTER;words.add_theme_constant_override("separation",3);heading.add_child(words)
		if letter:var tiny:=UI.label("阿鱼的来信",24);tiny.add_theme_color_override("font_color",Color("99754f"));words.add_child(tiny)
		words.add_child(UI.paragraph(title,24 if letter else 36)) # 面板标题 36（组件库第 2 条）
		var exit:=UI.button("收起",close);exit.size_flags_vertical=SIZE_SHRINK_CENTER;heading.add_child(exit);exit.grab_focus();column.add_child(UI.divider())
	scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;column.add_child(scroll)
	body=VBoxContainer.new();body.add_theme_constant_override("separation",14);body.size_flags_horizontal=SIZE_EXPAND_FILL;scroll.add_child(body)
	body.minimum_size_changed.connect(queue_measure);get_viewport().size_changed.connect(queue_measure);queue_measure();return body
static func _noise(x:int,y:int,seed:=0) -> float:
	var v:=sin(float(x*127+y*311+seed*71)*.0731)*43758.5453;return v-floor(v)
var letter_tex:ImageTexture
var letter_size:=Vector2i.ZERO
func draw_letter() -> void:
	var size:=panel.size;var w:=int(size.x/2);var h:=int(size.y/2)
	panel.draw_rect(Rect2(Vector2(6,8),size),Color(0.18,0.12,0.07,0.28))
	if letter_size!=Vector2i(w,h) or letter_tex==null:
		letter_size=Vector2i(w,h);letter_tex=ImageTexture.create_from_image(letter_image(w,h))
	panel.draw_texture_rect(letter_tex,Rect2(Vector2.ZERO,Vector2(w*2,h*2)),false)
## 纸只在大小变了时画一次（一格 = 屏上 2 像素），平时直接贴图，手机上不费
func letter_image(w:int,h:int) -> Image:
	var img:=Image.create(maxi(w,1),maxi(h,1),false,Image.FORMAT_RGBA8);img.fill(Color(0,0,0,0))
	var paper:=Color("f6ead2")
	var folds:=[int(h/3),int(h*2/3)]
	for y in h:
		for x in w:
			# 毛边：四周随机缺一两格；右上角折起一角
			var edge:=mini(mini(x,w-1-x),mini(y,h-1-y))
			if edge<2 and _noise(x,y,3)<(.55 if edge==0 else .2):continue
			if x>w-16 and y<16 and (w-1-x)+y<15:continue
			var c:=paper
			var n:=_noise(x,y)
			if n<.08:c=c.darkened(.05)
			elif n>.95:c=c.lightened(.06)
			# 纸边微微发黄
			if edge<5:c=c.lerp(Color("e3cda3"),.35-edge*.06)
			# 两道横折痕：上面一行暗、下面一行亮
			for f in folds:
				if y==f:c=c.darkened(.13)
				elif y==f+1:c=c.lightened(.08)
			# 一道竖折痕（信纸对折过）
			if x==int(w/2) and _noise(0,y,9)<.85:c=c.darkened(.07)
			# 几道斜褶皱
			for k in 4:
				var cx:=int(w*(.2+.2*k));var cy:=int(h*(.15+.21*k))
				var d:=(x-cx)+(y-cy)*(1 if k%2 else -1)
				if absi(d)<=0 and absi(x-cx)<14+k*3:c=c.darkened(.08)
				elif d==1 and absi(x-cx)<14+k*3:c=c.lightened(.05)
			img.set_pixel(x,y,c)
	# 折起的那一角
	for i in 15:
		for j in 15-i:
			if w-15+j>=0:img.set_pixel(w-15+j,i,Color("e7d3ae") if j+i<14 else Color("c8ad80"))
	return img
func queue_measure() -> void:
	settle_frames=4;set_process(true)
func _process(_dt:float) -> void:
	if not panel:return
	var screen:=get_viewport_rect().size;var width:=minf(516,screen.x-32)
	panel.size.x=width;body.custom_minimum_size.x=width-48
	var head:=0.0 if not heading else heading.get_combined_minimum_size().y+32
	var available:=maxf(100,screen.y-80-head-36)
	scroll.custom_minimum_size.y=minf(available,body.get_combined_minimum_size().y)
	panel.size.y=panel.get_combined_minimum_size().y
	panel.position=Vector2((screen.x-width)*.5,screen.y-panel.size.y-22 if bottom else (screen.y-panel.size.y)*.5).round()
	settle_frames-=1
	if settle_frames<=0:set_process(false)
