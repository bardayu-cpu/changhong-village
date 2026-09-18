'use strict';
/**
 * 误伤测试（docs/敏感词模块-需求.md 第 9 节验收标准 + HANDOFF 要求）：
 *   - 100 个常见昵称（中文名、网名、英文名、带数字的）全部必须放行
 *   - 30 句常见婚礼祝福全部必须放行
 *   - 20 个明显该拦的词（从 words/base.txt 实际内容里挑，覆盖 13 个源分类）必须拦住
 *
 * 跑出误伤（正常文本被拦）就去改 scripts/build-words.js 的 FALSE_POSITIVE_EXCLUDE 列表，
 * 写明删的是哪条、命中了什么样的正常文本、为什么删，然后重新跑 node scripts/build-words.js。
 * 用法：node test/words-false-positive.test.js
 */
const fs = require('fs');
const path = require('path');
const sensitive = require('../src/sensitive');

const WORDS_DIR = path.join(__dirname, '..', 'words');

function readLines(file) {
  if (!fs.existsSync(file)) return [];
  return fs.readFileSync(file, 'utf8').split(/\r?\n/).map(s => s.trim()).filter(Boolean);
}

const baseWords = readLines(path.join(WORDS_DIR, 'base.txt'));
const reservedWords = readLines(path.join(WORDS_DIR, 'reserved.txt'));
const matcher = sensitive.buildMatcher(baseWords);
const reservedSet = new Set(reservedWords.map(sensitive.normalize));

let pass = 0, fail = 0;
const failures = [];
function expectPass(text, label) {
  const r = sensitive.checkText(text, { sensitiveMatcher: matcher, reservedSet });
  if (r.ok) pass++;
  else { fail++; failures.push(`${label} "${text}" 应该放行，实际被拦：${r.reason}`); }
}
function expectBlock(text, label) {
  const r = sensitive.checkText(text, { sensitiveMatcher: matcher, reservedSet });
  if (!r.ok && r.reason === 'sensitive') pass++;
  else { fail++; failures.push(`${label} "${text}" 应该被拦（sensitive），实际 ${JSON.stringify(r)}`); }
}

// ---------- 100 个常见昵称：中文名 25 + 网名 25 + 英文名 25 + 带数字/符号 25 ----------
const NICK_CN_NAME = [
  '王芳', '李娜', '张伟', '刘洋', '陈静', '杨帆', '赵敏', '黄磊', '周杰', '吴磊',
  '徐静', '孙悦', '马超', '朱丽', '胡歌', '郭涛', '何炅', '高远', '林峰', '郑爽',
  '谢娜', '蔡徐坤', '邓超', '韩梅梅', '李雷',
];
const NICK_WANGMING = [
  '小可爱', '阿花', '大头', '老王', '小骚包', '月光族', '柠檬精', '一只猫', '快乐星球', '追风少年',
  '岁月静好', '人间不值得', '元气满满', '佛系青年', '咸鱼一条', '摸鱼选手', '熬夜冠军', '社恐患者', '快乐肥宅', '奶茶不加糖',
  '打工人', '干饭人', '拖延症晚期', '追剧小能手', '云吸猫',
];
const NICK_EN_NAME = [
  'Tom', 'Jerry', 'Amy', 'Lucy', 'Kevin', 'Sunny', 'Coco', 'Lily', 'Jack', 'Anna',
  'Emma', 'David', 'Grace', 'Leo', 'Nina', 'Sam', 'Ivy', 'Max', 'Ella', 'Ryan',
  'Mia', 'Alex', 'Zoe', 'Ben', 'Kate',
];
const NICK_WITH_DIGIT = [
  '小明123', '张三_007', '阿花99', 'cat2020', '233酱', '88号选手', 'QQ糖不甜', 'No1开心果', '幸运7', '快乐ing',
  '大白菜v5', '阿呆_2024', '汪汪队长', '007号特工', '甜甜圈no3', '小仙女丫', '阿May', 'Coco_Chan', '二狗子', '三胖',
  '四喜丸子', '五月天粉', '六六大顺', '七宝', '八戒',
];
const NICKNAMES = [...NICK_CN_NAME, ...NICK_WANGMING, ...NICK_EN_NAME, ...NICK_WITH_DIGIT];

