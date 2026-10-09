#!/usr/bin/env python3
"""软著软件说明书（01 E 10/2 派）：写给审核的人看，一节一节配 540×960 游戏截图，出 HTML 给 Chrome 打成 PDF。

用法：python3 godot/tools/ruanzhu_manual.py <输出目录> <截图目录>
  截图目录里放 _setup_shot 截出来的 png（文件名 = 预设名），脚本拷进 <输出目录>/截图/ 改中文名。

版式照中国版权保护中心官网（10/2 读）：纵向、从左往右；页眉写软件名称和版本号、页码在右上角，从目录那页编第 1 页；
文档每页不少于 30 行——这里每页左边的字按固定行高排，脚本数行数，少于 30 行或者超出一页就报错不出。
"""
import html
import os
import shutil
import sys

from PIL import Image

TITLE = "苏七镇奇缘游戏软件 V1.0"
COLS = 38          # 左栏折行的显示宽度（中文算 2）
MIN_ROWS = 30
MAX_ROWS = 42

SHOTS = {
    "title": "01-开场.png", "nick": "02-起名字.png", "avatar": "03-选形象.png",
    "court_welcome": "04-迎宾院.png", "court_sign_gift": "05-签到礼金.png",
    "big_stage": "06-宴会厅婚礼台.png", "arrive_card": "07-进厅.png", "big_sit_far": "08-坐下.png",
    "toast_send": "09-敬酒.png", "book": "10-翻簿子.png", "big_main": "11-主桌.png",
    "game_lianliankan_play": "12-连连看.png", "game_match3_play": "13-川菜消消乐.png",
    "game_g2048_play": "14-小菜合大菜.png", "big_feast": "15-开席.png",
}

