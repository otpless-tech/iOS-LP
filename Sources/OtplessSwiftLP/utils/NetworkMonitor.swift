//
//  NetworkMonitor.swift
//  OtplessSwiftLP
//
//  Created by Sparsh on 03/05/25.
//


import Network

class NetworkMonitor {
    static let shared = NetworkMonitor()
    
    private let networkMonitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "OtplessLPNetworkMonitor")
    
    var isConnectedToNetwork: Bool = false
    var isCellularNetworkEnabled: Bool = false
    
    var connectionType: NWInterface.InterfaceType?

    private let cellularMonitor = NWPathMonitor(requiredInterfaceType: .cellular)
    
    func startMonitoringNetwork() {
        networkMonitor.pathUpdateHandler = { path in
            self.isConnectedToNetwork = path.status == .satisfied
            
            if path.usesInterfaceType(.wifi) {
                self.connectionType = .wifi
            } else if path.usesInterfaceType(.cellular) {
                self.connectionType = .cellular
            } else if path.usesInterfaceType(.wiredEthernet) {
                self.connectionType = .wiredEthernet
            } else if path.usesInterfaceType(.other) {
                self.connectionType = .other
            } else {
                self.connectionType = nil
            }
        }
        networkMonitor.start(queue: queue)
    }
    
    func startMonitoringCellular() {
        cellularMonitor.pathUpdateHandler = { path in
            DispatchQueue.main.async { [weak self] in
                self?.isCellularNetworkEnabled = path.status == .satisfied
            }
        }
        cellularMonitor.start(queue: DispatchQueue.global())
    }

    func stopMonitoring() {
        networkMonitor.cancel()
        cellularMonitor.cancel()
    }
    
    
}
