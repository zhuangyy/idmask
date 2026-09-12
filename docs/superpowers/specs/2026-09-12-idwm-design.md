# 证件水印（idwm）设计

- 日期：2026-09-12
- 状态：待评审

## 1. 概述

证件水印（idwm）是一个手机 App，用于在证件照片上加文字水印，目的是防止证件照片被挪用于约定用途之外的场合。

典型场景：用户要在线上提交身份证、学历证、户口本等证件的照片，希望在照片上叠一句「仅供某某公司办理入职使用 2026-09-12」，让这张照片即使外流也无法被当作无标注的原件使用。

### 目标

- 加一次水印只需几步：选图 → 输文案 → 看预览 → 保存
- 水印牢固：默认平铺满画面，难以裁剪或涂抹掉
- 观感一致：同一文案在小图和大图上看起来比例相同
- 全程离线：照片不出手机

### 非目标（本次不做）

- 批量处理多张照片（一次一张，但代码结构预留扩展位）
- 图片拍摄（只从相册选已有照片）
- 后端、账号、云同步、统计
- 擦除或检测已有的水印
- 桌面端与 Web 端

## 2. 技术路线

与 fitutor 保持一致。

| 项 | 选择 |
|---|---|
| 框架 | Flutter 3.47.2 stable |
| 语言 | Dart |
| 平台 | Android + iOS |
| 包名 / Bundle ID | `com.xzgg.idwm` |
| 应用显示名 | 证件水印 |
| Dart 包名 | `idwm` |
| 状态管理 | `provider`（ChangeNotifier） |
| 架构分层 | `UI(pages/widgets) → State(Provider) → Services → Data` |
| 网络 | 无。100% 离线，App 自身不发起任何网络请求 |
| 测试 | `flutter_test` |
| 本地存储 | `shared_preferences`（不建数据库表） |

### 网络与代理

App 运行时不联网。只有在安装依赖与构建时需要代理：

```bash
ALL_PROXY=socks5://127.0.0.1:7890 HTTPS_PROXY=socks5://127.0.0.1:7890 HTTP_PROXY=socks5://127.0.0.1:7890 flutter pub get
```

## 3. 依赖

已获用户同意安装以下 4 个包。除此之外不引入第三方依赖；水印绘制使用 Flutter 内置的 `dart:ui`。

| 包 | 用途 | 备注 |
|---|---|---|
| `image_picker` | 从相册选择照片 | Flutter 官方插件 |
| `gal` | 把成品图保存到系统相册 | Android 10+ 免存储权限 |
| `shared_preferences` | 记住最近文案与样式设置 | Flutter 官方插件 |
| `path_provider` | 取临时目录写中间文件 | Flutter 官方插件 |

明确不引入：

- `image`（纯 Dart 图像库）—— 见第 8 节，JPEG 编码改由平台通道完成
- `sqflite` —— 无表结构需求，`shared_preferences` 足够
- `permission_handler` —— 只在权限被拒时提示用户去系统设置，不做深链跳转

## 4. 功能范围

### 4.1 主流程

```
选图 ──▶ 输文案 ──▶ 实时预览 ──▶ 保存到相册
         (模板/自由)   (版式/样式/摆位置)
```

### 4.2 文案：模板与自由编辑双模式

两套都提供，可随时切换，**切换时保留已产生的内容**。

**模板模式** 提供三个字段：

| 字段 | 说明 | 默认值 |
|---|---|---|
| 接收方 | 证件交给谁 | 空 |
| 用途 | 办理什么事 | 空 |
| 日期 | 使用日期 | 今天 |

生成句式：

- 接收方与用途都填：`仅供⟨接收方⟩办理⟨用途⟩使用 ⟨日期⟩`
- 只填用途：`仅供办理⟨用途⟩使用 ⟨日期⟩`
- 只填接收方：`仅供⟨接收方⟩使用 ⟨日期⟩`
- 都为空：视为文案为空，保存按钮置灰（即第 10 节的「文案为空」情形）

日期格式固定为 `YYYY-MM-DD`，由日期选择器选定，默认今天。

**自由模式** 直接输入整段文字，不套句式。

