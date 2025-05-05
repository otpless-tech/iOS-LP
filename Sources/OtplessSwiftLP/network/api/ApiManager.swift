//
//  ApiManager.swift
//  OtplessSwiftLP
//
//  Created by Sparsh on 19/03/25.
//

import Foundation

class ApiManager {
    private let CONNECT_BASE_URL = "https://connect.otpless.app"
    
    func postConnect(
        path: String,
        body: [String: Any]?,
        headers: [String: String] = [:]
    ) async throws -> Data {
        let url = constructURL(baseURL: CONNECT_BASE_URL, path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        }
        
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
                let errorBody = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
                throw ApiError(
                    message: errorBody["message"] as? String ?? "Unexpected error occurred",
                    statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500,
                    responseJson: errorBody
                )
            }
            
            var responseString: String = ""
            if let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
               JSONSerialization.isValidJSONObject(jsonObject),
               let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted]),
               let prettyString = String(data: prettyData, encoding: .utf8) {
                responseString = prettyString
            } else if let rawString = String(data: data, encoding: .utf8) {
                responseString = rawString
            } else {
                responseString = "Unable to parse response"
            }
            
            sendEvent(event: .apiResponse, extras: [
                "api_success": "true",
                "response": responseString,
                "which_api": path
            ])
            
            return data
        } catch {
            sendEvent(event: .apiResponse, extras: [
                "api_success": "false",
                "response": "\(error.localizedDescription)",
                "which_api": path
            ])
            if let apiError = error as? ApiError {
                throw apiError
            } else {
                throw ApiError(
                    message: error.localizedDescription,
                    statusCode: 500,
                    responseJson: [
                        "errorCode": "500",
                        "errorMessage": "Something Went Wrong!"
                    ]
                )
            }
        }
    }
    
    private func constructURL(baseURL: String, path: String) -> URL {
        var components = URLComponents(string: baseURL)
        components?.path += path
        return components?.url ?? URL(string: baseURL + path)!
    }
}
