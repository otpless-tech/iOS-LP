//
//  UserAuthApiRepository.swift
//  OtplessSwiftLP
//
//  Created by Sparsh on 19/03/25.
//

import Foundation

internal final class ApiRepository {
    
    static let shared = ApiRepository()
    
    private let apiManager = ApiManager()
    private let cellularConnectionManager = CellularConnectionManager()
    
    private init() {
    }
    
    func getRoomId(headers: [String: String]) async -> String? {
        do {
            let roomIdResponse: RoomIDResponse = try await apiManager.postConnect(path: "/api/rooms", body: nil, headers: headers).decode()
            return roomIdResponse.data.roomId
        } catch {
            return nil
        }
    }
    
    func performSNA(requestURL urlString: String, completion: @Sendable @escaping ([String: Any]) -> Void) {
        guard let url = URL(string: urlString) else {
            // send event that url could not be parsed
            return
        }
        cellularConnectionManager.open(url: url, operators: nil, completion: completion)
    }
    
    func pushEvents(params: [String: String], completion: @escaping (ApiResponse<EmptyResponse>) -> Void) {
        var components = URLComponents(string:"https://d33ftqsb9ygkos.cloudfront.net/prod/appevent")!
        components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url?.absoluteString else {
            return
        }
        apiManager.get(from: url, completion: completion)
    }
}

internal struct EmptyResponse: Decodable {}
