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

  String? _viveiroSelecionado; // display "codigo - nome"
  String? _tipoDestino = 'viveiro';
  String? _codigoDestino;
  String? _destinoNome; // mesmo conteúdo de display para compatibilidade
  // Trato do dia (1, 2 ou 3)
  int? _tratoSelecionado; // 1, 2, 3
  bool _probioticoAplicado = false;
  bool _suplementoAplicado = false;
  bool _isLoading = false;
  // Lote de ração (FEFO)
  String? _insumoRacaoId;
  String? _insumoRacaoNome;
  String? _loteSelecionadoId;
  String? _loteSelecionadoCodigo;
  DateTime? _loteValidade;
  double? _loteQuantidadeAtual;
  bool _carregandoLote = false;
  bool _loteSelecionadoVencido = false;
  int _qtdLotesVencidos = 0;
  int _qtdLotesProximos = 0;
  bool _carregandoAlertas = false;

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
  }

  @override
  void dispose() {
    _racaoController.dispose();
    _observacoesController.dispose();
    super.dispose();
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
        final dataHora = DateTime.now();

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
                final atual = double.parse(
                  _racaoController.text.replaceAll(',', '.'),
                );
                totalAcumulado = soma + atual;
              }
            }
          }
        } catch (e) {
          debugPrint('Falha ao calcular dia/total do ciclo: $e');
        }

        // Preparar dados com todos os campos necessários
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
          'quantidade': double.parse(
            _racaoController.text.replaceAll(',', '.'),
          ),
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
        final quantidadeKg = double.parse(
          _racaoController.text.replaceAll(',', '.'),
        );
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

        final lotes = lotesEscolhidos;
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

                      final itens = lotesFiltrados
                          .where((l) => ((l['qtd'] as double?) ?? 0) > 0)
                          .map((l) {
                            final d =
                                l['doc']
                                    as QueryDocumentSnapshot<
                                      Map<String, dynamic>
                                    >;
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
                                      labelStyle: TextStyle(
                                        color: Colors.white,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  if (!vencido && perto)
                                    const Chip(
                                      label: Text('Vence logo'),
                                      backgroundColor: Colors.orange,
                                      labelStyle: TextStyle(
                                        color: Colors.white,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                ],
                              ),
                              onTap: () {
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
                          })
                          .toList();

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
                      const SizedBox(height: 10),
                      const Center(
                        child: Column(
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
                              'Registro de Ração',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Registre a oferta de ração nos viveiros e berçários com controle de lote (FEFO).',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.teal,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 20),
                          ],
                        ),
                      ),
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
                                            ],
                                          ),
                                        ),
                                        TextButton.icon(
                                          onPressed: _trocarLote,
                                          icon: const Icon(Icons.swap_horiz),
                                          label: const Text('Trocar'),
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
                                decoration: const InputDecoration(
                                  labelText: 'Quantidade (kg)',
                                  border: OutlineInputBorder(),
                                  suffixText: 'kg',
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
