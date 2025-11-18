import 'package:cloud_firestore/cloud_firestore.dart';

class ParametrosAnaliseHelper {
  static const String collection = 'parametros_analise_agua';

  // Valores padrão (fallback) quando não houver configuração no Firestore
  static const Map<String, Map<String, num>> defaults = {
    'ph': {'min': 7.0, 'max': 9.0},
    'oxigenio': {'min': 4.0, 'max': 14.0},
    'saturacao_percentual': {'min': 80.0, 'max': 120.0},
    'temperatura': {'min': 26.0, 'max': 32.0},
    'turbidez': {'min': 40.0, 'max': 60.0},
    'salinidade': {'min': 30.0, 'max': 45.0},
    'calcio': {'min': 100.0, 'max': 300.0},
    'nitrito': {'min': 0.0, 'max': 0.5},
    'amonia': {'min': 0.0, 'max': 1.5},
  };

  static Map<String, Map<String, double>> getDefaultsAsDouble() {
    final Map<String, Map<String, double>> out = {};
    defaults.forEach((k, v) {
      out[k] = {
        'min': (v['min'] ?? 0).toDouble(),
        'max': (v['max'] ?? 0).toDouble(),
      };
    });
    return out;
  }

  static Future<Map<String, Map<String, double>>> carregarTodos() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection(collection)
          .get();
      if (snap.docs.isEmpty) {
        return getDefaultsAsDouble();
      }
      final Map<String, Map<String, double>> out = getDefaultsAsDouble();
      for (final d in snap.docs) {
        final data = d.data();
        final min = (data['min'] as num?)?.toDouble();
        final max = (data['max'] as num?)?.toDouble();
        if (min != null && max != null) {
          out[d.id] = {'min': min, 'max': max};
        }
      }
      return out;
    } catch (_) {
      // Fallback em caso de erro
      return getDefaultsAsDouble();
    }
  }

  static Future<void> salvarLote(
    Map<String, Map<String, double>> faixas,
  ) async {
    final batch = FirebaseFirestore.instance.batch();
    final col = FirebaseFirestore.instance.collection(collection);
    faixas.forEach((key, range) {
      final docRef = col.doc(key);
      batch.set(docRef, {
        'min': range['min'],
        'max': range['max'],
        'atualizadoEm': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
    await batch.commit();
  }
}
