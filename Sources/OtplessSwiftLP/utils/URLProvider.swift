//
//  Utils.swift
//  OtplessSwiftLP
//
//  Created by Sparsh on 19/03/25.
//

import Foundation
import WebKit

func getLoadingURL(startUrl: String, loginUri: String, roomId: String) -> URL? {
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
    
    let queryItemLoginUri = URLQueryItem(name: "otpl_login_uri", value: loginUri)
    let queryItemWhatsApp = URLQueryItem(name: "otpl_instl_wa", value: DeviceInfoUtils.shared.hasWhatsApp ? "true" : "false")
    let queryItemRoomID = URLQueryItem(name: "otpless_connect_id", value: roomId)
    var type = "JSN"
    
    let queryItemType = URLQueryItem(name: "type", value: type)
    let queryItemPlatform = URLQueryItem(name: "otpl_platform", value: "iOS")
    let queryItemSDKType = URLQueryItem(name: "otpl_sdk_type", value: "lp")
    
    if urlComponents.queryItems != nil {
        urlComponents.queryItems?.append(contentsOf: [queryItemWhatsApp, queryItemLoginUri, queryItemType,queryItemRoomID, queryItemPlatform, queryItemSDKType])
    } else {
        urlComponents.queryItems = [queryItemWhatsApp, queryItemLoginUri,queryItemType, queryItemRoomID, queryItemPlatform, queryItemSDKType]
    }
    
    if let inid = inid {
        let queryItemInid = URLQueryItem(name: "inid", value: inid)
        urlComponents.queryItems?.append(queryItemInid)
    }
    
    if let tsid = tsid {
        let queryItemTsid = URLQueryItem(name: "tsid", value: tsid)
        urlComponents.queryItems?.append(queryItemTsid)
    }
    
    let queryItemCellularDataEnabled = URLQueryItem(name: "otpl_isCellularDataEnabled", value: NetworkMonitor.shared.isCellularNetworkEnabled.description)
    
    urlComponents.queryItems?.append(queryItemCellularDataEnabled)
    
    if !OtplessSwiftLP.shared.extras.isEmpty {
        var extras = OtplessSwiftLP.shared.extras  // Make a mutable copy
        var base64Params: String = ""

        if let phone = extras["phone"], !phone.isEmpty,
                  let countryCode = extras["countryCode"], !countryCode.isEmpty {
            // Overwrite the phone key with combined country code + phone
            extras["phone"] = "+\(countryCode)\(phone)"
        }
        base64Params = Utils.base64EncodedString(from: extras)
        urlComponents.queryItems?.append(URLQueryItem(name: "otpl_extras", value: base64Params))
    }
    
    return urlComponents.url
}

