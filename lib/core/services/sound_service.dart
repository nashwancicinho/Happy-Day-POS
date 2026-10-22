import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

enum PosSound {
  beep,
  cashRegister,
  delete,
  warning,
}

class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  bool isEnabled = true;

  final AudioPlayer _player = AudioPlayer()..setReleaseMode(ReleaseMode.stop);

  Future<void> playBeep() => play(PosSound.beep);
  Future<void> playCashRegister() => play(PosSound.cashRegister);
  Future<void> playDelete() => play(PosSound.delete);
  Future<void> playWarning() => play(PosSound.warning);

  Future<void> play(PosSound sound) async {
    if (!isEnabled) return;
    try {
      String assetName;
      switch (sound) {
        case PosSound.beep:
          assetName = 'sounds/beep.wav';
          break;
        case PosSound.cashRegister:
          assetName = 'sounds/cash_register.wav';
          break;
        case PosSound.delete:
          assetName = 'sounds/delete.wav';
          break;
        case PosSound.warning:
          assetName = 'sounds/warning.wav';
          break;
      }
      await _player.stop();
      await _player.play(AssetSource(assetName));
    } catch (e) {
      debugPrint('SoundService error playing $sound: $e');
    }
  }
}
