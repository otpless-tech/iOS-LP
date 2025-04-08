//
//  File.swift
//  OtplessSwiftConnect
//
//  Created by Sparsh on 20/03/25.
//


extension OtplessSwiftConnect {
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

extension OtplessSwiftConnect {
    func sendAppInfoToServer() {
        guard let socket = socket else {
            // Send socket null event
            return
        }
        
        let appInfo = DeviceInfoUtils.shared.getAppInfo()
        socket.emit(
            "message",
          [
                "event_name": "8",
                "event_value": appInfo
            ]
        )
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
        self.apiRepository.performSNA(requestURL: urlString, completion: { result in
            print("OtplessConnect: SNA completed with result: \(result)")
        })
    }
}
