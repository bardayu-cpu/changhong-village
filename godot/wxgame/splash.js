// 开屏第 1 层：引擎起来之前的加载页（01 E 10/3 起头；10/3 换成阿鱼交的开屏素材）。
// 只画两样：背景（assets/splash/splash_bg.jpg，导出时拷成 images/splash.jpg）慢慢推近又退回，下面一条红绸底金色进度条。
// logo、气泡、按钮都在第 2 层（Godot 的 scripts/title_screen.gd）。阿鱼 10/3：「第 1 层只显示背景和进度条，logo 落下放在第 2 层」。
// 两层要接得上（阿鱼 10/3：「位置、缩放完全一致，切换时不能跳」）：
//   - 背景铺法跟第 2 层一样：整张图等比铺满屏（cover），居中
//   - 推近只在下载时：引擎分包下完 1.2 秒退回原大，后面编译、引擎起来（手机上几秒）都是原大；第 2 层从原大开始，不再推近。
//     接手那一刻推到几倍记在 GameGlobal.__suqiSplash.zoom()，第 2 层打进日志，真机上看
//   - 进度条下完以后是满的、不带亮光，第 2 层照同样的位置、大小、颜色画一条满的接着（title_screen.gd 的 BAR），屏宽从 cssW() 读
//   - 引擎接手时不清屏：模板的 cleanup 会把画布清成透明（黑一下），这里留着最后一帧，等 Godot 画第一帧盖上。
//     Godot 网页版引擎自己不画启动画面（Godot 源码 main.cpp setup_boot_logo：网页导出不显示），中间没有别的画面插进来
// 怎么接：模板的 godot-loader.js 定义 GodotLoader，game.js 最后 new 它。这份排在 godot-loader 后面导入，把它的 render 换成我们画的，
// 再挂一个约 30 帧的循环；引擎接管画布时它调 cleanup()，循环当场停。
// 不拖慢打开：画在一块最多 2 倍像素比的离屏画布上；一帧画得慢（>45 毫秒）就降到 15 帧，连着很慢就停在静图。出错就退回模板原来的画法。
// 图在主包里，没网也看得见；进度条照下载回调走，没回调就停在开头那句话。
// 只用老写法：开发者工具的编译器碰到新写法可能会崩。

