//
//  Utils.swift
//  OtplessSwiftConnect
//
//  Created by Sparsh on 19/03/25.
//

import Foundation
import WebKit

func getLoadingURL(startUrl: String, isHeadless: Bool, loginUri: String, roomId: String) -> URL? {
    let inid = DeviceInfoUtils.shared.getInstallationId()
    let tsid = DeviceInfoUtils.shared.getTrackingSessionId()
    
    var urlComponents = URLComponents(string: startUrl)!
    if let bundleIdentifier = Bundle.main.bundleIdentifier {
        let queryItem = URLQueryItem(name: "packageName", value: bundleIdentifier)
        
        if urlComponents.queryItems != nil {
            urlComponents.queryItems?.append(queryItem)
        } else {
            urlComponents.queryItems = [queryItem]
        }
    }
    
    let queryItemLoginUri = URLQueryItem(name: "login_uri", value: loginUri)
    let queryItemWhatsApp = URLQueryItem(name: "hasWhatsapp", value: DeviceInfoUtils.shared.hasWhatsApp ? "true" : "false")
    let queryItemOtpless = URLQueryItem(name: "hasOtplessApp", value: DeviceInfoUtils.shared.hasOTPLESSInstalled ? "true" : "false")
    let queryItemGmail = URLQueryItem(name: "hasGmailApp", value: DeviceInfoUtils.shared.hasGmailInstalled ? "true" : "false")
    let querySilentAuth = URLQueryItem(name: "isSilentAuthSupported", value: "true")
    let queryItemRoomID = URLQueryItem(name: "otpless_connect_id", value: roomId)
    
    if urlComponents.queryItems != nil {
        urlComponents.queryItems?.append(contentsOf: [queryItemWhatsApp, queryItemOtpless, queryItemGmail, querySilentAuth, queryItemLoginUri, queryItemRoomID])
    } else {
        urlComponents.queryItems = [queryItemWhatsApp, queryItemOtpless, queryItemGmail, querySilentAuth, queryItemLoginUri, queryItemRoomID]
    }
    
    if let inid = inid {
        let queryItemInid = URLQueryItem(name: "inid", value: inid)
        urlComponents.queryItems?.append(queryItemInid)
    }
    
    if let tsid = tsid {
        let queryItemTsid = URLQueryItem(name: "tsid", value: tsid)
        urlComponents.queryItems?.append(queryItemTsid)
    }
    
    return urlComponents.url
}

