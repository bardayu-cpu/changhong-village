extends SceneTree
## 每种动作声都能合成出来、有声音、彼此不一样
const Sfx=preload("res://ayu_home/v4/sfx.gd")
func _initialize() -> void:
	var names:=["boil","kettle","pour","stream","leaf","plop","stir","bubble","cloth","wash","sand","cast","reel","splash","flip","shutter","dig","seed","pick","kick","twinkle","knock","bark"]
	var fails:=[];var sigs:={}
	for n in names:
		var w:AudioStreamWAV=Sfx.get_sound(n);var peak:=0;var sig:=0
		for i in range(0,w.data.size()-1,2):var v:=absi(w.data.decode_s16(i));peak=maxi(peak,v);sig+=v
		print(n," 长 %.2f 秒 峰值 %d"%[w.data.size()/2.0/22050.0,peak])
		if peak<1500 or peak>32000:fails.append(n)
		sigs[str(w.data.size())+"-"+str(sig)]=true
	print("RESULT ","PASS" if fails.is_empty() and sigs.size()==names.size() else "FAIL"," ",fails," 不同的声音 ",sigs.size(),"/",names.size());quit()
