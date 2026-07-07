import 'package:flutter/services.dart';

import 'moderation_agora_bridge_flutter_platform_interface.dart';

/// Default [ModerationAgoraBridgePlatform] over a [MethodChannel].
class MethodChannelModerationAgoraBridge extends ModerationAgoraBridgePlatform {
  final MethodChannel _channel =
      const MethodChannel('moderation_agora_bridge_flutter');

  @override
  Future<int> getNativeHandle(String agoraAppId) async {
    // The native handle is an intptr_t; it arrives as a 64-bit int.
    final handle = await _channel
        .invokeMethod<int>('getNativeHandle', {'appId': agoraAppId});
    return handle ?? 0;
  }

  @override
  Future<void> notifyCameraSwitch() =>
      _channel.invokeMethod<void>('notifyCameraSwitch');

  @override
  Future<void> disposeNative() => _channel.invokeMethod<void>('disposeNative');
}
