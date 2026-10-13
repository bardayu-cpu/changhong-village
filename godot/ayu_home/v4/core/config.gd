extends RefCounted
const INSTITUTION_GAMES={
 "mill":{"title":"推石磨 · 磨谷粉","steps":12,"input":{"grain":2},"output":{"flour":1},"daily":false,"host":"小涛"},
 "honey":{"title":"压蜜装瓶","steps":6,"input":{},"output":{"honey":1},"daily":true,"host":"凯凯"},
 "civic":{"title":"整理村务卡","steps":3,"input":{},"output":{"bamboo":1},"daily":true,"host":"林伯"},
 "community":{"title":"张罗共桌","steps":3,"input":{"radish":1,"pepper":1},"output":{"meal":1},"daily":false,"host":"方婆婆"}}
const INSTITUTION_ROOMS={"v_h3":{"game":"mill","host":"小涛","actions":["sift","tea","sweep"]},"v_h5":{"game":"honey","host":"凯凯","actions":["wash","filter","bottle","tea"]},"v_mayor":{"game":"civic","host":"林伯","actions":["register","counter","notice","bundle"]},"my_cabin":{"game":"community","host":"方婆婆","actions":["weave","table","read","tidy"]}}
## 本轮可改表的唯一数值源；所有秒数都是现实时间，无玩家付费加速。
const ANIMAL_SECONDS=300
const ANIMAL_ITEMS=4
const PETS={"xiduo":"喜多","qiuqiu":"求求","luoluo":"落落","tiantian":"天天"}
const CROPS={
 "radish":{"name":"楼卜","seconds":120,"yield":3,"seed":"radish_seed"},
 "pepper":{"name":"海椒","seconds":180,"yield":3,"seed":"pepper_seed"},
 "grain":{"name":"谷子","seconds":240,"yield":4,"seed":"grain_seed"}}
const RECIPES={
 "meal":{"name":"海椒拌楼卜","station":"stove","seconds":90,"input":{"radish":1,"pepper":1},"output":"meal"},
 "flour":{"name":"谷粉","station":"mill","seconds":60,"input":{"grain":2},"output":"flour"},
 "porridge":{"name":"谷香粥","station":"stove","seconds":90,"input":{"flour":1},"output":"porridge"}}
