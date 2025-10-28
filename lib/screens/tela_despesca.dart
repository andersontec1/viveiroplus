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

  // Estado da despesca
  Map<String, dynamic>? _despescaAtual;
  List<Map<String, dynamic>> _diasDespesca = [];
  List<Map<String, dynamic>> _basquetas = [];
  String _buscaBasqueta = '';
  int _diaAtual = 1;
  String _statusDespesca = 'em_andamento';
  String? _responsavelSelecionado;
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
      setState(() => _funcionarios = mapa);
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

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _despescaAtual = data;
          _statusDespesca = data['statusDespesca'] ?? 'em_andamento';
          _diasDespesca = List<Map<String, dynamic>>.from(data['dias'] ?? []);

          // Verificar se hoje já tem registro
          final hoje = DateFormat('yyyy-MM-dd').format(DateTime.now());
          final diaHoje = _diasDespesca.firstWhere(
            (dia) => dia['data'] == hoje,
            orElse: () => <String, dynamic>{},
          );

          if (diaHoje.isNotEmpty) {
            // Já existe registro de hoje, carregar basquetas
            _basquetas = List<Map<String, dynamic>>.from(
              diaHoje['basquetas'] ?? [],
            );
            _diaAtual = diaHoje['numeroDia'] ?? (_diasDespesca.length);
          } else {
            // Novo dia, começar do zero com numeração sequencial
            _diaAtual = _diasDespesca.length + 1;
            _basquetas = [];
          }
        });
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

  Future<void> _salvarDiaAtual() async {
    if (_basquetas.isEmpty) return;

    try {
      final hoje = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final pesoTotalDia = _basquetas.fold(
        0.0,
        (sum, b) => sum + (b['peso'] ?? 0.0),
      );

      // Dados do dia atual
      final diaAtual = {
        'data': hoje,
        'numeroDia': _diaAtual,
        'basquetas': _basquetas,
        'totalBasquetas': _basquetas.length,
        'pesoTotal': pesoTotalDia,
        'observacoes': _observacoesCtrl.text.trim(),
        'responsavel': _responsavelSelecionado != null
            ? _funcionarios[_responsavelSelecionado!]
            : _responsavelCtrl.text.trim(),
        'responsavelId': _responsavelSelecionado,
        'salvoEm': Timestamp.now(),
      };

      // Atualizar ou adicionar o dia na lista
      final indexDiaExistente = _diasDespesca.indexWhere(
        (dia) => dia['data'] == hoje,
      );
      if (indexDiaExistente >= 0) {
        _diasDespesca[indexDiaExistente] = diaAtual;
      } else {
        _diasDespesca.add(diaAtual);
      }

      // Calcular totais gerais
      final pesoTotalGeral = _diasDespesca.fold(
        0.0,
        (sum, dia) => sum + (dia['pesoTotal'] ?? 0.0),
      );
      final basquetasTotalGeral = _diasDespesca.fold(
        0,
        (sum, dia) => sum + (dia['totalBasquetas'] as int? ?? 0),
      );

      // Salvar no Firebase
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

  Future<void> _adicionarBasqueta() async {
    final proximoNumero = _basquetas.length + 1;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _DialogBasqueta(numeroBasqueta: proximoNumero),
    );

    if (result != null) {
      setState(() {
        _basquetas.add(result);
      });
      await _salvarDiaAtual(); // Salvar automaticamente
    }
  }

  Future<void> _editarBasqueta(int index) async {
    final basqueta = _basquetas[index];
    final numeroBasqueta = basqueta['numero'] ?? (index + 1);
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _DialogBasqueta(
        basquetaInicial: basqueta,
        numeroBasqueta: numeroBasqueta,
      ),
    );

    if (result != null) {
      setState(() {
        _basquetas[index] = result;
      });
      await _salvarDiaAtual(); // Salvar automaticamente
    }
  }

  Future<void> _excluirBasqueta(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Deseja excluir a basqueta ${index + 1}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _basquetas.removeAt(index);
      });
      await _salvarDiaAtual(); // Salvar automaticamente
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
      setState(() => _statusDespesca = 'concluida');
      await _salvarDiaAtual();

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/despesca_dashboard',
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Despesca ${widget.codigoViveiro}',
      body: DegradeFundo(
        child: _despescaAtual == null
            ? const Center(child: CircularProgressIndicator())
            : _buildConteudo(),
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

          // Basquetas
          _buildSecaoBasquetas(),
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
    final pesoTotal = _diasDespesca.fold(
      0.0,
      (sum, dia) => sum + (dia['pesoTotal'] ?? 0.0),
    );
    final basquetasTotal = _diasDespesca.fold(
      0,
      (sum, dia) => sum + (dia['totalBasquetas'] as int? ?? 0),
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
                        '${pesoTotal.toStringAsFixed(1)} kg',
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
                    onChanged: (v) =>
                        setState(() => _responsavelSelecionado = v),
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
                    onChanged: (_) =>
                        setState(() => _responsavelSelecionado = null),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecaoBasquetas() {
    double totalPeso = _basquetas.fold(
      0.0,
      (sum, basqueta) => sum + (basqueta['peso'] ?? 0.0),
    );
    int totalQuantidade = _basquetas.length;

    // Filtrar basquetas baseado na busca
    List<Map<String, dynamic>> basquetasFiltradas = _basquetas.where((
      basqueta,
    ) {
      if (_buscaBasqueta.isEmpty) return true;
      final numeroBasqueta = basqueta['numero']?.toString() ?? '';
      return numeroBasqueta.contains(_buscaBasqueta);
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Basquetas do Dia',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _adicionarBasqueta,
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Campo de busca (só mostra se houver basquetas)
            if (_basquetas.isNotEmpty) ...[
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Buscar por número da basqueta',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => _buscaBasqueta = value),
              ),
              const SizedBox(height: 12),
            ],

            // Totais do dia
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        '$totalQuantidade',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text('Basquetas Hoje'),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        '${totalPeso.toStringAsFixed(1)} kg',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text('Peso Hoje'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Lista de basquetas
            if (_basquetas.isNotEmpty) ...[
              if (basquetasFiltradas.isNotEmpty)
                ...basquetasFiltradas.map((basqueta) {
                  final index = _basquetas.indexOf(basqueta);
                  final numeroBasqueta = basqueta['numero'] ?? (index + 1);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade600,
                        child: Text(
                          '#$numeroBasqueta',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      title: Text(
                        'Basqueta #$numeroBasqueta',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Peso: ${basqueta['peso']} kg'),
                          if (basqueta['observacoes'] != null &&
                              basqueta['observacoes'].toString().isNotEmpty)
                            Text(
                              'Obs: ${basqueta['observacoes']}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _editarBasqueta(index),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _excluirBasqueta(index),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

              if (basquetasFiltradas.isEmpty && _buscaBasqueta.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Nenhuma basqueta encontrada com o número "$_buscaBasqueta"',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ),
            ],

            if (_basquetas.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                child: const Center(
                  child: Text(
                    'Nenhuma basqueta adicionada ainda.\nClique em "Adicionar" para começar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
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

  @override
  void dispose() {
    _observacoesCtrl.dispose();
    _responsavelCtrl.dispose();
    super.dispose();
  }
}

// Dialog para adicionar/editar basqueta
class _DialogBasqueta extends StatefulWidget {
  const _DialogBasqueta({this.basquetaInicial, required this.numeroBasqueta});
  final Map<String, dynamic>? basquetaInicial;
  final int numeroBasqueta;

  @override
  State<_DialogBasqueta> createState() => _DialogBasquetaState();
}

class _DialogBasquetaState extends State<_DialogBasqueta> {
  final _formKey = GlobalKey<FormState>();
  final _pesoCtrl = TextEditingController();
  final _observacoesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.basquetaInicial != null) {
      _pesoCtrl.text = widget.basquetaInicial!['peso']?.toString() ?? '';
      _observacoesCtrl.text = widget.basquetaInicial!['observacoes'] ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.basquetaInicial == null
            ? 'Basqueta #${widget.numeroBasqueta}'
            : 'Editar Basqueta #${widget.numeroBasqueta}',
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.tag, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Número da Basqueta: ${widget.numeroBasqueta}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _pesoCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Peso da Basqueta',
                prefixIcon: Icon(Icons.monitor_weight),
                border: OutlineInputBorder(),
                suffixText: 'kg',
                helperText: 'Registre o peso exato desta basqueta',
              ),
              validator: (value) {
                if (value == null || value.isEmpty)
                  return 'Informe o peso da basqueta';
                if (double.tryParse(value) == null)
                  return 'Informe um peso válido';
                if (double.parse(value) <= 0)
                  return 'O peso deve ser maior que zero';
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _observacoesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Observações (opcional)',
                prefixIcon: Icon(Icons.note),
                border: OutlineInputBorder(),
                hintText:
                    'Ex: Camarões de tamanho grande, qualidade excelente...',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _salvar,
          child: Text(widget.basquetaInicial == null ? 'Adicionar' : 'Salvar'),
        ),
      ],
    );
  }

  void _salvar() {
    if (_formKey.currentState!.validate()) {
      final basqueta = {
        'numero': widget.numeroBasqueta,
        'peso': double.parse(_pesoCtrl.text),
        'observacoes': _observacoesCtrl.text,
        'adicionadaEm': Timestamp.now(),
      };

      Navigator.pop(context, basqueta);
    }
  }

  @override
  void dispose() {
    _pesoCtrl.dispose();
    _observacoesCtrl.dispose();
    super.dispose();
  }
}
