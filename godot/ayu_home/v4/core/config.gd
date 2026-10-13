extends RefCounted
const INSTITUTION_GAMES={
 "mill":{"title":"推石磨 · 磨谷粉","steps":12,"input":{"grain":2},"output":{"flour":1},"daily":false,"host":"小涛"},
 "honey":{"title":"压蜜装瓶","steps":6,"input":{},"output":{"honey":1},"daily":true,"host":"凯凯"},
 "civic":{"title":"整理村务卡","steps":3,"input":{},"output":{"bamboo":1},"daily":true,"host":"林伯"},
 "community":{"title":"张罗共桌","steps":3,"input":{"radish":1,"pepper":1},"output":{"meal":1},"daily":false,"host":"方婆婆"}}
const INSTITUTION_ROOMS={"v_h3":{"game":"mill","host":"小涛","actions":["sift","tea","sweep"]},"v_h5":{"game":"honey","host":"凯凯","actions":["wash","filter","bottle","tea"]},"v_mayor":{"game":"civic","host":"林伯","actions":["register","counter","notice","bundle"]},"my_cabin":{"game":"community","host":"方婆婆","actions":["wash","weave","read"]}}
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
const ORDERS=[
 {"who":"妈妈","items":{"pepper":2},"coins":55,"family":true},
 {"who":"隔壁婆婆","items":{"porridge":1},"coins":70,"family":false},
 {"who":"牛肉店伙计","items":{"grain":3},"coins":60,"family":false},
 {"who":"阿鱼","items":{"meal":1},"coins":75,"family":true}]
const RESIDENCY={"coins":100,"items":{"radish":2,"bamboo":2},"orders":3}
const LOCATIONS={"lake":"湖边","bamboo":"竹林里","hill":"山坡上","garden":"花园中间"}
const LAND=[{"coins":60,"items":{"stone":2,"bamboo":1,"tool":1}},{"coins":100,"items":{"stone":3,"bamboo":2,"tool":1}},{"coins":150,"items":{"stone":4,"bamboo":3,"tool":1}}]
const FURNITURE={"chair":{"name":"竹椅","items":{"bamboo":2}},"table":{"name":"小木桌","items":{"bamboo":3,"stone":1}},"planter":{"name":"花架","items":{"bamboo":2,"stone":2}}}
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
 "honey":{"name":"凯凯","house":"h5","request":{"honey":1},"coins":35,"gift":{"bamboo":2},"first":"花架还空着。帮我收一瓶蜜，摆盆花在这里吧。","again":"你上次留下的蜜很香。花架一直给你留着位置。"},
 "mill":{"name":"小涛","house":"h3","request":{"flour":1},"coins":40,"gift":{"stone":2},"first":"谷子磨成粉，便能煮粥。帮我带一袋，石磨随时借你。","again":"上次的谷粉派上用场了。坐下，我再泡壶茶。"}}
const LOCATION_POINTS={"lake":[1300,4080],"bamboo":[1750,4080],"hill":[1300,4480],"garden":[1750,4480]}
