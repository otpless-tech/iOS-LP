//
//  Utils.swift
//  OtplessSwiftLP
//
//  Created by Sparsh on 20/03/25.
//

import SystemConfiguration
import Foundation
import UIKit

final internal class Utils {
    
    /// Convert base64Url to base64.
    ///
    /// - parameter string: Base64Url String that has to be converted into base64.
    /// - returns: A string that is base64 encoded.
    static func convertBase64UrlToBase64(base64Url: String) -> String {
        var base64 = base64Url
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        if base64.count % 4 != 0 {
            base64.append(String(repeating: "=", count: 4 - base64.count % 4))
        }
        
        return base64
    }
    
    /// Converts String to base64Url
    ///
    /// - parameter string: Base64 String that has to be converted into base64Url.
    /// - returns: A string that is base64Url encoded.
    static func base64UrlEncode(base64String: String) -> String {
        // Replace characters to make it URL-safe
        var base64UrlString = base64String
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
        
        // Remove padding characters
        base64UrlString = base64UrlString.trimmingCharacters(in: CharacterSet(charactersIn: "="))
        
        return base64UrlString
    }
    
    /// Fetches SNA URLs on which we make request while performing SNA.
    ///
    /// - returns: An array of URLs on which we make request.
    static func getSNAPreLoadingURLs() -> [String] {
        return [
            "https://in.safr.sekuramobile.com/v1/.well-known/jwks.json",
            "https://partnerapi.jio.com",
            "http://80.in.safr.sekuramobile.com"
        ]
    }
    
    static func formatCurrentTimeToDateString() -> String {
        let currentEpoch = Date().timeIntervalSince1970
        let date = Date(timeIntervalSince1970: currentEpoch)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        dateFormatter.timeZone = TimeZone.current
        dateFormatter.locale = Locale(identifier: "en_IN")
        
        return dateFormatter.string(from: date)
    }
    
    static func convertDictionaryToString(_ dictionary: [String: Any], options: JSONSerialization.WritingOptions = .prettyPrinted) -> String {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: dictionary, options: options)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString
            }
        } catch {
            return ("Error converting dictionary to JSON string: \(error)")
        }
        
        return ""
    }
    
    static func createErrorDictionary(errorCode: String, errorMessage: String) -> [String: String] {
        return [
            "errorCode": errorCode,
            "errorMessage": errorMessage
        ]
    }
    
    static func convertStringToDictionary(_ text: String) -> [String: Any]? {
        if let data = text.data(using: .utf8) {
            do {
                return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            } catch {
                
            }
        }
        return nil
    }

    static func base64EncodedString(from dictionary: [String: String]) -> String {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: dictionary, options: [])
            var base64String = jsonData.base64EncodedString()
            // Remove padding
            base64String = base64String.replacingOccurrences(of: "=", with: "")
            
            return base64String
        } catch {
            return ""
        }
    }
    
    static func base64ToJson(base64String: String) -> [String: Any] {
        guard let data = Data(base64Encoded: base64String) else {
            return [:]
        }
        
        do {
            if let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                return jsonObject
            } else {
                return [:]
            }
        } catch {
            return [:]
        }
    }
    
    static func convertToDictionary(text: String) -> [String: Any]? {
        if let data = text.data(using: .utf8) {
            do {
                return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            } catch {
                
            }
        }
        return nil
    }
    
    static func appendQueryParameters(from sourceURL: URL, to destinationURL: URL) -> URL? {
        // Create URL components from the destination URL
        guard var destinationComponents = URLComponents(url: destinationURL, resolvingAgainstBaseURL: false) else {
            return nil
        }

        // Get the query parameters from the source URL
        guard let sourceComponents = URLComponents(url: sourceURL, resolvingAgainstBaseURL: false),
              let queryItems = sourceComponents.queryItems else {
            return nil
        }

        // Append the query parameters to the destination URL
        if destinationComponents.queryItems != nil {
            destinationComponents.queryItems?.append(contentsOf: queryItems)
        } else {
            destinationComponents.queryItems = queryItems
        }

        // Reconstruct the URL with the appended query parameters
        if let updatedURL = destinationComponents.url {
            return updatedURL
        } else {
            return destinationURL
        }
    }
    
    static func containsJavaScriptInjection(url: URL) -> Bool {
        guard let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: true)?.queryItems else {
            return false
        }
        
        for item in queryItems {
            if let value = item.value, containsJavaScriptCode(value) {
                return true
            }
        }
        
        return false
    }

    static func containsJavaScriptCode(_ value: String) -> Bool {
        let javascriptRegex = try! NSRegularExpression(pattern: "<script\\b[^>]*>(.*?)</script>", options: .caseInsensitive)
        return javascriptRegex.matches(in: value, options: [], range: NSRange(location: 0, length: value.utf16.count)).count > 0
    }
    
    
    static func createUnsupportedIOSVersionError(supportedFrom: String, forFeature feature: String) -> [String: String] {
        return [
            "error": "\(feature.replacingOccurrences(of: " ", with: "_").lowercased()) not supported",
            "error_description": "\(feature) requires iOS version \(supportedFrom) and above."
        ]
    }
}

internal extension UIColor {
    convenience init?(hexString: String?) {
        guard let hexString = hexString else {
            return nil
        }
        
        var formattedString = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        formattedString = formattedString.replacingOccurrences(of: "#", with: "")
        
        guard formattedString.count == 6 else {
            return nil
        }
        
        var rgbValue: UInt64 = 0
        Scanner(string: formattedString).scanHexInt64(&rgbValue)
        
        let red = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(rgbValue & 0x0000FF) / 255.0
        
        self.init(red: red, green: green, blue: blue, alpha: 1.0)
    }
}



@inline(__always)
internal func DLog(_ message: @autoclosure () -> Any, file: String = #fileID, function: String = #function, line: Int = #line) {
    #if DEBUG
        print("🐛 [\(file):\(line)] \(function) → \(message())")
    #endif
}

