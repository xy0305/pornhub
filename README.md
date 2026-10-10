# Pornhub

原生 SwiftUI/UIKit iOS 客户端，1.0.0 build6。黑橙品牌、官网内容信息层级；公开内容来自官网 HTML/JSON 数据解析，HLS 使用单 UIKit KSPlayer 播放。**不是网页封装：应用没有 WKWebView/UIWebView、嵌入站点、网页登录或 SVG 网页回退。**

## Build6 原生视觉升级

顶部导航/搜索与操作区使用 iOS26 公开 Liquid Glass API (`glassEffect`、`GlassEffectContainer`、`.glass`/`.glassProminent`)，以 availability 分支兼容 iOS17 material。Reduce Transparency 使用不透明控件；视频/资料/订阅卡片保持实底可读，不把全部内容叠透明。统一间距、圆角、44pt 操作、卡片字体层次，分类/明星自适应网格。播放器与 seek 状态机完全保留 build5 实现。

完整设计、官方参考、原生审计与真机待验收边界见 [Docs/UI-build6.md](Docs/UI-build6.md)，播放器说明见 [Docs/Player-build5.md](Docs/Player-build5.md)。

## 验证与构建

```sh
python3 Tests/UIChecks/check.py
python3 Tests/PlayerChecks/check.py
python3 Tests/ParserRegression/check.py Tests/Fixtures
```

GitHub Actions 使用 Xcode26 运行以上保护、实际 Swift seek/解析测试，Release iphoneos 编译并生成 `Pornhub-unsigned-1.0.0-6.ipa`。静态检查不是截图/真机交互测试；本次环境没有本地 Xcode 与真机。

**未签名 IPA 需要自行签名后安装。** 登录走原生邮箱表单与官网接口；站点要求验证码时会报告失败，不会假装已登录。网络 HTML 是数据源而非页面渲染。本次升级不执行真实登录或订阅写操作。
