import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let galleryChannel = FlutterMethodChannel(
        name: "lpco/image_gallery",
        binaryMessenger: controller.binaryMessenger
      )
      galleryChannel.setMethodCallHandler { call, result in
        guard call.method == "saveImage",
              let arguments = call.arguments as? [String: Any],
              let data = arguments["bytes"] as? FlutterStandardTypedData,
              let image = UIImage(data: data.data) else {
          result(FlutterError(code: "invalid_image", message: "Image data is missing", details: nil))
          return
        }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        result(nil)
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
