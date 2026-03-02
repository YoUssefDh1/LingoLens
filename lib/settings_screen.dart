import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_localizations.dart';
import 'services/feedback_service.dart';
import 'services/notification_service.dart';

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
  String _language = 'en';
  bool _soundOn = true;
  bool _vibrationOn = true;
  bool _isLoggedIn = false;
  bool _notificationsOn = false;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.initialDarkMode;
    _language = widget.initialLanguage;
    _soundOn = widget.initialSound;
    _vibrationOn = widget.initialVibration;
    _loadLoginState();
    _loadNotificationPrefs();
  }

  Future<void> _loadLoginState() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final prefs = await SharedPreferences.getInstance();
    final localLoggedIn = prefs.getBool('loggedIn') ?? false;
    if (!mounted) return;
    setState(() {
      _isLoggedIn = firebaseUser != null || localLoggedIn;
    });
  }

  Future<void> _loadNotificationPrefs() async {
    final enabled = await NotificationService.loadPreferences();
    if (!mounted) return;
    setState(() => _notificationsOn = enabled);
  }

  Future<void> _handleLogout(Map<String, String> loc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc['logoutConfirmTitle'] ?? 'Log Out'),
        content: Text(
            loc['logoutConfirmContent'] ?? 'Are you sure you want to log out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(loc['cancel'] ?? 'Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(loc['logout'] ?? 'Log Out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await FeedbackService.signOut();
    if (!mounted) return;

    setState(() => _isLoggedIn = false);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(loc['loggedOut'] ?? 'You have been logged out'),
      behavior: SnackBarBehavior.floating,
    ));

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(_language);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(loc['settings'] ?? 'Settings',
            style: const TextStyle(color: Colors.white)),
      ),
      body: SizedBox.expand(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? const [Color(0xFF022C33), Color(0xFF064E63), Color(0xFF0B7285)]
                  : const [Color(0xFF0EA5A4), Color(0xFF12B4CF), Color(0xFF0F9FB8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF020617).withValues(alpha: 0.85)
                          : Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 28,
                          offset: const Offset(0, 18),
                        ),
                      ],
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.white.withValues(alpha: 0.6),
                        width: 1.2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Dark mode
                            SwitchListTile(
                              title: Text(loc['darkMode'] ?? 'Dark Mode'),
                              value: _isDarkMode,
                              secondary: const Icon(Icons.brightness_6),
                              onChanged: (val) {
                                setState(() => _isDarkMode = val);
                                widget.toggleTheme?.call(val);
                                FeedbackService.click(
                                    sound: _soundOn, vibration: _vibrationOn);
                              },
                            ),
                            const Divider(),

                            // Language
                            ListTile(
                              leading: const Icon(Icons.language),
                              title: Text(loc['appLanguage'] ?? 'App Language'),
                              trailing: DropdownButton<String>(
                                value: _language,
                                items: [
                                  DropdownMenuItem(
                                      value: 'en',
                                      child: Text(loc['lang_en'] ?? 'English')),
                                  DropdownMenuItem(
                                      value: 'fr',
                                      child: Text(loc['lang_fr'] ?? 'French')),
                                  DropdownMenuItem(
                                      value: 'ar',
                                      child: Text(loc['lang_ar'] ?? 'Arabic')),
                                ],
                                onChanged: (val) {
                                  if (val == null) return;
                                  setState(() => _language = val);
                                  widget.changeLanguage?.call(val);
                                  FeedbackService.click(
                                      sound: _soundOn, vibration: _vibrationOn);
                                },
                              ),
                            ),
                            const Divider(),

                            // Sound
                            SwitchListTile(
                              title: Text(loc['soundEffects'] ?? 'Sound Effects'),
                              value: _soundOn,
                              secondary: const Icon(Icons.volume_up),
                              onChanged: (val) {
                                setState(() => _soundOn = val);
                                widget.toggleSound?.call(val);
                                FeedbackService.click(
                                    sound: val, vibration: _vibrationOn);
                              },
                            ),
                            const Divider(),

                            // Vibration
                            SwitchListTile(
                              title: Text(loc['vibration'] ?? 'Vibration'),
                              value: _vibrationOn,
                              secondary: const Icon(Icons.vibration),
                              onChanged: (val) {
                                setState(() => _vibrationOn = val);
                                widget.toggleVibration?.call(val);
                                FeedbackService.click(
                                    sound: _soundOn, vibration: val);
                              },
                            ),
                            const Divider(),

                            // Notifications toggle
                            SwitchListTile(
                              title: Text(loc['notifications'] ?? 'Daily Reminders'),
                              subtitle: Text(
                                loc['notificationsSubtitle'] ?? '10:00 AM & 9:00 PM',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                ),
                              ),
                              secondary: const Icon(Icons.notifications_outlined),
                              value: _notificationsOn,
                              onChanged: (val) async {
                                setState(() => _notificationsOn = val);
                                FeedbackService.click(
                                    sound: _soundOn, vibration: _vibrationOn);
                                if (val) {
                                  await NotificationService.scheduleDefaultReminders(
                                    title: 'LingoLens AI',
                                    body: loc['notificationBody'] ??
                                        'Time to translate something new today! 📸',
                                  );
                                } else {
                                  await NotificationService.cancelAll();
                                }
                                await NotificationService.savePreferences(
                                    enabled: val);
                              },
                            ),

                            // Logout — only when logged in
                            if (_isLoggedIn) ...[
                              const Divider(),
                              ListTile(
                                leading: const Icon(Icons.logout,
                                    color: Colors.redAccent),
                                title: Text(loc['logout'] ?? 'Log Out',
                                    style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontWeight: FontWeight.w600)),
                                onTap: () => _handleLogout(loc),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}