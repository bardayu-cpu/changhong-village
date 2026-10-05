extends RefCounted
## 公共·界面组件：全游戏界面用的颜色和字号都从这里取（组件库 v0.1 第二节第 1、2 条，罗-1；庄Z2 10/5）。
## 用法：const UI = preload("res://scripts/ui/ui_kit.gd")，然后 UI.BG、UI.TEXT、UI.SIZE_BODY……
## 以后裳泓村也从这里取（组件库 v0.1 改动清单 村-8）。改颜色只改这一份，别在各脚本里再抄一份。
## 场景里画的东西（地板、家具、相纸、海报、门牌、路牌……）不归这里管。

# ================================================================== 新皮（阿鱼定稿图那套，docs/参考图/对话框定稿-阿鱼10-04.png）
const BG := Color("#311e15")            # 深褐底：对话框、面板、提示条、顶栏小牌、提示泡的底
const EDGE := Color("#160c05")          # 最外线：所有框的最外一圈
const LINE := Color("#bf8044")          # 金棕线：框的里线、角花、提示泡边
const TEXT := Color("#faf2e4")          # 米白字：深底上的字、图标
const NAME := Color("#f2c23e")          # 名字黄：名字牌的字、翻页三角、要紧的数字（金币）
const RED := Color("#cb1c1c")           # 喜红：按钮
const RED_DARK := Color("#a4191a")      # 喜红暗面（按钮下截、按下）
const RED_DOWN_BAND := Color("#86120f") # 按下时下截再暗一档
const RED_EDGE := Color("#3e0303")      # 按钮描边
const RED_RIM := Color("#f8a870")       # 按钮亮边
const STUD_LIGHT := Color("#fff0b2")    # 金钉（按钮四角）：亮、中、暗
const STUD := Color("#ffd842")
const STUD_DARK := Color("#f0aa28")
const BUBBLE_BG := Color("#ffffff")     # 泡白：头顶话泡底
const BUBBLE_EDGE := Color("#2b1d17")   # 话泡边
const BUBBLE_TEXT := Color("#1c120c")   # 话泡字

# ================================================================== 字号：只用 12 的整倍（像素字只有 12 的整倍才清楚）
const SIZE_BODY := 24                   # 正文：对话、按钮、名字牌、提示条、顶栏、面板正文
const SIZE_TITLE := 36                  # 标题：面板标题、小游戏标题
const SIZE_BIG := 48                    # 大字：开屏、结算这类一屏一句的
const SIZE_TAG := 12                    # 只给不用读的角标数字

# ================================================================== 旧主题（深紫底、#d4af37 金边、平滑圆角）——罗-2 换掉
# 罗-1 这一步照原值放在这里，画面一点不变；罗-2 把用到它们的地方换成上面的新皮，再删掉这一节
const OLD_GOLD := Color("#d4af37")      # 旧金边、旧名字色
const OLD_GOLD1 := Color("#f4d97a")     # 旧亮金字
const OLD_RED := Color("#c0392b")       # 旧红（按钮悬停）
const OLD_RED0 := Color("#8c2f27")      # 旧按钮底
const OLD_RED_DOWN := Color("#6e211b")  # 旧按钮按下
const OLD_PAPER := Color("#efe6d8")     # 旧米白字（叫 PAPER 的那个）
const OLD_MUTED := Color("#b1a6ba")     # 旧灰紫小字
const OLD_INK := Color("#15111b")       # 旧深字
const OLD_ERR := Color("#E8746A")       # 旧错误红字（字数超了、昵称不对）
const OLD_PANEL := Color(0.106, 0.078, 0.133, 0.94)     # 旧深紫面板底（提示框、主题面板、到达卡）
const OLD_PANEL_HALF := Color(0.106, 0.078, 0.133, 0.5)  # 旧次要按钮底
const OLD_PANEL_PRESSED := Color(0.106, 0.078, 0.133, 0.6)
const OLD_CHIP := Color(0.08, 0.06, 0.1, 0.78)          # 旧顶栏小牌底（罗曼山庄、金币、席面菜单）
const OLD_CHIP_EDGE := Color(OLD_GOLD, 0.5)    # 旧小牌金边（旧金半透明）
const OLD_STICK_BASE := Color(0.08, 0.06, 0.1, 0.32)    # 摇杆底圈
const OLD_STICK_KNOB_EDGE := Color(0.08, 0.06, 0.1, 0.8)
const OLD_DISABLED := Color("#3b3148")  # 旧按钮不能点
const OLD_DISABLED_EDGE := Color("#5a4e68")
const OLD_FIELD := Color("#2a2235")     # 旧输入框、选人格子底
const OLD_PICK_DOWN := Color("#3b2230") # 选人格子按下
const OLD_SHADOW := Color(0.08, 0.05, 0.1, 0.9)         # 字的阴影
const OLD_CARD := Color(0.12, 0.07, 0.06, 0.96)         # 居中弹窗（结算卡）底
const OLD_WINE := Color("#2a1418")      # 小游戏遮罩（酒红）
const OLD_GAME_CARD := Color("#6e1e1e") # 小游戏结算卡、菜单册标题的深红
const OLD_MENU_PAPER := Color("#efe6d8")   # 菜单册纸面
const OLD_MENU_INK := Color("#2c1f1c")  # 菜单册字：开着的菜
const OLD_MENU_DIM := Color("#8a7a66")  # 菜单册字：还没开的菜
const OLD_MENU_NOTE := Color("#5a4a3a") # 菜单册小注
const OLD_MENU_FOOT := Color("#6a5a4a") # 结算卡纸面版的脚注

# ================================================================== 遮罩、过场（界面底允许半透明，画风页第 7 节）
const DIM := Color(0.06, 0.03, 0.06, 0.55)        # 弹窗后面压暗（主题、迎宾院、宴会厅）
const DIM_DEEP := Color(0.06, 0.03, 0.06, 0.6)    # 人物卡、簿子后面压暗
const DIM_LIGHT := Color(0.06, 0.03, 0.06, 0.35)  # 迎宾院签到后面压暗
const DIM_DARK := Color(0.03, 0.02, 0.04, 0.35)   # 迎宾院合影后面压暗
const DIM_BLACK := Color(0, 0, 0, 0.45)           # 居中弹窗后面压暗
const DIM_GAME := Color(0, 0, 0, 0.55)            # 小游戏没换皮时的遮罩
const SWITCH_TINT := Color("#3a1d12")             # 换画布时淡出淡入的暖色

# ================================================================== 调试用（只有开发模式看得见）
const DEBUG_TEXT := Color("#9CFF9C")    # 调试按钮、55 桌信息的绿字
const DEBUG_GAME := Color("#7ee08a")    # 小游戏调试行
const DEBUG_BG := Color(0, 0, 0, 0.55)  # 调试按钮底
const DEBUG_PANEL := Color(0, 0, 0, 0.7)
const OLD_RING_WHITE := Color("#f4f1ea")  # 迎宾院拍照对焦的白圈（跟相纸底一个色）
const FLASH := Color(1, 1, 1, 0)          # 快门一闪（白，平时全透明）
