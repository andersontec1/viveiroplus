import 'package:cloud_firestore/cloud_firestore.dart';
import 'audit_helper.dart';

class EstoqueHelper {
  // Coleções
  static CollectionReference get _insumosCol =>
      FirebaseFirestore.instance.collection('insumos');
  static CollectionReference get _movCol =>
      FirebaseFirestore.instance.collection('movimentacoes_estoque');
  static CollectionReference get _lotesCol =>
      FirebaseFirestore.instance.collection('lotes_insumo');

  /// Registra entrada de um lote para um insumo e atualiza o estoque agregado.
  /// Retorna o ID do lote criado.
  static Future<String> registrarEntradaLote({
    required String insumoId,
    required num quantidade,
    String? unidade,
    String? lote,
    DateTime? validade,
    DateTime? fabricacao,
    String? fornecedor,
    String? nfNumero,
    double? precoUnitario,
    String? localArmazenamento,
    String? observacoes,
    String? responsavel,
    List<Map<String, dynamic>>?
    entregasPorPonto, // [{pontoId, nomePonto, quantidade}]
  }) async {
    if (quantidade <= 0) {
      throw ArgumentError('Quantidade deve ser maior que zero');
    }

    final insumoRef = _insumosCol.doc(insumoId);
    final insumoSnap = await insumoRef.get();
    if (!insumoSnap.exists) {
      throw Exception('Insumo não encontrado');
    }
    final insumo = insumoSnap.data() as Map<String, dynamic>;
    final tipoStr = (insumo['tipo'] ?? '').toString().toLowerCase();
    final isRacao = tipoStr == 'ração' || tipoStr == 'racao';

    // Regras obrigatórias de integridade para Ração
    if (isRacao) {
      if (validade == null) {
        throw Exception('Validade é obrigatória para entrada de ração.');
      }
      if (entregasPorPonto == null || entregasPorPonto.isEmpty) {
        throw Exception(
          'Distribuição por ponto de entrega é obrigatória para entrada de ração.',
        );
      }
      // Verificar soma das quantidades por ponto == quantidade total
      final soma = entregasPorPonto
          .map((e) => (e['quantidade'] ?? 0) as num)
          .fold<num>(0, (a, b) => a + b);
      if ((soma - quantidade).abs() > 0.0001) {
        throw Exception(
          'Soma das quantidades por ponto (${soma.toString()}) difere da quantidade total (${quantidade.toString()}).',
        );
      }
    }

    // Cria lote
    final loteDoc = await _lotesCol.add({
      'insumoId': insumoId,
      'nomeInsumo': insumo['nome'],
      'quantidade': quantidade,
      'unidade': unidade ?? insumo['unidade'],
      'lote': (lote ?? '').trim(),
      'validade': validade != null ? Timestamp.fromDate(validade) : null,
      'fabricacao': fabricacao != null ? Timestamp.fromDate(fabricacao) : null,
      'fornecedor': fornecedor ?? insumo['fornecedor'],
      'nfNumero': (nfNumero ?? '').trim(),
      'precoUnitario': precoUnitario,
      'custoTotal': precoUnitario != null ? precoUnitario * quantidade : null,
      'localArmazenamento': (localArmazenamento ?? '').trim(),
      'observacoes': (observacoes ?? '').trim(),
      'entregasPorPonto': (entregasPorPonto == null || entregasPorPonto.isEmpty)
          ? null
          : entregasPorPonto
                .map(
                  (e) => {
                    'pontoId': (e['pontoId'] ?? '').toString(),
                    'nomePonto': (e['nomePonto'] ?? '').toString(),
                    'quantidade': (e['quantidade'] ?? 0),
                  },
                )
                .toList(),
      'status': 'ativo',
      'dataEntrada': FieldValue.serverTimestamp(),
      'criadoEm': FieldValue.serverTimestamp(),
      'criadoPor': responsavel,
    });

    // Movimento de entrada
    await _movCol.add({
      'insumoId': insumoId,
      'nome': insumo['nome'],
      'tipo': insumo['tipo'],
      'tipoMov': 'entrada',
      'quantidade': quantidade,
      'unidade': unidade ?? insumo['unidade'],
      'loteId': loteDoc.id,
      'lote': (lote ?? '').trim(),
      'validade': validade != null ? Timestamp.fromDate(validade) : null,
      'fabricacao': fabricacao != null ? Timestamp.fromDate(fabricacao) : null,
      'fornecedor': fornecedor ?? insumo['fornecedor'],
      'nfNumero': (nfNumero ?? '').trim(),
      'precoUnitario': precoUnitario,
      'localArmazenamento': (localArmazenamento ?? '').trim(),
      'observacao': (observacoes ?? '').trim(),
      'entregasPorPonto': (entregasPorPonto == null || entregasPorPonto.isEmpty)
          ? null
          : entregasPorPonto
                .map(
                  (e) => {
                    'pontoId': (e['pontoId'] ?? '').toString(),
                    'nomePonto': (e['nomePonto'] ?? '').toString(),
                    'quantidade': (e['quantidade'] ?? 0),
                  },
                )
                .toList(),
      'timestamp': FieldValue.serverTimestamp(),
      'registradoPor': responsavel,
    });

    // Atualiza estoque agregado
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(insumoRef);
      final snapData = snap.data() as Map<String, dynamic>?;
      final atual = (snapData?['estoque'] ?? 0) as num;
      tx.update(insumoRef, {'estoque': atual + quantidade});
    });

    await _recomputarResumoInsumo(insumoId);

    await AuditHelper.registrarAcao(
      acao: 'ESTOQUE_ENTRADA',
      modulo: 'ESTOQUE',
      detalhes: {
        'insumoId': insumoId,
        'loteId': loteDoc.id,
        'quantidade': quantidade,
        'validade': validade?.toIso8601String(),
      },
    );

    return loteDoc.id;
  }

  /// Realiza saída utilizando FEFO (primeiro a vencer), ignorando lotes vencidos.
  /// Retorna a lista de lotes utilizados e suas quantidades consumidas.
  /// Lança uma Exception se não houver quantidade suficiente em lotes não-vencidos.
  static Future<List<Map<String, dynamic>>> registrarSaidaFefo({
    required String insumoNomeOuId,
    required num quantidade,
    String? origem, // ex: 'racao'
    String? referenciaId, // ex: ID do registro de ração
    String? responsavel,
    String? preferLoteId, // se informado, tenta consumir primeiro deste lote
    bool permitirVencidoPreferido =
        false, // se true e o preferido estiver vencido, permite consumir dele
  }) async {
    if (quantidade <= 0) {
      throw ArgumentError('Quantidade deve ser maior que zero');
    }

    // Localiza insumo por ID ou nome
    DocumentSnapshot? insumoSnap;
    if (insumoNomeOuId.length == 20) {
      // heurística simples para ID
      insumoSnap = await _insumosCol.doc(insumoNomeOuId).get();
    }
    if (insumoSnap == null || !insumoSnap.exists) {
      final byName = await _insumosCol
          .where('nome', isEqualTo: insumoNomeOuId)
          .limit(1)
          .get();
      if (byName.docs.isEmpty) throw Exception('Insumo não encontrado');
      insumoSnap = byName.docs.first;
    }
    final insumoId = insumoSnap.id;
    final insumo = insumoSnap.data() as Map<String, dynamic>;

    // Consulta lotes: ativos para o insumo
    final lotesSnap = await _lotesCol
        .where('insumoId', isEqualTo: insumoId)
        .where('status', isEqualTo: 'ativo')
        .get();

    final hoje = DateTime.now();
    final hojeBase = DateTime(hoje.year, hoje.month, hoje.day);

    // Monta lista primária com quantidade > 0
    final todosLotes = lotesSnap.docs
        .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
        .where((m) => (m['quantidade'] ?? 0) > 0)
        .toList();

    // Opcional: mover o lote preferido para a frente da fila de consumo
    Map<String, dynamic>? lotePreferido;
    if (preferLoteId != null && preferLoteId.isNotEmpty) {
      try {
        final idx = todosLotes.indexWhere((l) => l['id'] == preferLoteId);
        if (idx >= 0) {
          final cand = todosLotes[idx];
          final v = cand['validade'] is Timestamp
              ? (cand['validade'] as Timestamp).toDate()
              : null;
          final vencido = v != null && v.isBefore(hojeBase);
          if (!vencido || (vencido && permitirVencidoPreferido)) {
            lotePreferido = cand;
            todosLotes.removeAt(idx);
          }
        }
      } catch (_) {
        // ignora falhas ao posicionar preferido
      }
    }

    // Ordenação FEFO para os demais: validade mais próxima primeiro; nulls por último
    todosLotes.sort((a, b) {
      final av = a['validade'] is Timestamp
          ? (a['validade'] as Timestamp).toDate()
          : null;
      final bv = b['validade'] is Timestamp
          ? (b['validade'] as Timestamp).toDate()
          : null;
      if (av == null && bv == null) return 0;
      if (av == null) return 1;
      if (bv == null) return -1;
      return av.compareTo(bv);
    });

    // Fila final de consumo: preferido (se houver) seguido de FEFO; ignorar vencidos exceto o preferido quando permitido
    final fila = <Map<String, dynamic>>[];
    if (lotePreferido != null) fila.add(lotePreferido);
    fila.addAll(todosLotes);

    // 1) Simula consumo para verificar suficiência (sem escrever)
    num restante = quantidade;
    final planoConsumos =
        <Map<String, dynamic>>[]; // {id, lote, validade, consumir, novoSaldo}
    for (final lote in fila) {
      if (restante <= 0) break;
      final validade = lote['validade'] is Timestamp
          ? (lote['validade'] as Timestamp).toDate()
          : null;
      final vencido = validade != null && validade.isBefore(hojeBase);
      final ehPreferido =
          lotePreferido != null && lote['id'] == lotePreferido['id'];
      if (vencido && !(ehPreferido && permitirVencidoPreferido)) continue;
      final disp = (lote['quantidade'] ?? 0) as num;
      if (disp <= 0) continue;
      final consumir = disp >= restante ? restante : disp;
      planoConsumos.add({
        'id': lote['id'],
        'lote': lote['lote'] ?? '',
        'validade': validade,
        'consumir': consumir,
        'novoSaldo': disp - consumir,
      });
      restante -= consumir;
    }

    if (restante > 0) {
      // Quantidade insuficiente, nenhuma baixa deve ocorrer
      final temNaoVencidoDisponivel = todosLotes.any((l) {
        final v = l['validade'] is Timestamp
            ? (l['validade'] as Timestamp).toDate()
            : null;
        final qtd = (l['quantidade'] ?? 0) as num;
        return qtd > 0 && (v == null || !v.isBefore(hojeBase));
      });
      if (!temNaoVencidoDisponivel) {
        throw Exception(
          'Não há lotes válidos disponíveis para atender a quantidade solicitada. Todos os lotes estão vencidos.',
        );
      } else {
        throw Exception(
          'Estoque insuficiente em lotes não vencidos. Faltam $restante ${insumo['unidade'] ?? ''}.',
        );
      }
    }

    // 2) Aplica consumo de forma atômica via batch (tudo-ou-nada)
    final batch = FirebaseFirestore.instance.batch();
    final usados = <Map<String, dynamic>>[];
    for (final item in planoConsumos) {
      final loteRef = _lotesCol.doc(item['id'] as String);
      batch.update(loteRef, {'quantidade': item['novoSaldo']});
      final movRef = _movCol.doc();
      batch.set(movRef, {
        'insumoId': insumoId,
        'nome': insumo['nome'],
        'tipo': insumo['tipo'],
        'tipoMov': 'saida',
        'quantidade': item['consumir'],
        'unidade': insumo['unidade'],
        'loteId': item['id'],
        'lote': item['lote'],
        'validade': (item['validade'] as DateTime?) != null
            ? Timestamp.fromDate(item['validade'] as DateTime)
            : null,
        'origem': origem,
        'referenciaId': referenciaId,
        'timestamp': FieldValue.serverTimestamp(),
        'registradoPor': responsavel,
      });
      usados.add({
        'loteId': item['id'],
        'lote': item['lote'],
        'validade': (item['validade'] as DateTime?)?.toIso8601String(),
        'quantidade': item['consumir'],
      });
    }
    await batch.commit();

    // Recalcula o agregado e resumo a partir dos lotes atualizados
    await _recomputarResumoInsumo(insumoId);

    await AuditHelper.registrarAcao(
      acao: 'ESTOQUE_SAIDA_FEFO',
      modulo: 'ESTOQUE',
      detalhes: {
        'insumoId': insumoId,
        'quantidade': quantidade,
        'origem': origem,
        'referenciaId': referenciaId,
      },
    );

    return usados;
  }

  /// Recalcula e salva no insumo um resumo útil para listagens: próxima validade,
  /// quantidade de lotes vencidos e por vencer (<=7 dias).
  static Future<void> _recomputarResumoInsumo(String insumoId) async {
    final snap = await _lotesCol
        .where('insumoId', isEqualTo: insumoId)
        .where('status', isEqualTo: 'ativo')
        .get();
    final now = DateTime.now();
    DateTime? proximaVal;
    int vencidos = 0;
    int perto = 0;
    num somaEstoque = 0;
    for (final d in snap.docs) {
      final data = d.data() as Map<String, dynamic>;
      final qtd = (data['quantidade'] ?? 0) as num;
      if (qtd <= 0) continue;
      somaEstoque += qtd;
      final v = data['validade'] is Timestamp
          ? (data['validade'] as Timestamp).toDate()
          : null;
      if (v == null) continue;
      final vBase = DateTime(v.year, v.month, v.day);
      if (vBase.isBefore(DateTime(now.year, now.month, now.day))) {
        vencidos++;
      } else {
        final dias = vBase
            .difference(DateTime(now.year, now.month, now.day))
            .inDays;
        if (dias <= 7) perto++;
        if (proximaVal == null || vBase.isBefore(proximaVal)) {
          proximaVal = vBase;
        }
      }
    }
    // Obter estoque mínimo para calcular flag de baixo estoque
    num estoqueMinimo = 0;
    try {
      final insumoDoc = await _insumosCol.doc(insumoId).get();
      final data = insumoDoc.data() as Map<String, dynamic>?;
      if (data != null) {
        estoqueMinimo = (data['estoque_minimo'] ?? 0) as num;
      }
    } catch (_) {}

    final bool estoqueBaixo = estoqueMinimo > 0 && somaEstoque <= estoqueMinimo;

    await _insumosCol.doc(insumoId).update({
      // Reconciliar campo agregado com a soma dos lotes ativos
      'estoque': somaEstoque,
      'estoque_baixo': estoqueBaixo,
      'proxima_validade': proximaVal != null
          ? Timestamp.fromDate(proximaVal)
          : null,
      'qtd_lotes_vencidos': vencidos,
      'qtd_lotes_perto_vencer': perto,
    });
  }

  /// Recalcula o estoque agregado de um insumo a partir dos lotes ativos.
  static Future<void> reconciliarEstoqueDeInsumo(String insumoId) async {
    await _recomputarResumoInsumo(insumoId);
  }

  /// Reconciliar todos os insumos (custo: varre todos os lotes ativos). Use com parcimônia.
  static Future<void> reconciliarTodosInsumos() async {
    final insumos = await _insumosCol.get();
    for (final d in insumos.docs) {
      await _recomputarResumoInsumo(d.id);
    }
  }

  /// Marca um lote como inativo (soft-delete) e atualiza o resumo do insumo.
  static Future<void> inativarLote({required String loteId}) async {
    final doc = await _lotesCol.doc(loteId).get();
    if (!doc.exists) return;
    final data = doc.data() as Map<String, dynamic>;
    await _lotesCol.doc(loteId).update({'status': 'inativo'});
    final insumoId = data['insumoId'] as String?;
    if (insumoId != null) {
      await _recomputarResumoInsumo(insumoId);
    }
  }

  /// Atualiza campos de um lote e ajusta estoque agregado conforme mudança de quantidade.
  /// Apenas campos não nulos são atualizados. Se novaQuantidade for fornecida,
  /// o estoque do insumo é ajustado pela diferença (nova - atual).
  static Future<void> atualizarLote({
    required String loteId,
    num? novaQuantidade,
    DateTime? novaValidade,
    DateTime? novaFabricacao,
    String? novoFornecedor,
    String? novoCodigoLote,
    double? novoPrecoUnitario,
    String? novoLocalArmazenamento,
    String? novasObservacoes,
    String? responsavel,
  }) async {
    final loteSnap = await _lotesCol.doc(loteId).get();
    if (!loteSnap.exists) throw Exception('Lote não encontrado');
    final lote = loteSnap.data() as Map<String, dynamic>;
    final insumoId = lote['insumoId'] as String?;
    if (insumoId == null) throw Exception('Lote sem referência de insumo');

    // Prepara atualização
    final updates = <String, dynamic>{};
    num? diffQtd;
    if (novaQuantidade != null) {
      final atualQtd = (lote['quantidade'] ?? 0) as num;
      if (novaQuantidade < 0)
        throw Exception('Quantidade não pode ser negativa');
      diffQtd = novaQuantidade - atualQtd;
      updates['quantidade'] = novaQuantidade;
    }
    if (novaValidade != null)
      updates['validade'] = Timestamp.fromDate(novaValidade);
    if (novaFabricacao != null)
      updates['fabricacao'] = Timestamp.fromDate(novaFabricacao);
    if (novoFornecedor != null) updates['fornecedor'] = novoFornecedor.trim();
    if (novoCodigoLote != null) updates['lote'] = novoCodigoLote.trim();
    if (novoPrecoUnitario != null) {
      updates['precoUnitario'] = novoPrecoUnitario;
      // Recalcula custo total se quantidade disponível (após possível alteração)
      final qtdBase = (updates['quantidade'] ?? lote['quantidade'] ?? 0) as num;
      updates['custoTotal'] = qtdBase * novoPrecoUnitario;
    }
    if (novoLocalArmazenamento != null)
      updates['localArmazenamento'] = novoLocalArmazenamento.trim();
    if (novasObservacoes != null)
      updates['observacoes'] = novasObservacoes.trim();
    if (updates.isEmpty) return; // nada para fazer

    // Ajuste de estoque agregado se necessário
    if (diffQtd != null && diffQtd != 0) {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final insumoRef = _insumosCol.doc(insumoId);
        final insumoSnap = await tx.get(insumoRef);
        if (!insumoSnap.exists) throw Exception('Insumo não encontrado');
        final insumoData = insumoSnap.data() as Map<String, dynamic>?;
        final atualEstoque = (insumoData?['estoque'] ?? 0) as num;
        final novoEstoque = atualEstoque + diffQtd!;
        if (novoEstoque < 0)
          throw Exception('Resultado deixaria estoque negativo');
        tx.update(insumoRef, {'estoque': novoEstoque});
        tx.update(_lotesCol.doc(loteId), updates);
      });
    } else {
      await _lotesCol.doc(loteId).update(updates);
    }

    await _recomputarResumoInsumo(insumoId);

    await AuditHelper.registrarAcao(
      acao: 'ESTOQUE_ATUALIZAR_LOTE',
      modulo: 'ESTOQUE',
      detalhes: {
        'loteId': loteId,
        'insumoId': insumoId,
        'diffQuantidade': diffQtd,
        'responsavel': responsavel,
        'camposAlterados': updates.keys.toList(),
      },
    );
  }

  /// Estorna todas as saídas de estoque vinculadas a uma referência (ex.: registro de ração)
  /// - Incrementa o saldo dos lotes utilizados
  /// - Marca os movimentos como estornados
  /// - Cria movimentos de estorno para trilha de auditoria
  /// - Recalcula resumos dos insumos afetados
  static Future<void> estornarSaidasPorReferencia({
    required String origem,
    required String referenciaId,
    String? responsavel,
  }) async {
    final movs = await _movCol
        .where('origem', isEqualTo: origem)
        .where('referenciaId', isEqualTo: referenciaId)
        .where('tipoMov', isEqualTo: 'saida')
        .get();
    if (movs.docs.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    final insumosAfetados = <String>{};

    for (final d in movs.docs) {
      final m = d.data() as Map<String, dynamic>;
      if (m['estornado'] == true) continue; // idempotência
      final insumoId = (m['insumoId'] ?? '').toString();
      final loteId = (m['loteId'] ?? '').toString();
      final qtd = (m['quantidade'] ?? 0) as num;
      if (loteId.isNotEmpty && qtd != 0) {
        // devolve saldo ao lote
        final loteRef = _lotesCol.doc(loteId);
        batch.update(loteRef, {'quantidade': FieldValue.increment(qtd)});
      }

      // marca movimento original como estornado
      batch.update(d.reference, {
        'estornado': true,
        'estornadoEm': FieldValue.serverTimestamp(),
        'estornadoPor': responsavel,
      });

      // cria registro de estorno
      final estornoRef = _movCol.doc();
      batch.set(estornoRef, {
        'insumoId': insumoId,
        'nome': m['nome'],
        'tipo': m['tipo'],
        'tipoMov': 'estorno',
        'quantidade': qtd,
        'unidade': m['unidade'],
        'loteId': loteId,
        'lote': m['lote'],
        'validade': m['validade'],
        'origem': origem,
        'referenciaId': referenciaId,
        'referenciaMovId': d.id,
        'timestamp': FieldValue.serverTimestamp(),
        'registradoPor': responsavel,
      });

      if (insumoId.isNotEmpty) insumosAfetados.add(insumoId);
    }

    await batch.commit();

    // Recalcular resumos
    for (final insumoId in insumosAfetados) {
      await _recomputarResumoInsumo(insumoId);
    }

    await AuditHelper.registrarAcao(
      acao: 'ESTOQUE_ESTORNO_SAIDA',
      modulo: 'ESTOQUE',
      detalhes: {
        'origem': origem,
        'referenciaId': referenciaId,
        'insumosAfetados': insumosAfetados.toList(),
      },
    );
  }
}
