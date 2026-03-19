import UIKit
import Flutter
import GoogleMaps // 1. Add this import

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 2. Add this line with your key
    GMSServices.provideAPIKey("AIzaSyDSancgtsmUfagoV1aW20WXv1HfvsdwAF8")

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}