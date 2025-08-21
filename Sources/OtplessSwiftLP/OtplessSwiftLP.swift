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
    internal private(set) var apiRepository: ApiRepository = ApiRepository.shared
    private lazy var roomIdUseCase: RoomIDUseCase = {
        return RoomIDUseCase(apiRepository: apiRepository)
    }()
    private var roomRequestId: String = ""
    internal private(set) weak var delegate: ConnectResponseDelegate?
    private var safariViewController: SFSafariViewController?
    
    
    private var isUsingCustomURL = false
    
    @objc weak var otplessView: OtplessView?
    private weak var merchantVC: UIViewController?
    
    @objc public static let shared: OtplessSwiftLP = {
        DeviceInfoUtils.shared.initialise()
        return OtplessSwiftLP()
    }()
    
    public override init() {
        super.init()
    }
    
    // method for initialization
    @objc public func initialize(
        appId: String,
        merchantLoginUri: String? = nil,
        onTraceIDReceived: @escaping (String) -> Void
    ) {
        // todo send event
//        sendEvent(event: .initializationStarted)
        self.appId = appId
        if let merchantLoginUri = merchantLoginUri {
            self.loginUri = merchantLoginUri
        } else {
            self.loginUri = "otpless." + appId.lowercased() + "://otpless"
        }
        
        NetworkMonitor.shared.startMonitoringCellular()
        NetworkMonitor.shared.startMonitoringNetwork()
        
        onTraceIDReceived(ResourceManager.shared.tsId )

    }
    
    public func start(vc: UIViewController, options: SafariCustomizationOptions? = nil, extras: [String: String] = [:], timeout: TimeInterval = 2) {
        if !isInitilized(){
            return
        }
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
        if !isInitilized(){
            return
        }
        self.webviewBaseURL = baseUrl + "?appid=\(appId)"
        self.isUsingCustomURL = true
        processWithParams(vc: vc, options: options, extras: extras, timeout: timeout)
    }
    
    private func isInitilized() -> Bool {
        if appId.isEmpty {
            sendAuthResponse(OtplessResult.error(errorType: ErrorTypes.INITIATE, errorCode: ErrorCodes.NOT_INITIALIZED_EC, errorMessage: "Loginpage sdk not initialized"))
            return false
        }
        return true
    }
    
    private func processWithParams(vc: UIViewController, options: SafariCustomizationOptions? = nil, extras: [String: String] = [:], timeout: TimeInterval = 2){
        if shouldThrowError(for: extras) {
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
    
    func addHeadlessViewToMerchantVC() {
        if (merchantVC != nil && merchantVC?.view != nil) {
            if otplessView == nil || otplessView?.superview == nil {
                let vcView = merchantVC?.view
                DispatchQueue.main.async {
                    if vcView != nil {
                        
                        var headlessView: OtplessView
                        headlessView = OtplessView(headlessRequest: headlessRequest)
                        self.otplessView = headlessView
                        
                        OtplessHelper.sendEvent(event: EventConstants.REQUEST_PUSHED_WEB)
                        
                        if let view = vcView {
                            if let lastSubview = view.subviews.last {
                                view.insertSubview(headlessView, aboveSubview: lastSubview)
                            } else {
                                view.addSubview(headlessView)
                            }
                        }
                        
                        if #available(iOS 11.0, *) {
                            if let headlessView = self.otplessView,
                               let vcView = self.merchantVC?.view {
                                
                                headlessView.setConstraints([
                                    headlessView.widthAnchor.constraint(equalToConstant: UIScreen.main.bounds.width),
                                    headlessView.heightAnchor.constraint(equalToConstant: headlessView.getViewHeight()),
                                    headlessView.centerXAnchor.constraint(equalTo: vcView.centerXAnchor),
                                    headlessView.bottomAnchor.constraint(equalTo: vcView.bottomAnchor)
                                ])
                            }
                        }
                    }
                }
            }
        }
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
                            let otplessResult = OtplessResult.success(token: token)
                            sendEvent(event: .nativeSuccessResult, extras: OtplessResult.successMap(from: otplessResult) ?? [:])
                            delegate?.onConnectResponse(
                                otplessResult
                            )
                        } else if let error = queryItems.first(where: { $0.name == "error"})?.value {
                            let errorDict = Utils.base64ToJson(base64String: error)
                            sendEvent(event: .nativeWebErrorResult, extras: errorDict)
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
        sendEvent(event: .nativeErrorResult, extras: OtplessResult .errorMap(from: response) ?? [:])
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
