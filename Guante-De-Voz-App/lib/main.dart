import 'dart:ui' show ImageFilter;
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ble_manager.dart';
import 'models.dart';
import 'storage.dart';
import 'json_exporter.dart'; 

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const BeyondWordsApp());
}

class BeyondWordsApp extends StatefulWidget {
  const BeyondWordsApp({super.key});

  @override
  State<BeyondWordsApp> createState() => _BeyondWordsAppState();
}

class _BeyondWordsAppState extends State<BeyondWordsApp> {
  bool darkMode = false;
  String uiLanguage = 'es';
  double speechRate = 0.45;
  double speechVolume = 1.0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      darkMode = p.getBool('dark_mode') ?? false;
      uiLanguage = p.getString('ui_language') ?? 'es';
      speechRate = p.getDouble('speech_rate') ?? 0.45;
      speechVolume = p.getDouble('speech_volume') ?? 1.0;
    });
  }

  Future<void> _persist(String key, dynamic value) async {
    final p = await SharedPreferences.getInstance();
    if (value is bool) await p.setBool(key, value);
    if (value is String) await p.setString(key, value);
    if (value is double) await p.setDouble(key, value);
  }

  ThemeData _theme(Brightness b) {
    final dark = b == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0A84FF),
      brightness: b,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: b,
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: scheme,
      fontFamily: 'SF Pro Display',
      textTheme: Typography.material2021(platform: TargetPlatform.iOS)
          .black
          .apply(
            bodyColor: dark ? Colors.white : const Color(0xFF0B1220),
            displayColor: dark ? Colors.white : const Color(0xFF0B1220),
          ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: dark ? Colors.white : const Color(0xFF0B1220),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.65),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: dark
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.white.withValues(alpha: 0.55),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: dark
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.white.withValues(alpha: 0.55),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF0A84FF), width: 1.4),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Beyond Words',
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      home: LiquidBackground(
        darkMode: darkMode,
        child: HomeShell(
          darkMode: darkMode,
          uiLanguage: uiLanguage,
          speechRate: speechRate,
          speechVolume: speechVolume,
          onDarkMode: (v) {
            setState(() => darkMode = v);
            _persist('dark_mode', v);
          },
          onUiLanguage: (v) {
            setState(() => uiLanguage = v);
            _persist('ui_language', v);
          },
          onSpeechRate: (v) {
            setState(() => speechRate = v);
            _persist('speech_rate', v);
          },
          onSpeechVolume: (v) {
            setState(() => speechVolume = v);
            _persist('speech_volume', v);
          },
        ),
      ),
    );
  }
}/// Fondo con degradado frío + orbes difusos (Liquid Glass).
class LiquidBackground extends StatelessWidget {
  final Widget child;
  final bool darkMode;
  const LiquidBackground({
    super.key,
    required this.child,
    required this.darkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: darkMode
              ? const [
                  Color(0xFF04070F),
                  Color(0xFF07101F),
                  Color(0xFF0A1A2F),
                ]
              : const [
                  Color(0xFFF6FAFF),
                  Color(0xFFEAF3FF),
                  Color(0xFFDCEBFF),
                ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -120, left: -80,
            child: _orb(const Color(0x5522D3EE), 280),
          ),
          Positioned(
            top: 200, right: -100,
            child: _orb(const Color(0x445B8DEF), 320),
          ),
          Positioned(
            bottom: -140, left: 40,
            child: _orb(const Color(0x5581E9FF), 300),
          ),
          child,
        ],
      ),
    );
  }

  Widget _orb(Color color, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      );
}

/// Tarjeta de vidrio con blur, borde luminoso y sombra fría.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double blur;
  final double radius;
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.blur = 22,
    this.radius = 26,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? [
                      Colors.white.withValues(alpha: 0.10),
                      Colors.white.withValues(alpha: 0.03),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.75),
                      Colors.white.withValues(alpha: 0.45),
                    ],
            ),
            border: Border.all(
              color: dark
                  ? Colors.white.withValues(alpha: 0.14)
                  : Colors.white.withValues(alpha: 0.80),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: dark
                    ? Colors.black.withValues(alpha: 0.30)
                    : const Color(0xFF0A84FF).withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Botón tipo iOS con efecto líquido.
class LiquidButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool primary;
  const LiquidButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.primary = true,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onPressed,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: primary
                  ? const LinearGradient(
                      colors: [Color(0xFF0A84FF), Color(0xFF22D3EE)],
                    )
                  : null,
              color: primary
                  ? null
                  : (Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.10)
                      : Colors.white.withValues(alpha: 0.70)),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 1,
              ),
              boxShadow: primary
                  ? [
                      BoxShadow(
                        color: const Color(0xFF0A84FF)
                            .withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon,
                      color: primary
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface),
                  const SizedBox(width: 10),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: primary
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}class Lang {
  final String code;
  final String tts;
  final String label;
  const Lang(this.code, this.tts, this.label);
}

const kLanguages = <Lang>[
  Lang('zh-yue', 'yue-HK', '中文（粤语）'),
  Lang('zh-cmn', 'zh-CN', '中文（普通话）'),
  Lang('es-PA', 'es-PA', 'Español (Panamá)'),
  Lang('es-MX', 'es-MX', 'Español (México)'),
  Lang('es-ES', 'es-ES', 'Español (España)'),
  Lang('pt', 'pt-BR', 'Português'),
  Lang('en', 'en-US', 'English'),
  Lang('fr', 'fr-FR', 'Français'),
  Lang('de', 'de-DE', 'Deutsch'),
  Lang('ar', 'ar-SA', 'العربية'),
  Lang('ru', 'ru-RU', 'Русский'),
  Lang('ja', 'ja-JP', '日本語'),
  Lang('ko', 'ko-KR', '한국어'),
];

