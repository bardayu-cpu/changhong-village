# -*- coding: utf-8 -*-
# 生成《游戏文案总表》：只读仓库里的 json 和 gd，不改任何东西
import json, os, re, csv, sys

ROOT = "/Users/kayra_ayu/Desktop/苏七镇奇缘/苏七镇奇缘-claude 总文件"
OUT_DIR = os.path.join(ROOT, "godot/回执")

def rp(p):
    return os.path.join(ROOT, p)

def load(p):
    return json.load(open(rp(p), encoding="utf-8"))

EN = "godot/assets/entrance/lines.json"
BH = "godot/assets/backhall/lines.json"
LW = "godot/assets/lawn/lines.json"
LK = "godot/assets/lake/lines.json"
OR = "godot/assets/orchard/lines.json"
FARM = "godot/assets/orchard/farm.json"
MG = "godot/assets/minigames/minigames.json"
LD = "godot/assets/minigames/ladder.json"
MENU = "godot/assets/banquet/menu.json"
LAY = "godot/assets/layered/scene_luoman_%s/layout.json"
MAIN = "godot/scripts/main.gd"
COURT = "godot/scripts/court_ui.gd"
ARR = "godot/scripts/arrival_card.gd"
BUI = "godot/scripts/banquet_ui.gd"
HOST = "godot/scripts/games/game_host.gd"
LH = "godot/scripts/layered_hall.gd"
ORG = "godot/scripts/orchard.gd"

J = {p: load(p) for p in [EN, BH, LW, LK, OR, FARM, MG, LD, MENU]}
GAMES = {g["id"]: g for g in J[MG]["games"]}
SRC_CACHE = {}

def src_text(p):
    if p not in SRC_CACHE:
        SRC_CACHE[p] = open(rp(p), encoding="utf-8").read()
    return SRC_CACHE[p]

def show(s):
    return str(s).replace("\n", "／")

def status_of(src, text):
    if "【待补】" in text:
        return "【待补】"
    if "新写" in src:
        return "新写，等阿鱼定"
    if src.startswith("蓝图") or src.startswith("世界观"):
        return "蓝图原话"
    if "文案改写版" in src or src.startswith("《乐山话"):
        return "文档原句"
    if src.startswith("现有"):
        return "现有的字"
    return ""

def short_src(src, n=90):
    s = src.strip()
    return s if len(s) <= n else s[:n] + "…"

SECTIONS = []   # [(code, name, rows)]
cur = None

def section(code, name):
    global cur
    cur = (code, name, [])
    SECTIONS.append(cur)

def row(when, who, text, status, where, note="", check=None):
    """check: (文件, 要在文件里找到的原文)；None 表示不查（json 直接读出来的，或者说明性的字）"""
    if check is not None:
        f, raw = check
        if raw not in src_text(f):
            print("!! 对不上：", f, repr(raw), file=sys.stderr)
            sys.exit(1)
    cur[2].append([when, who, show(text), status, where, note])

def code(when, who, text, status, f, name, note="", raw=None):
    """代码里写死的字：raw 是源码里的原样写法（默认就是 text，\n 按源码的反斜杠 n 找）"""
    r = raw if raw is not None else text.replace("\n", "\\n")
    row(when, who, text, status, f + " 的 " + name, note, (f, r))

def jl(path, key, when, pos="", note="", status=None, who=None):
    d = J[path]["lines"][key]
    t = d.get("text", "")
    w = who if who is not None else (d.get("who", "") or pos)
    src = d.get("source", "")
    st = status if status is not None else status_of(src, t)
    n = note
    if src and src not in ("新写，等阿鱼定",):
        n = (n + "；" if n else "") + "出处：" + short_src(src)
    row(when, w, t, st, path + " 的 " + key, n)

def label_rows(scene, when_prefix, skip=()):
    p = LAY % scene
    d = load(p)
    for i, it in enumerate(d.get("flat", [])):
        if it.get("type") == "label" and it["text"] not in skip:
            row(when_prefix + "（画在地上的名字）", "地上的名字牌", it["text"], "灰盒占位",
                p + " 的 flat[%d].text" % i, "灰盒阶段代码画的字，出正式底图后整份换掉")
    for i, it in enumerate(d.get("items", [])):
        if "label" in it:
            row(when_prefix + "（物件头上的名字）", "物件名字牌", it["label"]["text"], "灰盒占位",
                p + " 的 items[%d].label.text" % i, "灰盒阶段代码画的字，出正式底图后整份换掉")

# ======================= 开场 =======================
section("开", "开场")
wg = "wechat-build/game.js"
row("第一次打开小游戏、下载游戏包时", "黑屏进度条上", "首次加载请耐心等待", "导出模板自带",
    wg + " 的 textConfig.firstStartText", "Godot 微信导出模板生成的，直接改会被下次导出冲掉，要改得让 02 改导出流程", (wg, "首次加载请耐心等待"))
row("下载游戏包过程中（三句轮换）", "黑屏进度条上", "正在加载资源／加载中...／请稍候...", "导出模板自带",
    wg + " 的 textConfig.downloadingText", "同上", (wg, "'正在加载资源', '加载中...', '请稍候...'"))
row("下载完、编译时", "黑屏进度条上", "编译中", "导出模板自带", wg + " 的 textConfig.compilingText", "同上", (wg, "编译中"))
row("引擎启动时", "黑屏进度条上", "引擎初始化中", "导出模板自带", wg + " 的 textConfig.initText", "同上", (wg, "引擎初始化中"))
row("引擎启动完", "黑屏进度条上", "开始游戏", "导出模板自带", wg + " 的 textConfig.completeText", "同上", (wg, "开始游戏"))
code("游戏画面出来前黑屏预热（手机上十几二十秒）", "屏幕正中", "加载中", "", MAIN, "_ready 里的 wait 标签", "和翻簿子的「加载中」是两处")
code("开场标题页", "大标题", "苏七镇奇缘", "", MAIN, "_build_ui 的 name_l")
code("开场标题页", "按钮", "打开看看", "", MAIN, "_build_ui 的 open_b")
code("起昵称页，输入框空着时", "输入框里的灰字", "填一个朋友们认得出的名字", "", MAIN, "_build_ui 的 nick_edit.placeholder_text")
code("起昵称页", "输入框下面一行", "其他宾客会看到这个名字", "", MAIN, "_build_ui")
code("起昵称页，边打边数", "输入框右下角", "0/12", "", MAIN, "nick_count（_check_nick_ui 里是 %d/12）", "前面是已经打了几个字，最多 12")
code("起昵称页", "按钮", "好", "", MAIN, "_build_ui 的 nick_ok", "名字不合格时是灰的点不了")
code("起昵称，只打了 1 个字", "输入框下红字", "再长一点", "", MAIN, "_check_nick", "至少 2 个字")
code("起昵称，超过 12 个字", "输入框下红字", "最多 12 个字", "", MAIN, "_check_nick")
code("起昵称，全是数字或全是符号", "输入框下红字", "用中文、英文或数字", "", MAIN, "_check_nick")
code("起昵称，有字体里没有的字（生僻字、表情）", "输入框下红字", "有个字显示不出来 换一个", "", MAIN, "_check_nick",
     "翻簿子、签到签名也有一样的句子，分在三处")
