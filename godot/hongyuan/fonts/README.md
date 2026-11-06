# 对白 Emoji 回退

`HongyuanEmoji.ttf` 是 Noto Emoji 的 U+1F602 / U+1F914 子集，仅补原稿的 😂🤔。正文仍用项目像素字体。授权见 OFL.txt。

来源：https://github.com/google/fonts/tree/main/ofl/notoemoji ，原文件 `NotoEmoji[wght].ttf`。FontTools 4.60.2 命令：

```sh
pyftsubset 'NotoEmoji[wght].ttf' --unicodes=U+1F602,U+1F914 --output-file=HongyuanEmoji.ttf --layout-features='*' --name-IDs='*' --name-languages='*'
```

新增原稿字符时更新子集；本次不改文案。
