//
//  ApiManager.swift
//  OtplessSwiftLP
//
//  Created by Sparsh on 19/03/25.
//

import Foundation

class ApiManager {
    private let CONNECT_BASE_URL = "https://connect.otpless.app"
    
    // todo i think this class is not in use
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


internal final class HTTPClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Execute a request and return ApiResponse<Data>
    func execute(_ request: URLRequest) async -> ApiResponse<Data> {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                // No HTTPURLResponse — treat as transport failure
                return .error(error: ApiError(message: "No HTTP response"))
            }

            if (200..<300).contains(http.statusCode) {
                return .success(data: data)
            } else {
                // Build ApiError with status + parsed JSON (if any)
                let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
                let message = json?["description"] as? String
                    ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
                    ?? "HTTP \(http.statusCode)"
                return .error(error: ApiError(message: message, statusCode: http.statusCode, responseJson: json))
            }
        } catch {
            // Transport errors (DNS, TLS, no network, timeouts, cancellations, etc.)
            return .error(error: ApiError(message: error.localizedDescription))
        }
    }

    /// Build URLRequest and handle JSON body encoding errors → ApiResponse.error
    func makeRequest(
        baseURL: URL, path: String, method: String, headers: [String: String] = [:], jsonBody: [String: String]? = nil
    ) -> ApiResponse<URLRequest> {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = method
        headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }

        if let body = jsonBody {
            do {
                req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
                if req.value(forHTTPHeaderField: "Content-Type") == nil {
                    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                }
            } catch {
                // Encoding error (kept because you asked to keep "encoding")
                return .error(error: ApiError(message: "Encoding failed: \(error.localizedDescription)"))
            }
        }

        return .success(data: req)
    }
}

// MARK: - SessionService (signature mirrors your Retrofit one, returning ApiResponse<Data>)

internal protocol SessionService {
    func authenticateSession(headers: [String: String], body: [String: String]) async -> ApiResponse<Data>
    func refreshSession(headers: [String: String], body: [String: String]) async -> ApiResponse<Data>
    func deleteSession(sessionToken: String, headers: [String: String], body: [String: String]) async -> ApiResponse<Data>
}

// MARK: - Implementation

internal final class SessionServiceImpl: SessionService {
    private let baseURL: URL
    private let http: HTTPClient

    init(sessionBaseURL: URL, http: HTTPClient = HTTPClient()) {
        self.baseURL = sessionBaseURL
        self.http = http
    }

    func authenticateSession(headers: [String : String], body: [String : String]) async -> ApiResponse<Data> {
        switch http.makeRequest(
            baseURL: baseURL,
            path: "v4/session/authenticate",
            method: "POST",
            headers: headers,
            jsonBody: body
        ) {
        case .success(let req):
            return await http.execute(req!)
        case .error(let err):
            return .error(error: err)
        }
    }

    func refreshSession(headers: [String : String], body: [String : String]) async -> ApiResponse<Data> {
        switch http.makeRequest(
            baseURL: baseURL,
            path: "v4/session/refresh",
            method: "POST",
            headers: headers,
            jsonBody: body
        ) {
        case .success(let req):
            return await http.execute(req!)
        case .error(let err):
            return .error(error: err)
        }
    }

    func deleteSession(sessionToken: String, headers: [String : String], body: [String : String]) async -> ApiResponse<Data> {
        let safeToken = sessionToken.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? sessionToken
        switch http.makeRequest(baseURL: baseURL,path: "v4/session/\(safeToken)",method: "DELETE",headers: headers,jsonBody: body) {
        case .success(let req):
            return await http.execute(req!)
        case .error(let err):
            return .error(error: err)
        }
    }
}

// MARK: - Optional: tiny helper to decode ApiResponse<Data> to ApiResponse<T: Decodable>

internal extension ApiResponse where T == Data {
    func decode<U: Decodable>(as type: U.Type, using decoder: JSONDecoder = .init()) -> ApiResponse<U> {
        switch self {
        case .success(let data):
            guard let data = data else { return .success(data: nil) }
            do {
                let value = try decoder.decode(U.self, from: data)
                return .success(data: value)
            } catch {
                // Surface as your ApiError with a synthetic "encoding" style message
                return .error(error: ApiError(message: "Decoding failed: \(error.localizedDescription)"))
            }
        case .error(let err):
            return .error(error: err)
        }
    }

    /// Convenience to parse JSON to [String: Any] for quick maps / bridging layers
    func toJSONObject() -> ApiResponse<[String: Any]> {
        switch self {
        case .success(let data):
            guard
                let d = data,
                let obj = try? JSONSerialization.jsonObject(with: d),
                let json = obj as? [String: Any]
            else {
                return .success(data: nil)
            }
            return .success(data: json)
        case .error(let err):
            return .error(error: err)
        }
    }
}

