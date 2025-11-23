import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/degrade_fundo.dart';

class TelaDespesca extends StatefulWidget {
  const TelaDespesca({
    super.key,
    required this.despescaId,
    required this.codigoViveiro,
    required this.nomeViveiro,
  });

  final String despescaId;
  final String codigoViveiro;
  final String nomeViveiro;

  @override
  State<TelaDespesca> createState() => _TelaDespescaState();
}

class _TelaDespescaState extends State<TelaDespesca> {
  final _formKey = GlobalKey<FormState>();

  // Controladores
  final _observacoesCtrl = TextEditingController();
  final _responsavelCtrl = TextEditingController();
  final _pesoTotalDiaCtrl = TextEditingController();
  final _quantidadeBasquetasCtrl = TextEditingController();
  final _biometriaCtrl = TextEditingController();
  // Lotes (subtotais do dia)
  List<Map<String, dynamic>> _lotesDia = [];
  final _pesoLoteCtrl = TextEditingController();
  final _basquetasLoteCtrl = TextEditingController();
  final _basquetasFocus = FocusNode();
  int? _sugestaoBasquetas;
  // Data do registro com edição manual
  final _dataRegistroCtrl = TextEditingController();
  DateTime _dataRegistro = DateTime.now();

  // Estado da despesca
  Map<String, dynamic>? _despescaAtual;
  List<Map<String, dynamic>> _diasDespesca = [];
  int _diaAtual = 1;
  String? _responsavelSelecionado;
  String? _responsavelNomeAtual;
  Map<String, String> _funcionarios = {};
  Timer? _debounceBiometria;
  Timer? _debounceObservacoes;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    await Future.wait([_carregarFuncionarios(), _carregarDespescaAtual()]);
  }

  Future<void> _carregarFuncionarios() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('usuarios')
          .orderBy('nome')
          .get();
      final mapa = <String, String>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        mapa[doc.id] = data['nome'];
      }
      setState(() {
        _funcionarios = mapa;
        if (_responsavelSelecionado != null) {
          _responsavelNomeAtual =
              mapa[_responsavelSelecionado!] ?? _responsavelNomeAtual;
        }
      });
    } catch (e) {
      debugPrint('Erro ao carregar funcionários: $e');
    }
  }

  Future<void> _carregarDespescaAtual() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('despescas')
          .doc(widget.despescaId)
          .get();

      if (!doc.exists) return;

      final data = doc.data()!;
      final dias = List<Map<String, dynamic>>.from(data['dias'] ?? []);
      final hoje = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final diaHoje = dias.firstWhere(
        (dia) => dia['data'] == hoje,
        orElse: () => <String, dynamic>{},
      );

      double? pesoTotalDia = (diaHoje['pesoTotal'] as num?)?.toDouble();
      int? totalBasquetasDia = (diaHoje['totalBasquetas'] as num?)?.toInt();
      double? biometriaDia =
          (diaHoje['biometriaPesoMedio'] as num?)?.toDouble() ??
          (diaHoje['biometria'] as num?)?.toDouble();
      final observacoesDia = diaHoje['observacoes']?.toString() ?? '';
      String? responsavelId = diaHoje['responsavelId'] as String?;
      String responsavelNome = diaHoje['responsavel']?.toString() ?? '';

      // Suporte a múltiplos lotes por dia (mantido por compatibilidade)
      final lotes = List<Map<String, dynamic>>.from(
        diaHoje['lotes'] ?? const [],
      );

      final basquetasAntigas = List<Map<String, dynamic>>.from(
        diaHoje['basquetas'] ?? [],
      );
      if (pesoTotalDia == null && basquetasAntigas.isNotEmpty) {
        pesoTotalDia = basquetasAntigas.fold<double>(
          0.0,
          (sum, basqueta) =>
              sum + ((basqueta['peso'] as num?)?.toDouble() ?? 0.0),
        );
      }
      if (totalBasquetasDia == null && basquetasAntigas.isNotEmpty) {
        totalBasquetasDia = basquetasAntigas.length;
      }

      if (lotes.isEmpty &&
          (pesoTotalDia != null || totalBasquetasDia != null)) {
        _lotesDia = [
          {
            'pesoTotal': pesoTotalDia ?? 0.0,
            'totalBasquetas': totalBasquetasDia ?? 0,
          },
        ];
      } else {
        _lotesDia = lotes;
      }

      if (diaHoje.isEmpty && dias.isNotEmpty) {
        final ultimoDia = dias.last;
        responsavelId ??= ultimoDia['responsavelId'] as String?;
        responsavelNome =
            ultimoDia['responsavel']?.toString() ?? responsavelNome;
      }

      setState(() {
        _despescaAtual = data;
        _diasDespesca = dias;
        _diaAtual = diaHoje.isNotEmpty
            ? (diaHoje['numeroDia'] as int? ?? dias.length)
            : dias.length + 1;
        _dataRegistro = DateTime.now();
        _responsavelSelecionado = responsavelId;
        _responsavelNomeAtual = responsavelNome;
      });

      _dataRegistroCtrl.text = DateFormat('dd/MM/yyyy').format(_dataRegistro);
      _pesoTotalDiaCtrl.text = pesoTotalDia != null
          ? _formatDouble(pesoTotalDia)
          : '';
      _quantidadeBasquetasCtrl.text = totalBasquetasDia != null
          ? '$totalBasquetasDia'
          : '';
      _biometriaCtrl.text = biometriaDia != null
          ? _formatDouble(biometriaDia)
          : '';
      _observacoesCtrl.text = observacoesDia;

      if (responsavelId == null) {
        _responsavelCtrl.text = responsavelNome;
      } else {
        _responsavelCtrl.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar despesca: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Selecionar/alterar a data do registro do dia
  Future<void> _selecionarDataRegistro() async {
    final agora = DateTime.now();
    final selecionada = await showDatePicker(
      context: context,
      initialDate: _dataRegistro,
      firstDate: DateTime(agora.year - 1, 1, 1),
      lastDate: DateTime(agora.year, agora.month, agora.day),
      helpText: 'Selecionar data do registro',
      confirmText: 'Selecionar',
      cancelText: 'Cancelar',
    );

    if (selecionada == null) return;
    _aplicarDataSelecionada(selecionada);
  }

  void _aplicarDataSelecionada(DateTime selecionada) {
    // Ao mudar a data, tentar carregar o dia existente (se houver)
    final chave = DateFormat('yyyy-MM-dd').format(selecionada);
    final existente = _diasDespesca.firstWhere(
      (d) => d['data'] == chave,
      orElse: () => <String, dynamic>{},
    );

    setState(() {
      _dataRegistro = selecionada;
      _dataRegistroCtrl.text = DateFormat('dd/MM/yyyy').format(_dataRegistro);

      if (existente.isNotEmpty) {
        // Carrega registros e campos desse dia para edição
        final lotes = List<Map<String, dynamic>>.from(
          existente['lotes'] ?? const [],
        );

        final basquetasAntigas = List<Map<String, dynamic>>.from(
          existente['basquetas'] ?? [],
        );

        if (lotes.isEmpty && basquetasAntigas.isNotEmpty) {
          final pesoTotalDia = basquetasAntigas.fold<double>(
            0.0,
            (sum, b) => sum + ((b['peso'] as num?)?.toDouble() ?? 0.0),
          );
          final totalBasquetasDia = basquetasAntigas.length;
          _lotesDia = [
            {'pesoTotal': pesoTotalDia, 'totalBasquetas': totalBasquetasDia},
          ];
        } else {
          _lotesDia = lotes;
        }

        final biometriaDia =
            (existente['biometriaPesoMedio'] as num?)?.toDouble() ??
            (existente['biometria'] as num?)?.toDouble();
        _biometriaCtrl.text = biometriaDia != null
            ? _formatDouble(biometriaDia)
            : '';
        _observacoesCtrl.text = existente['observacoes']?.toString() ?? '';

        final respId = existente['responsavelId'] as String?;
        final respNome = existente['responsavel']?.toString() ?? '';
        _responsavelSelecionado = respId;
        _responsavelNomeAtual = respId != null
            ? (_funcionarios[respId] ?? respNome)
            : respNome;
        if (respId == null) {
          _responsavelCtrl.text = respNome;
        } else {
          _responsavelCtrl.clear();
        }

        // Número do dia: usar o armazenado ou calcular pela ordem
        _diaAtual =
            (existente['numeroDia'] as int?) ?? _calcularNumeroDia(selecionada);
      } else {
        // Novo dia selecionado: limpa campos de dia
        _lotesDia = [];
        _biometriaCtrl.clear();
        _observacoesCtrl.clear();
        // Mantém responsável atual selecionado/digitado
        _diaAtual = _calcularNumeroDia(selecionada);
      }
    });
  }

  int _calcularNumeroDia(DateTime data) {
    // Calcula posição 1-based considerando ordem cronológica das datas existentes
    final datas =
        _diasDespesca
            .map((d) => d['data']?.toString())
            .whereType<String>()
            .map((s) => DateFormat('yyyy-MM-dd').parse(s))
            .toList()
          ..sort();
    // Garante a inclusão da data selecionada
    datas.add(data);
    datas.sort();
    final pos = datas.indexWhere(
      (d) => d.year == data.year && d.month == data.month && d.day == data.day,
    );
    return (pos >= 0 ? pos : datas.length - 1) + 1;
  }

  void _sincronizarNumeroDiaOrdenando() {
    _diasDespesca.sort((a, b) {
      final sa = a['data']?.toString() ?? '';
      final sb = b['data']?.toString() ?? '';
      return sa.compareTo(sb);
    });
    for (var i = 0; i < _diasDespesca.length; i++) {
      _diasDespesca[i]['numeroDia'] = i + 1;
    }
    // Atualiza _diaAtual com base na data selecionada
    final chave = DateFormat('yyyy-MM-dd').format(_dataRegistro);
    final idx = _diasDespesca.indexWhere((d) => d['data'] == chave);
    if (idx >= 0)
      _diaAtual = _diasDespesca[idx]['numeroDia'] as int? ?? (idx + 1);
  }

  // Removido _salvarDiaAtual: agora auto-save ocorre em cada alteração relevante.

  Future<void> _finalizarDespesca() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finalizar Despesca'),
        content: const Text(
          'Tem certeza que deseja finalizar esta despesca? Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Garante numeração e ordenação
        setState(() {}); // status agora inferido diretamente no update
        _sincronizarNumeroDiaOrdenando();

        // Recalcula totais gerais com base em todos os dias em memória
        final pesoTotalGeral = _diasDespesca.fold<double>(
          0.0,
          (sum, dia) => sum + ((dia['pesoTotal'] as num?)?.toDouble() ?? 0.0),
        );
        final basquetasTotalGeral = _diasDespesca.fold<int>(
          0,
          (sum, dia) => sum + ((dia['totalBasquetas'] as num?)?.toInt() ?? 0),
        );

        await FirebaseFirestore.instance
            .collection('despescas')
            .doc(widget.despescaId)
            .update({
              'dias': _diasDespesca,
              'pesoTotal': pesoTotalGeral,
              'basquetasTotal': basquetasTotalGeral,
              'statusDespesca': 'concluida',
              'dataFinalizacao': Timestamp.now(),
              'ultimaAtualizacao': Timestamp.now(),
            });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Despesca finalizada com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
          await _oferecerEncerramentoCiclo();
          if (!mounted) return;
          // Volta para o dashboard mantendo o histórico para permitir voltar ao menu
          Navigator.pushReplacementNamed(context, '/despesca_dashboard');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao finalizar despesca: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _oferecerEncerramentoCiclo() async {
    final cicloId = _despescaAtual?['cicloId']?.toString();
    if (cicloId == null || cicloId.isEmpty) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Encerrar ciclo também?'),
        content: Text(
          'Deseja aproveitar e encerrar o ciclo do viveiro ${widget.codigoViveiro}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Agora não'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Encerrar ciclo'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await _encerrarCicloRelacionado(cicloId);
    }
  }

  Future<void> _encerrarCicloRelacionado(String cicloId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      String fechadoPor = 'Usuário';
      if (user != null) {
        final usuarioDoc = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user.uid)
            .get();
        fechadoPor =
            usuarioDoc.data()?['nome']?.toString() ??
            user.displayName ??
            user.email ??
            fechadoPor;
      }

      await FirebaseFirestore.instance
          .collection('ciclos')
          .doc(cicloId)
          .update({
            'encerrado': true,
            'dataEncerramento': Timestamp.now(),
            'fechadoPor': fechadoPor,
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ciclo encerrado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao encerrar ciclo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: AppScaffold(
        title: 'Despesca ${widget.codigoViveiro}',
        body: DegradeFundo(
          child: _despescaAtual == null
              ? const Center(child: CircularProgressIndicator())
              : _buildConteudo(),
        ),
      ),
    );
  }

  Widget _buildConteudo() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Informações da despesca
          _buildInfoDespesca(),
          const SizedBox(height: 16),

          // Responsável
          _buildResponsavel(),
          const SizedBox(height: 16),

          // Registro do dia
          _buildRegistroDia(),
          const SizedBox(height: 16),

          // Observações
          _buildObservacoes(),
          const SizedBox(height: 8),
          const Text(
            'Os dados do dia são salvos automaticamente ao adicionar/editar registros, biometria ou observações.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 24),

          // Botões
          _buildBotoes(),
        ],
      ),
    );
  }

  Widget _buildInfoDespesca() {
    final pesoTotal = _diasDespesca.fold<double>(
      0.0,
      (sum, dia) => sum + ((dia['pesoTotal'] as num?)?.toDouble() ?? 0.0),
    );
    final basquetasTotal = _diasDespesca.fold<int>(
      0,
      (sum, dia) => sum + ((dia['totalBasquetas'] as num?)?.toInt() ?? 0),
    );
    final biometrias = _diasDespesca
        .map(
          (d) =>
              (d['biometriaPesoMedio'] as num?)?.toDouble() ??
              (d['biometria'] as num?)?.toDouble(),
        )
        .whereType<double>()
        .toList();
    final biometriaMedia = biometrias.isNotEmpty
        ? (biometrias.reduce((a, b) => a + b) / biometrias.length)
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.water, color: Colors.blue.shade600),
                const SizedBox(width: 8),
                Text(
                  'Viveiro ${widget.codigoViveiro} - ${widget.nomeViveiro}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${_diasDespesca.length}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text('Dias de Despesca'),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${_formatDecimalPtBr(pesoTotal, decimals: 1)} kg',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text('Peso Total'),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '$basquetasTotal',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text('Basquetas Total'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (biometriaMedia != null)
              Row(
                children: [
                  Icon(Icons.scale, color: Colors.green.shade600),
                  const SizedBox(width: 8),
                  Text(
                    'Biometria média: ${_formatDouble(biometriaMedia, maxDecimals: 2)} g',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsavel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Responsável pela Despesca',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _responsavelSelecionado,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Selecionar Funcionário',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                    items: _funcionarios.entries.map((e) {
                      return DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() {
                      _responsavelSelecionado = v;
                      if (v != null) {
                        _responsavelNomeAtual = _funcionarios[v];
                        _responsavelCtrl.clear();
                      }
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                const Text('ou'),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _responsavelCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Digite o nome',
                      prefixIcon: Icon(Icons.edit),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => setState(() {
                      _responsavelSelecionado = null;
                      _responsavelNomeAtual = value.trim();
                    }),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegistroDia() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Registro do Dia',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            // Data do registro (permite lançar retroativo e digitação)
            TextFormField(
              controller: _dataRegistroCtrl,
              keyboardType: TextInputType.datetime,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(8),
                _DateInputFormatter(),
              ],
              decoration: InputDecoration(
                labelText: 'Data do registro (dd/MM/aaaa)',
                prefixIcon: const Icon(Icons.calendar_today),
                border: const OutlineInputBorder(),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_dataRegistroCtrl.text.isNotEmpty)
                      IconButton(
                        tooltip: 'Limpar',
                        icon: const Icon(Icons.clear, color: Colors.redAccent),
                        onPressed: () {
                          setState(() {
                            _dataRegistroCtrl.clear();
                          });
                        },
                      ),
                    IconButton(
                      tooltip: 'Selecionar no calendário',
                      icon: const Icon(Icons.edit_calendar),
                      onPressed: _selecionarDataRegistro,
                    ),
                  ],
                ),
              ),
              onChanged: (txt) {
                final d = _parseData(txt);
                if (d != null) {
                  _aplicarDataSelecionada(d);
                }
              },
            ),
            const SizedBox(height: 16),
            // Peso, basquetas e botão (auto-save ao adicionar)
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 600;

                final pesoField = TextFormField(
                  controller: _pesoLoteCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Peso total das Basquetas',
                    prefixIcon: Icon(Icons.monitor_weight),
                    border: OutlineInputBorder(),
                    suffixText: 'kg',
                  ),
                  inputFormatters: [_PtBrDecimalInputFormatter(maxDecimals: 2)],
                  onChanged: (txt) {
                    final peso = _parseDouble(txt);
                    if (peso != null && peso > 0) {
                      final sugestao = (peso / 15).round();
                      setState(() => _sugestaoBasquetas = sugestao);
                      if (!_basquetasFocus.hasFocus) {
                        _basquetasLoteCtrl.text = sugestao.toString();
                      }
                    } else {
                      setState(() => _sugestaoBasquetas = null);
                    }
                  },
                );

                void preencherBasquetas() {
                  final peso = _parseDouble(_pesoLoteCtrl.text);
                  if (peso == null || peso <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Informe um peso válido antes de calcular.',
                        ),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }
                  final calculado = (peso / 15)
                      .round()
                      .clamp(1, double.infinity)
                      .toInt();
                  setState(() {
                    _basquetasLoteCtrl.text = calculado.toString();
                    _sugestaoBasquetas = calculado;
                  });
                }

                final basquetasField = TextFormField(
                  controller: _basquetasLoteCtrl,
                  keyboardType: TextInputType.number,
                  focusNode: _basquetasFocus,
                  decoration: InputDecoration(
                    labelText: 'Quantidade de Basquetas',
                    prefixIcon: const Icon(Icons.inventory_2),
                    border: const OutlineInputBorder(),
                    helperText: _sugestaoBasquetas != null
                        ? 'Sugerido: $_sugestaoBasquetas (15 kg cada)'
                        : null,
                    suffixIcon: IconButton(
                      tooltip: 'Calcular basquetas (peso / 15)',
                      icon: const Icon(Icons.calculate_outlined),
                      onPressed: preencherBasquetas,
                    ),
                  ),
                );

                final addButton = ElevatedButton.icon(
                  onPressed: () {
                    final peso = _parseDouble(_pesoLoteCtrl.text);
                    final qtd = _parseInt(_basquetasLoteCtrl.text);
                    if (peso == null || peso <= 0 || qtd == null || qtd <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Informe peso e basquetas válidos para o registro.',
                          ),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }

                    // Adiciona registro ao dia atualmente selecionado
                    final dataStr = DateFormat(
                      'yyyy-MM-dd',
                    ).format(_dataRegistro);
                    // Recalcula totais do dia diretamente dos campos informados
                    final pesoTotalDia = peso;
                    final totalBasquetasDia = qtd;
                    final biometriaDia = _parseDouble(_biometriaCtrl.text);

                    String responsavelNome = (_responsavelNomeAtual ?? '')
                        .trim();
                    if (_responsavelSelecionado != null &&
                        responsavelNome.isEmpty) {
                      responsavelNome =
                          _funcionarios[_responsavelSelecionado!] ??
                          responsavelNome;
                    }
                    if (_responsavelSelecionado == null) {
                      responsavelNome = _responsavelCtrl.text.trim();
                    }

                    final idxExistente = _diasDespesca.indexWhere(
                      (d) => d['data'] == dataStr,
                    );
                    final mapDia = <String, dynamic>{
                      'data': dataStr,
                      'numeroDia': idxExistente >= 0
                          ? (_diasDespesca[idxExistente]['numeroDia'] as int? ??
                                _calcularNumeroDia(_dataRegistro))
                          : _calcularNumeroDia(_dataRegistro),
                      'totalBasquetas': totalBasquetasDia,
                      'pesoTotal': pesoTotalDia,
                      'lotes': <Map<String, dynamic>>[
                        {
                          'pesoTotal': pesoTotalDia,
                          'totalBasquetas': totalBasquetasDia,
                        },
                      ],
                      'observacoes': _observacoesCtrl.text.trim(),
                      'responsavel': responsavelNome,
                      'responsavelId': _responsavelSelecionado,
                      'atualizadoEm': Timestamp.now(),
                    };
                    if (biometriaDia != null) {
                      mapDia['biometriaPesoMedio'] = biometriaDia;
                    }

                    setState(() {
                      _lotesDia = [
                        {
                          'pesoTotal': pesoTotalDia,
                          'totalBasquetas': totalBasquetasDia,
                        },
                      ];
                      if (idxExistente >= 0) {
                        _diasDespesca[idxExistente] = mapDia;
                      } else {
                        _diasDespesca.add(mapDia);
                      }
                      _sincronizarNumeroDiaOrdenando();
                      _pesoLoteCtrl.clear();
                      _basquetasLoteCtrl.clear();
                      _biometriaCtrl.clear();
                      _sugestaoBasquetas = null;
                    });
                    _persistirDiasNoFirestore();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar registro'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                );

                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      pesoField,
                      const SizedBox(height: 12),
                      basquetasField,
                      const SizedBox(height: 12),
                      // Biometria logo abaixo das basquetas
                      TextFormField(
                        controller: _biometriaCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Biometria (peso médio)',
                          helperText:
                              'Opcional: peso médio dos camarões em gramas',
                          prefixIcon: Icon(Icons.scale),
                          suffixText: 'g',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) {
                          setState(() {});
                          _debounceBiometria?.cancel();
                          _debounceBiometria = Timer(
                            const Duration(milliseconds: 600),
                            () {
                              _atualizarDiaEmMemoria();
                            },
                          );
                        },
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return null;
                          }
                          final parsed = _parseDouble(value);
                          if (parsed == null || parsed <= 0) {
                            return 'Informe uma biometria válida';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      SizedBox(width: double.infinity, child: addButton),
                    ],
                  );
                }

                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: pesoField),
                        const SizedBox(width: 12),
                        Expanded(child: basquetasField),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Biometria logo abaixo das basquetas
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: double.infinity,
                        child: TextFormField(
                          controller: _biometriaCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Biometria (peso médio)',
                            helperText:
                                'Opcional: peso médio dos camarões em gramas',
                            prefixIcon: Icon(Icons.scale),
                            suffixText: 'g',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) {
                            setState(() {});
                            _debounceBiometria?.cancel();
                            _debounceBiometria = Timer(
                              const Duration(milliseconds: 600),
                              () {
                                _atualizarDiaEmMemoria();
                              },
                            );
                          },
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return null;
                            }
                            final parsed = _parseDouble(value);
                            if (parsed == null || parsed <= 0) {
                              return 'Informe uma biometria válida';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(alignment: Alignment.centerRight, child: addButton),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            // Lista de dias com biometria
            if (_diasDespesca.isNotEmpty) ...[
              const Text(
                'Dias da despesca',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...() {
                final diasOrdenados =
                    List<Map<String, dynamic>>.from(_diasDespesca)..sort(
                      (a, b) => (a['data']?.toString() ?? '').compareTo(
                        b['data']?.toString() ?? '',
                      ),
                    );

                return diasOrdenados.map((dia) {
                  final dataStr = dia['data']?.toString() ?? '';
                  String dataBonita;
                  try {
                    final parsed = DateFormat('yyyy-MM-dd').parse(dataStr);
                    dataBonita = DateFormat('dd/MM/yyyy').format(parsed);
                  } catch (_) {
                    dataBonita = dataStr;
                  }
                  final peso = (dia['pesoTotal'] as num?)?.toDouble() ?? 0.0;
                  final basq = (dia['totalBasquetas'] as num?)?.toInt() ?? 0;
                  final bio =
                      (dia['biometriaPesoMedio'] as num?)?.toDouble() ??
                      (dia['biometria'] as num?)?.toDouble();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$dataBonita • ${_formatDecimalPtBr(peso, decimals: 1)} kg • $basq basquetas',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          bio != null
                              ? 'Bio: ${_formatDouble(bio, maxDecimals: 2)} g'
                              : 'Bio: --',
                          style: const TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(width: 4),
                        PopupMenuButton<String>(
                          tooltip: 'Opções do dia',
                          icon: const Icon(Icons.more_vert),
                          onSelected: (value) {
                            if (value == 'editar') {
                              try {
                                final parsed = DateFormat(
                                  'yyyy-MM-dd',
                                ).parse(dataStr);
                                _aplicarDataSelecionada(parsed);
                              } catch (_) {}
                            } else if (value == 'excluir') {
                              _excluirDia(dataStr);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'editar',
                              child: ListTile(
                                leading: Icon(Icons.edit_note_outlined),
                                title: Text('Editar'),
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'excluir',
                              child: ListTile(
                                leading: Icon(
                                  Icons.delete_forever_outlined,
                                  color: Colors.redAccent,
                                ),
                                title: Text('Excluir'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList();
              }(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildObservacoes() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Observações do Dia',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _observacoesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Observações sobre o dia de despesca',
                prefixIcon: Icon(Icons.note),
                border: OutlineInputBorder(),
                hintText: 'Ex: Qualidade excelente, camarões grandes...',
              ),
              onChanged: (_) {
                _debounceObservacoes?.cancel();
                _debounceObservacoes = Timer(
                  const Duration(milliseconds: 600),
                  () {
                    _atualizarDiaEmMemoria();
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotoes() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _finalizarDespesca,
        icon: const Icon(Icons.check),
        label: const Text('Finalizar Despesca'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          padding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  double? _parseDouble(String? value) {
    if (value == null) return null;
    var sanitized = value.trim();
    if (sanitized.isEmpty) return null;
    if (sanitized.contains(',') && sanitized.contains('.')) {
      sanitized = sanitized.replaceAll('.', '');
    } else if (sanitized.contains('.') && !sanitized.contains(',')) {
      // Trata ponto como separador de milhar (ex: 5.310 -> 5310)
      sanitized = sanitized.replaceAll('.', '');
    }
    sanitized = sanitized.replaceAll(',', '.');
    return double.tryParse(sanitized);
  }

  int? _parseInt(String? value) {
    final parsed = _parseDouble(value);
    if (parsed == null || parsed % 1 != 0) {
      return null;
    }
    return parsed.toInt();
  }

  String _formatDouble(double value, {int maxDecimals = 2}) {
    final isInt = value.truncateToDouble() == value;
    final decimals = isInt ? 0 : maxDecimals;
    final fixed = value.toStringAsFixed(decimals);
    return fixed.replaceAll('.', ',');
  }

  String _formatDecimalPtBr(num value, {int decimals = 1}) {
    final f = NumberFormat.decimalPattern('pt_BR')
      ..minimumFractionDigits = decimals
      ..maximumFractionDigits = decimals;
    return f.format(value);
  }

  DateTime? _parseData(String input) {
    final t = input.trim();
    final re = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$');
    final m = re.firstMatch(t);
    if (m == null) return null;
    final d = int.tryParse(m.group(1)!);
    final mth = int.tryParse(m.group(2)!);
    final y = int.tryParse(m.group(3)!);
    if (d == null || mth == null || y == null) return null;
    try {
      final parsed = DateTime(y, mth, d);
      if (parsed.day == d && parsed.month == mth && parsed.year == y) {
        return parsed;
      }
    } catch (_) {}
    return null;
  }

  // --- Novo: suporte a edição e exclusão de dias/lotes --- //

  void _atualizarDiaEmMemoria() {
    final dataStr = DateFormat('yyyy-MM-dd').format(_dataRegistro);
    final idxExistente = _diasDespesca.indexWhere((d) => d['data'] == dataStr);
    if (idxExistente < 0 && _lotesDia.isEmpty) {
      // Ainda não existe registro para a data e não há dados de peso/basquetas.
      // Evita criar dia automaticamente somente por digitar biometria/observações.
      return;
    }
    final pesoTotalDia = _lotesDia.fold<double>(
      0.0,
      (sum, l) => sum + ((l['pesoTotal'] as num?)?.toDouble() ?? 0.0),
    );
    final totalBasquetasDia = _lotesDia.fold<int>(
      0,
      (sum, l) => sum + ((l['totalBasquetas'] as num?)?.toInt() ?? 0),
    );
    final biometriaDia = _parseDouble(_biometriaCtrl.text);
    String responsavelNome = (_responsavelNomeAtual ?? '').trim();
    if (_responsavelSelecionado != null && responsavelNome.isEmpty) {
      responsavelNome =
          _funcionarios[_responsavelSelecionado!] ?? responsavelNome;
    }
    if (_responsavelSelecionado == null) {
      responsavelNome = _responsavelCtrl.text.trim();
    }
    final mapDia = <String, dynamic>{
      'data': dataStr,
      'numeroDia': idxExistente >= 0
          ? (_diasDespesca[idxExistente]['numeroDia'] as int? ??
                _calcularNumeroDia(_dataRegistro))
          : _calcularNumeroDia(_dataRegistro),
      'totalBasquetas': totalBasquetasDia,
      'pesoTotal': pesoTotalDia,
      'lotes': List<Map<String, dynamic>>.from(_lotesDia),
      'observacoes': _observacoesCtrl.text.trim(),
      'responsavel': responsavelNome,
      'responsavelId': _responsavelSelecionado,
      'atualizadoEm': Timestamp.now(),
    };
    if (biometriaDia != null) {
      mapDia['biometriaPesoMedio'] = biometriaDia;
    }
    setState(() {
      if (idxExistente >= 0) {
        _diasDespesca[idxExistente] = mapDia;
      } else {
        _diasDespesca.add(mapDia);
      }
      _sincronizarNumeroDiaOrdenando();
    });
    _persistirDiasNoFirestore();
  }

  void _persistirDiasNoFirestore() async {
    final pesoTotalGeral = _diasDespesca.fold<double>(
      0.0,
      (sum, dia) => sum + ((dia['pesoTotal'] as num?)?.toDouble() ?? 0.0),
    );
    final basquetasTotalGeral = _diasDespesca.fold<int>(
      0,
      (sum, dia) => sum + ((dia['totalBasquetas'] as num?)?.toInt() ?? 0),
    );
    try {
      await FirebaseFirestore.instance
          .collection('despescas')
          .doc(widget.despescaId)
          .update({
            'dias': _diasDespesca,
            'pesoTotal': pesoTotalGeral,
            'basquetasTotal': basquetasTotalGeral,
            'ultimaAtualizacao': Timestamp.now(),
          });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar despesca: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _excluirDia(String dataStr) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Dia'),
        content: Text('Remover definitivamente o dia $dataStr da despesca?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    setState(() {
      _diasDespesca.removeWhere((d) => d['data'] == dataStr);
      if (dataStr == DateFormat('yyyy-MM-dd').format(_dataRegistro)) {
        final hoje = DateTime.now();
        _dataRegistro = hoje;
        _dataRegistroCtrl.text = DateFormat('dd/MM/yyyy').format(hoje);
        _lotesDia.clear();
        _biometriaCtrl.clear();
        _observacoesCtrl.clear();
      }
      _sincronizarNumeroDiaOrdenando();
    });
    _persistirDiasNoFirestore();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dia excluído.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // Edição de lotes não é mais usada no fluxo atual

  @override
  void dispose() {
    _debounceBiometria?.cancel();
    _debounceObservacoes?.cancel();
    _observacoesCtrl.dispose();
    _responsavelCtrl.dispose();
    _pesoTotalDiaCtrl.dispose();
    _quantidadeBasquetasCtrl.dispose();
    _biometriaCtrl.dispose();
    _pesoLoteCtrl.dispose();
    _basquetasLoteCtrl.dispose();
    _dataRegistroCtrl.dispose();
    _basquetasFocus.dispose();
    super.dispose();
  }
}

class _DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length && i < 8; i++) {
      buffer.write(digits[i]);
      if (i == 1 || i == 3) buffer.write('/');
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
      composing: TextRange.empty,
    );
  }
}

class _PtBrDecimalInputFormatter extends TextInputFormatter {
  _PtBrDecimalInputFormatter({this.maxDecimals = 2});
  final int maxDecimals;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text;
    text = text.replaceAll('.', ',');
    text = text.replaceAll(RegExp(r'[^0-9,]'), '');

    final commaIndex = text.indexOf(',');
    String intPart;
    String fracPart = '';
    if (commaIndex >= 0) {
      intPart = text.substring(0, commaIndex).replaceAll(RegExp(r'[^0-9]'), '');
      fracPart = text
          .substring(commaIndex + 1)
          .replaceAll(RegExp(r'[^0-9]'), '');
      if (maxDecimals >= 0 && fracPart.length > maxDecimals) {
        fracPart = fracPart.substring(0, maxDecimals);
      }
    } else {
      intPart = text.replaceAll(RegExp(r'[^0-9]'), '');
    }

    final formattedInt = _formatThousands(intPart);
    final result = commaIndex >= 0
        ? (fracPart.isEmpty ? '$formattedInt,' : '$formattedInt,$fracPart')
        : formattedInt;

    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
      composing: TextRange.empty,
    );
  }

  String _formatThousands(String digits) {
    if (digits.isEmpty) return '';
    final buf = StringBuffer();
    var count = 0;
    for (int i = digits.length - 1; i >= 0; i--) {
      buf.write(digits[i]);
      count++;
      if (count == 3 && i != 0) {
        buf.write('.');
        count = 0;
      }
    }
    return buf.toString().split('').reversed.join();
  }
}
