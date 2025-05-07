// The Swift Programming Language
// https://docs.swift.org/swift-book

import UIKit
import SocketIO
import SafariServices
import os


@objc public class OtplessSwiftLP: NSObject, URLSessionDelegate {
    private var socketManager: SocketManager? = nil
    internal private(set) var socket: SocketIOClient? = nil
    internal private(set) var appId: String = ""
    private var loginUri: String = ""
    private var webviewBaseURL = ""
    private var originalUri = "https://otpless.com/rc5/appid/"
    internal private(set) var apiRepository: ApiRepository = ApiRepository()
    private lazy var roomIdUseCase: RoomIDUseCase = {
        return RoomIDUseCase(apiRepository: apiRepository)
    }()
    private var roomRequestId: String = ""
    internal private(set) weak var delegate: ConnectResponseDelegate?
    private var safariViewController: SFSafariViewController?
    
    private var shouldLog = false
    
    internal private(set) var extras: [String: String] = [:]
    private var timeout: TimeInterval = 2
    
    private var roomIdContinuation: CheckedContinuation<Void, Never>?
    private var roomIdResolved = false
    
    internal private(set) var eventCounter = 1
    private var isUsingCustomURL = false
    
    @objc public static let shared: OtplessSwiftLP = {
        DeviceInfoUtils.shared.initialise()
        return OtplessSwiftLP()
    }()
    
    public override init() {
        super.init()
    }
    
    @objc public func enableSocketLogging() {
        self.shouldLog = true
    }
    // method for initialization
    @objc public func initialize(
        appId: String,
        merchantLoginUri: String? = nil,
        onTraceIDReceived: @escaping (String) -> Void
    ) { 
        sendEvent(event: .initializationStarted)
        self.appId = appId
        if let merchantLoginUri = merchantLoginUri {
            self.loginUri = merchantLoginUri
        } else {
            self.loginUri = "otpless." + appId.lowercased() + "://otpless"
        }
        
        NetworkMonitor.shared.startMonitoringCellular()
        NetworkMonitor.shared.startMonitoringNetwork()
        
        if let tsid = DeviceInfoUtils.shared.getTrackingSessionId() {
            onTraceIDReceived(tsid)
        }
        
        Task(priority: .medium, operation: { [weak self] in
            guard let self = self else { return }
            self.roomRequestId = await self.roomIdUseCase.invoke(appId: appId, isRetry: false) ?? ""

            if !self.roomRequestId.isEmpty {
                if self.roomIdResolved == false {
                    self.roomIdResolved = true
                    self.roomIdContinuation?.resume()
                    self.roomIdContinuation = nil
                }
            }
        })

    }
    
    func setupSocketEvents() {
        guard let socket = socket else {
            sendEvent(event: .connectConnection, extras: [
                "reason": "Got null socket instance."
            ])
            os_log("OtplessConnect: Could not create socket connection")
            return
        }
        
        socket.on(clientEvent: .connect) { [weak self] data, ack in
            sendEvent(event: .connectConnection, extras: [
                "connection_status": "connected",
                "api_success": "true"
            ])
            if self?.shouldLog == true {
                os_log("OtplessConnect: socket connected")
            }
        }
        
        socket.on(clientEvent: .disconnect) { [weak self] data, ack in
            let reasonString: String
            if data.isEmpty {
                reasonString = "No data"
            } else if data.count == 1 {
                reasonString = "\(data[0])"
            } else {
                reasonString = data.map { "\($0)" }.joined(separator: ", ")
            }
            
            sendEvent(event: .connectConnection, extras: [
                "connection_status": "connect_error",
                "api_success": "false",
                "reason": reasonString
            ])
            if self?.shouldLog == true {
                os_log("OtplessConnect: socket disconnected")
            }
        }
        
        socket.on("message") { [weak self] (data, ack) in
            if let parsedEvent = SocketEventParser.parseEvent(from: data) {
                self?.handleParsedEvent(parsedEvent)
            } else {
                if self?.shouldLog == true {
                    print("OtplessConnect: Failed to parse event \(data)")
                }
            }
            let dataString: String
            if data.isEmpty {
                dataString = "No data"
            } else if data.count == 1 {
                dataString = "\(data[0])"
            } else {
                dataString = data.map { "\($0)" }.joined(separator: ", ")
            }
            sendEvent(event: .connectEventsReceived, extras: ["request": dataString])
        }
    }
    