const ITEMS={"radish":"楼卜","pepper":"海椒","grain":"谷子","radish_seed":"楼卜种","pepper_seed":"海椒种","grain_seed":"谷种","stone":"石头","bamboo":"竹材","tool":"旧锄头","parcel":"动物包","meal":"海椒拌楼卜","flour":"谷粉","porridge":"谷香粥","honey":"蜂蜜","fish":"鲜鱼","egg":"鸡蛋","fruit":"时令果"}
const ORDERS=[{"key":"o01","who":"妈妈","title":"一碟海椒","items":{"pepper":2},"coins":55,"family":true},{"key":"o07","who":"隔壁婆婆","title":"热粥一碗","items":{"porridge":1},"coins":70,"family":false},{"key":"o02","who":"牛肉店伙计","title":"磨坊添谷","items":{"grain":3},"coins":60,"family":false},{"key":"o05","who":"阿鱼","title":"拌菜一碗","items":{"meal":1},"coins":75,"family":true},{"key":"o03","who":"林伯","title":"午饭楼卜","items":{"radish":2},"coins":62,"family":false},{"key":"o04","who":"凯凯","title":"蜂蜜糕用粉","items":{"flour":1},"coins":72,"family":false},{"key":"o06","who":"村民活动中心","title":"聚餐配菜","items":{"radish":1,"pepper":1},"coins":62,"family":false},{"key":"o08","who":"小涛","title":"谷粮和菜","items":{"grain":2,"radish":1},"coins":66,"family":false},{"key":"o09","who":"妈妈","title":"晒楼卜干","items":{"radish":3},"coins":65,"family":true},{"key":"o10","who":"凯凯","title":"邻里分海椒","items":{"pepper":3},"coins":64,"family":false},{"key":"o11","who":"林伯","title":"储粮补一袋","items":{"grain":4},"coins":70,"family":false},{"key":"o12","who":"村民活动中心","title":"蒸糕配料","items":{"flour":1,"radish":1},"coins":80,"family":false}]
const RESIDENCY={"coins":100,"items":{"radish":2,"bamboo":2},"orders":3}
const LOCATIONS={"lake":"湖边","bamboo":"竹林里","hill":"山坡上","garden":"花园中间"}
const LAND=[{"coins":60,"items":{"stone":2,"bamboo":1,"tool":1}},{"coins":120,"items":{"stone":3,"bamboo":2,"tool":1}},{"coins":180,"items":{"stone":4,"bamboo":3,"tool":1}}]
const FURNITURE={"chair":{"name":"竹椅","items":{"bamboo":2},"visual":"低竹椅、藤色座面；休息"},"table":{"name":"小木桌","items":{"bamboo":3,"stone":1},"visual":"四脚小桌、深木边；摆物"},"planter":{"name":"花架","items":{"bamboo":2,"stone":2},"visual":"两层竹格架；绿植"},"grain_crate":{"name":"谷粮小箱","items":{"bamboo":3},"visual":"谷穗刻线小箱；储物","texture":"res://ayu_home/v4/assets/craft/grain_crate.png"},"tea_stool":{"name":"矮茶凳","items":{"bamboo":2,"stone":1},"visual":"方矮凳配茶垫；歇脚","texture":"res://ayu_home/v4/assets/craft/tea_stool.png"},"bamboo_screen":{"name":"竹屏风","items":{"bamboo":5},"visual":"横编竹屏与矮脚；分区","texture":"res://ayu_home/v4/assets/craft/bamboo_screen.png"},"honey_rack":{"name":"蜂蜜小架","items":{"bamboo":4,"stone":1},"visual":"蜂巢形侧板；摆物","texture":"res://ayu_home/v4/assets/craft/honey_rack.png"},"clay_pot":{"name":"陶花盆","items":{"stone":3},"visual":"红褐粗陶圆盆；绿植","texture":"res://ayu_home/v4/assets/craft/clay_pot.png"},"hanging_lamp":{"name":"暖灯架","items":{"bamboo":3,"stone":2},"visual":"竹杆悬暖灯；照明","texture":"res://ayu_home/v4/assets/craft/hanging_lamp.png"},"wash_basin":{"name":"石洗盆","items":{"stone":4,"bamboo":1},"visual":"浅石盆与短木托；清洁","texture":"res://ayu_home/v4/assets/craft/wash_basin.png"},"picnic_mat":{"name":"野餐席","items":{"bamboo":4},"visual":"竹编席、深绿包边；活动","texture":"res://ayu_home/v4/assets/craft/picnic_mat.png"},"notice_easel":{"name":"留言画架","items":{"bamboo":5,"stone":2},"visual":"木脚架夹留言板；活动","texture":"res://ayu_home/v4/assets/craft/notice_easel.png"}}
const BOX_COST=30
## 每件抽取：工具 12%，动物包 8%，石头 20%，竹材 20%，三种种子共 40%。
const LOOT=[{"id":"tool","weight":12},{"id":"parcel","weight":8},{"id":"stone","weight":20},{"id":"bamboo","weight":20},{"id":"radish_seed","weight":14},{"id":"pepper_seed","weight":13},{"id":"grain_seed","weight":13}]
const SEED_COST=3
const START_ITEMS={"radish_seed":3,"pepper_seed":3,"grain_seed":4}

const PRODUCERS={
 "honey":{"name":"蜂蜜箱","seconds":240,"input":{},"output":"honey","yield":2},
 "pond":{"name":"池塘","seconds":180,"input":{"grain":1},"output":"fish","yield":2},
 "chicken":{"name":"鸡圈","seconds":180,"input":{"grain":1},"output":"egg","yield":2},
 "orchard":{"name":"果树","seconds":300,"input":{},"output":"fruit","yield":3}}
const NEIGHBOURS={
 "honey":{"name":"凯凯","house":"h5","request":{"honey":1},"coins":0,"gift":{},"first":"花架还空着。帮我收一瓶蜜，摆盆花在这里吧。","again":"你上次留下的蜜很香。花架一直给你留着位置。"},
 "mill":{"name":"小涛","house":"h3","request":{"flour":1},"coins":0,"gift":{},"first":"谷子磨成粉，便能煮粥。帮我带一袋，石磨随时借你。","again":"上次的谷粉派上用场了。坐下，我再泡壶茶。"}}
