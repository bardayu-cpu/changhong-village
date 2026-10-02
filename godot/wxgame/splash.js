// 开屏加载页动起来（01 E 10/3；阿鱼：「最好是带动画和 loading 条的」「为什么不直接做一个动画呢？拆起来太麻烦了」）。
// GPT 只画一张完整的开屏图（wxgame/splash/splash.jpg，tools/splash/make_splash.py 转），这里让整张图动起来：
//   慢慢推近又退回（几秒一循环）、灯笼和桥灯一闪一闪、标题一道金光从左扫到右、飘花瓣彩纸（宴会厅现成的两张 FX 小图），
//   最下面五分之一一条红绸底金色填充的进度条，照真实下载进度走，字是我们的口吻（game.js 的 textConfig，导出时换）。
// 怎么接：模板的 godot-loader.js 定义 GodotLoader（引擎起来之前那一页），game.js 最后 new 它。这份排在 godot-loader 后面导入，
// 把它的 render 换成我们画的，再挂一个约 30 帧的循环；引擎接管画布时它调 cleanup()，循环当场停，一帧都不再碰画布。
// 不拖慢打开：画在一块最多 2 倍像素比的离屏画布上；一帧画得慢（>45 毫秒）就降到 15 帧，连着很慢就停在静图。出错就退回模板原来的画法。
// 图和花瓣都在主包里，没网也看得见；进度条照下载回调走，没回调就停在开头那句话。
// 只用老写法：开发者工具的编译器碰到新写法可能会崩。

