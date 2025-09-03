//
//  OtplessView.swift
//  OtplessSDK
//
//  Created by Sparsh on 28/03/24.
//
import UIKit
import WebKit
import Foundation

class OtplessView: UIView {
    
    let JAVASCRIPT_OBJ = "window.webkit.messageHandlers"
    let messageName = "webNativeAssist"
    var mWebView: WKWebView! = nil
    var bridge: NativeWebBridge = NativeWebBridge()
    var finalDeeplinkUri: URL?
    var startUri = ""
    
    init(webURL: String) {
        super.init(frame: CGRectZero)
        startUri = webURL
        translatesAutoresizingMaskIntoConstraints = false
        setupView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }
    
    private func setupView() {
        initializeWebView()
        bridge.delegate = self
        clearWebViewCache()
        prepareUrlLoadWebview()
        //OtplessHelper.sendEvent(event: "sdk_screen_loaded")
    }
    
    private func initializeWebView() {
        mWebView = WKWebView(frame: bounds, configuration: getWKWebViewConfiguration())
        mWebView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mWebView.backgroundColor = UIColor.clear
        mWebView.isOpaque = false
        mWebView.navigationDelegate = self
        setInspectable()
        // OtplessHelper.sendEvent(event: EventConstants.WEBVIEW_ADDED)
        addSubview(mWebView)
    }
    
    
    
    private func setInspectable() {
        if #available(iOS 16.4, *) {
            if (OtplessSwiftLP.shared.webviewInspectable) {
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
        
        // OtplessHelper.sendEvent(event: EventConstants.JS_INJECT)
        
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
    
    func prepareUrlLoadWebview(){
        self.mWebView.evaluateJavaScript("navigator.userAgent") { [weak self] (result, error) in
            guard let self = self else { return }
            let request = URLRequest(url: URL(string: startUri)!)
            // OtplessLogger.log(string: request.url?.absoluteString ?? "Unable to get URL", type: "WebView URL")
            mWebView.load(request)
            // OtplessHelper.sendEvent(event: EventConstants.LOAD_URL)
        }
    }
        
}

extension OtplessView: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == self.messageName {
            bridge.parseScriptMessage(message: message, webview: self.mWebView)
        }
    }
}

extension OtplessView: BridgeDelegate {
    
    func dismissView() {
        self.mWebView.isHidden = true
        self.removeFromSuperview()
      //  OtplessHelper.sendEvent(event: "sdk_screen_dismissed")
    }
}

