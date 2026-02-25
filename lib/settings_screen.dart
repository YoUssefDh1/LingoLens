import 'package:flutter/material.dart';
import 'app_localizations.dart';
import 'services/feedback_service.dart';

class SettingsScreen extends StatefulWidget {
  final Function(bool)? toggleTheme;
  final Function(String)? changeLanguage;
  final Function(bool)? toggleSound;
  final Function(bool)? toggleVibration;
  final bool initialDarkMode;
  final String initialLanguage;
  final bool initialSound;
  final bool initialVibration;

  const SettingsScreen({
    super.key,
    this.toggleTheme,
    this.changeLanguage,
    this.toggleSound,
    this.toggleVibration,
    this.initialDarkMode = false,
    this.initialLanguage = 'en',
    this.initialSound = true,
    this.initialVibration = true,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDarkMode = false;
  String _language = "en";
  bool _soundOn = true;
  bool _vibrationOn = true;

  @override
  void initState() {
    super.initState();
    // Initialize local state from values passed by HomeScreen/Main
    _isDarkMode = widget.initialDarkMode;
    _language = widget.initialLanguage;
    _soundOn = widget.initialSound;
    _vibrationOn = widget.initialVibration;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(_language);
    return Scaffold(
      appBar: AppBar(title: Text(t['settings'] ?? 'Settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListView(
                padding: const EdgeInsets.all(20),
                shrinkWrap: true,
                children: [
                  SwitchListTile(
                    title: Text(t['darkMode'] ?? 'Dark Mode'),
                    value: _isDarkMode,
                    onChanged: (val) {
                      setState(() => _isDarkMode = val);
                      widget.toggleTheme?.call(val);
                      FeedbackService.click(sound: _soundOn, vibration: _vibrationOn);
                    },
                    secondary: const Icon(Icons.brightness_6),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.language),
                    title: Text(t['appLanguage'] ?? 'App Language'),
                    trailing: DropdownButton<String>(
                      value: _language,
                      items: [
                        DropdownMenuItem(value: 'en', child: Text(t['lang_en'] ?? 'English')),
                        DropdownMenuItem(value: 'fr', child: Text(t['lang_fr'] ?? 'French')),
                        DropdownMenuItem(value: 'ar', child: Text(t['lang_ar'] ?? 'Arabic')),
                      ],
                      onChanged: (val) {
                        if (val == null) return;
                        setState(() => _language = val);
                        widget.changeLanguage?.call(val);
                        FeedbackService.click(sound: _soundOn, vibration: _vibrationOn);
                      },
                    ),
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: Text(t['soundEffects'] ?? 'Sound Effects'),
                    value: _soundOn,
                    onChanged: (val) {
                      setState(() => _soundOn = val);
                      widget.toggleSound?.call(val);
                      FeedbackService.click(sound: val, vibration: _vibrationOn);
                    },
                    secondary: const Icon(Icons.volume_up),
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: Text(t['vibration'] ?? 'Vibration'),
                    value: _vibrationOn,
                    onChanged: (val) {
                      setState(() => _vibrationOn = val);
                      widget.toggleVibration?.call(val);
                      FeedbackService.click(sound: _soundOn, vibration: val);
                    },
                    secondary: const Icon(Icons.vibration),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}