import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MLService {
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final LanguageIdentifier _languageIdentifier = LanguageIdentifier(confidenceThreshold: 0.5);

  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user ID
  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  /// Process image: OCR -> Identify Lang -> Translate -> Save to Firestore
  /// (No image upload to Storage - keeping it free!)
  Future<Map<String, dynamic>> processImage(File imageFile, String targetLanguage) async {
    try {
      // 1. Perform OCR
      final String extractedText = await recognizeText(imageFile);
      if (extractedText.isEmpty) {
        return {'success': false, 'error': 'No text detected in image'};
      }

      // 2. Identify source language
      final String sourceLanguage = await identifyLanguage(extractedText);

      // 3. Translate text
      final String translatedText = await translateText(extractedText, sourceLanguage, targetLanguage);

      // 4. Save to Firestore history (NO image storage needed!)
      await _saveToHistory(
        originalText: extractedText,
        translatedText: translatedText,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
      );

      return {
        'success': true,
        'originalText': extractedText,
        'translatedText': translatedText,
        'sourceLanguage': sourceLanguage,
        'targetLanguage': targetLanguage,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Save translation to Firestore history (TEXT ONLY - no images)
  Future<void> _saveToHistory({
    required String originalText,
    required String translatedText,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    if (_userId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('history')
          .add({
        'originalText': originalText,
        'translatedText': translatedText,
        'sourceLanguage': sourceLanguage,
        'targetLanguage': targetLanguage,
        'imageUrl': null, // No image saved
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving to history: $e');
    }
  }

  /// Get translation history stream
  Stream<QuerySnapshot> getHistoryStream() {
    if (_userId == null) return Stream.empty();
    
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('history')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Delete a history item
  Future<void> deleteHistoryItem(String documentId) async {
    if (_userId == null) return;
    
    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('history')
        .doc(documentId)
        .delete();
  }

  // Original ML methods
  Future<String> recognizeText(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
    return recognizedText.text;
  }

  Future<String> identifyLanguage(String text) async {
    if (text.isEmpty) return 'und';
    return await _languageIdentifier.identifyLanguage(text);
  }

  Future<String> translateText(String text, String sourceLanguage, String targetLanguage) async {
    TranslateLanguage map(String code) {
      switch (code.toLowerCase()) {
        case 'fr':
          return TranslateLanguage.french;
        case 'ar':
          return TranslateLanguage.arabic;
        case 'en':
        default:
          return TranslateLanguage.english;
      }
    }

    final sourceModel = map(sourceLanguage);
    final targetModel = map(targetLanguage);

    final onDeviceTranslator = OnDeviceTranslator(
      sourceLanguage: sourceModel,
      targetLanguage: targetModel,
    );

    try {
      final String response = await onDeviceTranslator.translateText(text);
      return response;
    } finally {
      onDeviceTranslator.close();
    }
  }

  void dispose() {
    _textRecognizer.close();
    _languageIdentifier.close();
  }
}