从模板切到自由模式时，把当前生成的文案填入自由输入框作为起点；从自由模式切回模板模式时，字段值保持上次填写的内容。这样来回切换不会丢东西。

### 4.3 水印版式与位置

两种版式，在设置里切换，选择会被记住：

- **平铺满画面**（默认）：文字倾斜重复铺满整张图，无法靠裁剪或局部涂抹去除。位置由算法决定，用户不需也无法摆放
- **单块**：一段文字，默认居中显示，**位置可以用手指在预览上直接拖动摆放**

单块模式的摆放规则：

- 在预览图上直接拖动水印文字即可移动，跟手移动，不会跳到手指位置
- 拖动过程中在预览图上显示穿过水印中心的十字参考线，松手后隐藏
- **不做吸附**，位置完全由手指决定
- 拖到画面边缘时**夹住**，水印文字始终完整可见，不会被推出画面
- 摆好的位置会被记住：切换版式再切回来、重启 App 后仍在

### 4.4 样式

版式与位置属于低频偏好；透明度、字号、颜色是每次处理都可能微调的，放在主编辑页。数值可调项只有三项，其余走调好的默认值：

| 项 | 范围 | 默认 |
|---|---|---|
| 透明度 | 0.05 – 1.0 | 0.28 |
| 字号 | 相对图片短边的比例，0.02 – 0.12 | 0.045 |
| 颜色 | 预设色板：黑、深灰、红、白、蓝 | 深灰 `#404040` |

字号用**相对于图片短边的比例**而非绝对像素，这样同一设置在不同分辨率的照片上观感一致。

### 4.5 最近文案

记住最近使用过的 10 条水印文案，以列表形式供一键复用，新的挤掉最旧的。样式设置（版式、位置、透明度、字号、颜色）同样持久化，作为下次打开时的初始值。

### 4.6 保存行为

- 成品图**另存**到系统相册，**原图保持不动**
- 输出格式 JPEG，质量为 92
- **不保留原图 EXIF**（拍摄时间、GPS 等一律丢弃）。对证件照而言这是隐私上的优点
- 保存成功后给出明确反馈；保存失败给出可读的原因

## 5. 架构与组件

### 5.1 目录结构

Flutter 工程直接位于仓库根 `idwm/`：

```
idwm/
├── CLAUDE.md
├── reasonix.toml
├── .gitignore
├── docs/superpowers/specs/2026-09-12-idwm-design.md
├── pubspec.yaml
├── android/                      # flutter create 生成，改动见第 9 节
├── ios/                          # flutter create 生成，改动见第 9 节
├── lib/
│   ├── main.dart                 # 入口，注册 Provider
│   ├── app.dart                  # MaterialApp、主题、路由
│   ├── models/
│   │   ├── watermark_style.dart  # 版式/位置/透明度/字号/颜色 + 序列化
│   │   ├── watermark_item.dart   # 单条水印的绘制指令
│   │   └── template_fields.dart  # 接收方/用途/日期
│   ├── services/
│   │   ├── template_composer.dart      # 模板字段 → 文案（纯函数）
│   │   ├── watermark_layout.dart       # 文案+画布+位置 → List<WatermarkItem>（纯函数）
│   │   ├── watermark_painter.dart      # 按 items 绘制到 Canvas（预览与输出共用）
│   │   ├── image_renderer.dart         # 解码 → 绘制 → 编码 的编排
│   │   ├── jpeg_encoder.dart           # platform channel 封装
│   │   ├── photo_saver.dart            # gal 封装
│   │   └── recent_texts_store.dart     # 最近文案与样式的持久化
│   ├── providers/
│   │   └── watermark_provider.dart     # 唯一的 ChangeNotifier
│   ├── pages/
│   │   ├── edit_page.dart              # 主页面
│   │   └── settings_page.dart          # 版式与默认样式
│   └── widgets/
│       ├── photo_canvas.dart           # CustomPaint 实时预览
│       ├── watermark_drag_layer.dart   # 单块水印的拖动手势与参考线
│       ├── text_input_section.dart     # 模板/自由 双模式输入
│       ├── style_controls.dart         # 透明度/字号/颜色
│       └── recent_texts_sheet.dart     # 最近文案选择
└── test/
    ├── models/watermark_style_test.dart
    ├── services/template_composer_test.dart
    ├── services/watermark_layout_test.dart
    └── services/recent_texts_store_test.dart
```