# 每页：左栏是若干节（标题 + 段落），右栏是这几节的截图（最多两张）
# 段落里的字用玩家视角写；没做完的不写成做完了
PAGES = [
    {
        "cover": True,
        "sections": [
            ("一、软件概述", [
                "苏七镇奇缘游戏软件（简称“苏七镇奇缘”）V1.0 是一款在微信里运行的小游戏，用手机竖屏玩。",
                "游戏的故事发生在一个虚构的小镇“苏七镇”。当前版本开放的是镇上的罗曼山庄：玩家作为宾客来到山庄吃一场喜酒——在迎宾院签到，进宴会厅找座位入席，和同桌、邻桌的人打招呼、敬酒，在桌上的簿子里留言，坐下以后还能玩席间小游戏。",
                "运行环境：微信 App（iOS、Android）里的微信小游戏，画面按竖屏 540×960 设计。客户端用 Godot 4.7 引擎（GDScript）开发，座位、敬酒、簿子等多人共享的数据放在微信云开发的云函数（JavaScript）里。",
                "基本操作：点一下地面，人物就走过去；也可以按住左下角的圆圈推着走。走近桌椅、人物或可以互动的东西时，屏幕下方会出现按钮，点按钮就能做对应的事。",
            ]),
        ],
        "shots": ["title"],
    },
    {
        "sections": [
            ("二、起名字", [
                "第一次打开游戏，在开场画面点“打开看看”，先给自己起一个名字。",
                "名字会显示在宴会厅里自己的头顶，也会出现在别人的簿子、敬酒提示里，所以输入框上方写着“其他宾客会看到这个名字”，建议填一个朋友们认得出的名字。",
                "名字最多 12 个字，可以用中文、英文或数字。太长、是空的、或者有显示不出来的字时，框下会直接提示，改好才能点“好”。名字含不合适的词时，会提示“换一个吧”，回到这一屏重新起。",
            ]),
            ("三、选形象", [
                "起好名字后选一个形象。画面上有 8 个像素小人可选，点一下选中，再点“好”。",
                "选好的形象就是自己在山庄里走动、入座、敬酒时的样子，别的宾客看到的也是它。",
            ]),
        ],
        "shots": ["nick", "avatar"],
    },
    {
        "sections": [
            ("四、罗曼山庄迎宾院", [
                "选好形象后，玩家来到罗曼山庄的迎宾院。院子正中铺着红毯，北面是通往宴会厅的楼门，南面是山庄大门。",
                "刚到时新娘妈妈会招呼一句“来啦 先到这边签个到”。签到台在屏幕外时，屏幕边上有一个小箭头指着它的方向。",
                "院子里还有花墙可以合影：摆好姿势，看准时机按快门，就能得到一张相纸，最多留 3 张。签完到，新娘妈妈会递上喜糖。",
            ]),
            ("五、签到与礼金", [
                "走到签到台前，点下方的“签到”。第一步写签到名字，默认就是自己起的名字，可以改；第二步选礼金，有“不送”、66、88、188 和“自己填”几项，写着“要包多少都行 不包也行”；最后确认。",
                "礼金只是在签到簿上登记一个数字，游戏里不发生真实付款，登记的数字也不会公开给其他宾客。",
            ]),
        ],
        "shots": ["court_welcome", "court_sign_gift"],
    },
    {
        "sections": [
            ("六、宴会厅", [
                "从迎宾院的楼门进去就是宴会厅。宴会厅按婚宴现场的规模布置：北面正中是婚礼台，台上站着一对新人，婚礼台左边是礼物架，右边是乐队台；一条红毯从门口一直铺到台前，红毯两边立着宫灯。",
                "厅里一共 55 张桌子：一张主桌和 54 张普通桌，每排 4 张，红毯两边各 2 张。每张桌子坐 10 个人，宾客们坐在桌边吃席、聊天。",
                "画面一屏看不完整个厅，人物走到哪里，镜头就跟到哪里；手指在屏幕上拖动也可以看别处。",
                "走到婚礼台前新人跟前，会弹出一个框，可以给新人写几句悄悄话，只有新人看得到。左上角的“席面菜单”能看今天席上有哪些菜，中午、晚上各是一桌菜单。",
            ]),
            ("七、进厅与分座", [
                "进厅时，玩家会被分到一张桌子的座位上，镜头先从大门滑到自己那桌，人站在桌边。是朋友邀请来的，会尽量和邀请人坐一桌；桌子都坐满时，会先安排坐墙边的长凳。",
                "离开过宴会厅、再回来时，屏幕上方会出现一张小卡，告诉玩家这段时间谁敬了自己、自己这桌的簿子上多了几句、还有几位来过。卡上可以直接“回敬一杯”或“翻簿子”。",
            ]),
        ],
        "shots": ["big_stage", "arrive_card"],
    },
    {
        "sections": [
            ("八、找座位、坐下与换桌", [
                "自己那桌一直挂着桌牌，写着几号桌和这桌今天玩的小游戏；走近别的桌子时，那桌的桌牌也会亮起来。",
                "走到一把空椅子旁边，屏幕下方出现“坐这儿”。点一下，上方会问“换到 X 号桌那桌？”，按钮变成“再点一下确认”；再点一次就坐下，上方提示“坐好了”。换桌次数不限。",
                "椅子已经有人坐时会提示“这把有人坐了”。主桌留给新人的家里人，普通宾客走到主桌跟前不会出现“坐这儿”。",
            ]),
            ("九、看人与敬酒", [
                "走近一位坐着的宾客，下方出现“看看 某某”，点开是他的卡片。卡片上可以“敬一杯”，敬了以后会放一张“干杯”的小插图，对方下次进厅时也会知道。",
                "已经敬过的人再敬，会提示“这杯敬过了”；一天敬的次数有上限，到了会提示“今天敬够了”。和自己同桌、或者互相敬过酒的人，还可以点“想认识你”，表示想认识对方。",
            ]),
        ],
        "shots": ["big_sit_far", "toast_send"],
    },
    {
        "sections": [
            ("十、翻簿子", [
                "每张桌子上放着一本簿子。坐下以后点“翻簿子”，就能看到这桌宾客写过的话，一行一句，前面是写的人的名字。",
                "下面的框里可以“接一句”，最多 100 个字，写好点“好”就留在这桌的簿子上，之后来坐这桌的人都能翻到。还没人写过时，簿子上会显示“还没人写 你来第一句”。",
                "没坐下也能翻看，但要写得先坐下，会提示“先坐下 慢慢写”。",
            ]),
            ("十一、主桌", [
                "主桌在婚礼台前，坐着新人的家里人，每位头上有称呼，比如外婆。走近家里人时，下方出现“和某某聊聊”，点一下对方会说一句话。",
                "主桌的 1、2 号座位留给新人本人，普通宾客不能换进主桌，走到跟前也不会出现“坐这儿”。",
            ]),
        ],
        "shots": ["book", "big_main"],
    },
    {
        "sections": [
            ("十二、席间小游戏：连连看", [
                "坐下以后，下方会出现“玩·游戏名”，点开就是这桌的小游戏。54 张普通桌按当天的日期分成三种游戏，换一桌就可能换一种玩。每局先看开始卡上的玩法和目标，点“开始”。",
                "连连看：点一张菜牌，再点一张一样的，两张能用拐弯不超过两次的线连起来就一起消掉。连线可以绕到棋盘外面一圈。全部消完就过关，右上角的时间用完就算没过。",
                "关数越往后，棋盘越大、菜的种类越多。每过一关解锁一道本地菜，收进小游戏里的“菜单册”，能翻看菜名和一句短评。",
            ]),
            ("十三、席间小游戏：川菜消消乐", [
                "川菜消消乐：交换相邻的两道菜，让横着或竖着 3 道以上一样的菜连成一排就会消掉、得分，上面的菜掉下来补上，还能连着消。",
                "步数用完前分数达到目标就过关。换了凑不成时，两道菜会滑回原位，不扣步数。关数越往后，菜的种类越多，要凑的分也越高。",
            ]),
        ],
        "shots": ["game_lianliankan_play", "game_match3_play"],
    },
    {
        "sections": [
            ("十四、席间小游戏：小菜合大菜", [
                "小菜合大菜：在棋盘上往上、下、左、右滑，同样的两格碰到一起就合成更大一级。顶栏写着这一关的目标和现在合到的最大一级，合出目标就过关；棋盘满了又合不了就算没过。",
                "格子上画的是一种作物从种下到上桌的样子。第 1 关是水稻：谷种、芽谷、秧苗，一级级合上去，最后是一碗米饭；往后的关换别的作物。",
                "三个小游戏通关都能得到金币，没过也给一点；玩到一半点“歇一下”会停在当前进度，不算输，也不扣金币。进度和金币自动保存，换一部手机进厅也能接着玩。",
            ]),
            ("十五、开席与亲友", [
                "宴会厅里有新人的亲友。按北京时间，中午 12 点到 2 点、傍晚 5 点到 7 点是开席时间：亲友会回到自己那桌坐下，隔一阵有人端着杯子去主桌敬酒，还有一桌在打牌，玩家可以在旁边看。",
                "其他时间亲友在厅里走动、站着聊天。走近一位亲友，下方出现“看看某某”，点开能看到他的称呼和与新人的关系，比如“爸爸的大哥”。",
            ]),
        ],
        "shots": ["game_g2048_play", "big_feast"],
    },
    {
        "sections": [
            ("十六、金币与消费说明", [
                "金币只能靠玩席间小游戏得到，游戏里没有任何充值、购买金币的入口，也没有付款功能。",
                "手上的金币显示在左上角。金币有两个用处：给新人写悄悄话时可以“添礼金”，添的金币记在礼金簿上；坐在自己桌上时可以“添一道菜”，40 金一道，服务员会把菜端到这桌上，一直摆到离开宴会厅。金币只换这样一个当下的小场面，不会让人物变强。",
            ]),
            ("十七、数据保存说明", [
                "需要和别的宾客共享的内容存在服务端：名字和形象、坐在哪桌哪把椅子、敬酒记录、每桌簿子上的话、签到名字和礼金数。签到名字和礼金数不公开给其他宾客；给新人写的悄悄话只有新人看得到。",
                "小游戏进度和金币在本机和服务端各存一份；合影相纸只存在本机。",
                "名字和簿子上的留言写进去之前，都会检查有没有不合适的词，有的话会提示换一个。",
            ]),
            ("十八、常见提示", [
                "“没连上 再试一下”：网络没连上服务端，稍后再点一次。",
                "“这把有人坐了”：这把椅子刚被别人坐了，换一把。",
                "“先坐下 再玩”：小游戏要坐到桌边才能开。",
                "“今天敬够了”：今天敬酒的次数用完了，第二天再来。",
                "“这个名字留给主角了，换一个吧”：这个名字给新人留着，起一个别的。",
            ]),
        ],
        "shots": [],
    },
]

