import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var profilePhotoChannel: FlutterMethodChannel?
  private var appIconChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let photoChannel = FlutterMethodChannel(
      name: "selah/profile_photo",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    photoChannel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "normaliseProfilePhoto", let self else {
        result(FlutterMethodNotImplemented)
        return
      }
      self.normaliseProfilePhoto(arguments: call.arguments) { data, error in
        if let error {
          result(error)
        } else {
          result(data)
        }
      }
    }
    profilePhotoChannel = photoChannel

    // This draft owns one Selah icon. Never expose another app's alternate icons.
    let iconChannel = FlutterMethodChannel(
      name: "selah/app_icon",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    iconChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "getAppIconState":
        result(["supported": false, "iconName": NSNull()])
      case "setAppIcon":
        result(FlutterError(
          code: "unsupported",
          message: "This Selah draft uses its own primary app icon.",
          details: nil
        ))
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    appIconChannel = iconChannel
  }

  // Preserve the existing privacy-safe local preparation primitive. This does
  // not upload anything or connect Selah to any other application's backend.
  private func normaliseProfilePhoto(
    arguments: Any?,
    completion: @escaping (FlutterStandardTypedData?, FlutterError?) -> Void
  ) {
    guard
      let arguments = arguments as? [String: Any],
      let maxDimension = arguments["maxDimension"] as? NSNumber,
      let quality = arguments["quality"] as? NSNumber,
      (arguments["data"] is FlutterStandardTypedData || arguments["path"] is String),
      maxDimension.doubleValue > 0,
      quality.doubleValue >= 0,
      quality.doubleValue <= 100
    else {
      completion(nil, FlutterError(
        code: "photo_bad_arguments",
        message: "The selected photo could not be prepared.",
        details: nil
      ))
      return
    }

    let suppliedData = (arguments["data"] as? FlutterStandardTypedData)?.data
    let suppliedPath = arguments["path"] as? String
    DispatchQueue.global(qos: .userInitiated).async {
      autoreleasepool {
        let sourceData = suppliedData ?? suppliedPath.flatMap {
          try? Data(contentsOf: URL(fileURLWithPath: $0))
        }
        guard
          let sourceData,
          let sourceImage = UIImage(data: sourceData),
          sourceImage.size.width > 0,
          sourceImage.size.height > 0
        else {
          DispatchQueue.main.async {
            completion(nil, FlutterError(
              code: "photo_decode_failed",
              message: "The selected photo format could not be prepared.",
              details: nil
            ))
          }
          return
        }

        let longestEdge = max(sourceImage.size.width, sourceImage.size.height)
        let scale = min(1.0, maxDimension.doubleValue / longestEdge)
        let targetSize = CGSize(
          width: max(1, (sourceImage.size.width * scale).rounded()),
          height: max(1, (sourceImage.size.height * scale).rounded())
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let outputData = renderer.jpegData(
          withCompressionQuality: quality.doubleValue / 100.0
        ) { context in
          UIColor.black.setFill()
          context.fill(CGRect(origin: .zero, size: targetSize))
          // Fresh pixels strip EXIF/GPS/capture/device metadata and normalise
          // source orientation before the local draft can use the image.
          sourceImage.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        guard !outputData.isEmpty else {
          DispatchQueue.main.async {
            completion(nil, FlutterError(
              code: "photo_encode_failed",
              message: "The selected photo could not be encoded safely.",
              details: nil
            ))
          }
          return
        }
        DispatchQueue.main.async {
          completion(FlutterStandardTypedData(bytes: outputData), nil)
        }
      }
    }
  }
}