row("起昵称被服务端拒（敏感词、保留名）", "输入框下红字", "换一个吧／这个名字留给主角了，换一个吧", "阿鱼定稿（敏感词模块需求）",
    MAIN + " 的 REASONS", "见「各处通用」拒绝原因 sensitive、reserved 两条，不在这里重复改")
code("选形象页（8 个形象，没有标题字）", "按钮", "好", "", MAIN, "_build_ui 的 ok2", "点了从迎宾院大门进来")
code("回忆册里的两分钟剪辑（占位屏）", "标题", "【待补】两分钟剪辑", "【待补】，只有阿鱼能写", MAIN, "_build_ui 的 clip 屏",
     "现在只有调试版能从迎宾院回忆册点进来，正式版按钮是灰的「还没印好」。六章六张图六句话是阿鱼的记忆点（世界观 4.2）")
code("回忆册里的两分钟剪辑（占位屏）", "标题下面一行", "六章各一张图一句话，等阿鱼提供。样机先跳过。", "占位说明", MAIN, "_build_ui 的 clip 屏",
     "这是给开发看的占位说明，剪辑做好后整屏换掉")
code("回忆册里的两分钟剪辑（占位屏）", "按钮", "继续", "", MAIN, "_build_ui 的 go", "看完回迎宾院原地")

# ======================= 迎宾院 =======================
section("迎", "迎宾院")
code("选完形象，从大门走进迎宾院", "阿鱼", "到啦～ 罗曼山庄 席还没散", "", MAIN, "LINE_ARRIVE", "每次从开场进山庄都说")
code("第一次进场景、还没走过路", "屏幕下方提示条", "点地面走路 或推左下圆圈", "新写，等阿鱼定", MAIN, "LINE_WALK_HINT",
     "这次打开游戏走过一次就不再出")
jl(EN, "welcome", "第一次走到门口迎宾处（还没签到）")
jl(EN, "btn_sign", "走到签到桌", pos="按钮")
jl(EN, "btn_signed", "签过到以后再走到签到桌", pos="按钮", note="灰的，点不了")
jl(EN, "sign_name_title", "点「签到」，签名页", pos="面板标题")
code("签名页，边打边数", "输入框右下角", "0/12", "", COURT, "name_count（%d/12）")
jl(EN, "btn_cancel", "签名页、合影摆姿势页", pos="按钮", note="两处共用这一条")
jl(EN, "btn_next", "签名页", pos="按钮")
jl(EN, "err_name_empty", "签名页，名字空着点下一步", pos="输入框下红字")
jl(EN, "err_name_long", "签名页，超过 12 个字", pos="输入框下红字")
jl(EN, "err_name_glyph", "签名页，有显示不出来的字", pos="输入框下红字")
jl(EN, "gift_title", "签名后，礼金页", pos="面板标题")
jl(EN, "gift_hint", "礼金页", pos="标题下面一行")
jl(EN, "gift_none", "礼金页第一个选项；确认页没送礼金时也显示它", pos="按钮")
code("礼金页的三个数目", "按钮", "66／88／188", "蓝图原话", COURT, "GIFTS", "数字按钮上只有数字、不带「金」；蓝图 3.1：不送、66、88、188",
     raw="const GIFTS := [0, 66, 88, 188]")
jl(EN, "gift_custom", "礼金页", pos="按钮")
jl(EN, "gift_custom_placeholder", "点「自己填」，输入框空着时", pos="输入框里的灰字", note="上限 9999")
jl(EN, "btn_ok", "自己填礼金旁边；确认页", pos="按钮", note="两处共用这一条")
jl(EN, "btn_back", "礼金页、确认页", pos="按钮", note="两处共用这一条")
jl(EN, "confirm_title", "礼金选完，确认页", pos="面板标题")
jl(EN, "confirm_name_fmt", "确认页", pos="面板第一行", note="%s 是刚签的名字")
jl(EN, "confirm_gift_fmt", "确认页", pos="面板第二行", note="%s 是礼金数字（不带「金」）；选了不送时是「不送」")
jl(EN, "confirm_note", "确认页", pos="面板底下灰字")
jl(EN, "dad_thanks", "签完到、包了礼金")
jl(EN, "dad_no_gift", "签完到、选了不送")
jl(EN, "candy", "签完到，第一次（只弹一次）", pos="弹窗大字", note="弹窗上还有一张「糖」字菜牌占位图")
jl(EN, "mom_point", "喜糖弹窗收起后")
jl(EN, "btn_album", "走到回忆册台子（剪辑做好了）", pos="按钮")
jl(EN, "album_not_ready", "走到回忆册台子（剪辑还没做好，正式版现在就是这样）", pos="按钮（灰）＋顶上提示",
   note="按钮上写它、同时顶上提示也说一遍")
jl(EN, "photo_greet", "每回到迎宾院，第一次走近花墙")
jl(EN, "btn_photo", "站上花墙前的合影位", pos="按钮")
jl(EN, "pose_title", "点「拍一张」，选姿势", pos="面板标题")
jl(EN, "pose_stand", "选姿势", pos="按钮")
jl(EN, "pose_wave", "选姿势", pos="按钮")
jl(EN, "pose_heart", "选姿势", pos="按钮")
jl(EN, "photo_count", "选完姿势，拍之前")
jl(EN, "focus_hint", "对焦小玩法", pos="屏幕提示")
code("拍好的相纸上", "相纸顶上", "囍", "", COURT, "_compose_paper 的 xi", "装饰字，花墙上也有一个（entrance.gd）")
jl(EN, "btn_retake", "相纸展示页", pos="按钮")
jl(EN, "btn_keep", "相纸展示页", pos="按钮")
jl(EN, "photo_kept", "点「收好」以后", pos="顶上提示")
jl(EN, "elder", "每回到迎宾院，第一次走到休息区", note="一句最多一个方言词")
jl(EN, "elder_gloss", "老人那句第一次出现时自动弹；以后点说话框再弹", pos="顶上提示")
jl(EN, "gate_not_signed", "写过悄悄话、没签到就走到大门")
row("签过到、写过悄悄话，走到大门口", "新娘妈妈", show(J[EN]["lines"]["gate_bye"]["text"]) + "／" + show(J[EN]["lines"]["gate_tomorrow"]["text"]),
    "新写，等阿鱼定", EN + " 的 gate_bye ＋ gate_tomorrow",
    "两句拼成两行一起说（第一行 gate_bye，第二行 gate_tomorrow），各改各的键。第二句说的是进厅那张小卡；原来的「镇上的路还没修好 下次带你去」（gate_road）已停用")