const LOCATION_POINTS={"lake":[1300,4080],"bamboo":[1750,4080],"hill":[1300,4480],"garden":[1750,4480]}

const DAILY_ORDER_COUNT=4
const ORDER_ROTATION_DAYS=3
const ORDER_EPOCH="2026-10-06"
const FIRST_TRIP_GUARANTEE=["stone","stone","bamboo","bamboo","bamboo","tool"]
const FIRST_TRIP_SLOTS=16
const ANIMAL_TOOL_MISSES=5
const BOX_TOOL_CHANCE=0.25
const BOX_TOOL_MISSES=3
const DUPLICATE_BLUEPRINT_BAMBOO=3
const FOOD_SALE_COINS=12
const LAND_SECONDS=3
const MARKET_GOODS=[{"bamboo":9,"radish_seed":2,"honey":18},{"stone":10,"pepper_seed":2,"egg":18},{"bamboo":9,"grain_seed":2,"fruit":18}]
const NEIGHBOUR_REQUESTS={"honey":[{"honey":1},{"fruit":2},{"egg":2}],"mill":[{"flour":1},{"grain":3},{"porridge":1}]}
const SEASON_REQUESTS={"wet":{"grain":1},"dry":{"fruit":1}}

const DOOR_CHORES={"erba":{"owner":"二爸","closed":"门闩落下了","label":"点亮门边灯","response":"灯芯拨亮了，二爸留话：今晚在田边忙，灯替我照着晚归的人。"},"daba":{"owner":"大爸","closed":"竹帘放下了","label":"收齐散竹条","response":"竹条捆成小束，大爸留话：今天出门送竹器，门边这些留着明天编。"},"h1":{"owner":"街口人家","closed":"屋里在午睡","label":"把报纸卷进筒","response":"报纸卷好了，门上便签写着：家里正在午睡，这一卷留给晚上慢慢看。"},"h2":{"owner":"方婆婆","closed":"活动中心值日","label":"理顺门边线筐","response":"线头绕回轴上，方婆婆留话：我在活动中心值日，线筐多谢你理顺。"},"h4":{"owner":"石阶人家","closed":"全家去赶集","label":"扫净门前落叶","response":"落叶扫成一小堆，门边字条说：我们去赶集了，石阶清爽得像早上的风。"},"h6":{"owner":"花窗人家","closed":"门帘已放下","label":"给窗下花浇水","response":"水润进花土，叶片挺起来了，住户留话：今天在后院忙，花托你照看一会儿。"},"h7":{"owner":"晒谷人家","closed":"今天下田去了","label":"翻一翻晒粮盘","response":"谷粒翻过一面，晒粮人留话：我下田去了，金黄这一面也要见见太阳。"},"h8":{"owner":"柴火人家","closed":"烟囱旁留了条","label":"码好门旁柴段","response":"柴段码得稳稳的，门边字条说：屋里在熏豆干，今天先在门边歇脚。"},"flower":{"owner":"花园人家","closed":"一家出门赏花","label":"给鸟饮盆添水","response":"小饮盆映出天光，花园人留话：我们赏花去了，麻雀的水别忘了添满。"},"whitebrick":{"owner":"白砖人家","closed":"门内传来琴声","label":"擦亮铜铃","response":"铜铃擦亮了，清脆响了一声，住户隔门说：正在教小孩弹琴，晚些再坐。"},"grape":{"owner":"葡萄架人家","closed":"藤帘放下了","label":"扶好葡萄藤","response":"藤条扎在小竹竿上，院里传来一句：葡萄正挑着呢，明天再请你进来吃。"},"sunflower":{"owner":"向日葵人家","closed":"主人去看蜂了","label":"收拢葵籽盘","response":"葵籽归进小盘，向日葵人留话：我去看蜂了，鸟儿那一份就留在门旁。"},"persimmon":{"owner":"柿树人家","closed":"家里在晒柿饼","label":"捡起落地柿子","response":"三只熟柿子安稳进了篮，院里传来一句：今天晒柿饼腾不开手，秋甜先收好。"},"rose":{"owner":"玫瑰人家","closed":"午后歇一会儿","label":"摘去枯花瓣","response":"枯花瓣收走，玫瑰露出新花心，门边小卡写着：午后歇一会儿，花香陪你坐。"}}
