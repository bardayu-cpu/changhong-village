extends RefCounted
## 家里的动作声：全部用代码现场合成，不用任何外来录音（没有版权问题）。
## 体验师 10/5：所有小游戏只有同一个合成「叮」。这里给主要动作各配一种声音：
## 烧水、倒水、流水、收线、洗衣、翻牌、快门、下锅、搅汤、翻土、摘果、甩竿、溅水……
const RATE := 22050
static var cache: Dictionary = {}

static func get_sound(name: String) -> AudioStreamWAV:
	if cache.has(name):return cache[name]
	var samples: PackedFloat32Array
	match name:
		"boil":samples=_boil(2.2)          # 水壶慢慢滚起来：低沉的沙沙 + 越来越密的小气泡
		"kettle":samples=_whistle(.9)      # 水开了，壶嘴轻轻一声哨
		"pour":samples=_pour(1.4)          # 倒水：细流声，音高慢慢往上走（杯子在满）
		"stream":samples=_noise(1.2,.35,.12) # 流水
		"leaf":samples=_rustle(.35,.5)     # 茶叶、花枝落下
		"plop":samples=_plop(.35,180.0)    # 菜下锅、浮漂一沉
		"stir":samples=_stir(.6)           # 勺子贴着锅边搅一圈
		"bubble":samples=_boil(1.2)        # 汤咕嘟
		"cloth":samples=_rustle(.3,.8)     # 衣服抖一抖、挂上绳
		"wash":samples=_wash(2.0)          # 滚筒转起来：低低的嗡 + 水声一阵一阵
		"sand":samples=_rustle(.12,1.0)    # 砂纸磨木头
		"cast":samples=_cast(.7)           # 甩竿：呼一声，再落水
		"reel":samples=_reel(.5)           # 收线：一串咔嗒
		"splash":samples=_splash(.6)       # 鱼出水、网兜捞起
		"flip":samples=_flip(.16)          # 翻牌：纸片一翻
		"shutter":samples=_shutter(.35)    # 拍立得快门：咔—嚓
		"dig":samples=_dig(.3)             # 翻土
		"seed":samples=_plop(.18,420.0)    # 种子落进土里
		"pick":samples=_pick(.2)           # 摘果子：啵
		"kick":samples=_plop(.22,120.0)    # 踢球
		"twinkle":samples=_twinkle(1.0)    # 流星划过
		"knock":samples=_knock(.5)
		"bark":samples=_bark(.42)            # 喜多轻轻「汪汪」两声，音量小
		"cicada":samples=_cicada(8.0)       # 夏日树间的一阵蝉声；缓存后循环，首尾平滑归零
		_:samples=_plop(.2,300.0)
	var wav:=AudioStreamWAV.new();wav.format=AudioStreamWAV.FORMAT_16_BITS;wav.mix_rate=RATE
	var bytes:=PackedByteArray();bytes.resize(samples.size()*2)
	for i in samples.size():bytes.encode_s16(i*2,int(clampf(samples[i],-1,1)*26000))
	wav.data=bytes
	if name=="cicada":wav.loop_mode=AudioStreamWAV.LOOP_FORWARD;wav.loop_begin=0;wav.loop_end=samples.size()
	cache[name]=wav;return wav

static func _rand(seed: int) -> float:
	var x:=sin(float(seed)*12.9898+78.233)*43758.5453
	return (x-floor(x))*2.0-1.0
static func _cicada(sec:float) -> PackedFloat32Array:
	var out:=PackedFloat32Array();out.resize(int(sec*RATE));var previous:=0.0
	for i in out.size():
		var t:=float(i)/RATE
		var envelope:=pow(sin(PI*float(i)/float(out.size()-1)),2.0)
		var pulse:=.55+.45*sin(TAU*57.0*t)
		var chorus:=.72+.28*sin(TAU*.625*t)
		var carrier:=sin(TAU*3850.0*t+1.8*sin(TAU*113.0*t))+.36*sin(TAU*4720.0*t)
		var noise:=_rand(i*7+31);var rasp:=noise-previous;previous=noise
		out[i]=(carrier*.38+rasp*.10)*pulse*chorus*envelope
	return out
