import 'package:cloud_firestore/cloud_firestore.dart';

class DestinosCache {
  static Map<String, String>? _viveiros;
  static Map<String, String>? _bercarios;
  static DateTime? _ultimoFetch;
  static const Duration _ttl = Duration(minutes: 5);

  static bool _expirado() {
    if (_ultimoFetch == null) return true;
    return DateTime.now().difference(_ultimoFetch!) > _ttl;
  }

  static Future<void> _carregarSeNecessario() async {
    if (_viveiros != null && _bercarios != null && !_expirado()) return;
    final v = await FirebaseFirestore.instance.collection('viveiros').get();
    final b = await FirebaseFirestore.instance.collection('bercarios').get();
    final tmpV = <String, String>{};
    final tmpB = <String, String>{};
    for (final d in v.docs) {
      final m = d.data();
      final c = m['codigo'];
      final n = m['nome'];
      if (c != null && n != null) tmpV[c] = n;
    }
    for (final d in b.docs) {
      final m = d.data();
      final c = m['codigo'];
      final n = m['nome'];
      if (c != null && n != null) tmpB[c] = n;
    }
    _viveiros = tmpV;
    _bercarios = tmpB;
    _ultimoFetch = DateTime.now();
  }

  static Future<Map<String, String>> obterViveiros() async {
    await _carregarSeNecessario();
    return Map.unmodifiable(_viveiros!);
  }

  static Future<Map<String, String>> obterBercarios() async {
    await _carregarSeNecessario();
    return Map.unmodifiable(_bercarios!);
  }

  static void limpar() {
    _viveiros = null;
    _bercarios = null;
    _ultimoFetch = null;
  }
}
