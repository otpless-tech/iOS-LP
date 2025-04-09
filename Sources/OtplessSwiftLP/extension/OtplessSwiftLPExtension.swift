//
//  File.swift
//  OtplessSwiftLP
//
//  Created by Sparsh on 20/03/25.
//


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
        
        sendAuthResponse(formattedResponse)
    }
    
    func startSNA(requestURLString urlString: String) {
        self.apiRepository.performSNA(requestURL: urlString, completion: { [weak self] result in
            self?.sendSocketMessage(eventName: AppEventType.responseOnCellularData.rawValue, eventValue: result)
        })
    }
    
    func sendSocketMessage(_ messageName: String = "message", eventName: String, eventValue: Any) {
        guard let socket = socket else {
            return
        }
        
        socket.emit(
            messageName,
          [
            "event_name": eventName,
            "event_value": eventValue
            ]
        )
    }
}
