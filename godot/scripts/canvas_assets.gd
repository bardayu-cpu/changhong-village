extends RefCounted
## 画布的图从哪来（HANDOFF §0.9）：场景代码读底图、积木图一律走这里，不直接 load。
## 现在全从包里读。远程加载真机验过以后只改这一处：先看本机 user:// 有没有、大小对不对，
## 没有就从云存储下载（做法见 scripts/remote_probe.gd、回执 远程加载-最小验证.md）。
## 宴会厅的图这次不迁出包（01 9/19）

static func texture(path: String) -> Texture2D:
    return load(path)