(function () {
    var G = typeof GameGlobal !== 'undefined' ? GameGlobal : this;
    var Loader = G.GodotLoader;
    if (!Loader || Loader.prototype.__suqiSplash) return;

    // ---- 换图只改这里：位置都是相对整张图（0～1） ----
    var SPLASH = {
        // 宴会厅现成的两张 FX（hall_festive.gd）：一行一种颜色，一行 4 帧翻面；cell 是一格多大
        petals: [{ src: 'images/splash_petal.png', cell: 12, rows: 4 }, { src: 'images/splash_paper.png', cell: 10, rows: 6 }],
        petalScale: [1.8, 2.6],   // 一格画几倍（CSS 像素）：宴会厅里一片约 11 像素，开屏放大一点
        petalCount: 14,
        // 一闪一闪的灯：x、y 是灯芯，r 是光晕半径（相对图宽）。假图（宴会厅北边）是舞台两边那两盏大灯笼
        lights: [{ x: 0.317, y: 0.066, r: 0.07 }, { x: 0.678, y: 0.066, r: 0.07 }],
        // 标题那一块：金光从左扫到右。假图是 make_splash.py 写上去的占位标题
        title: { x: 0.14, y: 0.36, w: 0.72, h: 0.095 },
        sweepEvery: 4.5,      // 隔几秒扫一次
        sweepTime: 1.3,       // 一次扫多久
        zoom: 0.06,           // 推近多少（1 → 1.06）
        zoomCycle: 12,        // 推近又退回一圈几秒
        focus: { x: 0.5, y: 0.4 },   // 推近对着哪一点
        bar: { y: 0.885, w: 0.72, h: 18 },   // 进度条中心在图高的几成；宽占屏宽几成；高（CSS 像素）
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
        self.__petalImgs = [];
        SPLASH.petals.forEach(function (pt) {
            var img = new Image();
            img.onload = function () { self.__petalImgs.push({ img: img, cell: pt.cell, rows: pt.rows }); };
            img.src = pt.src;
        });
        self.__t0 = now();
        self.__petals = [];
        self.__fps = SPLASH.fps;
        self.__slow = 0;
        self.__last = 0;
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

    P.cleanup = function () {
        this.__dead = true;   // 引擎接管画布：循环停，一帧都不再画
        origCleanup.call(this);
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

    function draw(L) {
        var cv = L.offScreenCanvas;
        var ctx = cv.getContext('2d');
        var W = cv.width, H = cv.height;
        var k = L.__k || 1;                 // 1 个 CSS 像素是离屏画布的几个像素
        var t = L.__still ? 0 : now() - (L.__t0 || now());
        ctx.globalCompositeOperation = 'source-over';
        ctx.globalAlpha = 1;
        ctx.fillStyle = '#3a0f12';           // 图还没出来时的底色（深红）
        ctx.fillRect(0, 0, W, H);

        // 图：铺满屏（cover），对着 focus 慢慢推近又退回
        var img = L.backgroundImage;
        var map = null;   // 图上 (u, v) → 屏上 (x, y)
        if (img && img.width) {
            var z = 1 + SPLASH.zoom * (0.5 - 0.5 * Math.cos(2 * Math.PI * t / SPLASH.zoomCycle));
            var s = Math.max(W / img.width, H / img.height) * z;
            var dw = img.width * s, dh = img.height * s;
            var fx = SPLASH.focus.x, fy = SPLASH.focus.y;
            var base = Math.max(W / img.width, H / img.height);
            var x0 = (W - img.width * base) / 2 + img.width * base * fx - dw * fx;
            var y0 = (H - img.height * base) / 2 + img.height * base * fy - dh * fy;
            ctx.imageSmoothingEnabled = true;
            ctx.drawImage(img, x0, y0, dw, dh);
            map = function (u, v) { return [x0 + u * dw, y0 + v * dh, dw]; };
        }

        if (map) {
            // 灯一闪一闪：暖色光晕叠上去，各盏错开，再加一点抖
            ctx.globalCompositeOperation = 'lighter';
            SPLASH.lights.forEach(function (l, i) {
                var p = map(l.x, l.y);
                var r = l.r * p[2];
                var a = 0.22 + 0.16 * Math.sin(t * 2.6 + i * 1.9) + 0.06 * Math.sin(t * 11.3 + i * 3.1);
                var g = ctx.createRadialGradient(p[0], p[1], 0, p[0], p[1], r);
                g.addColorStop(0, 'rgba(255,200,110,' + a.toFixed(3) + ')');
                g.addColorStop(1, 'rgba(255,140,40,0)');
                ctx.fillStyle = g;
                ctx.fillRect(p[0] - r, p[1] - r, 2 * r, 2 * r);
            });
            // 标题金光：一条斜的亮带从左扫到右，只在标题那一块里
            var ph = t % SPLASH.sweepEvery;
            if (ph < SPLASH.sweepTime) {
                var a0 = map(SPLASH.title.x, SPLASH.title.y);
                var a1 = map(SPLASH.title.x + SPLASH.title.w, SPLASH.title.y + SPLASH.title.h);
                var tw = a1[0] - a0[0], th = a1[1] - a0[1];
                var band = tw * 0.22;
                var bx = a0[0] - band + (tw + 2 * band) * (ph / SPLASH.sweepTime);
                ctx.save();
                ctx.beginPath();
                ctx.rect(a0[0], a0[1], tw, th);
                ctx.clip();
                // 一道斜的、边上虚的亮光（不是一整块亮方块）：在亮光中心转一下、压扁，画一个径向渐变
                var cy = a0[1] + th / 2;
                ctx.translate(bx, cy);
                ctx.rotate(-0.35);
                ctx.scale(0.28, 1);   // 压成窄窄一道
                var rg = ctx.createRadialGradient(0, 0, 0, 0, 0, th * 0.5);   // 半径小于标题那块的半高：上下自己淡掉，不被框切出硬边
                rg.addColorStop(0, 'rgba(255,246,200,0.9)');
                rg.addColorStop(0.55, 'rgba(255,226,150,0.45)');
                rg.addColorStop(1, 'rgba(255,210,120,0)');
                ctx.fillStyle = rg;
                ctx.fillRect(-th, -th, 2 * th, 2 * th);
                ctx.restore();
            }
            ctx.globalCompositeOperation = 'source-over';
        }

        petals(L, ctx, W, H, k, t);
        bar(L, ctx, W, H, k);
    }

    // 花瓣彩纸从上往下飘、左右晃，一格一格翻面（跟宴会厅一样的画法）；飘出去从上面再来。停在静图时不画
    function petals(L, ctx, W, H, k, t) {
        var kinds = L.__petalImgs || [];
        if (!kinds.length || L.__still) return;
        var ps = L.__petals;
        var dt = Math.min(0.1, t - (L.__pt || t));
        L.__pt = t;
        while (ps.length < SPLASH.petalCount) {
            var kd = kinds[ps.length % kinds.length];
            ps.push({ x: Math.random() * W, y: Math.random() * H, vy: (35 + Math.random() * 45) * k,
                sway: (8 + Math.random() * 16) * k, ph: Math.random() * 6.28, kind: kd, row: Math.floor(Math.random() * kd.rows),
                s: (SPLASH.petalScale[0] + Math.random() * (SPLASH.petalScale[1] - SPLASH.petalScale[0])) * k });
        }
        ctx.imageSmoothingEnabled = false;
        ps.forEach(function (p) {
            p.y += p.vy * dt;
            if (p.y > H + 30 * k) { p.y = -30 * k; p.x = Math.random() * W; }
            var x = p.x + Math.sin(t * 1.3 + p.ph) * p.sway;
            var c = p.kind.cell, fr = Math.floor(t / 0.12 + p.ph) % 4, w = c * p.s;
            ctx.drawImage(p.kind.img, fr * c, p.row * c, c, c, Math.round(x - w / 2), Math.round(p.y - w / 2), w, w);
        });
        ctx.imageSmoothingEnabled = true;
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

    // 进度条：红绸底、金边，金色填充，填充上有一道亮光走；字在条子上面（下载时带百分数）
    function bar(L, ctx, W, H, k) {
        var bw = W * SPLASH.bar.w, bh = SPLASH.bar.h * k;
        var bx = (W - bw) / 2, by = H * SPLASH.bar.y - bh / 2;
        var silk = ctx.createLinearGradient(0, by, 0, by + bh);
        silk.addColorStop(0, '#9e1b1b');
        silk.addColorStop(0.5, '#7a1212');
        silk.addColorStop(1, '#5c0c0c');
        ctx.fillStyle = silk;
        rr(ctx, bx, by, bw, bh, bh / 2);
        ctx.fill();
        ctx.lineWidth = 1.5 * k;
        ctx.strokeStyle = '#e8c15a';
        ctx.stroke();
        var p = Math.max(0, Math.min(1, L.progress || 0));
        if (p > 0) {
            var pad = 3 * k;
            var fw = Math.max(bh - 2 * pad, (bw - 2 * pad) * p);
            var gold = ctx.createLinearGradient(0, by + pad, 0, by + bh - pad);
            gold.addColorStop(0, '#fff0a8');
            gold.addColorStop(0.45, '#f2c94c');
            gold.addColorStop(1, '#c8932a');
            ctx.fillStyle = gold;
            rr(ctx, bx + pad, by + pad, fw, bh - 2 * pad, (bh - 2 * pad) / 2);
            ctx.fill();
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
