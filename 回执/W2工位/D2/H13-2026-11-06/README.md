# H11 冻结 Web 输入观测工具

只读提供 b6415d7 冻结 Web 文件，监听 DOM 输入、只读观察游戏存档。观测工具不调用游戏内部方法、不注入存档、不派发 DOM 事件。游戏自身仍会正常写存档。证据全部留在本机。

## 重跑

需 Python 3.9+、带内置 WebSocket 的 Node，以及已授权且正在运行的本机 Chrome CDP。本工具不会启动浏览器、开启调试或修改安全设置。默认使用已有 9364；如不存在则停止，由操作者提供可用本机端口。

```sh
python3 serve.py --port 8897 --frozen /absolute/path/to/h-delivery-b6415d7
```

在另一个终端：

```sh
node cdp-probe.mjs touch
node cdp-probe.mjs mouse
```

端口不同可设置 `H11_CDP_ORIGIN=http://127.0.0.1:9364` 和 `H11_PROBE_ORIGIN=http://127.0.0.1:8897`。仅接受 127.0.0.1。每轮建立独立临时浏览器上下文及存储，结束只销毁自己的上下文。截图、事件、调用和检查结果放进带时间戳的 chrome-* 目录。

顺序：正常请柬按钮 (180,92) → 等上海上车步骤 → 摇杆 (64,558) 拖到 (100,558) 停留 500ms → 点地 (263,445) → 确认仍是上车步骤 → 手动点互动图标 (263,382)。坐标为游戏 CSS 像素；截图为 DPR 3 的 1080×1920。

Safari：新建无痕窗口，使用独立端口（本次桌面 8897、响应式 8898），打开 `/?run=本次英文标识`。正常点击请柬走入上海；按画面缩放换算坐标，完成相同步骤。响应式模式另核对 360×640、3×、iPhone UA。浏览器窗口缩放和屏幕截图坐标不同，不能机械照搬其他工位的屏幕坐标。日志自动写入 `events/本次英文标识.jsonl`；不需要开启设备检查或 JavaScript 自动化权限。

## 证据解释

- CDP touch 是浏览器合成触控；即使 `isTrusted=true`，也不代表手指或物理 iPhone。只标 Web 开发检查。
- Safari 的 CUA 原生鼠标操作也不是人工手指。必须同时看 pointerType、touch 事件、坐标、持续时间与保存脚点。
- 日志的本地 HTTP 请求可能乱序；同一次页面会话按 seq 排序。reload 后 seq 会从 1 开始。
- `probe-v1.js` 是首轮 Chrome 与桌面 Safari 使用的版本，会过滤 buttons=0 的 move 事件。Safari CUA 鼠标在本机报告 buttons=0，因此首轮缺失 move 记录。现行 probe.js 取消该过滤，响应式与最终脚本重跑使用现行版。两版都不更改事件传播。
- `safari-desktop.jsonl` 只是最初定位页面时的环境记录，不是桌面实测；桌面实测是 safari-native-desktop。后者尾部包含进入响应式和改 UA 导致的加载/失焦记录，桌面四次操作以截图和输入时刻为界。
- Chrome 首轮 touch 有一次 favicon.ico 404；没有 Runtime.exceptionThrown。Safari 日志只监听 window error，并非完整网络/控制台采集。

本工具不构成 D4 体验通过，不包含驾驶/停车五轮，不替代微信或 iOS 真机验收。冻结包以 SHA256SUMS.web.txt 启动校验；服务不改包。
