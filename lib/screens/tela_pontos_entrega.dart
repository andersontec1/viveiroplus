import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/app_scaffold.dart';
import '../widgets/degrade_fundo.dart';
import '../helpers/audit_helper.dart';

class TelaPontosEntrega extends StatefulWidget {
  const TelaPontosEntrega({super.key});

  @override
  State<TelaPontosEntrega> createState() => _TelaPontosEntregaState();
}

class _TelaPontosEntregaState extends State<TelaPontosEntrega> {
  String _busca = '';
  bool _somenteAtivos = true;

  Future<void> _abrirEditorPonto({
    String? pontoId,
    Map<String, dynamic>? dados,
  }) async {
    await showDialog(
      context: context,
      builder: (_) => _EditorPontoEntregaDialog(pontoId: pontoId, dados: dados),
    );
  }

  Future<void> _renomear(String idAtual, String nomeAtual) async {
    final ctrl = TextEditingController(text: nomeAtual);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Renomear ponto'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Nome do ponto'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final novo = ctrl.text.trim();
      if (novo.isEmpty || novo == nomeAtual) return;
      await FirebaseFirestore.instance
          .collection('pontos_entrega')
          .doc(idAtual)
          .update({'nome': novo, 'atualizadoEm': FieldValue.serverTimestamp()});
      await AuditHelper.registrarAcao(
        acao: 'RENOMEAR_PONTO_ENTREGA',
        modulo: 'ESTOQUE',
        detalhes: {'id': idAtual, 'de': nomeAtual, 'para': novo},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ Nome atualizado')));
    }
  }