    public func start(vc: UIViewController, options: SafariCustomizationOptions? = nil, extras: [String: String] = [:], timeout: TimeInterval = 2) {
        self.webviewBaseURL = originalUri
        self.isUsingCustomURL = false
        processWithParams(vc: vc, options: options, extras: extras, timeout: timeout)
    }
    
    public func start(
        baseUrl: String,
        vc: UIViewController,
        options: SafariCustomizationOptions? = nil,
        extras: [String: String] = [:],
        timeout: TimeInterval = 2
    ) {
        self.webviewBaseURL = baseUrl + "?appid=\(appId)"
        self.isUsingCustomURL = true
        processWithParams(vc: vc, options: options, extras: extras, timeout: timeout)
    }
    
    private func processWithParams(vc: UIViewController, options: SafariCustomizationOptions? = nil, extras: [String: String] = [:], timeout: TimeInterval = 2){
        if connectionCouldNotBeMade() || !areExtrasValid(extras) {
            return
        }
        
        self.extras = extras
        self.timeout = timeout
        if roomRequestId.isEmpty {
            waitForRoomId(timeout: timeout) { [weak self] in
                guard let self = self else { return }
                self.proceedToOpenSafariVC(vc: vc, options: options)
            }
        } else {
            proceedToOpenSafariVC(vc: vc, options: options)
        }
    }
    
    @objc public func userAuthEvent(event: String, providerType: String, fallback: Bool, providerInfo: [String: String]) {
        var extras: [String: Any] = [:]
        extras["providerType"] = ProviderType.toNativeName(providerType)
        extras["fallback"] = fallback ? "true" : "false"
        extras["providerInfo"] = providerInfo
        sendEvent(
            event: AuthEvent.toNativeName(event),
            extras: extras
        )
    }

    private func proceedToOpenSafariVC(vc: UIViewController, options: SafariCustomizationOptions?) {
        
        let url: URL?
        if isUsingCustomURL {
            // In case of custom url, appId is appended along with the baseUrl when start function is called.
            url = getLoadingURL(startUrl: webviewBaseURL, loginUri: loginUri, roomId: self.roomRequestId)
        } else {
            url = getLoadingURL(startUrl: webviewBaseURL + appId, loginUri: loginUri, roomId: self.roomRequestId)
        }

        guard let url = url else {
            print("Received null url from getLoadingURL")
            return
        }
        
        self.openSocket()
        openSafariVC(from: vc, urlString: url.absoluteString, options: options)
    }

    private func waitForRoomId(timeout: TimeInterval, completion: @escaping () -> Void) {
        roomIdResolved = false

        Task {
            await withCheckedContinuation { continuation in
                self.roomIdContinuation = continuation

                Task {
                    try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    if !roomIdResolved {
                        roomIdResolved = true
                        continuation.resume()
                    }
                }
            }
            completion()
        }
    }

    
    private func openSafariVC(from vc: UIViewController, urlString: String, options: SafariCustomizationOptions?) {
        DispatchQueue.main.async {
            guard let url = URL(string: urlString) else { return }

            self.safariViewController = SFSafariViewController(url: url)
            
            guard let safariViewController = self.safariViewController else {
                return
            }
            
            if let barTintColor = options?.preferredBarTintColor {
                safariViewController.preferredBarTintColor = barTintColor
            }

            if let controlTintColor = options?.preferredControlTintColor {
                safariViewController.preferredControlTintColor = controlTintColor
            }
            
            safariViewController.modalPresentationStyle = .formSheet
            safariViewController.delegate = self
            safariViewController.presentationController?.delegate = self

            vc.present(safariViewController, animated: true, completion: nil)
        }
    }
    
