// ============================================================
//  models.dart
//  Estructuras de datos + parser binario + reconocimiento (KNN + DTW).
// ============================================================

import 'dart:math' as math;
import 'dart:typed_data';

enum HandSide { left, right }

/// Una trama de sensores de un guante.
class SensorFrame {
  final List<double> fingers; // 5 valores 0/1
  final double pitch;         // grados
  final double roll;          // grados
  final double ax, ay, az;    // g
  final double gx, gy, gz;    // °/s
  final DateTime time;

  SensorFrame({
    required this.fingers,
    required this.pitch,
    required this.roll,
    required this.ax,
    required this.ay,
    required this.az,
    required this.gx,
    required this.gy,
    required this.gz,
    DateTime? time,
  }) : time = time ?? DateTime.now();

  /// Decodifica el paquete binario de 17 bytes del ESP32.
  /// [0]      uint8_t  fingers (bit0=pulgar ... bit4=meñique)
  /// [1..2]   int16_t  pitch   /100
  /// [3..4]   int16_t  roll    /100
  /// [5..6]   int16_t  ax      /100
  /// [7..8]   int16_t  ay      /100
  /// [9..10]  int16_t  az      /100
  /// [11..12] int16_t  gx      /10
  /// [13..14] int16_t  gy      /10
  /// [15..16] int16_t  gz      /10
  static SensorFrame? fromBinary(List<int> bytes) {
    if (bytes.length < 17) return null;
    try {
      final u8 = Uint8List.fromList(bytes);
      final data = ByteData.sublistView(u8);

      final mask = data.getUint8(0);
      final fingers = <double>[
        (mask & 0x01) != 0 ? 1.0 : 0.0, // pulgar
        (mask & 0x02) != 0 ? 1.0 : 0.0, // índice
        (mask & 0x04) != 0 ? 1.0 : 0.0, // medio
        (mask & 0x08) != 0 ? 1.0 : 0.0, // anular
        (mask & 0x10) != 0 ? 1.0 : 0.0, // meñique
      ];

      int off = 1;
      double next(double scale) {
        final v = data.getInt16(off, Endian.little) / scale;
        off += 2;
        return v;
      }

      return SensorFrame(
        fingers: fingers,
        pitch: next(100.0),
        roll:  next(100.0),
        ax:    next(100.0),
        ay:    next(100.0),
        az:    next(100.0),
        gx:    next(10.0),
        gy:    next(10.0),
        gz:    next(10.0),
      );
    } catch (_) {
      return null;
    }
  }

  /// Parser CSV antiguo (compatibilidad con firmware viejo).
  static SensorFrame? fromCsv(String raw) {
    final parts = raw.trim().split(',');
    if (parts.length < 9) return null;
    final bits = parts[0].trim();
    if (!RegExp(r'^[01]{5}$').hasMatch(bits)) return null;

    final nums = <double>[];
    for (int i = 1; i < 9; i++) {
      final v = double.tryParse(parts[i].trim());
      if (v == null) return null;
      nums.add(v);
    }

    return SensorFrame(
      fingers: bits.split('').map((e) => double.parse(e)).toList(),
      pitch: nums[0],
      roll: nums[1],
      ax: nums[2],
      ay: nums[3],
      az: nums[4],
      gx: nums[5],
      gy: nums[6],
      gz: nums[7],
    );
  }

  /// Vector normalizado de 13 dimensiones por mano.
  List<double> normalizedVector() => [
        ...fingers,
        pitch / 180.0,
        roll / 180.0,
        ax / 20.0,
        ay / 20.0,
        az / 20.0,
        gx / 10.0,
        gy / 10.0,
        gz / 10.0,
      ];

  /// Aceleración resultante (para detección automática de movimiento).
  double get accelMagnitude =>
      math.sqrt(ax * ax + ay * ay + az * az);

  /// Etiqueta corta para el terminal.
  String shortLabel() {
    final b = fingers.map((f) => f >= .5 ? '1' : '0').join();
    return '$b P${pitch.toStringAsFixed(1)} '
        'R${roll.toStringAsFixed(1)} '
        'A(${ax.toStringAsFixed(2)},'
        '${ay.toStringAsFixed(2)},'
        '${az.toStringAsFixed(2)}) '
        'G(${gx.toStringAsFixed(1)},'
        '${gy.toStringAsFixed(1)},'
        '${gz.toStringAsFixed(1)})';
  }

