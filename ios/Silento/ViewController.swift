import UIKit
import WebKit

class ViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    
    private var webView: WKWebView!
    private var activityIndicator: UIActivityIndicatorView!
    private var errorLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set background color to prevent black screen
        view.backgroundColor = UIColor.systemBackground
        
        print("ViewController: viewDidLoad started")
        setupErrorLabel()
        setupWebView()
        setupActivityIndicator()
        
        // Delay loading to ensure everything is set up
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.loadWebApp()
        }
    }
    
    private func setupErrorLabel() {
        errorLabel = UILabel()
        errorLabel.text = "Loading Silento..."
        errorLabel.textColor = UIColor.label
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0
        errorLabel.font = UIFont.systemFont(ofSize: 16)
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(errorLabel)
        
        NSLayoutConstraint.activate([
            errorLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            errorLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            errorLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
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
        webView.backgroundColor = UIColor.systemBackground
        webView.isOpaque = false
        webView.scrollView.backgroundColor = UIColor.systemBackground
        webView.scrollView.bounces = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.isHidden = true // Hide until loaded
        
        view.addSubview(webView)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        print("ViewController: WebView setup completed")
    }
    
    private func setupActivityIndicator() {
        activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.color = UIColor.systemBlue
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        
        view.addSubview(activityIndicator)
        
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -50)
        ])
        
        print("ViewController: Activity indicator setup completed")
    }
    
    private func loadWebApp() {
        print("ViewController: Starting to load web app")
        
        // Update status
        errorLabel.text = "Connecting to server..."
        
        // Load from deployed server
        let urlString = "https://silento-backend.onrender.com"
        
        guard let url = URL(string: urlString) else {
            showError("Invalid URL: \(urlString)")
            return
        }
        
        print("ViewController: Loading URL: \(urlString)")
        
        let request = URLRequest(url: url)
        webView.load(request)
        activityIndicator.startAnimating()
    }
    
    private func showError(_ message: String) {
        print("ViewController: Error - \(message)")
        
        DispatchQueue.main.async {
            self.errorLabel.text = message
            self.activityIndicator.stopAnimating()
            self.webView.isHidden = true
            
            // Add retry button
            let retryButton = UIButton(type: .system)
            retryButton.setTitle("Retry", for: .normal)
            retryButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
            retryButton.backgroundColor = UIColor.systemBlue
            retryButton.setTitleColor(.white, for: .normal)
            retryButton.layer.cornerRadius = 8
            retryButton.translatesAutoresizingMaskIntoConstraints = false
            retryButton.addTarget(self, action: #selector(self.retryLoading), for: .touchUpInside)
            
            self.view.addSubview(retryButton)
            
            NSLayoutConstraint.activate([
                retryButton.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
                retryButton.topAnchor.constraint(equalTo: self.errorLabel.bottomAnchor, constant: 20),
                retryButton.widthAnchor.constraint(equalToConstant: 120),
                retryButton.heightAnchor.constraint(equalToConstant: 44)
            ])
        }
    }
    
    @objc private func retryLoading() {
        // Remove any existing retry buttons
        view.subviews.forEach { subview in
            if let button = subview as? UIButton, button.titleLabel?.text == "Retry" {
                button.removeFromSuperview()
            }
        }
        
        loadWebApp()
    }
    
    // MARK: - WKNavigationDelegate
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("ViewController: Started loading")
        activityIndicator.startAnimating()
        errorLabel.text = "Loading..."
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("ViewController: Finished loading successfully")
        activityIndicator.stopAnimating()
        errorLabel.isHidden = true
        webView.isHidden = false
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("ViewController: Navigation failed with error: \(error.localizedDescription)")
        activityIndicator.stopAnimating()
        showError("Failed to load: \(error.localizedDescription)")
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("ViewController: Provisional navigation failed with error: \(error.localizedDescription)")
        activityIndicator.stopAnimating()
        showError("Failed to connect to server. Please check your internet connection.\n\nError: \(error.localizedDescription)")
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
        decisionHandler(.grant)
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
} 