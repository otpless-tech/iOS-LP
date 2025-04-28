//
//  UserAuthApiRepository.swift
//  OtplessSwiftLP
//
//  Created by Sparsh on 19/03/25.
//

import Foundation

class ApiRepository {
    private let apiManager = ApiManager()
    private let cellularConnectionManager = CellularConnectionManager()
    
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
}
