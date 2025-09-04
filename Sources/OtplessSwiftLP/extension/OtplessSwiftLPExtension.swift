//
//  File.swift
//  OtplessSwiftLP
//
//  Created by Sparsh on 20/03/25.
//

import Foundation

extension OtplessSwiftLP {
    
    func shouldThrowError(for extras: [String: String]) -> Bool {
        // Check network connectivity
        if !NetworkMonitor.shared.isConnectedToNetwork {
            sendAuthResponse(OtplessResult.error(
                errorType: ErrorTypes.NETWORK,
                errorCode: ErrorCodes.INTERNET_EC,
                errorMessage:ErrorMessages.InternetNotAvailable
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
                    errorMessage: ErrorMessages.InvalidPhoneNumber
                ))
                return true
            }
        } else if let email = extras["email"], !email.isEmpty {
            if !isEmailValid(email) {
                sendAuthResponse(OtplessResult.error(
                    errorType: ErrorTypes.INITIATE,
                    errorCode: ErrorCodes.INVALID_EMAIL_EC,
                    errorMessage:ErrorMessages.InvalidEmail
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
