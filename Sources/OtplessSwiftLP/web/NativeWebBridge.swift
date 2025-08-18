//
//  NativeWebBridge.swift
//  OTPless
//
//  Created by Anubhav Mathur on 15/05/23.
//

import Foundation
import UIKit
import WebKit
import SafariServices


@objc class NativeWebBridge: NSObject {
    internal var webView: WKWebView! = nil
    internal var otplessSFSafariVC: SFSafariViewController?
    
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
            
            switch nativeKey {
            case 7:
                // open deeplink
                if let url = dataDict?["deeplink"] as? String {
                    self.openDeepLink(url)
                }
                break
            case 8:
                self.sendAppInfo()
                break
            case 15:
                // todo send event
                break
            case 42:
                // perform silent auth
                let url = dataDict?["url"] as? String ?? ""
                let connectionUrl = URL(string: url)
                self.performSilentAuth(withConnectionUrl: connectionUrl)
                break
            default:
                return
            }
        }
    }
}

extension NativeWebBridge: SFSafariViewControllerDelegate, UIAdaptivePresentationControllerDelegate {
    
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        otplessSFSafariVC = nil
      }
    
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        otplessSFSafariVC = nil
    }
    
    func dismissOtplessSFSafariVC() {
        if otplessSFSafariVC != nil {
            otplessSFSafariVC?.dismiss(animated: true) { [weak self] in
                self?.otplessSFSafariVC = nil
            }
        }
    }
}

