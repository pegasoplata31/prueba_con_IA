// ============================================================
//  json_exporter.dart
//  Exporta e importa las señas entrenadas en formato JSON.
//  Se usa desde la pantalla "Señas" (botones Exportar/Importar).
// ============================================================

import 'dart:convert';                          // Para jsonEncode / jsonDecode
import 'dart:io';                               // Para File, Directory
import 'package:file_picker/file_picker.dart';  // Selector de archivos
import 'package:path_provider/path_provider.dart'; // Para obtener carpetas
import 'models.dart';                           // TrainingGesture

class JsonExporter {
  /// Exporta todas las señas a un archivo JSON en el almacenamiento
  /// interno de la app. Devuelve la ruta del archivo creado o null si falla.
  static Future<String?> exportToJson(List<TrainingGesture> gestures) async {
    try {
      // Construye el objeto JSON con versión, fecha y todas las señas.
      final jsonData = jsonEncode({
        'version': 2,
        'exportedAt': DateTime.now().toIso8601String(),
        'count': gestures.length,
        'gestures': gestures.map((g) => g.toJson()).toList(),
      });

      // Guarda el archivo en la carpeta de documentos de la app.
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/beyond_words_signs.json');
      await file.writeAsString(jsonData);

      return file.path;
    } catch (e) {
      // Si algo falla, devolvemos null para que la UI muestre el error.
      return null;
    }
  }

  /// Abre el selector de archivos para que el usuario elija un JSON
  /// previamente exportado. Devuelve la lista de señas o null si falla.
  static Future<List<TrainingGesture>?> importFromJson() async {
    try {
      // Selector limitado a archivos .json.
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.single.path == null) return null;

      // Lee el archivo y lo decodifica.
      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      final list = data['gestures'] as List;

      // Reconstruye cada seña desde su JSON.
      return list
          .map((e) =>
              TrainingGesture.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      return null;
    }
  }
}