页面只有两个：主编辑页（选图、输文案、预览、摆位置、保存都在这一页）和设置页。这是一个工具型 App，不套 fitutor 那样的多 Tab 结构。

### 5.2 组件职责

| 组件 | 做什么 | 依赖谁 | 怎么用 |
|---|---|---|---|
| `TemplateComposer` | 三个字段 + 日期 → 一句文案 | 无 | `compose(fields)` 纯函数 |
| `WatermarkLayout` | 画布尺寸 + 文案 + 样式 → 绘制指令列表 | 注入的文字测量器 | `compute(...)` 纯函数 |
| `WatermarkPainter` | 把绘制指令画到任意 `Canvas` 上 | `dart:ui` | 预览与输出调同一个函数 |
| `ImageRenderer` | 组织整条管线：读文件 → 解码 → 画 → 编码 JPEG → 写临时文件 | 上面几个 + `JpegEncoder` | `render(request)` 返回成品文件路径 |
| `JpegEncoder` | PNG 字节 → JPEG 字节 | platform channel | `encode(png, quality)` |
| `PhotoSaver` | 成品文件 → 系统相册 | `gal` | `save(path)` |
| `RecentTextsStore` | 读写最近文案与样式 | `shared_preferences` | `load()` / `push(text)` / `saveStyle(style)` |
| `WatermarkProvider` | 持有当前照片、文案、样式、处理状态，暴露给 UI | 上述 services | `ChangeNotifier` |
| `WatermarkDragLayer` | 叠加在预览上的透明层：接管拖动手势、算归一化坐标、画参考线 | `WatermarkProvider` | `Stack` 里盖在 `photo_canvas` 之上 |

`WatermarkDragLayer` 只负责「让用户摆水印」，不负责画水印本身 —— 水印仍由 `photo_canvas` 按 `WatermarkLayout` 的结果绘制。拖动改的只是 `WatermarkStyle.singlePosition` 这一个值，预览自然跟着重绘。

### 5.3 数据流

```
用户操作 → WatermarkProvider (状态变更) → notifyListeners()
                                              ├─▶ photo_canvas 重绘预览
                                              └─▶ 控件刷新（保存按钮可用性等）

拖动水印 → WatermarkDragLayer 手势
         → 增量换算成归一化位移
         → WatermarkProvider.updateSinglePosition(...)
         → notifyListeners() → photo_canvas 重绘

点保存 → WatermarkProvider.save()
       → ImageRenderer.render(原图路径, 文案, 样式)
       → PhotoSaver.save(成品路径)
       → 回写最近文案 → 反馈结果
```

## 6. 核心数据结构

```dart
enum WatermarkLayoutMode { tile, single }

/// 水印样式，需可序列化为 JSON 存入 shared_preferences
class WatermarkStyle {
  final WatermarkLayoutMode mode;  // 默认 tile
  final Offset singlePosition;     // 归一化 0–1，默认 (0.5, 0.5)，仅单块模式使用
  final double opacity;            // 默认 0.28
  final double fontSizeRatio;      // 相对短边，默认 0.045
  final int colorValue;            // ARGB，默认 0xFF404040
}

/// 一条水印的绘制指令，坐标系为成品图的像素坐标
class WatermarkItem {
  final String text;
  final Offset center;   // 文字中心点
  final double fontSize; // 像素
  final double rotation; // 弧度
}

/// 模板字段
class TemplateFields {
  final String receiver; // 接收方
  final String purpose;  // 用途
  final DateTime date;   // 默认今天
}
```

`WatermarkItem` 刻意不带颜色和透明度 —— 这两项属于整张图的样式，放在 `WatermarkStyle` 里由绘制层统一施加，避免每条指令重复携带。这样将来若要支持"两种颜色交替平铺"之类的效果，只需扩展 `WatermarkItem` 的可选字段。

`WatermarkStyle` 在构造与反序列化时把 `opacity`、`fontSizeRatio` 夹到第 4.4 节的合法区间，把 `singlePosition` 的两个分量夹到 0–1，颜色只接受色板内的值。这样即使持久化的数据被改坏，布局层也不会算出离谱的结果。

