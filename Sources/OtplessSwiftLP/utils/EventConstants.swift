//
//  EventConstants.swift
//  OtplessSwiftLP
//
//  Created by Sparsh on 05/05/25.
//

import Foundation

internal enum EventConstants {
    static let initializationStarted = "native_lp_initialization_started"
    static let callbackSet = "native_lp_callback_set"
    static let apiInitialized = "native_lp_api_initialized"
    static let apiResponse = "native_lp_api_response"
    static let connectConnection = "native_lp_connect_connection"
    static let connectEventsReceived = "native_lp_connect_events_received"
    static let connectEventsSent = "native_lp_connect_events_sent"
    static let onNewIntent = "native_lp_on_new_intent"
    static let snaUrlInitiated = "native_lp_sna_url_initiated"
    static let snaUrlRedirection = "native_lp_sna_url_redirection"
    static let snaUrlResponse = "native_lp_sna_url_response"
    static let clientCommit = "native_lp_client_commit"
    
    static let nativeErrorResult = "native_lp_error_result"
    static let nativeWebErrorResult = "native_lp_web_error_result"
    static let nativeSuccessResult = "native_lp_success_result"
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

