Pod::Spec.new do |s|
    s.name             = 'OtplessSwiftLP'
    s.version          = '1.0.8'
    s.summary          = 'A Swift SDK for integrating Otpless Pre Build UI.'
  
    s.description      = <<-DESC
                          OtplessSwiftLP is a Swift-based SDK that enables seamless 
                          integration with the Otpless platform for user authentication, using the Pre Built UI provided by Otpless.
                         DESC
  
    s.homepage         = 'https://github.com/otpless-tech/iOS-LP.git'
    s.license          = { :type => 'MIT', :file => 'LICENSE' }
    s.author           = { 'Sparsh' => 'sparsh.chadha@otpless.com' }
    s.source           = { :git => 'https://github.com/otpless-tech/iOS-LP.git', :tag => s.version.to_s }
  
    s.platform         = :ios, '13.0'
    s.swift_version    = '5.9'
  
    s.source_files     = 'Sources/OtplessSwiftLP/**/*.{swift}'

    s.resource_bundles = {
        'OtplessSwiftLP' => ['Sources/PrivacyInfo.xcprivacy']
    }
  
    s.dependency 'Socket.IO-Client-Swift', '~> 16.1.1'
  end
  
