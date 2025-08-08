import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/degrade_fundo.dart';

class TelaEditarBercario extends StatefulWidget {
  const TelaEditarBercario({required this.docId, required this.dados, super.key});
  final String docId;
  final Map<String, dynamic> dados;

  @override
  State<TelaEditarBercario> createState() => _TelaEditarBercarioState();
}

class _TelaEditarBercarioState extends State<TelaEditarBercario> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nomeCtrl;
  late TextEditingController _codigoCtrl;
  late TextEditingController _areaCtrl;
  late TextEditingController _volumeCtrl;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _nomeCtrl = TextEditingController(text: widget.dados['nome'] ?? '');
    _codigoCtrl = TextEditingController(text: widget.dados['codigo'] ?? '');
    _areaCtrl = TextEditingController(text: widget.dados['area']?.toString() ?? '');
    _volumeCtrl = TextEditingController(text: widget.dados['volume']?.toString() ?? '');
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _codigoCtrl.dispose();
    _areaCtrl.dispose();
    _volumeCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvarAlteracoes() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      await FirebaseFirestore.instance.collection('bercarios').doc(widget.docId).update({
        'nome': _nomeCtrl.text.trim(),
        'codigo': _codigoCtrl.text.trim(),
        'area': _areaCtrl.text.trim(),
        'volume': _volumeCtrl.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Berçário atualizado com sucesso!'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DegradeFundo(
        child: AppScaffold(
          title: 'Editar Berçário',
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nomeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nome do Berçário',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Informe o nome' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _codigoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Código do Berçário',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Informe o código' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _areaCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Área (m²)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _volumeCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Volume (m³)',
                      border: OutlineInputBorder(),
                    ),
                  ),
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
