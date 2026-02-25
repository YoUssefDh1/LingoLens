import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

class MLService {
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final LanguageIdentifier _languageIdentifier = LanguageIdentifier(confidenceThreshold: 0.5);

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
    TranslateLanguage _map(String code) {
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

    final sourceModel = _map(sourceLanguage);
    final targetModel = _map(targetLanguage);

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