label_rows("entrance", "迎宾院地图上")

# ======================= 宴会厅 =======================
section("宴", "宴会厅")
# 进厅
row("第一次进宴会厅：邀请人就是这桌第一个坐下的", "阿鱼", "%s 带你来的 你们坐一桌", "新写，等阿鱼定", MAIN + " 的 LINE_FIRST_WITH_INVITER",
    "%s 是邀请人昵称（超过 6 个字截断加…）", (MAIN, "%s 带你来的 你们坐一桌"))
row("第一次进宴会厅：邀请人那桌满了，你坐别人那桌", "阿鱼", "%s 带你来的 你坐 %s 那桌", "新写，等阿鱼定", MAIN + " 的 LINE_FIRST_INVITER_OTHER",
    "第一个 %s 是邀请人，第二个是这桌第一个坐下的人", (MAIN, "%s 带你来的 你坐 %s 那桌"))
row("第一次进宴会厅：邀请人那桌满了，新开了一桌", "阿鱼", "%s 带你来的 这桌还空着 你先坐", "新写，等阿鱼定", MAIN + " 的 LINE_FIRST_INVITER_NEW",
    "%s 是邀请人昵称", (MAIN, "%s 带你来的 这桌还空着 你先坐"))
row("第一次进宴会厅：没人邀请、桌子空着", "阿鱼", "这桌还空着 你是第一个坐的", "新写，等阿鱼定", MAIN + " 的 LINE_FIRST_EMPTY", "", (MAIN, "这桌还空着 你是第一个坐的"))
row("第一次进宴会厅：没人邀请、桌上有人", "阿鱼", "你坐 %s 那桌", "新写，等阿鱼定", MAIN + " 的 LINE_FIRST_TABLE",
    "%s 是这桌第一个坐下的人", (MAIN, "你坐 %s 那桌"))
code("进厅时 120 个座坐满了，被分到墙边长凳", "顶上提示", "桌子都坐满了 先坐墙边的长凳", "新写，等阿鱼定", MAIN, "LINE_BENCH")
code("进厅时分到的座位画面上摆不出来", "顶上提示", "先找把空椅子坐下", "", MAIN, "_on_enter_hall", "少见的兜底情况")
code("以后每次进厅（有新鲜事才弹）小卡：有 1 个人敬过你", "进厅小卡一行", "%s 敬了你一杯", "新写，等阿鱼定", ARR, "LINE_TOAST_1",
     "%s 是对方昵称（超 6 字截断加…）；进厅先放的那张干杯插图下面也写这句")
code("进厅小卡：同一个人敬了你几杯", "进厅小卡一行", "%s 敬了你 %d 杯", "新写，等阿鱼定", ARR, "LINE_TOAST_N", "%s 昵称，%d 杯数")
code("进厅小卡：有人在你这桌簿子上写了 1 句", "进厅小卡一行", "%s 在你这桌簿子上写了一句", "新写，等阿鱼定", ARR, "LINE_BOOK_1", "%s 昵称")
code("进厅小卡：有人写了几句", "进厅小卡一行", "%s 在你这桌簿子上写了 %d 句", "新写，等阿鱼定", ARR, "LINE_BOOK_N", "%s 昵称，%d 句数")
code("进厅小卡：你走后有人来过", "进厅小卡一行", "%s 你走后来过", "新写，等阿鱼定", ARR, "LINE_VISIT", "%s 昵称")
code("进厅小卡：人多，第三行合起来", "进厅小卡一行", "还有 %d 位来过", "新写，等阿鱼定", ARR, "LINE_MORE", "%d 人数")
code("进厅小卡「敬了你」那行右边", "按钮", "回敬一杯", "新写，等阿鱼定", ARR, "BTN_TOAST_BACK", "和被敬时顶上那个按钮（main.gd 的 LINE_TOAST_BACK）一个字，两处要一起改")
code("进厅小卡「簿子上写了」那行右边", "按钮", "翻簿子", "", ARR, "BTN_BOOK", "和走到桌边的按钮（main.gd）一个字，两处要一起改")
row("进厅提示（旧版服务端才走这条，新版进厅小卡上线后看不到）", "顶上提示",
    "%s 敬了你一杯／%s等 %d 人敬了你／簿子上多了 %d 句", "", MAIN + " 的 _arrive_old",
    "几段用「，」连成一行；%s 昵称。注意「等」前面没空格，和当场被敬那句不一样", (MAIN, "簿子上多了 %d 句"))
# 找座、坐下
row("宴会厅每张桌心立着的桌牌", "桌牌", "%s那桌·%s", "", LH + " 的 _table_sign",
    "第一个 %s 是这桌第一个坐下的人，第二个是这桌的小游戏名（见小游戏各节的标题）；没真人坐的桌只写游戏名", (LH, 'parts.append(nick + "那桌")'))
code("走到空椅子旁", "按钮", "坐这儿", "", MAIN, "_build_hud 和 _refresh_seat_buttons 的 sit_btn", "代码里两处写了这个字，要一起改", raw='sit_btn.text = "坐这儿"')
code("点了「坐这儿」，等你再点一次", "按钮", "再点一下确认", "", MAIN, "_on_sit_pressed")
row("点了「坐这儿」，等你再点一次", "顶上提示", "换到%s那桌？／坐这桌？", "", MAIN + " 的 _on_sit_pressed",
    "两种情况二选一：这桌有人时「换到XX那桌？」，%s 是这桌第一个坐下的人；空桌时「坐这桌？」", (MAIN, '"那桌？" if tn != "" else "坐这桌？"'))
code("坐下成功", "顶上提示", "坐好了", "", MAIN, "_on_seat_changed")
# 看人
code("走近坐着的人", "按钮", "看看 %s", "新写，等阿鱼定", MAIN, "LINE_LOOK_FMT", "%s 是对方昵称，太长截成…")
code("看人卡片", "卡片上的名字", "（对方昵称）", "", MAIN, "_open_person_card", "没有昵称时写「有人」，见各处通用", raw="person_card_name.text")
code("看人卡片，对方是别人邀请来的", "卡片名字下面一行", "%s 带进来的", "", MAIN, "_open_person_card",
     "%s 是邀请人昵称；查不到邀请人这行不出", raw='inviter_nick + " 带进来的"')
