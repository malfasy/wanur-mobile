import 'dart:async';

import 'package:flutter/services.dart';

/// Satu event keypad dari glove (keyboard Bluetooth HID).
class KeyPress {
  /// Karakter huruf kecil, misalnya 'f'. Kosong bila tombol tidak menghasilkan karakter.
  final String char;
  final int keyCode;
  final bool isDown;

  /// Waktu dinding (epoch ms). Untuk sumber nyata dikonversi dari `KeyEvent.eventTime`.
  final int tMs;
  final int? deviceId;

  const KeyPress({
    required this.char,
    required this.isDown,
    required this.tMs,
    this.keyCode = 0,
    this.deviceId,
  });

  String get action => isDown ? 'down' : 'up';

  @override
  String toString() => 'KeyPress($char $action @$tMs)';
}

/// Satu sampel gaya dari loadcell (HX711).
class ForceSample {
  /// Nilai mentah dari firmware (diasumsikan gram).
  final int raw;
  final int tMs;

  const ForceSample({required this.raw, required this.tMs});

  /// Konversi gaya: hxValue / 1000, diperlakukan sebagai nilai relatif (kg*).
  double get kg => raw / 1000.0;
}

/// Sumber data glove. Ada dua implementasi: glove nyata dan simulasi.
abstract class GloveDataSource {
  String get id; // 'real' atau 'sim'
  Stream<KeyPress> get keyEvents;
  Stream<ForceSample> get forceSamples;
  Stream<bool> get connectionState;
  bool get isConnected;

  /// Petunjuk fase tes genggam. Hanya dipakai sumber simulasi supaya nilai gaya
  /// naik saat layar meminta "Genggam kuat". Sumber nyata mengabaikannya.
  void hintGripPhase(bool gripping) {}
}

/// Stream key event dari `MainActivity.dispatchKeyEvent` lewat EventChannel.
class KeyEventChannel {
  static const EventChannel _channel = EventChannel('wanur/key_events');
  static Stream<KeyPress>? _stream;

  static Stream<KeyPress> get stream {
    return _stream ??= _channel
        .receiveBroadcastStream()
        .map(parse)
        .where((k) => k != null)
        .cast<KeyPress>()
        .handleError((Object e) {
      // MissingPluginException di platform selain Android: abaikan.
    }).asBroadcastStream();
  }

  static KeyPress? parse(dynamic raw) {
    if (raw is! Map) return null;
    final action = raw['action'];
    if (action != 'down' && action != 'up') return null;
    final wall = raw['wallTimeMs'];
    return KeyPress(
      char: (raw['char'] as String? ?? '').toLowerCase(),
      keyCode: (raw['keyCode'] as num?)?.toInt() ?? 0,
      isDown: action == 'down',
      tMs: wall is num ? wall.toInt() : DateTime.now().millisecondsSinceEpoch,
      deviceId: (raw['deviceId'] as num?)?.toInt(),
    );
  }
}
