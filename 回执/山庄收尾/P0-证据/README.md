# P0 · 360×640 实拍证据

基准：`hongyuan-launch @ 4ae581fa1fb539d7df76a3164f222c42d621fd8f`。

从该提交导出隔离副本，使用 Godot 4.7.2 图形窗口运行真实 `WorldEntry → Wedding`；开车到停车场后，以原场景切换逻辑逐区加载，迎宾院至宴会厅用直接入席路径。选择正常场景可见、镜头稳定时，在每次帧绘制结束后直接保存游戏根窗口像素；未裁剪、缩放、拼接或生成画面。采用独立存档；与婚礼无关的村子、剧情素材不参与本轮运行。

如需复核：从基准另建隔离副本，启动 `godot/hongyuan/world_entry.tscn`，使用 360×640 图形窗口（高 DPI 关闭），选择婚礼入口，按下表机位用原画布切换和普通镜头取景。化妆间的截图位于后厅子区；不是独立画布。脚本切场、原地取景均不证明逐门步行、全玩法或跨世界回归通过。

| 文件 | 实际场景 | 玩家坐标 | SHA-256 |
|---|---|---|---|
| [迎宾院](court.png) | `court` | `(1430.0, 780.0)` | `261ca8aefc8fddd3df6e255864417ef20b8291bbf2ebc1dd5c344f4a60664f1d` |
| [宴会厅](banquet.png) | `banquet` | `(1035.0, 415.0)` | `610a15cc7bc2c9b4f3c7219f8f617d5b90cb84bd37ffb249286a8664d98e1d95` |
| [后厅](backhall.png) | `backhall` | `(1426.0, 780.0)` | `e4a6d698a2faa96c6c5ef977d03eec00b172ad59b4fd9c3f69075de3ff26edc5` |
| [草坪](lawn.png) | `lawn` | `(1496.0, 440.0)` | `ff422bae9a88a4207610985e914ef9e381b366f85773347bb508b05b4674ca9e` |
| [湖边](lake.png) | `lake` | `(768.0, 996.0)` | `3dcd4d03d73645022a16c808365d8d8f370c7d1c555a9e0df7abc68bda8341a0` |
| [果园](orchard.png) | `orchard` | `(1116.0, 1066.0)` | `0c4171a51f6c0d2dd89aef85a8122e50087603b009a45ccae155cff3827cdd90` |
| [停车场](parking.png) | `parking` | `(439.0, 946.0)` | `52d732e65b0c81bc487ce912c6234bf86cf98423d88aee021f31ddce1ab6a93e` |
| [喷泉广场](plaza.png) | `plaza` | `(1430.0, 720.0)` | `f0eb07baeec3e45f21c65735db3d39e4c9bdc206adfef8e7d7cf1d9c53583c62` |
| [儿童乐园](kids.png) | `kids` | `(772.0, 106.0)` | `49f33399ffa023bdb65fbb0b05bbec0ceff035beb0219cf92c5218a8a2419cc5` |
| [小卖部](shop.png) | `shop` | `(106.0, 560.0)` | `a9fcb4707c890ba61b84592377145ef1f110cbfbb5a6eb1f5ad45363d8220d53` |
| [休息厅2](rest2.png) | `rest2` | `(106.0, 560.0)` | `00907392d05103495ebd1fafb1603e5bfeca97eb86d88fc58d88312798f82c5a` |
| [西餐厨房](wkitchen.png) | `wkitchen` | `(576.0, 106.0)` | `b0d226d4d70dd7de1f2552a71d9632f31721f2ed59fa21619eba48eef5d12e7a` |
| [后花园](garden.png) | `garden` | `(796.0, 106.0)` | `e2c27907eabbe221abf7f68fccc5fcf1b8c9ed493ee950be91c8d6033276281f` |
| [前门](frontgate.png) | `frontgate` | `(1430.0, 536.0)` | `9f80e2e1a3a057ce18c3192d18d9951f85b0d0426539382f8f0fe032596f9294` |
| [后门](backgate.png) | `backgate` | `(576.0, 918.0)` | `d52c186179fe38243e335756ca4500cb549e11901c54487438c41ff085f63b94` |
| [化妆间](makeup.png) | `backhall` | `(1363.0, 430.0)` | `4e99ce5c99bac40b9f21c779314d8987e9f5e935b58b8c53510e0e9060f6c429` |
