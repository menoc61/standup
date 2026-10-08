import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  final AudioPlayer _player = AudioPlayer();
  bool soundEnabled = true;

  /// The reminder tone chosen in Preferences. Reminder events play this sound
  /// while celebrations keep their own dedicated cue.
  String selectedSound = 'chime';

  /// Volume applied to every cue, scaled from the Preferences slider.
  double volume = 1.0;

  static const Map<String, String> soundAssets = {
    'chime': 'sounds/chime.wav',
    'success': 'sounds/success.wav',
    'nudge': 'sounds/nudge.wav',
    'click': 'sounds/click.wav',
  };

  AudioService({this.soundEnabled = true}) {
    _init();
  }

  void _init() {
    _player.setReleaseMode(ReleaseMode.stop);
  }

  /// Plays one of the bundled cues by key. Unknown keys fall back to the chime
  /// so a stale preference can never silence the reminders.
  Future<void> playSound(String key, {double? volume}) async {
    if (!soundEnabled) return;
    final asset = soundAssets[key] ?? soundAssets['chime']!;
    try {
      await _player.stop();
      await _player.play(
        AssetSource(asset),
        volume: (volume ?? this.volume).clamp(0.0, 1.0),
      );
    } catch (e) {
      debugPrint('AudioService $key error: $e');
    }
  }

  Future<void> playChime() => playSound(selectedSound, volume: 0.85);

  Future<void> playSuccess() async {
    if (!soundEnabled) return;
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/success.wav'), volume: 0.9);
    } catch (e) {
      debugPrint('AudioService success error: $e');
    }
  }

  Future<void> playNudge() async {
    if (!soundEnabled) return;
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/nudge.wav'), volume: 0.8);
    } catch (e) {
      debugPrint('AudioService nudge error: $e');
    }
  }

  Future<void> playClick() async {
    if (!soundEnabled) return;
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/click.wav'), volume: 0.4);
    } catch (e) {
      debugPrint('AudioService click error: $e');
    }
  }

  void dispose() {
    _player.dispose();
  }
}
