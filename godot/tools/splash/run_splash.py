#!/usr/bin/env python3
"""开屏加载页在电脑上跑一遍、截几帧（01 E 10/3 验收）：拿导出目录里真的 godot-loader.js（模板的）+ splash.js + game.js 的 config + 图，
在无界面 Chrome 里装一个假的 wx（屏幕尺寸、像素比、分包下载进度），照真机的顺序走：
开头那句 → 下载 0%～100%（onProgressUpdate）→ 下完（initText）→ 引擎编译（compilingText）→ 引擎起来（cleanup，停）。
每一步截屏幕画布（WebGL，preserveDrawingBuffer），另外量一帧画多久；再跑一遍「没网」（下载一直不动）。
微信开发者工具的自动化端口 10/2 试过不回话、这台 Mac 也不让截屏，所以用 Chrome 跑；真机上的样子、手机上一帧多快要真机看。

用法：python3 godot/tools/splash/run_splash.py <导出目录> <输出目录> [宽x高@像素比，默认 360x640@3]
"""
import base64
import json
import os
import re
import subprocess
import sys
import tempfile

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

HTML = r"""<!doctype html><html><head><meta charset="utf-8">
<style>html,body{margin:0;background:#000}</style></head><body>
<pre id="out">running</pre>
<script>
var VW = __VW__, VH = __VH__, DPR = __DPR__, MODE = '__MODE__';
window.GameGlobal = window;
var frames = [], log = [];
var task = { cbs: [], onProgressUpdate: function (f) { this.cbs.push(f); } };
var subSuccess = null;
window.wx = {
  env: {},
  getWindowInfo: function () { return { windowWidth: VW, windowHeight: VH, pixelRatio: DPR }; },
  loadSubpackage: function (o) { subSuccess = o.success; return task; },
};
window.canvas = document.createElement('canvas');
canvas.style.width = VW + 'px'; canvas.style.height = VH + 'px';
document.body.appendChild(canvas);
window.innerWidth = VW; window.innerHeight = VH;
</script>
<script>__LOADER__</script>
<script>__SPLASH__</script>
<script>
var config = __CONFIG__;
// 图在导出目录里：换成 data 网址喂给 Image
var FILES = __FILES__;
var RealImage = window.Image;
window.Image = function () {
  var img = new RealImage();
  var real = Object.getOwnPropertyDescriptor(HTMLImageElement.prototype, 'src');
  Object.defineProperty(img, 'src', { set: function (v) { var k = String(v).replace(/^\//, ''); real.set.call(img, FILES[k] || v); }, get: function () { return real.get.call(img); } });
  return img;
};
var L = new GodotLoader(canvas, config);
GameGlobal.godotLoader = L;
// 量一帧画多久（电脑上的数，只看个量级）
var costs = [];
var rr = L.render.bind(L);
L.render = function () { var a = performance.now(); rr(); costs.push(performance.now() - a); };
function snap(name) { frames.push([name, canvas.toDataURL('image/png')]); }
function wait(ms) { return new Promise(function (r) { setTimeout(r, ms); }); }
async function run() {
  await wait(600); snap('0-开头');
  // 标题金光扫到一半那一刻（4.5 秒一次、一次 1.3 秒）
  for (var g = 0; g < 200; g++) { var ph = (Date.now() / 1000 - L.__t0) % 4.5; if (ph > 0.6 && ph < 0.75) break; await wait(25); }
  snap('0b-标题金光');
  if (MODE === 'offline') {
    await wait(2500); snap('1-没网等了3秒');
  } else {
    var steps = [12, 37, 64, 88];
    for (var i = 0; i < steps.length; i++) {
      task.cbs.forEach(function (f) { f({ progress: steps[i] }); });
      await wait(i == 1 ? 1100 : 700);
      snap((i + 1) + '-下载' + steps[i]);
    }
    task.cbs.forEach(function (f) { f({ progress: 100 }); });
    subSuccess && subSuccess();
    await wait(500); snap('5-下完');
    L.currentText = config.textConfig.compilingText;   // 引擎 startGame 里就是这么直接改字的
    await wait(700); snap('6-编译');
    L.currentText = config.textConfig.initText;
    L.cleanup();
    var n0 = costs.length;
    await wait(600);
    log.push('cleanup 以后又画了 ' + (costs.length - n0) + ' 帧');
  }
  costs.sort(function (a, b) { return a - b; });
  log.push('画了 ' + costs.length + ' 帧，一帧中位 ' + (costs[costs.length >> 1] || 0).toFixed(1) + ' 毫秒，最慢 ' + (costs[costs.length - 1] || 0).toFixed(1));
  document.getElementById('out').textContent = JSON.stringify({ frames: frames, log: log });
}
run();
</script></body></html>"""


def main():
    exp, out = sys.argv[1], sys.argv[2]
    spec = sys.argv[3] if len(sys.argv) > 3 else "360x640@3"
    m = re.match(r"(\d+)x(\d+)@(\d+(?:\.\d+)?)", spec)
    vw, vh, dpr = int(m.group(1)), int(m.group(2)), float(m.group(3))
    os.makedirs(out, exist_ok=True)
    game = open(os.path.join(exp, "game.js"), encoding="utf-8").read()
    cm = re.search(r"const config = (\{.*?\n\});\n", game, re.S)
    if not cm:
        sys.exit("game.js 里找不到 config")
    files = {}
    for rel in ["images/splash.jpg", "images/splash_petal.png", "images/splash_paper.png"]:
        b = open(os.path.join(exp, rel), "rb").read()
        mime = "image/jpeg" if rel.endswith(".jpg") else "image/png"
        files[rel] = "data:%s;base64,%s" % (mime, base64.b64encode(b).decode())
    loader = open(os.path.join(exp, "godot-loader.js"), encoding="utf-8").read()
    splash = open(os.path.join(exp, "splash.js"), encoding="utf-8").read()
    for mode in ["online", "offline"]:
        html = (HTML.replace("__VW__", str(vw)).replace("__VH__", str(vh)).replace("__DPR__", str(dpr)).replace("__MODE__", mode)
                .replace("__LOADER__", loader).replace("__SPLASH__", splash).replace("__CONFIG__", cm.group(1))
                .replace("__FILES__", json.dumps(files)))
        with tempfile.NamedTemporaryFile("w", suffix=".html", delete=False, encoding="utf-8") as f:
            f.write(html)
            path = f.name
        r = subprocess.run([CHROME, "--headless=new", "--disable-gpu-sandbox", "--use-angle=swiftshader", "--enable-unsafe-swiftshader",
                            "--virtual-time-budget=15000", "--window-size=%d,%d" % (vw, vh), "--dump-dom", "file://" + path],
                           capture_output=True, text=True, timeout=120)
        mm = re.search(r'<pre id="out">(.*?)</pre>', r.stdout, re.S)
        if not mm or mm.group(1).strip() == "running":
            print(r.stderr[-2000:])
            sys.exit("Chrome 没跑完（%s）" % mode)
        import html as H
        d = json.loads(H.unescape(mm.group(1)))
        for name, url in d["frames"]:
            p = os.path.join(out, "开屏-%s-%s.png" % (mode, name))
            open(p, "wb").write(base64.b64decode(url.split(",", 1)[1]))
            print("截了", p)
        for l in d["log"]:
            print(mode, l)
        os.unlink(path)


if __name__ == "__main__":
    main()