  Future<void> _alterarAtivo(String id, bool ativo, String nome) async {
    // Se for inativar, pedir confirmação
    if (!ativo) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Inativar Ponto de Entrega'),
          content: Text(
            'Tem certeza que deseja inativar o ponto de entrega "$nome"?\n\n'
            'Pontos inativos não aparecerão nas listagens de seleção.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Inativar'),
            ),
          ],
        ),
      );

      if (confirmar != true) return;
    }

    await FirebaseFirestore.instance
        .collection('pontos_entrega')
        .doc(id)
        .update({'ativo': ativo, 'atualizadoEm': FieldValue.serverTimestamp()});
    await AuditHelper.registrarAcao(
      acao: ativo ? 'ATIVAR_PONTO_ENTREGA' : 'INATIVAR_PONTO_ENTREGA',
      modulo: 'ESTOQUE',
      detalhes: {'id': id, 'nome': nome},
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Pontos de Entrega',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirEditorPonto(),
        icon: const Icon(Icons.add),
        label: const Text('Novo ponto'),
      ),
      body: DegradeFundo(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Buscar por nome',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _busca = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    children: [
                      const Text('Somente ativos'),
                      Switch(
                        value: _somenteAtivos,
                        onChanged: (v) => setState(() => _somenteAtivos = v),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('pontos_entrega')
                      .orderBy('nome')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Erro: ${snapshot.error}'));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    var docs = snapshot.data!.docs;
                    final busca = _busca.trim().toLowerCase();
                    if (_somenteAtivos) {
                      docs = docs
                          .where((d) => (d.data()['ativo'] == true))
                          .toList();
                    }
                    if (busca.isNotEmpty) {
                      docs = docs
                          .where(
                            (d) => (d.data()['nome'] ?? '')
                                .toString()
                                .toLowerCase()
                                .contains(busca),
                          )
                          .toList();
                    }
                    if (docs.isEmpty) {
                      return const Center(
                        child: Text('Nenhum ponto encontrado.'),
                      );
                    }
                    return ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final d = docs[i];
                        final m = d.data();
                        final nome = (m['nome'] ?? '').toString();
                        final ativo = m['ativo'] == true;
                        final viveiros = (m['atendeViveiros'] is List)
                            ? List<String>.from(
                                (m['atendeViveiros'] as List).map(
                                  (e) => e.toString(),
                                ),
                              )
                            : const <String>[];
                        final bercarios = (m['atendeBercarios'] is List)
                            ? List<String>.from(
                                (m['atendeBercarios'] as List).map(
                                  (e) => e.toString(),
                                ),
                              )
                            : const <String>[];
                        return ListTile(
                          leading: Icon(
                            Icons.local_shipping,
                            color: ativo ? Colors.teal : Colors.grey,
                          ),
                          title: Text(nome),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ativo ? 'Ativo' : 'Inativo'),
                              const SizedBox(height: 4),
                              if (viveiros.isNotEmpty || bercarios.isNotEmpty)
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    ...viveiros.map(
                                      (v) => Chip(
                                        label: Text('Viveiro $v'),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                    ...bercarios.map(
                                      (b) => Chip(
                                        label: Text('Berçário $b'),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                    if (viveiros.isEmpty && bercarios.isEmpty)
                                      const Text(
                                        'Sem vinculações de atendimento',
                                        style: TextStyle(color: Colors.black54),
                                      ),
                                  ],
                                )
                              else
                                const Text(
                                  'Sem vinculações de atendimento',
                                  style: TextStyle(color: Colors.black54),
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: ativo,
                                onChanged: (v) => _alterarAtivo(d.id, v, nome),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (acao) {
                                  if (acao == 'renomear') {
                                    _renomear(d.id, nome);
                                  } else if (acao == 'ativar') {
                                    _alterarAtivo(d.id, true, nome);
                                  } else if (acao == 'inativar') {
                                    _alterarAtivo(d.id, false, nome);
                                  } else if (acao == 'editar') {
                                    _abrirEditorPonto(pontoId: d.id, dados: m);
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'editar',
                                    child: Text('Editar vínculos'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'renomear',
                                    child: Text('Renomear'),
                                  ),
                                  if (!ativo)
                                    const PopupMenuItem(
                                      value: 'ativar',
                                      child: Text('Ativar'),
                                    ),
                                  if (ativo)
                                    const PopupMenuItem(
                                      value: 'inativar',
                                      child: Text('Inativar'),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditorPontoEntregaDialog extends StatefulWidget {
  const _EditorPontoEntregaDialog({this.pontoId, this.dados});
  final String? pontoId;
  final Map<String, dynamic>? dados;

  @override
  State<_EditorPontoEntregaDialog> createState() =>
      _EditorPontoEntregaDialogState();
}

class _EditorPontoEntregaDialogState extends State<_EditorPontoEntregaDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  bool _ativo = true;
  bool _carregando = true;
  final Set<String> _viveirosSel = {};
  final Set<String> _bercariosSel = {};
  List<String> _viveiros = [];
  List<String> _bercarios = [];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final vSnap = await FirebaseFirestore.instance
          .collection('viveiros')
          .orderBy('codigo')
          .get();
      final bSnap = await FirebaseFirestore.instance
          .collection('bercarios')
          .orderBy('codigo')
          .get();
      _viveiros = vSnap.docs
          .map((d) => ((d.data()['codigo'] ?? d.id).toString()))
          .toList();
      _bercarios = bSnap.docs
          .map((d) => ((d.data()['codigo'] ?? d.id).toString()))
          .toList();
    } finally {
      if (widget.dados != null) {
        _nomeCtrl.text = (widget.dados!['nome'] ?? '').toString();
        _ativo = widget.dados!['ativo'] != false;
        final v = (widget.dados!['atendeViveiros'] is List)
            ? (widget.dados!['atendeViveiros'] as List)
            : const [];
        final b = (widget.dados!['atendeBercarios'] is List)
            ? (widget.dados!['atendeBercarios'] as List)
            : const [];
        _viveirosSel
          ..clear()
          ..addAll(v.map((e) => e.toString()));
        _bercariosSel
          ..clear()
          ..addAll(b.map((e) => e.toString()));
      }
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.pontoId == null
            ? 'Novo ponto de entrega'
            : 'Editar ponto de entrega',
      ),
      content: SizedBox(
        width: 520,
        child: _carregando
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _nomeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nome do ponto',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Informe o nome'
                            : null,
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        value: _ativo,
                        onChanged: (v) => setState(() => _ativo = v),
                        title: const Text('Ativo'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 8),
                      const Text('Viveiros atendidos:'),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: _viveiros
                            .map(
                              (v) => FilterChip(
                                label: Text(v),
                                selected: _viveirosSel.contains(v),
                                onSelected: (sel) => setState(() {
                                  if (sel) {
                                    _viveirosSel.add(v);
                                  } else {
                                    _viveirosSel.remove(v);
                                  }
                                }),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 8),
                      const Text('Berçários atendidos:'),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: _bercarios
                            .map(
                              (b) => FilterChip(
                                label: Text(b),
                                selected: _bercariosSel.contains(b),
                                onSelected: (sel) => setState(() {
                                  if (sel) {
                                    _bercariosSel.add(b);
                                  } else {
                                    _bercariosSel.remove(b);
                                  }
                                }),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (!_formKey.currentState!.validate()) return;
            final data = {
              'nome': _nomeCtrl.text.trim(),
              'ativo': _ativo,
              'atendeViveiros': _viveirosSel.toList(),
              'atendeBercarios': _bercariosSel.toList(),
              'atualizadoEm': FieldValue.serverTimestamp(),
            };
            if (widget.pontoId == null) {
              final ref = await FirebaseFirestore.instance
                  .collection('pontos_entrega')
                  .add({...data, 'criadoEm': FieldValue.serverTimestamp()});
              await AuditHelper.registrarAcao(
                acao: 'CRIAR_PONTO_ENTREGA',
                modulo: 'ESTOQUE',
                detalhes: {
                  'id': ref.id,
                  'nome': data['nome'],
                  'viveiros': data['atendeViveiros'],
                  'bercarios': data['atendeBercarios'],
                },
              );
            } else {
              await FirebaseFirestore.instance
                  .collection('pontos_entrega')
                  .doc(widget.pontoId)
                  .update(data);
              await AuditHelper.registrarAcao(
                acao: 'EDITAR_PONTO_ENTREGA',
                modulo: 'ESTOQUE',
                detalhes: {
                  'id': widget.pontoId,
                  'nome': data['nome'],
                  'viveiros': data['atendeViveiros'],
                  'bercarios': data['atendeBercarios'],
                },
              );
            }
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