code("看人卡片", "按钮", "敬一杯", "", MAIN, "_build_person_card 和 _open_person_card", "代码里两处写了这个字，要一起改", raw='person_card_toast_btn.text = "敬一杯"')
code("看人卡片", "按钮", "想认识你", "蓝图 3.2（阶段 1 设计 v1.1 §4）", MAIN, "LINE_MEET")
# 敬酒、回敬
code("敬酒成功", "顶上提示", "敬了 %s 一杯", "新写，等阿鱼定", MAIN, "LINE_TOASTED_FMT", "%s 是对方昵称")
code("敬酒、被敬时弹的干杯插图", "插图大字", "干杯", "新写，等阿鱼定", MAIN, "LINE_CHEERS")
row("在厅里时有人当场敬你", "顶上提示", "%s 敬了你一杯／%s 等 %d 人敬了你", "", MAIN + " 的 _on_pulse",
    "二选一：1 个人时前一句，几个人时后一句；%s 是最新那位的昵称，%d 人数", (MAIN, '" 等 %d 人敬了你"'))
code("被敬以后，顶上那句提示右边（留 6 秒）", "按钮", "回敬一杯", "新写，等阿鱼定", MAIN, "LINE_TOAST_BACK", "和进厅小卡的按钮一个字，两处要一起改")
# 翻簿子
code("走到桌边，或坐在自己桌上", "按钮", "翻簿子", "", MAIN, "_build_hud 的 book_btn", "和进厅小卡的按钮一个字，两处要一起改", raw='book_btn.text = "翻簿子"')
code("簿子刚打开、还在读", "簿子面板", "加载中", "", MAIN, "_build_book_panel 的 book_loading")
code("簿子还没人写", "簿子面板", "还没人写 你来第一句", "新写，等阿鱼定", MAIN, "LINE_BOOK_EMPTY")
row("簿子里每一条", "簿子面板", "%s：%s", "", MAIN + " 的 _render_book_lines", "前一个 %s 是写的人昵称，后一个是那句话；中间是全角冒号", (MAIN, 'nick + "：" + str('))
code("簿子写字框空着时", "输入框里的灰字", "接一句", "新写，等阿鱼定", MAIN, "BOOK_PLACEHOLDER")
code("簿子写字，边打边数", "输入框右下角", "0/100", "", MAIN, "book_count（%d/100）", "最多 100 字")
code("簿子写字", "按钮", "好", "", MAIN, "_build_book_panel 的 book_ok", raw='book_ok.text = "好"')
code("翻的不是自己现在坐的那桌", "簿子面板（替换写字框）", "先坐下 慢慢写", "蓝图原话（9/18 定稿）", MAIN, "LINE_BOOK_READONLY",
     "拒绝原因 not_sat_here 也是这句，两处要一起改")
code("簿子写了显示不出来的字", "输入框下红字", "有个字显示不出来 换一个", "", MAIN, "_check_book", "超过 100 字时显示拒绝原因 book_too_long（见各处通用）",
     raw='return "有个字显示不出来 换一个"')
# 想认识你
code("「想认识你」发出去了", "顶上提示", "想认识 %s 记下了", "新写，等阿鱼定", MAIN, "LINE_MEET_SENT_FMT", "%s 是对方昵称；对方现在看不到（好友在阶段 2）")
# 席面菜单
ML = J[MENU]["lines"]
def ml(key, when, pos, note=""):
    d = ML[key]
    t = d["text"]
    src = d.get("source", "")
    n = note
    if src and src != "新写，等阿鱼定":
        n = (n + "；" if n else "") + "出处：" + short_src(src)
    row(when, pos, t, status_of(src, t) or ("玩法过目原话" if "原话" in src else ""), MENU + " 的 lines." + key, n)
ml("btn_menu", "在宴会厅，左上角地名下面那块牌子；添菜页底下切回菜单的按钮", "按钮", "两处共用这一条")
ml("head_midday", "打开席面菜单（北京时间 12:00～18:00）", "面板标题")
ml("head_evening", "打开席面菜单（18:00 以后、12:00 以前）", "面板标题")
ml("sub_fmt", "打开席面菜单", "标题下面一行", "{n} 是今天这套有几道菜，别删")
row("席面菜单里每一道", "列表", "%d. %s", "", BUI + " 的 _fill_menu", "序号. 菜名", (BUI, '"%d. %s" % [i + 1, name]'))
row("席面菜单：中午正席的菜名（19 道，按顺序）", "列表", "／".join(J[MENU]["menus"]["midday"]["dishes"]),
    "阿鱼认过的定稿", MENU + " 的 menus.midday.dishes", "菜名别改（menu.json 注明）；单子上的人数、价格、单号不进游戏")
row("席面菜单：晚上晚宴的菜名（18 道，按顺序）", "列表", "／".join(J[MENU]["menus"]["evening"]["dishes"]),
    "阿鱼认过的定稿", MENU + " 的 menus.evening.dishes", "菜名别改（menu.json 注明）")
for name, intro in J[MENU]["intros"].items():
    if intro:
        row("席面菜单里点开「%s」" % name, "菜名下面展开的简介", intro, "02 草稿，等阿鱼定", MENU + " 的 intros." + name,
            "写法照《文案改写版 v2》2.3：白描、短、不夸；两套里重样的菜共用一条")
    else:
        row("席面菜单里点开「%s」" % name, "菜名下面展开的简介", "（空着，显示【待补】）", "【待补】", MENU + " 的 intros." + name,
            "酒店自己起的名字，02 没瞎猜，要阿鱼说这道是什么")