# 上面按节写；排版时顺着重新分页：每页字 30～42 行、截图最多 4 张（2×2）。分法写死在这里，改了字重跑会报行数
GROUPS = [[0], [1, 2, 3, 4], [5, 6, 7], [8, 9, 10, 11], [12, 13, 14], [15, 16, 17]]
_SECS = [(sec, shot) for pg in PAGES for sec, shot in zip(pg["sections"], pg["shots"] + [None] * len(pg["sections"]))]
PAGES = [{"cover": g == [0], "sections": [_SECS[i][0] for i in g], "shots": [_SECS[i][1] for i in g if _SECS[i][1]]}
         for g in GROUPS]


def width(s):
    return sum(2 if ord(ch) > 0x2E7F or ch in "“”" else 1 for ch in s)


def wrap(text, first_indent=True):
    out, cur, w = [], "　　" if first_indent else "", 4 if first_indent else 0
    for ch in text:
        cw = 2 if ord(ch) > 0x2E7F or ch in "“”" else 1
        if ch in "，。、；：？！”）" and not cur and out:
            out[-1] += ch   # 刚折了行又来一个标点（比如”。连着）：挂在上一行末尾
            continue
        if w + cw > COLS:
            # 中文标点别落在行首
            if ch in "，。、；：？！”）" and cur:
                cur += ch; out.append(cur); cur, w = "", 0; continue
            carry = ""
            if cur.endswith(("“", "（")):
                carry, cur = cur[-1], cur[:-1]   # 前引号、前括号别落在行尾
            out.append(cur); cur, w = carry, width(carry)
        cur += ch; w += cw
    if cur:
        out.append(cur)
    return out


