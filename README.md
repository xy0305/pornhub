# Pornhub

原生 SwiftUI/UIKit iOS 客户端，**1.0.0 build11**。年轻、舒展的黑橙发现界面、官网真实内容解析、单 UIKit KSPlayer HLS 播放；无 WebView 或网页套壳。

## Build11 · 原生视觉改版

- 轻量品牌导航代替双层厚胶囊栏；大标题发现区、精致搜索、真实分类/明星/观看记录快捷入口与热门标题区，非单纯换色。
- 有节制的橙色/暖中性色，图片优先的浅层实底内容卡片；分类、明星、作者、详情、媒体、订阅与账号统一标题和信息层级。无假统计、假推荐或无功能按钮。
- iOS26真实公开 Liquid Glass 仅用于导航/搜索/操作；iOS17 material与Reduce Transparency不透明回退。保留44pt命中、单sheet所有者、装饰层不拦截触摸、Dynamic Type、自适应网格与窄屏metadata fallback。
- **播放器/seek/手势/画质政策/解析/网络客户端源文件字节不动**：保留真实最高有效画质、手动画质保留、单UIKit横屏aspectFit、左上返回/画质菜单/进度seek、PiP后台、build10亮度音量手势。
- 保留作者真实筛选/分页、官网`/subscriptions`账号隔离与原登录协议；未执行真实登录/订阅写。

详见 [Build11视觉与验收边界](Docs/Build11.md)、[Build10手势审计](Docs/Build10.md)、[Build9](Docs/Build9.md)、[Seek状态机](Docs/Player-build5.md)。

## 验证与发布

```sh
python3 Tests/PlayerChecks/ui_check.py
python3 Tests/PlayerChecks/check.py
python3 Tests/ParserRegression/check.py Tests/Fixtures
```

GitHub Actions/Xcode26编译执行Swift画质/解析/seek/手势回归、实际Simulator XCUITest（原有交互及新增快捷入口/账号/详情/特大字体），导出`Build11-UIEvidence-synthetic-fixtures`截图，再构建`Pornhub-unsigned-1.0.0-11.ipa`。实际执行结果以对应commit的Actions为准。

**静态检查不是视觉验收；不可播放的localhost测试源不是播放验收。** 实际Simulator截图使用synthetic fixture，非线上内容、不伪造截图。真实PiP、后台/锁屏、系统音量、真实媒体连续播放、iPad/旧系统/Reduce Transparency全矩阵及真机视觉仍需设备验收。未签名IPA须自行签名安装。原生邮箱登录仍使用官网接口；验证码失败如实显示，不假登录。