static func _noise(sec: float, low: float, gain: float) -> PackedFloat32Array:
	var out:=PackedFloat32Array();out.resize(int(sec*RATE));var y:=0.0
	for i in out.size():
		y+= (_rand(i)-y)*low;var env:=minf(1.0,float(i)/800.0)*minf(1.0,float(out.size()-i)/1500.0)
		out[i]=y*gain*4.0*env
	return out
static func _boil(sec: float) -> PackedFloat32Array:
	var out:=_noise(sec,.08,.18)
	var t:=0
	while t<out.size():
		var gap:int=int(lerpf(3000,500,float(t)/out.size()));var f:float=300.0+fposmod(float(t)*.37,500.0)
		for k in mini(900,out.size()-t):out[t+k]+=sin(TAU*f*k/RATE*(1.0+k/1800.0))*exp(-float(k)/220.0)*.22
		t+=gap+int(absf(_rand(t))*gap)
	return out
static func _whistle(sec: float) -> PackedFloat32Array:
	var out:=PackedFloat32Array();out.resize(int(sec*RATE))
	for i in out.size():
		var env:=minf(1.0,float(i)/3000.0)*minf(1.0,float(out.size()-i)/2500.0)
		out[i]=sin(TAU*(1650.0+sin(i*.0009)*40.0)*i/RATE)*env*.18+_rand(i)*.03*env
	return out
static func _pour(sec: float) -> PackedFloat32Array:
	var out:=PackedFloat32Array();out.resize(int(sec*RATE));var y:=0.0
	for i in out.size():
		var p:=float(i)/out.size();y+=(_rand(i)-y)*(.25+p*.25)
		var ring:=sin(TAU*lerpf(500,1100,p)*i/RATE)*.08
		var env:=minf(1.0,float(i)/600.0)*minf(1.0,float(out.size()-i)/1800.0)
		out[i]=(y*.45+ring*(.5+.5*sin(i*.02)))*env
	return out
static func _rustle(sec: float, bright: float) -> PackedFloat32Array:
	var out:=PackedFloat32Array();out.resize(int(sec*RATE));var y:=0.0;var prev:=0.0
	for i in out.size():
		var n:=_rand(i*3+7);y+=(n-y)*(.3+bright*.5);var hp:=y-prev;prev=y
		var env:=sin(PI*float(i)/out.size())*(.6+.4*absf(sin(i*.004)))
		out[i]=hp*env*.9
	return out
static func _plop(sec: float, f0: float) -> PackedFloat32Array:
	var out:=PackedFloat32Array();out.resize(int(sec*RATE))
	for i in out.size():
		var t:=float(i)/RATE;out[i]=sin(TAU*f0*t*(1.0+t*6.0))*exp(-t*14.0)*.55+_rand(i)*exp(-t*60.0)*.2
	return out
static func _stir(sec: float) -> PackedFloat32Array:
	var out:=_rustle(sec,.3)
	for i in out.size():out[i]+=sin(TAU*240.0*i/RATE)*.04*sin(PI*float(i)/out.size())
	return out
static func _wash(sec: float) -> PackedFloat32Array:
	var out:=PackedFloat32Array();out.resize(int(sec*RATE));var y:=0.0
	for i in out.size():
		y+=(_rand(i)-y)*.05;var slosh:=.5+.5*sin(TAU*1.6*i/RATE)
		var env:=minf(1.0,float(i)/4000.0)*minf(1.0,float(out.size()-i)/4000.0)
		out[i]=(sin(TAU*55.0*i/RATE)*.12+y*.9*slosh)*env
	return out
