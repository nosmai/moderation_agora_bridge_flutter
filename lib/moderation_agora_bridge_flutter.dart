import 'moderation_agora_bridge_flutter_platform_interface.dart';

/// Bridges an Agora RTC video stream into the Nosmai Moderation SDK so a live
/// broadcast is moderated on-device, in real time.
///
/// The Nosmai Moderation SDK and its models live in the `nosmai_moderation_sdk`
/// package; this bridge ships neither. It only creates the native Agora engine
/// (so it can tap raw frames natively, with no pixels crossing into Dart) and
/// forwards each frame to the Nosmai plugin already running in the app.
/// Moderation results come out of `nosmai_moderation_sdk`'s own
/// `NosmaiLive.results()` stream.
///
/// Only one line of an existing Agora setup changes — `createAgoraRtcEngine`:
/// ```dart
/// // 1. Nosmai Moderation as usual (loads the SDK + models once):
/// await NosmaiModeration.initialize(licenseKey, models: [...]);
/// await NosmaiLive.startExternal();               // native stream, no camera
/// final sub = NosmaiLive.results().listen((r) { /* r.isUnsafe, r.nsfw, ... */ });
///
/// // 2. Create the Agora engine from the bridge's shared native handle:
/// final handle = await ModerationAgoraBridge.getNativeHandle(agoraAppId: appId);
/// final engine = createAgoraRtcEngine(sharedNativeHandle: handle);
///
/// // 3. ... the rest of the Agora setup (initialize / join / preview) is unchanged ...
///
/// // On camera switch, tell the bridge so orientation stays correct:
/// await engine.switchCamera();
/// await ModerationAgoraBridge.notifyCameraSwitch();
///
/// // Teardown:
/// await NosmaiLive.stop();
/// await ModerationAgoraBridge.disposeNative();
/// await engine.leaveChannel();
/// await engine.release();
/// ```
class ModerationAgoraBridge {
  ModerationAgoraBridge._();

  /// Creates the native Agora engine with a read-only Nosmai frame observer
  /// attached, and returns its native handle. Pass the handle straight to
  /// `createAgoraRtcEngine(sharedNativeHandle: handle)`.
  static Future<int> getNativeHandle({required String agoraAppId}) =>
      ModerationAgoraBridgePlatform.instance.getNativeHandle(agoraAppId);

  /// Call right after `engine.switchCamera()` so moderation stays correct on the
  /// newly selected camera.
  static Future<void> notifyCameraSwitch() =>
      ModerationAgoraBridgePlatform.instance.notifyCameraSwitch();

  /// Detaches the frame observer and destroys the native Agora engine the bridge
  /// created. Call during teardown, before releasing the Flutter engine.
  static Future<void> disposeNative() =>
      ModerationAgoraBridgePlatform.instance.disposeNative();
}
