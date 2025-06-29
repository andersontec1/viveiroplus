import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/degrade_fundo.dart'; // adicione este import

class TelaCadastroViveiro extends StatefulWidget {
  const TelaCadastroViveiro({super.key});
  @override
  _TelaCadastroViveiroState createState() => _TelaCadastroViveiroState();
}

class _TelaCadastroViveiroState extends State<TelaCadastroViveiro> {
  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  final _codigoCtrl = TextEditingController();
  final _nomeBercarioCtrl = TextEditingController();
  final FocusNode _nomeFocus = FocusNode();

  bool _temBercario = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 300), () {
      FocusScope.of(context).requestFocus(_nomeFocus);
    });
  }

  Future<bool> _existeViveiro(String codigo) async {
    final snap = await FirebaseFirestore.instance
        .collection('viveiros')
        .where('codigo', isEqualTo: codigo)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<bool> _existeBercario(String codigo) async {
    final snap = await FirebaseFirestore.instance
        .collection('bercarios')
        .where('codigo', isEqualTo: codigo)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final nome = _nomeCtrl.text.trim();
    final codigo = _codigoCtrl.text.trim();

    setState(() => _saving = true);

    if (await _existeViveiro(codigo)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Expanded(child: Text('Já existe um viveiro com esse código.')),
            ],
          ),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      setState(() => _saving = false);
      return;
    }

    if (_temBercario && await _existeBercario('$codigo-B')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Expanded(child: Text('Já existe um berçário com esse código.')),
            ],
          ),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      setState(() => _saving = false);
      return;
    }

    await FirebaseFirestore.instance.collection('viveiros').add({
      'nome': nome,
      'codigo': codigo,
      'nomeLower': nome.toLowerCase(),
      'temBercario': _temBercario,
      'criadoEm': FieldValue.serverTimestamp(),
    });

    if (_temBercario) {
      final nomeBercario = _nomeBercarioCtrl.text.trim().isEmpty
          ? 'Bercario do $nome'
          : _nomeBercarioCtrl.text.trim();

      await FirebaseFirestore.instance.collection('bercarios').add({
        'nome': nomeBercario,
        'codigo': '$codigo-B',
        'viveiroCodigo': codigo,
        'criadoEm': FieldValue.serverTimestamp(),
      });
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text('Cadastro realizado com sucesso!')),
          ],
        ),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _codigoCtrl.dispose();
    _nomeBercarioCtrl.dispose();
    _nomeFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Cadastrar Viveiro',
      body: DegradeFundo(
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Preencha os dados do novo viveiro:',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nomeCtrl,
                  focusNode: _nomeFocus,
                  decoration: const InputDecoration(
                    labelText: 'Nome do Viveiro (Ex: Viveiro 1)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Informe o nome' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _codigoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Código do Viveiro (ex: 001)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Informe o código' : null,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Possui bercario?'),
                  value: _temBercario,
                  onChanged: (v) => setState(() => _temBercario = v),
                ),
                if (_temBercario) ...[
                  TextFormField(
                    controller: _nomeBercarioCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nome do Bercario (Ex: Bercario do 1)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const Spacer(),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: _saving
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Salvar'),
                  onPressed: _saving ? null : _onSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 184, 255, 248),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