`singlePosition` 存的是**归一化坐标**而非像素。所以它天然与照片分辨率无关：同一张照片的预览和成品图、竖图与横图、换一张尺寸完全不同的照片，位置都按同一个比例生效。

## 7. 水印布局算法

这一节是项目的核心。设计要点是**把布局计算做成不依赖渲染环境的纯函数**。

```dart
typedef TextMeasurer = Size Function(String text, double fontSize);

class WatermarkLayout {
  static List<WatermarkItem> compute({
    required Size canvasSize,
    required String text,
    required WatermarkStyle style,
    required TextMeasurer measure,   // 注入，便于测试
  });
}
```

文字宽度测量被抽成注入的 `TextMeasurer`。生产环境传入基于 `TextPainter` 的实现；单元测试传入一个按字数估算的假实现。这样布局算法完全不依赖 Flutter binding，可以用普通 `test()` 覆盖，且能构造极端尺寸（超宽图、超窄图、超长文案）而不需要真实图片。

### 7.1 基础量

设图片短边为 `shortSide`：

- `fontSize = shortSide × style.fontSizeRatio`
- 平铺角 `θ = -30°`
- 行距 `lineHeight = fontSize × 1.8`
- 列间距 `columnGap = fontSize × 1.2`

### 7.2 平铺算法

目标是保证旋转后仍铺满整个画布，不留空白角。

1. 在旋转后的坐标系里，画布两个方向的投影长度：
   `extentX = |w·cosθ| + |h·sinθ|`
   `extentY = |w·sinθ| + |h·cosθ|`
2. 以画布中心为原点，在旋转坐标系中从 `-extentY/2` 到 `+extentY/2` 按 `lineHeight` 逐行扫描
3. 每行内以 `textWidth + columnGap` 为步长，从 `-extentX/2` 扫到 `+extentX/2`
4. 相邻行整体水平偏移半个步长，形成交错，比整齐网格更难被涂抹
5. 旋转坐标系中的点 `(cx, cy)` 换算回画布坐标：

   ```
   x = w/2 + cx·cosθ − cy·sinθ
   y = h/2 + cx·sinθ + cy·cosθ
   ```

   每条指令的 `rotation` 均为 `θ`

超出画布范围的指令照常生成，交给画布的裁剪丢弃 —— 这样算法不必处理边界特例，代码更短也更不容易出错。

### 7.3 单块算法

只有一条指令，`rotation = 0`，`fontSize = shortSide × style.fontSizeRatio × 1.2`（单块没有平铺的视觉密度，字号略放大以保持可读）。

中心点由 `style.singlePosition` 按画布尺寸换算，**再做夹取**，保证文字完整落在画面内：

```
fw, fh = 文字宽高（由 measure 得到）
px = singlePosition.dx × w
py = singlePosition.dy × h

x = (fw <= w) ? px.clamp(fw/2, w − fw/2) : w/2
y = (fh <= h) ? py.clamp(fh/2, h − fh/2) : h/2
```

- 夹取在**每次计算时按当前画布尺寸做**，而不是在拖动时写死。因为文字宽高和画布尺寸等比缩放，预览与成品图会夹取到等比的位置，两者一致
- 文字比画布还宽或还高时（超长文案配窄图），该方向改为居中。这是无奈的降级：此时文字本身已无法完整显示。见第 12 节的已知限制
- `clamp` 只在 `fw <= w` 时调用，避免最小值大于最大值

### 7.4 拖动与坐标换算

`WatermarkDragLayer` 用 `GestureDetector` 的 `onPanStart / onPanUpdate / onPanEnd`：

```
onPanUpdate:
  delta = details.delta                              // 屏幕像素增量
  singlePosition += Offset(delta.dx / previewWidth,
                           delta.dy / previewHeight) // 转成归一化增量
  再夹到 0–1
```

用**增量**而不是「把水印中心设到手指位置」，这样水印不会在按下瞬间跳到手指下方，拖动手感是跟手的。

两处边界处理分工明确：

