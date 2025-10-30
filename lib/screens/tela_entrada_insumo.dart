import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/degrade_fundo.dart';
import '../helpers/estoque_helper.dart';

class TelaEntradaInsumo extends StatefulWidget {
  const TelaEntradaInsumo({super.key, this.insumoIdPreSelecionado});
  final String? insumoIdPreSelecionado;

  @override
  State<TelaEntradaInsumo> createState() => _TelaEntradaInsumoState();
}

class _TelaEntradaInsumoState extends State<TelaEntradaInsumo> {
  final _formKey = GlobalKey<FormState>();
  String? _insumoId;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _insumos = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _lotesAtivos = [];
  bool _carregandoLotes = false;
  final _quantidadeCtrl = TextEditingController();
  final _loteCtrl = TextEditingController();
  final _fornecedorCtrl = TextEditingController();
  final _nfCtrl = TextEditingController();
  final _localCtrl = TextEditingController();
  final _precoCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();
  DateTime? _validade;
  DateTime? _fabricacao;
  bool _salvando = false;
  List<Map<String, dynamic>> _distribuicaoPorPonto = [];

  @override
  void initState() {
    super.initState();
    _carregarInsumos();
  }

  Future<void> _carregarInsumos() async {
    final snap = await FirebaseFirestore.instance
        .collection('insumos')
        .orderBy('nome')
        .get();
    setState(() {
      _insumos = snap.docs;
      if (widget.insumoIdPreSelecionado != null) {
        _insumoId = widget.insumoIdPreSelecionado;
      } else if (_insumos.isNotEmpty) {
        _insumoId = _insumos.first.id;
      } else {
        _insumoId = null;
      }
    });
    if (_insumoId != null) _carregarLotesAtivos();
  }

  Future<void> _carregarLotesAtivos() async {
    if (_insumoId == null) return;
    setState(() => _carregandoLotes = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('lotes_insumo')
          .where('insumoId', isEqualTo: _insumoId)
          .where('status', isEqualTo: 'ativo')
          .get();
      final docs = snap.docs.toList();
      docs.sort((a, b) {
        final av = (a.data()['validade'] as Timestamp?)?.toDate();
        final bv = (b.data()['validade'] as Timestamp?)?.toDate();
        if (av == null && bv == null) return 0;
        if (av == null) return 1;
        if (bv == null) return -1;
        return av.compareTo(bv);
      });
      setState(() => _lotesAtivos = docs);
    } finally {
      if (mounted) setState(() => _carregandoLotes = false);
    }
  }

  void _gerarCodigoLote() {
    if (_insumoId == null) return;
    final insumo = _insumos.firstWhere((d) => d.id == _insumoId).data();
    final prefix = (insumo['nome'] ?? 'LOT')
        .toString()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final abreviado = prefix.length > 4 ? prefix.substring(0, 4) : prefix;
    final now = DateTime.now();
    final codigo =
        '$abreviado-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    setState(() => _loteCtrl.text = codigo);
  }