ml("intro_todo", "简介还空着的菜点开时", "菜名下面（灰字）", "现在是金牌玉女瓜、天赐良缘网红参两道")
row("简介下面", "按钮", J[MENU]["learn"]["btn"], "", MENU + " 的 learn.btn", "代码里 banquet_ui.gd 也留了一份一样的兜底字")
row("点「学做这道」（厨房还没做）", "顶上提示", J[MENU]["learn"]["not_ready"], "", MENU + " 的 learn.not_ready", "代码里 banquet_ui.gd 也留了一份一样的兜底字")
code("席面菜单、添菜页", "按钮", "合上", "", BUI, "_build_panel 的 close_b", "小游戏菜单册的「合上」是另一处", raw='_btn("合上", close)')
# 添菜
code("坐在自己桌上时，底下那排按钮", "按钮", "添一道菜", "", MAIN, "_build_hud 的 add_dish_btn", "和菜单面板里的「添一道菜」（menu.json btn_add）是两处，要一起改", raw='add_dish_btn.text = "添一道菜"')
ml("btn_add", "席面菜单面板底下，切到添菜页", "按钮")
ml("add_head_fmt", "添菜页", "面板标题", "{price} 是一道多少金（现在 40），别删")
code("添菜页", "标题下面一行", "手上 %d 金", "", BUI, "_fill_add", "%d 是手上金币", raw='sub.text = "手上 %d 金"')
row("添菜页每一道能添的菜", "按钮", "%s　%d 金", "", BUI + " 的 _fill_add", "%s 菜名，%d 价格，中间是全角空格；钱不够时按钮是灰的", (BUI, '"%s　%d 金" % [name, price]'))
row("添菜页：一开始就能添的三道", "按钮上的菜名", "／".join(J[MENU]["add_dish"]["always"]), "", MENU + " 的 add_dish.always", "别的菜要打连连看解锁（菜名见 小游戏·连连看）")
ml("add_locked", "添菜页，还有没解锁的菜", "列表底下灰字")
ml("add_done_fmt", "添菜成功", "顶上提示", "{dish} 是菜名，别删；服务员端上来时盘子上方也飘几秒菜名")
ml("add_no_coins_fmt", "添菜钱不够", "顶上提示", "{n} 是还差几金，别删")
ml("add_sit_first", "没坐下就点添菜", "顶上提示")
ml("add_full", "桌上已经摆了 4 道", "顶上提示")
# 主桌悄悄话
code("走到主桌新人跟前", "阿鱼", "想跟我们说点什么 写这儿 只有我们看得到", "", MAIN, "LINE_TABLE", "说完底下出写字框")
code("写悄悄话，边打边数", "输入框左下角", "0/200", "", MAIN, "whisper_count（%d/200）", "最多 200 字")
code("写悄悄话", "按钮", "好", "", MAIN, "_build_hud 的 whisper_ok", raw='whisper_ok.text = "好"')
code("悄悄话写完", "阿鱼", "收到啦 谢谢你专门来一趟", "新写，等阿鱼定", MAIN, "LINE_THANKS", "写完厅门亮金光、迎宾院大门才开")
# 添礼金
code("写悄悄话的框里（手上有金币才出）", "框里一行", "手上 %d 金", "", MAIN, "_refresh_gift_row", "%d 是手上金币", raw='"手上 %d 金" % games_save.coins')
code("写悄悄话的框里", "按钮", "添礼金", "", MAIN, "_build_hud 的 gb")
row("点「添礼金」，一排数目", "按钮", "%d 金", "新写，等阿鱼定", MAIN + " 的 LINE_GIFT_BTN_FMT ＋ GIFT_CHOICES",
    "%d 是 8／88／188／888 里比手上少的那几个", (MAIN, 'const LINE_GIFT_BTN_FMT := "%d 金"'))
code("一排数目的最后一个", "按钮", "全部 %d 金", "新写，等阿鱼定", MAIN, "LINE_GIFT_ALL_FMT", "%d 是手上全部金币")
code("选数目时、问「全添上？」时", "按钮", "算了", "", MAIN, "_open_gift_pick 和 _ask_gift_all", "代码里两处写了这个字", raw='back.text = "算了"')
code("点了「全部」，先问一句", "框里一行", "%d 金全添上？", "新写，等阿鱼定", MAIN, "LINE_GIFT_ASK_FMT")
code("点了「全部」，确认", "按钮", "添", "新写，等阿鱼定", MAIN, "LINE_GIFT_YES")
code("添完礼金", "顶上提示", "添了 %d 金 礼金簿记上了", "新写，等阿鱼定", MAIN, "LINE_GIFT_DONE_FMT", "%d 是添了多少")
# 厅里热闹
row("厅里热闹（服务员、乐队、彩带、别桌客人）", "—", "（没有字）", "", "godot/scripts/hall_life.gd",
    "只有自己添的菜端上桌时，盘子上方飘几秒菜名（就是菜单里的菜名）")

# ======================= 小游戏·通用 =======================
section("游", "小游戏·通用（六个游戏共用的外壳）")
code("点了别人桌（不是自己坐着的）桌心的菜", "顶上提示", "先坐下 再玩", "新写，等阿鱼定", MAIN, "LINE_SIT_FIRST_GAME", "蓝图 3.2 异常表写的文案待阿鱼定")
code("坐在有小游戏的桌上，底下那排按钮", "按钮", "玩·%s", "", MAIN, "_refresh_seat_buttons 的 play_btn", "%s 是这桌的游戏名（见各游戏节的标题）", raw='"玩·" + GameCfg.title(my_game)')
code("开始卡、顶栏", "第几关", "第 %d 关", "", HOST, "_show_start 和 _process", "代码里两处", raw='"第 %d 关" % level')
code("游戏里右上角", "顶栏", "%d 金", "", HOST, "_process 的 coins_l", "手上金币", raw='coins_l.text = "%d 金"')
code("开始卡：游戏脚本还没做好", "开始卡一行", "这个游戏还在做", "", HOST, "_show_start", "现在六个都做好了，一般看不到")
code("开始卡", "按钮", "开始", "", HOST, "_show_start")
code("开始卡、歇一下卡、过关卡、没过卡、游戏里左下角", "按钮", "离开", "", HOST, "_button(\"离开\"…) 和 [\"离开\", _close]（共 5 处）",
     "代码里 5 处都写的这个字，要一起改", raw='"离开"')
code("游戏进行中，左下角", "按钮", "歇一下", "", HOST, "open 的 pause_b", raw='_button("歇一下", _pause)')
code("点了「歇一下」", "卡片标题", "歇一下", "", HOST, "_pause", raw='_card("歇一下"')
code("点了「歇一下」", "卡片正文", "这一关停在这儿 等你回来／不算输 也不扣金币", "", HOST, "_pause", "两行",
     raw='"这一关停在这儿 等你回来", "不算输 也不扣金币"')
code("点了「歇一下」", "按钮", "接着玩", "", HOST, "_pause")
code("过关", "卡片标题", "第 %d 关 过了", "", HOST, "_after_win", "%d 是刚过的关")
code("过关", "卡片正文第一行", "+%d 金（手上 %d 金）", "", HOST, "_on_finished", "第一个 %d 这关得了多少，第二个是得完手上一共多少")
code("过关", "按钮", "下一关", "", HOST, "_after_win")
code("没过", "卡片标题", "差一点", "", HOST, "_after_lose", "正文第一行是各游戏自己的输因（见各游戏节）")
code("没过（真玩过才给）", "卡片正文", "没过 也给你 %d 金 辛苦了", "新写，等阿鱼定", HOST, "LINE_CONSOLE", "%d 是这关奖励的四分之一；要让人听出是安慰、不是过关")
code("没过", "按钮", "再来一次", "", HOST, "_after_lose")
row("五个游戏共用的菜牌，图还没到时色块上写的字（12 种）", "牌面上的一个字", "／".join(t["ch"] for t in J[MG]["tiles"]),
    "占位", MG + " 的 tiles[].ch", "正式图到了换成图、有图的牌不叠字（阿鱼 9/23）；第 11 个「糖」接喜糖在用，别挪")

