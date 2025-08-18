//
//  OtplessHelper.swift
//  OtplessSDK
//
//  Created by Otpless on 06/02/23.
//

import Foundation
import UIKit

class OtplessHelper {
    
  public static func checkValueExists(forKey key: String) -> Bool {
        return UserDefaults.standard.object(forKey: key) != nil
    }

    public static func getValue<T>(forKey key: String) -> T? {
        return UserDefaults.standard.object(forKey: key) as? T
    }
    
    public static func setValue<T>(value: T?, forKey key: String) {
            UserDefaults.standard.set(value, forKey: key)
        }
    
    public static func removeValue(forKey key: String) {
        UserDefaults.standard.removeObject(forKey: key)
    }
    
    public static func UIColorFromRGB(rgbValue: UInt) -> UIColor {
        return UIColor(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
        )
    }
}
