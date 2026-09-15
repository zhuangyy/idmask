# CLAUDE.md

本文件指导在本仓库工作的 AI Agent。

## 项目概述

证件水印（idmask）—— 在证件照片上叠文字水印的 Android + iOS App。

用途：在线上提交身份证、学历证等证件照片时，先叠一句「仅供某某公司办理入职使用 2026-09-12」，
让照片即使外流也无法被当作无标注的原件使用。

关键属性：100% 离线、无账号、无后端、单张处理、水印默认平铺满画面、单块模式可用手指拖动摆放、
成品另存到系统相册（原图不动）。

Flutter 工程**直接位于仓库根目录**，不是子目录。

## 命令

所有命令在仓库根执行。

```bash
flutter run
flutter test
flutter analyze
flutter build apk
flutter build ios --simulator
```

平台通道与渲染链要在真实设备上验证（必须指定设备）：

```bash
flutter test integration_test/platform_channels_test.dart -d <device-id>
```

### 代理

`flutter pub get` / `flutter test` / `flutter build` 需要 SOCKS5 代理：

```bash
export ALL_PROXY=socks5://127.0.0.1:7890
export HTTPS_PROXY=socks5://127.0.0.1:7890
export HTTP_PROXY=socks5://127.0.0.1:7890
```

## 架构

`UI(pages/widgets) → State(WatermarkProvider) → Services → 本地存储`

### 核心设计：布局与绘制分离

`WatermarkLayout.compute(...)` 是纯函数，把 `(画布尺寸, 文案, 样式)` 算成 `List<WatermarkItem>` 绘制指令。
文字测量通过注入的 `TextMeasurer` 提供 —— 测试传估算实现，生产传 `TextPainterMeasurer`。

**预览与成品图调用同一个 `compute` 和同一个 `WatermarkPainter.paint`**，区别只是画布尺寸。
字号按图片短边比例、单块位置是归一化坐标，所以两者结果等比，所见即所得由结构保证。

改动布局算法时务必保持这条性质：不要引入任何绝对像素常量，否则预览与成品会不一致。
`test/services/watermark_layout_test.dart` 里那条「同一归一化位置在两种画布尺寸下产生等比的结果」
守的就是这件事。

### 关键模块

| 模块 | 职责 |
|---|---|
| `WatermarkLayout` | 布局计算（纯函数，核心） |
| `WatermarkPainter` | 按指令绘制到 Canvas（预览与输出共用） |
| `PhotoFingerprint` | 内容指纹，用于最近照片去重（纯函数，FNV-1a 抽样首/中/末各 4KB） |
| `RecentPhotosStore` | 照片副本与缩略图的增删查、容量淘汰（10 张）、孤儿清理 |
| `RecentTextsStore` | 最近文案（10 条）与样式的持久化 |
| `ImageRenderer` | 解码 → 绘制 → 编码 JPEG → 写临时文件 |
| `JpegEncoder` | PNG → JPEG 平台通道 |
| `BackupExcluder` | iOS 上把照片副本目录排除出 iCloud 备份 |

`RecentPhotosStore` 的根目录与缩略图生成器都是**构造注入**的，内部不调 path_provider、不碰 dart:ui。
改它的时候保持这个约定 —— 测试靠它才能在临时目录里做真实的文件系统断言。

## 本地存储

- `shared_preferences` 三个键：`recent_photos`、`recent_texts`、`watermark_style`
- App 私有目录 `idmask_photos/`：照片副本 + `thumbs/` 缩略图
  - 副本**直接复制源字节**，不重新编码（保留原始画质）
  - **iOS 上该目录排除 iCloud 备份**（见 `lib/services/backup_excluder.dart`），
    这是隐私承诺，不要删掉那段逻辑
- 成品图写到系统临时目录，存进相册后立即删掉临时文件

## 平台通道

两条，原生实现分别位于 `android/app/src/main/kotlin/com/xzgg/idmask/MainActivity.kt`
与 `ios/Runner/AppDelegate.swift`：

