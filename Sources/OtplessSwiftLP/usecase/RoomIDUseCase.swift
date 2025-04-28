//
//  RoomIDUseCase.swift
//  OtplessSwiftLP
//
//  Created by Sparsh on 19/03/25.
//

import Foundation

class RoomIDUseCase {
    private let apiRepository: ApiRepository
    private var retryCount: Int = 0
    
    init (apiRepository: ApiRepository) {
        self.apiRepository = apiRepository
    }
    
    func invoke(appId: String, isRetry: Bool) async -> String? {
        if !isRetry {
            retryCount = 0
        }
        
        if retryCount >= 2 {
            return nil
        }
        
        if let roomId = await apiRepository.getRoomId(headers: [
            "appId": appId
        ]) {
            return roomId
        }
        
        retryCount += 1
        return await invoke(appId: appId, isRetry: true)
    }
}
