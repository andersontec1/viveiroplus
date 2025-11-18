import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/degrade_fundo.dart';
import '../helpers/estoque_helper.dart';
import '../helpers/confirmation_helper.dart';
import 'tela_pontos_entrega.dart';

class TelaEntregaRacaoFornecedor extends StatefulWidget {
  const TelaEntregaRacaoFornecedor({super.key});

  @override
  State<TelaEntregaRacaoFornecedor> createState() =>
      _TelaEntregaRacaoFornecedorState();
}

class _TelaEntregaRacaoFornecedorState extends State<TelaEntregaRacaoFornecedor>
    with SingleTickerProviderStateMixin {
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _racoes = [];
  String? _insumoId;
  final _qtdCtrl = TextEditingController();
  DateTime? _validade;
  DateTime? _fabricacao;
  final _loteCtrl = TextEditingController();
  final _nfCtrl = TextEditingController();
  final _precoUnitCtrl = TextEditingController();
  final _recebidoPorCtrl = TextEditingController();
  final _observacoesCtrl = TextEditingController();
  bool _salvando = false;
  List<Map<String, dynamic>> _distribuicaoPorPonto = [];
  late TabController _tabController;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _lotesAtivos = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _lotesInativos = [];
  bool _carregandoLotes = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _carregarRacoes();
    _prefillRecebidoPor();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _qtdCtrl.dispose();
    _loteCtrl.dispose();
    _nfCtrl.dispose();
    _precoUnitCtrl.dispose();
    _recebidoPorCtrl.dispose();
    _observacoesCtrl.dispose();
    super.dispose();
  }

  Future<void> _prefillRecebidoPor() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();
      final nome = doc.data()?['nome']?.toString();
      if (nome != null && mounted) {
        setState(() => _recebidoPorCtrl.text = nome);
      }
    } catch (_) {}
  }

  Future<void> _carregarRacoes() async {
    final snap = await FirebaseFirestore.instance
        .collection('insumos')
        .where('tipo', isEqualTo: 'Ração')
        .get();
    setState(() {
      _racoes = snap.docs;
      _insumoId = _racoes.isNotEmpty ? _racoes.first.id : null;
    });
    if (_insumoId != null) _carregarLotes();
  }

  Future<void> _carregarLotes() async {
    if (_insumoId == null) return;
    setState(() => _carregandoLotes = true);
    try {
      final ativos = await FirebaseFirestore.instance
          .collection('lotes_insumo')
          .where('insumoId', isEqualTo: _insumoId)
          .where('status', isEqualTo: 'ativo')
          .get();
      final inativos = await FirebaseFirestore.instance
          .collection('lotes_insumo')
          .where('insumoId', isEqualTo: _insumoId)
          .where('status', isEqualTo: 'inativo')
          .get();

      final docsAtivos = ativos.docs.toList();
      docsAtivos.sort((a, b) {
        final av = (a.data()['validade'] as Timestamp?)?.toDate();
        final bv = (b.data()['validade'] as Timestamp?)?.toDate();
        if (av == null && bv == null) return 0;
        if (av == null) return 1;
        if (bv == null) return -1;
        return av.compareTo(bv);
      });

      setState(() {
        _lotesAtivos = docsAtivos;
        _lotesInativos = inativos.docs;
      });
    } finally {
      if (mounted) setState(() => _carregandoLotes = false);
    }
  }

  void _gerarCodigoLote() {
    if (_insumoId == null) return;
    final insumo = _racoes.firstWhere((d) => d.id == _insumoId).data();
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

  Future<void> _registrarEntrega() async {
    if (_insumoId == null) {
      await ConfirmationHelper.showError(
        context: context,
        title: 'Campo obrigatório',
        content: 'Selecione o insumo de ração.',
      );
      return;
    }
    final qtd = num.tryParse(_qtdCtrl.text.replaceAll(',', '.'));
    if (qtd == null || qtd <= 0) {
      await ConfirmationHelper.showError(
        context: context,
        title: 'Quantidade inválida',
        content: 'Informe uma quantidade válida para a entrega.',
      );
      return;
    }
    if (_validade == null) {
      await ConfirmationHelper.showError(
        context: context,
        title: 'Campo obrigatório',
        content: 'Informe a validade do lote de ração.',
      );
      return;
    }
    if (_recebidoPorCtrl.text.trim().isEmpty) {
      await ConfirmationHelper.showError(
        context: context,
        title: 'Campo obrigatório',
        content: 'Informe quem recebeu a entrega.',
      );
      return;
    }

    // Validação da distribuição por ponto
    if (_distribuicaoPorPonto.isNotEmpty) {
      final soma = _distribuicaoPorPonto
          .map((e) => (e['quantidade'] ?? 0) as num)
          .fold<num>(0, (a, b) => a + b);
      if ((soma - qtd).abs() > 0.0001) {
        await ConfirmationHelper.showError(
          context: context,
          title: 'Distribuição incorreta',
          content:
              'A soma das quantidades por ponto (${soma.toStringAsFixed(2)} kg) precisa ser igual à quantidade total ($qtd kg).',
        );
        return;
      }
    }

    // Validação de duplicidade de código de lote
    final codigoLote = _loteCtrl.text.trim();
    if (codigoLote.isNotEmpty) {
      final dup = await FirebaseFirestore.instance
          .collection('lotes_insumo')
          .where('insumoId', isEqualTo: _insumoId)
          .where('lote', isEqualTo: codigoLote)
          .limit(1)
          .get();
      if (dup.docs.isNotEmpty) {
        await ConfirmationHelper.showError(
          context: context,
          title: 'Código duplicado',
          content:
              'Já existe um lote com este código para esta ração. Altere ou gere outro.',
        );
        return;
      }
    }

    setState(() => _salvando = true);
    try {
      final insumo = _racoes.firstWhere((d) => d.id == _insumoId!).data();
      final user = FirebaseAuth.instance.currentUser;
      final usuarioDoc = user != null
          ? await FirebaseFirestore.instance
                .collection('usuarios')
                .doc(user.uid)
                .get()
          : null;
      final nomeFornecedor = usuarioDoc?.data()?['nome']?.toString();

      await EstoqueHelper.registrarEntradaLote(
        insumoId: _insumoId!,
        quantidade: qtd,
        unidade: insumo['unidade'],
        lote: _loteCtrl.text.trim().isEmpty ? null : _loteCtrl.text.trim(),
        validade: _validade,
        fabricacao: _fabricacao,
        fornecedor: nomeFornecedor ?? insumo['fornecedor'],
        nfNumero: _nfCtrl.text.trim().isEmpty ? null : _nfCtrl.text.trim(),
        precoUnitario: _precoUnitCtrl.text.trim().isEmpty
            ? null
            : double.tryParse(_precoUnitCtrl.text.replaceAll(',', '.')),
        responsavel: _recebidoPorCtrl.text.trim(),
        observacoes: _observacoesCtrl.text.trim().isEmpty
            ? null
            : _observacoesCtrl.text.trim(),
        entregasPorPonto: _distribuicaoPorPonto.isEmpty
            ? null
            : _distribuicaoPorPonto,
      );

      await _carregarLotes();

      if (!mounted) return;
      await ConfirmationHelper.showSuccess(
        context: context,
        title: 'Entrega registrada',
        content:
            'A entrada do lote de ração foi salva com sucesso. Você pode consultar no histórico de lotes.',
      );
      setState(() {
        _qtdCtrl.clear();
        _loteCtrl.clear();
        _nfCtrl.clear();
        _precoUnitCtrl.clear();
        _observacoesCtrl.clear();
        _validade = null;
        _fabricacao = null;
        _distribuicaoPorPonto = [];
      });
    } catch (e) {
      if (!mounted) return;
      await ConfirmationHelper.showError(
        context: context,
        title: 'Falha ao registrar',
        content: 'Não foi possível registrar a entrega de ração.',
        error: e.toString(),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Gestão de Entrega de Ração',
      body: DegradeFundo(
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: Icon(Icons.local_shipping), text: 'Nova Entrega'),
                Tab(icon: Icon(Icons.inventory_2), text: 'Lotes'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Aba 1: Nova Entrega
                  _buildAbaNovaEntrega(),
                  // Aba 2: Histórico de Lotes
                  _buildAbaLotes(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAbaNovaEntrega() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Dropdown de seleção de ração
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Selecione a Ração',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _insumoId,
                    items: _racoes
                        .map(
                          (d) => DropdownMenuItem(
                            value: d.id,
                            child: Text(
                              '${d.data()['nome']} (${d.data()['unidade']})',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      setState(() => _insumoId = v);
                      _carregarLotes();
                    },
                    decoration: const InputDecoration(
                      labelText: 'Ração',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Dados básicos da entrega
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dados da Entrega',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _qtdCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Quantidade entregue *',
                      border: OutlineInputBorder(),
                      suffixText: 'kg',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _loteCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Código do lote (opcional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.auto_awesome),
                        tooltip: 'Gerar código automático',
                        onPressed: _gerarCodigoLote,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final now = DateTime.now();
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _fabricacao ?? now,
                              firstDate: DateTime(now.year - 2),
                              lastDate: DateTime(now.year + 5),
                            );
                            if (d != null) setState(() => _fabricacao = d);
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Fabricação (opcional)',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(
                              _fabricacao == null
                                  ? 'Selecionar data'
                                  : '${_fabricacao!.day.toString().padLeft(2, '0')}/${_fabricacao!.month.toString().padLeft(2, '0')}/${_fabricacao!.year}',
                              style: TextStyle(
                                color: _fabricacao == null
                                    ? Colors.grey
                                    : Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final now = DateTime.now();
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _validade ?? now,
                              firstDate: DateTime(now.year - 1),
                              lastDate: DateTime(now.year + 5),
                            );
                            if (d != null) setState(() => _validade = d);
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Validade *',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(
                              _validade == null
                                  ? 'Selecionar data'
                                  : '${_validade!.day.toString().padLeft(2, '0')}/${_validade!.month.toString().padLeft(2, '0')}/${_validade!.year}',
                              style: TextStyle(
                                color: _validade == null
                                    ? Colors.grey
                                    : Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _nfCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nota Fiscal (opcional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _precoUnitCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Preço unitário (opcional)',
                            border: OutlineInputBorder(),
                            prefixText: 'R\$ ',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _recebidoPorCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Recebido por *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _observacoesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Observações (opcional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Distribuição por pontos de entrega
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Distribuição por Pontos de Entrega',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TelaPontosEntrega(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.settings, size: 16),
                        label: const Text('Gerenciar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_distribuicaoPorPonto.isEmpty)
                    const Text(
                      'Opcional: distribuir quantidade entre os pontos de entrega',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    )
                  else
                    ..._distribuicaoPorPonto.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final dist = entry.value;
                      return Card(
                        color: Colors.teal[50],
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(dist['nome'] ?? 'Ponto ${idx + 1}'),
                          subtitle: Text('${dist['quantidade']} kg'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setState(
                                () => _distribuicaoPorPonto.removeAt(idx),
                              );
                            },
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _adicionarDistribuicaoPonto(),
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar Ponto'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[100],
                      foregroundColor: Colors.teal[900],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Botão de salvar
          ElevatedButton.icon(
            onPressed: _salvando ? null : _registrarEntrega,
            icon: _salvando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: const Text('Registrar Entrega'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _adicionarDistribuicaoPonto() async {
    final pontosSnap = await FirebaseFirestore.instance
        .collection('pontos_entrega')
        .where('ativo', isEqualTo: true)
        .get();

    if (!mounted) return;

    if (pontosSnap.docs.isEmpty) {
      await ConfirmationHelper.showError(
        context: context,
        title: 'Nenhum ponto ativo',
        content: 'Cadastre pontos de entrega antes de distribuir.',
      );
      return;
    }

    String? pontoId;
    final qtdCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adicionar distribuição'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              items: pontosSnap.docs
                  .map(
                    (d) => DropdownMenuItem(
                      value: d.id,
                      child: Text(d.data()['nome'] ?? 'Ponto'),
                    ),
                  )
                  .toList(),
              onChanged: (v) => pontoId = v,
              decoration: const InputDecoration(labelText: 'Ponto de entrega'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtdCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Quantidade (kg)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (pontoId == null) return;
              final qtd = num.tryParse(qtdCtrl.text.replaceAll(',', '.'));
              if (qtd == null || qtd <= 0) return;

              final ponto = pontosSnap.docs.firstWhere((d) => d.id == pontoId);
              setState(() {
                _distribuicaoPorPonto.add({
                  'pontoId': pontoId,
                  'nome': ponto.data()['nome'],
                  'quantidade': qtd,
                });
              });
              Navigator.pop(ctx);
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }

  Widget _buildAbaLotes() {
    if (_insumoId == null) {
      return const Center(
        child: Text('Selecione uma ração na aba "Nova Entrega"'),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Ativos'),
              Tab(text: 'Inativos'),
            ],
          ),
          Expanded(
            child: _carregandoLotes
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    children: [
                      // Lotes ativos
                      _lotesAtivos.isEmpty
                          ? const Center(child: Text('Nenhum lote ativo'))
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _lotesAtivos.length,
                              itemBuilder: (context, idx) {
                                final doc = _lotesAtivos[idx];
                                final data = doc.data();
                                return _buildLoteCard(doc.id, data);
                              },
                            ),
                      // Lotes inativos
                      _lotesInativos.isEmpty
                          ? const Center(child: Text('Nenhum lote inativo'))
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _lotesInativos.length,
                              itemBuilder: (context, idx) {
                                final doc = _lotesInativos[idx];
                                final data = doc.data();
                                return _buildLoteCard(doc.id, data);
                              },
                            ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoteCard(String loteId, Map<String, dynamic> data) {
    final quantidade = (data['quantidade'] ?? 0).toString();
    final unidade = (data['unidade'] ?? 'kg').toString();
    final lote = (data['lote'] ?? '-').toString();
    final validade = (data['validade'] as Timestamp?)?.toDate();
    final fabricacao = (data['fabricacao'] as Timestamp?)?.toDate();
    final fornecedor = (data['fornecedor'] ?? '-').toString();
    final status = (data['status'] ?? 'ativo').toString();
    final isAtivo = status == 'ativo';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Icon(
          Icons.inventory_2,
          color: isAtivo ? Colors.teal : Colors.grey,
        ),
        title: Text('Lote: $lote'),
        subtitle: Text('$quantidade $unidade'),
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (fabricacao != null)
                  _infoRow(
                    'Fabricação',
                    '${fabricacao.day.toString().padLeft(2, '0')}/${fabricacao.month.toString().padLeft(2, '0')}/${fabricacao.year}',
                  ),
                if (validade != null)
                  _infoRow(
                    'Validade',
                    '${validade.day.toString().padLeft(2, '0')}/${validade.month.toString().padLeft(2, '0')}/${validade.year}',
                  ),
                _infoRow('Fornecedor', fornecedor),
                if (data['nfNumero'] != null)
                  _infoRow('Nota Fiscal', data['nfNumero'].toString()),
                if (data['precoUnitario'] != null)
                  _infoRow(
                    'Preço Unit.',
                    'R\$ ${(data['precoUnitario'] as num).toStringAsFixed(2)}',
                  ),
                if (data['localArmazenamento'] != null)
                  _infoRow('Local', data['localArmazenamento'].toString()),
                if (data['observacoes'] != null)
                  _infoRow('Observações', data['observacoes'].toString()),
                _infoRow('Status', isAtivo ? 'Ativo' : 'Inativo'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