(function () {
    var G = typeof GameGlobal !== 'undefined' ? GameGlobal : this;
    var Loader = G.GodotLoader;
    if (!Loader || Loader.prototype.__suqiSplash) return;

    // ---- 跟 title_screen.gd 对齐的数，改一边要改另一边 ----
    var SPLASH = {
        zoom: 0.06,           // 推近多少（1 → 1.06）
        zoomCycle: 12,        // 推近又退回一圈几秒
        zoomBack: 1.2,        // 分包下完以后几秒退回原大
        focus: { x: 0.5, y: 0.4 },   // 推近对着哪一点（相对整张图）
        bar: { y: 0.885, w: 0.72, h: 18 },   // 进度条中心在屏高的几成；宽占屏宽几成；高（CSS 像素）
        fps: 30,
    };

    var P = Loader.prototype;
    P.__suqiSplash = true;
    var origRender = P.render;
    var origResize = P.resizeCanvases;
    var origCleanup = P.cleanup;
    var origLoadImages = P.loadImages;

    function now() { return Date.now() / 1000; }
    // 用定时器不用 requestAnimationFrame：引擎直接改 currentText（编译、初始化）时也接着画；帧数自己管
    function later(fn, fps) { setTimeout(fn, Math.round(1000 / fps)); }

    P.loadImages = function () {
        origLoadImages.call(this);
        var self = this;
        self.__t0 = now();
        self.__z = 1;
        self.__fps = SPLASH.fps;
        self.__slow = 0;
        // 给第 2 层读：接手那一刻推近到几倍、屏宽多少 CSS 像素、条子上写的什么
        G.__suqiSplash = {
            zoom: function () { return self.__z || 1; },
            cssW: function () { return self.getViewportSize().width; },
            text: function () { return self.currentText || ''; },
        };
        var tick = function () {
            if (self.__dead) return;
            var a = Date.now();
            self.render();
            var cost = Date.now() - a;
            if (cost > 45) {
                self.__slow += 1;
                self.__fps = 15;
                if (self.__slow > 20 && !self.__still) { self.__still = true; console.log('[suqi] 开屏 画得太慢，停在静图'); }
            } else if (self.__slow > 0) {
                self.__slow -= 1;
            }
            // 停在静图：不动了，但字、进度还是每秒更新两次
            later(tick, self.__still ? 2 : self.__fps);
        };
        later(tick, self.__fps);
    };

    // 离屏画布最多 2 倍像素比：3 倍屏的手机每帧少传一半多的像素到显卡，看着差不多
    P.resizeCanvases = function () {
        origResize.call(this);
        var vp = this.getViewportSize();
        this.__k = Math.min(this.dpr, 2);
        this.offScreenCanvas.width = Math.round(vp.width * this.__k);
        this.offScreenCanvas.height = Math.round(vp.height * this.__k);
        this.render();
    };

    // 引擎接手：循环停；模板的收尾照做，只是不清屏（清了会透明黑一下），最后一帧留在屏上等 Godot 盖
    P.cleanup = function () {
        this.__dead = true;
        var gl = this.gl;
        var clear = gl && gl.clear;
        if (gl) gl.clear = function () {};
        try {
            origCleanup.call(this);
        } finally {
            if (gl) gl.clear = clear;
        }
    };

    P.render = function () {
        if (this.__dead) return;
        if (this.__fail || !this.gl) { origRender.call(this); return; }
        try {
            draw(this);
            this.renderToWebGL();
        } catch (e) {
            this.__fail = true;
            console.error('[suqi] 开屏 画不了，退回模板的画法 ' + (e && e.message));
            origRender.call(this);
        }
    };

    // 现在推近到几倍：平时 12 秒一圈来回；分包下完（progress 到 1）那一刻起 1.2 秒缓缓退回 1，之后一直是 1
    function zoomNow(L, t) {
        var cyc = function (tt) { return 1 + SPLASH.zoom * (0.5 - 0.5 * Math.cos(2 * Math.PI * tt / SPLASH.zoomCycle)); };
        if (L.__still) return 1;
        if ((L.progress || 0) >= 1 && L.__tBack === undefined) {
            L.__tBack = t;
            L.__zBack = cyc(t);
        }
        if (L.__tBack === undefined) return cyc(t);
        var f = Math.min(1, (t - L.__tBack) / SPLASH.zoomBack);
        f = 1 - (1 - f) * (1 - f);   // 先快后慢
        return 1 + (L.__zBack - 1) * (1 - f);
    }

    function draw(L) {
        var cv = L.offScreenCanvas;
        var ctx = cv.getContext('2d');
        var W = cv.width, H = cv.height;
        var k = L.__k || 1;                 // 1 个 CSS 像素是离屏画布的几个像素
        var t = now() - (L.__t0 || now());
        ctx.globalCompositeOperation = 'source-over';
        ctx.globalAlpha = 1;
        ctx.fillStyle = '#110c22';           // 图还没出来时的底色（夜色，跟图上的天一个色）
        ctx.fillRect(0, 0, W, H);

        // 图：铺满屏（cover），对着 focus 推近
        var img = L.backgroundImage;
        if (img && img.width) {
            var z = zoomNow(L, t);
            L.__z = z;
            var base = Math.max(W / img.width, H / img.height);
            var dw = img.width * base * z, dh = img.height * base * z;
            var fx = SPLASH.focus.x, fy = SPLASH.focus.y;
            var x0 = (W - img.width * base) / 2 + img.width * base * fx - dw * fx;
            var y0 = (H - img.height * base) / 2 + img.height * base * fy - dh * fy;
            ctx.imageSmoothingEnabled = true;
            ctx.drawImage(img, x0, y0, dw, dh);
        }
        bar(L, ctx, W, H, k);
    }

    function rr(ctx, x, y, w, h, r) {
        r = Math.min(r, h / 2, w / 2);
        ctx.beginPath();
        ctx.moveTo(x + r, y);
        ctx.arcTo(x + w, y, x + w, y + h, r);
        ctx.arcTo(x + w, y + h, x, y + h, r);
        ctx.arcTo(x, y + h, x, y, r);
        ctx.arcTo(x, y, x + w, y, r);
        ctx.closePath();
    }

    // 进度条：红绸底、金边，金色填充（平涂，第 2 层照画得出一样的）；下载时填充上有一道亮光走，下完就不走了；
    // 字在条子上面（下载时带百分数）
    function bar(L, ctx, W, H, k) {
        var bw = W * SPLASH.bar.w, bh = SPLASH.bar.h * k;
        var bx = (W - bw) / 2, by = H * SPLASH.bar.y - bh / 2;
        ctx.fillStyle = '#7a1212';
        rr(ctx, bx, by, bw, bh, bh / 2);
        ctx.fill();
        ctx.lineWidth = 1.5 * k;
        ctx.strokeStyle = '#e8c15a';
        ctx.stroke();
        var p = Math.max(0, Math.min(1, L.progress || 0));
        if (p > 0) {
            var pad = 3 * k;
            var fw = Math.max(bh - 2 * pad, (bw - 2 * pad) * p);
            ctx.fillStyle = '#f2c94c';
            rr(ctx, bx + pad, by + pad, fw, bh - 2 * pad, (bh - 2 * pad) / 2);
            ctx.fill();
        }
        if (p > 0 && p < 1) {
            var sx = bx + pad + ((now() * 0.6) % 1) * fw;   // 一道亮光在填好的那段里走
            ctx.save();
            rr(ctx, bx + pad, by + pad, fw, bh - 2 * pad, (bh - 2 * pad) / 2);
            ctx.clip();
            var sh = ctx.createLinearGradient(sx - 30 * k, 0, sx + 30 * k, 0);
            sh.addColorStop(0, 'rgba(255,255,255,0)');
            sh.addColorStop(0.5, 'rgba(255,255,255,0.55)');
            sh.addColorStop(1, 'rgba(255,255,255,0)');
            ctx.fillStyle = sh;
            ctx.fillRect(bx, by, bw, bh);
            ctx.restore();
        }
        var text = L.currentText || '';
        var dl = L.config.textConfig.downloadingText || [];
        if (p > 0 && p < 1 && dl.indexOf(text) >= 0) text += '  ' + Math.round(p * 100) + '%';
        ctx.font = Math.round(15 * k) + 'px sans-serif';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'bottom';
        ctx.lineWidth = 3 * k;
        ctx.strokeStyle = 'rgba(60,10,10,0.85)';
        ctx.strokeText(text, W / 2, by - 8 * k);
        ctx.fillStyle = '#fbefd0';
        ctx.fillText(text, W / 2, by - 8 * k);
    }
})();
