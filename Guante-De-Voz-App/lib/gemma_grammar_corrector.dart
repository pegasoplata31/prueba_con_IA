// ============================================================
//  gemma_grammar_corrector.dart
//  Corrector gramatical OFFLINE con Gemma 3 1B (LiteRT-LM).
// ============================================================

import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:flutter_gemma/core/domain/download_exception.dart';

class GrammarCorrectionResult {
  final String corrected;
  final bool success;
  final String? error;

  GrammarCorrectionResult({
    required this.corrected,
    this.success = true,
    this.error,
  });

  static GrammarCorrectionResult failure(String error) =>
      GrammarCorrectionResult(corrected: '', success: false, error: error);
}

class GemmaGrammarCorrector {
  bool _initialized = false;
  bool _modelInstalled = false;
  InferenceModel? _model;

  /// Nombre del archivo del modelo en HuggingFace.
  static const String _modelFileName =
      Gemma3-1B-IT_multi-prefill-seq_q4_ekv4096.litertlm;

  /// Verifica si el modelo ya está descargado en el dispositivo.
  Future<bool> isModelInstalled() async {
    try {
      return await FlutterGemma.isModelInstalled(_modelFileName);
    } catch (_) {
      return false;
    }
  }

  /// Descarga el modelo desde HuggingFace.
  /// ⚠️ El repo es gated: requiere un token de HuggingFace con acceso aprobado.
    Future<bool> downloadModel({
    required String huggingFaceToken,
    void Function(double progress)? onProgress,
  }) async {
    try {
      await FlutterGemma.initialize(
        huggingFaceToken: huggingFaceToken,
      );

      await FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
        fileType: ModelFileType.litertlm,
      )
          .fromNetwork(
            'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/$_modelFileName',
            token: huggingFaceToken,
          )
          .withProgress((p) => onProgress?.call(p.toDouble()))
          .install();

      _modelInstalled = true;
      return true;
    } on DownloadException catch (e) {
      // 🔥 Aquí capturamos el error REAL
      print('DownloadException: ${e.error.runtimeType} - ${e.error.toUserMessage()}');
      
      switch (e.error) {
        case UnauthorizedError():
          print('❌ Token inválido o faltante (401)');
        case ForbiddenError():
          print('❌ No tienes acceso aprobado al modelo (403)');
        case NotFoundError():
          print('❌ Archivo no encontrado - revisa el nombre (404)');
        case RateLimitedError():
          print('❌ Demasiadas peticiones, espera un momento (429)');
        case ServerError():
          print('❌ Error del servidor de HuggingFace (5xx)');
        case NetworkError():
          print('❌ Error de red - revisa tu conexión');
        case CanceledError():
          print('❌ Descarga cancelada por el usuario');
        case UnknownError():
          print('❌ Error desconocido: ${e.error.toUserMessage()}');
      }
      return false;
    } catch (e) {
      print('Error general: $e');
      return false;
    }
  }

  /// Inicializa el motor LiteRT-LM y carga el modelo.
  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    if (!_modelInstalled) {
      _modelInstalled = await isModelInstalled();
    }
    if (!_modelInstalled) {
      throw Exception('Modelo no descargado.');
    }

    // Registrar el engine de LiteRT-LM.
    await FlutterGemma.initialize(
      inferenceEngines: [LiteRtLmEngine()],
    );

    // Cargar el modelo en memoria.
    _model = await FlutterGemma.getActiveModel(
      maxTokens: 1024,
      preferredBackend: PreferredBackend.gpu,
    );

    _initialized = true;
  }

  /// Corrige la gramática de una lista de palabras.
  Future<GrammarCorrectionResult> correct(
    List<String> words, {
    String targetLanguage = 'es-PA',
  }) async {
    if (words.isEmpty) {
      return GrammarCorrectionResult(corrected: '');
    }

    try {
      await _ensureInitialized();
      if (_model == null) {
        return GrammarCorrectionResult.failure('Modelo no cargado');
      }

      final inputText = words.join(' ');
      final langName = _languageName(targetLanguage);

      final prompt = '''
Eres un corrector gramatical experto en $langName.
Recibes una secuencia de palabras que vienen de una Lengua de Señas.
Tu tarea es convertirla en una oración gramaticalmente correcta y natural en $langName.

Reglas:
- Mantén TODAS las palabras del original si es posible.
- Solo corrige la gramática, no cambies el significado.
- Responde ÚNICAMENTE con la oración corregida.

Secuencia de entrada: $inputText

Oración corregida:''';

      final chat = await _model!.createChat(temperature: 0.3);
      await chat.addQueryChunk(Message.text(text: prompt, isUser: true));
      final response = await chat.generateChatResponse();
      await chat.close();

      String cleaned = '';
      if (response is TextResponse) {
        cleaned = response.token.trim();
      }
      cleaned = cleaned.replaceAll(RegExp(r'''^["'«»]+|["'«»]+$'''), '');

      if (cleaned.isEmpty) {
        return GrammarCorrectionResult.failure('Respuesta vacía');
      }

      return GrammarCorrectionResult(corrected: cleaned);
    } catch (e) {
      return GrammarCorrectionResult.failure('Error: $e');
    }
  }

  /// Corrige una frase completa (Modo Frase).
  Future<GrammarCorrectionResult> correctPhrase(
    String phrase, {
    String targetLanguage = 'es-PA',
  }) async {
    if (phrase.trim().isEmpty) {
      return GrammarCorrectionResult(corrected: '');
    }
    return correct(
      phrase.split(RegExp(r'\s+')),
      targetLanguage: targetLanguage,
    );
  }

  String _languageName(String code) {
    if (code.startsWith('es')) return 'español';
    if (code.startsWith('en')) return 'inglés';
    if (code.startsWith('zh')) return 'chino';
    if (code.startsWith('fr')) return 'francés';
    if (code.startsWith('pt')) return 'portugués';
    if (code.startsWith('de')) return 'alemán';
    if (code.startsWith('ja')) return 'japonés';
    if (code.startsWith('ko')) return 'coreano';
    if (code.startsWith('ar')) return 'árabe';
    if (code.startsWith('ru')) return 'ruso';
    return 'español';
  }

  Future<void> dispose() async {
    await _model?.close();
    _model = null;
    _initialized = false;
  }
}
