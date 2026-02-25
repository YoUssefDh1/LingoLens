import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

class FeedbackService {
  static final AudioPlayer _player = AudioPlayer();

  static Future<void> click({bool sound = true, bool vibration = true}) async {
    if (sound) {
      await _player.play(AssetSource('sounds/click.mp3'), volume: 0.5);
    }
    if (vibration && await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 50, amplitude: 128);
    }
  }
}