//
//  NativeWebManagerExtension.swift
//  OtplessSDK
//
//  Created by Sparsh on 12/08/24.
//

import Foundation
import WebKit
import SafariServices

internal extension NativeWebBridge {
    
    /// Key 7 - Open deeplink
    func openDeepLink(_ deeplink: String) {
        let urlWithOutDecoding = deeplink.removingPercentEncoding
        var params: [String: String] = [:]
        if let link = URL(string: (urlWithOutDecoding!.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))!) {
            
            var channel = ""
            if #available(iOS 16.0, *) {
                channel = link.scheme ?? "" + "://" + (link.host() ?? "")
            } else {
                channel = link.scheme ?? "" + "://" + (link.host ?? "")
            }
            params["channel"] = channel
            
            if link.absoluteString.hasPrefix("http") || link.absoluteString.hasPrefix("https") {
                if otplessSFSafariVC == nil {
                    otplessSFSafariVC = SFSafariViewController(url: link)
                }
                // Do not change the order of code lines
                if let safariVC = otplessSFSafariVC {
                    safariVC.modalPresentationStyle = .formSheet
                    safariVC.delegate = self
                    safariVC.presentationController?.delegate = self
                    Otpless.sharedInstance.merchantVC?.present(safariVC, animated: true)
                } else {
                    UIApplication.shared.open(link, options: [:], completionHandler: nil)
                }
            } else {
                UIApplication.shared.open(link, options: [:], completionHandler: nil)
            }
        }
        // todo send event
    }
    
    
    /// Key 8 - Get AppInfo
    func sendAppInfo() {
        DLog("Sending app info")
        var parametersToSend =  DeviceInfoUtils.shared.getAppInfo()
        parametersToSend["appSignature"] = DeviceInfoUtils.shared.appHash
        let jsonStr = Utils.convertDictionaryToString(parametersToSend)
        loadScript(function: "onAppInfoResult", message: jsonStr)
    }
    
    /// Key 42 - Perform SNA (Silent Network Auth)
    func performSilentAuth(withConnectionUrl url: URL?) {
        if url != nil {
            forceOpenURLOverMobileNetwork(
                url: url!,
                completion: { silentAuthResponse in
                    let jsonStr = Utils.convertDictionaryToString(silentAuthResponse)
                    self.loadScript(function: "onCellularNetworkResult", message: jsonStr)
                    // todo send event
                }
            )
        } else {
            // handle case when unable to create URL from string
            self.loadErrorInScript(function: "onCellularNetworkResult", error: "url_parsing_fail", errorDescription: "Unable to parse url from string.")
        }
    }
    
}


extension NativeWebBridge {
    private func loadScript(function: String, message: String) {
        let tempScript = function + "(" + message + ")"
        let script = tempScript.replacingOccurrences(of: "\n", with: "")
        callJs(webview: webView, script: script)
    }
    
    private func callJs(webview: WKWebView, script: String) {
        DispatchQueue.main.async {
            webview.evaluateJavaScript(script, completionHandler: nil)
        }
    }
    
    private func forceOpenURLOverMobileNetwork(url: URL, completion: @escaping ([String: Any]) -> Void) {
        if #available(iOS 12.0, *) {
            let cellularConnectionManager = CellularConnectionManager()
            cellularConnectionManager.open(url: url, operators: nil, completion: completion)
        } else {
            let errorJson = Utils.createUnsupportedIOSVersionError(supportedFrom: "iOS 12", forFeature: "Silent Network Authentication")
            completion(errorJson)
        }
    }
    
    @available(iOS 13, *)
    private func getWindowScene() -> UIWindowScene? {
        return webView.window?.windowScene
    }
}

/// Handles exceptions and errors and send them to web
extension NativeWebBridge {
    
    private func loadErrorInScript(function: String, error: String, errorDescription: String) {
        let error = Utils.createErrorDictionary(errorCode: error, errorMessage: errorDescription)
        loadScript(function: function, message: Utils.convertDictionaryToString(error))
    }
    
    private func loadUnsupportedIOSVersionErrorInScript(function: String, supportedFrom: String, feature: String) {
        let unsupportedIOSVersionError = Utils.createUnsupportedIOSVersionError(supportedFrom: supportedFrom, forFeature: feature)
        loadScript(function: function, message: Utils.convertDictionaryToString(unsupportedIOSVersionError))
    }
}
