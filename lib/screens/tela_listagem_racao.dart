import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/degrade_fundo.dart';
import 'detalhes_racao_dialog.dart';
import 'tela_arracoador.dart';
import '../helpers/security_helper.dart';
import '../helpers/confirmation_helper.dart';
import '../helpers/audit_helper.dart';
import '../helpers/racao_helper.dart';
import '../helpers/estoque_helper.dart';

class TelaListagemRacao extends StatefulWidget {
  const TelaListagemRacao({super.key});

  @override
  State<TelaListagemRacao> createState() => _TelaListagemRacaoState();
}

class _TelaListagemRacaoState extends State<TelaListagemRacao> {
  String? _tipoSelecionado;
  String? _codigoSelecionado;
  String? _destinoCompleto;
  DateTime? _dataFiltro;
  bool _carregandoPreferencias = true;
  bool _verTodos =
      false; // novo: listar todos os registros independente do destino
  // Nomes dos insumos de aditivos (carregados de Firestore)
  String? _nomeInsumoProbiotico;
  String? _nomeInsumoSuplemento;
  // Indicador não utilizado diretamente na UI; removido para evitar lint

  // Cache para dados do ciclo
  Map<String, dynamic>? _cicloCache;
  // Removido _dataCicloCache não utilizado após refatoração do FAB sempre visível

  // Cache de lotes para enriquecer chips com fornecedor/validade
  final Map<String, Map<String, dynamic>> _loteCache = {};
  final Set<String> _carregandoLoteIds = {};

  bool _podeExcluir = false;

  @override
  void initState() {
    super.initState();
    _carregarUltimaSelecao();
    _carregarNomesAditivos();
    _carregarPermissaoExclusao();
  }

  // Carregar última seleção do usuário
  Future<void> _carregarUltimaSelecao() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tipo = prefs.getString('racao_ultimo_tipo');
      final codigo = prefs.getString('racao_ultimo_codigo');
      final destino = prefs.getString('racao_ultimo_destino');
      // Padrão desejado: ao entrar, ver todos por padrão
      final verTodos = prefs.getBool('racao_ver_todos') ?? true;

