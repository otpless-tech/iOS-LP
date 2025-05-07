//
//  EventConstants.swift
//  OtplessSwiftLP
//
//  Created by Sparsh on 05/05/25.
//

import Foundation
import Network
import UIKit

private var deviceInfoString: String = ""

func sendEvent(event: EventConstants, extras: [String: Any] = [:]) {
    sendEvent(event: event.rawValue, extras: extras)
}

func sendEvent(event: String, extras: [String: Any] = [:]){
    do {
        var params = [String: String]()
        params["event_name"] = event
        params["platform"] = "iOS-LP"
        params["sdk_version"] = "1.0.8"
        params["mid"] = OtplessSwiftLP.shared.appId
        params["event_timestamp"] = Utils.formatCurrentTimeToDateString()
        
        var newEventParams = [String: Any]()
        for (key, value) in extras {
            newEventParams[key] = value
        }
        
        params["tsid"] = DeviceInfoUtils.shared.getTrackingSessionId() ?? ""
        params["inid"] = DeviceInfoUtils.shared.getInstallationId() ?? ""
        params["event_id"] = String(OtplessSwiftLP.shared.getAndIncrementEventCounter())
        
        var eventParams = extras
        eventParams["device_info"] = getDeviceInfoString()
        
        if let eventParamsData = try? JSONSerialization.data(withJSONObject: newEventParams, options: []),
           let eventParamsString = String(data: eventParamsData, encoding: .utf8) {
            params["event_params"] = eventParamsString
        }
        
        fetchDataWithGET(
            apiRoute: "https://d33ftqsb9ygkos.cloudfront.net",
            params: params
        )
    }
    catch {
        
    }
}

func getDeviceInfoString() -> String {
    if !deviceInfoString.isEmpty {
        return deviceInfoString
    }
    
    let device = UIDevice.current
    let systemVersion = device.systemVersion
    let model = device.model
    let name = device.name
    let manufacturer = "Apple"
    let systemName = device.systemName
    
    let deviceInfo: [String: String] = [
        "brand": manufacturer,
        "device": name,
        "model": model,
        "manufacturer": manufacturer,
        "product": systemName,
        "ios_version": systemVersion
    ]
    
    if let jsonData = try? JSONSerialization.data(withJSONObject: deviceInfo, options: []),
       let jsonString = String(data: jsonData, encoding: .utf8) {
        deviceInfoString = jsonString
    }
    
    return deviceInfoString
}


private func fetchDataWithGET(apiRoute: String, params: [String: String]? = nil, headers: [String: String]? = nil) {
    var components = URLComponents(string:apiRoute)
    
    if let params = params {
        components?.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
    }
    
    guard let url = components?.url else {
        return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    
    if let headers = headers {
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
    }
    
    let task = URLSession.shared.dataTask(with: request) { (_, _, error) in
        
    }
    task.resume()
}


enum EventConstants: String {
    case initializationStarted = "native_lp_initialization_started"
    case callbackSet = "native_lp_callback_set"
    case apiInitialized = "native_lp_api_initialized"
    case apiResponse = "native_lp_api_response"
    case connectConnection = "native_lp_connect_connection"
    case connectEventsReceived = "native_lp_connect_events_received"
    case connectEventsSent = "native_lp_connect_events_sent"
    case onNewIntent = "native_lp_on_new_intent"
    case snaUrlInitiated = "native_lp_sna_url_initiated"
    case snaUrlRedirection = "native_lp_sna_url_redirection"
    case snaUrlResponse = "native_lp_sna_url_response"
    case clientCommit = "native_lp_client_commit"
    
    case nativeErrorResult = "native_lp_error_result"
    case nativeWebErrorResult = "native_lp_web_error_result"
    case nativeSuccessResult = "native_lp_success_result"
}

@objcMembers
public class AuthEvent: NSObject {
    public static let authInitiated = "AUTH_INITIATED"
    public static let authSuccess = "AUTH_SUCCESS"
    public static let authFailed = "AUTH_FAILED"

    public static func toNativeName(_ event: String) -> String {
        return "native_lp_cle_\(event)".lowercased()
    }
}

@objcMembers
public class ProviderType: NSObject {
    public static let client = "CLIENT"
    public static let otpless = "OTPLESS"

    public static func toNativeName(_ provider: String) -> String {
        return "native_lp_cle_\(provider)".lowercased()
    }
}

