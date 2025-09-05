//
//  File.swift
//  OtplessSwiftLP
//
//  Created by on 03/09/25.
//


import Foundation


@objc public enum OtplessEventCategory: Int {
    case action, click, load

    static func from(_ s: String) -> OtplessEventCategory? {
        switch s.uppercased() {
        case "ACTION": return .action
        case "CLICK":  return .click
        case "LOAD":   return .load
        default:       return nil
        }
    }

    public var name: String {
        switch self {
        case .action: return "ACTION"
        case .click:  return "CLICK"
        case .load:   return "LOAD"
        }
    }
}

@objc public enum OtplessEventType: Int {
    case initiate, verifyError, otpAutoRead, deliveryStatus, fallbackTriggered,
         phoneChange, verify, resend, pageLoaded, custom

    static func from(_ s: String) -> OtplessEventType? {
        switch s.uppercased() {
        case "INITIATE":           return .initiate
        case "VERIFY_ERROR":       return .verifyError
        case "OTP_AUTO_READ":      return .otpAutoRead
        case "DELIVERY_STATUS":    return .deliveryStatus
        case "FALLBACK_TRIGGERED": return .fallbackTriggered
        case "PHONE_CHANGE":       return .phoneChange
        case "VERIFY":             return .verify
        case "RESEND":             return .resend
        case "PAGE_LOADED":        return .pageLoaded
        case "CUSTOM":             return .custom
        default:                   return nil
        }
    }

    public var name: String {
        switch self {
        case .initiate:          return "INITIATE"
        case .verifyError:       return "VERIFY_ERROR"
        case .otpAutoRead:       return "OTP_AUTO_READ"
        case .deliveryStatus:    return "DELIVERY_STATUS"
        case .fallbackTriggered: return "FALLBACK_TRIGGERED"
        case .phoneChange:       return "PHONE_CHANGE"
        case .verify:            return "VERIFY"
        case .resend:            return "RESEND"
        case .pageLoaded:        return "PAGE_LOADED"
        case .custom:            return "CUSTOM"
        }
    }
}

@objcMembers
public final class OtplessEventData: NSObject {
    public let category: OtplessEventCategory
    public let eventType: OtplessEventType
    public let metaData: NSDictionary

    public init(category: OtplessEventCategory,
                eventType: OtplessEventType,
                metaData: NSDictionary = [:]) {
        self.category = category
        self.eventType = eventType
        self.metaData = metaData
        super.init()
    }
}

protocol OtplessEventDelegate: AnyObject {
    func onOTPlessEvent(_ event: OtplessEventData)
}


enum _OtplessEventParseError: Error {
    case missingKey(String)
    case invalidValue(String, String)
}

extension _OtplessEventParseError {
    var nsError: NSError {
        switch self {
        case .missingKey(let k):
            return NSError(domain: "com.otpless.events", code: 1,
                           userInfo: [NSLocalizedDescriptionKey: "Missing required key: \(k)"])
        case .invalidValue(let key, let value):
            return NSError(domain: "com.otpless.events", code: 2,
                           userInfo: [NSLocalizedDescriptionKey: "Invalid value '\(value)' for key '\(key)'"])
        }
    }
}

final class OtplessEventManager {

    static let shared = OtplessEventManager()
    weak var delegate: OtplessEventDelegate?

    private init() {}

    /// Entry point for NativeWebBridge when it sees `key == 69`
    /// `payload` is the JSON dictionary passed from web.
    func ingestFromWeb(_ payload: [String: Any]) {
        do {
            // Some integrations send the event fields at top-level,
            // others nest them under "payload" or "response". Handle all.
            let event = try parseEvent(payload)
            delegate?.onOTPlessEvent(event)
        } catch {
            let nsErr = (error as? _OtplessEventParseError)?.nsError ?? (error as NSError)
            sendEvent(event:.eventParsingError, extras: ["error":nsErr.localizedDescription])
        }
    }

    
    private func parseEvent(_ json: [String: Any]) throws -> OtplessEventData {
        // unwrap nested "eventData"
        guard let eventData = json["eventData"] as? [String: Any] else {
            throw _OtplessEventParseError.missingKey("eventData")
        }
        
        guard let eventStr = (eventData["event"] as? String)?.uppercased()
        else { throw _OtplessEventParseError.missingKey("event") }

        guard let typeStr = (eventData["type"] as? String)?.uppercased()
        else { throw _OtplessEventParseError.missingKey("type") }

        let meta = (eventData["metaData"] as? [String: Any]) ?? [:]

        guard let category = OtplessEventCategory.from(eventStr)
        else { throw _OtplessEventParseError.invalidValue("event", eventStr) }

        guard let eventType = OtplessEventType.from(typeStr)
        else { throw _OtplessEventParseError.invalidValue("type", typeStr) }

        return OtplessEventData(
            category: category,
            eventType: eventType,
            metaData: meta as NSDictionary
        )
    }

}
