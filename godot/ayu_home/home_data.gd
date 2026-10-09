extends RefCounted
## Original fictional day-to-day activities, not claims about the real family.
const SIZE := Vector2(1024, 768)
const WORLD_SCALE := 2.0/3.0
const FAMILY := ["ayu", "father", "mother"]
const NAMES := {"ayu":"阿鱼", "father":"爸爸", "mother":"妈妈", "qiuqiu":"求求", "luoluo":"落落", "tiantian":"天天", "xiduo":"喜多", "visitor":"你"}
const AREAS := {"exterior":"门前小院", "floor1":"一楼 · 家的日常", "floor2":"二楼 · 安静时光", "garden":"后花园与果园"}
const SEASONS := ["春", "夏", "秋", "冬"]
const SEASON_COPY := ["豌豆攀上竹架，草莓开着小白花。桃花边有蝴蝶，燕子在屋檐筑巢。", "番茄与黄瓜熟了，蓝莓、桃子挂满枝。蜜蜂采蜜，蜻蜓掠过水边。", "南瓜、萝卜和白菜长得正好，苹果与柿子转红。松鼠捡果，归鸟停在枝头。", "蒜苗与菠菜在暖棚里长着，柑橘映着冬阳。山雀啄食，刺猬在叶堆下冬眠。"]
const CROPS := [["豌豆","草莓","生菜"],["番茄","黄瓜","甜椒"],["南瓜","萝卜","白菜"],["蒜苗","菠菜","冬莴苣"]]
const FRUITS := [["桃花","梨花","草莓"],["桃子","蓝莓","葡萄"],["苹果","柿子","梨"],["柑橘","冬芽","金桔"]]
const WILDLIFE := [["蝴蝶","燕子"],["蜜蜂","蜻蜓"],["松鼠","归鸟"],["山雀","刺猬"]]

static func season(month: int) -> int:
	return 0 if month in [3,4,5] else (1 if month in [6,7,8] else (2 if month in [9,10,11] else 3))

static func r(x: float, y: float, w: float, h: float) -> Rect2:
	return Rect2(Vector2(x,y)*SIZE, Vector2(w,h)*SIZE)

static func p(x: float, y: float) -> Vector2:
	return Vector2(x,y)*SIZE

static func rooms(area: String) -> Dictionary:
	match area:
		"floor1": return {"kitchen":r(.12,.10,.13,.17),"dining":r(.26,.10,.22,.32),"cats":r(.50,.11,.12,.30),"stairs":r(.63,.11,.10,.32),"mahjong":r(.75,.11,.22,.26),"laundry":r(.024,.28,.23,.14),"workshop":r(.024,.44,.125,.34),"garage":r(.15,.44,.22,.34),"living":r(.39,.44,.34,.34),"corridor":r(.735,.385,.07,.15),"bath":r(.83,.39,.14,.13),"parents":r(.75,.53,.22,.25),"porch":r(.04,.79,.92,.13)}
		"floor2": return {"guest_closet":r(.04,.095,.095,.155),"guest_bath":r(.04,.29,.11,.13),"guest":r(.15,.10,.28,.32),"stairs":r(.455,.105,.17,.31),"study":r(.66,.10,.285,.215),"corridor":r(.635,.32,.067,.18),"closet":r(.706,.337,.082,.13),"bath":r(.81,.34,.137,.125),"ayu_room":r(.67,.50,.275,.305),"terrace":r(.04,.49,.595,.345)}
		"garden": return {"garden":r(.055,.10,.89,.78)}
		_: return {"yard":r(.105,.56,.76,.19),"gate":r(.46,.72,.145,.20),"garden_path":r(.015,.40,.05,.50),"stream":r(.86,.89,.10,.055),"road":r(.04,.88,.93,.06)}

static func doors(area: String) -> Array:
	match area:
		"floor1": return [r(.24,.18,.035,.10),r(.23,.37,.04,.06),r(.28,.40,.05,.06),r(.58,.40,.15,.065),r(.71,.45,.07,.06),r(.765,.505,.04,.055),r(.80,.475,.06,.06),r(.775,.36,.035,.06),r(.59,.765,.05,.065),r(.23,.765,.05,.065),r(.055,.76,.045,.075),r(.135,.70,.035,.06),r(.54,.40,.064,.067)]
		"floor2": return [r(.42,.355,.05,.07),r(.125,.17,.055,.075),r(.125,.345,.055,.055),r(.555,.405,.05,.115),r(.61,.35,.07,.07),r(.64,.30,.075,.075),r(.69,.38,.05,.055),r(.78,.385,.05,.04),r(.65,.465,.045,.08)]
		_: return []

