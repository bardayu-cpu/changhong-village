'use strict';
/**
 * 把 src/ 的纯函数、lib/ 的 I/O 小工具同步进各云函数自己的 rules/、lib/ 文件夹。
 * 微信云函数按文件夹单独打包上传，云函数里不能 require 文件夹外的代码，
 * 所以部署前必须先跑一遍这个脚本，把用到的文件复制进去（改了 src/ 或 lib/ 也要重跑）。
 * 用法：node scripts/sync-cf-rules.js
 */
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const SRC = path.join(ROOT, 'src');
const LIB = path.join(ROOT, 'lib');
const WORDS = path.join(ROOT, 'words');
const CF = path.join(ROOT, 'cloudfunctions');

// 云函数名 -> 需要哪些 src/ 纯函数文件（同步进各自的 rules/ 文件夹；只列这个函数真正 require 到的）
// sensitive.js（敏感词/保留名校验，docs/敏感词模块-需求.md）：saveProfile 查 nick，writeBook 查 text
const NEEDS = {
  enterHall: ['config.js', 'banquet.js'],
  // changeSeat 9/18 起不再需要 time.js：canChangeSeat 去掉了「今天换过几次」的判定
  changeSeat: ['config.js', 'banquet.js'],
  toast: ['config.js', 'time.js', 'banquet.js'],
  // wantToMeet（想认识你，9/19）：canWantToMeet 要 config.js 的长凳 id
  wantToMeet: ['config.js', 'banquet.js'],
  // canvasFile（画布图远程加载，9/19）：只许读 canvas/ 下面的文件、一块多大
  canvasFile: ['config.js', 'canvas.js'],
  writeBook: ['config.js', 'banquet.js', 'sensitive.js'],
  readBook: ['config.js'],
  saveProfile: ['config.js', 'resident.js', 'sensitive.js'],
  // readBlessings（迎宾院祝福牌，10/2）：一次带回几条
  readBlessings: ['config.js'],
  // posterCode（合影海报的小程序码，10/2）：码打开哪个版本、多宽
  posterCode: ['config.js'],
};

// 云函数名 -> 需要哪些 lib/ 的 I/O 小工具（同步进各自的 lib/ 文件夹）。
// 分页读全（回执 03 第 1 项）：enterHall、readBook 的查询可能超过 100 条，要用 lib/db-page.js。
const LIB_NEEDS = {
  enterHall: ['db-page.js'],
  readBook: ['db-page.js'],
};

for (const [fn, files] of Object.entries(NEEDS)) {
  const dest = path.join(CF, fn, 'rules');
  fs.mkdirSync(dest, { recursive: true });
  for (const f of files) {
    fs.copyFileSync(path.join(SRC, f), path.join(dest, f));
  }
  console.log(`${fn}: 同步了 rules/${files.join('、rules/')}`);
}

for (const [fn, files] of Object.entries(LIB_NEEDS)) {
  const dest = path.join(CF, fn, 'lib');
  fs.mkdirSync(dest, { recursive: true });
  for (const f of files) {
    fs.copyFileSync(path.join(LIB, f), path.join(dest, f));
  }
  console.log(`${fn}: 同步了 lib/${files.join('、lib/')}`);
}

// 云函数名 -> 需要哪些词库文件（同步进各自的 words/ 文件夹；build-words.js 生成 base.txt 之后要重跑这里）。
// saveProfile 的 nick 要查敏感词 + 保留名，writeBook 的 text 只查敏感词（悄悄话不过滤，没有云函数需要它）。
// MIT 许可证原文跟着词库一起拷过去（阿鱼 9/18 同意下载时的要求，见 words/source/.../SOURCE.md）。
const WORDS_NEEDS = {
  saveProfile: ['base.txt', 'reserved.txt'],
  writeBook: ['base.txt'],
};
const LICENSE_SRC = path.join(WORDS, 'source', 'konsheng-Sensitive-lexicon', 'LICENSE');

for (const [fn, files] of Object.entries(WORDS_NEEDS)) {
  const dest = path.join(CF, fn, 'words');
  fs.mkdirSync(dest, { recursive: true });
  for (const f of files) {
    fs.copyFileSync(path.join(WORDS, f), path.join(dest, f));
  }
  fs.copyFileSync(LICENSE_SRC, path.join(dest, 'LICENSE'));
  console.log(`${fn}: 同步了 words/${files.join('、words/')}、words/LICENSE`);
}