// ---------- 30 句常见婚礼祝福 ----------
const WISHES = [
  '新婚快乐', '百年好合', '早生贵子', '白头偕老', '永结同心',
  '天作之合', '举案齐眉', '花好月圆', '相濡以沫', '心心相印',
  '佳偶天成', '鸾凤和鸣', '琴瑟和鸣', '甜甜蜜蜜', '恩爱一生',
  '幸福美满', '白头到老', '永浴爱河', '情投意合', '喜结连理',
  '珠联璧合', '五世其昌', '早日添丁', '儿孙满堂', '执子之手 与子偕老',
  '愿你们相爱到老', '祝你们幸福美满', '新婚愉快 永结同心', '祝新人白头偕老', '婚姻美满 家庭幸福',
];

// ---------- 20 个明显该拦的词：从 words/base.txt 实际内容里挑，覆盖全部 13 个源分类 ----------
const SHOULD_BLOCK = [
  ['借腹生子', '广告类型'], ['代开发票', '广告类型'],
  ['情色', '色情类型'], ['包二奶', '色情类型'],
  ['娘西皮', '色情词库'],
  ['布卖淫女', '补充词库'], ['学骚乱', '补充词库'],
  ['人类灭亡进程表', '暴恐词库'], ['氧化亚铊', '暴恐词库'],
  ['燃烧弹的制作方法', '涉枪涉爆'], ['各类军用枪支', '涉枪涉爆'],
  ['受贿罪', '贪腐词库'],
  ['习明泽', '政治类型'], ['姚依林', '政治类型'],
  ['打倒中国', '反动词库'], ['颜色革命', '反动词库'],
  ['梭哈买房', '新思想启蒙'],
  ['拆迁', '民生词库'],
  ['武汉不明肺炎', 'COVID-19词库'],
  ['triangleboy', '其他词库'],
];

for (const n of NICKNAMES) expectPass(n, '昵称');
for (const w of WISHES) expectPass(w, '祝福语');
for (const [w, cat] of SHOULD_BLOCK) expectBlock(w, cat);

// ---------- 性能：需求文档第 4 节要求单次校验 < 10ms ----------
const PERF_TEXT = '恭喜恭喜恭喜恭喜恭喜恭喜恭喜恭喜恭喜恭喜 新婚快乐百年好合早生贵子 abcdefghijklmnopqrstuvwxyz0123456789 祝你们幸福美满白头偕老永结同心'.slice(0, 100);
const PERF_N = 2000;
const t0 = process.hrtime.bigint();
for (let i = 0; i < PERF_N; i++) sensitive.checkText(PERF_TEXT, { sensitiveMatcher: matcher, reservedSet });
const t1 = process.hrtime.bigint();
const avgMs = Number(t1 - t0) / 1e6 / PERF_N;
console.log(`性能：100 字文本连跑 ${PERF_N} 次，单次平均 ${avgMs.toFixed(4)} ms（要求 < 10ms）`);
if (avgMs < 10) pass++; else { fail++; failures.push(`性能 单次平均 ${avgMs.toFixed(4)} ms，超过 10ms 要求`); }

console.log(`词库 base.txt ${baseWords.length} 条，reserved.txt ${reservedWords.length} 条`);
console.log(`昵称 ${NICKNAMES.length} 个、祝福语 ${WISHES.length} 句、应拦词 ${SHOULD_BLOCK.length} 个`);
console.log(`通过 ${pass}，失败 ${fail}`);
if (fail) {
  console.log('\n失败项：');
  failures.forEach(f => console.log('  ✗ ' + f));
  process.exit(1);
} else {
  console.log('全部通过（100 昵称 + 30 祝福语放行，20 个应拦词全部拦住）');
}