static func obstacles(area: String) -> Array:
	match area:
		"floor1": return [r(.30,.20,.135,.125),r(.42,.105,.05,.08),r(.125,.105,.105,.065),r(.80,.19,.115,.09),r(.025,.445,.105,.11),r(.025,.635,.052,.03),r(.205,.515,.108,.205),r(.42,.525,.19,.074),r(.42,.60,.054,.104),r(.486,.63,.08,.09),r(.57,.695,.064,.06),r(.79,.57,.115,.16),r(.405,.435,.10,.035)]
		"floor2": return [r(.22,.155,.122,.166),r(.66,.13,.18,.055),r(.863,.205,.042,.052),r(.707,.56,.136,.175),r(.891,.64,.04,.105),r(.15,.59,.13,.13),r(.233,.74,.12,.04),r(.515,.76,.055,.055),r(.491,.327,.033,.056)]
		"garden": return [r(.10,.15,.18,.20),r(.10,.40,.18,.18),r(.10,.65,.18,.14),r(.44,.12,.10,.17),r(.60,.12,.10,.17),r(.78,.12,.10,.17),r(.44,.43,.10,.17),r(.60,.43,.10,.17),r(.78,.43,.10,.17),r(.78,.70,.14,.10)]
		_: return [r(.43,.55,.045,.025),r(.74,.58,.03,.035)]

static func hotspots(area: String) -> Array:
	match area:
		"floor1": return [h("cook","厨房",.18,.17,.155,.225),h("meal","餐桌",.365,.255,.45,.375),h("cats","猫窝",.575,.17,.558,.245),h("stairs_up","上二楼",.67,.25,.66,.40),h("mahjong","麻将小聚",.855,.235,.855,.335),h("record","唱片机",.95,.325,.78,.325),h("laundry","洗衣机",.056,.376,.10,.38),h("workbench","工具台",.078,.52,.12,.70),h("garage","车与自行车",.215,.58,.175,.69),h("tv","看电视",.706,.65,.67,.65),h("fish","喂鱼",.484,.45,.55,.52),h("album","家庭相册",.507,.675,.585,.66),h("relax_sofa","沙发小坐",.485,.575,.67,.72),h("parents","爸妈卧室",.85,.67,.925,.67),h("bath","浴室",.91,.45,.85,.48),h("exit","回到院子",.61,.81,.615,.77),h("garden","后花园",.535,.09,.535,.15)]
		"floor2": return [h("relax","客房大床",.282,.225,.365,.31),h("guest_closet","客房衣帽间",.092,.20,.108,.22),h("guest_bath","客房浴室",.089,.35,.108,.37),h("stairs_down","下到一楼",.54,.235,.565,.38),h("computer","电脑与游戏",.782,.16,.84,.27),h("guitar","吉他",.889,.152,.80,.28),h("puzzle","书架拼图",.68,.169,.69,.255),h("read","书房小椅",.895,.27,.865,.283),h("ayu_room","阿鱼卧室",.789,.665,.877,.60),h("closet","衣柜",.745,.40,.747,.44),h("bath","卧室浴室",.87,.41,.85,.435),h("terrace","露台喝茶",.23,.665,.35,.67),h("flowers","露台花盆",.081,.64,.107,.64),h("garden","看看后花园",.40,.83,.40,.78)]
		"garden": return [h("garden_play","照料菜园",.20,.42,.35,.66),h("fruit","四季果树",.65,.25,.65,.33),h("bees","花田蜂箱",.20,.20,.34,.23),h("pond","小溪生物",.87,.78,.735,.78),h("return","回门前小院",.51,.89,.51,.825)]
		_: return [h("door","敲门拜访",.551,.515,.55,.602),h("garden","沿小路去后园",.045,.66,.045,.68),h("xiduo","喜多的小窝",.80,.85,.77,.918),h("stream","看看小溪",.94,.86,.90,.918),h("flowers","院前花田",.14,.32,.15,.60),h("gate","院门",.52,.91,.53,.84)]

static func h(id: String, label: String, x: float, y: float, ax: float, ay: float) -> Dictionary:
	return {"id":id,"label":label,"pos":p(x,y),"approach":p(ax,ay)}

static func spawn(area: String) -> Vector2:
	match area:
		"floor1": return p(.615,.735)
		"floor2": return p(.565,.385)
		"garden": return p(.51,.825)
		_: return p(.535,.85)

