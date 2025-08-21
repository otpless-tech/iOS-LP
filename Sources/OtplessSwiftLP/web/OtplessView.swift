//
//  OtplessView.swift
//  OtplessSDK
//
//  Created by Sparsh on 28/03/24.
//
import UIKit
import WebKit

class OtplessView: UIView {
    
    let JAVASCRIPT_OBJ = "window.webkit.messageHandlers"
    let messageName = "webNativeAssist"
    var mWebView: WKWebView! = nil
    var bridge: NativeWebBridge = NativeWebBridge()
    var loadingUri = ""
    var finalDeeplinkUri: URL?
    
    var networkUIHidden: Bool = false
    var hideActivityIndicator: Bool = false
    
    private var headlessViewHeight: CGFloat = 0.1
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        setupView()
    }
    
    init(loadingUri: String) {
        super.init(frame: .zero)
        self.loadingUri = loadingUri
        translatesAutoresizingMaskIntoConstraints = false
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        translatesAutoresizingMaskIntoConstraints = false
        setupView()
    }
    
    
    private func setupView() {
        initializeWebView()
        clearWebViewCache()
        prepareUrlLoadWebview(startUrl: loadingUri)
//        OtplessHelper.sendEvent(event: "sdk_screen_loaded")
        // todo send event
    }
    
    private func initializeWebView() {
        mWebView = WKWebView(frame: bounds, configuration: getWKWebViewConfiguration())
        mWebView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mWebView.backgroundColor = UIColor.clear
        mWebView.isOpaque = false
        mWebView.navigationDelegate = self
        
        setupScrollView()
        setInspectable()
//        OtplessHelper.sendEvent(event: EventConstants.WEBVIEW_ADDED)
        // todo send event
        addSubview(mWebView)
    }
    
    private func setupScrollView() {
        mWebView.scrollView.delegate = self
        mWebView.scrollView.minimumZoomScale = 0.0
        mWebView.scrollView.maximumZoomScale = 0.0
    }
    
    private func setInspectable() {
        if #available(iOS 16.4, *) {
            if (Otpless.sharedInstance.webviewInspectable) {
                self.mWebView.isInspectable = true
            }
        }
    }
    
    
    public func getWKWebViewConfiguration() -> WKWebViewConfiguration {
        let contentController = WKUserContentController()
        let scriptSource1 = "javascript: window.androidObj = function AndroidClass() { };"
        let scriptSource = "javascript: " +
        "window.androidObj.webNativeAssist = function(message) { " + JAVASCRIPT_OBJ + ".webNativeAssist.postMessage(message) }"
        let zoomDisableJs: String = "var meta = document.createElement('meta');" +
        "meta.name = 'viewport';" +
        "meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';" +
        "var head = document.getElementsByTagName('head')[0];" +
        "head.appendChild(meta);"
        let script1: WKUserScript = WKUserScript(source: scriptSource1, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        let script: WKUserScript = WKUserScript(source: scriptSource, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        let disableZoomScript = WKUserScript(source: zoomDisableJs, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        contentController.addUserScript(script1)
        contentController.addUserScript(script)
        contentController.addUserScript(disableZoomScript)
        contentController.add(self, name: messageName)
        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        
        // todo send event
        
        return config
    }
    
    func clearWebViewCache() {
        do {
            if #available(iOS 9.0, *) {
                let websiteDataTypes = NSSet(array: [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache])
                let date = Date(timeIntervalSince1970: 0)
                WKWebsiteDataStore.default().removeData(ofTypes: websiteDataTypes as! Set<String>, modifiedSince: date, completionHandler: {})
            } else {
                // Clear cache for earlier versions of iOS
                let libraryPath = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first!
                let cookiesFolderPath = "\(libraryPath)/Cookies"
                do {
                    try FileManager.default.removeItem(atPath: cookiesFolderPath)
                } catch {
                    
                }
            }
        }
    }
    
    func prepareUrlLoadWebview(startUrl: String){
        self.mWebView.evaluateJavaScript("navigator.userAgent") { [weak self] (result, error) in
            guard let self = self else { return }
            
            if let currentUserAgent = result as? String {
                // Append the custom User-Agent
                let customUserAgent = "\(currentUserAgent) otplesssdk"
                Otpless.sharedInstance.setUserAgent(customUserAgent)
                
                // Set the modified User-Agent
                mWebView.customUserAgent = customUserAgent
                let inid = ResourceManager.shared.inId
                let tsid = ResourceManager.shared.tsId
                
                // Load a webpage
                var urlComponents = URLComponents(string: startUrl)!
                if let bundleIdentifier = Bundle.main.bundleIdentifier {
                    let queryItem = URLQueryItem(name: "package", value: bundleIdentifier)
                    
                    if urlComponents.queryItems != nil {
                        urlComponents.queryItems?.append(queryItem)
                    } else {
                        urlComponents.queryItems = [queryItem]
                    }
                }
                
                var loginUri = "otpless." + Otpless.sharedInstance.getAppId().lowercased() + "://otpless"
                
                if let loginUriFromClient = Otpless.sharedInstance.getLoginUri(),
                   !loginUriFromClient.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                {
                    loginUri = loginUriFromClient.lowercased()
                }
                
                let queryItemLoginUri = URLQueryItem(name: "login_uri", value: loginUri)
                
                let queryItemWhatsApp = URLQueryItem(name: "hasWhatsapp", value: DeviceInfoUtils.shared.hasWhatsApp ? "true" : "false" )
                let queryItemOtpless = URLQueryItem(name: "hasOtplessApp", value: DeviceInfoUtils.shared.hasOTPLESSInstalled ? "true" : "false" )
                let queryItemGmail = URLQueryItem(name: "hasGmailApp", value: DeviceInfoUtils.shared.hasGmailInstalled ? "true" : "false" )
                let querySilentAuth = URLQueryItem(name: "isSilentAuthSupported", value: "true")
                
                if urlComponents.queryItems != nil {
                    urlComponents.queryItems?.append(queryItemWhatsApp)
                    urlComponents.queryItems?.append(queryItemOtpless)
                    urlComponents.queryItems?.append(queryItemGmail)
                    urlComponents.queryItems?.append(querySilentAuth)
                    urlComponents.queryItems?.append(queryItemLoginUri)
                } else {
                    urlComponents.queryItems = [queryItemWhatsApp, queryItemOtpless, queryItemGmail, querySilentAuth, queryItemLoginUri]
                }
                
                
                if inid != nil {
                    let queryItemInid = URLQueryItem(name: "inid", value: inid)
                    urlComponents.queryItems?.append(queryItemInid)
                }
                
                if tsid != nil {
                    let queryItemTsid = URLQueryItem(name: "tsid", value: tsid)
                    urlComponents.queryItems?.append(queryItemTsid)
                }
                
                if #available(iOS 16, *) {
                    let queryWebAuthn = URLQueryItem(name: "isWebAuthnSupported", value: "true")
                    urlComponents.queryItems?.append(queryWebAuthn)
                }
                

                if let updatedURL = urlComponents.url {
                    let request = URLRequest(url: updatedURL)
//                    OtplessLogger.log(string: request.url?.absoluteString ?? "Unable to get URL", type: "WebView URL")
                    //todo add logging
                    mWebView.load(request)
//                    OtplessHelper.sendEvent(event: EventConstants.LOAD_URL)
                    //todo send event
                }
            }
        }
    }
    
    public func onDeeplinkRecieved(deeplink: URL){
        let deepLinkURI = deeplink.absoluteString
        
        bridge.dismissOtplessSFSafariVC()
        
        // Parse existing URL
        if (self.mWebView.url != nil) {
            var components = URLComponents(url: self.mWebView.url!, resolvingAgainstBaseURL: true)
            // Parse deep link URI
            if let deepLinkURL = URL(string: deepLinkURI),
               let deepLinkComponents = URLComponents(url: deepLinkURL, resolvingAgainstBaseURL: true),
               let queryItems = deepLinkComponents.queryItems {
                
                // Append query items to existing URL
                if components?.queryItems == nil {
                    components?.queryItems = queryItems
                } else {
                    components?.queryItems?.append(contentsOf: queryItems)
                }
            }
            
            // Get the final URL with the appended query items
            if let finalURL = components?.url {
                self.finalDeeplinkUri = finalURL
                let request = URLRequest(url: finalURL)
                self.mWebView.load(request)
            }
        }
    }
    
    func stopOtpless(dueToNoInternet: Bool) {
        if !dueToNoInternet {
//            OtplessHelper.sendEvent(event: "merchant_abort")
            // todo send event
        }
        removeFromSuperview()
    }
    
    
    func setLoginPageAttributes(networkUIHidden: Bool, hideActivityIndicator: Bool, initialParams: [String: Any]?) {
        self.networkUIHidden = networkUIHidden
        self.hideActivityIndicator = hideActivityIndicator
    }
    
    
    func setConstraints(_ constraints: [NSLayoutConstraint]) {
        NSLayoutConstraint.activate(constraints)
    }
    
    func setHeight(forHeightPercent heightPercent: Int) {
        if heightPercent < 0 || heightPercent > 100 {
            self.headlessViewHeight = UIScreen.main.bounds.height
        } else {
            self.headlessViewHeight = (CGFloat(heightPercent) * UIScreen.main.bounds.height) / 100
        }
        
        self.constraints.forEach { (constraint) in
            if constraint.firstAttribute == .height {
                constraint.constant = self.headlessViewHeight
            }
        }
    }
    
    func getViewHeight() -> CGFloat {
        return self.headlessViewHeight
    }
}