# ======================= 六个游戏 =======================
def game_head(gid, table_note):
    g = GAMES[gid]
    st = "暂名，等阿鱼给" if "title_note" in g else ""
    row("桌牌、「玩·XX」按钮、开始卡大字、游戏顶栏（%s）" % table_note, "游戏名", g["title"], st, MG + " 的 games[%s].title" % gid,
        g.get("title_note", ""))
    row("开始卡第一行", "开始卡说明", g["goal"], "", MG + " 的 games[%s].goal" % gid, "卡片按字硬折行，自己用换行断好（／就是换行）")

section("连", "小游戏·连连看")
game_head("lianliankan", "T1、T2 两桌")
code("开始卡", "这关目标", "%d 秒内把菜连完", "", "godot/scripts/games/lianliankan.gd", "goal_text", "%d 是这关给几秒")
code("游戏中", "顶栏状态", "剩 %d 秒", "", "godot/scripts/games/lianliankan.gd", "status_text")
code("没得连了自动洗牌那一下", "顶栏状态", "洗一下牌", "", "godot/scripts/games/lianliankan.gd", "status_text")
code("时间用完", "没过卡的输因", "时间到了", "", "godot/scripts/games/lianliankan.gd", "_game_tick 里的 lose", raw='lose("时间到了")')
code("连连看开始卡", "按钮", "菜单册", "", HOST, "_show_start", raw='["菜单册", _open_book]')
code("过关卡（连连看每关解锁一道菜）", "卡片正文一行", "菜单册多了一道：%s", "", HOST, "_on_finished", "%s 是解锁的菜名")
code("打开菜单册", "面板标题", "菜单册", "", HOST, "_open_book 的 head", raw='_label("菜单册", 36')
code("菜单册", "按钮", "合上", "", HOST, "_open_book 的 close_b", raw='_button("合上", func(): book.queue_free())')
code("菜单册里没解锁的菜", "列表一行（灰）", "%d. ？？？（连连看第 %d 关解锁）", "", HOST, "_open_book", "第一个 %d 序号，第二个是第几关解锁")
code("菜单册里解锁了的菜", "列表一行", "%d. %s", "", HOST, "_open_book", "序号. 菜名；下一行是短评", raw='"%d. %s" % [i + 1, str(d.get("name", ""))]')
row("菜单册 12 道菜的名字（按解锁顺序）", "列表里的菜名", "／".join(d["name"] for d in J[MG]["dishes"]), "占位，阿鱼可改",
    MG + " 的 dishes[].name", "游戏里不出现真实地名，一律写苏七；已解锁的也能在宴会厅「添一道菜」")
for i, d in enumerate(J[MG]["dishes"]):
    row("菜单册里「%s」解锁后，名字下面" % d["name"], "短评", d["note"], "待阿鱼写", MG + " 的 dishes[%d].note" % i,
        "只有阿鱼能写（世界观 4.2）；没写时显示「待阿鱼写」")

section("消", "小游戏·川菜消消乐")
game_head("match3", "T3、T4 两桌")
code("开始卡", "这关目标", "%d 步内凑够 %d 分（一次消三个 = 30 分，连着消还翻倍）", "", "godot/scripts/games/match3.gd", "goal_text", "%d 步数、%d 目标分")
code("游戏中", "顶栏状态", "%d/%d 分 剩 %d 步", "", "godot/scripts/games/match3.gd", "status_text", "现在分／目标分，剩几步")
code("没得消了自动洗牌那一下", "顶栏状态", "洗一下", "", "godot/scripts/games/match3.gd", "status_text", raw='return "洗一下"')
code("步数用完没凑够", "没过卡的输因", "步数用完了", "", "godot/scripts/games/match3.gd", "lose")

section("合", "小游戏·小菜合大菜")
game_head("g2048", "T5、T6 两桌")
code("开始卡", "这关目标", "从一粒%s合到「%s」", "", "godot/scripts/games/g2048.gd", "goal_text", "第一个 %s 是这关作物第 1 级的名字，第二个是目标那一级（名字见下面作物表）")
row("游戏中（这关图没交齐、用色块时）", "顶栏状态", "目标 %s 现在最大 %s", "", "godot/scripts/games/g2048.gd 的 status_text",
    "两个 %s 都是作物级名；还没开合时只有「目标 %s」", (("godot/scripts/games/g2048.gd"), "目标 %s 现在最大 %s"))
row("游戏中（有图时）", "顶栏状态", "目标 [图] 现在最大 [图]", "", "godot/scripts/games/g2048.gd 的 status_parts",
    "有图就不写级名（阿鱼 9/23 有图别叠字）；字只有「目标」「现在最大」", ("godot/scripts/games/g2048.gd", '["目标", goal_tex]'))
code("没地方合了", "没过卡的输因", "没地方合了", "", "godot/scripts/games/g2048.gd", "lose")
crops = J[LD]["crops"]
for i, (cid, c) in enumerate(sorted(crops.items())):
    row("第 %d 关（%s）牌面：从第 1 级到第 10 级" % (i + 1, c["title"]), "牌上的级名（没图时写在色块上）；开始卡、顶栏也用",
        "／".join(c["steps"]), "01 拟（按农作物成长阶段表）", LD + " 的 crops.%s.steps" % cid,
        "作物名「%s」本身不显示；每个三个字以内，长辈认得出；第 11 关以后一直用最后一种" % c["title"])
code("作物表读不到时的兜底", "级名", "种子", "", "godot/scripts/games/g2048.gd", "steps", "一般看不到", raw='["种子"]')

section("记", "小游戏·记菜名")
game_head("memory", "T7、T8 两桌")
code("开始卡", "这关目标", "配完 %d 对，最多翻错 %d 次", "", "godot/scripts/games/memory.gd", "goal_text", "%d 几对、%d 最多翻错几次")
code("开局先亮牌让你记", "顶栏状态", "记住它们", "", "godot/scripts/games/memory.gd", "status_text")
code("刚配上一对", "顶栏状态", "配上了", "", "godot/scripts/games/memory.gd", "status_text")
code("游戏中", "顶栏状态", "翻错 %d/%d", "", "godot/scripts/games/memory.gd", "status_text", "翻错几次／最多几次")
code("翻错次数用完", "没过卡的输因", "翻错太多次了", "", "godot/scripts/games/memory.gd", "lose")
code("扣着的牌背面", "牌背", "囍", "", "godot/scripts/games/memory.gd", "_game_tick 里牌背的 l", "装饰字", raw='l.text = "囍"')

