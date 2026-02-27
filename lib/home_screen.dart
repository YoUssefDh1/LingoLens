import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/ml_service.dart';
import 'services/feedback_service.dart';
import 'app_localizations.dart';
import 'results_screen.dart';
import 'settings_screen.dart';
import 'translation.dart';
import 'history.dart';

class HomeScreen extends StatefulWidget {
  final Function(bool)? toggleTheme;
  final Function(String)? changeLanguage;
  final bool soundOn;
  final bool vibrationOn;
  final bool isDarkMode;
  final String currentLanguage;
  final Function(bool)? toggleSound;
  final Function(bool)? toggleVibration;

  const HomeScreen({
    super.key,
    this.toggleTheme,
    this.changeLanguage,
    required this.soundOn,
    required this.vibrationOn,
    required this.isDarkMode,
    required this.currentLanguage,
    this.toggleSound,
    this.toggleVibration,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final ImagePicker _picker = ImagePicker();
  final MLService _mlService = MLService();
  bool _isLoading = false;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshLoginState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mlService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshLoginState();
  }

  Future<void> _refreshLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _isLoggedIn = prefs.getBool('loggedIn') ?? false);
  }

  Future<void> _processImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image == null) return;
    setState(() => _isLoading = true);
    final loc = AppLocalizations.of(widget.currentLanguage);
    try {
      final File file = File(image.path);
      final String text = await _mlService.recognizeText(file);
      if (text.trim().isEmpty) {
        throw Exception(loc['noTextDetected'] ?? 'No text detected.');
      }
      final String langCode = await _mlService.identifyLanguage(text);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultsScreen(
            imageFile: file,
            recognizedText: text,
            languageCode: langCode,
            appLanguage: widget.currentLanguage,
            soundOn: widget.soundOn,
            vibrationOn: widget.vibrationOn,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${loc['errorPrefix'] ?? 'Error:'} ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showImageSourceDialog() {
    final loc = AppLocalizations.of(widget.currentLanguage);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(loc['chooseImageSource'] ?? 'Choose Image Source',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: Text(loc['camera'] ?? 'Camera'),
                onTap: () {
                  FeedbackService.click(sound: widget.soundOn, vibration: widget.vibrationOn);
                  Navigator.pop(context);
                  _processImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text(loc['gallery'] ?? 'Gallery'),
                onTap: () {
                  FeedbackService.click(sound: widget.soundOn, vibration: widget.vibrationOn);
                  Navigator.pop(context);
                  _processImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleProfileTap() async {
    final loc = AppLocalizations.of(widget.currentLanguage);
    if (_isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(loc['alreadyLoggedIn'] ?? 'You are already logged in'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    await Navigator.pushNamed(context, '/login');
    _refreshLoginState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final loc = AppLocalizations.of(widget.currentLanguage);

    return DefaultTabController(
      initialIndex: 0,
      length: 3,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          automaticallyImplyLeading: false,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: theme.colorScheme.surface, shape: BoxShape.circle),
                padding: const EdgeInsets.all(6),
                child: ClipOval(child: Image.asset('assets/images/logo.png', fit: BoxFit.contain)),
              ),
              const SizedBox(width: 12),
              Text(loc['appTitle'] ?? 'LingoLens AI',
                  style: const TextStyle(color: Colors.white)),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(_isLoggedIn ? Icons.person : Icons.person_outline, color: Colors.white),
              tooltip: _isLoggedIn
                  ? loc['alreadyLoggedIn'] ?? 'Profile'
                  : loc['logIn'] ?? 'Log In',
              onPressed: _handleProfileTap,
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: loc['settings'] ?? 'Settings',
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SettingsScreen(
                      toggleTheme: widget.toggleTheme,
                      changeLanguage: widget.changeLanguage,
                      toggleSound: widget.toggleSound,
                      toggleVibration: widget.toggleVibration,
                      initialDarkMode: widget.isDarkMode,
                      initialLanguage: widget.currentLanguage,
                      initialSound: widget.soundOn,
                      initialVibration: widget.vibrationOn,
                    ),
                  ),
                );
                _refreshLoginState();
              },
            ),
          ],
          bottom: TabBar(
            indicatorColor: const Color(0xFF004E4E),
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            // Tab labels localized
            tabs: [
              Tab(text: loc['tabScan'] ?? loc['scanText'] ?? 'SCAN'),
              Tab(text: loc['tabTranslations'] ?? loc['translate'] ?? 'TRANSLATIONS'),
              Tab(text: loc['tabHistory'] ?? 'HISTORY'),
            ],
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? const [Color(0xFF022C33), Color(0xFF064E63), Color(0xFF0B7285)]
                  : const [Color(0xFF0EA5A4), Color(0xFF12B4CF), Color(0xFF0F9FB8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF020617).withOpacity(0.85)
                                : Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.35),
                                blurRadius: 28,
                                offset: const Offset(0, 18),
                              ),
                            ],
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withOpacity(0.08)
                                  : Colors.white.withOpacity(0.6),
                              width: 1.2,
                            ),
                          ),
                          child: TabBarView(
                            children: [
                              // ── SCAN ──────────────────────────────────
                              SingleChildScrollView(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Card(
                                    elevation: 6,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20)),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surface,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 24, vertical: 28),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          const SizedBox(height: 8),
                                          Container(
                                            width: 140, height: 140,
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.surface,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: theme.colorScheme.primary.withOpacity(0.06),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 6),
                                                ),
                                              ],
                                            ),
                                            padding: const EdgeInsets.all(12),
                                            child: ClipOval(
                                              child: Image.asset('assets/images/logo.png',
                                                  width: 140, height: 140, fit: BoxFit.contain),
                                            ),
                                          ),
                                          const SizedBox(height: 18),
                                          Text(
                                            loc['appTitle'] ?? 'LingoLens AI',
                                            style: theme.textTheme.headlineSmall?.copyWith(
                                                fontWeight: FontWeight.w800,
                                                color: theme.colorScheme.onSurface),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            loc['aboutDesc'] ?? '',
                                            style: theme.textTheme.bodyLarge?.copyWith(
                                                color: theme.colorScheme.onSurface.withOpacity(0.85)),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 22),
                                          SizedBox(
                                            width: double.infinity, height: 56,
                                            child: FilledButton.icon(
                                              onPressed: () {
                                                FeedbackService.click(
                                                    sound: widget.soundOn,
                                                    vibration: widget.vibrationOn);
                                                _showImageSourceDialog();
                                              },
                                              icon: const Icon(Icons.document_scanner_outlined),
                                              label: Text(loc['scanText'] ?? 'Scan Text',
                                                  style: const TextStyle(fontSize: 16)),
                                              style: FilledButton.styleFrom(
                                                shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(18)),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          ExpansionTile(
                                            leading: Icon(Icons.info_outline,
                                                color: theme.colorScheme.primary),
                                            title: Text(loc['about'] ?? 'About',
                                                style: theme.textTheme.titleMedium
                                                    ?.copyWith(fontWeight: FontWeight.bold)),
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                                                child: Column(children: [
                                                  ListTile(
                                                    leading: Icon(Icons.document_scanner_outlined,
                                                        color: theme.colorScheme.primary),
                                                    title: Text(loc['extractText'] ?? 'Extract text from images',
                                                        style: theme.textTheme.bodyMedium),
                                                  ),
                                                  ListTile(
                                                    leading: Icon(Icons.language,
                                                        color: theme.colorScheme.primary),
                                                    title: Text(loc['detectLang'] ?? 'Detect language automatically',
                                                        style: theme.textTheme.bodyMedium),
                                                  ),
                                                  ListTile(
                                                    leading: Icon(Icons.translate,
                                                        color: theme.colorScheme.primary),
                                                    title: Text(loc['translateInstantly'] ?? 'Translate instantly',
                                                        style: theme.textTheme.bodyMedium),
                                                  ),
                                                ]),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // ── TRANSLATIONS ───────────────────────────
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                child: LearningFeed(appLanguage: widget.currentLanguage),
                              ),

                              // ── HISTORY ────────────────────────────────
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                child: HistoryScreen(appLanguage: widget.currentLanguage),
                              ),
                            ],
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