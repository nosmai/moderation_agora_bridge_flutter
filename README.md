# moderation_agora_bridge_flutter

Bridge that feeds **Agora RTC** video frames into the **Nosmai Moderation SDK**
so a live broadcast is moderated on-device, in real time.

It is deliberately thin: it ships **no SDK of its own**. The Nosmai Moderation
SDK lives in [`nosmai_moderation_sdk`](https://github.com/nosmai); Agora lives
in `agora_rtc_engine`. This bridge only creates the native Agora engine so it
can tap raw frames natively (no pixels ever cross into Dart) and forwards each
sampled frame to the Nosmai plugin already running in your app. Moderation
results come out of `nosmai_moderation_sdk`'s own `NosmaiLive.results()` stream.

Your existing Agora code changes by **one line**: how you create the engine.

## When to use it

You already stream with Agora and already moderate images/video with
`nosmai_moderation_sdk`, and now you want the **live Agora stream** moderated
too, without rebuilding your Agora setup.

## Install

This package is distributed through **GitHub**, not pub.dev. You already depend
on `agora_rtc_engine` and `nosmai_moderation_sdk`. Leave those exactly as they
are (keep your own versions) and just add the bridge as a **git dependency**:

```yaml
dependencies:
  # ... your existing agora_rtc_engine and nosmai_moderation_sdk stay unchanged ...

  moderation_agora_bridge_flutter:
    git:
      url: https://github.com/nosmai/moderation_agora_bridge_flutter.git
      # ref: v0.0.1   # optional: pin to a tag, branch, or commit
```

Then run:

```sh
flutter pub get
```

The bridge bundles neither package; it uses the `agora_rtc_engine` and
`nosmai_moderation_sdk` already in your app at runtime. It only requires that
your `nosmai_moderation_sdk` includes external-frame support
(`NosmaiLive.startExternal()`).

## Usage

```dart
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:nosmai_moderation_sdk/nosmai_moderation_sdk.dart';
import 'package:moderation_agora_bridge_flutter/moderation_agora_bridge_flutter.dart';

late RtcEngine engine;
StreamSubscription<NosmaiResult>? sub;

Future<void> startModeratedStream() async {
  // 1. Nosmai Moderation, exactly as usual.
  await NosmaiModeration.initialize(licenseKey, models: [
    NosmaiModel.objectDetection,
    NosmaiModel.nsfw,
  ]);

  // 2. Start live detection in EXTERNAL-frame mode (no device camera; the
  //    bridge feeds Agora's frames), and listen for verdicts.
  await NosmaiLive.startExternal();
  sub = NosmaiLive.results().listen((r) {
    // r.isUnsafe, r.nsfw, r.detections, ...
  });

  // 3. Create the Agora engine from the bridge's shared native handle.
  //    >>> This is the only line that differs from a normal Agora setup. <<<
  final handle = await ModerationAgoraBridge.getNativeHandle(agoraAppId: appId);
  engine = createAgoraRtcEngine(sharedNativeHandle: handle);

  // 4. ...everything below is your ordinary Agora setup, unchanged...
  await engine.initialize(RtcEngineContext(
    appId: appId,
    channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
  ));
  await engine.enableVideo();
  await engine.startPreview();
  await engine.joinChannel(
    token: token,
    channelId: channel,
    uid: 0,
    options: const ChannelMediaOptions(
      clientRoleType: ClientRoleType.clientRoleBroadcaster,
    ),
  );
}

// On camera switch, switch the shared engine, then notify the bridge:
Future<void> switchCamera() async {
  await engine.switchCamera();
  await ModerationAgoraBridge.notifyCameraSwitch();
}

// Teardown:
Future<void> stopModeratedStream() async {
  await NosmaiLive.stop();
  await sub?.cancel();
  await ModerationAgoraBridge.disposeNative();
  await engine.leaveChannel();
  await engine.release();
}
```

## How it works

`getNativeHandle()` creates the native Agora `RtcEngine` and attaches a
**read-only** video-frame observer to it, then returns the engine's native
handle. You wrap that handle with `createAgoraRtcEngine(sharedNativeHandle:)`, so
your Dart-side Agora calls drive the very engine the bridge is observing.

For each captured frame the observer forwards a sampled subset (about 3/second)
to `nosmai_moderation_sdk` over the in-process JNI / Objective-C runtime; the
frame is never modified, so your outgoing Agora stream is untouched, and no pixel
data crosses the Dart boundary. The Nosmai SDK runs NSFW + object detection and
emits each verdict on `NosmaiLive.results()`.

The bridge links no Nosmai code (reflection) and only needs the Agora native SDK
at compile time (provided by `agora_rtc_engine`), so it stays a pure glue layer.

## Requirements

- `nosmai_moderation_sdk` with external-frame support (`NosmaiLive.startExternal()`).
- `agora_rtc_engine` (Agora RTC 4.x native SDK).
- Android: minSdk 24+, Vulkan-capable device (as required by the Nosmai SDK).
- iOS: a real device (the Nosmai SDK is arm64-only).

## License

Proprietary. Requires a Nosmai Moderation license key.