section("护", "小游戏·护菜")
game_head("whack", "T9、T10 两桌")
code("开始卡", "这关目标", "%d 秒内挡回 %d 次偷菜的小松鼠\n别点辣椒", "", "godot/scripts/games/whack.gd", "goal_text", "%d 秒数、%d 要挡几次；两行")
code("游戏中", "顶栏状态", "守住 %d/%d 剩 %d 秒", "", "godot/scripts/games/whack.gd", "status_text", "守住几次／要几次，剩几秒")
code("时间到没守够", "没过卡的输因", "时间到了，守住了 %d 次", "", "godot/scripts/games/whack.gd", "lose")

section("接", "小游戏·接彩头")
game_head("catch", "T11、T12 两桌")
code("开始卡", "这关目标", "%d 秒内接够 %d 金\n喜糖、红包都是钱，鞭炮别接\n糖和红包给的金币不一样\n接到 %d 个鞭炮就输了",
     "第三行新写，等阿鱼定", "godot/scripts/games/catch.gd", "goal_text", "四行；%d 秒数、%d 要接几金、%d 几个鞭炮就输")
code("游戏中", "顶栏状态", "还差 %d 金", "新写，等阿鱼定", "godot/scripts/games/catch.gd", "status_text", "原来是「接了 N 金／这关要 M 金」")
code("游戏中", "游戏区左上角", "剩 %d 秒  鞭炮 %d/%d", "", "godot/scripts/games/catch.gd", "_sync_hud 的 hud", "剩几秒，接到几个鞭炮／几个就输；中间两个半角空格")
code("时间到没接够", "没过卡的输因", "时间到了，接了 %d 金", "", "godot/scripts/games/catch.gd", "lose")
code("接到太多鞭炮", "没过卡的输因", "接到的鞭炮太多了", "", "godot/scripts/games/catch.gd", "lose")
for i, s in enumerate(GAMES["catch"]["sayings"]):
    row("接到小红包、大红包时篮子上方冒一句；过关卡也随机说一句", "吉利话", s, "阿鱼给的" if i == 0 else "新写，等阿鱼定",
        MG + " 的 games[catch].sayings[%d]" % i, "一句最好 10 个字以内；接到糖不冒字")

# ======================= 后厅 =======================
section("后", "后厅")
for room, name in [("dress", "化妆室"), ("lounge", "休息间"), ("mahjong", "麻将室"), ("pot", "厨房")]:
    jl(BH, "btn_" + room, "走到%s的交互点" % name, pos="按钮")
    note = "02 的草稿在 回执/等阿鱼定的字.md 第 1 条（有 A／B 两版）"
    jl(BH, room, "在%s点了按钮" % name, note=note, status="【待补】，等阿鱼定")
label_rows("backhall", "后厅地图上")

# ======================= 草坪 =======================
section("草", "草坪")
jl(LW, "btn_kick", "走到球旁边", pos="按钮")
jl(LW, "kids", "踢完球、喜多把球叼回脚边（每回到草坪喊一次）")
label_rows("lawn", "草坪地图上")

# ======================= 湖边 =======================
section("湖", "湖边")
jl(LK, "btn_sit", "走到长凳旁", pos="按钮")
jl(LK, "btn_stand", "坐在长凳上", pos="按钮")
jl(LK, "pavilion", "走上栈道进亭子（自动出，走出去收）", status="【待补】，只有阿鱼能写",
   note="阿鱼的记忆点（世界观 4.2），02 不代写；一行 20 字以内好看；说话人现在写阿鱼，也可以改成没人说的旁白")
label_rows("lake", "湖边地图上")

# ======================= 果园 =======================
section("果", "果园")
jl(OR, "btn_harvest", "走到熟了的草莓垄、枇杷树下", pos="按钮", note="{fruit} 果名、{n} 几块熟了、{plot} 垄／棵，别删")
jl(OR, "growing", "走到还没熟的地", pos="顶上提示", note="{fruit} 果名、{left} 还有多久（格式见下一条），别删")
row("「还有多久」的说法", "嵌在上一句里", "%d 秒／%d 分 %d 秒", "", ORG + " 的 left_text", "不到 1 分钟用前一种", (ORG, '"%d 分 %d 秒"'))
jl(OR, "sold", "收完果子（现在是山庄直接收走折成金币）", pos="说话框（没写谁说）",
   note="{what} 是卖了什么（格式见下一条）、{coins} 几金，别删")
row("「卖了什么」的说法", "嵌在上一句里", "%s %d %s", "", ORG + " 的 basket_text", "果名 数量 单位，两种果子之间空格隔开，比如「草莓 3 筐 枇杷 2 篮」", (ORG, '"%s %d %s"'))
jl(OR, "harvested", "收完果子（切成自己拿去卖的模式才出，现在看不到）", pos="说话框（没写谁说）",
   note="{n} 几份、{unit} 筐／篮、{fruit} 果名，别删")
jl(OR, "btn_sell", "果篮有东西、走到山庄收购处（自己卖模式才出）", pos="按钮", note="{coins} 能卖几金，别删")
jl(OR, "shop_auto", "走到山庄收购处（现在的山庄直接收模式）", pos="顶上提示")
jl(OR, "basket_empty", "果篮空着走到收购处（自己卖模式）", pos="顶上提示")
jl(OR, "not_season", "走到不在季节的地（季节开关打开才出，现在关着）", pos="顶上提示")
for k, f in J[FARM]["fruits"].items():
    row("果园各句里嵌的「%s」的叫法" % f["name"], "嵌在按钮和提示里", "%s／%s／%s" % (f["name"], f["plot"], f["unit"]), "",
        FARM + " 的 fruits.%s 的 name／plot／unit" % k, "依次是果名、一块地叫什么（几%s熟了）、一份叫什么（3 %s）" % (f["plot"], f["unit"]))
label_rows("orchard", "果园地图上")

# ======================= 结束页 =======================
section("终", "结束页")
code("吃完出门后的下一段（还没做）", "标题", "【待做】出了罗曼山庄往南", "【待做】", MAIN, "_build_ui 的 end 屏",
     "现在正常玩到不了这一屏（出大门是新娘妈妈送你），只有截图模式能看到")
code("同上", "标题下面一行", "本地人集市、镇政府、小学门口的黄葛树、老街、石板桥", "占位说明", MAIN, "_build_ui 的 end 屏")
code("同上", "按钮", "再走一遍", "", MAIN, "_build_ui 的 again")

# ======================= 各处通用 =======================
section("通", "各处通用")
code("所有场景左上角", "地名牌", "● 罗曼山庄", "", MAIN, "_build_hud 的 chip", "五块画布都写这一个，不随场景变")
code("所有场景左上角地名右边", "金币牌", "%d 金", "", MAIN, "coins_chip", "刚打开是「0 金」", raw='coins_chip.text = "%d 金"')
code("说话框左上角，没指定谁说时", "说话人", "阿鱼", "", MAIN, "_say 的 who 默认值", "其他说话人（新娘妈妈、新娘爸爸、摄影师、老人、长辈、厨师、小孩）写在各 lines.json 的 who",
     raw='who := "阿鱼"')