- 拖动结束前把 `singlePosition` 夹到 0–1 —— 保证持久化的值始终合法
- 渲染时按第 7.3 节再夹一次 —— 保证文字完整可见

拖动期间显示十字参考线：一条水平线、一条垂直线，穿过水印中心，跟随拖动实时更新，`onPanEnd` 时隐藏。参考线只画在预览层，不会被保存进成品图。

手势冲突：预览区在 `edit_page` 里占一块固定高度的区域，不放在可滚动容器内部，因此拖动手势不会和页面滚动打架。

### 7.5 预览与输出的一致性

预览的 `CustomPaint` 与成品图的离屏渲染，**调用同一个 `WatermarkLayout.compute` 和同一个 `WatermarkPainter`**，区别只是画布尺寸不同。因为字号按短边比例计算，`singlePosition` 又是归一化的，两者算出的指令在各自坐标系里是等比的，用户所见即所得。

## 8. 渲染与输出管线

### 8.1 为什么需要平台通道

Flutter 内置的 `Image.toByteData` 支持的编码格式只有 PNG，没有 JPEG。而 `dart:ui` 也没有暴露 JPEG 编码器。若直接输出 PNG，一张原本 1–3 MB 的证件照会膨胀到 5–15 MB，对"发微信、传邮箱"的使用场景不友好。

引入纯 Dart 的 `image` 包可以自己编 JPEG，但 4000×3000 的图要花数秒，且显著增大 App 体积。

因此采用：**Flutter 负责绘制，原生只负责编码**。绘制逻辑只写一遍，原生代码各约 20 行，不产生重复实现。

### 8.2 管线

```
1. 读原图字节（File.readAsBytes）
2. ui.instantiateImageCodec(bytes, targetWidth/targetHeight) 解码
   —— 超过 MAX_DIMENSION 时在此处直接等比缩小，避免解码后占大内存
3. codec.getNextFrame() → ui.Image
4. PictureRecorder + Canvas
5. drawImageRect 画底图
6. WatermarkLayout.compute(...) → WatermarkPainter.paint(canvas, items, style)
7. recorder.endRecording().toImage(w, h)
8. toByteData(format: png) → PNG 字节
9. JpegEncoder.encode(pngBytes, quality: 92) → JPEG 字节   [platform channel]
10. 写入临时目录文件
11. PhotoSaver.save(tempPath) → 进入系统相册
12. 删除临时文件
```

### 8.3 尺寸上限

`MAX_DIMENSION = 4096`。超过时在解码阶段等比缩到长边 4096，并在界面上提示「图片已按 4096 像素长边压缩」。理由是 4000×3000 的 RGBA 位图约占 48 MB，解码原图、画布、编码缓冲叠加后内存峰值可能超出手机限额；而在解码阶段缩放可以避免为原尺寸分配内存。证件照极少超过这个尺寸，实际影响很小。

### 8.4 平台通道协议

- 通道名：`com.xzgg.idwm/jpeg`
- 方法：`encodeJpeg`
- 入参：`{ "png": Uint8List, "quality": Int }`
- 返回：`Uint8List`（JPEG 字节）

Android 侧用 `BitmapFactory.decodeByteArray` + `Bitmap.compress(JPEG, quality)`；iOS 侧用 `UIImage(data:)` + `jpegData(compressionQuality:)`。两侧都要在完成后释放位图，并在失败时回传可读的错误。

### 8.5 降级策略

平台通道不存在或抛错时（例如未来某平台未实现原生侧），**回退为直接保存 PNG**，功能仍可用，只是文件更大，并提示用户。降级而非失败，因为用户的目的是拿到加了水印的照片。

## 9. 权限与平台配置

### 9.1 Android

`android/app/src/main/AndroidManifest.xml`：

- `android:label="证件水印"`
- 取图优先走系统照片选择器：`image_picker` 在受支持的 Android 版本上使用系统照片选择器，不要求声明相册读取权限。实现时先不声明 `READ_MEDIA_IMAGES` / `READ_EXTERNAL_STORAGE`，真机上确认低版本也能取图；若确有版本取图失败，再补最小必要的那一个权限
- 写入相册：`gal` 在 Android 10+ 通过 MediaStore 保存，无需权限；Android 9 及以下需要 `WRITE_EXTERNAL_STORAGE`
- `applicationId` 与 `namespace` 均为 `com.xzgg.idwm`

