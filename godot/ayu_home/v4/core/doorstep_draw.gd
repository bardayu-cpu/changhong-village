extends RefCounted
## 十四种门边实物的前后状态。屋子本身沿用既有原画，门帘与便签表明今日在门口相见。
const C=preload("res://ayu_home/v4/core/config.gd")
const UI=preload("res://ayu_home/v4/pixel_ui.gd")
static func box(node:CanvasItem,at:Vector2,x:float,y:float,w:float,h:float,color:String) -> void:
	node.draw_rect(Rect2((at+Vector2(x,y)).round(),Vector2(w,h)),Color(color))
static func paint(node:CanvasItem,id:String,at:Vector2,done:bool) -> void:
	box(node,at,-28,12,63,5,"71583d")
	match id:
		"erba":
			box(node,at,-19,-60,38,58,"583e2c");box(node,at,-14,-51,28,41,"f6cf74" if done else "8c8060");box(node,at,-23,-64,46,7,"8e6740");box(node,at,-22,-4,44,6,"9e7848")
			if done:box(node,at,-5,-38,10,18,"fff0b7")
		"daba":
			for n in 5:
				var p:=at+Vector2(-21,-12+n*5) if done else at+Vector2(-30+n*11,-13+n%2*9)
				node.draw_line(p,p+Vector2(49,0) if done else p+Vector2(25,-27),Color("d7b973"),4)
			if done:box(node,at,1,-14,5,29,"8a6752")
		"h1":
			box(node,at,12,-41,21,56,"756648");box(node,at,14,-44,17,7,"3b493d")
			if done:box(node,at,18,-50,8,34,"eadbc0");box(node,at,20,-45,2,14,"978a76")
			else:
				box(node,at,-31,-20,36,24,"eadbc0")
				for n in 4:box(node,at,-27,-16+n*5,25,2,"968a72")
		"h2":
			box(node,at,-26,-14,54,28,"977744")
			for n in 4:
				var p:=at+Vector2(-23+n*13,-16 if done else -13+n%2*8)
				box(node,p,0,0,10,9,["b06972","c9b668","7d8d9c","d8bb90"][n])
				if not done:node.draw_line(p,p+Vector2(-10,20),Color("d8bc92"),2)
		"h4":
			for n in 12:box(node,at,(-7+n%4*5) if done else (-31+n%5*15),(-4+n/4*4) if done else (-19+n/5*13),6,3,"b4884f")
			box(node,at,30,-57,3,62,"9e7547");box(node,at,26,-2,12,14,"ccb377")
		"h6":
			box(node,at,-24,-5,48,17,"9f6746")
			for n in 3:plant(node,at+Vector2(-17+n*17,-6),done,"edb979")
			if done:
				for n in 4:box(node,at,-29+n*15,-18,3,5,"aac8b7")
		"h7":
			box(node,at,-32,-18,64,29,"8b6841");box(node,at,-27,-14,54,21,"cab277")
			for n in 20:box(node,at,-24+n%7*7,-12+n/7*7,5,3,"ebc969" if done else "aa8652")
		"h8":
			for n in 6:
				var p:=at+Vector2(-26+n%3*18,-4-n/3*12) if done else at+Vector2(-28+n*8,-17+n%3*9)
				box(node,p,0,0,18 if done else 26,10,"8d6542");box(node,p,2,2,7,6,"d4ab6b")
		"flower":
			box(node,at,-28,-16,56,26,"9e9980");box(node,at,-23,-12,46,12,"85b5b1" if done else "746e5a");box(node,at,-20,10,40,5,"7d765e")
			if done:box(node,at,-21,-31,14,11,"a49775");box(node,at,-10,-35,8,8,"c4b38c");box(node,at,-8,-33,2,2,"493b30")
		"whitebrick":
			box(node,at,-3,-65,5,65,"72523a");box(node,at,-22,-62,45,5,"aa8050");box(node,at,-15,-47,30,27,"d6ae55" if done else "777759");box(node,at,-20,-23,40,6,"ebc775" if done else "929071");box(node,at,-2,-17,5,9,"d9b463")
		"grape":
			box(node,at,-23,-64,4,74,"b18b50");box(node,at,22,-64,4,74,"b18b50");box(node,at,-28,-57,61,4,"c6a263")
			for n in 7:box(node,at,-21+n*7,(-56+n%2*5) if done else (-44+n%3*11),10,5,"608650")
			for n in 6:box(node,at,-8+n%3*5,-40+n/3*5,4,4,"8c759b")
			if done:box(node,at,0,-60,3,15,"c4a776")
		"sunflower":
			box(node,at,-27,-15,54,25,"9a7542");box(node,at,-22,-10,44,14,"bd9e62");plant(node,at+Vector2(34,0),true,"e9c052")
			for n in 16:box(node,at,(-19+n%7*6) if done else (-32+n%7*10),(-7+n/7*4) if done else (5+n/7*5),3,2,"655337")
		"persimmon":
			box(node,at,-25,-19,52,31,"947047");box(node,at,-21,-15,44,6,"775735")
			for n in 3:
				var p:=at+Vector2(-16+n*13,-23+n%2*3) if done else at+Vector2(-32+n*29,9+n%2*4)
				box(node,p,0,0,11,10,"d69449");box(node,p,4,-2,4,3,"69804e")
		"rose":
			box(node,at,-23,-3,47,18,"a27758")
			for n in 3:plant(node,at+Vector2(-17+n*17,-4),true,"d385a0" if done else "9c7969")
			if done:box(node,at,30,5,12,9,"b99368");box(node,at,32,6,8,3,"92715c")
	# 木牌不是进门按钮；每家独立的短句与门边物件都可从路上看到。
	box(node,at,-63,-111,130,25,"7d6041");box(node,at,-60,-108,124,19,"d6be86")
	node.draw_string(UI.FONT,at+Vector2(-59,-93),C.DOOR_CHORES[id].closed,HORIZONTAL_ALIGNMENT_CENTER,120,13,Color("584b37"))
static func plant(node:CanvasItem,p:Vector2,bloom:bool,petal:String) -> void:
	box(node,p,-1,-27,3,28,"62834b");box(node,p,-9,-17,19,4,"7a9956")
	if bloom:box(node,p,-7,-34,15,7,petal);box(node,p,-3,-38,7,15,petal);box(node,p,-1,-32,3,3,"e3c075")
	else:box(node,p,-3,-28,7,7,"92955d")