| 通道 | 方法 | 用途 |
|---|---|---|
| `com.xzgg.idmask/jpeg` | `encodeJpeg` | PNG → JPEG。不可用时 Dart 侧返回 null，上层回退存 PNG |
| `com.xzgg.idmask/storage` | `excludeFromBackup` | 仅 iOS；把目录排除出 iCloud 备份 |

**iOS 集成方式**：插件走 Flutter 的 **Swift Package Manager**（生成物在 `ios/Flutter/ephemeral/Packages/`），
`ios/` 下**没有也不需要 Podfile** —— 不要新建 Podfile，也不要执行 `pod install`。

**iOS 侧注意**：本工程是 Flutter 3.47.2 的 **UIScene 架构**（存在 `ios/Runner/SceneDelegate.swift`，
且 `Info.plist` 里有 `UIApplicationSceneManifest`）。`AppDelegate` 声明为
`class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate`，通道在
`didInitializeImplicitFlutterEngine` 里用 `engineBridge.applicationRegistrar.messenger()` 注册。
**不要改回 `window?.rootViewController` 的老写法** —— 那种写法在本架构下拿不到控制器，通道会静默失效。

## 依赖约束

只允许：`image_picker`、`gal`、`shared_preferences`、`path_provider`、`path`、`provider`、`package_info_plus`、`cupertino_icons`。

其中 `package_info_plus` 读取 App 版本号，显示在标题栏。

**不要引入**：`image`（JPEG 编码已有平台通道）、`sqflite`（键值存储已够）、
`permission_handler`（权限被拒时只提示，不做深链跳转）、`crypto`（去重指纹用自写的 FNV-1a）。
新增依赖前先问人。

## 测试

`test/` 下按被测对象分文件。纯逻辑（布局、文案、指纹、存储）与主编辑页的 widget 测试都已覆盖，
全量 82 条。

`integration_test/platform_channels_test.dart` 覆盖只能在真机/模拟器上跑的三件事：
JPEG 编码平台通道、渲染链（解码 → 绘制 → 编码 → 写临时文件）、iOS 的 iCloud 备份排除。
它不在 `flutter test` 的默认范围内，要按上面的命令显式指定设备运行。

真机相关的事靠手测：相册读写、平台通道编码、权限弹窗、大图内存表现、拖动手感、
iCloud 备份排除是否生效。清单见设计文档第 12.2 节。

## 在模拟器上做自动化验证

用 `adb` 驱动界面验证时，有三条容易踩的坑：

- **拖动要用 `input motionevent`，不能用 `input swipe`。** `input swipe` 产生的 `DragUpdateDetails.delta` 恒为 0，Flutter 侧的状态不会被推动，看起来像「拖动没生效」。要逐条注入 DOWN / MOVE / UP：

  ```bash
  adb shell input motionevent DOWN 400 600
  sleep 0.3
  adb shell input motionevent MOVE 460 600
  sleep 0.3
  adb shell input motionevent MOVE 520 600
  sleep 0.3
  adb shell input motionevent UP 520 600
  ```

- **`Offset.toString()` 有精度损失。** 它内部用 `toStringAsFixed(1)`，所以 `Offset(0.25, 0)` 会打印成 `Offset(0.3, 0)`。靠日志判断数值时别被它骗了，必要时直接打印 `dx` / `dy` 分量。

- **别拿自带水印的成品图当验证素材。** 照片内容里的水印会和刚渲染的水印叠在一起，看不出差异，容易误判成「修复没生效」。先用一张干净图片。

## Git 提交约定

**commit message 一律用英文**（subject 与正文都是）。仓库里的文档、注释与对话可以用中文，
但提交信息统一英文，便于跨项目检索与协作。沿用 Conventional Commits 前缀
（`feat` / `fix` / `docs` / `chore` / `style` / `refactor` / `test` / `perf`）。

```bash
git commit -m "fix: keep the reference line centered on the watermark"
git commit -m "feat: support dragging the tiled watermark offset" -m "Clamp the offset to 3/4 of the canvas."
```

## 设计文档

`docs/superpowers/specs/2026-09-12-idmask-design.md` 是唯一事实来源，改动行为前先读它。
实施计划在 `docs/superpowers/plans/2026-09-12-idmask.md`。
