// The Swift Programming Language
// https://docs.swift.org/swift-book

import UIKit
import SocketIO
import SafariServices
import os


@objc public class OtplessSwiftLP: NSObject, URLSessionDelegate,OtplessEventDelegate {
    internal private(set) var appId: String = ""
    private var loginUri: String = ""
    private var webviewBaseURL = ""
    private var originalUri = "https://otpless.com/rc5/appid/"
    @objc weak var otplessView: OtplessView?
    internal private(set) var apiRepository: ApiRepository = ApiRepository()

    internal private(set) weak var delegate: ConnectResponseDelegate?
    internal private(set) weak var eventDelegate: OnEventDelegate?
    @objc public var webviewInspectable: Bool = false
    weak var merchantVC: UIViewController?
    
    private var shouldLog = false
    
    internal private(set) var extras: [String: String] = [:]
    
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
    }
    
    public func start(vc: UIViewController, extras: [String: String] = [:]) {
        merchantVC = vc
        if !isInitilized(){
            return
        }
        self.webviewBaseURL = originalUri
        self.isUsingCustomURL = false
        processWithParams(extras: extras)
    }
    
    public func start(
        baseUrl: String,
        vc: UIViewController,
        extras: [String: String] = [:]
    ) {
        merchantVC = vc
        if !isInitilized(){
            return
        }
        self.webviewBaseURL = baseUrl + "?appid=\(appId)"
        self.isUsingCustomURL = true
        processWithParams(extras: extras)
    }
    
    private func isInitilized() -> Bool {
        if appId.isEmpty {
            sendAuthResponse(OtplessResult.error(errorType: ErrorTypes.INITIATE, errorCode: ErrorCodes.NOT_INITIALIZED_EC, errorMessage: ErrorMessages.SDKNotInitialized))
            return false
        }
        return true
    }
    
    private func processWithParams( extras: [String: String] = [:]){
        if shouldThrowError(for: extras) {
            return
        }
        
        self.extras = extras
        proceedToCreateLoadingUrl()
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

    private func proceedToCreateLoadingUrl() {
        
        let url: URL?
        if isUsingCustomURL {
            // In case of custom url, appId is appended along with the baseUrl when start function is called.
            url = getLoadingURL(startUrl: webviewBaseURL, loginUri: loginUri)
        } else {
            url = getLoadingURL(startUrl: webviewBaseURL + appId, loginUri: loginUri)
        }

        guard let url = url else {
            var errorMessage = ErrorMessages.UnknownUrlError
            var errorCode = ErrorCodes.EXCEPTION_EC
            var errorType = ErrorTypes.INITIATE
            let unknownErrorJson = ["errorType":errorType,"errorCode":errorCode,"errorMessage":errorMessage] as [String : Any]
            generateErrorResult(errorDict: unknownErrorJson)
            print("Received null url from getLoadingURL")
            return
        }
        addLoginPageToMerchantVC(urlString: url.absoluteString)
    }

    private func addLoginPageToMerchantVC(urlString: String) {
        // Bail if container view is missing or the view is already added
        guard let containerView = merchantVC?.view, otplessView?.superview == nil else { return }

        DispatchQueue.main.async {
            let loginPage = OtplessView(webURL: urlString)
            self.otplessView = loginPage
            containerView.addSubview(loginPage)

            if #available(iOS 11.0, *) {
                loginPage.translatesAutoresizingMaskIntoConstraints = false
                let guide = containerView.safeAreaLayoutGuide
                NSLayoutConstraint.activate([
                    loginPage.topAnchor.constraint(equalTo: guide.topAnchor),
                    loginPage.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                    loginPage.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                    loginPage.bottomAnchor.constraint(equalTo: guide.bottomAnchor)
                ])
            } else {
                // iOS < 11 fallback
                loginPage.frame = containerView.bounds
                loginPage.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            }

            // If the view wraps a WKWebView, let it respect inset adjustments
            if #available(iOS 11.0, *) {
                (loginPage.mWebView?.scrollView)?.contentInsetAdjustmentBehavior = .automatic
            }
        }
    }

    
    @objc public func cease() {
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
    
    @objc public func setEventDelegate(_ delegate: OnEventDelegate) {
        self.eventDelegate = delegate
        OtplessEventManager.shared.delegate = self
        //sendEvent(event: .callbackSet)
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
    func sendAuthResponse(_ response: OtplessResult) {
        sendEvent(event: .nativeErrorResult, extras: OtplessResult .errorMap(from: response) ?? [:])
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.onConnectResponse(response)
            //self?.cease()
        }
    }
    
    func getAndIncrementEventCounter() -> Int {
        let currentEventCounter = eventCounter
        eventCounter += 1
        return currentEventCounter
    }
    
    public func onOTPlessEvent(_ event: OtplessEventData) {
        self.eventDelegate?.onEvent(event)
    }
    
    
    func parseResponse(response:[String:Any]) {
        DispatchQueue.main.async { [weak self] in
               self?.otplessView?.dismissView()
        }
        var responseJson : [String:Any] = [:]
        var errorJson:[String:Any] = [:]
        var errorResponseJson:[String:Any] = [:]
        var legacyToken = response["token"] as? String ?? ""
        
        if let base64Response = response["response"] as? String {
            responseJson = Utils.base64ToJson(base64String: base64Response)
        } else {
            responseJson = [:]
        }
        if let base64Error = response["error"] as? String {
            errorJson = Utils.base64ToJson(base64String: base64Error)
        } else {
            errorJson = [:]
        }
        if let base64ErrorInResponse = response["response"] as? String {
            errorResponseJson = Utils.base64ToJson(base64String: base64ErrorInResponse)
        } else {
            errorResponseJson = [:]
        }
        if !responseJson.isEmpty,
           let token = responseJson["token"] as? String,
           !token.isEmpty {
            generateSuccessResult(token: token, responseJson: responseJson)
                
        } else if !legacyToken.isEmpty  {
            let result = OtplessResult.success(
                token: legacyToken,
                sessionTokenJWT: nil,
                fireBaseToken: nil
            )
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.onConnectResponse(result)
            }
        } else if !errorJson.isEmpty {
            generateErrorResult(errorDict: errorJson)
        } else if !errorResponseJson.isEmpty {
            generateErrorResult(errorDict: errorResponseJson)
        } else {
            var errorMessage = ErrorMessages.UnknownResponse
            var errorCode = ErrorCodes.EXCEPTION_EC
            var errorType = ErrorTypes.INITIATE
            let unknownErrorJson = ["errorType":errorType,"errorCode":errorCode,"errorMessage":errorMessage] as [String : Any]
            generateErrorResult(errorDict: unknownErrorJson)
        }
    }
    
    func generateSuccessResult(token : String,responseJson : [String:Any]) {
        // sessionInfo
        var jwtToken = ""
        var sessionToken = ""
        var refreshToken = ""
        if let sessionInfo = responseJson["sessionInfo"] as? [String: Any] {
            jwtToken = (sessionInfo["sessionTokenJWT"] as? String) ?? ""
            if !jwtToken.isEmpty {
                sessionToken = (sessionInfo["sessionToken"] as? String) ?? ""
                refreshToken = (sessionInfo["refreshToken"] as? String) ?? ""
                // TODO session refresh logic
            }
        }
        // firebaseInfo
        var firebaseToken = ""
        if let firebaseInfo = responseJson["firebaseInfo"] as? [String: Any] {
            firebaseToken = (firebaseInfo["firebaseToken"] as? String) ?? ""
        }
      let result = OtplessResult.success(
              token: token,
              sessionTokenJWT: jwtToken.isEmpty ? nil : jwtToken,
              fireBaseToken: firebaseToken.isEmpty ? nil : firebaseToken
          )
      DispatchQueue.main.async { [weak self] in
              self?.delegate?.onConnectResponse(result)
          }
    }
    
    func generateErrorResult(errorDict:[String:Any]){
        sendEvent(event: .nativeWebErrorResult, extras: errorDict)
        let errorType = (errorDict["errorType"] as? String) ?? ErrorTypes.INITIATE
        let errorMessage = (errorDict["errorMessage"] as? String) ?? ErrorMessages.UnknownErrorMessage
        let errorCode = (errorDict["errorCode"] as? Int)
            ?? Int(errorDict["errorCode"] as? String ?? "-1")
            ?? -1
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.onConnectResponse(OtplessResult.error(errorType: errorType, errorCode: errorCode, errorMessage: errorMessage))
        }
    }
    
}


@objc public protocol ConnectResponseDelegate: NSObjectProtocol {
    func onConnectResponse(_ response: OtplessResult)
}

@objc public protocol OnEventDelegate: AnyObject {
    func onEvent(_ event: OtplessEventData)
}
