import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    // 先注册插件，再注册本 App 的方法通道，确保 engine 就绪后再挂通道。
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: "com.xzgg.idwm/jpeg",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )

    channel.setMethodCallHandler { call, result in
      guard call.method == "encodeJpeg" else {
        result(FlutterMethodNotImplemented)
        return
      }

      guard let args = call.arguments as? [String: Any],
            let data = args["png"] as? FlutterStandardTypedData,
            let image = UIImage(data: data.data) else {
        result(FlutterError(code: "BAD_ARGS", message: "缺少或无法解析 png 参数", details: nil))
        return
      }

      // Dart 侧传的是 0–100 的整数，UIImage 的 compressionQuality 需要 0–1 的浮点。
      let quality = (args["quality"] as? NSNumber)?.doubleValue ?? 92.0
      guard let jpeg = image.jpegData(compressionQuality: quality / 100.0) else {
        result(FlutterError(code: "ENCODE_FAILED", message: "JPEG 编码失败", details: nil))
        return
      }

      result(FlutterStandardTypedData(bytes: jpeg))
    }
  }
}