    @objc public func cease() {
        socket?.disconnect()
        socketManager?.disconnect()
        socket = nil
        socketManager = nil
        safariViewController?.dismiss(animated: true)
        safariViewController = nil
        roomRequestId = ""
        NetworkMonitor.shared.stopMonitoring()
        NetworkMonitor.shared.stopMonitoring()
    }
    
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
    }
    
    @objc public func setResponseDelegate(_ delegate: ConnectResponseDelegate) {
        self.delegate = delegate
        sendEvent(event: .callbackSet)
    }
    
    @objc public func isOtplessDeeplink(url : URL) -> Bool{
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: true), let host = components.host {
            switch host {
            case "otpless":
                return true
            default:
                break
            }
        }
        return false
    }
    
    @objc public func processOtplessDeeplink(url : URL) {
        sendEvent(event: .onNewIntent, extras: ["deeplink": url.absoluteString])
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: true), let host = components.host {
            switch host {
            case "otpless":
                if url.lastPathComponent.lowercased() == "close" {
                    if let queryItems = components.queryItems {
                        if let token = queryItems.first(where: { $0.name == "token" })?.value {
                            delegate?.onConnectResponse(
                                .success(token: token)
                            )
                        } else if let error = queryItems.first(where: { $0.name == "error"})?.value {
                            let errorDict = Utils.base64ToJson(base64String: error)
                            let errorType = (errorDict["errorType"] as? String) ?? ErrorTypes.INITIATE
                            let errorMessage = (errorDict["errorMessage"] as? String) ?? ""
                            let errorCode = (errorDict["errorCode"] as? Int) ?? -1
                            delegate?.onConnectResponse(
                                OtplessResult.error(errorType: errorType, errorCode: errorCode, errorMessage: errorMessage)
                            )
                        }
                         cease()
                    }
                }
            default:
                break
            }
        }
    }
    
}

extension OtplessSwiftLP {
    func openSocket() {
        let socketUrl = URL(string: "https://connect.otpless.app/?token=\(self.roomRequestId)")
        guard let socketUrl = socketUrl else {
            os_log("Could not create socket url")
            return
        }
        self.socketManager = SocketManager(
            socketURL: socketUrl,
            config: [
                .log(shouldLog),
                .reconnects(true),
                .compress,
                .secure(true),
                .selfSigned(true),
                .sessionDelegate(self),
                .path("/socket.io"),
                .connectParams(["token": self.roomRequestId])
            ]
        )
        socketManager?.reconnect()
        guard let socketManager = self.socketManager else {
            os_log("Could not create socket manager")
            return
        }
        self.socket = socketManager.defaultSocket
        
        guard let socket = self.socket else {
            os_log("Could not create socket")
            return
        }
        socket.connect()
        
        self.setupSocketEvents()
    }
}

extension OtplessSwiftLP: SFSafariViewControllerDelegate, UIAdaptivePresentationControllerDelegate {
    
    public func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        sendAuthResponse(
            OtplessResult.error(
                errorType: ErrorTypes.INITIATE, errorCode: ErrorCodes.USER_CANCELLED_EC, errorMessage: "User cancelled")
            )
      }
    
    public func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        sendAuthResponse(
            OtplessResult.error(
                errorType: ErrorTypes.INITIATE, errorCode: ErrorCodes.USER_CANCELLED_EC, errorMessage: "User cancelled")
        )
    }
}

extension OtplessSwiftLP {
    func sendAuthResponse(_ response: OtplessResult) {
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.onConnectResponse(response)
            self?.cease()
        }
    }
    
    func getAndIncrementEventCounter() -> Int {
        let currentEventCounter = eventCounter
        eventCounter += 1
        return currentEventCounter
    }
}


@objc public protocol ConnectResponseDelegate: NSObjectProtocol {
    func onConnectResponse(_ response: OtplessResult)
}
