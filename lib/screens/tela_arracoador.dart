import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/app_scaffold.dart';
import '../helpers/auth_helper.dart';
import '../helpers/audit_helper.dart';
import '../helpers/estoque_helper.dart';
import '../widgets/degrade_fundo.dart';
import 'tela_entrada_insumo.dart';

class TelaArracoador extends StatefulWidget {
  // display completo (ex: COD - Nome)

  const TelaArracoador({
    super.key,
    this.tipoDestinoInicial,
    this.codigoDestinoInicial,
    this.destinoNomeInicial,
  });
  final String? tipoDestinoInicial;
  final String? codigoDestinoInicial;
  final String? destinoNomeInicial;

  @override
  State<TelaArracoador> createState() => _TelaArracoadorState();
}

class _TelaArracoadorState extends State<TelaArracoador> {
  final _formKey = GlobalKey<FormState>();
  final _racaoController = TextEditingController();
  final _observacoesController = TextEditingController();
  final _quantidadeBaldeMlGramasController = TextEditingController();

  String? _viveiroSelecionado; // display "codigo - nome"
  String? _tipoDestino = 'viveiro';
  String? _codigoDestino;
  String? _destinoNome; // mesmo conteúdo de display para compatibilidade
  // Trato do dia (1, 2 ou 3)
  int? _tratoSelecionado; // 1, 2, 3
  bool _probioticoAplicado = false;
  bool _suplementoAplicado = false;
  bool _isLoading = false;
  DateTime? _dataRegistro; // Data do registro (padrão: hoje)
  // Preview do dia do ciclo para a data selecionada
  int? _diaCicloPreview;
  DateTime? _inicioCicloPreview;
  bool _temCicloAtivoPreview = false;
  // Preview de totais (kg) para a data selecionada
  double? _totalDiaPreviewKg;
  double? _totalAcumuladoPreviewKg;
  // Preview: registros por trato (1,2,3) no dia selecionado
  Map<int, List<Map<String, dynamic>>> _tratosDiaPreview = {};
  // Lote de ração (FEFO)
  String? _insumoRacaoId;
  String? _insumoRacaoNome;
  String? _loteSelecionadoId;
  String? _loteSelecionadoCodigo;
  DateTime? _loteValidade;
  double? _loteQuantidadeAtual;
  String? _loteUnidade; // Armazena a unidade do lote selecionado
  bool _carregandoLote = false;
  bool _loteSelecionadoVencido = false;
  int _qtdLotesVencidos = 0;
  int _qtdLotesProximos = 0;
  bool _carregandoAlertas = false;
  bool _apenasComSaldoSelecaoLote = true;
  String _unidadeBaldeSelecionada = 'mL'; // Para quando a unidade for balde
  // Preferência por ponto de entrega que atende o destino
  String? _pontoPreferidoId;
  String? _pontoPreferidoNome;
  bool _usarPreferenciaPonto = true;

  // Normaliza strings removendo acentos e case para comparações simples
  String _norm(String input) {
    var s = (input).toLowerCase().trim();
    s = s.replaceAll(RegExp(r'[áàâãä]'), 'a');
    s = s.replaceAll(RegExp(r'[éèêë]'), 'e');
    s = s.replaceAll(RegExp(r'[íìïî]'), 'i');
    s = s.replaceAll(RegExp(r'[óòôõö]'), 'o');
    s = s.replaceAll(RegExp(r'[úùûü]'), 'u');
    s = s.replaceAll('ç', 'c');
    return s;
  }