String builtInTranslation(String word, String lang) {
  final key = word.trim().toUpperCase();
  const dict = {
    'HOLA': {
      'es': 'Hola', 'en': 'Hello', 'zh': '你好', 'fr': 'Bonjour',
      'pt': 'Olá', 'de': 'Hallo', 'ja': 'こんにちは', 'ko': '안녕하세요',
      'ar': 'مرحبا', 'ru': 'Привет',
    },
    'GRACIAS': {
      'es': 'Gracias', 'en': 'Thank you', 'zh': '谢谢', 'fr': 'Merci',
      'pt': 'Obrigado', 'de': 'Danke', 'ja': 'ありがとう',
      'ko': '감사합니다', 'ar': 'شكرا', 'ru': 'Спасибо',
    },
    'POR FAVOR': {
      'es': 'Por favor', 'en': 'Please', 'zh': '请',
      'fr': "S'il vous plaît", 'pt': 'Por favor', 'de': 'Bitte',
      'ja': 'お願いします', 'ko': '제발', 'ar': 'من فضلك', 'ru': 'Пожалуйста',
    },
    'AGUA': {
      'es': 'Agua', 'en': 'Water', 'zh': '水', 'fr': 'Eau',
      'pt': 'Água', 'de': 'Wasser', 'ja': '水', 'ko': '물',
      'ar': 'ماء', 'ru': 'Вода',
    },
    'AYUDAME': {
      'es': 'Ayúdame', 'en': 'Help me', 'zh': '帮帮我',
      'fr': 'Aidez-moi', 'pt': 'Ajude-me', 'de': 'Hilf mir',
      'ja': '助けて', 'ko': '도와주세요', 'ar': 'ساعدني', 'ru': 'Помоги мне',
    },
    'COMIDA': {
      'es': 'Comida', 'en': 'Food', 'zh': '食物', 'fr': 'Nourriture',
      'pt': 'Comida', 'de': 'Essen', 'ja': '食べ物', 'ko': '음식',
      'ar': 'طعام', 'ru': 'Еда',
    },
    'YO': {
      'es': 'Yo', 'en': 'I / Me', 'zh': '我', 'fr': 'Moi',
      'pt': 'Eu', 'de': 'Ich', 'ja': '私', 'ko': '나',
      'ar': 'أنا', 'ru': 'Я',
    },
    'TE QUIERO': {
      'es': 'Te quiero', 'en': 'I love you', 'zh': '我爱你',
      'fr': "Je t'aime", 'pt': 'Eu te amo', 'de': 'Ich liebe dich',
      'ja': '愛してる', 'ko': '사랑해', 'ar': 'أحبك', 'ru': 'Я тебя люблю',
    },
    'SI': {
      'es': 'Sí', 'en': 'Yes', 'zh': '是', 'fr': 'Oui',
      'pt': 'Sim', 'de': 'Ja', 'ja': 'はい', 'ko': '네',
      'ar': 'نعم', 'ru': 'Да',
    },
    'NO': {
      'es': 'No', 'en': 'No', 'zh': '不', 'fr': 'Non',
      'pt': 'Não', 'de': 'Nein', 'ja': 'いいえ', 'ko': '아니요',
      'ar': 'لا', 'ru': 'Нет',
    },
  };
  return dict[key]?[lang] ?? word;
}class HomeShell extends StatefulWidget {
  final bool darkMode;
  final String uiLanguage;
  final double speechRate;
  final double speechVolume;
  final ValueChanged<bool> onDarkMode;
  final ValueChanged<String> onUiLanguage;
  final ValueChanged<double> onSpeechRate;
  final ValueChanged<double> onSpeechVolume;

  const HomeShell({
    super.key,
    required this.darkMode,
    required this.uiLanguage,
    required this.speechRate,
    required this.speechVolume,
    required this.onDarkMode,
    required this.onUiLanguage,
    required this.onSpeechRate,
    required this.onSpeechVolume,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final ble = BleManager();
  final storage = GestureStorage();
  final tts = FlutterTts();

  final List<SensorFrame> leftWindow = [];
  final List<SensorFrame> rightWindow = [];
  final List<LogEntry> logs = [];
  List<TrainingGesture> gestures = [];

  StreamSubscription<BlePacket>? packetSub;
  Timer? recognizeTimer;

  final segmenterLeft = MotionSegmenter();
  final segmenterRight = MotionSegmenter();
  final stability = StabilityFilter(
    hold: const Duration(milliseconds: 250),
  );

  List<double>? restVector;
  String recognized = '—';
  double confidence = 0;
  String language = 'es-PA';
  int tab = 0;

  bool dynamicMode = false;
  final List<List<double>> dynamicBuffer = [];

  bool phraseMode = false;              
  final List<String> phraseWords = [];

  String _t(String es, String en) =>
      widget.uiLanguage == 'en' ? en : es;

  @override
  void initState() {
    // ...
    super.initState();
    _load();
    ble.addListener(_refresh);
    packetSub = ble.packets.listen(_onPacket);
    recognizeTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _recognizeTick(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showCalibrationWarning();
    });
  }

  Future<void> _load() async {
    gestures = await storage.load();
    final p = await SharedPreferences.getInstance();
    final r = p.getString('rest_vector');
    if (r != null) {
      try {
        restVector = (jsonDecode(r) as List)
            .map((e) => (e as num).toDouble())
            .toList();
      } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _onPacket(BlePacket p) {
    logs.insert(0, LogEntry(p.raw));
    if (logs.length > 400) logs.removeLast();

    if (p.processedWord != null) {
      _acceptWord(p.processedWord!, 1.0);
      return;
    }

    if (p.left != null) _addFrame(leftWindow, p.left!);
    if (p.right != null) _addFrame(rightWindow, p.right!);
    if (p.frame != null && p.side == HandSide.left) {
      _addFrame(leftWindow, p.frame!);
    }
    if (p.frame != null && p.side == HandSide.right) {
      _addFrame(rightWindow, p.frame!);
    }

    _feedSegmenters();

    if (mounted) setState(() {});
  }

  void _addFrame(List<SensorFrame> w, SensorFrame f) {
    w.add(f);
    while (w.length > 30) w.removeAt(0);
  }

  // ---- Vector actual (promedio de últimos 500 ms) ----
  List<double>? _currentVector() {
    final now = DateTime.now();
    final l = leftWindow
        .where((f) => now.difference(f.time).inMilliseconds < 1200)
        .toList();
    final r = rightWindow
        .where((f) => now.difference(f.time).inMilliseconds < 1200)
        .toList();
    if (l.isEmpty && r.isEmpty) return null;

    final la = l.isEmpty ? null : SensorFrame.average(l);
    final ra = r.isEmpty ? null : SensorFrame.average(r);
    return BimanualVector.fromFrames(la, ra).values;
  }

  // ---- Detección de movimiento para señas dinámicas ----
  void _feedSegmenters() {
    final now = DateTime.now();
    final l = leftWindow.where(
      (f) => now.difference(f.time).inMilliseconds < 80,
    );
    final r = rightWindow.where(
      (f) => now.difference(f.time).inMilliseconds < 80,
    );

    final lMag = l.isEmpty
        ? 1.0
        : l.map((f) => f.accelMagnitude).reduce((a, b) => a + b) /
            l.length;
    final rMag = r.isEmpty
        ? 1.0
        : r.map((f) => f.accelMagnitude).reduce((a, b) => a + b) /
            r.length;

    final combined = (lMag + rMag) / 2.0;
    final vector = _currentVector();
    if (vector == null) return;

    final doneL = segmenterLeft.push(vector, lMag);
    final doneR = segmenterRight.push(vector, rMag);

    if (doneL != null || doneR != null) {
      final seq = doneL ?? doneR!;
      if (seq.length >= 8) {
        setState(() {
          dynamicBuffer
            ..clear()
            ..addAll(seq);
        });
        _tryDynamicRecognition();
      }
    } else if (segmenterLeft.isActive || segmenterRight.isActive) {
      // Ventana activa: alimentar el buffer para la vista en vivo.
      setState(() {
        dynamicBuffer.add(vector);
        while (dynamicBuffer.length > 120) dynamicBuffer.removeAt(0);
      });
    }

    // Silencio por reposo: si la aceleración está en rango de reposo,
    // forzar bloqueo de traducción.
    if (combined >= 0.80 && combined <= 1.20) {
      stability.reset();
    }
  }

  // ---- Tick de reconocimiento (100 ms) ----
  void _recognizeTick() {
    if (gestures.isEmpty) return;
    if (dynamicMode) return; // el reconocimiento dinámico va por evento

    final v = _currentVector();
    if (v == null) return;

    // Anti-reposo
    if (restVector != null && restVector!.length == v.length) {
      final restDist = GestureMath.vectorDistance(v, restVector!);
      if (restDist < 0.30) {
        stability.reset();
        return;
      }
    }

    final r = GestureMath.recognizeStatic(v, gestures);
    final id = r?.gesture.id;
    if (!stability.confirm(id)) return;
    _acceptWord(id!, r!.confidence);
  }

  void _tryDynamicRecognition() {
    if (dynamicBuffer.length < 8) return;
    final r = GestureMath.recognizeDynamic(dynamicBuffer, gestures);
    if (r == null) return;
    _acceptWord(r.gesture.id, r.confidence);
  }

  void _acceptWord(String id, double conf) {
    if (recognized == id && conf < 0.98) return;
    recognized = id;
    confidence = conf;
    if (mounted) setState(() {});
  }

  TrainingGesture? get currentGesture {
    for (final g in gestures) {
      if (g.id.toLowerCase() == recognized.toLowerCase()) return g;
    }
    return null;
  }

  String get translated {
    if (recognized == '—') return '—';
    final g = currentGesture;
    if (g != null) {
      final exact = g.translations[language];
      if (exact != null && exact.trim().isNotEmpty) return exact;
      if (language.startsWith('es-')) {
        return g.translations['es'] ?? g.id;
      }
      if (language.startsWith('zh-')) {
        return g.translations['zh'] ?? g.id;
      }
      return g.translations[language] ?? g.id;
    }
    return builtInTranslation(recognized, language);
  }

    Future<void> _speak() async {
    if (translated == '—') return;
    final lang = kLanguages.firstWhere(
      (l) => l.code == language,
      orElse: () => kLanguages[2],
    );
    await tts.setLanguage(lang.tts);
    await tts.setSpeechRate(widget.speechRate);
    await tts.setVolume(widget.speechVolume);
    await tts.speak(translated);
  }

    Future<void> _speakPhrase() async {
    if (phraseWords.isEmpty) return;

    // Traduce cada palabra con la tabla del gesto si existe
    final translatedWords = phraseWords.map((word) {
      for (final g in gestures) {
        if (g.id.toLowerCase() == word.toLowerCase()) {
          final exact = g.translations[language];
          if (exact != null && exact.trim().isNotEmpty) return exact;
          if (language.startsWith('es-')) {
            return g.translations['es'] ?? word;
          }
          if (language.startsWith('zh-')) {
            return g.translations['zh'] ?? word;
          }
          return g.translations[language] ?? word;
        }
      }
      return builtInTranslation(word, language);
    }).join(' ');

    final lang = kLanguages.firstWhere(
      (l) => l.code == language,
      orElse: () => kLanguages[2],
    );
    await tts.setLanguage(lang.tts);
    await tts.setSpeechRate(widget.speechRate);
    await tts.setVolume(widget.speechVolume);
    await tts.speak(translatedWords);

    if (mounted) setState(() => phraseWords.clear());
  }

  Future<void> _captureRest() async {
    final v = _currentVector();
    if (v == null) {
      if (!mounted) return;
      _snack(_t(
        'Conecta los guantes y mantén las manos relajadas.',
        'Connect the gloves and keep your hands relaxed.',
      ));
      return;
    }
    restVector = List<double>.from(v);
    final p = await SharedPreferences.getInstance();
    await p.setString('rest_vector', jsonEncode(restVector));
    if (!mounted) return;
    setState(() {});
    _snack(_t('Postura de reposo guardada.',
        'Rest position saved.'));
  }

  void _snack(String s) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );

  Future<void> _showCalibrationWarning() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0A84FF), Color(0xFF22D3EE)],
                  ),
                ),
                child: const Icon(Icons.back_hand_outlined,
                    color: Colors.white, size: 30),
              ),
              const SizedBox(height: 16),
              Text(
                _t('Calibración inicial', 'Initial calibration'),
                style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _t(
                  'Durante la calibración, relaja la mano de forma natural y luego forma un puño suavemente. No aprietes con fuerza, porque puede alterar los valores de flexión y reducir la precisión.',
                  'During calibration, relax your hand naturally and then make a gentle fist. Do not squeeze hard because it can alter the flex values and reduce accuracy.',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: LiquidButton(
                  label: _t('Entendido', 'Got it'),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    ble.removeListener(_refresh);
    packetSub?.cancel();
    recognizeTimer?.cancel();
    ble.dispose();
    tts.stop();
    super.dispose();
  }  @override
  Widget build(BuildContext context) {
    final pages = [
      _translatePage(),
      _addSignPage(),
      _signsListPage(),
      _terminalPage(),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      drawer: _settingsDrawer(),
      appBar: AppBar(
        toolbarHeight: 84,
        titleSpacing: 12,
        title: Row(
          children: [
            Container(
              width: 160,
              height: 46,
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0A84FF)
                        .withValues(alpha: 0.15),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Image.asset('assets/logo.png', fit: BoxFit.contain),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Beyond Words',
                  style: TextStyle(
                    fontFamily: 'Snell Roundhand',
                    fontStyle: FontStyle.italic,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
                Text(
                  'H&R',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.0,
                    color: Color(0xFF0A84FF),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: _connectionPill(),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: KeyedSubtree(
            key: ValueKey(tab),
            child: pages[tab],
          ),
        ),
      ),
      bottomNavigationBar: _liquidNavBar(),
    );
  }

  Widget _connectionPill() {
    final n = (ble.leftConnected ? 1 : 0) + (ble.rightConnected ? 1 : 0);
    final ok = n == 2;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      radius: 30,
      blur: 14,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ok
                  ? const Color(0xFF22D3EE)
                  : (n == 1
                      ? const Color(0xFFFFB020)
                      : const Color(0xFFFF4D6D)),
              boxShadow: [
                BoxShadow(
                  color: (ok
                          ? const Color(0xFF22D3EE)
                          : const Color(0xFFFF4D6D))
                      .withValues(alpha: 0.6),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$n/2 BLE',
            style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

   Widget _liquidNavBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          radius: 26,
          blur: 22,
          child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _navItem(0, Icons.translate,
                    _t('Traducir', 'Translate')),
                _navItem(1, Icons.add_circle_outline,
                    _t('Agregar', 'Add')),
                _navItem(2, Icons.list_alt,
                    _t('Señas', 'Signs')),
                _navItem(3, Icons.terminal, 'BLE'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int i, IconData icon, String label) {
    final active = tab == i;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: GestureDetector(
          onTap: () => setState(() => tab = i),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: active
                  ? const LinearGradient(
                      colors: [Color(0xFF0A84FF), Color(0xFF22D3EE)],
                    )
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: active
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurface
                          .withValues(alpha: 0.7),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: active
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface
                            .withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _settingsDrawer() {
    return Drawer(
      backgroundColor: Colors.transparent,
      child: LiquidBackground(
        darkMode: widget.darkMode,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Row(
                children: [
                  const Text(
                    'Configuración',
                    style: TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GlassCard(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: widget.darkMode,
                  onChanged: widget.onDarkMode,
                  secondary: Icon(widget.darkMode
                      ? Icons.dark_mode
                      : Icons.light_mode),
                  title: Text(_t('Modo oscuro', 'Dark mode')),
                ),
              ),
              const SizedBox(height: 12),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('Idioma de la interfaz',
                          'Interface language'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                            value: 'es', label: Text('Español')),
                        ButtonSegment(
                            value: 'en', label: Text('English')),
                      ],
                      selected: {widget.uiLanguage},
                      onSelectionChanged: (v) {
                        if (v.isNotEmpty) {
                          widget.onUiLanguage(v.first);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('Velocidad de voz', 'Speech speed'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Slider(
                      value: widget.speechRate,
                      min: 0.25, max: 0.70, divisions: 9,
                      label: widget.speechRate.toStringAsFixed(2),
                      onChanged: widget.onSpeechRate,
                    ),
                    Text(
                      _t('Volumen', 'Volume'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Slider(
                      value: widget.speechVolume,
                      min: 0, max: 1, divisions: 10,
                      label:
                          '${(widget.speechVolume * 100).round()}%',
                      onChanged: widget.onSpeechVolume,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GlassCard(
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.self_improvement),
                      title: Text(_t(
                        'Guardar postura de reposo',
                        'Save rest position',
                      )),
                      subtitle: Text(
                        restVector == null
                            ? _t('Aún no configurada',
                                'Not configured')
                            : _t('Configurada', 'Configured'),
                      ),
                      onTap: _captureRest,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.info_outline),
                      title: Text(_t(
                        'Ver aviso de calibración',
                        'Show calibration notice',
                      )),
                      onTap: _showCalibrationWarning,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }  Widget _translatePage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
      children: [
        _connectionStrip(),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              Text(
                _t('TRADUCCIÓN EN TIEMPO REAL',
                    'REAL-TIME TRANSLATION'),
                style: const TextStyle(
                  color: Color(0xFF22D3EE),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 20),
              // Indicador circular
              SizedBox(
                width: 130,
                height: 130,
                child: CustomPaint(
                  painter: _PulsePainter(
                    active: recognized != '—',
                    confidence: confidence,
                    dark: widget.darkMode,
                  ),
                  child: Center(
                    child: Text(
                      recognized == '—'
                          ? '—'
                          : '${(confidence * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                translated,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: language,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText:
                      _t('Idioma de salida', 'Output language'),
                  prefixIcon: const Icon(Icons.language),
                ),
                items: kLanguages
                    .map((l) => DropdownMenuItem(
                          value: l.code, child: Text(l.label),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => language = v);
                },
              ),
              const SizedBox(height: 16),
              LiquidButton(
                label: _t('Reproducir voz', 'Speak'),
                icon: Icons.volume_up,
                onPressed: translated == '—' ? null : _speak,
              ),
            ],
          ),
        ),
        // Toggle de Modo Frase
GlassCard(
  child: SwitchListTile(
    value: phraseMode,
    onChanged: (v) => setState(() {
      phraseMode = v;
      if (!v) phraseWords.clear();
    }),
    title: Text(_t('Modo Frase', 'Phrase Mode')),
    subtitle: Text(_t(
      'Acumula palabras y reproduce la oración completa',
      'Accumulate words and speak the full sentence',
    )),
  ),
),
// Si phraseMode está activo, mostrar palabras acumuladas
if (phraseMode) ...[
  const SizedBox(height: 12),
  GlassCard(
    child: Column(
      children: [
        Text(
          phraseWords.isEmpty
              ? _t('Sin palabras aún', 'No words yet')
              : phraseWords.join(' · '),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: LiquidButton(
                label: _t('Reproducir frase', 'Speak phrase'),
                icon: Icons.volume_up,
                onPressed: phraseWords.isEmpty ? null : _speakPhrase,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: LiquidButton(
                label: _t('Limpiar', 'Clear'),
                icon: Icons.clear,
                primary: false,
                onPressed: phraseWords.isEmpty
                    ? null
                    : () => setState(() => phraseWords.clear()),
              ),
            ),
          ],
        ),
      ],
    ),
  ),
],
        const SizedBox(height: 16),
        // Vista 3D en vivo
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t('Vista 3D en vivo', 'Live 3D view'),
                style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 15,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 200,
                child: Row(
                  children: [
                    Expanded(
                      child: Hand3DView(
                        frame: leftWindow.isEmpty
                            ? null
                            : leftWindow.last,
                        label: _t('Izquierda', 'Left'),
                        enabled: ble.leftConnected,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Hand3DView(
                        frame: rightWindow.isEmpty
                            ? null
                            : rightWindow.last,
                        label: _t('Derecha', 'Right'),
                        enabled: ble.rightConnected,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sensorSummary(),
      ],
    );
  }

  Widget _connectionStrip() {
    return Row(
      children: [
        Expanded(
          child: _statusCard(
            _t('Guante izquierdo', 'Left glove'),
            HandSide.left,
            ble.leftConnected,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statusCard(
            _t('Guante derecho', 'Right glove'),
            HandSide.right,
            ble.rightConnected,
          ),
        ),
      ],
    );
  }

  Widget _statusCard(String title, HandSide side, bool connected) {
    String subtitle;
    Color dot;

    if (!connected) {
      subtitle = _t('Desconectado', 'Disconnected');
      dot = const Color(0xFFFF4D6D);
    } else if (ble.receivingValidData(side)) {
      subtitle = _t('Datos válidos', 'Valid data');
      dot = const Color(0xFF22D3EE);
    } else if (ble.receivingBytes(side)) {
      subtitle =
          _t('Bytes sin formato', 'Bytes, bad format');
      dot = const Color(0xFFFFB020);
    } else {
      subtitle = _t('Esperando datos', 'Waiting for data');
      dot = const Color(0xFF8AA3C1);
    }

    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dot,
                  boxShadow: [
                    BoxShadow(
                      color: dot.withValues(alpha: 0.6),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(subtitle,
              style: const TextStyle(
                fontSize: 11, color: Color(0xFF91A6C0),
              )),
          if (connected) ...[
            const SizedBox(height: 4),
            Text(
              'RX ${ble.notificationCount(side)} · OK ${ble.validFrameCount(side)} · ✗ ${ble.badFrameCount(side)}',
              style: const TextStyle(
                fontSize: 10, color: Color(0xFF7188A6),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sensorSummary() {
    final l = leftWindow.isEmpty ? null : leftWindow.last;
    final r = rightWindow.isEmpty ? null : rightWindow.last;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_t('Datos actuales', 'Current data'),
              style: const TextStyle(
                fontWeight: FontWeight.w800, fontSize: 15,
              )),
          const SizedBox(height: 12),
          Text('${_t("Izquierda", "Left")}: ${_brief(l)}'),
          const SizedBox(height: 6),
          Text('${_t("Derecha", "Right")}: ${_brief(r)}'),
        ],
      ),
    );
  }

  String _brief(SensorFrame? f) {
    if (f == null) return '—';
    final bits = f.fingers.map((x) => x.round()).join();
    return '$bits · P ${f.pitch.toStringAsFixed(1)}° · '
        'R ${f.roll.toStringAsFixed(1)}°';
  }  Widget _addSignPage() {
    return AddSignPanel(
      uiLanguage: widget.uiLanguage,
      currentVector: _currentVector,
      currentLeft: () =>
          leftWindow.isEmpty ? null : leftWindow.last,
      currentRight: () =>
          rightWindow.isEmpty ? null : rightWindow.last,
      gestures: gestures,
      onSave: (g) async {
        final i = gestures.indexWhere(
          (x) => x.id.toLowerCase() == g.id.toLowerCase(),
        );
        if (i >= 0) {
          gestures[i] = g;
        } else {
          gestures.add(g);
        }
        await storage.save(gestures);
        if (mounted) setState(() {});
      },
      onDelete: (g) async {
        gestures.remove(g);
        await storage.save(gestures);
        if (mounted) setState(() {});
      },
    );
  }

  Widget _signsListPage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
      children: [
        Text(
          _t('Señas disponibles', 'Available signs'),
          style: const TextStyle(
            fontSize: 24, fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _t(
            '${gestures.length} seña(s) en el sistema.',
            '${gestures.length} sign(s) in the system.',
          ),
          style: const TextStyle(color: Color(0xFF91A6C0)),
        ),
        const SizedBox(height: 16),
        Row(
  children: [
    Expanded(
      child: OutlinedButton.icon(
        onPressed: () async {
          final path = await JsonExporter.exportToJson(gestures);
          if (!mounted) return;
          _snack(path != null
              ? _t('Señas exportadas a: $path', 'Signs exported to: $path')
              : _t('Error al exportar', 'Export failed'));
        },
        icon: const Icon(Icons.upload_file),
        label: Text(_t('Exportar JSON', 'Export JSON')),
      ),
    ),
    const SizedBox(width: 10),
    Expanded(
      child: OutlinedButton.icon(
        onPressed: () async {
          final imported = await JsonExporter.importFromJson();
          if (imported == null) {
            if (mounted) _snack(_t('Error al importar', 'Import failed'));
            return;
          }
          setState(() {
            for (final g in imported) {
              final i = gestures.indexWhere(
                  (x) => x.id.toLowerCase() == g.id.toLowerCase());
              if (i >= 0) {
                gestures[i] = g;
              } else {
                gestures.add(g);
              }
            }
          });
          await storage.save(gestures);
          if (mounted) {
            _snack(_t(
              '${imported.length} seña(s) importada(s)',
              '${imported.length} sign(s) imported',
            ));
          }
        },
        icon: const Icon(Icons.download),
        label: Text(_t('Importar JSON', 'Import JSON')),
      ),
    ),
  ],
),
        if (gestures.isEmpty)
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                _t(
                  'Todavía no hay señas guardadas.',
                  'No saved signs yet.',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ...gestures.map(
          (g) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: g.isDynamic
                            ? const [
                                Color(0xFF0A84FF),
                                Color(0xFF22D3EE),
                              ]
                            : const [
                                Color(0xFF7C3AED),
                                Color(0xFFEC4899),
                              ],
                      ),
                    ),
                    child: Icon(
                      g.isDynamic
                          ? Icons.waves
                          : Icons.pan_tool_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          g.id,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '${g.isDynamic ? _t("Dinámica", "Dynamic") : _t("Estática", "Static")} · '
                          '${g.isDynamic ? g.sequences.length : g.samples.length} ${_t("muestras", "samples")}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF91A6C0),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Color(0xFFFF4D6D)),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: Text(_t('Eliminar seña',
                              'Delete sign')),
                          content: Text(_t(
                            '¿Eliminar "${g.id}" del sistema?',
                            'Delete "${g.id}" from the system?',
                          )),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(context, false),
                              child: Text(_t('Cancelar', 'Cancel')),
                            ),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.pop(context, true),
                              child: Text(_t('Eliminar', 'Delete')),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await storage.save(
                          gestures..remove(g),
                        );
                        if (mounted) setState(() {});
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }  Widget _terminalPage() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _t('Terminal BLE', 'BLE Terminal'),
                  style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(logs.clear),
                icon: const Icon(Icons.delete_outline),
                label: Text(_t('Limpiar', 'Clear')),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: LiquidButton(
              label: ble.scanning
                  ? _t('Buscando...', 'Scanning...')
                  : _t('Buscar y conectar guantes',
                      'Scan and connect gloves'),
              icon: Icons.bluetooth_searching,
              onPressed: ble.scanning ? null : ble.scanAndAutoConnect,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: logs.isEmpty
              ? Center(
                  child: Text(
                    _t('Aún no hay datos recibidos.',
                        'No data received yet.'),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: logs.length,
                  itemBuilder: (_, i) {
                    final l = logs[i];
                    final t =
                        '${l.time.hour.toString().padLeft(2, '0')}:'
                        '${l.time.minute.toString().padLeft(2, '0')}:'
                        '${l.time.second.toString().padLeft(2, '0')}';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: GlassCard(
                        padding: const EdgeInsets.all(10),
                        radius: 14,
                        blur: 14,
                        child: Text(
                          '[$t] ${l.text}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11.5,
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}class Hand3DView extends StatelessWidget {
  final SensorFrame? frame;
  final String label;
  final bool enabled;

  const Hand3DView({
    super.key,
    required this.frame,
    required this.label,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(8),
      radius: 18,
      blur: 14,
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
            ),
          ),
          Expanded(
            child: Opacity(
              opacity: enabled ? 1 : 0.3,
              child: CustomPaint(
                painter: _Hand3DPainter(frame),
                size: Size.infinite,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hand3DPainter extends CustomPainter {
  final SensorFrame? f;
  _Hand3DPainter(this.f);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Rotaciones en radianes
    final pitch = (f?.pitch ?? 0) * math.pi / 180.0;
    final roll = (f?.roll ?? 0) * math.pi / 180.0;

    // Proyección isométrica simple
    Offset project(List<double> v) {
      // Rotación pitch (eje X)
      final cp = math.cos(pitch), sp = math.sin(pitch);
      final y1 = v[1] * cp - v[2] * sp;
      final z1 = v[1] * sp + v[2] * cp;
      // Rotación roll (eje Z)
      final cr = math.cos(roll), sr = math.sin(roll);
      final x2 = v[0] * cr - y1 * sr;
      final y2 = v[0] * sr + y1 * cr;
      return Offset(cx + x2 * 60, cy - y2 * 60 + z1 * 6);
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        colors: [Color(0xFF0A84FF), Color(0xFF22D3EE)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    // Palma
    final palmPts = <List<double>>[
      [-0.3, 0.4, 0], [0.3, 0.4, 0], [0.4, -0.1, 0],
      [0.2, -0.45, 0], [-0.2, -0.45, 0], [-0.4, -0.1, 0],
    ];
    final palmPath = Path();
    for (int i = 0; i < palmPts.length; i++) {
      final p = project(palmPts[i]);
      if (i == 0) {
        palmPath.moveTo(p.dx, p.dy);
      } else {
        palmPath.lineTo(p.dx, p.dy);
      }
    }
    palmPath.close();
    canvas.drawPath(palmPath, paint);

    // Dedos: 5 por mano. Cada dedo es un segmento desde la base.
    final extended = f?.fingers ?? [0, 0, 0, 0, 0];
    final baseAngles = [-0.6, -0.3, 0.0, 0.3, 0.6];
    for (int i = 0; i < 5; i++) {
      final base = <double>[
        baseAngles[i] * 0.5,
        0.4 - (i == 0 ? -0.1 : i == 4 ? 0.1 : 0.0),
        0,
      ];
      final len = extended[i] >= 0.5 ? 0.55 : 0.15;
      final tip = <double>[
        base[0] + baseAngles[i] * 0.5,
        base[1] + len,
        0,
      ];
      canvas.drawLine(project(base), project(tip), paint);
      // Nudillo
      canvas.drawCircle(project(tip), 2.5, paint);
    }

    // Punto central
    canvas.drawCircle(
      Offset(cx, cy),
      3,
      Paint()..color = const Color(0xFF0A84FF),
    );
  }

  @override
  bool shouldRepaint(covariant _Hand3DPainter old) => true;
}class _PulsePainter extends CustomPainter {
  final bool active;
  final double confidence;
  final bool dark;
  _PulsePainter({
    required this.active,
    required this.confidence,
    required this.dark,
  });                    

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 8;

    // Halo exterior
    final halo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = (active
              ? const Color(0xFF22D3EE)
              : (dark ? Colors.white : const Color(0xFF0A84FF)))
          .withValues(alpha: active ? 0.35 : 0.15);
    canvas.drawCircle(center, radius + 6, halo);

    // Círculo base
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = (dark
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.black.withValues(alpha: 0.06));
    canvas.drawCircle(center, radius, base);

    // Arco de confianza
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        colors: [Color(0xFF0A84FF), Color(0xFF22D3EE)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    final sweep = active ? (confidence.clamp(0.0, 1.0) * 2 * math.pi) : 0.0;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _PulsePainter old) =>
      old.active != active ||
      old.confidence != confidence ||
      old.dark != dark;
}class LogEntry {
  final DateTime time;
  final String text;
  LogEntry(this.text) : time = DateTime.now();
}class AddSignPanel extends StatefulWidget {
  final String uiLanguage;
  final List<double>? Function() currentVector;
  final SensorFrame? Function() currentLeft;
  final SensorFrame? Function() currentRight;
  final List<TrainingGesture> gestures;
  final Future<void> Function(TrainingGesture) onSave;
  final Future<void> Function(TrainingGesture) onDelete;

  const AddSignPanel({
    super.key,
    required this.uiLanguage,
    required this.currentVector,
    required this.currentLeft,
    required this.currentRight,
    required this.gestures,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<AddSignPanel> createState() => _AddSignPanelState();
}

class _AddSignPanelState extends State<AddSignPanel> {
  final name = TextEditingController();
  late final Map<String, TextEditingController> translations = {
    for (final l in kLanguages) l.code: TextEditingController(),
  };

  bool isDynamic = false;
  bool useLeft = true;
  bool useRight = true;
  int repetitions = 0;
  bool counting = false;
  int countdown = 0;
  bool ready = false;
  String message = '';

  // Para dinámico:
  final List<List<List<double>>> dynamicSamples = [];
  List<List<double>> dynamicRecording = [];
  final List<SensorFrame> leftLive = [];
  final List<SensorFrame> rightLive = [];
  Timer? liveTimer;

  String _t(String es, String en) =>
      widget.uiLanguage == 'en' ? en : es;

  @override
  void initState() {
    super.initState();
    message = _t(
      'Escribe el nombre y elige el tipo de seña.',
      'Enter a name and choose the sign type.',
    );
  }

  @override
  void dispose() {
    name.dispose();
    for (final c in translations.values) c.dispose();
    liveTimer?.cancel();
    super.dispose();
  }

  List<double>? _filteredVector() {
    final v = widget.currentVector();
    if (v == null || v.length < 26) return null;
    final out = List<double>.from(v);
    if (!useLeft) {
      for (int i = 0; i < 13; i++) out[i] = 0;
    }
    if (!useRight) {
      for (int i = 13; i < 26; i++) out[i] = 0;
    }
    return out;
  }

  Future<void> _startTrial() async {
    if (name.text.trim().isEmpty) {
      setState(() => message = _t(
        'Escribe el nombre de la seña.', 'Enter the sign name.'));
      return;
    }
    if (!useLeft && !useRight) {
      setState(() => message = _t(
        'Activa al menos un guante.', 'Enable at least one glove.'));
      return;
    }
    if (_filteredVector() == null) {
      setState(() => message = _t(
        'No hay datos recientes de los guantes.',
        'No recent glove data.'));
      return;
    }

    setState(() {
      counting = true;
      ready = false;
      countdown = 2;
      message = _t('Prepárate...', 'Get ready...');
    });

    for (int i = 2; i >= 1; i--) {
      if (!mounted) return;
      setState(() => countdown = i);
      SystemSound.play(SystemSoundType.click);
      await Future.delayed(const Duration(seconds: 1));
    }

    SystemSound.play(SystemSoundType.click);

    if (isDynamic) {
      dynamicRecording = [];
      liveTimer?.cancel();
      liveTimer = Timer.periodic(
        const Duration(milliseconds: 40), // 25 Hz
        (_) {
          final v = _filteredVector();
          if (v != null) dynamicRecording.add(v);
        },
      );
    }

    setState(() {
      countdown = 0;
      counting = false;
      ready = true;
      message = _t(
        'Realiza la seña y pulsa "Completar".',
        'Perform the sign and tap "Complete".',
      );
    });
  }

  void _completeTrial() {
    if (!ready) return;
    liveTimer?.cancel();

    if (isDynamic) {
      if (dynamicRecording.length < 8) {
        setState(() {
          ready = false;
          message = _t(
            'Grabación muy corta, intenta otra vez.',
            'Recording too short, try again.');
        });
        return;
      }
      dynamicSamples.add(List<List<double>>.from(dynamicRecording));
      repetitions = dynamicSamples.length;
    } else {
      final v = _filteredVector();
      if (v == null) {
        setState(() {
          ready = false;
          message = _t(
            'Se perdieron los datos. Intenta de nuevo.',
            'Data lost. Try again.');
        });
        return;
      }
      dynamicSamples.add([v]);
      repetitions = dynamicSamples.length;
    }

    SystemSound.play(SystemSoundType.click);
    setState(() {
      ready = false;
      message = repetitions < 10
          ? _t(
              'Repetición $repetitions/10 guardada.',
              'Repetition $repetitions/10 saved.')
          : _t('10/10 listas.', '10/10 complete.');
    });
  }

  Future<void> _save() async {
    if (repetitions != 10 || name.text.trim().isEmpty) return;
    final id = name.text.trim();
    final map = <String, String>{};
    for (final e in translations.entries) {
      final v = e.value.text.trim();
      map[e.key] = v.isEmpty ? id : v;
    }

    if (isDynamic) {
      await widget.onSave(TrainingGesture(
        id: id,
        translations: map,
        isDynamic: true,
        useLeft: useLeft,
        useRight: useRight,
        sequences: dynamicSamples,
      ));
    } else {
      await widget.onSave(TrainingGesture(
        id: id,
        translations: map,
        isDynamic: false,
        useLeft: useLeft,
        useRight: useRight,
        samples: dynamicSamples.map((s) => s.first).toList(),
      ));
    }

    if (!mounted) return;
    setState(() {
      dynamicSamples.clear();
      dynamicRecording.clear();
      repetitions = 0;
      name.clear();
      for (final c in translations.values) c.clear();
      ready = false;
      message = _t('Seña guardada.', 'Sign saved.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = counting
        ? (2 - countdown) / 2.0
        : repetitions / 10.0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
      children: [
        Text(
          _t('Agregar una nueva seña', 'Add a new sign'),
          style: const TextStyle(
            fontSize: 24, fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _t(
            'Cada seña se registra 10 veces. Antes de cada repetición hay una cuenta regresiva de 2 segundos.',
            'Each sign is recorded 10 times. Every repetition starts with a 2-second countdown.',
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          child: Column(
            children: [
              TextField(
                controller: name,
                decoration: InputDecoration(
                  labelText: _t('Nombre de la seña', 'Sign name'),
                  hintText: _t('Ej. Buenos días', 'e.g. Good morning'),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => isDynamic = false),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: !isDynamic
                              ? const LinearGradient(colors: [
                                  Color(0xFF7C3AED),
                                  Color(0xFFEC4899),
                                ])
                              : null,
                          color: isDynamic
                              ? (Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                      .withValues(alpha: 0.08)
                                  : Colors.white
                                      .withValues(alpha: 0.60))
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            _t('Estática', 'Static'),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: !isDynamic
                                  ? Colors.white
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => isDynamic = true),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: isDynamic
                              ? const LinearGradient(colors: [
                                  Color(0xFF0A84FF),
                                  Color(0xFF22D3EE),
                                ])
                              : null,
                          color: !isDynamic
                              ? (Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                      .withValues(alpha: 0.08)
                                  : Colors.white
                                      .withValues(alpha: 0.60))
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            _t('Dinámica', 'Dynamic'),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isDynamic
                                  ? Colors.white
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: useLeft,
                      onChanged: (v) =>
                          setState(() => useLeft = v ?? true),
                      title: Text(_t('Izquierdo', 'Left')),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ),
                  Expanded(
                    child: CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: useRight,
                      onChanged: (v) =>
                          setState(() => useRight = v ?? true),
                      title: Text(_t('Derecho', 'Right')),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (isDynamic) ...[
          const SizedBox(height: 16),
          _liveDualPanel(),
        ],
        const SizedBox(height: 20),
        Center(
          child: SizedBox(
            width: 140, height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 128, height: 128,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 8,
                    backgroundColor: Colors.white
                        .withValues(alpha: 0.15),
                    valueColor: const AlwaysStoppedAnimation(
                      Color(0xFF22D3EE),
                    ),
                  ),
                ),
                Text(
                  counting
                      ? '$countdown'
                      : '$repetitions/10',
                  style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: LiquidButton(
                label: _t('Iniciar', 'Start'),
                icon: Icons.play_arrow,
                onPressed: (counting || ready || repetitions >= 10)
                    ? null
                    : _startTrial,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: LiquidButton(
                label: _t('Completar', 'Complete'),
                icon: Icons.check,
                primary: false,
                onPressed: ready ? _completeTrial : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF0A84FF),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 18),
        Theme(
          data: Theme.of(context)
              .copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            title: Text(_t(
              'Traducciones opcionales',
              'Optional translations',
            )),
            children: kLanguages
                .map((l) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextField(
                        controller: translations[l.code],
                        decoration:
                            InputDecoration(labelText: l.label),
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 10),
        LiquidButton(
          label: _t('Guardar nueva seña', 'Save new sign'),
          icon: Icons.save,
          onPressed: repetitions == 10 ? _save : null,
        ),
      ],
    );
  }

  Widget _liveDualPanel() {
    return Row(
      children: [
        Expanded(
          child: _livePanel(widget.currentLeft(), 'L', useLeft),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _livePanel(widget.currentRight(), 'R', useRight),
        ),
      ],
    );
  }

  Widget _livePanel(SensorFrame? f, String tag, bool enabled) {
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        radius: 18,
        child: f == null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tag,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                      )),
                  const SizedBox(height: 8),
                  const Text('—'),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(tag,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                          )),
                      const Spacer(),
                      Text(
                        '|a| ${f.accelMagnitude.toStringAsFixed(2)}g',
                        style: const TextStyle(
                          fontSize: 10, color: Color(0xFF22D3EE),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(f.fingers.map((e) => e.round()).join(),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      )),
                  Text(
                    'P ${f.pitch.toStringAsFixed(1)}° '
                    'R ${f.roll.toStringAsFixed(1)}°',
                    style: const TextStyle(fontSize: 11),
                  ),
                  Text(
                    'A ${f.ax.toStringAsFixed(2)} '
                    '${f.ay.toStringAsFixed(2)} '
                    '${f.az.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 10),
                  ),
                  Text(
                    'G ${f.gx.toStringAsFixed(1)} '
                    '${f.gy.toStringAsFixed(1)} '
                    '${f.gz.toStringAsFixed(1)}',
                    style: const TextStyle(fontSize: 10),
                  ),
                  const SizedBox(height: 8),
                  // Mini gráfica de aceleración
                  SizedBox(
                    height: 26,
                    child: _MiniAccelChart(
                      frame: f,
                      color: tag == 'L'
                          ? const Color(0xFF0A84FF)
                          : const Color(0xFF22D3EE),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _MiniAccelChart extends StatelessWidget {
  final SensorFrame frame;
  final Color color;
  const _MiniAccelChart({required this.frame, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MiniAccelPainter(frame.accelMagnitude, color),
      size: Size.infinite,
    );
  }
}

class _MiniAccelPainter extends CustomPainter {
  final double magnitude;
  final Color color;
  _MiniAccelPainter(this.magnitude, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color.withValues(alpha: 0.65)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final centerY = size.height / 2;
    final norm = (magnitude / 3.0).clamp(0.0, 1.0);
    final x = norm * size.width;
    canvas.drawLine(
      Offset(0, centerY),
      Offset(x, centerY),
      p,
    );
    canvas.drawCircle(Offset(x, centerY), 3, p..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant _MiniAccelPainter old) => true;
}