code("对方没有昵称时（卡片、簿子、敬酒提示、桌牌…）", "替代昵称", "有人", "", MAIN, "多处兜底字（另有 godot/scripts/arrival_card.gd 的 short_nick）", "main.gd 里好几处、arrival_card.gd 1 处都写这个字，要一起改", raw='"有人"')
code("昵称太长被截断", "截断记号", "…", "", ARR, "short_nick", "进厅小卡、第一次进厅那句截到 6 个字加…；按钮上的截断是引擎自带")
code("看人卡片、翻簿子右上角", "关闭按钮", "×", "", MAIN, "_build_person_card、_build_book_panel", "字体里有这个字才出", raw='close_b.text = "×"')
code("花墙上、相纸上、翻牌背面", "装饰字", "囍", "", "godot/scripts/entrance.gd", "_item 里花墙的 xl", "唯一允许画在场景里的字（ASSETS 第 0 节）", raw='xl.text = "囍"')
R = [
    ("seat_taken", "坐的那把椅子刚被人抢先坐了", "阿鱼定稿"),
    ("toast_limit", "今天敬酒次数用完", "阿鱼定稿"),
    ("toast_same_person", "同一个人敬过了", "阿鱼定稿"),
    ("toast_self", "敬自己", "阿鱼定稿"),
    ("not_sat_here", "往不是自己坐的桌簿子上写", "阿鱼定稿"),
    ("book_too_long", "簿子写超过 100 字", "阿鱼定稿"),
    ("sensitive", "起昵称、签到签名、写簿子碰到敏感词", "阿鱼定稿（敏感词模块需求第 2 节）"),
    ("reserved", "昵称撞了保留名（主角的名字）", "阿鱼定稿（敏感词模块需求第 2 节）"),
    ("meet_self", "想认识自己", "新写，等阿鱼定"),
    ("meet_already", "同一个人说过想认识了", "新写，等阿鱼定"),
    ("meet_not_met", "不同桌、也没敬过酒就点想认识你", "新写，等阿鱼定"),
]
main_src = src_text(MAIN)
for key, when, st in R:
    m = re.search(r'"%s": "([^"]*)"' % key, main_src)
    row(when, "顶上提示（起昵称时是输入框下红字）", m.group(1), st, MAIN + " 的 REASONS." + key, "服务端回拒绝原因码，客户端翻成这句")
row("没连上网、服务端出错、或者服务端回了没见过的原因码", "顶上提示（签到时是输入框下红字）", "没连上 再试一下", "阿鱼定稿",
    MAIN + " 的 REASONS.network／no_resident／bad_request／no_seat ＋ _reason_text 的兜底",
    "代码里 5 处都是这句，要一起改；进厅、坐下、敬酒、翻簿子、写簿子、想认识你、签到失败都用它", (MAIN, '"network": "没连上 再试一下"'))
row("有新版本下好了（微信弹窗）", "弹窗标题", "更新提示", "导出模板自带", wg + " 的 checkUpdate", "导出模板生成的，直接改会被下次导出冲掉", (wg, "'更新提示'"))
row("有新版本下好了（微信弹窗）", "弹窗正文", "新版本已经准备好，是否重启应用？", "导出模板自带", wg + " 的 checkUpdate", "同上", (wg, "新版本已经准备好，是否重启应用？"))
row("右上角「···」转发给朋友、朋友圈时", "分享卡片标题", "苏七镇奇缘", "待阿鱼定", "godot/wxgame/share.js 的 card().title",
    "代码注释：卡片文案待阿鱼定，先只放游戏名；卡片图是 godot/wxgame/share.jpg", ("godot/wxgame/share.js", "title: '苏七镇奇缘'"))

# ======================= 输出 =======================
HEAD = ["编号", "环节", "什么时候出现", "谁说／在哪", "现在的字", "状态", "在哪改", "改成（阿鱼填）", "备注"]
flat = []
counts = []
for code_, name, rows in SECTIONS:
    counts.append((name, len(rows)))
    block = []
    for i, r in enumerate(rows, 1):
        when, who, text, st, where, note = r
        block.append(["%s-%02d" % (code_, i), name, when, who, text, st, where, "", note])
    flat.append(block)

total = sum(c for _, c in counts)

# csv（UTF-8 带 BOM）
with open(os.path.join(OUT_DIR, "游戏文案总表.csv"), "w", encoding="utf-8-sig", newline="") as f:
    w = csv.writer(f)
    w.writerow(HEAD)
    for block in flat:
        for r in block:
            w.writerow(r)

# xlsx
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter
wb = Workbook()
ws = wb.active
ws.title = "总表"
ws.append(HEAD)
hfill = PatternFill("solid", fgColor="8C2F27")
for c in ws[1]:
    c.font = Font(bold=True, color="FFFFFF")
    c.fill = hfill
    c.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
yellow = PatternFill("solid", fgColor="FFF6C8")
secfill = PatternFill("solid", fgColor="EFE6D8")
thin = Side(style="thin", color="D8CFC0")
border = Border(left=thin, right=thin, top=thin, bottom=thin)
wrap_cols = {3, 4, 5, 6, 7, 8, 9}
for bi, block in enumerate(flat):
    if bi > 0:
        ws.append([])
    code_, name, _ = SECTIONS[bi]
    ws.append(["", "【%s】%d 条" % (name, len(block))])
    sr = ws.max_row
    for col in range(1, len(HEAD) + 1):
        ws.cell(sr, col).fill = secfill
    ws.cell(sr, 2).font = Font(bold=True, color="6E1E1E")
    for r in block:
        ws.append(r)
        rr = ws.max_row
        for col in range(1, len(HEAD) + 1):
            c = ws.cell(rr, col)
            c.border = border
            c.alignment = Alignment(vertical="top", wrap_text=(col in wrap_cols))
        ws.cell(rr, 8).fill = yellow
        if "待补" in r[5] or "待阿鱼写" in r[5] or "只有阿鱼" in r[5]:
            ws.cell(rr, 6).font = Font(bold=True, color="C0392B")
widths = [8, 14, 34, 18, 44, 18, 40, 30, 50]
for i, wd in enumerate(widths, 1):
    ws.column_dimensions[get_column_letter(i)].width = wd
ws.freeze_panes = "C2"
ws.auto_filter.ref = "A1:I%d" % ws.max_row
ws.sheet_view.zoomScale = 110
ws.page_setup.orientation = "landscape"
ws.print_title_rows = "1:1"
wb.save(os.path.join(OUT_DIR, "游戏文案总表.xlsx"))

print("总数", total)
for n, c in counts:
    print(n, c)
