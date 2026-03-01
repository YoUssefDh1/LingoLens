import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/ml_service.dart';
import 'services/feedback_service.dart';
import 'app_localizations.dart';
import 'translation.dart';

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
  String _translatedText = '';
  bool _isTranslating = false;
  bool _hasTranslated = false;
  String _targetLanguage = 'en';

  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    _mlService.dispose();
    super.dispose();
  }

  /// Get current Firebase user ID
  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  /// Save translation to Firestore
  Future<void> _saveToFirestore({
    required String originalText,
    required String translatedText,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    final userId = _userId;
    if (userId == null) return; // Not logged in, skip Firestore save

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('history')
          .add({
        'originalText': originalText,
        'translatedText': translatedText,
        'sourceLanguage': sourceLanguage,
        'targetLanguage': targetLanguage,
        'imageUrl': widget.imageFile.path,// Image already processed, we could upload if needed
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving to Firestore: $e');
      // Don't show error to user, just log it
    }
  }

  Future<void> _handleTranslation(Map<String, String> loc) async {
    setState(() => _isTranslating = true);
    try {
      final result = await _mlService.translateText(
          widget.recognizedText, widget.languageCode, _targetLanguage);
      setState(() {
            _translatedText = result;
            _hasTranslated = true;
      });

      // Save to local repository (existing behavior)
      final now = DateTime.now();
      final id = now.microsecondsSinceEpoch.toString();
      final sourceLang = _languageName(widget.languageCode);
      final targetLang = _languageName(_targetLanguage);
      final snippet = result.length > 200 ? '${result.substring(0, 200)}…' : result;

      translationRepo.addTranslation(Translation(
        id: id,
        sourceLang: sourceLang,
        targetLang: targetLang,
        title: '${sourceLang.toUpperCase()} → ${targetLang.toUpperCase()}',
        snippet: snippet,
        imageUrl: widget.imageFile.path,
        originalText: widget.recognizedText,
        languageCode: widget.languageCode,
      ));

      // Save to Firestore (new Firebase integration)
      await _saveToFirestore(
        originalText: widget.recognizedText,
        translatedText: result,
        sourceLanguage: widget.languageCode,
        targetLanguage: _targetLanguage,
      );

      if (!mounted) return;
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc['translationSaved'] ?? 'Translation saved to history'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green.shade600,
        ),
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${loc['translationFailed'] ?? 'Translation failed:'} ${e.toString()}'),
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _isTranslating = false);
    }
  }

  String _languageName(String code) {
    switch (code) {
      case 'en': return 'English';
      case 'fr': return 'French';
      case 'ar': return 'Arabic';
      default: return code.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(widget.appLanguage);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(loc['scanResults'] ?? 'Scan Results'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: loc['close'] ?? 'Close',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Image
            SizedBox(
              height: 200,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                child: Image.file(widget.imageFile, fit: BoxFit.cover),
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${loc['detectedLanguage'] ?? 'Detected Language'}: ${_languageName(widget.languageCode)}',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 10),
                    Text(loc['originalText'] ?? 'Original Text',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 6),
                    Text(widget.recognizedText, style: const TextStyle(fontSize: 15)),
                    const SizedBox(height: 20),

                    // Language dropdown — labels use loc
                    DropdownButtonFormField<String>(
                      initialValue: _targetLanguage,
                      decoration: InputDecoration(
                        labelText: loc['translateTo'] ?? 'Translate To',
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(value: 'en', child: Text(loc['lang_en'] ?? 'English')),
                        DropdownMenuItem(value: 'fr', child: Text(loc['lang_fr'] ?? 'French')),
                        DropdownMenuItem(value: 'ar', child: Text(loc['lang_ar'] ?? 'Arabic')),
                      ],
                      onChanged: (v) => setState(() => _targetLanguage = v!),
                    ),
                    const SizedBox(height: 20),

                    if (_translatedText.isNotEmpty) ...[
                      const Divider(),
                      const SizedBox(height: 10),
                      Text(
                        loc['translatedText'] ?? 'Translated Text',
                        style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary),
                      ),
                      const SizedBox(height: 6),
                      Text(_translatedText, style: const TextStyle(fontSize: 16)),
                    ],
                  ],
                ),
              ),
            ),

            // Translate button
            Padding(
              padding: EdgeInsets.only(
                left: 20, right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: _isTranslating
                  ? const Center(child: CircularProgressIndicator())
                : SizedBox(
                      width: double.infinity,
                      height: 50,
                  child: _hasTranslated
                ? FilledButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.check),
                    label: Text(loc['done'] ?? 'Done'),
                )
                : FilledButton.icon(
                  onPressed: () {
                  FeedbackService.click(
                    sound: widget.soundOn, vibration: widget.vibrationOn);
                  _handleTranslation(loc);
              },
              icon: const Icon(Icons.translate),
              label: Text(loc['translate'] ?? 'Translate'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}