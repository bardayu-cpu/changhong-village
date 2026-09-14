// 苏七镇 · 占位入口：只用来确认 AppID、开发者工具、手机这条链路是通的
const canvas = wx.createCanvas();
const ctx = canvas.getContext('2d');
const info = wx.getWindowInfo ? wx.getWindowInfo() : wx.getSystemInfoSync();
const w = info.windowWidth, h = info.windowHeight, r = info.pixelRatio || 2;
canvas.width = w * r; canvas.height = h * r; ctx.scale(r, r);
ctx.fillStyle = '#15111b'; ctx.fillRect(0, 0, w, h);
ctx.textAlign = 'center';
ctx.fillStyle = '#f4d97a'; ctx.font = 'bold 40px sans-serif'; ctx.fillText('苏七镇', w / 2, h * 0.42);
ctx.fillStyle = '#b1a6ba'; ctx.font = '15px sans-serif'; ctx.fillText('工程已接通', w / 2, h * 0.42 + 40);
