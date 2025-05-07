//
//  File.swift
//  OtplessSwiftLP
//
//  Created by Sparsh on 20/03/25.
//

import Foundation


extension OtplessSwiftLP {
    func handleParsedEvent(_ socketEvent: SocketEventData) {
        switch socketEvent.eventType {
        case .appInfo:
            sendAppInfoToServer()
            break
        case .authResponse:
            sendAuthResponseToUser(socketEvent.eventValue)
            break
        case .error:
            break
        case .responseOnCellularData:
            if let url = socketEvent.eventValue["url"] as? JSONValue,
               let urlStr = url.value as? String {
                startSNA(requestURLString: urlStr)
            }
            break
        case .unknown:
            break
        }
    }
}

extension OtplessSwiftLP {
    func sendAppInfoToServer() {
        let appInfo = DeviceInfoUtils.shared.getAppInfo()
        sendSocketMessage(eventName: AppEventType.appInfo.rawValue, eventValue: appInfo)
    }
    
    func sendAuthResponseToUser(_ response: [String: Any]) {
        var formattedResponse: [String: Any] = [:]
        for (key, value) in response {
            if let jsonValue = response[key] as? JSONValue {
                formattedResponse[key] = jsonValue.value
            } else {
                formattedResponse[key] = value
            }
        }
        
        sendAuthResponse(
            OtplessResult.success(token: response["token"] as? String ?? "")
        )
    }
    
    func startSNA(requestURLString urlString: String) {
        sendEvent(event: .snaUrlInitiated, extras: [
            "url": urlString
        ])
        self.apiRepository.performSNA(requestURL: urlString, completion: { [weak self] result in
            let api_success = (result["status"] as? String)?.lowercased() == "ok"
            sendEvent(event: .snaUrlResponse, extras: [
                "response": Utils.convertDictionaryToString(result),
                "api_success": api_success.description
            ])
            self?.sendSocketMessage(eventName: AppEventType.responseOnCellularData.rawValue, eventValue: result)
        })
    }
    
    func sendSocketMessage(_ messageName: String = "message", eventName: String, eventValue: Any) {
        guard let socket = socket else {
            return
        }
        
        let eventDict = [
            "event_name": eventName,
            "event_value": eventValue
        ]
        socket.emit(
            messageName,
            eventDict
        )
        
        sendEvent(event: .connectEventsSent, extras: [
            "response": Utils.convertDictionaryToString(eventDict)
        ])
    }
}

extension OtplessSwiftLP {
    
    func shouldThrowError(for extras: [String: String]) -> Bool {
        // Check network connectivity
        if !NetworkMonitor.shared.isConnectedToNetwork {
            sendAuthResponse(OtplessResult.error(
                errorType: ErrorTypes.NETWORK,
                errorCode: ErrorCodes.INTERNET_EC,
                errorMessage: "Internet is not available"
            ))
            return true
        }

        // Validate extras only if relevant non-empty values are present
        if let phone = extras["phone"], !phone.isEmpty,
           let countryCode = extras["countryCode"], !countryCode.isEmpty {
            if !isPhoneNumberWithCountryCodeValid(phoneNumber: phone, countryCode: countryCode) {
                sendAuthResponse(OtplessResult.error(
                    errorType: ErrorTypes.INITIATE,
                    errorCode: ErrorCodes.INVALID_PHONE_EC,
                    errorMessage: "Invalid phone number"
                ))
                return true
            }
        } else if let email = extras["email"], !email.isEmpty {
            if !isEmailValid(email) {
                sendAuthResponse(OtplessResult.error(
                    errorType: ErrorTypes.INITIATE,
                    errorCode: ErrorCodes.INVALID_EMAIL_EC,
                    errorMessage: "Invalid email"
                ))
                return true
            }
        }

        return false
    }

    // Helper functions
    private func isEmailValid(_ email: String) -> Bool {
        if email.isEmpty {
            return false
        }
        let emailRegex = "^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    private func isPhoneNumberWithCountryCodeValid(phoneNumber: String, countryCode: String) -> Bool {
        if phoneNumber.isEmpty || countryCode.isEmpty {
            return false
        }
        let fullPhoneNumber = countryCode.replacingOccurrences(of: "+", with: "") + phoneNumber
        let phoneNumberRegex = "^[0-9]+$"
        let phoneNumberPredicate = NSPredicate(format: "SELF MATCHES %@", phoneNumberRegex)
        return phoneNumberPredicate.evaluate(with: fullPhoneNumber)
    }

}
