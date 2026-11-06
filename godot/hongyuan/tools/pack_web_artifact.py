"""把 Godot Web 导出改成能放进私密 Artifact 的形式：wasm 先 gzip，wasm 和 pck 转成 base64 文本，
页面里拦截 fetch 还原。用法：python3 pack_web_artifact.py <导出目录> <输出目录>"""
import sys, os, re, gzip, base64, shutil
src, dst = sys.argv[1], sys.argv[2]
os.makedirs(dst, exist_ok=True)
for old in os.listdir(dst):
    if old.endswith(".b64.txt"):
        os.remove(os.path.join(dst, old))
CHUNK = 12 * 1024 * 1024
def chunks(name, data):
    text = base64.b64encode(data).decode()
    parts = [text[i:i + CHUNK] for i in range(0, len(text), CHUNK)]
    for i, part in enumerate(parts):
        open(os.path.join(dst, "%s.%d.b64.txt" % (name, i)), "w").write(part)
    return len(parts)
nw = chunks("wasm", gzip.compress(open(os.path.join(src, "index.wasm"), "rb").read(), 9))
np_ = chunks("pck", open(os.path.join(src, "index.pck"), "rb").read())
for f in ["index.js", "index.audio.worklet.js", "index.audio.position.worklet.js", "index.png", "index.icon.png"]:
    shutil.copy(os.path.join(src, f), dst)
s = open(os.path.join(src, "index.html")).read()
patch = r'''<script>
(function(){const f=window.fetch.bind(window);
function b64(name,n){const ps=[];for(let i=0;i<n;i++)ps.push(f(name+'.'+i+'.b64.txt').then(function(r){if(!r.ok)throw new Error(name+' '+r.status);return r.text();}));return Promise.all(ps).then(function(ts){const bin=atob(ts.join('').trim());const a=new Uint8Array(bin.length);for(let i=0;i<bin.length;i++)a[i]=bin.charCodeAt(i);return a;});}
window.fetch=function(i,o){const u=typeof i==='string'?i:(i&&i.url)||'';
if(/index\.wasm(\?|$)/.test(u)){return b64('wasm',NW).then(function(a){return new Response(new Blob([a]).stream().pipeThrough(new DecompressionStream('gzip')),{headers:{'Content-Type':'application/wasm'}});});}
if(/index\.pck(\?|$)/.test(u)){return b64('pck',NP).then(function(a){return new Response(a,{headers:{'Content-Type':'application/octet-stream','Content-Length':String(a.length)}});});}
return f(i,o);};})();
</script>
<script src="index.js"></script>'''
patch = patch.replace('NW', str(nw)).replace('NP', str(np_))
s = s.replace('<script src="index.js"></script>', patch, 1)
s = re.sub(r'<title>.*?</title>', '<title>红缘大冒险</title>', s)
for pat in [r'<!DOCTYPE html>\s*', r'<html[^>]*>\s*', r'</html>', r'</?head>\s*', r'<meta charset="utf-8">\s*', r'<meta name="viewport"[^>]*>\s*', r'<body>\s*', r'</body>']:
    s = re.sub(pat, '', s)
open(os.path.join(dst, "index.html"), "w").write(s.strip() + "\n")
print("ok", {f: os.path.getsize(os.path.join(dst, f)) for f in os.listdir(dst)})
