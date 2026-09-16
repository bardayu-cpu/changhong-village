'use strict';
/**
 * 把 src/ 的纯函数同步进各云函数自己的 rules/ 文件夹。
 * 微信云函数按文件夹单独打包上传，云函数里不能 require 文件夹外的代码，
 * 所以部署前必须先跑一遍这个脚本，把用到的规则文件复制进去（改了 src/ 也要重跑）。
 * 用法：node scripts/sync-cf-rules.js
 */
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const SRC = path.join(ROOT, 'src');
const CF = path.join(ROOT, 'cloudfunctions');

// 云函数名 -> 需要哪些 src 文件（只列这个函数真正 require 到的，别的不拷）
const NEEDS = {
  enterHall: ['config.js', 'banquet.js'],
  changeSeat: ['config.js', 'time.js', 'banquet.js'],
  toast: ['config.js', 'time.js', 'banquet.js'],
  writeBook: ['config.js', 'banquet.js'],
};

for (const [fn, files] of Object.entries(NEEDS)) {
  const dest = path.join(CF, fn, 'rules');
  fs.mkdirSync(dest, { recursive: true });
  for (const f of files) {
    fs.copyFileSync(path.join(SRC, f), path.join(dest, f));
  }
  console.log(`${fn}: 同步了 ${files.join('、')}`);
}