  static SensorFrame average(List<SensorFrame> frames) {
    if (frames.isEmpty) {
      return SensorFrame(
        fingers: List.filled(5, 0),
        pitch: 0, roll: 0,
        ax: 0, ay: 0, az: 0,
        gx: 0, gy: 0, gz: 0,
      );
    }
    double avg(Iterable<double> xs) =>
        xs.reduce((a, b) => a + b) / xs.length;

    final fingerAvg = List<double>.generate(
      5,
      (i) => avg(frames.map((f) => f.fingers[i])) >= .5 ? 1.0 : 0.0,
    );

    return SensorFrame(
      fingers: fingerAvg,
      pitch: avg(frames.map((f) => f.pitch)),
      roll: avg(frames.map((f) => f.roll)),
      ax: avg(frames.map((f) => f.ax)),
      ay: avg(frames.map((f) => f.ay)),
      az: avg(frames.map((f) => f.az)),
      gx: avg(frames.map((f) => f.gx)),
      gy: avg(frames.map((f) => f.gy)),
      gz: avg(frames.map((f) => f.gz)),
    );
  }
}

/// Vector bimanual de 26 dimensiones (13 izq + 13 der).
class BimanualVector {
  final List<double> values;
  BimanualVector(this.values);

  static BimanualVector fromFrames(
    SensorFrame? left,
    SensorFrame? right, {
    bool useLeft = true,
    bool useRight = true,
  }) {
    final l = (useLeft && left != null)
        ? left.normalizedVector()
        : List<double>.filled(13, 0.0);
    final r = (useRight && right != null)
        ? right.normalizedVector()
        : List<double>.filled(13, 0.0);
    return BimanualVector([...l, ...r]);
  }

  List<double> get leftHalf => values.sublist(0, 13);
  List<double> get rightHalf => values.sublist(13, 26);
}

/// Seña entrenada (estática o dinámica).
class TrainingGesture {
  final String id;
  final Map<String, String> translations;
  final bool isDynamic;
  final bool useLeft;
  final bool useRight;

  /// Para señas estáticas: cada muestra es un vector de 26 dims.
  final List<List<double>> samples;

  /// Para señas dinámicas: cada muestra es una secuencia temporal.
  final List<List<List<double>>> sequences;

  TrainingGesture({
    required this.id,
    required this.translations,
    this.isDynamic = false,
    this.useLeft = true,
    this.useRight = true,
    List<List<double>>? samples,
    List<List<List<double>>>? sequences,
  })  : samples = samples ?? const [],
        sequences = sequences ?? const [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'translations': translations,
        'isDynamic': isDynamic,
        'useLeft': useLeft,
        'useRight': useRight,
        'samples': samples,
        'sequences': sequences,
      };

  static TrainingGesture fromJson(Map<String, dynamic> json) {
    final samples = (json['samples'] as List? ?? [])
        .map<List<double>>((e) => (e as List)
            .map<double>((x) => (x as num).toDouble())
            .toList())
        .toList();

    final sequences = (json['sequences'] as List? ?? [])
        .map<List<List<double>>>((seq) => (seq as List)
            .map<List<double>>((frame) => (frame as List)
                .map<double>((x) => (x as num).toDouble())
                .toList())
            .toList())
        .toList();

    return TrainingGesture(
      id: json['id'] as String,
      translations:
          Map<String, String>.from(json['translations'] as Map? ?? {}),
      isDynamic: json['isDynamic'] as bool? ?? false,
      useLeft: json['useLeft'] as bool? ?? true,
      useRight: json['useRight'] as bool? ?? true,
      samples: samples,
      sequences: sequences,
    );
  }
}

class RecognitionResult {
  final TrainingGesture gesture;
  final double distance;
  final double confidence;
  RecognitionResult(this.gesture, this.distance, this.confidence);
}

/// Motor de reconocimiento (KNN + DTW + umbrales relajados).
class GestureMath {
  static double vectorDistance(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return double.infinity;
    double sum = 0;
    for (int i = 0; i < a.length; i++) {
      final d = a[i] - b[i];
      sum += d * d;
    }
    return math.sqrt(sum / a.length);
  }

  /// DTW entre dos secuencias de vectores de la misma dimensión.
  static double dtw(
    List<List<double>> a,
    List<List<double>> b, {
    int band = 20,
  }) {
    if (a.isEmpty || b.isEmpty) return double.infinity;
    final n = a.length;
    final m = b.length;
    final w = math.max(band, (math.max(n, m) * 0.2).round());

    final inf = double.infinity;
    final prev = List<double>.filled(m + 1, inf);
    final curr = List<double>.filled(m + 1, inf);
    prev[0] = 0;

    for (int i = 1; i <= n; i++) {
      for (int j = 0; j <= m; j++) {
        curr[j] = inf;
      }
      final jStart = math.max(1, i - w);
      final jEnd = math.min(m, i + w);
      for (int j = jStart; j <= jEnd; j++) {
        final cost = vectorDistance(a[i - 1], b[j - 1]);
        final best = math.min(
          math.min(prev[j], curr[j - 1]),
          prev[j - 1],
        );
        curr[j] = cost + (best.isFinite ? best : 0);
      }
      for (int j = 0; j <= m; j++) {
        prev[j] = curr[j];
      }
    }
    return prev[m] / math.max(n, m);
  }

