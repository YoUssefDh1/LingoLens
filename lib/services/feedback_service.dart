import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  /// Sign out from Firebase and clear local storage
  static Future<void> signOut() async {
    try {
      // Sign out from Firebase
      await FirebaseAuth.instance.signOut();
      
      // Clear local login state
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('loggedIn', false);
      await prefs.remove('username');
      await prefs.remove('email');
    } catch (e) {
      print('Error signing out: $e');
    }
  }
}