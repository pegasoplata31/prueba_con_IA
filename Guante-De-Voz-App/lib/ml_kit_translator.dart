// ============================================================
//  ml_kit_translator.dart
//  Traducción OFFLINE con Google ML Kit On-Device Translation.
// ============================================================

import 'dart:async';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

class MlTranslationResult {
  final String text;
  final bool success;
  final String? error;

  MlTranslationResult({
    required this.text,
    this.success = true,
    this.error,
  });

  static MlTranslationResult failure(String error) =>
      MlTranslationResult(text: '', success: false, error: error);
}

class MlKitTranslator {
  static const Map<String, String> langMap = {
    'zh-yue': 'zh',
    'zh-cmn': 'zh',
    'es-PA': 'es',
    'es-MX': 'es',
    'es-ES': 'es',
    'pt': 'pt',
    'en': 'en',
    'fr': 'fr',
    'de': 'de',
    'ar': 'ar',
    'ru': 'ru',
    'ja': 'ja',
    'ko': 'ko',
  };

  final OnDeviceTranslatorModelManager _modelManager =
      OnDeviceTranslatorModelManager();

  OnDeviceTranslator? _translator;
  String? _currentSource;
  String? _currentTarget;

  static const List<String> preloadLanguages = ['es-PA', 'en'];

  Future<bool> isModelDownloaded(String appLangCode) async {
    final bcp = langMap[appLangCode] ?? appLangCode;
    try {
      return await _modelManager.isModelDownloaded(bcp);
    } catch (_) {
      return false;
    }
  }

  Future<bool> downloadModel(
    String appLangCode, {
    void Function(double progress)? onProgress,
  }) async {
    final bcp = langMap[appLangCode] ?? appLangCode;
    if (await isModelDownloaded(appLangCode)) {
      onProgress?.call(1.0);
      return true;
    }
    onProgress?.call(0.0);
    try {
      final result = await _modelManager.downloadModel(bcp);
      onProgress?.call(1.0);
      return result;
    } catch (_) {
      return false;
    }
  }

  Future<MlTranslationResult> translate(
    String text, {
    String fromLang = 'es-PA',
    required String toLang,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return MlTranslationResult(text: trimmed);

    final fromBcp = langMap[fromLang] ?? fromLang;
    final toBcp = langMap[toLang] ?? toLang;
    if (fromBcp == toBcp) return MlTranslationResult(text: trimmed);

    if (!await isModelDownloaded(fromLang) ||
        !await isModelDownloaded(toLang)) {
      return MlTranslationResult.failure('Modelo no descargado');
    }

    if (_translator != null &&
        _currentSource == fromBcp &&
        _currentTarget == toBcp) {
      try {
        final out = await _translator!.translateText(trimmed);
        return MlTranslationResult(text: out);
      } catch (e) {
        return MlTranslationResult.failure('Error: $e');
      }
    }

    await _translator?.close();
    _translator = OnDeviceTranslator(
      sourceLanguage: _parseLang(fromBcp),
      targetLanguage: _parseLang(toBcp),
    );
    _currentSource = fromBcp;
    _currentTarget = toBcp;

    try {
      final out = await _translator!.translateText(trimmed);
      return MlTranslationResult(text: out);
    } catch (e) {
      return MlTranslationResult.failure('Error: $e');
    }
  }

  TranslateLanguage _parseLang(String bcpCode) {
    return TranslateLanguage.values.firstWhere(
      (l) => l.bcpCode == bcpCode || l.bcpCode.startsWith('$bcpCode-'),
      orElse: () => TranslateLanguage.english,
    );
  }

  Future<void> dispose() async {
    await _translator?.close();
    _translator = null;
  }
}