def toc_rows():
    rows = [("h1", "苏七镇奇缘游戏软件 V1.0 软件说明书"), ("blank", ""), ("h2", "目录")]
    for no, pg in enumerate(PAGES, 1):
        for title, _ in pg["sections"]:
            rows.append(("toc", (title, no)))
    rows.append(("blank", ""))
    return rows


def page_rows(pg):
    rows = toc_rows() if pg.get("cover") else []
    for title, paras in pg["sections"]:
        rows.append(("h2", title))
        for p in paras:
            for r in wrap(p):
                rows.append(("p", r))
    return rows


def render_row(kind, val):
    if kind == "toc":
        title, no = val
        return '<div class="r toc"><span>%s</span><span>%d</span></div>' % (html.escape(title), no)
    if kind == "blank":
        return '<div class="r">&nbsp;</div>'
    return '<div class="r %s">%s</div>' % (kind, html.escape(val))


def main():
    out_dir, shot_dir = sys.argv[1], sys.argv[2]
    img_dir = os.path.join(out_dir, "截图")
    os.makedirs(img_dir, exist_ok=True)
    for k, name in SHOTS.items():
        shutil.copy(os.path.join(shot_dir, k + ".png"), os.path.join(img_dir, name))
        # PDF 里嵌 JPEG（PNG 嵌进去整本 6 MB），原图 png 留在截图目录
        Image.open(os.path.join(shot_dir, k + ".png")).convert("RGB").save(
            os.path.join(img_dir, name[:-4] + ".jpg"), quality=88)
    pages = []
    for no, pg in enumerate(PAGES, 1):
        rows = page_rows(pg)
        n = len(rows)
        print("第 %d 页 %d 行" % (no, n))
        if n < MIN_ROWS or n > MAX_ROWS:
            sys.exit("第 %d 页 %d 行，要在 %d～%d 行之间" % (no, n, MIN_ROWS, MAX_ROWS))
        shots = "".join('<figure><img src="截图/%s"><figcaption>图 %s</figcaption></figure>'
                        % (SHOTS[s][:-4] + ".jpg", SHOTS[s][:2].lstrip("0") + "　" + SHOTS[s][3:-4]) for s in pg["shots"])
        pages.append('<section class="pg"><header><span>%s</span><span>%d</span></header><div class="body">'
                     '<div class="txt">%s</div>%s</div></section>'
                     % (TITLE, no, "".join(render_row(k, v) for k, v in rows),
                        '<div class="imgs">%s</div>' % shots if shots else ""))
    css = """
@page { size: A4 portrait; margin: 12mm 14mm 12mm 14mm; }
body { margin: 0; font-family: "PingFang SC", "STHeiti", sans-serif; font-size: 10.5pt; color: #000; }
.pg { page-break-after: always; break-after: page; }
.pg:last-child { page-break-after: auto; break-after: auto; }
header { display: flex; justify-content: space-between; font-size: 9pt; border-bottom: 0.5pt solid #000;
         padding-bottom: 1.5mm; margin-bottom: 4mm; }
.body { display: flex; gap: 6mm; }
.txt { flex: 1; }
.r { height: 6.0mm; line-height: 6.0mm; white-space: pre; overflow: hidden; }
.h1 { font-size: 15pt; font-weight: bold; text-align: center; }
.h2 { font-weight: bold; }
.toc { display: flex; justify-content: space-between; padding-left: 2em; border-bottom: 0.3pt dotted #999; }
.imgs { width: 104mm; display: grid; grid-template-columns: 50mm 50mm; gap: 3mm 4mm; align-content: start; }
figure { margin: 0; }
img { width: 50mm; height: 88.9mm; display: block; border: 0.3pt solid #999; }
figcaption { font-size: 9pt; text-align: center; margin-top: 1mm; }
"""
    doc = ('<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><title>%s 软件说明书</title><style>%s</style></head>'
           '<body>%s</body></html>' % (TITLE, css, "".join(pages)))
    open(os.path.join(out_dir, "说明书.html"), "w", encoding="utf-8").write(doc)
    print("共 %d 页" % len(pages))


if __name__ == "__main__":
    main()
