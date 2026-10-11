# Pornhub

原生 SwiftUI/UIKit iOS 客户端，**1.0.0 build9**。黑橙精致界面、官网真实内容解析、单 UIKit KSPlayer HLS 播放；无 WebView 或网页套壳。

## Build9

- 首次播放选择真实最高有效分辨率，不受网站低档 defaultQuality 影响。未知画质显示“自动”，不伪造1080标签。手动画质在同视频刷新/签名URL更新时保留，位置与播放意图通过源就绪恢复。
- 重构导航为克制的玻璃操作栏；实底内容、缩略图优先的视频卡片、标题/作者元信息层级、自适应首页/分类/明星/媒体网格、宽屏内容限宽、作者统计窄屏fallback、统一loading/错误/空态。
- iOS26公开 Liquid Glass；iOS17 material兼容；Reduce Transparency不透明回退；保留44pt命中、单sheet所有者和横屏左上安全区返回修复。
- 系统Picture in Picture（设备/源不支持时明确提示）、后台音频模式、横屏左侧竖滑亮度/右侧竖滑系统音量及原生HUD。复用单一方向锁pan，排除控件及seek冲突；不调用私有API。
- 保留作者真实筛选/分页及订阅账号隔离；不改变登录协议、不执行真实登录/订阅写。

详见 [Build9实现与验收边界](Docs/Build9.md)、[Build8](Docs/Build8.md)、[Seek状态机](Docs/Player-build5.md)。

## 验证与发布

```sh
python3 Tests/PlayerChecks/ui_check.py
python3 Tests/PlayerChecks/check.py
python3 Tests/ParserRegression/check.py Tests/Fixtures
```

GitHub Actions/Xcode26另行编译执行Swift画质/解析/seek回归、实际Simulator XCUITest并导出合成fixture截图，然后构建`Pornhub-unsigned-1.0.0-9.ipa`。

**静态检查不是视觉验收；不可播放的localhost测试源不是播放验收。** 合成截图不是线上数据。真实PiP、后台/锁屏、系统音量、真实媒体连续播放及真机视觉仍需设备验证。未签名IPA须自行签名安装。原生邮箱登录仍使用官网接口；验证码失败如实显示，不假登录。
