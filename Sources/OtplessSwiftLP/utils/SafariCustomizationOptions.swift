//
//  SafariCustomizationOptions.swift
//  OtplessSwiftLP
//
//  Created by Sparsh on 30/04/25.
//


import SafariServices
import UIKit

public struct SafariCustomizationOptions {
    public var preferredBarTintColor: UIColor?
    public var preferredControlTintColor: UIColor?
    public var dismissButtonStyle: SFSafariViewController.DismissButtonStyle
    public var modalPresentationStyle: UIModalPresentationStyle?

    public init(
        preferredBarTintColor: UIColor? = nil,
        preferredControlTintColor: UIColor? = nil,
        dismissButtonStyle: SFSafariViewController.DismissButtonStyle = .done,
        modalPresentationStyle: UIModalPresentationStyle? = nil
    ) {
        self.preferredBarTintColor = preferredBarTintColor
        self.preferredControlTintColor = preferredControlTintColor
        self.dismissButtonStyle = dismissButtonStyle
        self.modalPresentationStyle = modalPresentationStyle
    }
}
