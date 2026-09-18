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
const CF = path.join(ROOT, 'cloudfunctions');

// 云函数名 -> 需要哪些 src/ 纯函数文件（同步进各自的 rules/ 文件夹；只列这个函数真正 require 到的）
const NEEDS = {
  enterHall: ['config.js', 'banquet.js'],
  // changeSeat 9/18 起不再需要 time.js：canChangeSeat 去掉了「今天换过几次」的判定
  changeSeat: ['config.js', 'banquet.js'],
  toast: ['config.js', 'time.js', 'banquet.js'],
  writeBook: ['config.js', 'banquet.js'],
  readBook: ['config.js'],
  saveProfile: ['config.js', 'resident.js'],
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
