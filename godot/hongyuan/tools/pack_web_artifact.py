"""把 Godot Web 导出改成能放进私密 Artifact 的形式：wasm 先 gzip，wasm 和 pck 转成 base64 文本，
页面里拦截 fetch 还原。用法：python3 pack_web_artifact.py <导出目录> <输出目录>"""
import sys, os, re, gzip, base64, shutil
src, dst = sys.argv[1], sys.argv[2]
os.makedirs(dst, exist_ok=True)
open(os.path.join(dst, "wasm.gz.b64.txt"), "w").write(base64.b64encode(gzip.compress(open(os.path.join(src, "index.wasm"), "rb").read(), 9)).decode())
open(os.path.join(dst, "pck.b64.txt"), "w").write(base64.b64encode(open(os.path.join(src, "index.pck"), "rb").read()).decode())
for f in ["index.js", "index.audio.worklet.js", "index.audio.position.worklet.js", "index.png", "index.icon.png"]:
    shutil.copy(os.path.join(src, f), dst)
s = open(os.path.join(src, "index.html")).read()
patch = r'''<script>
(function(){const f=window.fetch.bind(window);
function b64(u){return f(u).then(function(r){if(!r.ok)throw new Error(u+' '+r.status);return r.text();}).then(function(t){const bin=atob(t.trim());const a=new Uint8Array(bin.length);for(let i=0;i<bin.length;i++)a[i]=bin.charCodeAt(i);return a;});}
window.fetch=function(i,o){const u=typeof i==='string'?i:(i&&i.url)||'';
if(/index\.wasm(\?|$)/.test(u)){return b64('wasm.gz.b64.txt').then(function(a){return new Response(new Blob([a]).stream().pipeThrough(new DecompressionStream('gzip')),{headers:{'Content-Type':'application/wasm'}});});}
if(/index\.pck(\?|$)/.test(u)){return b64('pck.b64.txt').then(function(a){return new Response(a,{headers:{'Content-Type':'application/octet-stream','Content-Length':String(a.length)}});});}
return f(i,o);};})();
</script>
<script src="index.js"></script>'''
s = s.replace('<script src="index.js"></script>', patch, 1)
s = re.sub(r'<title>.*?</title>', '<title>红缘大冒险</title>', s)
for pat in [r'<!DOCTYPE html>\s*', r'<html[^>]*>\s*', r'</html>', r'</?head>\s*', r'<meta charset="utf-8">\s*', r'<meta name="viewport"[^>]*>\s*', r'<body>\s*', r'</body>']:
    s = re.sub(pat, '', s)
open(os.path.join(dst, "index.html"), "w").write(s.strip() + "\n")
print("ok", {f: os.path.getsize(os.path.join(dst, f)) for f in os.listdir(dst)})
