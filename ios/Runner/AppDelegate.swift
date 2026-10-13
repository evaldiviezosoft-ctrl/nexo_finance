import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var privacyCover: UIView?
  private var privacyCoverRemoval: DispatchWorkItem?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationWillResignActive(_ application: UIApplication) {
    super.applicationWillResignActive(application)
    privacyCoverRemoval?.cancel()
    privacyCoverRemoval = nil
    guard privacyCover == nil, let window = window else { return }
    let cover = UIView(frame: window.bounds)
    cover.backgroundColor = .black
    cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    cover.accessibilityIdentifier = "nexo-finance-privacy-cover"
    window.addSubview(cover)
    privacyCover = cover
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    privacyCoverRemoval?.cancel()
    let removal = DispatchWorkItem { [weak self] in
      guard application.applicationState == .active else { return }
      self?.privacyCover?.removeFromSuperview()
      self?.privacyCover = nil
      self?.privacyCoverRemoval = nil
    }
    privacyCoverRemoval = removal
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: removal)
  }
}