  /// Reconoce una seña estática (vector de 26 dims).
  static RecognitionResult? recognizeStatic(
    List<double> vector,
    List<TrainingGesture> gestures, {
    double threshold = 0.60, // relajado (antes 0.42)
    int k = 3,
  }) {
    RecognitionResult? best;

    for (final g in gestures) {
      if (g.isDynamic || g.samples.isEmpty) continue;
      final distances = g.samples
          .where((s) => s.length == vector.length)
          .map((s) => vectorDistance(vector, s))
          .toList()
        ..sort();
      if (distances.isEmpty) continue;

      final neighbors =
          distances.take(math.min(k, distances.length)).toList();
      final mean = neighbors.reduce((a, b) => a + b) / neighbors.length;
      final score = (1.0 - mean / threshold).clamp(0.0, 1.0).toDouble();

      if (best == null || mean < best.distance) {
        best = RecognitionResult(g, mean, score);
      }
    }

    if (best == null || best.distance > threshold) return null;
    return best;
  }

  /// Reconoce una seña dinámica (secuencia temporal).
  static RecognitionResult? recognizeDynamic(
    List<List<double>> sequence,
    List<TrainingGesture> gestures, {
    double threshold = 0.55, // relajado (antes 0.35)
    int k = 3,
  }) {
    if (sequence.isEmpty) return null;
    RecognitionResult? best;

    for (final g in gestures) {
      if (!g.isDynamic || g.sequences.isEmpty) continue;
      final distances = g.sequences
          .map((s) => dtw(sequence, s))
          .where((d) => d.isFinite)
          .toList()
        ..sort();
      if (distances.isEmpty) continue;

      final neighbors =
          distances.take(math.min(k, distances.length)).toList();
      final mean = neighbors.reduce((a, b) => a + b) / neighbors.length;
      final score = (1.0 - mean / threshold).clamp(0.0, 1.0).toDouble();

      if (best == null || mean < best.distance) {
        best = RecognitionResult(g, mean, score);
      }
    }

    if (best == null || best.distance > threshold) return null;
    return best;
  }
}

/// Detector de movimiento por aceleración resultante.
class MotionSegmenter {
  final double restMin;
  final double restMax;
  final int minFrames;

  bool _active = false;
  final List<List<double>> _buffer = [];
  int _stillFrames = 0;
  DateTime? _startedAt;

  MotionSegmenter({
    this.restMin = 0.80,
    this.restMax = 1.20,
    this.minFrames = 8,
  });

  bool get isActive => _active;
  int get frameCount => _buffer.length;

  /// Introduce una muestra. Devuelve una secuencia completa cuando
  /// el movimiento terminó.
  List<List<double>>? push(List<double> vector, double accelMag) {
    final resting = accelMag >= restMin && accelMag <= restMax;

    if (!_active) {
      if (!resting) {
        _active = true;
        _startedAt = DateTime.now();
        _buffer
          ..clear()
          ..add(vector);
        _stillFrames = 0;
      }
      return null;
    }

    _buffer.add(vector);

    if (resting) {
      _stillFrames++;
    } else {
      _stillFrames = 0;
    }

    final elapsed = DateTime.now().difference(_startedAt!);
    final tooLong = elapsed.inMilliseconds > 2500;

    if ((_stillFrames >= minFrames && _buffer.length >= minFrames) ||
        tooLong) {
      final result = List<List<double>>.from(_buffer);
      _active = false;
      _buffer.clear();
      _stillFrames = 0;
      _startedAt = null;
      return result.length >= minFrames ? result : null;
    }
    return null;
  }

  void reset() {
    _active = false;
    _buffer.clear();
    _stillFrames = 0;
    _startedAt = null;
  }
}

/// Ventana de permanencia: exige que la misma seña se detecte
/// de forma estable durante N ms antes de aceptarla.
class StabilityFilter {
  final Duration hold;
  String? _candidateId;
  DateTime? _since;

  StabilityFilter({this.hold = const Duration(milliseconds: 300)});

  bool confirm(String? id) {
    if (id == null) {
      _candidateId = null;
      _since = null;
      return false;
    }
    final now = DateTime.now();
    if (_candidateId != id) {
      _candidateId = id;
      _since = now;
      return false;
    }
    if (_since == null) {
      _since = now;
      return false;
    }
    return now.difference(_since!) >= hold;
  }

  void reset() {
    _candidateId = null;
    _since = null;
  }
}
