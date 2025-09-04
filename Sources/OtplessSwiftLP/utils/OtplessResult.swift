//
//  OtplessResult.swift
//  OtplessSwiftLP
//
//  Created by Sparsh on 03/05/25.
//

import Foundation

@objc public class ErrorCodes: NSObject {
    @objc public static let USER_CANCELLED_EC = 10_000
    @objc public static let EXCEPTION_EC = 11_000

    @objc public static let INVALID_PHONE_EC = 7102
    @objc public static let INVALID_EMAIL_EC = 7104
    @objc public static let INTERNET_EC = 9103
    @objc public static let NOT_INITIALIZED_EC = 9120
}

@objc public class ErrorMessages: NSObject {
    @objc public static let InternetNotAvailable = "Internet is not available"
    @objc public static let InvalidPhoneNumber = "Invalid phone number"
    @objc public static let InvalidEmail = "Invalid email"
    @objc public static let SDKNotInitialized = "Loginpage sdk not initialized"
    @objc public static let UnknownErrorMessage = "Unknown error"
    @objc public static let UnknownUrlError = "Unknown url error"
    @objc public static let UnknownResponse = "Unknown response"
    @objc public static let RequestLoadError = "Request load error"
}

@objc public class OtplessResult: NSObject {

    /// "success" or "error"
    @objc public let status: String

    /// Present if status == "success"
    @objc public let token: String?
    
    /// Present if status == "success"
    @objc public let sessionTokenJWT: String?
    
    /// Present if status == "success"
    @objc public let fireBaseToken: String?

    /// Always present
    @objc public let traceId: String = DeviceInfoUtils.shared.getTrackingSessionId() ?? ""

    /// Present if status == "error"
    @objc public let errorType: String?
    @objc public let errorCode: Int
    @objc public let errorMessage: String?

    private init(status: String,
                 token: String? = nil,
                 sessionTokenJWT: String? = nil,
                 fireBaseToken: String? = nil,
                 errorType: String? = nil,
                 errorCode: Int = 0,
                 errorMessage: String? = nil) {
        self.status = status
        self.token = token
        self.sessionTokenJWT = sessionTokenJWT
        self.fireBaseToken = fireBaseToken
        self.errorType = errorType
        self.errorCode = errorCode
        self.errorMessage = errorMessage
    }

    /// Factory method for success
    @objc public static func success(token: String, sessionTokenJWT: String? = nil, fireBaseToken: String? = nil) -> OtplessResult {
        return OtplessResult(status: "success", token: token, sessionTokenJWT: sessionTokenJWT, fireBaseToken: fireBaseToken)
    }

    /// Factory method for error
    @objc public static func error(errorType: String, errorCode: Int, errorMessage: String) -> OtplessResult {
        return OtplessResult(status: "error", errorType: errorType, errorCode: errorCode, errorMessage: errorMessage)
    }
    
    @objc public static func successMap(from result: OtplessResult) -> [String: Any]? {
        guard result.status == "success" else {
            return nil
        }

        return [
            "token": result.token,
            "sessionTokenJWT": result.sessionTokenJWT,
            "fireBaseToken": result.fireBaseToken,
            "traceId": result.traceId ?? ""
        ]
    }
    
    @objc public static func errorMap(from result: OtplessResult) -> [String: Any]? {
        guard result.status == "error" else {
            return nil
        }

        return [
            "errorCode": result.errorCode,
            "errorMessage": result.errorMessage ?? "",
            "errorType": result.errorType ?? "",
            "traceId": result.traceId
        ]
    }
}

internal class ErrorTypes {
    static let INITIATE = "INITIATE"
    static let VERIFY = "VERIFY"
    static let NETWORK = "NETWORK"
}
