# 空白 DEBUG 窗口核查（进行中）

11/07 D0转达用户截图。尚无法仅凭标题唯一定位截图属于哪一个Godot进程，不宣称已回首页。

已确认一个可复现来源：D2新固定尺寸QA harness将游戏渲染到SubViewport并保存PNG，但没有把该viewport纹理呈现给根Window，根窗口因此保持Godot默认纯灰，标题继承“苏七镇奇缘 (DEBUG)”。这不是Web包首页，也不能作为正常启动画面。

修复：full_flow_review.gd、round1_interactions_test.gd、photo_restore_test.gd均增加TextureRect呈现实际测试viewport，窗口标题显式标“内部验证／非交付包”。另发现并修复正式章节元数据校验冲突：转换scene时遗留actorMode=sprite而visibleActors为空，造成player初始化失败。现在38个playlist节点均能正常初始化运行。

待补：最终新Web包正常boot入口冷启动、可见书桌首页截图及四屏到上海连续点击证据；未以日志代替画面。
