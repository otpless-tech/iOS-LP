//
//  ApiManager.swift
//  OtplessSwiftLP
//
//  Created by Sparsh on 19/03/25.
//

import Foundation

internal final class ApiManager {
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
    
    
    func get<T: Decodable>(
        from urlString: String,
        headers: [String: String]? = nil,
        completion: @escaping (ApiResponse<T>) -> Void
    ) {
        // 1. Validate URL
        guard let url = URL(string: urlString) else {
            let err = ApiError(
                message: "Invalid URL: \(urlString)",
                statusCode: 0,
                responseJson: nil
            )
            return completion(.error(error: err))
        }
        
        // 2. Build request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        headers?.forEach { request.addValue($1, forHTTPHeaderField: $0) }
        
        // 3. Fire
        URLSession.shared.dataTask(with: request) { data, response, error in
            // 3a. Networking error
            if let networkErr = error {
                let apiErr = ApiError(
                    message: networkErr.localizedDescription,
                    statusCode: 0,
                    responseJson: nil
                )
                return completion(.error(error: apiErr))
            }
            
            // 3b. HTTP status check
            guard let httpResp = response as? HTTPURLResponse else {
                let apiErr = ApiError(
                    message: "Invalid response from server",
                    statusCode: 0,
                    responseJson: nil
                )
                return completion(.error(error: apiErr))
            }
            
            // 3c. Non-2xx → parse error body if JSON
            guard (200..<300).contains(httpResp.statusCode) else {
                let jsonBody = (try? JSONSerialization.jsonObject(
                    with: data ?? Data(),
                    options: []
                ) as? [String: Any]) ?? [:]
                let message = jsonBody["message"] as? String
                ?? HTTPURLResponse.localizedString(forStatusCode: httpResp.statusCode)
                let apiErr = ApiError(
                    message: message,
                    statusCode: httpResp.statusCode,
                    responseJson: jsonBody
                )
                return completion(.error(error: apiErr))
            }
            
            // 3d. Empty‐body check
            let raw = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            if raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // no payload → still a success, with nil data
                return completion(.success(data: nil))
            }
            
            // 3e. Decode payload
            guard let payload = data else {
                // (this shouldn’t happen, since raw wasn’t empty—but just in case)
                let apiErr = ApiError(
                    message: "No data received",
                    statusCode: httpResp.statusCode,
                    responseJson: nil
                )
                return completion(.error(error: apiErr))
            }
            
            do {
                let decoded = try JSONDecoder().decode(T.self, from: payload)
                completion(.success(data: decoded))
            } catch {
                let apiErr = ApiError(
                    message: error.localizedDescription,
                    statusCode: httpResp.statusCode,
                    responseJson: nil
                )
                completion(.error(error: apiErr))
            }
        }
        .resume()
    }

    func getAsync<T: Decodable>(
        from urlString: String,
        headers: [String: String]? = nil,
        completion: @escaping (ApiResponse<T>) -> Void
    ) async -> ApiResponse<T> {
        await withCheckedContinuation { continuation in
            get(from: urlString, headers: headers){ response in
                continuation.resume(returning: response)
            }
        }
    }

}

