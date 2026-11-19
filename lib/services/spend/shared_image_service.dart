// services/shared_image_service.dart
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// One image shared into the app. [path] is null when the share arrived
// but the native side couldn't read the image — the listener should then
// fall back to the blank add-expense sheet and say so.
class SharedImage {
  const SharedImage(this.path);

  final String? path;

  bool get failed => path == null;

  // Removes the cached copy. Call once the receipt has been handled
  // (saved, dismissed or failed) — the native side only clears files
  // older than a day.
  Future<void> discard() async {
    final p = path;
    if (p == null) return;
    try {
      final file = File(p);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Best effort — the cache is cleaned up later anyway.
    }
  }
}

// Receives images shared into the app from other apps (GPay, PhonePe...).
//
// The native side (MainActivity.kt) copies the shared image into the
// app's cache off the main thread and reports its path. To make sure
// nothing is sent before Dart is listening, startup is a handshake:
// 1. Dart registers the 'sharedImage' handler.
// 2. Dart calls 'ready'. Native answers with a share that was waiting
//    (the one that launched the app), if any, and from then on pushes
//    new shares through 'sharedImage'.
//
// A path of "" (empty string) means a share arrived but couldn't be
// read, and shows up here as a [SharedImage] with a null path.
class SharedImageService {
  SharedImageService._();
  static final SharedImageService instance = SharedImageService._();

  static const _channel = MethodChannel('taskflow/share');

  // The share waiting to be handled; null when none. A new instance is
  // created for every share, so listeners fire even if two shares carry
  // the same path.
  final ValueNotifier<SharedImage?> pending = ValueNotifier<SharedImage?>(null);

  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    // 1. Handler first, so a push can never arrive unheard.
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'sharedImage') {
        _accept(call.arguments as String?);
      }
      return null;
    });

    // 2. Then announce we're ready and pick up a waiting share.
    try {
      final waiting = await _channel.invokeMethod<String>('ready');
      _accept(waiting);
    } on PlatformException catch (_) {
      // Native side unavailable — nothing can be shared in; carry on.
    } on MissingPluginException catch (_) {
      // Not running on Android (or an old native build) — same.
    }
  }

  void _accept(String? path) {
    if (path == null) return; // nothing was waiting
    // "" = the share couldn't be read: report it as a failed share.
    pending.value = SharedImage(path.isEmpty ? null : path);
  }

  // Takes the pending share and clears it, so each share is handled once.
  SharedImage? take() {
    final shared = pending.value;
    pending.value = null;
    return shared;
  }
}
