'use strict';
/**
 * 从 words/source/konsheng-Sensitive-lexicon 的 13 个开源分类文件构建 words/base.txt（一行一词）。
 * 用法：node scripts/build-words.js
 *
 * 处理规则（阿鱼 9/18 同意下载开源词库时定的，见 words/source/konsheng-Sensitive-lexicon/SOURCE.md）：
 *   1. 去空行、首尾空白
 *   2. 用 src/sensitive.js 的 normalize() 做一次归一化（全角转半角、大小写不敏感等），
 *      跟运行时校验用的是同一份归一化实现，词库里存的形式和查询时生成的文本 A 对得上
 *   3. 去重
 *   4. 删掉只有一个字的词条（免得误伤姓名——"伟""芳"这类单字很容易出现在真实名字里）
 *   5. 减去 FALSE_POSITIVE_EXCLUDE 列表：这些词条在 100 个常见昵称 / 30 句祝福语的误伤测试
 *      （test/words-false-positive.test.js）里命中了正常文本，逐条列在下面并写明原因，
 *      回执 05 也会摘一份。以后词库来源文件更新、重新跑这个脚本，还会自动排除这些词
 *
 * 生成的 words/base.txt 进 git 仓库（README 要求：词库更新不需要改代码，改 txt 重新构建即可）。
 */
const fs = require('fs');
const path = require('path');
const sensitive = require('../src/sensitive');

const ROOT = path.join(__dirname, '..');
const SOURCE_DIR = path.join(ROOT, 'words', 'source', 'konsheng-Sensitive-lexicon');
const OUT_FILE = path.join(ROOT, 'words', 'base.txt');

// ---- 误伤词条排除清单：跑 test/words-false-positive.test.js 测出来的，每条写明命中了什么、为什么删 ----
// （回执 05-敏感词.md 会摘一份同样的清单）。
const FALSE_POSITIVE_EXCLUDE = [
  ['ly', '广告类型.txt 的裸双字母缩写，包含匹配下会命中任何带"ly"的文本；误伤测试：英文名 "Lily"'],
  ['ma', '其他词库.txt 的裸双字母缩写，包含匹配下会命中任何带"ma"的文本；误伤测试：英文名 "Emma""Max"、"阿May"'],
  ['av', '其他词库.txt 的裸双字母缩写（原意疑似指 AV 女优），包含匹配下会命中任何带"av"的文本；误伤测试：英文名 "David"'],
  ['qq', '广告类型.txt 的裸双字母缩写（腾讯 QQ 号，广告加好友话术用），包含匹配下会命中任何带"qq"的文本；' +
    '误伤测试："QQ糖不甜"。涉枪涉爆.txt 里"出售气枪 QQ"这类带联系方式的完整广告短语是单独词条，不受影响，只删的是裸的双字母"QQ"'],
  ['五月天', '补充词库.txt 词条，但"五月天"是知名乐队名，日常引用概率高；误伤测试："五月天粉"'],
];

function readLines(file) {
  return fs.readFileSync(file, 'utf8').split(/\r?\n/);
}

function main() {
  const files = fs.readdirSync(SOURCE_DIR).filter(f => f.endsWith('.txt')).sort();
  if (files.length === 0) throw new Error('build-words: 词库源目录下没有 .txt 文件，先确认路径');

  const perFile = [];
  const seen = new Set(); // 归一化后的词 -> 已收录
  let totalRaw = 0;
  let emptyAfterNormalize = 0;
  let singleCharRemoved = 0;
  let dupRemoved = 0;

  for (const f of files) {
    const lines = readLines(path.join(SOURCE_DIR, f));
    let kept = 0;
    for (const raw of lines) {
      const line = raw.trim();
      if (!line) continue;
      totalRaw++;
      const norm = sensitive.normalize(line);
      if (!norm) { emptyAfterNormalize++; continue; }
      if (Array.from(norm).length <= 1) { singleCharRemoved++; continue; }
      if (seen.has(norm)) { dupRemoved++; continue; }
      seen.add(norm);
      kept++;
    }
    perFile.push({ file: f, rawLines: lines.filter(l => l.trim()).length, kept });
  }

  let excludeHit = 0;
  for (const [word] of FALSE_POSITIVE_EXCLUDE) {
    const norm = sensitive.normalize(word);
    if (seen.has(norm)) { seen.delete(norm); excludeHit++; }
  }

  const finalWords = Array.from(seen).sort((a, b) => (a < b ? -1 : a > b ? 1 : 0));
  fs.mkdirSync(path.dirname(OUT_FILE), { recursive: true });
  fs.writeFileSync(OUT_FILE, finalWords.join('\n') + '\n', 'utf8');

  console.log('构建 words/base.txt 完成：');
  for (const p of perFile) console.log(`  ${p.file}：源 ${p.rawLines} 行 → 净收录前 ${p.kept} 条（未去重前，按文件顺序累计去重）`);
  console.log(`原始总行数 ${totalRaw}`);
  console.log(`归一化后变空 ${emptyAfterNormalize} 条（丢弃）`);
  console.log(`单字词条删除 ${singleCharRemoved} 条`);
  console.log(`跨文件重复 ${dupRemoved} 条`);
  console.log(`误伤排除 ${excludeHit}/${FALSE_POSITIVE_EXCLUDE.length} 条（FALSE_POSITIVE_EXCLUDE 列表，命中数应等于列表长度，不等说明词库更新后某条已经不在里面了）`);
  console.log(`最终 base.txt 词条数 ${finalWords.length}`);
  const stat = fs.statSync(OUT_FILE);
  console.log(`文件大小 ${stat.size} 字节`);
}

main();
