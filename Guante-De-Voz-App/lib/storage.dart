// ============================================================
//  storage.dart
//  Guarda y carga las señas entrenadas en SharedPreferences.
//  Se usa desde HomeShell (_load, onSave, onDelete).
// ============================================================

import 'dart:convert';                             // jsonEncode / jsonDecode
import 'package:shared_preferences/shared_preferences.dart'; // Almacenamiento local
import 'models.dart';                              // TrainingGesture

class GestureStorage {
  // Clave usada en SharedPreferences. Cambiada a v2 por el nuevo formato.
  static const _key = 'trained_gestures_v2';

  /// Carga la lista de señas guardadas. Devuelve [] si no hay nada.
  Future<List<TrainingGesture>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) =>
              TrainingGesture.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      // Si el JSON está corrupto, devolvemos lista vacía.
      return [];
    }
  }

  /// Guarda la lista completa de señas en SharedPreferences.
  Future<void> save(List<TrainingGesture> gestures) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(gestures.map((g) => g.toJson()).toList()),
    );
  }

  /// Borra todas las señas guardadas. (No se usa actualmente.)
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
