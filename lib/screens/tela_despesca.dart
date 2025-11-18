import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  final _pesoLoteCtrl = TextEditingController();
  final _basquetasLoteCtrl = TextEditingController();

  // Data selecionada para o registro do dia (permite lançar retroativo)
  DateTime _dataRegistro = DateTime.now();

  // Estado da despesca
  Map<String, dynamic>? _despescaAtual;
  List<Map<String, dynamic>> _diasDespesca = [];
  List<Map<String, dynamic>> _lotesDia = [];
  int _diaAtual = 1;
  String _statusDespesca = 'em_andamento';
  String? _responsavelSelecionado;
  String? _responsavelNomeAtual;
  Map<String, String> _funcionarios = {};
  final bool _salvando = false;

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
      print('Erro ao carregar funcionários: $e');
    }
  }

  Future<void> _carregarDespescaAtual() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('despescas')
          .doc(widget.despescaId)
          .get();

      if (!doc.exists) {
        return;
      }

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

      // Suporte a múltiplos lotes por dia
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

      // Fallback para registros antigos sem "lotes":
      // se não houver lotes, mas houver totais/basquetas antigas,
      // cria um lote único para manter compatibilidade de edição
      if (lotes.isEmpty &&
          (pesoTotalDia != null || totalBasquetasDia != null)) {
        final loteUnico = <String, dynamic>{
          'pesoTotal': (pesoTotalDia ?? 0.0),
          'totalBasquetas': (totalBasquetasDia ?? 0),
        };
        _lotesDia = [loteUnico];
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
        _statusDespesca = data['statusDespesca'] ?? 'em_andamento';
        _diasDespesca = dias;
        _diaAtual = diaHoje.isNotEmpty
            ? (diaHoje['numeroDia'] as int? ?? dias.length)
            : dias.length + 1;
        // Por padrão, editar/lançar para a data de hoje
        _dataRegistro = DateTime.now();
        _responsavelSelecionado = responsavelId;
        _responsavelNomeAtual = responsavelNome;
      });

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

    // Ao mudar a data, tentar carregar o dia existente (se houver)
    final chave = DateFormat('yyyy-MM-dd').format(selecionada);
    final existente = _diasDespesca.firstWhere(
      (d) => d['data'] == chave,
      orElse: () => <String, dynamic>{},
    );

    setState(() {
      _dataRegistro = selecionada;

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

  Future<void> _salvarDiaAtual() async {
    // Validação: é necessário pelo menos um lote no dia
    if (_lotesDia.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Adicione ao menos um lote para salvar o dia.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Valida biometria (se fornecida) via form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      // Usa a data selecionada (padrão: hoje)
      final dataSelecionadaStr = DateFormat('yyyy-MM-dd').format(_dataRegistro);
      // Calcula totais do dia com base nos lotes
      final pesoTotalDia = _lotesDia.fold<double>(
        0.0,
        (sum, lote) => sum + ((lote['pesoTotal'] as num?)?.toDouble() ?? 0.0),
      );
      final totalBasquetasDia = _lotesDia.fold<int>(
        0,
        (sum, lote) => sum + ((lote['totalBasquetas'] as num?)?.toInt() ?? 0),
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

      final diaAtual = <String, dynamic>{
        'data': dataSelecionadaStr,
        'numeroDia': _diaAtual,
        'totalBasquetas': totalBasquetasDia,
        'pesoTotal': pesoTotalDia,
        'lotes': _lotesDia,
        'observacoes': _observacoesCtrl.text.trim(),
        'responsavel': responsavelNome,
        'responsavelId': _responsavelSelecionado,
        'salvoEm': Timestamp.now(),
      };

      if (biometriaDia != null) {
        diaAtual['biometriaPesoMedio'] = biometriaDia;
      }

      final indexDiaExistente = _diasDespesca.indexWhere(
        (dia) => dia['data'] == dataSelecionadaStr,
      );

      setState(() {
        if (indexDiaExistente >= 0) {
          _diasDespesca[indexDiaExistente] = diaAtual;
        } else {
          _diasDespesca.add(diaAtual);
        }
        _responsavelNomeAtual = responsavelNome;
      });

      if (_responsavelSelecionado == null) {
        _responsavelCtrl.text = responsavelNome;
      }

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
            'statusDespesca': _statusDespesca,
            'ultimaAtualizacao': Timestamp.now(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Dia salvo com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

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
        setState(() => _statusDespesca = 'concluida');
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
                        'Dia $_diaAtual',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text('Dia Atual'),
                    ],
                  ),
                ),
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
                        '${_formatDouble(pesoTotal, maxDecimals: 1)} kg',
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
    final pesoTotalDia = _lotesDia.fold<double>(
      0.0,
      (sum, lote) => sum + ((lote['pesoTotal'] as num?)?.toDouble() ?? 0.0),
    );
    final totalBasquetasDia = _lotesDia.fold<int>(
      0,
      (sum, lote) => sum + ((lote['totalBasquetas'] as num?)?.toInt() ?? 0),
    );
    final biometriaDia = _parseDouble(_biometriaCtrl.text);

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
            // Data do registro (permite lançar retroativo)
            InkWell(
              onTap: _selecionarDataRegistro,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Data do registro',
                  prefixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Text(
                        DateFormat('dd/MM/yyyy').format(_dataRegistro),
                        style: const TextStyle(fontSize: 16),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _selecionarDataRegistro,
                        icon: const Icon(Icons.edit_calendar),
                        label: const Text('Alterar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Resumo do dia
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '${_formatDouble(pesoTotalDia, maxDecimals: 1)} kg',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text('Peso Hoje'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '$totalBasquetasDia',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text('Basquetas Hoje'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          biometriaDia != null
                              ? '${_formatDouble(biometriaDia, maxDecimals: 2)} g'
                              : '--',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text('Biometria'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Adicionar lote
            Row(
              children: [
                Expanded(
                  child: TextFormField(
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
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _basquetasLoteCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Quantidade de Basquetas',
                      prefixIcon: Icon(Icons.inventory_2),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
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
                    // Atualiza lista da UI do dia
                    setState(() {
                      _lotesDia.add({'pesoTotal': peso, 'totalBasquetas': qtd});
                      _pesoLoteCtrl.clear();
                      _basquetasLoteCtrl.clear();
                    });

                    // Recalcula totais do dia e reflete em _diasDespesca (memória)
                    final pesoTotalDia = _lotesDia.fold<double>(
                      0.0,
                      (sum, l) =>
                          sum + ((l['pesoTotal'] as num?)?.toDouble() ?? 0.0),
                    );
                    final totalBasquetasDia = _lotesDia.fold<int>(
                      0,
                      (sum, l) =>
                          sum + ((l['totalBasquetas'] as num?)?.toInt() ?? 0),
                    );
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
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar Registro'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Lista de lotes
            if (_lotesDia.isNotEmpty) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Registros adicionados',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ..._lotesDia.asMap().entries.map((entry) {
                    final index = entry.key + 1;
                    final lote = entry.value;
                    final peso = (lote['pesoTotal'] as num?)?.toDouble() ?? 0.0;
                    final qtd = (lote['totalBasquetas'] as num?)?.toInt() ?? 0;
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
                              'Registro $index: ${_formatDouble(peso, maxDecimals: 1)} kg • $qtd basquetas',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remover registro',
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _lotesDia.removeAt(entry.key);
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
              const SizedBox(height: 8),
            ],
            // Biometria
            TextFormField(
              controller: _biometriaCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Biometria (peso médio)',
                helperText: 'Opcional: peso médio dos camarões em gramas',
                prefixIcon: Icon(Icons.scale),
                suffixText: 'g',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotoes() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _salvando ? null : _salvarDiaAtual,
            icon: _salvando
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(_salvando ? 'Salvando...' : 'Salvar Dia'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.all(16),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _finalizarDespesca,
            icon: const Icon(Icons.check),
            label: const Text('Finalizar Despesca'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  double? _parseDouble(String? value) {
    if (value == null) return null;
    var sanitized = value.trim();
    if (sanitized.isEmpty) return null;
    if (sanitized.contains(',') && sanitized.contains('.')) {
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

  @override
  void dispose() {
    _observacoesCtrl.dispose();
    _responsavelCtrl.dispose();
    _pesoTotalDiaCtrl.dispose();
    _quantidadeBasquetasCtrl.dispose();
    _biometriaCtrl.dispose();
    _pesoLoteCtrl.dispose();
    _basquetasLoteCtrl.dispose();
    super.dispose();
  }
}
