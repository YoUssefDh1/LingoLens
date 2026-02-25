import 'dart:io';
import 'package:flutter/material.dart';
import 'services/ml_service.dart';
import 'services/feedback_service.dart';
import 'app_localizations.dart';

class ResultsScreen extends StatefulWidget {
  final File imageFile;
  final String recognizedText;
  final String languageCode;
  final String appLanguage;

  final bool soundOn;
  final bool vibrationOn;

  const ResultsScreen({
    super.key,
    required this.imageFile,
    required this.recognizedText,
    required this.languageCode,
    this.appLanguage = 'en',
    this.soundOn = true,
    this.vibrationOn = true,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  final MLService _mlService = MLService();

  String _translatedText = "";
  bool _isTranslating = false;
  String _targetLanguage = "en";

  @override
  void dispose() {
    _mlService.dispose();
    super.dispose();
  }

  Future<void> _handleTranslation() async {
    setState(() => _isTranslating = true);
    try {
      final result = await _mlService.translateText(
        widget.recognizedText,
        widget.languageCode,
        _targetLanguage,
      );
      setState(() => _translatedText = result);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Translation failed: ${e.toString()}"),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isTranslating = false);
    }
  }

  String _languageName(String code) {
    switch (code) {
      case "en":
        return "English";
      case "fr":
        return "French";
      case "ar":
        return "Arabic";
      default:
        return code.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(widget.appLanguage);

    return Scaffold(
      appBar: AppBar(title: Text(t['scanResults'] ?? 'Scan Results')),
      body: SafeArea(
        child: Column(
          children: [
            // -------- IMAGE --------
            SizedBox(
              height: 220,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                child: Image.file(widget.imageFile, fit: BoxFit.cover),
              ),
            ),

            // -------- CONTENT --------
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${t['detectedLanguage'] ?? 'Detected Language'}: ${_languageName(widget.languageCode)}",
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 10),

                      Text(t['originalText'] ?? 'Original Text', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 6),
                      Text(widget.recognizedText),

                      const SizedBox(height: 20),

                      // -------- TARGET LANGUAGE DROPDOWN --------
                      DropdownButtonFormField<String>(
                        value: _targetLanguage,
                        decoration: InputDecoration(
                          labelText: t['translateTo'] ?? 'Translate To',
                          border: const OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'en', child: Text("English")),
                          DropdownMenuItem(value: 'fr', child: Text("French")),
                          DropdownMenuItem(value: 'ar', child: Text("Arabic")),
                        ],
                        onChanged: (value) => setState(() => _targetLanguage = value!),
                      ),

                      const SizedBox(height: 20),

                      if (_translatedText.isNotEmpty) ...[
                        const Divider(),
                        const SizedBox(height: 10),
                        Text(
                          t['translate'] ?? 'Translated Text',
                          style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                        ),
                        const SizedBox(height: 6),
                        Text(_translatedText, style: const TextStyle(fontSize: 16)),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // -------- BUTTON --------
            Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20, // safe for keyboard/gesture bars
              ),
                      child: _isTranslating
                  ? const Center(child: CircularProgressIndicator())
                  : SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: () {
                          FeedbackService.click(sound: widget.soundOn, vibration: widget.vibrationOn);
                          _handleTranslation();
                        },
                        icon: const Icon(Icons.translate),
                        label: Text(t['translate'] ?? 'Translate'),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}