//
//  NativeWebBridge.swift
//  OTPless
//
//  Created by Anubhav Mathur on 15/05/23.
//

import Foundation
import UIKit
import WebKit


class NativeWebBridge {
    internal var webView: WKWebView! = nil
    public weak var delegate: BridgeDelegate?
    
    func parseScriptMessage(message: WKScriptMessage, webview : WKWebView){
        webView = webview
        
        if let jsonStringFromWeb = message.body as? String {
            let dataDict = Utils.convertToDictionary(text: jsonStringFromWeb)
            var nativeKey = 0
            if let key = dataDict?["key"] as? String {
                nativeKey = Int(key)!
            } else {
                if let key = dataDict?["key"] as? Int {
                    nativeKey = key
                }
            }
            sendEvent(event: .webview_request_recieved, extras: dataDict ?? [:])
            switch nativeKey {
            case 7:
                // open deeplink
                if let url = dataDict?["deeplink"] as? String {
                    self.openDeepLink(url)
                }
                break
            case 8:
                // get app info
                self.getAppInfo()
                break
            case 15:
                // send event
                sendAuthEvents(response: dataDict ?? [:])
                break
            case 42:
                // perform silent auth
                let url = dataDict?["url"] as? String ?? ""
                let connectionUrl = URL(string: url)
                self.performSilentAuth(withConnectionUrl: connectionUrl)
                break
            case 69:
                self.parseScriptResponse(response: dataDict ?? [:])
                break
            default:
                return
            }
        }
    }
}


extension NativeWebBridge {
    func setHeadlessRequest(webview: WKWebView) {
        if self.webView == nil {
            self.webView = webview
        }
    }
}

public protocol BridgeDelegate: AnyObject {
    func dismissView()
}
