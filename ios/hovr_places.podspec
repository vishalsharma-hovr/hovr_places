#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
#
Pod::Spec.new do |s|
  s.name             = 'hovr_places'
  s.version          = '0.1.0'
  s.summary          = 'Native Google Places autocomplete for HOVR Flutter apps.'
  s.description      = <<-DESC
Method-channel Google Places autocomplete and place details. The API key stays on the host native side.
                       DESC
  s.homepage         = 'https://github.com/vishalsharma-hovr/hovr_places'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'HOVR' => 'dev@ridehovr.com' }
  s.source           = { :path => '.' }
  s.source_files = 'hovr_places/Sources/hovr_places/**/*.swift'
  s.resource_bundles = {
    'hovr_places_privacy' => ['hovr_places/Sources/hovr_places/PrivacyInfo.xcprivacy']
  }
  s.dependency 'Flutter'
  s.dependency 'GooglePlaces', '>= 9.0'
  s.platform = :ios, '16.0'
  s.static_framework = true

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'IPHONEOS_DEPLOYMENT_TARGET' => '16.0'
  }
  s.swift_version = '5.0'

  s.test_spec 'Tests' do |test_spec|
    test_spec.source_files = 'hovr_places/Tests/**/*'
  end
end
