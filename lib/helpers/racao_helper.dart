import 'package:cloud_firestore/cloud_firestore.dart';

class RacaoHelper {
  /// Recalcula totalAcumulado e diaCiclo para todos os registros do mesmo destino.
  static Future<void> reprocessarDestinoFromBase(
    Map<String, dynamic> base,
  ) async {
    final String? tipo = base['tipoDestino'] as String?;
    final String? codigo = base['codigoDestino'] as String?;
    if (tipo == null || codigo == null) return;
    await reprocessarDestino(tipo: tipo, codigo: codigo);
  }

  static Future<void> reprocessarDestino({
    required String tipo,
    required String codigo,
  }) async {
    // Buscar início do ciclo
    DateTime? inicioCiclo;
    try {
      final cicloSnap = await FirebaseFirestore.instance
          .collection('ciclos')
          .where('codigo', isEqualTo: codigo)
          .where('encerrado', isEqualTo: false)
          .limit(1)
          .get();
      if (cicloSnap.docs.isNotEmpty) {
        final cd = cicloSnap.docs.first.data();
        if (cd['dataPovoamento'] is Timestamp) {
          inicioCiclo = (cd['dataPovoamento'] as Timestamp).toDate();
        } else if (cd['dataInicio'] is Timestamp) {
          inicioCiclo = (cd['dataInicio'] as Timestamp).toDate();
        }
      }
    } catch (_) {}

    // Busca todos os registros do destino ordenados por data
    final qs = await FirebaseFirestore.instance
        .collection('racao')
        .where('tipoDestino', isEqualTo: tipo)
        .where('codigoDestino', isEqualTo: codigo)
        .orderBy('dataRegistro')
        .limit(1000)
        .get();

    double acumulado = 0.0;
    final int batchLimit = 400;
    WriteBatch? batch;
    int ops = 0;
    for (final d in qs.docs) {
      final m = d.data();
      final q = (m['quantidade'] ?? 0);
      if (q is num) acumulado += q.toDouble();

      final ts = m['dataRegistro'] as Timestamp?;
      int? diaCiclo;
      if (inicioCiclo != null && ts != null) {
        final rd = ts.toDate();
        final inicioDia = DateTime(rd.year, rd.month, rd.day);
        final inicioBase = DateTime(
          inicioCiclo.year,
          inicioCiclo.month,
          inicioCiclo.day,
        );
        diaCiclo = inicioDia.difference(inicioBase).inDays + 1;
      }

      batch ??= FirebaseFirestore.instance.batch();
      final docRef = d.reference;
      final payload = <String, dynamic>{'totalAcumulado': acumulado};
      if (diaCiclo != null) payload['diaCiclo'] = diaCiclo;
      batch.update(docRef, payload);
      ops++;
      if (ops >= batchLimit) {
        await batch.commit();
        batch = null;
        ops = 0;
      }
    }
    if (batch != null && ops > 0) {
      await batch.commit();
    }
  }
}