`android/gradle.properties` 里按 fitutor 的做法预配 SOCKS5 代理，供 Gradle 拉依赖。

少声明权限是刻意的：不需要的相册读取权限既增加审核问询的风险，也让用户看到多余的授权提示。

### 9.2 iOS

`ios/Runner/Info.plist`：

- `CFBundleDisplayName` = `证件水印`
- `NSPhotoLibraryUsageDescription` —— 说明读取相册是为了选取要加水印的证件照
- `NSPhotoLibraryAddUsageDescription` —— 说明保存是为了把加好水印的照片存回相册
- `PRODUCT_BUNDLE_IDENTIFIER` = `com.xzgg.idwm`

两个权限说明文案都要写清楚用途，不能是占位符 —— 这是 App Store 审核的常见退回点。

### 9.3 字体

中文水印依赖系统字体（iOS 苹方 / Android 思源黑体）。`TextPainter` 使用默认字体族并配置合理的中文字体回退链，避免在个别设备上渲染成方框。不打包自定义字体，以免增大体积。

## 10. 错误处理

| 情况 | 处理 |
|---|---|
| 用户取消选图 | 静默返回，不报错 |
| 选中文件无法解码 | 提示「无法读取这张图片，请换一张」 |
| 文案为空 | 保存按钮置灰，不进入渲染 |
| 相册读取权限被拒 | 提示缺少权限，并引导用户到系统设置开启；不自动跳转 |
| 相册写入权限被拒 | 同上，并保留成品文件的临时路径以便重试 |
| 图片超过 4096 | 自动等比缩小 + 界面提示，不算错误 |
| 渲染过程内存不足 | 捕获异常，提示「图片过大，处理失败」，建议先裁剪 |
| 平台通道不可用 | 回退保存 PNG，并提示文件较大（见 8.5） |
| 保存过程中 App 切到后台 | 处理期间禁用保存按钮并显示进度，不额外做后台保活 |
| 未选图时在预览区拖动 | 无预览则无拖动层，手势不产生任何效果 |

渲染是几百毫秒量级的同步重活，期间显示进度指示并禁用重复点击，避免用户连点造成并发渲染。

## 11. 测试策略

### 11.1 单元测试（纯 Dart，主要投入）

| 被测 | 要点 |
|---|---|
| `TemplateComposer` | 四种字段组合的句式正确；日期格式为 `YYYY-MM-DD`；含空格、超长接收方等边界 |
| `WatermarkLayout` 平铺 | 注入假测量器。断言：指令条数 > 0；所有指令 rotation 等于 −30°；字号等于短边 × 比例；超宽图与超窄图不产生空区间；空文案返回空列表 |
| `WatermarkLayout` 单块 | 位置 (0.5, 0.5) 时居中；位置 (0, 0) 与 (1, 1) 时文字仍完整落在画布内（即夹取生效）；文字宽高超过画布时该方向居中；同一归一化位置在两种画布尺寸下产生等比的结果 |
| `WatermarkStyle` | JSON 往返序列化；`singlePosition` 越界时被夹到 0–1；非法值（透明度越界、比例越界）被夹到合法区间 |
| `RecentTextsStore` | 用 `SharedPreferences.setMockInitialValues` 注入；超出 10 条时淘汰最旧；去重；样式读写往返 |

布局算法不依赖真图，是本项目测试覆盖的重点，也是它被设计成纯函数的直接收益。「同一归一化位置在不同画布尺寸下等比」这条尤其重要 —— 它守的是预览与成品一致这件用户能直接看见的事。

### 11.2 Widget 测试

- 模板/自由模式切换时内容不丢失
- 文案为空时保存按钮禁用
- 调节透明度/字号后预览 `CustomPaint` 收到重绘
- 选图前主区域显示空状态引导
- 在预览区拖动后 `singlePosition` 变化，且被夹在 0–1 内
- 拖动过程中参考线出现，松手后消失

### 11.3 不做自动化、改为真机手测

相册读写、平台通道编码、权限弹窗、大图内存表现、拖动手感 —— 这几项依赖真实设备与系统对话框，自动化成本高于收益，归入手测清单（见 12.1）。

