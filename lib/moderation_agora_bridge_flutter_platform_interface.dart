import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'moderation_agora_bridge_flutter_method_channel.dart';

abstract class ModerationAgoraBridgePlatform extends PlatformInterface {
  ModerationAgoraBridgePlatform() : super(token: _token);

  static final Object _token = Object();

  static ModerationAgoraBridgePlatform _instance =
      MethodChannelModerationAgoraBridge();

  static ModerationAgoraBridgePlatform get instance => _instance;

  static set instance(ModerationAgoraBridgePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<int> getNativeHandle(String agoraAppId) {
    throw UnimplementedError('getNativeHandle() has not been implemented.');
  }

  Future<void> notifyCameraSwitch() {
    throw UnimplementedError('notifyCameraSwitch() has not been implemented.');
  }

  Future<void> disposeNative() {
    throw UnimplementedError('disposeNative() has not been implemented.');
  }
}