static func _cast(sec: float) -> PackedFloat32Array:
	var out:=PackedFloat32Array();out.resize(int(sec*RATE));var y:=0.0
	var whoosh:=int(.4*RATE)
	for i in out.size():
		if i<whoosh:
			y+=(_rand(i)-y)*lerpf(.05,.6,float(i)/whoosh);out[i]=y*sin(PI*float(i)/whoosh)*.6
	var splash:=_plop(sec-.4,160.0)
	for i in splash.size():out[whoosh+i-1]+=splash[i]*.8
	return out
static func _reel(sec: float) -> PackedFloat32Array:
	var out:=PackedFloat32Array();out.resize(int(sec*RATE))
	for c in int(sec*22):
		var at:=int(c*RATE/22.0)
		for k in mini(260,out.size()-at):out[at+k]+=(_rand(at+k)*.5+sin(TAU*2400.0*k/RATE)*.5)*exp(-float(k)/45.0)*.5
	return out
static func _splash(sec: float) -> PackedFloat32Array:
	var out:=PackedFloat32Array();out.resize(int(sec*RATE));var y:=0.0
	for i in out.size():
		var t:=float(i)/RATE;y+=(_rand(i)-y)*.55;out[i]=y*exp(-t*7.0)*.8
		if i%2200<900:out[i]+=sin(TAU*(700.0+i%2200)*t)*exp(-float(i%2200)/180.0)*.1
	return out
static func _flip(sec: float) -> PackedFloat32Array:
	var out:=_rustle(sec,1.0)
	for i in mini(300,out.size()):out[i]+=sin(TAU*900.0*i/RATE)*exp(-float(i)/60.0)*.3
	return out
static func _shutter(sec: float) -> PackedFloat32Array:
	var out:=PackedFloat32Array();out.resize(int(sec*RATE))
	for click in [0,int(.13*RATE)]:
		for k in mini(1400,out.size()-click):out[click+k]+=(_rand(click+k)*.7+sin(TAU*1800.0*k/RATE)*.3)*exp(-float(k)/(110.0 if click==0 else 260.0))*.8
	return out
static func _dig(sec: float) -> PackedFloat32Array:
	var out:=_noise(sec,.12,.25)
	for i in out.size():out[i]*=exp(-float(i)/2200.0)*1.6
	return out
static func _pick(sec: float) -> PackedFloat32Array:
	var out:=PackedFloat32Array();out.resize(int(sec*RATE))
	for i in out.size():
		var t:=float(i)/RATE;out[i]=sin(TAU*lerpf(900,500,t/sec)*t)*exp(-t*30.0)*.5+_rand(i)*exp(-t*120.0)*.25
	return out
static func _twinkle(sec: float) -> PackedFloat32Array:
	var out:=PackedFloat32Array();out.resize(int(sec*RATE))
	for n in 6:
		var at:int=int(n*RATE*.12);var f:float=[1568.0,1760.0,2093.0,1760.0,2349.0,2637.0][n]
		for k in mini(int(RATE*.4),out.size()-at):out[at+k]+=sin(TAU*f*k/RATE)*exp(-float(k)/2500.0)*.12
	return out
static func _bark(sec: float) -> PackedFloat32Array:
	var out:=PackedFloat32Array();out.resize(int(sec*RATE))
	for n in 2:
		var at:int=int(n*RATE*.2)
		for k in mini(int(RATE*.12),out.size()-at):
			var t:=float(k)/RATE;var f:float=lerpf(560.0,330.0,t/.12)
			var env:=minf(1.0,t*120.0)*exp(-t*22.0)
			out[at+k]+=(sin(TAU*f*t)*.6+sin(TAU*f*2.0*t)*.2+_rand(at+k)*.12)*env*.32
	return out
static func _knock(sec: float) -> PackedFloat32Array:
	var out:=PackedFloat32Array();out.resize(int(sec*RATE))
	for n in 3:
		var at:=int(n*RATE*.15)
		for k in mini(1200,out.size()-at):out[at+k]+=sin(TAU*140.0*k/RATE)*exp(-float(k)/220.0)*.7+_rand(at+k)*exp(-float(k)/60.0)*.3
	return out
