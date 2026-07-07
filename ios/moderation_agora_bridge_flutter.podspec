#
# Run `pod lib lint moderation_agora_bridge_flutter.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'moderation_agora_bridge_flutter'
  s.version          = '0.0.1'
  s.summary          = 'Bridge Agora RTC video into the Nosmai Moderation SDK for Flutter.'
  s.description      = <<-DESC
Feeds Agora RTC captured frames into the Nosmai Moderation SDK for on-device,
real-time live-stream moderation. Ships no models and no SDK — the Nosmai
Moderation SDK lives in the nosmai_moderation_sdk plugin.
                       DESC
  s.homepage         = 'https://github.com/nosmai/moderation_agora_bridge_flutter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Nosmai' => 'admin@nosmai.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*.{h,m}'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  # Depend on the app's Agora Flutter plugin (not the raw AgoraRtcEngine_iOS pod)
  # so we compile against the SAME Agora it vends (AgoraRtcKit) and do not pull a
  # second copy of the Agora xcframeworks — which would clash by name. The Nosmai
  # SDK is reached over the ObjC runtime, so it is NOT declared here.
  s.dependency 'agora_rtc_engine'
  s.platform = :ios, '13.0'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
end