extension OtplessView: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
//        if !isHeadless {
//            loader.hide()
//        }

        guard let urlError = error as? URLError else {
            // Handle other types of errors if needed
            var errorMessage = ErrorMessages.RequestLoadError
            var errorCode = ErrorCodes.EXCEPTION_EC
            var errorType = ErrorTypes.NETWORK
            let unknownErrorJson = ["errorType":errorType,"errorCode":errorCode,"errorMessage":errorMessage] as [String : Any]
            OtplessSwiftLP.shared.generateErrorResult(errorDict: unknownErrorJson)
            return
        }
        
        let errorDict = [
            "errorCode": String(urlError.code.rawValue),
            "description": error.localizedDescription,
            "message": getMessage(fromErrorCode: urlError.code)
        ]
     
        //OtplessHelper.sendEvent(event: EventConstants.WEBVIEW_URL_LOAD_FAIL, extras: errorDict)
        
        if [
            .notConnectedToInternet,
            .cannotFindHost,
            .cannotConnectToHost,
            .networkConnectionLost,
            .timedOut,
            .unsupportedURL
        ].contains(urlError.code)  {
            var errorMessage = getMessage(fromErrorCode: urlError.code)
            var errorCode = ErrorCodes.EXCEPTION_EC
            var errorType = ErrorTypes.NETWORK
            let unknownErrorJson = ["errorType":errorType,"errorCode":errorCode,"errorMessage":errorMessage] as [String : Any]
            OtplessSwiftLP.shared.generateErrorResult(errorDict: unknownErrorJson)
//            Otpless.sharedInstance.eventDelegate?.onEvent(
//                eventCallback: OtplessEventResponse(
//                    responseString: error.localizedDescription,
//                    responseData: nil,
//                    eventCode: .networkFailure
//                )
//            )
            
//                if let request = headlessRequest,
//                   !request.isChannelEmpty()
//                {
//                    Otpless.sharedInstance.headlessDelegate?.onHeadlessResponse(
//                        response: HeadlessResponse(
//                            responseType: "INTERNET_ERR",
//                            responseData: [
//                                "errorMessage": "Internet Error",
//                                "details": [
//                                    "errorCode": String(urlError.errorCode),
//                                    "description": urlError.localizedDescription.description
//                                ]
//                            ],
//                            statusCode: 5002
//                        )
//                    )
//                }
                
               // stopOtpless(dueToNoInternet: true)
            
            //OtplessLogger.log(string: "No internet connection", type: "No internet connection.")
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
//        if !isHeadless {
//            loader.hide()
//        }
//        OtplessHelper.sendEvent(event: EventConstants.WEBVIEW_URL_LOAD_SUCCESS)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
//        if !isHeadless {
//            loader.hide()
//        }
     
        guard let urlError = error as? URLError else {
            // Handle other types of errors if needed
            var errorMessage = ErrorMessages.RequestLoadError
            var errorCode = ErrorCodes.EXCEPTION_EC
            var errorType = ErrorTypes.NETWORK
            let unknownErrorJson = ["errorType":errorType,"errorCode":errorCode,"errorMessage":errorMessage] as [String : Any]
            OtplessSwiftLP.shared.generateErrorResult(errorDict: unknownErrorJson)
            return
        }
        
        let errorDict = [
            "errorCode": String(urlError.code.rawValue),
            "description": error.localizedDescription,
            "message": getMessage(fromErrorCode: urlError.code)
        ]
        
//        OtplessHelper.sendEvent(event: EventConstants.WEBVIEW_URL_LOAD_FAIL, extras: errorDict)
        
        if [
            .notConnectedToInternet,
            .cannotFindHost,
            .cannotConnectToHost,
            .networkConnectionLost,
            .timedOut,
            .unsupportedURL
        ].contains(urlError.code) {
            
            var errorMessage =  getMessage(fromErrorCode: urlError.code)
            var errorCode = ErrorCodes.EXCEPTION_EC
            var errorType = ErrorTypes.NETWORK
            let unknownErrorJson = ["errorType":errorType,"errorCode":errorCode,"errorMessage":errorMessage] as [String : Any]
            OtplessSwiftLP.shared.generateErrorResult(errorDict: unknownErrorJson)
//            Otpless.sharedInstance.eventDelegate?.onEvent(
//                eventCallback: OtplessEventResponse(
//                    responseString: error.localizedDescription,
//                    responseData: nil,
//                    eventCode: .networkFailure
//                )
//            )
            
//            if isHeadless {
//                if let request = headlessRequest,
//                   !request.isChannelEmpty()
//                {
//                    Otpless.sharedInstance.headlessDelegate?.onHeadlessResponse(
//                        response: HeadlessResponse(
//                            responseType: "INTERNET_ERR",
//                            responseData: [
//                                "errorMessage": "Internet Error",
//                                "details": [
//                                    "errorCode": String(urlError.errorCode),
//                                    "description": urlError.localizedDescription.description
//                                ]
//                            ],
//                            statusCode: 5002
//                        )
//                    )
//                }
//                
//                stopOtpless(dueToNoInternet: true)
//            } else {
//                loader.showWithErrorAndRetry(errorText: "Connection error" + " : " + error.localizedDescription.description)
//            }
//            
            //OtplessLogger.log(string: "No internet connection", type: "No internet connection.")
        }
    }

    private func getMessage(fromErrorCode code: URLError.Code) -> String {
        switch code {
        case .unknown:
            return "An unknown error occurred."
        case .cancelled:
            return "The request was cancelled."
        case .badURL:
            return "The URL is malformed."
        case .timedOut:
            return "The request timed out."
        case .unsupportedURL:
            return "The URL is not supported."
        case .cannotFindHost:
            return "The host could not be found."
        case .cannotConnectToHost:
            return "Cannot connect to the host."
        case .networkConnectionLost:
            return "The network connection was lost."
        case .dnsLookupFailed:
            return "The DNS lookup failed."
        case .httpTooManyRedirects:
            return "Too many HTTP redirects occurred."
        case .resourceUnavailable:
            return "The requested resource is unavailable."
        case .notConnectedToInternet:
            return "It appears you are not connected to the Internet."
        case .redirectToNonExistentLocation:
            return "Redirected to a non-existent location."
        case .badServerResponse:
            return "Received an invalid response from the server."
        case .userCancelledAuthentication:
            return "The user cancelled authentication."
        case .userAuthenticationRequired:
            return "Authentication is required to proceed."
        case .zeroByteResource:
            return "The resource is empty."
        case .cannotDecodeRawData:
            return "Cannot decode raw data."
        case .cannotDecodeContentData:
            return "Cannot decode content data."
        case .cannotParseResponse:
            return "Cannot parse the server response."
        case .appTransportSecurityRequiresSecureConnection:
            return "App Transport Security requires a secure connection."
        case .fileDoesNotExist:
            return "The specified file does not exist."
        case .fileIsDirectory:
            return "The specified file is a directory."
        case .noPermissionsToReadFile:
            return "No permission to read the file."
        case .dataLengthExceedsMaximum:
            return "The data length exceeds the maximum allowed."
        case .secureConnectionFailed:
            return "A secure connection could not be established."
        case .serverCertificateHasBadDate:
            return "The server certificate has an invalid date."
        case .serverCertificateUntrusted:
            return "The server certificate is untrusted."
        case .serverCertificateHasUnknownRoot:
            return "The server certificate has an unknown root."
        case .serverCertificateNotYetValid:
            return "The server certificate is not yet valid."
        case .clientCertificateRejected:
            return "The client certificate was rejected."
        case .clientCertificateRequired:
            return "A client certificate is required."
        case .cannotLoadFromNetwork:
            return "Cannot load data from the network."
        case .cannotCreateFile:
            return "Cannot create the specified file."
        case .cannotOpenFile:
            return "Cannot open the specified file."
        case .cannotCloseFile:
            return "Cannot close the specified file."
        case .cannotWriteToFile:
            return "Cannot write to the specified file."
        case .cannotRemoveFile:
            return "Cannot remove the specified file."
        case .cannotMoveFile:
            return "Cannot move the specified file."
        case .downloadDecodingFailedMidStream:
            return "Download decoding failed mid-stream."
        case .downloadDecodingFailedToComplete:
            return "Download decoding failed to complete."
        case .internationalRoamingOff:
            return "International roaming is turned off."
        case .callIsActive:
            return "A call is currently active."
        case .dataNotAllowed:
            return "Data usage is not allowed."
        case .requestBodyStreamExhausted:
            return "The request body stream is exhausted."
        case .backgroundSessionRequiresSharedContainer:
            return "A background session requires a shared container."
        case .backgroundSessionInUseByAnotherProcess:
            return "The background session is in use by another process."
        case .backgroundSessionWasDisconnected:
            return "The background session was disconnected."
        default:
            return "Something Went Wrong!."
        }
    }

}

extension OtplessView: UIScrollViewDelegate {
    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        scrollView.pinchGestureRecognizer?.isEnabled = false
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return nil
    }
}


