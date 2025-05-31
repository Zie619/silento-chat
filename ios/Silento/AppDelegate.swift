import UIKit
import ScreenProtectorKit

class AppDelegate: NSObject, UIApplicationDelegate {
    private var screenProtectorKit: ScreenProtectorKit?
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Initialize ScreenProtectorKit with the main window
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            screenProtectorKit = ScreenProtectorKit(window: window)
            screenProtectorKit?.configurePreventionScreenshot()
        }
        
        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Enable screenshot prevention and remove protection overlay
        screenProtectorKit?.enabledPreventScreenshot()
        screenProtectorKit?.disableBlurScreen()
        
        // Check for screen recording
        if screenProtectorKit?.screenIsRecording() == true {
            showScreenRecordingAlert()
        }
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Disable screenshot prevention and add protection overlay
        screenProtectorKit?.disablePreventScreenshot()
        screenProtectorKit?.enabledBlurScreen()
    }
    
    private func showScreenRecordingAlert() {
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else { return }
            
            let alert = UIAlertController(
                title: "🚫 Screen Recording Detected",
                message: "Screen recording is not allowed in secure chat rooms. Please stop recording to continue using the app.",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Understood", style: .default))
            
            var rootViewController = window.rootViewController
            while let presentedViewController = rootViewController?.presentedViewController {
                rootViewController = presentedViewController
            }
            
            rootViewController?.present(alert, animated: true)
        }
    }
} 