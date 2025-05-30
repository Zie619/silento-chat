import UIKit
import WebKit
import AVFoundation

class ViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    
    private var webView: WKWebView!
    private var splashImageView: UIImageView!
    private var errorLabel: UILabel!
    private var loadingTimeout: Timer?
    
    private let LOADING_TIMEOUT: TimeInterval = 30.0 // 30 seconds timeout
    
    private var urlsToTry = [
        "https://silento-backend.onrender.com",  // Your hosted backend
        "http://192.168.68.52:3000",      // Current network IP (fallback for development)
        "http://172.20.10.2:3000",       // Previous network IP (fallback for development) 
        "http://localhost:3000",         // Localhost (fallback for development)
    ]
    private var currentUrlIndex = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set background color to prevent black screen
        view.backgroundColor = UIColor.black
        
        print("ViewController: viewDidLoad started")
        setupSplashScreen()
        setupErrorLabel()
        setupWebView()
        
        // Delay loading to ensure everything is set up
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.loadWebApp()
        }
    }
    
    private func setupSplashScreen() {
        // Create splash screen with full-screen image
        splashImageView = UIImageView()
        
        // Try to load splash.png from bundle
        if let splashImage = UIImage(named: "splash") {
            splashImageView.image = splashImage
        } else {
            // Fallback to app icon if splash.png not found
            if let appIcon = UIImage(named: "AppIcon") {
                splashImageView.image = appIcon
            } else {
                // Last fallback - create a simple colored background
                splashImageView.backgroundColor = UIColor.systemBlue
            }
        }
        
        splashImageView.contentMode = .scaleAspectFill
        splashImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(splashImageView)
        
        // Make splash image full screen
        NSLayoutConstraint.activate([
            splashImageView.topAnchor.constraint(equalTo: view.topAnchor),
            splashImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            splashImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            splashImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        print("ViewController: Splash screen setup completed")
    }
    
    private func setupErrorLabel() {
        errorLabel = UILabel()
        errorLabel.text = "Loading Silento..."
        errorLabel.textColor = UIColor.white
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0
        errorLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        errorLabel.layer.cornerRadius = 8
        errorLabel.clipsToBounds = true
        
        view.addSubview(errorLabel)
        
        NSLayoutConstraint.activate([
            errorLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -50),
            errorLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            errorLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            errorLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }
    
    private func setupWebView() {
        let configuration = WKWebViewConfiguration()
        
        // Enable JavaScript
        configuration.preferences.javaScriptEnabled = true
        
        // Allow inline media playback
        configuration.allowsInlineMediaPlayback = true
        
        // Allow picture-in-picture
        configuration.allowsPictureInPictureMediaPlayback = true
        
        // Configure user content controller for JavaScript bridge
        let userContentController = WKUserContentController()
        configuration.userContentController = userContentController
        
        // Set a reasonable timeout for resource loading
        configuration.websiteDataStore = WKWebsiteDataStore.default()
        
        // Inject CSS for iOS-specific styling
        let cssString = """
        :root {
            --ios-safe-area-top: env(safe-area-inset-top);
            --ios-safe-area-bottom: env(safe-area-inset-bottom);
            --ios-safe-area-left: env(safe-area-inset-left);
            --ios-safe-area-right: env(safe-area-inset-right);
        }
        
        body {
            padding-top: env(safe-area-inset-top);
            padding-bottom: env(safe-area-inset-bottom);
            padding-left: env(safe-area-inset-left);
            padding-right: env(safe-area-inset-right);
            -webkit-touch-callout: none;
            -webkit-user-select: none;
            user-select: none;
        }
        
        /* Hide scrollbars */
        ::-webkit-scrollbar {
            display: none;
        }
        
        /* Improve touch targets */
        button, input, .ios-haptic {
            -webkit-tap-highlight-color: transparent;
            touch-action: manipulation;
        }
        """
        
        let cssScript = WKUserScript(
            source: """
            var style = document.createElement('style');
            style.innerHTML = `\(cssString)`;
            document.head.appendChild(style);
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        userContentController.addUserScript(cssScript)
        
        // Create webview
        webView = WKWebView(frame: view.bounds, configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.backgroundColor = UIColor.black
        webView.isOpaque = false
        webView.scrollView.backgroundColor = UIColor.black
        webView.scrollView.bounces = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.isHidden = true // Hide until loaded
        
        view.addSubview(webView)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        print("ViewController: WebView setup completed")
    }
    
    private func startLoadingTimeout() {
        // Cancel any existing timeout
        loadingTimeout?.invalidate()
        
        // Start new timeout
        loadingTimeout = Timer.scheduledTimer(withTimeInterval: LOADING_TIMEOUT, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                print("ViewController: Loading timeout reached")
                self?.handleLoadingTimeout()
            }
        }
    }
    
    private func stopLoadingTimeout() {
        loadingTimeout?.invalidate()
        loadingTimeout = nil
    }
    
    private func handleLoadingTimeout() {
        print("ViewController: Handling loading timeout, trying next URL")
        webView.stopLoading()
        tryNextUrl()
    }
    
    private func loadWebApp() {
        print("ViewController: Starting to load web app")
        
        // Update status
        errorLabel.text = "Connecting to server..."
        
        // Reset URL index if retrying
        if currentUrlIndex >= urlsToTry.count {
            currentUrlIndex = 0
        }
        
        let urlString = urlsToTry[currentUrlIndex]
        
        guard let url = URL(string: urlString) else {
            showError("Invalid URL: \(urlString)")
            return
        }
        
        print("ViewController: Loading URL: \(urlString) (attempt \(currentUrlIndex + 1)/\(urlsToTry.count))")
        
        // Create request with timeout
        var request = URLRequest(url: url)
        request.timeoutInterval = LOADING_TIMEOUT
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        // Start timeout timer
        startLoadingTimeout()
        
        webView.load(request)
    }
    
    private func tryNextUrl() {
        stopLoadingTimeout()
        
        currentUrlIndex += 1
        if currentUrlIndex < urlsToTry.count {
            print("ViewController: Trying next URL...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.loadWebApp()
            }
        } else {
            showError("Failed to connect to any server.\nPlease check your internet connection.\n\nTap to retry")
        }
    }
    
    private func showError(_ message: String) {
        print("ViewController: Error - \(message)")
        
        stopLoadingTimeout()
        
        DispatchQueue.main.async {
            self.errorLabel.text = message
            self.webView.isHidden = true
            self.splashImageView.isHidden = false
            
            // Make error label tappable for retry
            self.errorLabel.isUserInteractionEnabled = true
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.retryLoading))
            self.errorLabel.addGestureRecognizer(tapGesture)
        }
    }
    
    private func hideLoadingAndShowWebView() {
        DispatchQueue.main.async {
            // Smooth transition from splash to web view
            UIView.transition(with: self.view, duration: 0.5, options: .transitionCrossDissolve, animations: {
                self.splashImageView.isHidden = true
                self.errorLabel.isHidden = true
                self.webView.isHidden = false
            }, completion: nil)
        }
    }
    
    @objc private func retryLoading() {
        print("ViewController: Retry requested")
        
        // Reset UI
        errorLabel.isUserInteractionEnabled = false
        errorLabel.gestureRecognizers?.removeAll()
        splashImageView.isHidden = false
        
        // Reset URL index to start from the beginning
        currentUrlIndex = 0
        loadWebApp()
    }
    
    // MARK: - WKNavigationDelegate
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("ViewController: Started loading")
        DispatchQueue.main.async {
            self.errorLabel.text = "Loading..."
            self.splashImageView.isHidden = false
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("ViewController: Finished loading successfully")
        stopLoadingTimeout()
        
        // Wait a moment to ensure content is rendered
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.hideLoadingAndShowWebView()
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("ViewController: Navigation failed with error: \(error.localizedDescription)")
        tryNextUrl()
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("ViewController: Provisional navigation failed with error: \(error.localizedDescription)")
        tryNextUrl()
    }
    
    // Handle SSL certificate errors for development
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        print("ViewController: Received authentication challenge")
        
        // For development, accept self-signed certificates
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            let credential = URLCredential(trust: challenge.protectionSpace.serverTrust!)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
    
    // MARK: - WKUIDelegate
    
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: "Silento", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completionHandler()
        })
        present(alert, animated: true)
    }
    
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: "Silento", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completionHandler(true)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            completionHandler(false)
        })
        present(alert, animated: true)
    }
    
    // Handle camera and microphone permissions
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        
        print("ViewController: Media permission requested for type: \(type.rawValue)")
        
        // Request iOS system permissions first
        switch type {
        case .camera:
            requestCameraPermission { granted in
                DispatchQueue.main.async {
                    decisionHandler(granted ? .grant : .deny)
                }
            }
        case .microphone:
            requestMicrophonePermission { granted in
                DispatchQueue.main.async {
                    decisionHandler(granted ? .grant : .deny)
                }
            }
        case .cameraAndMicrophone:
            requestCameraAndMicrophonePermission { granted in
                DispatchQueue.main.async {
                    decisionHandler(granted ? .grant : .deny)
                }
            }
        @unknown default:
            decisionHandler(.deny)
        }
    }
    
    private func requestCameraPermission(completion: @escaping (Bool) -> Void) {
        let currentStatus = AVCaptureDevice.authorizationStatus(for: .video)
        print("ViewController: Current camera permission status: \(currentStatus.rawValue)")
        
        switch currentStatus {
        case .authorized:
            print("ViewController: Camera already authorized")
            completion(true)
        case .notDetermined:
            print("ViewController: Requesting camera permission...")
            AVCaptureDevice.requestAccess(for: .video) { granted in
                print("ViewController: Camera permission result: \(granted)")
                completion(granted)
            }
        case .denied, .restricted:
            print("ViewController: Camera permission denied/restricted, showing settings alert")
            showPermissionAlert(for: "Camera") { _ in
                completion(false)
            }
        @unknown default:
            print("ViewController: Unknown camera permission status")
            completion(false)
        }
    }
    
    private func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        let currentStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        print("ViewController: Current microphone permission status: \(currentStatus.rawValue)")
        
        switch currentStatus {
        case .authorized:
            print("ViewController: Microphone already authorized")
            completion(true)
        case .notDetermined:
            print("ViewController: Requesting microphone permission...")
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                print("ViewController: Microphone permission result: \(granted)")
                completion(granted)
            }
        case .denied, .restricted:
            print("ViewController: Microphone permission denied/restricted, showing settings alert")
            showPermissionAlert(for: "Microphone") { _ in
                completion(false)
            }
        @unknown default:
            print("ViewController: Unknown microphone permission status")
            completion(false)
        }
    }
    
    private func requestCameraAndMicrophonePermission(completion: @escaping (Bool) -> Void) {
        requestCameraPermission { cameraGranted in
            if cameraGranted {
                self.requestMicrophonePermission { micGranted in
                    completion(micGranted)
                }
            } else {
                completion(false)
            }
        }
    }
    
    private func showPermissionAlert(for mediaType: String, completion: @escaping (UIAlertAction) -> Void) {
        let alert = UIAlertController(
            title: "\(mediaType) Access Required",
            message: "Silento needs access to your \(mediaType.lowercased()) to take photos and videos. Please enable access in Settings.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl)
            }
            completion(UIAlertAction(title: "Settings", style: .default, handler: nil))
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: completion))
        
        present(alert, animated: true)
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
} 