## 12. 风险与验证点

| 风险 | 影响 | 验证方式 |
|---|---|---|
| `instantiateImageCodec` 是否正确应用原图 EXIF 旋转 | 竖拍照片的水印方向可能不对 | 真机用竖拍照片验证；若未应用，需在解码前自行读取并应用 EXIF 方向 |
| 相册取图与保存权限在各 Android 版本上的实际要求 | 可能多声明或漏声明权限 | 真机在低版本与高版本各验证取图与保存，据结果调整 Manifest |
| 相册权限在 Android 13+ / iOS 的实际弹窗流程 | 首次保存可能失败 | 真机在全新安装状态下验证拒绝与允许两条路径 |
| 4000×3000 照片的内存峰值 | 可能触发 OOM | 真机连续处理多张大图，观察是否被系统杀死 |
| 中文在个别设备上的字体回退 | 水印显示为方框 | 真机在 iOS 与 Android 各验证一次 |
| 平台通道两端行为差异（Android `Bitmap` 与 iOS `UIImage`） | 输出画质或方向不一致 | 同一张图两端各跑一遍，比对成品 |
| 单块水印拖到某位置后换成一张长宽比差别很大的照片 | 位置观感可能不如预期 | 归一化坐标已保证等比，真机确认；不为此引入吸附 |

### 12.1 已知限制

- 单块模式下，若文案宽度超过图片宽度（超长文案配窄图），文字无法完整显示，该方向改为居中。平铺模式没有这个问题。这是有意接受的结果，不做自动缩小字号 —— 那会违背「字号由用户设定」的约定
- 单块水印只支持水平文字，不支持旋转或竖排
- 平铺模式的位置与角度不可调

### 12.2 手测清单

1. 竖拍、横拍照片各一张，确认水印方向与照片一致
2. 相册权限首次拒绝 → 再次保存 → 引导开启 → 成功保存
3. 4000×3000 大图处理，确认不闪退且水印比例正常
4. 平铺与单块两种版式各保存一次，确认与预览一致
5. 换机验证中文渲染
6. 保存后的成品在系统相册中可正常查看与分享
7. 确认原图未被修改
8. 单块模式把水印拖到四个角落，确认文字都完整可见、没被推出画面
9. 单块模式拖到某个位置后切到平铺再切回来，确认位置还在
10. 拖动时的参考线只在预览里出现，成品图上没有

## 13. 实施里程碑

供后续实施计划拆分使用：

| 阶段 | 内容 | 完成标志 |
|---|---|---|
| M1 | Flutter 工程骨架、4 个依赖、权限配置、包名 | 空 App 在 Android 与 iOS 上能跑起来 |
| M2 | 模型与服务层纯逻辑（TemplateComposer、WatermarkLayout、WatermarkStyle 含位置与夹取） | 单元测试通过 |
| M3 | 选图、输入区、预览画布、样式控件 | 能在界面上选图并实时看到预览 |
| M4 | 单块水印的拖动摆放与参考线 | 能把水印拖到任意位置，边缘被夹住，位置可持久化 |
| M5 | 渲染管线、platform channel、保存相册 | 真机上保存出带水印的 JPEG |
| M6 | 设置持久化、最近文案、错误提示与空状态 | 重启 App 后设置、位置与最近文案仍在 |
| M7 | 手测清单全过、权限文案打磨 | 手测清单 10 项全部通过 |

## 14. 与 fitutor 的差异（备查）

沿用其技术路线，但去掉不需要的部分：

| fitutor 有 | idwm 是否需要 | 说明 |
|---|---|---|
| `sqflite` + DAO 四张表 | 不要 | 无表结构需求，改用 `shared_preferences` |
| `flutter_tts` / 通知 / 后台保活 | 不要 | 与水印场景无关 |
| 多 Tab `IndexedStack` 导航 | 不要 | 只有主编辑页 + 设置页 |
| Provider 分三个 | 只要一个 | `WatermarkProvider` 统一持有状态 |
| 按比例换算尺寸（进度环） | 沿用同类思路 | 水印字号同样按图片短边比例算，保证跨分辨率观感一致 |
