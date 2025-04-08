# OtplessSwiftLP

This guide will walk you through integrating the `OtplessSwiftLP` SDK in your iOS project using CocoaPods.

---

## Step 1: SDK Installation

### Option A: Using CocoaPods

1. Add the following to your `Podfile`:

    ```ruby
    pod 'OtplessSwiftLP'
    ```

2. Then run:

    ```bash
    pod install
    ```

### Option B: Using Swift Package Manager (SPM)

1. Open your project in Xcode.

2. Go to `File` → `Add Packages...`.

3. Enter the repository URL:

    ```
    https://github.com/otpless-tech/iOS-LP.git
    ```

4. Choose **"Exact version"**, select the latest version that is displayed there and click **Add Package**.

---

## Step 2: Setup SDK in your App

Add the following keys in your `info.plist` file: 

```xml info.plist
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>otpless.{{YOUR_APP_ID}}</string>
        </array>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>otpless</string>
    </dict>
</array>
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>whatsapp</string>
    <string>otpless</string>
    <string>gootpless</string>
    <string>com.otpless.ios.app.otpless</string>
    <string>googlegmail</string>
</array>
```

Import the SDK at the top of your `ViewController.swift`:

```swift
import OtplessSwiftLP
```

---

## Step 3: Implement the ConnectResponseDelegate

Your `ViewController` should conform to `ConnectResponseDelegate`:

```swift LoginViewController.swift
func onConnectResponse(_ response: [String: Any]) {
    if let error = response["error"] as? String {
        print("Error: \(error)")
    } else if token = response["token"] as? String {
        print("Token: \(token)")
        // Send this token to your server to validate and get user details.
    } else {
        // Unknown error occurred
        print("Unknown response: \(response)")
    }
}
```

---

## Step 4: Initialize the SDK, Set Delegate and Start

Set the response delegate and optionally enable socket logging:

```swift LoginViewController.swift
override func viewDidLoad() {
    super.viewDidLoad()
    
    OtplessSwiftLP.shared.setResponseDelegate(self)

    // Initialize SDK
    OtplessSwiftLP.shared.initialize(appId: "YOUR_APP_ID", secret: "YOUR_SECRET") { success in
        if success {
            // SDK initialization success
        }
    }
}
```

To start the authentication process, use:

```swift
@IBAction private func startButtonTapped() {
    OtplessSwiftLP.shared.start(vc: self)
}
```

---


## Step 5: Stop the process

When your login page is closed or login is successful, stop the Otpless' authentication process: 

```swift LoginViewController.swift
OtplessSwiftLP.shared.cease()
```

**Make sure that `initialize()` is called again if you call `cease()`.**

## 📄 License

MIT © [Otpless](https://otpless.com)

