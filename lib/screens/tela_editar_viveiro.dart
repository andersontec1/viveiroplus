import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/degrade_fundo.dart';

class TelaEditarViveiro extends StatefulWidget {
  const TelaEditarViveiro({
    required this.docId,
    required this.dados,
    super.key,
  });
  final String docId;
  final Map<String, dynamic> dados;

  @override
  State<TelaEditarViveiro> createState() => _TelaEditarViveiroState();
}

class _TelaEditarViveiroState extends State<TelaEditarViveiro> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nomeCtrl;
  late TextEditingController _nomeBercarioCtrl;
  bool _temBercario = false;
  bool _salvando = false;
  String? _codigo;

  @override
  void initState() {
    super.initState();
    _nomeCtrl = TextEditingController(text: widget.dados['nome']);
    _nomeBercarioCtrl = TextEditingController();
    _temBercario = widget.dados['temBercario'] ?? false;
    _codigo = widget.dados['codigo'];
    if (_temBercario) {
      _carregarNomeBercario();
    }
  }

  Future<void> _carregarNomeBercario() async {
    final snap = await FirebaseFirestore.instance
        .collection('bercarios')
        .where('codigo', isEqualTo: '$_codigo-B')
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      _nomeBercarioCtrl.text = snap.docs.first['nome'] ?? '';
    }
  }

  Future<bool> _nomeJaExiste(String nome) async {
    final snap = await FirebaseFirestore.instance
        .collection('viveiros')
        .where('nomeLower', isEqualTo: nome.toLowerCase())
        .get();
    for (var doc in snap.docs) {
      if (doc.id != widget.docId) return true;
    }
    return false;
  }

  Future<void> _salvarAlteracoes() async {
    if (!_formKey.currentState!.validate()) return;

    final novoNome = _nomeCtrl.text.trim();
    final novoNomeLower = novoNome.toLowerCase();
    final nomeBercario = _nomeBercarioCtrl.text.trim();

    setState(() => _salvando = true);

    if (await _nomeJaExiste(novoNome)) {
      setState(() => _salvando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Já existe um viveiro com esse nome.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final viveiroRef =
        FirebaseFirestore.instance.collection('viveiros').doc(widget.docId);
    await viveiroRef.update({
      'nome': novoNome,
      'nomeLower': novoNomeLower,
      'temBercario': _temBercario,
    });

    final bercarioCodigo = '$_codigo-B';
    final bercariosRef = FirebaseFirestore.instance.collection('bercarios');

    if (_temBercario) {
      final snap = await bercariosRef.where('codigo', isEqualTo: bercarioCodigo).get();
      if (snap.docs.isNotEmpty) {
        await bercariosRef.doc(snap.docs.first.id).update({
          'nome': nomeBercario.isEmpty ? 'Berçário do $novoNome' : nomeBercario,
        });
      } else {
        await bercariosRef.add({
          'nome': nomeBercario.isEmpty ? 'Berçário do $novoNome' : nomeBercario,
          'codigo': bercarioCodigo,
          'viveiroCodigo': _codigo,
          'criadoEm': FieldValue.serverTimestamp(),
        });
      }
    } else {
      final snap = await bercariosRef.where('codigo', isEqualTo: bercarioCodigo).get();
      if (snap.docs.isNotEmpty) {
        final confirmar = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Excluir berçário?'),
            content: const Text('Deseja excluir o berçário vinculado a este viveiro?'),
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
        if (confirmar == true) {
          await bercariosRef.doc(snap.docs.first.id).delete();
        }
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Viveiro atualizado com sucesso!'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _nomeBercarioCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DegradeFundo(
        child: AppScaffold(
          title: 'Editar Viveiro',
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nomeCtrl,
                    style: Theme.of(context).textTheme.bodyLarge,
                    decoration: InputDecoration(
                      labelText: 'Nome do Viveiro',
                      labelStyle: Theme.of(context).textTheme.bodyLarge,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value == null || value.trim().isEmpty ? 'Informe o nome' : null,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Possui berçário?'),
                    value: _temBercario,
                    onChanged: (v) => setState(() => _temBercario = v),
                  ),
                  if (_temBercario) ...[
                    TextFormField(
                      controller: _nomeBercarioCtrl,
                      style: Theme.of(context).textTheme.bodyLarge,
                      decoration: InputDecoration(
                        labelText: 'Nome do Berçário',
                        labelStyle: Theme.of(context).textTheme.bodyLarge,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const Spacer(),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: _salvando
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Salvar alterações'),
                    onPressed: _salvando ? null : _salvarAlteracoes,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
