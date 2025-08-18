//
//  OtplessViewExtensions.swift
//  OtplessSDK
//
//  Created by Sparsh on 28/03/24.
//

import Foundation
import UIKit
import WebKit

extension OtplessView: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == self.messageName {
            bridge.parseScriptMessage(message: message, webview: self.mWebView)
        }
    }
}

extension OtplessView: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard let urlError = error as? URLError else {
            // Handle other types of errors if needed
            
            return
        }
        
        let errorDict = [
            "errorCode": String(urlError.code.rawValue),
            "description": error.localizedDescription,
            "message": getMessage(fromErrorCode: urlError.code)
        ]
        // todo send failed to load event and response
            
//            OtplessLogger.log(string: "No internet connection", type: "No internet connection.")
            // todo log
        
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // todo handle success case
//        OtplessHelper.sendEvent(event: EventConstants.WEBVIEW_URL_LOAD_SUCCESS)
        
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        
     
        guard let urlError = error as? URLError else {
            // Handle other types of errors if needed
            
            return
        }
        
        let errorDict = [
            "errorCode": String(urlError.code.rawValue),
            "description": error.localizedDescription,
            "message": getMessage(fromErrorCode: urlError.code)
        ]
        
//        OtplessHelper.sendEvent(event: EventConstants.WEBVIEW_URL_LOAD_FAIL, extras: errorDict)
        
        // todo send the response back to client and event
    }

    private func getMessage(fromErrorCode code: URLError.Code) -> String {
        switch code {
        case .unknown:
            return "An unknown error occurred."
        case .cancelled:
            return "The request was cancelled."
        case .badURL:
            return "The URL is malformed."
        case .timedOut:
            return "The request timed out."
        case .unsupportedURL:
            return "The URL is not supported."
        case .cannotFindHost:
            return "The host could not be found."
        case .cannotConnectToHost:
            return "Cannot connect to the host."
        case .networkConnectionLost:
            return "The network connection was lost."
        case .dnsLookupFailed:
            return "The DNS lookup failed."
        case .httpTooManyRedirects:
            return "Too many HTTP redirects occurred."
        case .resourceUnavailable:
            return "The requested resource is unavailable."
        case .notConnectedToInternet:
            return "It appears you are not connected to the Internet."
        case .redirectToNonExistentLocation:
            return "Redirected to a non-existent location."
        case .badServerResponse:
            return "Received an invalid response from the server."
        case .userCancelledAuthentication:
            return "The user cancelled authentication."
        case .userAuthenticationRequired:
            return "Authentication is required to proceed."
        case .zeroByteResource:
            return "The resource is empty."
        case .cannotDecodeRawData:
            return "Cannot decode raw data."
        case .cannotDecodeContentData:
            return "Cannot decode content data."
        case .cannotParseResponse:
            return "Cannot parse the server response."
        case .appTransportSecurityRequiresSecureConnection:
            return "App Transport Security requires a secure connection."
        case .fileDoesNotExist:
            return "The specified file does not exist."
        case .fileIsDirectory:
            return "The specified file is a directory."
        case .noPermissionsToReadFile:
            return "No permission to read the file."
        case .dataLengthExceedsMaximum:
            return "The data length exceeds the maximum allowed."
        case .secureConnectionFailed:
            return "A secure connection could not be established."
        case .serverCertificateHasBadDate:
            return "The server certificate has an invalid date."
        case .serverCertificateUntrusted:
            return "The server certificate is untrusted."
        case .serverCertificateHasUnknownRoot:
            return "The server certificate has an unknown root."
        case .serverCertificateNotYetValid:
            return "The server certificate is not yet valid."
        case .clientCertificateRejected:
            return "The client certificate was rejected."
        case .clientCertificateRequired:
            return "A client certificate is required."
        case .cannotLoadFromNetwork:
            return "Cannot load data from the network."
        case .cannotCreateFile:
            return "Cannot create the specified file."
        case .cannotOpenFile:
            return "Cannot open the specified file."
        case .cannotCloseFile:
            return "Cannot close the specified file."
        case .cannotWriteToFile:
            return "Cannot write to the specified file."
        case .cannotRemoveFile:
            return "Cannot remove the specified file."
        case .cannotMoveFile:
            return "Cannot move the specified file."
        case .downloadDecodingFailedMidStream:
            return "Download decoding failed mid-stream."
        case .downloadDecodingFailedToComplete:
            return "Download decoding failed to complete."
        case .internationalRoamingOff:
            return "International roaming is turned off."
        case .callIsActive:
            return "A call is currently active."
        case .dataNotAllowed:
            return "Data usage is not allowed."
        case .requestBodyStreamExhausted:
            return "The request body stream is exhausted."
        case .backgroundSessionRequiresSharedContainer:
            return "A background session requires a shared container."
        case .backgroundSessionInUseByAnotherProcess:
            return "The background session is in use by another process."
        case .backgroundSessionWasDisconnected:
            return "The background session was disconnected."
        default:
            return "Something Went Wrong!."
        }
    }
}


extension OtplessView: UIScrollViewDelegate {
    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        scrollView.pinchGestureRecognizer?.isEnabled = false
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return nil
    }
}
