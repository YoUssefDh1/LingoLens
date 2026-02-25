import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'services/ml_service.dart';
import 'services/feedback_service.dart';
import 'app_localizations.dart';
import 'results_screen.dart';
import 'settings_screen.dart';

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

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();
  final MLService _mlService = MLService();
  bool _isLoading = false;

  Future<void> _processImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image == null) return;

    setState(() => _isLoading = true);

    try {
      final File file = File(image.path);
      final String text = await _mlService.recognizeText(file);
      if (text.trim().isEmpty) throw Exception("No text detected.");
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}"), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Choose Image Source", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text("Camera"),
                onTap: () {
                  FeedbackService.click(sound: widget.soundOn, vibration: widget.vibrationOn);
                  Navigator.pop(context);
                  _processImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text("Gallery"),
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

  @override
  void dispose() {
    _mlService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(widget.currentLanguage);
    return Scaffold(
      appBar: AppBar(
        title: const Text("LingoLens AI"),
        actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => Navigator.push(
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
                ),
              ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [theme.colorScheme.primary.withOpacity(0.06), theme.colorScheme.background],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Card(
                        elevation: 6,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(height: 8),
                              Icon(Icons.translate, size: 86, color: theme.colorScheme.primary),
                              const SizedBox(height: 14),
                              Text(
                                t['appTitle'] ?? 'LingoLens AI',
                                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                t['aboutDesc'] ?? '',
                                style: theme.textTheme.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 28),
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: FilledButton.icon(
                                  onPressed: () {
                                    FeedbackService.click(sound: widget.soundOn, vibration: widget.vibrationOn);
                                    _showImageSourceDialog();
                                  },
                                  icon: const Icon(Icons.document_scanner_outlined),
                                  label: Text(t['scanText'] ?? 'Scan Text', style: const TextStyle(fontSize: 16)),
                                  style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(t['about'] ?? 'About', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "LingoLens AI is a mobile application that uses Google ML Kit "
                                "to extract text from images, detect its language, and translate "
                                "it instantly. Designed for travelers, students, and professionals.",
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 8),
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