//
//  NativeWebManagerExtension.swift
//  OtplessSDK
//
//  Created by Sparsh on 12/08/24.
//

import Foundation
import WebKit

extension NativeWebBridge {
    
    
    /// Key 7 - Open deeplink
    func openDeepLink(_ deeplink: String) {
        let urlWithOutDecoding = deeplink.removingPercentEncoding
        if let link = URL(string: (urlWithOutDecoding!.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))!) {
            UIApplication.shared.open(link, options: [:], completionHandler: nil)
        }
        //OtplessHelper.sendEvent(event: EventConstants.DEEPLINK_WEB)
    }
    
    
    /// Key 8 - Get AppInfo
    func getAppInfo() {
        var parametersToSend =  DeviceInfoUtils.shared.getAppInfo()
        parametersToSend["appSignature"] = DeviceInfoUtils.shared.appHash
        let jsonStr = Utils.convertDictionaryToString(parametersToSend)
        loadScript(function: "onAppInfoResult", message: jsonStr)
    }
    
     
    /// Key 15 - Send event
    func sendAuthEvents(response:[String:Any]) {
        // TODO
        OtplessEventManager.shared.ingestFromWeb(response ?? [:])
    }

    /// Key 42 - Perform SNA (Silent Network Auth)
    func performSilentAuth(withConnectionUrl url: URL?) {
        if url != nil {
            forceOpenURLOverMobileNetwork(
                url: url!,
                completion: { silentAuthResponse in
                    let jsonStr = Utils.convertDictionaryToString(silentAuthResponse)
                    self.loadScript(function: "onCellularNetworkResult", message: jsonStr)
                    sendEvent(event: .snaUrlResponse, extras: [
                        "response": jsonStr
                    ])
                }
            )
        } else {
            // handle case when unable to create URL from string
            self.loadErrorInScript(function: "onCellularNetworkResult", error: "url_parsing_fail", errorDescription: "Unable to parse url from string.")
            sendEvent(event: .snaUrlResponse, extras: [
                "response": ["error":"url_parsing_fail"]
            ])
        }
    }
    
    /// Key 69 - Response Callback
    func parseScriptResponse(response:[String:Any]){
        OtplessSwiftLP.shared.parseResponse(response: response ?? [:])
    }
    
}


extension NativeWebBridge {
    private func loadScript(function: String, message: String) {
        let tempScript = function + "(" + message + ")"
        let script = tempScript.replacingOccurrences(of: "\n", with: "")
        callJs(webview: webView, script: script)
    }
    
    private func callJs(webview: WKWebView, script: String) {
       // OtplessLogger.log(string: script, type: "JS Script")
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
        let error = Utils.createErrorDictionary(error: error, errorDescription: errorDescription)
        loadScript(function: function, message: Utils.convertDictionaryToString(error))
    }
    
    private func loadUnsupportedIOSVersionErrorInScript(function: String, supportedFrom: String, feature: String) {
        let unsupportedIOSVersionError = Utils.createUnsupportedIOSVersionError(supportedFrom: supportedFrom, forFeature: feature)
        loadScript(function: function, message: Utils.convertDictionaryToString(unsupportedIOSVersionError))
    }
}
