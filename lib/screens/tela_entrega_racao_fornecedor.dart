import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/degrade_fundo.dart';
import '../helpers/estoque_helper.dart';
import '../helpers/security_helper.dart';

class TelaEntregaRacaoFornecedor extends StatefulWidget {
  const TelaEntregaRacaoFornecedor({super.key});

  @override
  State<TelaEntregaRacaoFornecedor> createState() =>
      _TelaEntregaRacaoFornecedorState();
}

class _TelaEntregaRacaoFornecedorState
    extends State<TelaEntregaRacaoFornecedor> {
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _racoes = [];
  String? _insumoId;
  final _qtdCtrl = TextEditingController();
  DateTime? _validade;
  final _loteCtrl = TextEditingController();
  final _nfCtrl = TextEditingController();
  final _precoUnitCtrl = TextEditingController();
  final _recebidoPorCtrl = TextEditingController();
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _carregarRacoes();
    _prefillRecebidoPor();
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
  }

  Future<void> _registrarEntrega() async {
    if (_insumoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione o insumo de ração.')),
      );
      return;
    }
    final qtd = num.tryParse(_qtdCtrl.text.replaceAll(',', '.'));
    if (qtd == null || qtd <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe uma quantidade válida.')),
      );
      return;
    }
    if (_recebidoPorCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe quem recebeu a entrega.')),
      );
      return;
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
        fornecedor: nomeFornecedor ?? insumo['fornecedor'],
        nfNumero: _nfCtrl.text.trim().isEmpty ? null : _nfCtrl.text.trim(),
        precoUnitario: _precoUnitCtrl.text.trim().isEmpty
            ? null
            : double.tryParse(_precoUnitCtrl.text.replaceAll(',', '.')),
        responsavel: _recebidoPorCtrl.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entrega registrada com sucesso!')),
      );
      setState(() {
        _qtdCtrl.clear();
        _loteCtrl.clear();
        _nfCtrl.clear();
        _precoUnitCtrl.clear();
        _validade = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao registrar entrega: $e')));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Fornecedor - Entrega de Ração',
      body: DegradeFundo(
        child: FutureBuilder<bool>(
          future: SecurityHelper.temPermissao('ver_estoque_racao'),
          builder: (context, snap) {
            final podeVer = snap.data == true;
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (podeVer)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('insumos')
                              .where('tipo', isEqualTo: 'Ração')
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData)
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            final docs = snapshot.data!.docs;
                            if (docs.isEmpty)
                              return const Center(
                                child: Text('Nenhuma ração cadastrada.'),
                              );
                            return ListView.separated(
                              itemCount: docs.length,
                              separatorBuilder: (_, __) => const Divider(),
                              itemBuilder: (context, idx) {
                                final d =
                                    docs[idx].data() as Map<String, dynamic>;
                                final estoque = (d['estoque'] ?? 0) as num;
                                final unidade = (d['unidade'] ?? '').toString();
                                return ListTile(
                                  leading: const Icon(
                                    Icons.inventory_2_rounded,
                                    color: Colors.teal,
                                  ),
                                  title: Text(d['nome'] ?? 'Ração'),
                                  subtitle: Text('Estoque: $estoque $unidade'),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Registrar Entrega',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _insumoId,
                          items: _racoes
                              .map(
                                (d) => DropdownMenuItem(
                                  value: d.id,
                                  child: Text(d.data()['nome'] ?? 'Ração'),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _insumoId = v),
                          decoration: const InputDecoration(labelText: 'Ração'),
                        ),
                        TextFormField(
                          controller: _qtdCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Quantidade entregue',
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _loteCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Código do lote (opcional)',
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
                                    labelText: 'Validade',
                                  ),
                                  child: Text(
                                    _validade == null
                                        ? '—'
                                        : '${_validade!.day.toString().padLeft(2, '0')}/${_validade!.month.toString().padLeft(2, '0')}/${_validade!.year}',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _nfCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'NF (opcional)',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _precoUnitCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Preço unit. (opcional)',
                                ),
                              ),
                            ),
                          ],
                        ),
                        TextFormField(
                          controller: _recebidoPorCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Recebido por (obrigatório)',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            onPressed: _salvando ? null : _registrarEntrega,
                            icon: _salvando
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.local_shipping),
                            label: const Text('Salvar entrega'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