  Future<void> _abrirEditarLoteDialog(
    String loteId,
    Map<String, dynamic> dados,
  ) async {
    final qtdCtrl = TextEditingController(
      text: (dados['quantidade'] ?? '').toString(),
    );
    final loteCtrl = TextEditingController(
      text: (dados['lote'] ?? '').toString(),
    );
    final precoCtrl = TextEditingController(
      text: (dados['precoUnitario'] ?? '').toString(),
    );
    DateTime? validade = (dados['validade'] as Timestamp?)?.toDate();
    DateTime? fabricacao = (dados['fabricacao'] as Timestamp?)?.toDate();
    final localCtrl = TextEditingController(
      text: (dados['localArmazenamento'] ?? '').toString(),
    );
    final fornecedorCtrl = TextEditingController(
      text: (dados['fornecedor'] ?? '').toString(),
    );
    final obsCtrl = TextEditingController(
      text: (dados['observacoes'] ?? '').toString(),
    );

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Editar lote'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: qtdCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Quantidade'),
                ),
                TextField(
                  controller: loteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Código do lote',
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final d = await showDatePicker(
                            context: ctx,
                            initialDate: fabricacao ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (d != null) setStateDialog(() => fabricacao = d);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Fabricação',
                          ),
                          child: Text(
                            fabricacao == null
                                ? 'Selecionar'
                                : '${fabricacao!.day.toString().padLeft(2, '0')}/${fabricacao!.month.toString().padLeft(2, '0')}/${fabricacao!.year}',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final d = await showDatePicker(
                            context: ctx,
                            initialDate: validade ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (d != null) setStateDialog(() => validade = d);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Validade',
                          ),
                          child: Text(
                            validade == null
                                ? 'Selecionar'
                                : '${validade!.day.toString().padLeft(2, '0')}/${validade!.month.toString().padLeft(2, '0')}/${validade!.year}',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                TextField(
                  controller: fornecedorCtrl,
                  decoration: const InputDecoration(labelText: 'Fornecedor'),
                ),
                TextField(
                  controller: precoCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Preço unitário',
                  ),
                ),
                TextField(
                  controller: localCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Local armazen.',
                  ),
                ),
                TextField(
                  controller: obsCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Observações'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final novaQtd = num.tryParse(
                    qtdCtrl.text.replaceAll(',', '.'),
                  );
                  final novoPreco = double.tryParse(
                    precoCtrl.text.replaceAll(',', '.'),
                  );
                  await EstoqueHelper.atualizarLote(
                    loteId: loteId,
                    novaQuantidade: novaQtd,
                    novaValidade: validade,
                    novaFabricacao: fabricacao,
                    novoFornecedor: fornecedorCtrl.text.trim(),
                    novoCodigoLote: loteCtrl.text.trim(),
                    novoPrecoUnitario: novoPreco,
                    novoLocalArmazenamento: localCtrl.text.trim(),
                    novasObservacoes: obsCtrl.text.trim(),
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Lote atualizado.')),
                    );
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Erro: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_insumoId == null) return;
    setState(() => _salvando = true);
    try {
      final qtd =
          double.tryParse(_quantidadeCtrl.text.replaceAll(',', '.')) ?? 0;
      final insumo = _insumos.firstWhere((d) => d.id == _insumoId).data();
      final tipoStr = (insumo['tipo'] ?? '').toString().toLowerCase();
      final isRacao = tipoStr == 'ração' || tipoStr == 'racao';

      // Validações obrigatórias para Ração
      if (isRacao) {
        if (_validade == null) {
          throw Exception('Validade é obrigatória para ração.');
        }
        if (_distribuicaoPorPonto.isEmpty) {
          throw Exception(
            'Distribuição por ponto de entrega é obrigatória para ração.',
          );
        }
      }

      // Validação da distribuição por ponto (quando informada ou obrigatória)
      if (_distribuicaoPorPonto.isNotEmpty) {
        final soma = _distribuicaoPorPonto
            .map((e) => (e['quantidade'] ?? 0) as num)
            .fold<num>(0, (a, b) => a + b);
        if ((soma - qtd).abs() > 0.0001) {
          throw Exception(
            'A soma das quantidades por ponto (${soma.toStringAsFixed(2)} kg) precisa ser igual à quantidade total ($qtd kg).',
          );
        }
      }
      // Validação de duplicidade de código de lote (se informado)
      final codigoLote = _loteCtrl.text.trim();
      if (codigoLote.isNotEmpty) {
        final dup = await FirebaseFirestore.instance
            .collection('lotes_insumo')
            .where('insumoId', isEqualTo: _insumoId)
            .where('lote', isEqualTo: codigoLote)
            .limit(1)
            .get();
        if (dup.docs.isNotEmpty) {
          throw Exception(
            'Já existe um lote com este código para este insumo. Altere ou gere outro.',
          );
        }
      }
      await EstoqueHelper.registrarEntradaLote(
        insumoId: _insumoId!,
        quantidade: qtd,
        unidade: insumo['unidade'],
        lote: _loteCtrl.text.trim(),
        validade: _validade,
        fabricacao: _fabricacao,
        fornecedor: _fornecedorCtrl.text.trim().isEmpty
            ? insumo['fornecedor']
            : _fornecedorCtrl.text.trim(),
        nfNumero: _nfCtrl.text.trim(),
        precoUnitario: double.tryParse(_precoCtrl.text.replaceAll(',', '.')),
        localArmazenamento: _localCtrl.text.trim(),
        observacoes: _obsCtrl.text.trim(),
        entregasPorPonto: _distribuicaoPorPonto.isEmpty
            ? null
            : _distribuicaoPorPonto,
      );

      await _carregarLotesAtivos();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entrada de lote registrada com sucesso!'),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text('Erro: $e')),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  void dispose() {
    _quantidadeCtrl.dispose();
    _loteCtrl.dispose();
    _fornecedorCtrl.dispose();
    _nfCtrl.dispose();
    _localCtrl.dispose();
    _precoCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Detecta se o insumo selecionado é do tipo "Ração" para ajustar mensagens/obrigações
    bool isRacaoAtual = false;
    if (_insumoId != null) {
      try {
        final ins = _insumos.firstWhere((d) => d.id == _insumoId).data();
        final t = (ins['tipo'] ?? '').toString().toLowerCase();
        isRacaoAtual = t == 'ração' || t == 'racao';
      } catch (_) {}
    }
    return AppScaffold(
      title: 'Entrada de Insumo (Lote)',
      body: DegradeFundo(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _insumoId,
                  items: _insumos
                      .map(
                        (d) => DropdownMenuItem<String>(
                          value: d.id,
                          child: Text(
                            '${d.data()['nome']} (${d.data()['unidade'] ?? '-'})',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    setState(() {
                      _insumoId = v;
                    });
                    _carregarLotesAtivos();
                  },
                  decoration: const InputDecoration(labelText: 'Insumo'),
                  validator: (v) => v == null ? 'Selecione o insumo' : null,
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  color: Colors.teal[50],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.inventory_2_outlined,
                              size: 18,
                              color: Colors.teal,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Lotes ativos deste insumo',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.teal[800],
                              ),
                            ),
                            const Spacer(),
                            if (_carregandoLotes)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (!_carregandoLotes && _lotesAtivos.isEmpty)
                          const Text(
                            'Nenhum lote ativo ainda.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          )
                        else
                          Column(
                            children: _lotesAtivos.map((l) {
                              final d = l.data();
                              final val = (d['validade'] as Timestamp?)
                                  ?.toDate();
                              final qtd = (d['quantidade'] ?? 0).toString();
                              final vencido =
                                  val != null &&
                                  DateTime(
                                    val.year,
                                    val.month,
                                    val.day,
                                  ).isBefore(DateTime.now());
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        (d['lote'] ?? '-').toString().isEmpty
                                            ? '-'
                                            : d['lote'],
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: vencido
                                              ? Colors.red
                                              : Colors.black87,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      'Qtd: $qtd',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      val != null
                                          ? '${val.day.toString().padLeft(2, '0')}/${val.month.toString().padLeft(2, '0')}/${val.year}'
                                          : '-',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: vencido
                                            ? Colors.red
                                            : Colors.black54,
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      onSelected: (acao) async {
                                        if (acao == 'editar') {
                                          await _abrirEditarLoteDialog(l.id, d);
                                          await _carregarLotesAtivos();
                                        } else if (acao == 'inativar') {
                                          final ok = await showDialog<bool>(
                                            context: context,
                                            builder: (_) => AlertDialog(
                                              title: const Text(
                                                'Inativar lote?',
                                              ),
                                              content: const Text(
                                                'O lote ficará indisponível para futuras saídas.',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        context,
                                                        false,
                                                      ),
                                                  child: const Text('Cancelar'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        context,
                                                        true,
                                                      ),
                                                  child: const Text('Inativar'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (ok == true) {
                                            await EstoqueHelper.inativarLote(
                                              loteId: l.id,
                                            );
                                            await _carregarLotesAtivos();
                                          }
                                        }
                                      },
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(
                                          value: 'editar',
                                          child: Text('Editar'),
                                        ),
                                        PopupMenuItem(
                                          value: 'inativar',
                                          child: Text('Inativar'),
                                        ),
                                      ],
                                      tooltip: 'Ações',
                                      icon: const Icon(
                                        Icons.more_vert,
                                        size: 18,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _quantidadeCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Quantidade'),
                  validator: (v) {
                    final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                    if (n == null || n <= 0) return 'Informe quantidade válida';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _loteCtrl,
                  decoration: InputDecoration(
                    labelText: 'Lote (opcional)',
                    suffixIcon: IconButton(
                      tooltip: 'Gerar código',
                      icon: const Icon(Icons.autorenew_rounded),
                      onPressed: _gerarCodigoLote,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _fabricacao ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (d != null) setState(() => _fabricacao = d);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Fabricação (opcional)',
                          ),
                          child: Text(
                            _fabricacao == null
                                ? 'Selecionar'
                                : '${_fabricacao!.day.toString().padLeft(2, '0')}/${_fabricacao!.month.toString().padLeft(2, '0')}/${_fabricacao!.year}',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _validade ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (d != null) setState(() => _validade = d);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Validade (obrigatória para Ração)',
                          ),
                          child: Text(
                            _validade == null
                                ? 'Selecionar'
                                : '${_validade!.day.toString().padLeft(2, '0')}/${_validade!.month.toString().padLeft(2, '0')}/${_validade!.year}',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _fornecedorCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Fornecedor (opcional)',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _nfCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nº Nota Fiscal (opcional)',
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _precoCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Preço unitário (opcional)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _localCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Local/Armazenamento (opcional)',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _obsCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Observações (opcional)',
                  ),
                ),
                const SizedBox(height: 16),
                // Distribuição por ponto de entrega
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.local_shipping, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'Distribuição por ponto de entrega' +
                                  (isRacaoAtual
                                      ? ' (obrigatória para Ração)'
                                      : ''),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () async {
                                final result =
                                    await showDialog<
                                      List<Map<String, dynamic>>
                                    >(
                                      context: context,
                                      builder: (_) =>
                                          const _DistribuicaoPontoDialog(),
                                    );
                                if (result != null) {
                                  setState(
                                    () => _distribuicaoPorPonto = result,
                                  );
                                }
                              },
                              icon: const Icon(
                                Icons.edit,
                                size: 16,
                                color: Colors.teal,
                              ),
                              label: const Text('Editar'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (_distribuicaoPorPonto.isEmpty)
                          Text(
                            isRacaoAtual
                                ? 'Obrigatório para ração: selecione ao menos um ponto e distribua 100% da quantidade.'
                                : 'Nenhum ponto selecionado. Toda a quantidade ficará sem distribuição por ponto.',
                            style: TextStyle(color: Colors.grey[700]),
                          )
                        else
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: _distribuicaoPorPonto
                                .map(
                                  (e) => Chip(
                                    label: Text(
                                      '${e['nomePonto']} • ${(e['quantidade'] ?? 0)} kg',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                )
                                .toList(),
                          ),
                      ],
                    ),
                  ),
                ),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _salvando ? null : _salvar,
                        icon: _salvando
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: const Text('Salvar entrada'),
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

class _DistribuicaoPontoDialog extends StatefulWidget {
  const _DistribuicaoPontoDialog();

  @override
  State<_DistribuicaoPontoDialog> createState() =>
      _DistribuicaoPontoDialogState();
}

class _DistribuicaoPontoDialogState extends State<_DistribuicaoPontoDialog> {
  bool _carregando = true;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _pontos = [];
  final Map<String, TextEditingController> _qtdCtrls = {};
  final Set<String> _selecionados = {};

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final snap = await FirebaseFirestore.instance
        .collection('pontos_entrega')
        .where('ativo', isEqualTo: true)
        .orderBy('nome')
        .get();
    setState(() {
      _pontos = snap.docs;
      _carregando = false;
    });
  }

  @override
  void dispose() {
    for (final c in _qtdCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Distribuir por ponto de entrega'),
      content: SizedBox(
        width: 520,
        child: _carregando
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Selecione os pontos e informe as quantidades (kg):',
                    ),
                    const SizedBox(height: 8),
                    ..._pontos.map((d) {
                      final m = d.data();
                      final id = d.id;
                      final nome = (m['nome'] ?? '').toString();
                      _qtdCtrls.putIfAbsent(id, () => TextEditingController());
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            Checkbox(
                              value: _selecionados.contains(id),
                              onChanged: (v) {
                                setState(() {
                                  if (v == true) {
                                    _selecionados.add(id);
                                  } else {
                                    _selecionados.remove(id);
                                    _qtdCtrls[id]?.text = '';
                                  }
                                });
                              },
                            ),
                            Expanded(child: Text(nome)),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 120,
                              child: TextField(
                                controller: _qtdCtrls[id],
                                enabled: _selecionados.contains(id),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Quantidade (kg)',
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            final result = <Map<String, dynamic>>[];
            for (final id in _selecionados) {
              final ctrl = _qtdCtrls[id]!;
              final qtd = double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0;
              if (qtd <= 0) continue;
              final ponto = _pontos.firstWhere((e) => e.id == id).data();
              result.add({
                'pontoId': id,
                'nomePonto': (ponto['nome'] ?? '').toString(),
                'quantidade': qtd,
              });
            }
            Navigator.pop(context, result);
          },
          child: const Text('Aplicar'),
        ),
      ],
    );
  }
}
