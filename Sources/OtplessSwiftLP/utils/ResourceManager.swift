//
//  ResourceManager.swift
//  OtplessSwiftLP
//
//  Created by Digvijay Singh on 05/08/25.
//

import Foundation
import UIKit


internal protocol EventSender {
    func pushEvent(_ eventName: String, _ eventParams: [String: Any])
}

internal final class ResourceManager: EventSender {
    static let shared = ResourceManager()
    
    private var _eventCount: Int = 1
    private var eventCount: Int {
        defer { _eventCount += 1 }
        return _eventCount
    }
    private var eventCountStr: String {
        return "\(eventCount)"
    }
    
    private(set) var appId: String = ""
    private(set) var inId: String = ""
    private let dateFormatter: DateFormatter
    lazy var tsId: String = {
        return "\(UUID().uuidString)-\(Int(Date().timeIntervalSince1970 * 1000))"
    }()
    private var deviceInfoString = ""
    
    /// [install-id, tsId, appId]
    var trackIds: [String] {
        return [inId, tsId, appId]
    }
    
    private init() {
        self.dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        dateFormatter.locale = Locale.current
    }
    
    /// Call once you know your appId
    func initialize(appId: String) {
        self.appId = appId
        // initializing inid
        if let savedInid: String = SecureStorage.shared.getFromUserDefaults(key: Constants.INID_KEY, defaultValue: ""),
           !savedInid.isEmpty {
            self.inId = savedInid
        } else {
            inId = "\(UUID().uuidString)-\(Int(Date().timeIntervalSince1970 * 1000))"
            SecureStorage.shared.saveToUserDefaults(key: Constants.INID_KEY, value: inId)
        }
    }

    
    func pushEvent(_ eventName: String, _ eventParams: [String: Any] = [:]) {
        let payload = makeEventMap(eventName: eventName, eventParams: eventParams)
        ApiRepository.shared.pushEvents(params: payload) { response in
            switch response {
            case .success:
                DLog("---> \(eventName)")
            case .error(let error):
                
                DLog("Error \(eventName): \(error.description)")
            }
        }
    }
    
    
    private func makeEventMap(eventName: String, eventParams: [String: Any]) -> [String: String] {
        var data: [String: String] = [:]
        do {
            data["event_name"] = eventName
            data["platform"] = "ios-lp"
            data["sdk_version"] = Bundle.main.infoDictionary?["LOGINPAGE_VERSION_NAME"] as? String ?? ""
            
            let (inid, tsid, mid) = (trackIds[0], trackIds[1], trackIds[2])
            data["inid"] = inid
            data["tsid"] = tsid
            data["mid"] = mid
            
            data["event_id"] = eventCountStr
            data["event_timestamp"] = dateFormatter.string(from: Date())
            data["device_info"] = getDeviceInfoString()

            let jsonData = try JSONSerialization.data(withJSONObject: eventParams, options: [])
            data["event_params"] = String(data: jsonData, encoding: .utf8) ?? "{}"
        }
        catch {
            DLog(error.localizedDescription)
        }
        return data
    }
    
    func getDeviceInfoString() -> String {
        if !deviceInfoString.isEmpty {
            return deviceInfoString
        }
        let deviceInfo: [String: String] = DeviceInfoUtils.shared.getDeviceInfoDict()
        if let jsonData = try? JSONSerialization.data(withJSONObject: deviceInfo, options: []),
           let jsonString = String(data: jsonData, encoding: .utf8)
        {
            deviceInfoString = jsonString
        } else {
            deviceInfoString = "{}"
        }
        return deviceInfoString
    }
}