static func state(id: String, hour: float) -> Dictionary:
	var action := "sleep"
	var area := "floor2" if id == "ayu" else "floor1"
	var point := p(.872,.70) if id == "ayu" else p(.926 if id == "father" else .767,.68)
	if hour >= 6.0 and hour < 7.5:
		action = "fish" if id == "ayu" else ("work" if id == "father" else "cook")
		area = "floor1"; point = p(.51,.505) if id == "ayu" else (p(.102,.62) if id == "father" else p(.21,.225))
	elif (hour >= 7.5 and hour < 8.25) or (hour >= 12.0 and hour < 13.0) or (hour >= 18.0 and hour < 19.0):
		action = "eat"; area = "floor1"; point = p(.29,.29) if id == "father" else (p(.44,.29) if id == "mother" else p(.365,.355))
	elif hour >= 8.25 and hour < 9.0:
		action = "clean"; area = "floor1"; point = p(.48,.37) if id == "ayu" else (p(.175,.73) if id == "father" else p(.135,.38))
	elif hour >= 9.0 and hour < 10.0:
		action = "away"; area = "away"
	elif hour >= 10.0 and hour < 12.0:
		action = "away" if id == "father" else (("homework" if hour < 11 else "computer") if id == "ayu" else "garden")
		area = "away" if id == "father" else ("floor2" if id == "ayu" else "garden")
		point = p(.79,.225) if id == "ayu" else p(.34,.43)
	elif hour >= 13.0 and hour < 14.0:
		action = "guitar" if id == "ayu" else "mahjong"; area = "floor2" if id == "ayu" else "floor1"
		point = p(.879,.277) if id == "ayu" else p(.795 if id == "father" else .92,.235)
	elif hour >= 14.0 and hour < 15.0:
		action = "away" if id == "mother" else ("game" if id == "ayu" else "work")
		area = "away" if id == "mother" else ("floor2" if id == "ayu" else "floor1")
		point = p(.79,.225) if id == "ayu" else p(.102,.62)
	elif hour >= 15.0 and hour < 17.0:
		action = "garden"; area = "garden"; point = p(.35,.58) if id == "ayu" else (p(.57,.34) if id == "father" else p(.34,.43))
	elif hour >= 17.0 and hour < 18.0:
		action = "clean" if id == "ayu" else ("work" if id == "father" else "cook"); area = "floor1"
		point = p(.59,.61) if id == "ayu" else (p(.102,.62) if id == "father" else p(.21,.225))
	elif hour >= 19.0 and hour < 20.0:
		action = "record" if id == "ayu" else ("mahjong" if id == "father" else "read"); area = "floor1"
		point = p(.90,.337) if id == "ayu" else (p(.795,.235) if id == "father" else p(.57,.61))
	elif hour >= 20.0 and hour < 21.0:
		action = "tv"; area = "floor1"; point = p(.58 if id == "ayu" else (.45 if id == "father" else .51),.615)
	elif hour >= 21.0 and hour < 22.0:
		action = "read" if id == "ayu" else "rest"; area = "floor2" if id == "ayu" else "floor1"
		point = p(.865,.283) if id == "ayu" else p(.925 if id == "father" else .768,.55)
	var face := "down"
	if action == "eat": face = "up" if id == "ayu" else ("right" if id == "father" else "left")
	elif action in ["cook","fish","work","computer","game","homework"]: face = "up"
	elif action == "mahjong": face = "right" if id == "father" else "left"
	elif action in ["tv","record"]: face = "right"
	elif action == "garden": face = "up" if id == "father" else "left"
	var bed := p(.803,.645) if id == "ayu" else p(.86 if id == "father" else .89,.65 if id == "father" else .69)
	return {"id":id,"action":action,"area":area,"pos":point,"bed":bed,"face":face}

static func at_home(hour: float) -> Array:
	var found := []
	for id in FAMILY:
		if state(id,hour).area != "away": found.append(id)
	return found

static func schedule_text() -> String:
	return "06:00  起床，养鱼、做早饭、工具整理\n07:30–08:15  一家三口吃早饭\n08:15  一起收拾家\n09:00–10:00  一家人外出，院子仍可散步\n10:00–11:00  爸爸外出，阿鱼写作业，妈妈照料菜园\n11:00–12:00  阿鱼用电脑，爸爸仍在外面\n12:00–13:00  一家三口吃午饭\n13:00  阿鱼弹吉他，爸爸妈妈与邻里麻将小聚\n14:00–15:00  妈妈外出，爸爸手作，阿鱼玩游戏\n15:00–17:00  一家人在后园照料植物\n17:00  准备晚饭与家务\n18:00–19:00  一家三口吃晚饭\n19:00  听唱片、读书、麻将小聚\n20:00  一家人看电视\n21:00  安静阅读，准备休息\n22:00–06:00  入睡（夜间拜访会轻声应门）\n\n以上是为游戏创作的生活安排。"