      if (tipo != null && codigo != null && destino != null) {
        setState(() {
          _tipoSelecionado = tipo;
          _codigoSelecionado = codigo;
          _destinoCompleto = destino;
        });
      }
      // aplica preferências do toggle mesmo sem destino salvo
      if (mounted) {
        setState(() {
          _verTodos = verTodos;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar preferências: $e');
    } finally {
      setState(() {
        _carregandoPreferencias = false;
      });
    }
  }

  // Normaliza strings (minúsculas e sem acentos) para comparações simples
  String _norm(String? input) {
    if (input == null) return '';
    var s = input.toLowerCase().trim();
    s = s.replaceAll(RegExp(r'[áàâãä]'), 'a');
    s = s.replaceAll(RegExp(r'[éèêë]'), 'e');
    s = s.replaceAll(RegExp(r'[íìïî]'), 'i');
    s = s.replaceAll(RegExp(r'[óòôõö]'), 'o');
    s = s.replaceAll(RegExp(r'[úùûü]'), 'u');
    s = s.replaceAll('ç', 'c');
    return s;
  }

  // Carrega os nomes dos insumos de Probiótico e Suplemento (para exibir na lista)
  Future<void> _carregarNomesAditivos() async {
    // carrega em background sem expor indicador visual
    try {
      final snap = await FirebaseFirestore.instance
          .collection('insumos')
          .limit(200)
          .get();
      String? nomeProb;
      String? nomeSupl;
      for (final d in snap.docs) {
        final data = d.data();
        final tipo = _norm(data['tipo']?.toString());
        if (tipo == 'probiotico' && nomeProb == null) {
          nomeProb = (data['nome'] ?? 'Probiótico').toString();
        }
        if (tipo == 'suplemento' && nomeSupl == null) {
          nomeSupl = (data['nome'] ?? 'Suplemento').toString();
        }
        if (nomeProb != null && nomeSupl != null) break;
      }
      if (mounted) {
        setState(() {
          _nomeInsumoProbiotico = nomeProb;
          _nomeInsumoSuplemento = nomeSupl;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar nomes de aditivos: $e');
    } finally {}
  }

  // Salvar seleção atual
  Future<void> _salvarSelecao() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('racao_ver_todos', _verTodos);
      if (_tipoSelecionado != null &&
          _codigoSelecionado != null &&
          _destinoCompleto != null) {
        await prefs.setString('racao_ultimo_tipo', _tipoSelecionado!);
        await prefs.setString('racao_ultimo_codigo', _codigoSelecionado!);
        await prefs.setString('racao_ultimo_destino', _destinoCompleto!);
      }
    } catch (e) {
      debugPrint('Erro ao salvar preferências: $e');
    }
  }

  // Função helper para obter o nome do destino com compatibilidade
  String _obterNomeDestino(Map<String, dynamic> data) {
    if (data['destinoNome'] != null &&
        data['destinoNome'].toString().isNotEmpty) {
      return data['destinoNome'];
    }
    return data['viveiro'] ?? 'Sem destino';
  }

  // Função helper para obter status de probiótico com compatibilidade
  bool _obterStatusProbiotico(Map<String, dynamic> data) {
    if (data.containsKey('probioticoAplicado')) {
      return data['probioticoAplicado'] == true;
    }
    if (data.containsKey('probióticoAplicado')) {
      return data['probióticoAplicado'] == true;
    }
    return false;
  }

  // Função helper para obter status de suplemento
  bool _obterStatusSuplemento(Map<String, dynamic> data) {
    return data['suplementoAplicado'] == true;
  }

  // Verificar se o registro pertence ao destino filtrado
  // Método _registroPertenceAoFiltro removido (lógica de filtro agora diretamente na query)

  // Limpar cache quando mudar seleção
  void _limparCache() {
    _cicloCache = null;
  }

  void _abrirDetalhes(Map<String, dynamic> data, String docId) {
    showDialog(
      context: context,
      builder: (context) => DetalhesRacaoDialog(
        dados: data,
        docId: docId,
        podeExcluir: _podeExcluir,
        onExcluir: () => _excluirRegistro(docId, data),
      ),
    );
  }

  Future<void> _carregarPermissaoExclusao() async {
    try {
      final adm = await SecurityHelper.temFuncaoAdministrativa();
      if (mounted) setState(() => _podeExcluir = adm);
    } catch (_) {}
  }

  Future<void> _excluirRegistro(
    String docId,
    Map<String, dynamic> dados,
  ) async {
    final destino = dados['destinoNome'] ?? dados['viveiro'] ?? 'Destino';
    final confirmar = await ConfirmationHelper.showDoubleConfirmation(
      context: context,
      title: 'Excluir registro de ração?',
      content:
          'Você está prestes a excluir o registro para "$destino". O estoque (ração e aditivos vinculados) será estornado automaticamente.',
      secondTitle: 'Confirma exclusão?',
      secondContent:
          'A exclusão é irreversível no histórico. Deseja continuar?',
      actionLabel: 'Excluir',
      actionColor: Colors.red,
      showId: false,
      id: docId,
    );
    if (confirmar != true) return;

    try {
      // Estornar saídas de estoque referentes a este registro (ração + aditivos)
      try {
        // Estorna saídas de estoque (ração e aditivos) vinculadas a este registro
        // ignore: avoid_dynamic_calls
        await EstoqueHelper.estornarSaidasPorReferencia(
          origem: 'racao',
          referenciaId: docId,
          responsavel: dados['registradoPor']?.toString(),
        );
      } catch (e) {
        debugPrint('Falha ao estornar estoque: $e');
      }

      // Remove o documento de ração
      await FirebaseFirestore.instance.collection('racao').doc(docId).delete();

      // Auditoria
      await AuditHelper.registrarAcao(
        acao: 'RACAO_EXCLUIDA',
        modulo: 'RACAO',
        detalhes: {
          'registroId': docId,
          'destino': destino,
          'quantidade': dados['quantidade'],
          'dataRegistro': (dados['dataRegistro'] is Timestamp)
              ? (dados['dataRegistro'] as Timestamp).toDate().toIso8601String()
              : dados['dataRegistro']?.toString(),
        },
      );

      // Reprocessar acumulado e dia do ciclo para o destino (se campos padronizados existirem)
      try {
        await RacaoHelper.reprocessarDestinoFromBase(dados);
      } catch (e) {
        debugPrint('Falha ao reprocessar acumulados após exclusão: $e');
      }

      if (mounted) {
        await ConfirmationHelper.showSuccess(
          context: context,
          title: 'Registro excluído',
          content: 'O registro de ração foi removido com sucesso.',
          icon: Icons.delete_forever,
          iconColor: Colors.red,
          backgroundColor: const Color(0xFFFFCDD2),
        );
      }
    } catch (e) {
      if (mounted) {
        await ConfirmationHelper.showError(
          context: context,
          content: 'Não foi possível excluir o registro.',
          error: e.toString(),
        );
      }
    }
  }

  // Recalcula totalAcumulado e diaCiclo para todos os registros do mesmo destino

  // Pré-carrega dados dos lotes referenciados nos registros atuais (fornecedor/validade)
  void _precarregarLotesParaRegistros(
    List<QueryDocumentSnapshot> registros,
  ) async {
    try {
      // Coletar todos os IDs de lote presentes nos registros (ração + aditivos)
      final ids = <String>{};
      for (final doc in registros) {
        final data = doc.data() as Map<String, dynamic>;
        final List<dynamic> lotesUsados = (data['lotesUsados'] is List)
            ? (data['lotesUsados'] as List)
            : const [];
        for (final lu in lotesUsados) {
          final Map<String, dynamic> m;
          if (lu is Map<String, dynamic>) {
            m = lu;
          } else if (lu is Map) {
            m = Map<String, dynamic>.from(lu);
          } else {
            m = <String, dynamic>{};
          }
          final id = (m['loteId'] ?? '').toString();
          if (id.isNotEmpty) ids.add(id);
        }
        final List<dynamic> probioticoUsados =
            (data['probioticoUsados'] is List)
            ? (data['probioticoUsados'] as List)
            : const [];
        for (final lu in probioticoUsados) {
          final Map<String, dynamic> m;
          if (lu is Map<String, dynamic>) {
            m = lu;
          } else if (lu is Map) {
            m = Map<String, dynamic>.from(lu);
          } else {
            m = <String, dynamic>{};
          }
          final id = (m['loteId'] ?? '').toString();
          if (id.isNotEmpty) ids.add(id);
        }
        final List<dynamic> suplementoUsados =
            (data['suplementoUsados'] is List)
            ? (data['suplementoUsados'] as List)
            : const [];
        for (final lu in suplementoUsados) {
          final Map<String, dynamic> m;
          if (lu is Map<String, dynamic>) {
            m = lu;
          } else if (lu is Map) {
            m = Map<String, dynamic>.from(lu);
          } else {
            m = <String, dynamic>{};
          }
          final id = (m['loteId'] ?? '').toString();
          if (id.isNotEmpty) ids.add(id);
        }
      }

      // Filtrar os que faltam no cache e que não estão sendo carregados
      final faltantes = ids
          .where(
            (id) =>
                !_loteCache.containsKey(id) && !_carregandoLoteIds.contains(id),
          )
          .toList();
      if (faltantes.isEmpty) return;

      // Marcar como em carregamento
      _carregandoLoteIds.addAll(faltantes);

      // Firestore limita whereIn a 10 itens por query
      const int batchSize = 10;
      for (var i = 0; i < faltantes.length; i += batchSize) {
        final slice = faltantes.sublist(
          i,
          i + batchSize > faltantes.length ? faltantes.length : i + batchSize,
        );
        try {
          final snap = await FirebaseFirestore.instance
              .collection('lotes_insumo')
              .where(FieldPath.documentId, whereIn: slice)
              .get();
          for (final d in snap.docs) {
            _loteCache[d.id] = d.data();
          }
        } catch (e) {
          debugPrint('Falha ao pré-carregar lotes: $e');
        }
      }

      _carregandoLoteIds.removeAll(faltantes);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Erro no pré-carregamento de lotes: $e');
    }
  }

  void _limparFiltros() {
    setState(() {
      _dataFiltro = null;
    });
  }

  Future<void> _selecionarData() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dataFiltro ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _dataFiltro = picked);
    }
  }

  // Mostrar erro padrão
  // _mostrarErro removido (não utilizado após simplificação)

  Widget _buildSeletorTipo() {
    final entries = const <ButtonSegment<String>>[
      ButtonSegment<String>(
        value: 'viveiro',
        label: Text('Viveiro'),
        icon: Icon(Icons.water_outlined),
      ),
      ButtonSegment<String>(
        value: 'bercario',
        label: Text('Berçário'),
        icon: Icon(Icons.biotech_outlined),
      ),
    ];
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Destino',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: entries,
              selected: <String>{
                if (_tipoSelecionado != null) _tipoSelecionado!,
              },
              emptySelectionAllowed: true,
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              onSelectionChanged: (newSel) {
                final value = newSel.isNotEmpty ? newSel.first : null;
                setState(() {
                  _tipoSelecionado = value;
                  _codigoSelecionado = null;
                  _destinoCompleto = null;
                  _limparCache();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeletorCodigo() {
    if (_tipoSelecionado == null) return const SizedBox();

    // Coleção correta em Firestore: 'bercarios' (sem cedilha)
    final colecao = _tipoSelecionado == 'viveiro' ? 'viveiros' : 'bercarios';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection(colecao)
              .orderBy('nome')
              .snapshots()
              .handleError((e) {
                // Fallback para coleção escrita incorretamente no passado: 'berçarios'
                if (colecao == 'bercarios') {
                  return FirebaseFirestore.instance
                      .collection('berçarios')
                      .orderBy('nome')
                      .snapshots();
                }
                return Stream.error(e);
              }),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('Erro ao carregar ${_tipoSelecionado}s');
            }

            if (!snapshot.hasData) {
              return const LinearProgressIndicator();
            }

            final documentos = snapshot.data!.docs;

            return DropdownButtonFormField<String>(
              initialValue: _codigoSelecionado,
              decoration: InputDecoration(
                labelText: 'Selecione o $_tipoSelecionado',
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              items: documentos.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final codigo = data['codigo'] ?? '';
                final nome = data['nome'] ?? '';
                final display = '$codigo - $nome';

                return DropdownMenuItem<String>(
                  value: codigo,
                  child: Text(display),
                  onTap: () {
                    setState(() {
                      _destinoCompleto = display;
                    });
                  },
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _codigoSelecionado = value;
                  _limparCache();
                  _salvarSelecao();
                });
              },
            );
          },
        ),
      ),
    );
  }

  // Buscar dados do ciclo com cache
  Future<Map<String, dynamic>?> _obterDadosCiclo() async {
    if (_codigoSelecionado == null) return null;

    // Usar cache se disponível
    if (_cicloCache != null) return _cicloCache;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('ciclos')
          .where('codigo', isEqualTo: _codigoSelecionado)
          .where('encerrado', isEqualTo: false)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        _cicloCache = snapshot.docs.first.data();
        _cicloCache!['id'] = snapshot.docs.first.id;
        return _cicloCache;
      }
    } catch (e) {
      debugPrint('Erro ao buscar ciclo: $e');
    }

    return null;
  }

  Widget _buildCardResumoCiclo() {
    if (_codigoSelecionado == null) return const SizedBox();

    final dataConsulta = _dataFiltro ?? DateTime.now();

    return FutureBuilder<Map<String, dynamic>?>(
      future: _obterDadosCiclo(),
      builder: (context, snapshotCiclo) {
        if (snapshotCiclo.connectionState == ConnectionState.waiting) {
          return const Card(
            margin: EdgeInsets.all(8.0),
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: LinearProgressIndicator()),
            ),
          );
        }

        if (snapshotCiclo.hasError) {
          return Card(
            margin: const EdgeInsets.all(8.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red[700]),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Erro ao carregar dados do ciclo',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final cicloData = snapshotCiclo.data;

        if (cicloData == null) {
          return Card(
            margin: const EdgeInsets.all(8.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Nenhum ciclo ativo encontrado para $_destinoCompleto',
                      style: TextStyle(color: Colors.orange[700]),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Obter data de povoamento
        DateTime? dataPovoamento;
        if (cicloData['dataPovoamento'] != null) {
          dataPovoamento = (cicloData['dataPovoamento'] as Timestamp).toDate();
        } else if (cicloData['dataInicio'] != null) {
          dataPovoamento = (cicloData['dataInicio'] as Timestamp).toDate();
        }

        if (dataPovoamento == null) {
          return Card(
            margin: const EdgeInsets.all(8.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_outlined, color: Colors.red[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Erro: Ciclo sem data de povoamento definida',
                      style: TextStyle(color: Colors.red[700]),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final diasCultivo = dataConsulta.difference(dataPovoamento).inDays + 1;
        final inicioDia = DateTime(
          dataConsulta.year,
          dataConsulta.month,
          dataConsulta.day,
        );
        final fimDia = inicioDia.add(const Duration(days: 1));

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Resumo do Ciclo',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_dataFiltro != null)
                          Text(
                            '${_dataFiltro!.day}/${_dataFiltro!.month}/${_dataFiltro!.year}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                    Chip(
                      backgroundColor: diasCultivo > 0
                          ? Colors.teal.shade100
                          : Colors.grey.shade300,
                      label: Text(
                        diasCultivo > 0 ? 'Dia $diasCultivo' : 'Pré-cultivo',
                        style: TextStyle(
                          color: diasCultivo > 0
                              ? Colors.teal.shade900
                              : Colors.grey.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                // Widget de métricas otimizado
                _buildMetricasOtimizadas(dataPovoamento, inicioDia, fimDia),
              ],
            ),
          ),
        );
      },
    );
  }

  // Métricas com consultas otimizadas
  Widget _buildMetricasOtimizadas(
    DateTime dataPovoamento,
    DateTime inicioDia,
    DateTime fimDia,
  ) {
    // Query otimizada para o dia
    final queryDia = FirebaseFirestore.instance
        .collection('racao')
        .where('tipoDestino', isEqualTo: _tipoSelecionado)
        .where('codigoDestino', isEqualTo: _codigoSelecionado)
        .where(
          'dataRegistro',
          isGreaterThanOrEqualTo: Timestamp.fromDate(inicioDia),
        )
        .where('dataRegistro', isLessThan: Timestamp.fromDate(fimDia));

    // Query otimizada para acumulado
    final queryAcumulado = FirebaseFirestore.instance
        .collection('racao')
        .where('tipoDestino', isEqualTo: _tipoSelecionado)
        .where('codigoDestino', isEqualTo: _codigoSelecionado)
        .where(
          'dataRegistro',
          isGreaterThanOrEqualTo: Timestamp.fromDate(dataPovoamento),
        )
        .where('dataRegistro', isLessThan: Timestamp.fromDate(fimDia));

    return FutureBuilder<List<QuerySnapshot>>(
      future: Future.wait([queryDia.get(), queryAcumulado.get()]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }

        int ofertasDia = 0;
        double totalDia = 0;
        double totalAcumulado = 0;

        if (snapshot.hasData && snapshot.data != null) {
          // Processar dados do dia
          final docsDia = snapshot.data![0].docs;
          ofertasDia = docsDia.length;
          for (var doc in docsDia) {
            totalDia +=
                (doc.data() as Map<String, dynamic>)['quantidade'] ?? 0.0;
          }

          // Processar dados acumulados
          final docsAcumulado = snapshot.data![1].docs;
          for (var doc in docsAcumulado) {
            totalAcumulado +=
                (doc.data() as Map<String, dynamic>)['quantidade'] ?? 0.0;
          }
        } else if (snapshot.hasError) {
          // Tentar fallback para campos antigos
          return _buildMetricasFallback(dataPovoamento, inicioDia, fimDia);
        }

        return _buildResumoMetricas(ofertasDia, totalDia, totalAcumulado);
      },
    );
  }

  // Fallback para campos antigos
  Widget _buildMetricasFallback(
    DateTime dataPovoamento,
    DateTime inicioDia,
    DateTime fimDia,
  ) {
    final queryFallback = FirebaseFirestore.instance
        .collection('racao')
        .where('viveiro', isEqualTo: _destinoCompleto)
        .where(
          'dataRegistro',
          isGreaterThanOrEqualTo: Timestamp.fromDate(dataPovoamento),
        )
        .where('dataRegistro', isLessThan: Timestamp.fromDate(fimDia));

    return FutureBuilder<QuerySnapshot>(
      future: queryFallback.get(),
      builder: (context, snapshot) {
        int ofertasDia = 0;
        double totalDia = 0;
        double totalAcumulado = 0;

        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final docDate = (data['dataRegistro'] as Timestamp).toDate();
            final quantidade = (data['quantidade'] ?? 0).toDouble();

            totalAcumulado += quantidade;

            if (docDate.isAfter(
                  inicioDia.subtract(const Duration(seconds: 1)),
                ) &&
                docDate.isBefore(fimDia)) {
              ofertasDia++;
              totalDia += quantidade;
            }
          }
        }

        return _buildResumoMetricas(ofertasDia, totalDia, totalAcumulado);
      },
    );
  }

  Widget _buildResumoMetricas(
    int ofertasDia,
    double totalDia,
    double totalAcumulado,
  ) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ofertas no dia',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                ofertasDia.toString(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total do dia',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                '${totalDia.toStringAsFixed(2)} kg',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Acumulado',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                '${totalAcumulado.toStringAsFixed(2)} kg',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_carregandoPreferencias) {
      return const AppScaffold(
        title: 'Registros de Ração',
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return AppScaffold(
      title: 'Registros de Ração',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TelaArracoador(
                tipoDestinoInicial: _tipoSelecionado,
                codigoDestinoInicial: _codigoSelecionado,
                destinoNomeInicial: _destinoCompleto,
              ),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Novo Registro'),
      ),
      body: DegradeFundo(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabeçalho centralizado seguindo o padrão visual
              const Padding(
                padding: EdgeInsets.only(
                  top: 28,
                  left: 24,
                  right: 24,
                  bottom: 12,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: Color(0xFF049F56),
                      child: Icon(
                        Icons.restaurant,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Registros de Ração',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Visualize e gerencie as ofertas de ração com rastreabilidade de lotes.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.teal,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // Instruções e dicas (alinhado ao padrão da tela de análises)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, color: Colors.blue),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Dicas para consultar e registrar ração',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            SizedBox(height: 6),
                            Text(
                              '• "Ver todos" lista registros gerais; use data/destino para reduzir a carga e ver métricas do dia/acumulado.',
                            ),
                            Text(
                              '• Selecione Tipo (Viveiro/Berçário) e Código para ver o Resumo do Ciclo e os registros daquele destino.',
                            ),
                            Text(
                              '• Clique em “Novo Registro” para lançar ração; aditivos são identificados nos chips quando aplicados.',
                            ),
                            Text(
                              '• Ao editar/excluir, o estoque (FEFO) é estornado automaticamente para ração e aditivos vinculados.',
                            ),
                            Text(
                              '• O selo LEGADO indica registros antigos sem vínculo de lote; edições passam a rastrear lotes normalmente.',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Card de filtros principais (ver todos + data)
              Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Ver todos os registros'),
                        subtitle: const Text(
                          'Ignora a seleção de destino e lista tudo',
                        ),
                        value: _verTodos,
                        onChanged: (v) {
                          setState(() => _verTodos = v);
                          _salvarSelecao();
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text(
                            'Filtrar por data:',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: _selecionarData,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      _dataFiltro != null
                                          ? '${_dataFiltro!.day}/${_dataFiltro!.month}/${_dataFiltro!.year}'
                                          : 'Todas as datas',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (_dataFiltro != null)
                            IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: _limparFiltros,
                              tooltip: 'Limpar filtro de data',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Seletor de tipo (Viveiro ou Berçário) e código apenas quando não estiver vendo todos
              if (!_verTodos) _buildSeletorTipo(),
              if (!_verTodos) _buildSeletorCodigo(),

              // Card de Resumo do Ciclo (apenas quando filtrando por destino)
              if (!_verTodos && _codigoSelecionado != null)
                _buildCardResumoCiclo(),

              // Lista com paginação
              if (_verTodos || _codigoSelecionado != null)
                StreamBuilder<QuerySnapshot>(
                  stream: _construirQueryOtimizada(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red[300],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Erro ao carregar registros',
                              style: TextStyle(color: Colors.red),
                            ),
                            TextButton(
                              onPressed: () => setState(() {}),
                              child: const Text('Tentar novamente'),
                            ),
                          ],
                        ),
                      );
                    }

                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final registros = snapshot.data!.docs;

                    // Pré-carrega metadados de lotes usados para enriquecer os chips
                    _precarregarLotesParaRegistros(registros);

                    if (registros.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.inbox,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _dataFiltro != null
                                  ? 'Nenhum registro em ${_dataFiltro!.day}/${_dataFiltro!.month}/${_dataFiltro!.year}'
                                  : (_verTodos
                                        ? 'Nenhum registro encontrado'
                                        : 'Nenhum registro encontrado para $_destinoCompleto'),
                              style: const TextStyle(color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(8.0),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: registros.length,
                      itemBuilder: (context, index) {
                        final doc = registros[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final timestamp = data['dataRegistro'] as Timestamp?;
                        final dataRegistro =
                            timestamp?.toDate() ?? DateTime.now();

                        final destino = _obterNomeDestino(data);
                        final temProbiotico = _obterStatusProbiotico(data);
                        final temSuplemento = _obterStatusSuplemento(data);

                        // Novos campos opcionais
                        final int? trato = data['trato'] is num
                            ? (data['trato'] as num).toInt()
                            : null;
                        final int? diaCiclo = data['diaCiclo'] is num
                            ? (data['diaCiclo'] as num).toInt()
                            : null;
                        final double? totalAcumulado =
                            data['totalAcumulado'] is num
                            ? (data['totalAcumulado'] as num).toDouble()
                            : null;

                        // Rastreabilidade do estoque (compatível com registros antigos)
                        final String? insumoNome =
                            (data['insumoNome'] as String?) ??
                            (data['insumoId'] as String?);
                        final List<dynamic> lotesUsados =
                            (data['lotesUsados'] is List)
                            ? (data['lotesUsados'] as List)
                            : const [];
                        final String? loteSelecionado =
                            (data['loteSelecionado'] as String?) != null &&
                                (data['loteSelecionado'] as String)
                                    .trim()
                                    .isNotEmpty
                            ? (data['loteSelecionado'] as String)
                            : null;
                        final List<dynamic> probioticoUsados =
                            (data['probioticoUsados'] is List)
                            ? (data['probioticoUsados'] as List)
                            : const [];
                        final List<dynamic> suplementoUsados =
                            (data['suplementoUsados'] is List)
                            ? (data['suplementoUsados'] as List)
                            : const [];

                        // Indicador visual para registros legados (sem vínculo de insumo/lote)
                        final bool ehLegado =
                            ((data['insumoId'] == null ||
                                (data['insumoId'] is String &&
                                    (data['insumoId'] as String)
                                        .trim()
                                        .isEmpty)) &&
                            lotesUsados.isEmpty &&
                            (loteSelecionado == null ||
                                loteSelecionado.trim().isEmpty));

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        destino,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    if (_podeExcluir)
                                      IconButton(
                                        tooltip: 'Excluir',
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.redAccent,
                                        ),
                                        onPressed: () =>
                                            _excluirRegistro(doc.id, data),
                                      ),
                                    Chip(
                                      label: Text(
                                        '${(data['quantidade'] ?? 0).toStringAsFixed(2)} kg',
                                      ),
                                      backgroundColor: Colors.teal.shade50,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    if (ehLegado) ...[
                                      const SizedBox(width: 8),
                                      Tooltip(
                                        message:
                                            'Registro legado: sem vínculo de insumo/lote. Recomenda-se backfill.',
                                        child: Chip(
                                          avatar: const Icon(
                                            Icons.warning_amber_rounded,
                                            size: 16,
                                            color: Colors.amber,
                                          ),
                                          label: const Text(
                                            'LEGADO',
                                            style: TextStyle(fontSize: 11),
                                          ),
                                          backgroundColor: Colors.amber.shade50,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    if (trato != null) ...[
                                      const Icon(
                                        Icons.fastfood,
                                        size: 14,
                                        color: Colors.indigo,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$tratoº Trato',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.indigo,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                    ] else if (data['horario'] != null) ...[
                                      Icon(
                                        Icons.access_time,
                                        size: 14,
                                        color: Colors.grey[700],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        data['horario'],
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                    ],
                                    Icon(
                                      Icons.event,
                                      size: 14,
                                      color: Colors.grey[700],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${dataRegistro.day}/${dataRegistro.month}/${dataRegistro.year}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                                if (diaCiclo != null ||
                                    totalAcumulado != null) ...[
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      if (diaCiclo != null)
                                        Chip(
                                          label: Text('Dia $diaCiclo'),
                                          backgroundColor: Colors.teal.shade50,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      if (totalAcumulado != null)
                                        Chip(
                                          label: Text(
                                            'Total até aqui: ${totalAcumulado.toStringAsFixed(2)} kg',
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          ),
                                          backgroundColor:
                                              Colors.blueGrey.shade50,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 4),
                                if ((data['registradoPor'] as String?) !=
                                        null &&
                                    (data['registradoPor'] as String)
                                        .trim()
                                        .isNotEmpty)
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.person,
                                        size: 14,
                                        color: Colors.grey[700],
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'Responsável: ${data['registradoPor']}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[800],
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                if ((data['observacoes'] as String?) != null &&
                                    (data['observacoes'] as String)
                                        .trim()
                                        .isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.notes,
                                        size: 14,
                                        color: Colors.grey[700],
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          (data['observacoes'] as String)
                                              .trim(),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[800],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                if (insumoNome != null ||
                                    lotesUsados.isNotEmpty ||
                                    loteSelecionado != null) ...[
                                  const SizedBox(height: 4),
                                  if (insumoNome != null)
                                    Text(
                                      'Insumo: $insumoNome',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  if (loteSelecionado != null)
                                    Text(
                                      'Lote (preferido): $loteSelecionado',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  if (lotesUsados.isNotEmpty)
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        const Text(
                                          'Lotes usados:',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        ...lotesUsados.take(4).map((lu) {
                                          final m = (lu is Map)
                                              ? lu
                                              : <String, dynamic>{};
                                          final codigo =
                                              (m['lote'] ??
                                                      m['codigo'] ??
                                                      m['loteCodigo'] ??
                                                      '')
                                                  .toString();
                                          final qtd =
                                              (m['quantidade'] ?? m['qtd'] ?? 0)
                                                  .toString();
                                          final loteId = (m['loteId'] ?? '')
                                              .toString();
                                          String fornecedor = '';
                                          String validadeTxt = '';
                                          if (loteId.isNotEmpty &&
                                              _loteCache.containsKey(loteId)) {
                                            final lot = _loteCache[loteId]!;
                                            final forn =
                                                (lot['fornecedor'] ?? '')
                                                    .toString();
                                            if (forn.isNotEmpty)
                                              fornecedor = forn;
                                          }
                                          try {
                                            final valIso = (m['validade'] ?? '')
                                                .toString();
                                            if (valIso.isNotEmpty) {
                                              final d = DateTime.tryParse(
                                                valIso,
                                              );
                                              if (d != null) {
                                                validadeTxt =
                                                    ' • v: ${d.day}/${d.month}/${d.year}';
                                              }
                                            }
                                          } catch (_) {}
                                          final base = codigo.isNotEmpty
                                              ? '$codigo ($qtd kg)'
                                              : '$qtd kg';
                                          final extra = fornecedor.isNotEmpty
                                              ? ' • forn: $fornecedor'
                                              : '';
                                          final label =
                                              '$base$extra$validadeTxt';
                                          return Chip(
                                            label: Text(
                                              label,
                                              style: const TextStyle(
                                                fontSize: 11,
                                              ),
                                            ),
                                            visualDensity:
                                                VisualDensity.compact,
                                          );
                                        }),
                                        if (lotesUsados.length > 4)
                                          Chip(
                                            label: Text(
                                              '+${lotesUsados.length - 4}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                              ),
                                            ),
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                      ],
                                    ),
                                ],
                                if (temProbiotico || temSuplemento)
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      if (temProbiotico)
                                        Chip(
                                          label: Text(
                                            _nomeInsumoProbiotico != null &&
                                                    _nomeInsumoProbiotico!
                                                        .isNotEmpty
                                                ? 'Probiótico: ${_nomeInsumoProbiotico!}'
                                                : 'Probiótico',
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          ),
                                          backgroundColor: Colors.green,
                                          padding: EdgeInsets.zero,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      if (temSuplemento)
                                        Chip(
                                          label: Text(
                                            _nomeInsumoSuplemento != null &&
                                                    _nomeInsumoSuplemento!
                                                        .isNotEmpty
                                                ? 'Suplemento: ${_nomeInsumoSuplemento!}'
                                                : 'Suplemento',
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          ),
                                          backgroundColor: Colors.orange,
                                          padding: EdgeInsets.zero,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                    ],
                                  ),
                                if (probioticoUsados.isNotEmpty ||
                                    suplementoUsados.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  if (probioticoUsados.isNotEmpty)
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        const Text(
                                          'Probiótico (lotes):',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        ...probioticoUsados.take(4).map((lu) {
                                          final m = (lu is Map)
                                              ? lu
                                              : <String, dynamic>{};
                                          final codigo =
                                              (m['lote'] ??
                                                      m['codigo'] ??
                                                      m['loteCodigo'] ??
                                                      '')
                                                  .toString();
                                          final qtd =
                                              (m['quantidade'] ?? m['qtd'] ?? 0)
                                                  .toString();
                                          final loteId = (m['loteId'] ?? '')
                                              .toString();
                                          String fornecedor = '';
                                          String validadeTxt = '';
                                          if (loteId.isNotEmpty &&
                                              _loteCache.containsKey(loteId)) {
                                            final lot = _loteCache[loteId]!;
                                            final forn =
                                                (lot['fornecedor'] ?? '')
                                                    .toString();
                                            if (forn.isNotEmpty)
                                              fornecedor = forn;
                                          }
                                          try {
                                            final valIso = (m['validade'] ?? '')
                                                .toString();
                                            if (valIso.isNotEmpty) {
                                              final d = DateTime.tryParse(
                                                valIso,
                                              );
                                              if (d != null) {
                                                validadeTxt =
                                                    ' • v: ${d.day}/${d.month}/${d.year}';
                                              }
                                            }
                                          } catch (_) {}
                                          final base = codigo.isNotEmpty
                                              ? '$codigo ($qtd un)'
                                              : '$qtd un';
                                          final extra = fornecedor.isNotEmpty
                                              ? ' • forn: $fornecedor'
                                              : '';
                                          final label =
                                              '$base$extra$validadeTxt';
                                          return Chip(
                                            label: Text(
                                              label,
                                              style: const TextStyle(
                                                fontSize: 11,
                                              ),
                                            ),
                                            visualDensity:
                                                VisualDensity.compact,
                                          );
                                        }),
                                        if (probioticoUsados.length > 4)
                                          Chip(
                                            label: Text(
                                              '+${probioticoUsados.length - 4}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                              ),
                                            ),
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                      ],
                                    ),
                                  if (suplementoUsados.isNotEmpty)
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        const Text(
                                          'Suplemento (lotes):',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        ...suplementoUsados.take(4).map((lu) {
                                          final m = (lu is Map)
                                              ? lu
                                              : <String, dynamic>{};
                                          final codigo =
                                              (m['lote'] ??
                                                      m['codigo'] ??
                                                      m['loteCodigo'] ??
                                                      '')
                                                  .toString();
                                          final qtd =
                                              (m['quantidade'] ?? m['qtd'] ?? 0)
                                                  .toString();
                                          final loteId = (m['loteId'] ?? '')
                                              .toString();
                                          String fornecedor = '';
                                          String validadeTxt = '';
                                          if (loteId.isNotEmpty &&
                                              _loteCache.containsKey(loteId)) {
                                            final lot = _loteCache[loteId]!;
                                            final forn =
                                                (lot['fornecedor'] ?? '')
                                                    .toString();
                                            if (forn.isNotEmpty)
                                              fornecedor = forn;
                                          }
                                          try {
                                            final valIso = (m['validade'] ?? '')
                                                .toString();
                                            if (valIso.isNotEmpty) {
                                              final d = DateTime.tryParse(
                                                valIso,
                                              );
                                              if (d != null) {
                                                validadeTxt =
                                                    ' • v: ${d.day}/${d.month}/${d.year}';
                                              }
                                            }
                                          } catch (_) {}
                                          final base = codigo.isNotEmpty
                                              ? '$codigo ($qtd un)'
                                              : '$qtd un';
                                          final extra = fornecedor.isNotEmpty
                                              ? ' • forn: $fornecedor'
                                              : '';
                                          final label =
                                              '$base$extra$validadeTxt';
                                          return Chip(
                                            label: Text(
                                              label,
                                              style: const TextStyle(
                                                fontSize: 11,
                                              ),
                                            ),
                                            visualDensity:
                                                VisualDensity.compact,
                                          );
                                        }),
                                        if (suplementoUsados.length > 4)
                                          Chip(
                                            label: Text(
                                              '+${suplementoUsados.length - 4}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                              ),
                                            ),
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                      ],
                                    ),
                                ],
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () =>
                                        _abrirDetalhes(data, doc.id),
                                    icon: const Icon(
                                      Icons.open_in_new,
                                      size: 16,
                                    ),
                                    label: const Text('Detalhes'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),

              // Mensagem quando não há seleção (somente se não estiver em "ver todos")
              if (!_verTodos && _codigoSelecionado == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48.0),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.restaurant,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Selecione um ${_tipoSelecionado ?? "viveiro ou berçário"} para visualizar os registros',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 88), // respiro para o FAB na web/mobile
            ],
          ),
        ),
      ),
    );
  }

  // Query otimizada com índices compostos
  Stream<QuerySnapshot> _construirQueryOtimizada() {
    Query query = FirebaseFirestore.instance.collection('racao');

    // Quando NÃO estamos vendo todos, aplicar filtro por destino
    if (!_verTodos && _tipoSelecionado != null && _codigoSelecionado != null) {
      query = query
          .where('tipoDestino', isEqualTo: _tipoSelecionado)
          .where('codigoDestino', isEqualTo: _codigoSelecionado);
    }

    // Adicionar filtro de data se selecionado
    if (_dataFiltro != null) {
      final inicioDia = DateTime(
        _dataFiltro!.year,
        _dataFiltro!.month,
        _dataFiltro!.day,
      );
      final fimDia = inicioDia.add(const Duration(days: 1));

      query = query
          .where(
            'dataRegistro',
            isGreaterThanOrEqualTo: Timestamp.fromDate(inicioDia),
          )
          .where('dataRegistro', isLessThan: Timestamp.fromDate(fimDia));
    }

    // Limitar resultados para performance
    return query
        .orderBy('dataRegistro', descending: true)
        .limit(50)
        .snapshots()
        .handleError((error) {
          // Fallback para campos antigos em caso de erro
          debugPrint('Erro na query otimizada, usando fallback: $error');

          Query fallbackQuery = FirebaseFirestore.instance.collection('racao');

          if (!_verTodos && _destinoCompleto != null) {
            fallbackQuery = fallbackQuery.where(
              'viveiro',
              isEqualTo: _destinoCompleto,
            );
          }

          if (_dataFiltro != null) {
            final inicioDia = DateTime(
              _dataFiltro!.year,
              _dataFiltro!.month,
              _dataFiltro!.day,
            );
            final fimDia = inicioDia.add(const Duration(days: 1));

            fallbackQuery = fallbackQuery
                .where(
                  'dataRegistro',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(inicioDia),
                )
                .where('dataRegistro', isLessThan: Timestamp.fromDate(fimDia));
          }

          return fallbackQuery
              .orderBy('dataRegistro', descending: true)
              .limit(50)
              .snapshots();
        });
  }
}
