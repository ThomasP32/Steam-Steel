import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

class AudioService {
  factory AudioService() => _instance;
  AudioService._internal();
  static final AudioService _instance = AudioService._internal();

  final AudioPlayer _musicPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();

  bool _isMusicEnabled = false;
  bool _isSfxEnabled = true;
  bool _isHostControlled = false;
  String _equippedMusic = 'music2.mp3'; // Default music

  final ValueNotifier<bool> musicEnabledNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> sfxEnabledNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<bool> isHostControlledNotifier = ValueNotifier<bool>(
    false,
  );
  final ValueNotifier<String> equippedMusicNotifier = ValueNotifier<String>(
    'music2.mp3',
  );

  bool get isMusicEnabled => _isMusicEnabled;
  bool get isSfxEnabled => _isSfxEnabled;

  bool get musicEnabled => _isMusicEnabled;
  // ignore: unnecessary_getters_setters : dont worry
  bool get sfxEnabled => _isSfxEnabled;
  String get equippedMusic => _equippedMusic;

  void setEquippedMusic(String filename) {
    _equippedMusic = filename;
    equippedMusicNotifier.value = filename;
    // If music is currently playing, switch to the new track
    if (_isMusicEnabled &&
        _musicPlayer.playerState.processingState != ProcessingState.idle) {
      playBackgroundMusic(filename);
    }
  }

  Future<void> playBackgroundMusic(String filename) async {
    if (!_isMusicEnabled) return;
    try {
      await _musicPlayer.setLoopMode(LoopMode.one);
      await _musicPlayer.setVolume(0.5);
      await _musicPlayer.setAsset('lib/assets/sounds/$filename');
      await _musicPlayer.play();
      debugPrint('Successfully playing background music: $filename');
      debugPrint('Player state: ${_musicPlayer.playerState}');
      debugPrint('Player volume: ${_musicPlayer.volume}');
    } on Exception catch (e) {
      debugPrint('Error playing background music: $e');
    }
  }

  Future<void> stopMusic() async {
    _isMusicEnabled = false;
    musicEnabledNotifier.value = false;
    await _musicPlayer.stop();
  }

  Future<void> pauseMusic() async {
    await _musicPlayer.pause();
  }

  Future<void> resumeMusic() async {
    await _musicPlayer.play();
  }

  Future<void> playSfx(String filename) async {
    if (!_isSfxEnabled) return;
    try {
      unawaited(
        _sfxPlayer.setAsset('lib/assets/sounds/$filename').then((_) {
          _sfxPlayer.play();
        }),
      );
    } on Exception catch (e) {
      debugPrint('Error playing sound effect: $e');
    }
  }

  set musicEnabled(bool enabled) {
    _isMusicEnabled = enabled;
    musicEnabledNotifier.value = enabled;
    if (enabled) {
      if (_musicPlayer.playerState.processingState == ProcessingState.idle) {
        playBackgroundMusic(_equippedMusic);
      } else {
        resumeMusic();
      }
    } else {
      pauseMusic();
    }
  }

  set sfxEnabled(bool enabled) {
    _isSfxEnabled = enabled;
    sfxEnabledNotifier.value = enabled;
  }

  void setHostControlledSettings({
    required bool musicEnabled,
    required bool sfxEnabled,
  }) {
    _isHostControlled = true;
    isHostControlledNotifier.value = true;
    this.musicEnabled = musicEnabled;
    this.sfxEnabled = sfxEnabled;
  }

  void clearHostControl() {
    _isHostControlled = false;
    isHostControlledNotifier.value = false;
  }

  bool get isHostControlled => _isHostControlled;

  void dispose() {
    _musicPlayer.dispose();
    _sfxPlayer.dispose();
    musicEnabledNotifier.dispose();
    sfxEnabledNotifier.dispose();
    isHostControlledNotifier.dispose();
    equippedMusicNotifier.dispose();
  }
}
