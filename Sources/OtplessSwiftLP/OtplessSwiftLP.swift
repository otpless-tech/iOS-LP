// The Swift Programming Language
// https://docs.swift.org/swift-book

import UIKit
import SocketIO
import SafariServices
import os


public class OtplessSwiftLP: NSObject, URLSessionDelegate {
    private var socketManager: SocketManager? = nil
    internal private(set) var socket: SocketIOClient? = nil
    private var appId: String = ""
    private var loginUri: String = ""
    private var webviewBaseURL = "https://otpless.com/rc5/appid/"
    private var roomRequestToken: String = ""
    internal private(set) var apiRepository: ApiRepository = ApiRepository()
    private lazy var roomTokenUseCase: RoomTokenUseCase = {
        return RoomTokenUseCase(apiRepository: apiRepository)
    }()
    private lazy var roomIdUseCase: RoomIDUseCase = {
        return RoomIDUseCase(apiRepository: apiRepository)
    }()
    private var roomRequestId: String = ""
    private var secret: String = ""
    internal private(set) weak var delegate: ConnectResponseDelegate?
    private var safariViewController: SFSafariViewController?
    
    private var shouldLog = false
    
    public static let shared: OtplessSwiftLP = {
        return OtplessSwiftLP()
    }()
    
    public override init() {
        super.init()
    }
    
    public func enableSocketLogging() {
        self.shouldLog = true
    }
    
    public func initialize(
        appId: String,
        secret: String,
        merchantLoginUri: String? = nil
    ) {
        self.appId = appId
        self.secret = secret
        if let merchantLoginUri = merchantLoginUri {
            self.loginUri = merchantLoginUri
        } else {
            self.loginUri = "otpless." + appId.lowercased() + "://otpless"
        }
        
        Task(priority: .medium, operation: { [weak self] in
            self?.roomRequestToken = await self?.roomTokenUseCase.invoke(appId: appId, secret: secret, isRetry: false) ?? ""
            self?.roomRequestId = await self?.roomIdUseCase.invoke(token: self?.roomRequestToken ?? "", isRetry: false) ?? ""
            
            if self?.roomRequestId.isEmpty == false {
                self?.openSocket()
            }
        })
    }
    
    func setupSocketEvents() {
        guard let socket = socket else {
            os_log("OtplessConnect: Could not create socket connection")
            return
        }
        
        socket.on(clientEvent: .connect) { [weak self] data, ack in
            if self?.shouldLog == true {
                os_log("OtplessConnect: socket connected")
            }
        }
        
        socket.on(clientEvent: .disconnect) { [weak self] data, ack in
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
        }
    }
    
    public func start(vc: UIViewController) {
        let url = getLoadingURL(startUrl: webviewBaseURL + appId, isHeadless: false, loginUri: loginUri, roomId: self.roomRequestId)
        
        guard let url = url else {
            print("Received null url from getLoadingURL")
            return
        }
        openSafariVC(from: vc, urlString: url.absoluteString)
    }
    
    func openSafariVC(from merchantVC: UIViewController, urlString: String) {
        guard let url = URL(string: urlString) else { return }
        safariViewController = SFSafariViewController(url: url)
        guard let safariViewController = safariViewController else {
            return
        }

        safariViewController.modalPresentationStyle = .formSheet
        safariViewController.delegate = self
        safariViewController.presentationController?.delegate = self
        merchantVC.present(safariViewController, animated: true)
    }
    
    public func cease() {
        socket?.disconnect()
        socketManager?.disconnect()
        socket = nil
        socketManager = nil
        safariViewController?.dismiss(animated: true)
        safariViewController = nil
        roomRequestId = ""
        roomRequestToken = ""
        secret = ""
    }
    
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
    }
    
    public func setResponseDelegate(_ delegate: ConnectResponseDelegate) {
        self.delegate = delegate
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
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: true), let host = components.host {
            switch host {
            case "otpless":
                if let queryItems = components.queryItems,
                   let token = queryItems.first(where: { $0.name == "token" })?.value {
                    delegate?.onConnectResponse(["token":  token])
                    
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
            sendAuthResponse([
                "error": "Could not create socket url"
            ])
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
            sendAuthResponse([
                "error": "Could not create socket url"
            ])
            return
        }
        socket.connect()
        
        self.setupSocketEvents()
    }
}

extension OtplessSwiftLP: SFSafariViewControllerDelegate, UIAdaptivePresentationControllerDelegate {
    
    public func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        sendAuthResponse([
            "error": "User cancelled"
        ])
        cease()
      }
    
    public func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        sendAuthResponse([
            "error": "User cancelled"
        ])
        cease()
    }
}

extension OtplessSwiftLP {
    func sendAuthResponse(_ response: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.onConnectResponse(response)
            
            if let _ = response["token"] as? String {
                self?.cease() // Stop connection and dismiss safariViewController if we get the token
            }
        }
    }
}


@objc public protocol ConnectResponseDelegate: NSObjectProtocol {
    func onConnectResponse(_ response: [String: Any])
}
