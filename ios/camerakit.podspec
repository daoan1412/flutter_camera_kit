#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint camerakit.podspec' to validate before publishing.
#

Pod::Spec.new do |s|
  s.name             = 'camerakit'
  s.version          = '0.0.1'
  s.summary          = 'Camera kit for flutter'

  s.description      = <<-DESC
Camera kit for flutter
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'

  s.platform = :ios, '10.0'


  # Flutter.framework does not contain a i386 slice. Only x86_64 simulators are supported.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'VALID_ARCHS[sdk=iphonesimulator*]' => 'x86_64' }
  s.swift_version = '5.0'
  

#  s.dependency 'GoogleMLKit'
  s.dependency 'GoogleMLKit/BarcodeScanning'
  s.dependency 'GoogleMLKit/FaceDetection'
  s.dependency 'Flutter'
  s.static_framework = true
  
end