  // Verifica se duas datas são do mesmo dia
  bool _isMesmaData(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  // Atualiza o preview do dia do ciclo ao mudar data ou destino
  Future<void> _atualizarDiaCicloPreview() async {
    try {
      if (_codigoDestino == null) {
        if (mounted) {
          setState(() {
            _diaCicloPreview = null;
            _inicioCicloPreview = null;
            _temCicloAtivoPreview = false;
            _totalDiaPreviewKg = null;
            _totalAcumuladoPreviewKg = null;
          });
        }
        return;
      }

      // Base da data selecionada (ou hoje) para todos os cálculos
      final base = _dataRegistro ?? DateTime.now();
      final baseDia = DateTime(base.year, base.month, base.day);
      final proximoDia = baseDia.add(const Duration(days: 1));

      // Calcular total do dia e preparar resumo por trato sempre, independentemente de haver ciclo ativo
      double somaDia = 0.0;
      final Map<int, List<Map<String, dynamic>>> tratos = {
        1: <Map<String, dynamic>>[],
        2: <Map<String, dynamic>>[],
        3: <Map<String, dynamic>>[],
      };
      try {
        final qsDia = await FirebaseFirestore.instance
            .collection('racao')
            .where('codigoDestino', isEqualTo: _codigoDestino)
            .where('tipoDestino', isEqualTo: (_tipoDestino ?? 'viveiro'))
            .get();
        for (final d in qsDia.docs) {
          final m = d.data();
          final ts = m['dataRegistro'] as Timestamp?;
          final dt = ts?.toDate();
          if (dt == null) continue;
          if (!dt.isBefore(baseDia) && dt.isBefore(proximoDia)) {
            final q = m['quantidade'];
            final qd = q is num ? q.toDouble() : double.tryParse('$q') ?? 0.0;
            somaDia += qd;

            final t = (m['trato'] is int) ? (m['trato'] as int) : null;
            if (t != null && tratos.containsKey(t)) {
              tratos[t]!.add({'hora': dt, 'quantidade': qd, 'id': d.id});
            }
          }
        }
      } catch (e) {
        debugPrint('Falha ao calcular total do dia (preview): $e');
      }

      final cicloSnap = await FirebaseFirestore.instance
          .collection('ciclos')
          .where('codigo', isEqualTo: _codigoDestino)
          .where('encerrado', isEqualTo: false)
          .limit(1)
          .get();

      if (cicloSnap.docs.isEmpty) {
        if (mounted) {
          setState(() {
            _diaCicloPreview = null;
            _inicioCicloPreview = null;
            _temCicloAtivoPreview = false;
            _totalDiaPreviewKg = somaDia;
            _totalAcumuladoPreviewKg = null;
            _tratosDiaPreview = tratos;
          });
        }
        return;
      }

      final ciclo = cicloSnap.docs.first.data();
      DateTime? inicioCiclo;
      if (ciclo['dataPovoamento'] is Timestamp) {
        inicioCiclo = (ciclo['dataPovoamento'] as Timestamp).toDate();
      } else if (ciclo['dataInicio'] is Timestamp) {
        inicioCiclo = (ciclo['dataInicio'] as Timestamp).toDate();
      }

      if (inicioCiclo == null) {
        if (mounted) {
          setState(() {
            _diaCicloPreview = null;
            _inicioCicloPreview = null;
            _temCicloAtivoPreview = false;
            _totalDiaPreviewKg = somaDia;
            _totalAcumuladoPreviewKg = null;
            _tratosDiaPreview = tratos;
          });
        }
        return;
      }

      final inicioDia = DateTime(
        inicioCiclo.year,
        inicioCiclo.month,
        inicioCiclo.day,
      );
      int dia = baseDia.difference(inicioDia).inDays + 1;
      if (dia < 1) {
        // Antes do início do ciclo
        dia = 0;
      }

      // Calcular totais do dia e acumulado (com base em registros existentes)
      // somaDia já calculado acima
      double somaAcumulado = 0.0;
      try {
        final qs = await FirebaseFirestore.instance
            .collection('racao')
            .where('codigoDestino', isEqualTo: _codigoDestino)
            .where('tipoDestino', isEqualTo: (_tipoDestino ?? 'viveiro'))
            .get();
        for (final d in qs.docs) {
          final m = d.data();
          final ts = m['dataRegistro'] as Timestamp?;
          final dt = ts?.toDate();
          if (dt == null) continue;
          final q = m['quantidade'];
          final qd = q is num ? q.toDouble() : double.tryParse('$q') ?? 0.0;
          // Total acumulado no ciclo até a data selecionada (inclusive)
          if (!dt.isBefore(inicioDia) && dt.isBefore(proximoDia)) {
            somaAcumulado += qd;
          }
        }
      } catch (e) {
        debugPrint('Falha ao calcular totais de preview: $e');
      }

      if (mounted) {
        setState(() {
          _diaCicloPreview = dia;
          _inicioCicloPreview = inicioCiclo;
          _temCicloAtivoPreview = true;
          _totalDiaPreviewKg = somaDia;
          _totalAcumuladoPreviewKg = somaAcumulado;
          _tratosDiaPreview = tratos;
        });
      }
    } catch (e) {
      debugPrint('Falha ao atualizar preview de dia do ciclo: $e');
      if (mounted) {
        setState(() {
          _diaCicloPreview = null;
          _inicioCicloPreview = null;
          _temCicloAtivoPreview = false;
          _totalDiaPreviewKg = null;
          _totalAcumuladoPreviewKg = null;
          _tratosDiaPreview = {};
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Pré-preencher se vier da listagem com seleção já feita
    if (widget.codigoDestinoInicial != null &&
        widget.destinoNomeInicial != null) {
      _tipoDestino = widget.tipoDestinoInicial ?? 'viveiro';
      _codigoDestino = widget.codigoDestinoInicial;
      _destinoNome = widget.destinoNomeInicial;
      _viveiroSelecionado =
          widget.destinoNomeInicial; // Para validar o dropdown
    }
    _carregarLoteFEFO();
    _carregarAlertasLotes();
    if (_codigoDestino != null) {
      _resolverPontoPreferido();
      // Calcular preview inicial se já houver destino
      _atualizarDiaCicloPreview();
    }
  }

  @override
  void dispose() {
    _racaoController.dispose();
    _observacoesController.dispose();
    _quantidadeBaldeMlGramasController.dispose();
    super.dispose();
  }

  Future<void> _resolverPontoPreferido() async {
    try {
      if (_codigoDestino == null) {
        if (mounted) {
          setState(() {
            _pontoPreferidoId = null;
            _pontoPreferidoNome = null;
          });
        }
        return;
      }
      final base = FirebaseFirestore.instance
          .collection('pontos_entrega')
          .where('ativo', isEqualTo: true);
      final tipo = (_tipoDestino ?? 'viveiro');
      Query snapQuery;
      try {
        // Tenta consulta composta com arrayContains (pode exigir índice)
        if (tipo == 'bercario') {
          snapQuery = base.where(
            'atendeBercarios',
            arrayContains: _codigoDestino,
          );
        } else {
          snapQuery = base.where(
            'atendeViveiros',
            arrayContains: _codigoDestino,
          );
        }
        final snap = await snapQuery.limit(1).get();
        if (snap.docs.isNotEmpty) {
          final d = snap.docs.first;
          final data = d.data() as Map<String, dynamic>?;
          if (mounted) {
            setState(() {
              _pontoPreferidoId = d.id;
              _pontoPreferidoNome = (data?['nome'] ?? '').toString();
            });
          }
          return;
        }
      } catch (e) {
        debugPrint(
          'Índice composto ausente para pontos_entrega; usando fallback: $e',
        );
      }

      // Fallback: busca somente por ativos e filtra em memória
      final snapAll = await base.get();
      MapEntry<String, Map<String, dynamic>>? escolhido;
      for (final d in snapAll.docs) {
        final data = d.data() as Map<String, dynamic>?;
        final List v = (tipo == 'bercario')
            ? (data?['atendeBercarios'] as List?) ?? const []
            : (data?['atendeViveiros'] as List?) ?? const [];
        if (v.contains(_codigoDestino)) {
          escolhido = MapEntry(d.id, data ?? const {});
          break; // pega o primeiro
        }
      }
      if (mounted) {
        setState(() {
          _pontoPreferidoId = escolhido?.key;
          _pontoPreferidoNome = (escolhido?.value['nome'] ?? '').toString();
        });
      }
    } catch (e) {
      debugPrint('Falha ao resolver ponto preferido: $e');
    }
  }

  Future<void> _salvarRegistro() async {
    if (_formKey.currentState!.validate() && _viveiroSelecionado != null) {
      if (_loteSelecionadoId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cadastre ou selecione um lote de ração.'),
          ),
        );
        return;
      }
      if (_loteSelecionadoVencido) {
        final confirmar = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Lote vencido'),
            content: const Text(
              'O lote selecionado está vencido. Confirmar uso mesmo assim?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Usar assim mesmo'),
              ),
            ],
          ),
        );
        if (confirmar != true) return;
      }
      setState(() => _isLoading = true);

      DocumentReference<Map<String, dynamic>>? docRef;
      try {
        final usuario = AuthHelper.obterUsuarioLogado();
        // Usar data selecionada ou data/hora atual
        final dataHora = _dataRegistro ?? DateTime.now();

        // Garantir que os campos de destino estejam preenchidos
        if (_codigoDestino == null || _destinoNome == null) {
          // Extrair código do viveiro selecionado se necessário
          final partes = _viveiroSelecionado!.split(' - ');
          _codigoDestino = partes.isNotEmpty ? partes[0] : _viveiroSelecionado;
          _destinoNome = _viveiroSelecionado;
        }

        // Calcular dia do ciclo e acumulado até aqui
        int? diaCiclo;
        double? totalAcumulado;
        try {
          // Buscar ciclo ativo do destino
          if (_codigoDestino != null) {
            final cicloSnap = await FirebaseFirestore.instance
                .collection('ciclos')
                .where('codigo', isEqualTo: _codigoDestino)
                .where('encerrado', isEqualTo: false)
                .limit(1)
                .get();
            if (cicloSnap.docs.isNotEmpty) {
              final ciclo = cicloSnap.docs.first.data();
              DateTime? inicioCiclo;
              if (ciclo['dataPovoamento'] is Timestamp) {
                inicioCiclo = (ciclo['dataPovoamento'] as Timestamp).toDate();
              } else if (ciclo['dataInicio'] is Timestamp) {
                inicioCiclo = (ciclo['dataInicio'] as Timestamp).toDate();
              }
              if (inicioCiclo != null) {
                final inicioDiaAtual = DateTime(
                  dataHora.year,
                  dataHora.month,
                  dataHora.day,
                );
                final inicioCicloDia = DateTime(
                  inicioCiclo.year,
                  inicioCiclo.month,
                  inicioCiclo.day,
                );
                diaCiclo = inicioDiaAtual.difference(inicioCicloDia).inDays + 1;

                // Somar registros anteriores no ciclo para este destino
                double soma = 0.0;
                try {
                  final qs = await FirebaseFirestore.instance
                      .collection('racao')
                      .where('codigoDestino', isEqualTo: _codigoDestino)
                      .where(
                        'tipoDestino',
                        isEqualTo: (_tipoDestino ?? 'viveiro'),
                      )
                      .get();
                  for (final d in qs.docs) {
                    final m = d.data();
                    final ts = m['dataRegistro'] as Timestamp?;
                    final dt = ts?.toDate();
                    if (dt != null &&
                        !dt.isBefore(inicioCicloDia) &&
                        dt.isBefore(dataHora)) {
                      final q = (m['quantidade'] ?? 0);
                      if (q is num) soma += q.toDouble();
                    }
                  }
                } catch (_) {}
                final atual =
                    double.tryParse(
                      _racaoController.text.replaceAll(',', '.'),
                    ) ??
                    0.0;
                totalAcumulado = soma + atual;
              }
            }
          }
        } catch (e) {
          debugPrint('Falha ao calcular dia/total do ciclo: $e');
        }

        // Preparar dados com todos os campos necessários
        final quantidadePrincipal = double.parse(
          _racaoController.text.replaceAll(',', '.'),
        );

        // Se for balde e tiver quantidade específica em mL/g
        String? quantidadeBaldeMlGramas;
        String? unidadeBalde;
        if (_loteUnidade?.toLowerCase() == 'balde' &&
            _quantidadeBaldeMlGramasController.text.trim().isNotEmpty) {
          quantidadeBaldeMlGramas = _quantidadeBaldeMlGramasController.text
              .trim();
          unidadeBalde = _unidadeBaldeSelecionada;
        }

        final dados = {
          // Campos legados (mantidos para compatibilidade)
          'viveiro': _viveiroSelecionado,
          'probióticoAplicado': _probioticoAplicado, // Campo legado com acento
          // Novos campos padronizados
          'tipoDestino': _tipoDestino ?? 'viveiro',
          'codigoDestino': _codigoDestino,
          'destinoNome': _destinoNome,
          'probioticoAplicado': _probioticoAplicado, // Novo campo sem acento
          'suplementoAplicado': _suplementoAplicado,

          // Campos existentes
          'quantidade': quantidadePrincipal,
          'unidade': _loteUnidade ?? 'kg',
          // Campos adicionais para balde
          if (quantidadeBaldeMlGramas != null)
            'quantidadeBaldeMlGramas': quantidadeBaldeMlGramas,
          if (unidadeBalde != null) 'unidadeBalde': unidadeBalde,
          // Campo de trato (1,2,3) opcional
          if (_tratoSelecionado != null) 'trato': _tratoSelecionado,
          // Novos campos automáticos
          if (diaCiclo != null) 'diaCiclo': diaCiclo,
          if (totalAcumulado != null) 'totalAcumulado': totalAcumulado,
          'observacoes': _observacoesController.text.trim(),
          'registradoPor': usuario?.displayName ?? 'Usuário',
          'dataRegistro': Timestamp.fromDate(dataHora),
          'timestamp': FieldValue.serverTimestamp(),
        };

        // Salvar registro de ração (capturar ref para atrelar consumo de estoque)
        docRef = await FirebaseFirestore.instance
            .collection('racao')
            .add(dados);

        // Baixa de estoque via FEFO usando EstoqueHelper
        final quantidadeKg = quantidadePrincipal;
        if (_insumoRacaoId == null && _insumoRacaoNome == null) {
          throw Exception(
            'Insumo de Ração não encontrado. Cadastre um insumo do tipo "Ração" no módulo de Estoque.',
          );
        }
        final usados = await EstoqueHelper.registrarSaidaFefo(
          insumoNomeOuId: _insumoRacaoId ?? _insumoRacaoNome!,
          quantidade: quantidadeKg,
          origem: 'racao',
          referenciaId: docRef.id,
          responsavel: usuario?.displayName,
          preferLoteId: _loteSelecionadoId,
          permitirVencidoPreferido: _loteSelecionadoVencido,
        );

        // Atualiza o registro de ração com vínculo ao insumo e lotes utilizados
        await docRef.update({
          'insumoId': _insumoRacaoId,
          'insumoNome': _insumoRacaoNome,
          'lotesUsados': usados,
          'loteSelecionadoId': _loteSelecionadoId,
          'loteSelecionado': _loteSelecionadoCodigo,
        });

        // Consumo de probiótico por FEFO, registrando lotes
        if (_probioticoAplicado) {
          try {
            final ad = await _localizarInsumoPorTipo('probiotico');
            if (ad != null) {
              final usadosProb = await EstoqueHelper.registrarSaidaFefo(
                insumoNomeOuId: ad['id'] ?? (ad['nome'] as String),
                quantidade: 1, // 1 unidade por aplicação
                origem: 'racao',
                referenciaId: docRef.id,
                responsavel: usuario?.displayName,
              );
              await docRef.update({
                'probioticoInsumoId': ad['id'],
                'probioticoInsumoNome': ad['nome'],
                'probioticoUsados': usadosProb,
              });
            }
          } catch (e) {
            debugPrint('Erro consumindo probiótico via FEFO: $e');
          }
        }

        // Consumo de suplemento por FEFO, registrando lotes
        if (_suplementoAplicado) {
          try {
            final ad = await _localizarInsumoPorTipo('suplemento');
            if (ad != null) {
              final usadosSupl = await EstoqueHelper.registrarSaidaFefo(
                insumoNomeOuId: ad['id'] ?? (ad['nome'] as String),
                quantidade: 1, // 1 unidade por aplicação
                origem: 'racao',
                referenciaId: docRef.id,
                responsavel: usuario?.displayName,
              );
              await docRef.update({
                'suplementoInsumoId': ad['id'],
                'suplementoInsumoNome': ad['nome'],
                'suplementoUsados': usadosSupl,
              });
            }
          } catch (e) {
            debugPrint('Erro consumindo suplemento via FEFO: $e');
          }
        }

        // Registrar auditoria
        await AuditHelper.registrarAcao(
          acao: 'REGISTRAR_RACAO',
          modulo: 'ARRACOAMENTO',
          detalhes: {
            'tipoDestino': _tipoDestino,
            'codigoDestino': _codigoDestino,
            'destino': _destinoNome,
            'quantidade': _racaoController.text,
            'probiotico': _probioticoAplicado,
            'suplemento': _suplementoAplicado,
            'loteId': _loteSelecionadoId,
            'loteCodigo': _loteSelecionadoCodigo,
          },
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Registro de ração salvo com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        // Limpar campos para próximo registro
        _racaoController.clear();
        _observacoesController.clear();
        _quantidadeBaldeMlGramasController.clear();
        _dataRegistro = null;
        _tratoSelecionado = null;
        _probioticoAplicado = false;
        _suplementoAplicado = false;

        Navigator.pop(context);
      } catch (e) {
        debugPrint('Erro ao salvar registro de ração: $e');
        // Se falhou depois de criar o documento (ex.: baixa FEFO insuficiente), apagar o registro para não deixar órfão
        if (docRef != null) {
          try {
            await docRef.delete();
          } catch (_) {}
        }
        if (mounted) {
          // Mensagem amigável ao usuário
          final raw = e.toString();
          String msg;
          if (raw.contains('Estoque insuficiente')) {
            // Tenta extrair a parte "Faltam X unidade"
            final idx = raw.indexOf('Faltam ');
            final detalhe = idx >= 0 ? raw.substring(idx).trim() : '';
            msg =
                'Estoque insuficiente para a quantidade informada.' +
                (detalhe.isNotEmpty ? ' $detalhe' : '');
            msg += ' O registro não foi salvo.';
          } else if (raw.contains('Todos os lotes estão vencidos') ||
              raw.contains('Não há lotes válidos')) {
            msg =
                'Não há lotes válidos disponíveis para atender a quantidade solicitada. Cadastre um novo lote ou selecione outro.';
          } else if (raw.contains('Insumo de Ração não encontrado') ||
              raw.contains('Insumo não encontrado')) {
            msg =
                'Insumo de ração não configurado. Cadastre um insumo do tipo "Ração" no módulo de Estoque.';
          } else {
            msg =
                'Não foi possível salvar o registro de ração. Verifique o estoque e tente novamente.';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ $msg'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  // _baixarEstoqueRacao removido (substituído por controle de lotes FEFO)

  Future<void> _carregarLoteFEFO() async {
    setState(() => _carregandoLote = true);
    try {
      // Localiza insumo de Ração (tolerante a acentos e variações)
      final insumosSnap = await FirebaseFirestore.instance
          .collection('insumos')
          .get();
      final candidatos = insumosSnap.docs.where((d) {
        final tipo = (d.data()['tipo'] ?? '').toString();
        return _norm(tipo) == 'racao';
      }).toList();

      if (candidatos.isEmpty) {
        if (mounted) {
          setState(() {
            _insumoRacaoId = null;
            _insumoRacaoNome = null;
            _loteSelecionadoId = null;
            _loteSelecionadoVencido = false;
          });
        }
      } else {
        // Procura o primeiro insumo de ração que tenha pelo menos 1 lote ativo com saldo
        QueryDocumentSnapshot<Map<String, dynamic>>? insumoEscolhido;
        List<Map<String, dynamic>> lotesEscolhidos = [];
        for (final insumoDoc in candidatos) {
          final lotesSnap = await FirebaseFirestore.instance
              .collection('lotes_insumo')
              .where('insumoId', isEqualTo: insumoDoc.id)
              .where('status', isEqualTo: 'ativo')
              .limit(100)
              .get();
          final lotesTmp = lotesSnap.docs
              .map((d) {
                final data = d.data();
                final qtd =
                    ((data['quantidade'] ?? data['quantidadeAtual'] ?? 0)
                            as num)
                        .toDouble();
                return {
                  'id': d.id,
                  'codigo':
                      ((data['lote'] ?? data['loteCodigo'] ?? '') as String)
                          .toString()
                          .isNotEmpty
                      ? (data['lote'] ?? data['loteCodigo'])
                      : d.id.substring(0, 6),
                  'validade': data['validade'],
                  'entrada': data['dataEntrada'],
                  'qtd': qtd,
                  'unidade': data['unidade'], // Captura a unidade do lote
                  'entregasPorPonto': data['entregasPorPonto'],
                };
              })
              .where((m) => (m['qtd'] as double) > 0)
              .toList();
          if (lotesTmp.isNotEmpty) {
            insumoEscolhido = insumoDoc;
            lotesEscolhidos = lotesTmp;
            break;
          }
        }

        // Se nenhum insumo tiver lotes com saldo, usa o primeiro candidato e mantém sem seleção de lote
        final insumoDocSel = insumoEscolhido ?? candidatos.first;
        _insumoRacaoId = insumoDocSel.id;
        _insumoRacaoNome = (insumoDocSel.data()['nome'] ?? 'Ração').toString();

        var lotes = lotesEscolhidos;
        // Se houver ponto preferido e a preferência estiver ativa, trazer lotes desse ponto primeiro
        if (_usarPreferenciaPonto && _pontoPreferidoId != null) {
          final doPonto = <Map<String, dynamic>>[];
          final outros = <Map<String, dynamic>>[];
          for (final l in lotes) {
            final eps = l['entregasPorPonto'];
            bool pertence = false;
            if (eps is List) {
              try {
                pertence = eps.any(
                  (e) =>
                      ((e['pontoId'] ?? e['id'] ?? '').toString()) ==
                      _pontoPreferidoId,
                );
              } catch (_) {}
            }
            (pertence ? doPonto : outros).add(l);
          }
          lotes = [...doPonto, ...outros];
        }
        // Ordenar FEFO: validade (não null primeiro, asc), depois dataEntrada
        lotes.sort((a, b) {
          DateTime va = a['validade'] is Timestamp
              ? (a['validade'] as Timestamp).toDate()
              : DateTime(9999);
          DateTime vb = b['validade'] is Timestamp
              ? (b['validade'] as Timestamp).toDate()
              : DateTime(9999);
          int comp = va.compareTo(vb);
          if (comp != 0) return comp;
          DateTime ea = a['entrada'] is Timestamp
              ? (a['entrada'] as Timestamp).toDate()
              : DateTime.now();
          DateTime eb = b['entrada'] is Timestamp
              ? (b['entrada'] as Timestamp).toDate()
              : DateTime.now();
          return ea.compareTo(eb);
        });
        if (lotes.isNotEmpty) {
          final hoje = DateTime.now();
          final validos = lotes.where((l) {
            final v = l['validade'] is Timestamp
                ? (l['validade'] as Timestamp).toDate()
                : null;
            if (v == null) return true; // sem validade vai pro fim mas é válido
            return !v.isBefore(DateTime(hoje.year, hoje.month, hoje.day));
          }).toList();
          Map<String, dynamic> selecionado;
          bool vencido = false;
          if (validos.isNotEmpty) {
            selecionado = validos.first;
          } else {
            selecionado = lotes.first; // só vencidos
            vencido = true;
          }
          if (mounted) {
            setState(() {
              _loteSelecionadoId = selecionado['id'];
              _loteSelecionadoCodigo = selecionado['codigo'];
              _loteValidade = selecionado['validade'] is Timestamp
                  ? (selecionado['validade'] as Timestamp).toDate()
                  : null;
              _loteQuantidadeAtual = selecionado['qtd'];
              _loteUnidade = selecionado['unidade']?.toString() ?? 'kg';
              _loteSelecionadoVencido = vencido;
            });
          }
          if (vencido && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Atenção: apenas lotes vencidos disponíveis.'),
              ),
            );
          }
        } else {
          if (mounted) {
            setState(() {
              _loteSelecionadoId = null;
              _loteSelecionadoVencido = false;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Erro carregando lote FEFO: $e');
    } finally {
      if (mounted) setState(() => _carregandoLote = false);
    }
  }

  Future<void> _carregarAlertasLotes() async {
    setState(() => _carregandoAlertas = true);
    try {
      final limite = DateTime.now().add(const Duration(days: 7));
      // Garante insumo de Ração carregado
      if (_insumoRacaoId == null) {
        // tenta carregar uma vez
        await _carregarLoteFEFO();
        if (_insumoRacaoId == null) {
          if (mounted) {
            setState(() {
              _qtdLotesVencidos = 0;
              _qtdLotesProximos = 0;
            });
          }
          return;
        }
      }
      final snap = await FirebaseFirestore.instance
          .collection('lotes_insumo')
          .where('insumoId', isEqualTo: _insumoRacaoId)
          .where('status', isEqualTo: 'ativo')
          .get();
      int vencidos = 0;
      int proximos = 0;
      for (var d in snap.docs) {
        final data = d.data();
        final qtd =
            ((data['quantidade'] ?? data['quantidadeAtual'] ?? 0) as num)
                .toDouble();
        if (qtd <= 0) continue;
        if (data['validade'] is Timestamp) {
          final v = (data['validade'] as Timestamp).toDate();
          final hoje = DateTime.now();
          if (v.isBefore(DateTime(hoje.year, hoje.month, hoje.day))) {
            vencidos++;
          } else if (!v.isBefore(hoje) && v.isBefore(limite)) {
            proximos++;
          }
        }
      }
      if (mounted) {
        setState(() {
          _qtdLotesVencidos = vencidos;
          _qtdLotesProximos = proximos;
        });
      }
    } catch (e) {
      debugPrint('Erro carregando alertas lotes: $e');
    } finally {
      if (mounted) setState(() => _carregandoAlertas = false);
    }
  }

  void _trocarLote() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        String filtro = '';
        bool ocultarVencidos = false;
        return StatefulBuilder(
          builder: (ctx, setStateModal) => SizedBox(
            height: 560,
            child: Column(
              children: [
                const SizedBox(height: 12),
                const Text(
                  'Selecionar Lote de Ração',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Buscar por código ou fornecedor',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (v) => setStateModal(
                            () => filtro = v.toLowerCase().trim(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        children: [
                          const Text('Ocultar vencidos'),
                          Switch(
                            value: ocultarVencidos,
                            onChanged: (v) =>
                                setStateModal(() => ocultarVencidos = v),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Row(
                        children: [
                          const Text('Somente com saldo'),
                          Switch(
                            value: _apenasComSaldoSelecaoLote,
                            onChanged: (v) => setStateModal(
                              () => _apenasComSaldoSelecaoLote = v,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Cadastrar novo lote de ração',
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await Navigator.push(
                              ctx,
                              MaterialPageRoute(
                                builder: (_) => TelaEntradaInsumo(
                                  insumoIdPreSelecionado: _insumoRacaoId,
                                ),
                              ),
                            );
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx); // fecha o bottom sheet
                            if (!mounted) return;
                            _carregarLoteFEFO();
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Novo lote'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_pontoPreferidoId != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Chip(
                          label: Text(
                            'Ponto preferido: ${_pontoPreferidoNome ?? ''}',
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        const Text('Priorizar lotes deste ponto'),
                        Switch(
                          value: _usarPreferenciaPonto,
                          onChanged: (v) =>
                              setStateModal(() => _usarPreferenciaPonto = v),
                        ),
                      ],
                    ),
                  ),
                const Divider(),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _insumoRacaoId == null
                        ? const Stream<
                            QuerySnapshot<Map<String, dynamic>>
                          >.empty()
                        : FirebaseFirestore.instance
                              .collection('lotes_insumo')
                              .where('insumoId', isEqualTo: _insumoRacaoId)
                              .where('status', isEqualTo: 'ativo')
                              .limit(200)
                              .snapshots(),
                    builder: (context, snapshot) {
                      if (_insumoRacaoId == null) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              'Para selecionar lotes, cadastre primeiro o insumo "Ração" no módulo de Estoque e crie um lote ativo.',
                            ),
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Erro: ${snapshot.error}'));
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = snapshot.data!.docs;
                      if (docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Nenhum lote ativo. Cadastre um lote.',
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  await Navigator.push(
                                    ctx,
                                    MaterialPageRoute(
                                      builder: (_) => TelaEntradaInsumo(
                                        insumoIdPreSelecionado: _insumoRacaoId,
                                      ),
                                    ),
                                  );
                                  if (!ctx.mounted) return;
                                  Navigator.pop(ctx); // fecha o bottom sheet
                                  if (!mounted) return;
                                  _carregarLoteFEFO();
                                },
                                icon: const Icon(Icons.add),
                                label: const Text('Cadastrar Lote (Estoque)'),
                              ),
                            ],
                          ),
                        );
                      }

                      // Monta lista com metadados para aplicar ordenação FEFO client-side
                      final lotes = docs.map((d) {
                        final data = d.data();
                        final validade = data['validade'] is Timestamp
                            ? (data['validade'] as Timestamp).toDate()
                            : null;
                        final entrada = data['dataEntrada'] is Timestamp
                            ? (data['dataEntrada'] as Timestamp).toDate()
                            : null;
                        final qtd =
                            ((data['quantidade'] ??
                                        data['quantidadeAtual'] ??
                                        0)
                                    as num)
                                .toDouble();
                        return {
                          'doc': d,
                          'data': data,
                          'validade': validade,
                          'entrada': entrada,
                          'qtd': qtd,
                          'fornecedor': (data['fornecedor'] ?? '').toString(),
                        };
                      }).toList();

                      // FEFO: menor validade primeiro (nulls por último), em empate usa dataEntrada mais antiga
                      lotes.sort((a, b) {
                        final va = a['validade'] as DateTime?;
                        final vb = b['validade'] as DateTime?;
                        if (va == null && vb != null) return 1;
                        if (va != null && vb == null) return -1;
                        if (va != null && vb != null) {
                          final comp = va.compareTo(vb);
                          if (comp != 0) return comp;
                        }
                        final ea = a['entrada'] as DateTime?;
                        final eb = b['entrada'] as DateTime?;
                        if (ea == null && eb != null) return 1;
                        if (ea != null && eb == null) return -1;
                        if (ea != null && eb != null) return ea.compareTo(eb);
                        return 0;
                      });

                      // Filtro por texto e opcionalmente ocultar vencidos
                      final agora = DateTime.now();
                      final hoje = DateTime(agora.year, agora.month, agora.day);
                      final lotesFiltrados = lotes.where((l) {
                        final data = l['data'] as Map<String, dynamic>;
                        final codigo =
                            (data['lote'] ?? '').toString().isNotEmpty
                            ? data['lote'].toString()
                            : (l['doc'] as QueryDocumentSnapshot).id.substring(
                                0,
                                6,
                              );
                        final fornecedor = (l['fornecedor'] as String?) ?? '';
                        final validade = l['validade'] as DateTime?;
                        final vencido =
                            validade != null && validade.isBefore(hoje);
                        final matchTexto =
                            filtro.isEmpty ||
                            codigo.toLowerCase().contains(filtro) ||
                            fornecedor.toLowerCase().contains(filtro);
                        if (!matchTexto) return false;
                        if (ocultarVencidos && vencido) return false;
                        return true;
                      }).toList();

                      // Determina exibição considerando filtro "somente com saldo"
                      final lotesExibir = lotesFiltrados.where((l) {
                        final qtd = (l['qtd'] as double?) ?? 0.0;
                        if (_apenasComSaldoSelecaoLote) return qtd > 0;
                        return true;
                      }).toList();

                      final itens = lotesExibir.map((l) {
                        final d =
                            l['doc']
                                as QueryDocumentSnapshot<Map<String, dynamic>>;
                        final data = l['data'] as Map<String, dynamic>;
                        final validade = l['validade'] as DateTime?;
                        final qtd = (l['qtd'] as double?) ?? 0.0;
                        final vencido =
                            validade != null && validade.isBefore(hoje);
                        final perto =
                            validade != null &&
                            !vencido &&
                            validade.difference(agora).inDays <= 7;
                        final codigo =
                            ((data['lote'] ?? data['loteCodigo'] ?? '')
                                    as String)
                                .toString()
                                .isNotEmpty
                            ? (data['lote'] ?? data['loteCodigo'])
                            : d.id.substring(0, 6);
                        final diasParaVencer = validade
                            ?.difference(agora)
                            .inDays;
                        return ListTile(
                          leading: Icon(
                            Icons.inventory_2,
                            color: vencido
                                ? Colors.red
                                : (perto ? Colors.orange : Colors.teal),
                          ),
                          title: Text(codigo),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                [
                                  if (validade != null)
                                    'Val: ${validade.day.toString().padLeft(2, '0')}/${validade.month.toString().padLeft(2, '0')}/${validade.year}'
                                  else
                                    'Sem validade',
                                  'Restante: ${qtd.toStringAsFixed(2)} kg',
                                ].join(' • '),
                              ),
                              if ((l['fornecedor'] as String).isNotEmpty ||
                                  diasParaVencer != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2.0),
                                  child: Text(
                                    [
                                      if ((l['fornecedor'] as String)
                                          .isNotEmpty)
                                        'Fornecedor: ${l['fornecedor']}',
                                      if (diasParaVencer != null &&
                                          !vencido &&
                                          validade != null)
                                        'Vence em ${diasParaVencer}d',
                                    ].join(' • '),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              if (vencido)
                                const Chip(
                                  label: Text('Vencido'),
                                  backgroundColor: Colors.red,
                                  labelStyle: TextStyle(color: Colors.white),
                                  visualDensity: VisualDensity.compact,
                                ),
                              if (!vencido && perto)
                                const Chip(
                                  label: Text('Vence logo'),
                                  backgroundColor: Colors.orange,
                                  labelStyle: TextStyle(color: Colors.white),
                                  visualDensity: VisualDensity.compact,
                                ),
                              if (qtd <= 0)
                                const Chip(
                                  label: Text('Sem saldo'),
                                  backgroundColor: Colors.grey,
                                  labelStyle: TextStyle(color: Colors.white),
                                  visualDensity: VisualDensity.compact,
                                ),
                            ],
                          ),
                          onTap: qtd <= 0
                              ? null
                              : () {
                                  setState(() {
                                    _loteSelecionadoId = d.id;
                                    _loteSelecionadoCodigo = codigo;
                                    _loteValidade = validade;
                                    _loteQuantidadeAtual = qtd;
                                    _loteSelecionadoVencido = vencido;
                                  });
                                  Navigator.pop(ctx);
                                  if (vencido && ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Lote vencido selecionado. Confirme ao salvar.',
                                        ),
                                      ),
                                    );
                                  }
                                },
                        );
                      }).toList();

                      if (itens.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Nenhum lote com saldo para os filtros atuais.',
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () => setStateModal(() {
                                        filtro = '';
                                        ocultarVencidos = false;
                                      }),
                                      icon: const Icon(Icons.filter_alt_off),
                                      label: const Text('Limpar filtros'),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () async {
                                        await Navigator.push(
                                          ctx,
                                          MaterialPageRoute(
                                            builder: (_) => TelaEntradaInsumo(
                                              insumoIdPreSelecionado:
                                                  _insumoRacaoId,
                                            ),
                                          ),
                                        );
                                        if (!ctx.mounted) return;
                                        Navigator.pop(ctx);
                                        if (!mounted) return;
                                        _carregarLoteFEFO();
                                      },
                                      icon: const Icon(Icons.add),
                                      label: const Text(
                                        'Cadastrar Lote (Estoque)',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView(children: itens);
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ), // end SizedBox from StatefulBuilder builder
        ); // end StatefulBuilder
      },
    );
  }

  // Localiza um insumo por tipo (ex.: 'probiotico', 'suplemento'), tolerante a acentos/case
  Future<Map<String, String>?> _localizarInsumoPorTipo(String tipoAlvo) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('insumos')
          .limit(200)
          .get();
      for (final d in snap.docs) {
        final data = d.data();
        final tipo = (data['tipo'] ?? '').toString();
        if (_norm(tipo) == _norm(tipoAlvo)) {
          return {'id': d.id, 'nome': (data['nome'] ?? tipoAlvo).toString()};
        }
      }
    } catch (e) {
      debugPrint('Erro localizando insumo por tipo $tipoAlvo: $e');
    }
    return null;
  }

  // Removido seletor de horário: não é mais necessário registrar hora manualmente.

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Registrar Ração',
      body: DegradeFundo(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Mantemos layout enxuto alinhado ao padrão de Análise de Água
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Destino',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SegmentedButton<String>(
                                segments: const [
                                  ButtonSegment(
                                    value: 'viveiro',
                                    label: Text('Viveiro'),
                                    icon: Icon(Icons.water_outlined),
                                  ),
                                  ButtonSegment(
                                    value: 'bercario',
                                    label: Text('Berçário'),
                                    icon: Icon(Icons.biotech_outlined),
                                  ),
                                ],
                                selected: <String>{
                                  if (_tipoDestino != null) _tipoDestino!,
                                },
                                emptySelectionAllowed: true,
                                showSelectedIcon: false,
                                onSelectionChanged: (newSel) {
                                  final v = newSel.isNotEmpty
                                      ? newSel.first
                                      : null;
                                  setState(() {
                                    _tipoDestino = v;
                                    _viveiroSelecionado = null;
                                    _codigoDestino = null;
                                    _destinoNome = null;
                                  });
                                },
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _tipoDestino == 'bercario'
                                    ? 'Listando berçários ativos'
                                    : 'Listando viveiros ativos',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection(
                                      _tipoDestino == 'bercario'
                                          ? 'bercarios'
                                          : 'viveiros',
                                    )
                                    .orderBy('nome')
                                    .snapshots()
                                    .handleError((e) {
                                      // Fallback legado para possível coleção com cedilha
                                      if (_tipoDestino == 'bercario') {
                                        return FirebaseFirestore.instance
                                            .collection('berçarios')
                                            .orderBy('nome')
                                            .snapshots();
                                      }
                                      return Stream.error(e);
                                    }),
                                builder: (context, snapshot) {
                                  if (snapshot.hasError) {
                                    return Text(
                                      'Erro ao carregar destinos: ${snapshot.error}',
                                    );
                                  }
                                  if (!snapshot.hasData) {
                                    return const LinearProgressIndicator();
                                  }
                                  final docs = snapshot.data!.docs;
                                  if (docs.isEmpty) {
                                    return Text(
                                      'Nenhum ${_tipoDestino == 'bercario' ? 'berçário' : 'viveiro'} cadastrado',
                                    );
                                  }
                                  return DropdownButtonFormField<String>(
                                    initialValue: _viveiroSelecionado,
                                    decoration: InputDecoration(
                                      labelText:
                                          'Selecione o ${_tipoDestino == 'bercario' ? 'berçário' : 'viveiro'}',
                                      border: const OutlineInputBorder(),
                                    ),
                                    items: docs.map((doc) {
                                      final data =
                                          doc.data() as Map<String, dynamic>;
                                      final codigo = data['codigo'] ?? '';
                                      final nome = data['nome'] ?? '';
                                      final display = '$codigo - $nome';
                                      return DropdownMenuItem<String>(
                                        value: display,
                                        child: Text(display),
                                        onTap: () {
                                          setState(() {
                                            _codigoDestino = codigo;
                                            _destinoNome = display;
                                          });
                                          _resolverPontoPreferido().then((_) {
                                            _carregarLoteFEFO();
                                          });
                                          // Atualizar preview do dia do ciclo ao trocar destino
                                          _atualizarDiaCicloPreview();
                                        },
                                      );
                                    }).toList(),
                                    onChanged: (v) {
                                      setState(() => _viveiroSelecionado = v);
                                    },
                                    validator: (value) {
                                      if (value == null) {
                                        return 'Selecione um destino';
                                      }
                                      return null;
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_carregandoAlertas)
                                const LinearProgressIndicator(minHeight: 2),
                              if (!_carregandoAlertas &&
                                  (_qtdLotesVencidos > 0 ||
                                      _qtdLotesProximos > 0))
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 16),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _qtdLotesVencidos > 0
                                        ? Colors.red[50]
                                        : Colors.orange[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _qtdLotesVencidos > 0
                                          ? Colors.red
                                          : Colors.orange,
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        _qtdLotesVencidos > 0
                                            ? Icons.error_outline
                                            : Icons.warning_amber_outlined,
                                        color: _qtdLotesVencidos > 0
                                            ? Colors.red
                                            : Colors.orange,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          [
                                            if (_qtdLotesVencidos > 0)
                                              '$_qtdLotesVencidos lote(s) vencido(s) ainda com saldo.',
                                            if (_qtdLotesProximos > 0)
                                              '$_qtdLotesProximos vence(m) em até 7 dias.',
                                          ].join('\n'),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Recarregar',
                                        onPressed: () {
                                          _carregarAlertasLotes();
                                          _carregarLoteFEFO();
                                        },
                                        icon: const Icon(Icons.refresh),
                                      ),
                                    ],
                                  ),
                                ),
                              const Text(
                                'Lote de Ração (FEFO)',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (_carregandoLote)
                                const LinearProgressIndicator(minHeight: 2)
                              else if (_loteSelecionadoId == null)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Nenhum lote ativo encontrado.'),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: () async {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    TelaEntradaInsumo(
                                                      insumoIdPreSelecionado:
                                                          _insumoRacaoId,
                                                    ),
                                              ),
                                            );
                                            _carregarLoteFEFO();
                                          },
                                          icon: const Icon(Icons.add),
                                          label: const Text(
                                            'Cadastrar Lote (Estoque)',
                                          ),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: _carregarLoteFEFO,
                                          icon: const Icon(Icons.refresh),
                                          label: const Text('Recarregar'),
                                        ),
                                      ],
                                    ),
                                  ],
                                )
                              else
                                Card(
                                  elevation: 1,
                                  color: _loteSelecionadoVencido
                                      ? Colors.red.shade50
                                      : Colors.teal.shade50,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.inventory_2,
                                          color: _loteSelecionadoVencido
                                              ? Colors.red
                                              : Colors.teal,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      'Lote: ${_loteSelecionadoCodigo ?? '-'}',
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                  if (_loteSelecionadoVencido)
                                                    const Chip(
                                                      label: Text('Vencido'),
                                                      backgroundColor:
                                                          Colors.red,
                                                      labelStyle: TextStyle(
                                                        color: Colors.white,
                                                      ),
                                                      visualDensity:
                                                          VisualDensity.compact,
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                [
                                                  if (_loteValidade != null)
                                                    'Val: ${_loteValidade!.day.toString().padLeft(2, '0')}/${_loteValidade!.month.toString().padLeft(2, '0')}/${_loteValidade!.year}'
                                                  else
                                                    'Sem validade',
                                                  if (_loteQuantidadeAtual !=
                                                      null)
                                                    'Restante: ${_loteQuantidadeAtual!.toStringAsFixed(2)} kg',
                                                ].join(' • '),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                              if (_pontoPreferidoNome != null)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 4.0,
                                                      ),
                                                  child: Wrap(
                                                    spacing: 8,
                                                    runSpacing: 4,
                                                    crossAxisAlignment:
                                                        WrapCrossAlignment
                                                            .center,
                                                    children: [
                                                      Chip(
                                                        label: Text(
                                                          'Ponto preferido: ${_pontoPreferidoNome!}',
                                                        ),
                                                        visualDensity:
                                                            VisualDensity
                                                                .compact,
                                                      ),
                                                      const Text(
                                                        'Priorizar lotes do ponto',
                                                      ),
                                                      Switch(
                                                        value:
                                                            _usarPreferenciaPonto,
                                                        onChanged: (v) => setState(
                                                          () =>
                                                              _usarPreferenciaPonto =
                                                                  v,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        // O botão 'Trocar' vai para a linha de baixo em telas estreitas
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton.icon(
                                            onPressed: _trocarLote,
                                            icon: const Icon(Icons.swap_horiz),
                                            label: const Text('Trocar'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              const Divider(height: 32),
                              const Text(
                                'Informações da Ração',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _racaoController,
                                decoration: InputDecoration(
                                  labelText:
                                      _loteUnidade?.toLowerCase() == 'balde'
                                      ? 'Quantidade (baldes)'
                                      : 'Quantidade (kg)',
                                  border: const OutlineInputBorder(),
                                  suffixText:
                                      _loteUnidade?.toLowerCase() == 'balde'
                                      ? 'baldes'
                                      : 'kg',
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Por favor, insira a quantidade';
                                  }
                                  final numero = double.tryParse(
                                    value.replaceAll(',', '.'),
                                  );
                                  if (numero == null || numero <= 0) {
                                    return 'Insira um valor válido';
                                  }
                                  return null;
                                },
                              ),
                              // Campo adicional quando for balde (mL ou gramas)
                              if (_loteUnidade?.toLowerCase() == 'balde') ...[
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: TextFormField(
                                        controller:
                                            _quantidadeBaldeMlGramasController,
                                        decoration: InputDecoration(
                                          labelText: 'Qtd. específica',
                                          border: const OutlineInputBorder(),
                                          suffixText: _unidadeBaldeSelecionada,
                                          helperText: 'Parcial do balde',
                                        ),
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 2,
                                      child: DropdownButtonFormField<String>(
                                        value: _unidadeBaldeSelecionada,
                                        decoration: const InputDecoration(
                                          labelText: 'Unidade',
                                          border: OutlineInputBorder(),
                                        ),
                                        items: const [
                                          DropdownMenuItem(
                                            value: 'mL',
                                            child: Text('mL'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'g',
                                            child: Text('g'),
                                          ),
                                        ],
                                        onChanged: (v) {
                                          if (v != null) {
                                            setState(
                                              () =>
                                                  _unidadeBaldeSelecionada = v,
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        size: 16,
                                        color: Colors.blue[700],
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Deixe vazio se usar baldes inteiros',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.blue[900],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              // Campo de Data do Registro
                              InkWell(
                                onTap: () async {
                                  final now = DateTime.now();
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _dataRegistro ?? now,
                                    firstDate: DateTime(now.year - 1),
                                    lastDate: now,
                                    helpText: 'Selecione a data do trato',
                                  );
                                  if (picked != null) {
                                    // Manter hora atual, apenas mudar dia
                                    setState(() {
                                      _dataRegistro = DateTime(
                                        picked.year,
                                        picked.month,
                                        picked.day,
                                        now.hour,
                                        now.minute,
                                      );
                                    });
                                    // Atualizar preview do dia do ciclo
                                    await _atualizarDiaCicloPreview();
                                  }
                                },
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: 'Data do Registro',
                                    border: const OutlineInputBorder(),
                                    prefixIcon: const Icon(
                                      Icons.calendar_today,
                                    ),
                                    suffixIcon: _dataRegistro != null
                                        ? IconButton(
                                            icon: const Icon(Icons.clear),
                                            onPressed: () {
                                              setState(
                                                () => _dataRegistro = null,
                                              );
                                              // Recalcular usando data de hoje
                                              _atualizarDiaCicloPreview();
                                            },
                                            tooltip: 'Usar data de hoje',
                                          )
                                        : null,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _dataRegistro == null
                                              ? 'Hoje (${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year})'
                                              : '${_dataRegistro!.day.toString().padLeft(2, '0')}/${_dataRegistro!.month.toString().padLeft(2, '0')}/${_dataRegistro!.year}',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: _dataRegistro == null
                                                ? Colors.grey[600]
                                                : Colors.black,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Indicador de Dia do Ciclo (se houver ciclo ativo)
                              if ((_temCicloAtivoPreview &&
                                      _diaCicloPreview != null) ||
                                  _totalDiaPreviewKg != null ||
                                  _totalAcumuladoPreviewKg != null) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.timeline, size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      _diaCicloPreview == 0
                                          ? 'Antes do início do ciclo'
                                          : _diaCicloPreview == null
                                          ? 'Dia do ciclo: —'
                                          : 'Dia do ciclo: $_diaCicloPreview',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_temCicloAtivoPreview &&
                                    _inicioCicloPreview != null) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.flag_circle, size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Início do ciclo: '
                                        '${_inicioCicloPreview!.day.toString().padLeft(2, '0')}/'
                                        '${_inicioCicloPreview!.month.toString().padLeft(2, '0')}/'
                                        '${_inicioCicloPreview!.year}',
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.today, size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Total do dia: ' +
                                          (_totalDiaPreviewKg == null
                                              ? '—'
                                              : '${_totalDiaPreviewKg!.toStringAsFixed(2)} kg'),
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.summarize, size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Total acumulado: ' +
                                          (_totalAcumuladoPreviewKg == null
                                              ? '—'
                                              : '${_totalAcumuladoPreviewKg!.toStringAsFixed(2)} kg'),
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 16),
                              // Resumo dos Tratos do Dia (1º, 2º, 3º)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: const [
                                      Icon(Icons.list_alt, size: 18),
                                      SizedBox(width: 6),
                                      Text(
                                        'Tratos do dia',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  for (final t in [1, 2, 3]) ...[
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          SizedBox(
                                            width: 80,
                                            child: Text(
                                              '${t}º Trato',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Builder(
                                              builder: (context) {
                                                final lista =
                                                    _tratosDiaPreview[t] ??
                                                    const <
                                                      Map<String, dynamic>
                                                    >[];
                                                if (lista.isEmpty) {
                                                  return Text(
                                                    '—',
                                                    style: TextStyle(
                                                      color: Colors.grey[600],
                                                    ),
                                                  );
                                                }
                                                return Wrap(
                                                  spacing: 6,
                                                  runSpacing: 6,
                                                  children: lista.map((e) {
                                                    final double? q =
                                                        e['quantidade']
                                                            as double?;
                                                    final qtd = q == null
                                                        ? '0.00'
                                                        : q.toStringAsFixed(2);
                                                    return Chip(
                                                      label: Text('$qtd kg'),
                                                      visualDensity:
                                                          VisualDensity.compact,
                                                      materialTapTargetSize:
                                                          MaterialTapTargetSize
                                                              .shrinkWrap,
                                                    );
                                                  }).toList(),
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Seleção de Trato (opcional)
                              DropdownButtonFormField<int>(
                                decoration: const InputDecoration(
                                  labelText: 'Trato (opcional)',
                                  border: OutlineInputBorder(),
                                ),
                                value: _tratoSelecionado,
                                items: const [
                                  DropdownMenuItem(
                                    value: 1,
                                    child: Text('1º Trato'),
                                  ),
                                  DropdownMenuItem(
                                    value: 2,
                                    child: Text('2º Trato'),
                                  ),
                                  DropdownMenuItem(
                                    value: 3,
                                    child: Text('3º Trato'),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _tratoSelecionado = v),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Aditivos',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  FilterChip(
                                    selected: _probioticoAplicado,
                                    onSelected: (v) =>
                                        setState(() => _probioticoAplicado = v),
                                    label: const Text('Probiótico'),
                                    avatar: const Icon(Icons.biotech, size: 16),
                                  ),
                                  FilterChip(
                                    selected: _suplementoAplicado,
                                    onSelected: (v) =>
                                        setState(() => _suplementoAplicado = v),
                                    label: const Text('Suplemento'),
                                    avatar: const Icon(
                                      Icons.add_circle_outline,
                                      size: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: TextFormField(
                            controller: _observacoesController,
                            decoration: const InputDecoration(
                              labelText: 'Observações (opcional)',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Mensagem informativa para registro retroativo
                      if (_dataRegistro != null &&
                          !_isMesmaData(_dataRegistro!, DateTime.now()))
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            border: Border.all(color: Colors.blue[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue[700]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Registro retroativo: será salvo com a data selecionada.',
                                  style: TextStyle(
                                    color: Colors.blue[900],
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                              child: const Text('Cancelar'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _salvarRegistro,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                              child: const Text('Salvar'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

// --- Tela simples para cadastrar lote de ração ---
class _TelaCadastroLoteRacao extends StatefulWidget {
  const _TelaCadastroLoteRacao();
  @override
  State<_TelaCadastroLoteRacao> createState() => _TelaCadastroLoteRacaoState();
}

class _TelaCadastroLoteRacaoState extends State<_TelaCadastroLoteRacao> {
  final _formKey = GlobalKey<FormState>();
  final _codigoController = TextEditingController();
  final _quantidadeController = TextEditingController();
  final _fornecedorController = TextEditingController();
  DateTime? _validade;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _codigoController.text = _gerarCodigo();
  }

  String _gerarCodigo() {
    final now = DateTime.now();
    return 'RAC-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      final qtd = double.parse(_quantidadeController.text.replaceAll(',', '.'));
      await FirebaseFirestore.instance.collection('lotes_insumo').add({
        'tipo': 'racao',
        'loteCodigo': _codigoController.text.trim(),
        'quantidadeInicial': qtd,
        'quantidadeAtual': qtd,
        'unidade': 'kg',
        'status': 'ativo',
        'dataEntrada': Timestamp.fromDate(DateTime.now()),
        'validade': _validade != null ? Timestamp.fromDate(_validade!) : null,
        'fornecedor': _fornecedorController.text.trim(),
        'criadoEm': FieldValue.serverTimestamp(),
        'atualizadoEm': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao salvar lote: $e')));
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Novo Lote de Ração')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _codigoController,
                decoration: const InputDecoration(labelText: 'Código do Lote'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Informe o código' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _quantidadeController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Quantidade Inicial (kg)',
                ),
                validator: (v) {
                  final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                  if (n == null || n <= 0) return 'Quantidade inválida';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate:
                        _validade ??
                        DateTime.now().add(const Duration(days: 180)),
                    firstDate: DateTime.now().subtract(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 1000)),
                  );
                  if (d != null) setState(() => _validade = d);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Validade (opcional)',
                  ),
                  child: Text(
                    _validade == null
                        ? 'Selecionar'
                        : '${_validade!.day.toString().padLeft(2, '0')}/${_validade!.month.toString().padLeft(2, '0')}/${_validade!.year}',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _fornecedorController,
                decoration: const InputDecoration(
                  labelText: 'Fornecedor (opcional)',
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _salvando ? null : _salvar,
                icon: const Icon(Icons.save),
                label: Text(_salvando ? 'Salvando...' : 'Salvar Lote'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
