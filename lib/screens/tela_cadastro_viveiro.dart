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
  final _areaCtrl = TextEditingController();
  final _volumeCtrl = TextEditingController();
  final _areaBercarioCtrl = TextEditingController();
  final _volumeBercarioCtrl = TextEditingController();
  final _codigoBercarioCtrl = TextEditingController();
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
    final area = _areaCtrl.text.trim();
    final volume = _volumeCtrl.text.trim();
    final nomeBercario = _nomeBercarioCtrl.text.trim().isEmpty
        ? 'Bercario do $nome'
        : _nomeBercarioCtrl.text.trim();
    final codigoBercario = _codigoBercarioCtrl.text.trim();
    final areaBercario = _areaBercarioCtrl.text.trim();
    final volumeBercario = _volumeBercarioCtrl.text.trim();

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

    if (_temBercario && await _existeBercario(codigoBercario)) {
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
      'area': area,
      'volume': volume,
      'criadoEm': FieldValue.serverTimestamp(),
    });

    if (_temBercario) {
      await FirebaseFirestore.instance.collection('bercarios').add({
        'nome': nomeBercario,
        'codigo': codigoBercario,
        'viveiroCodigo': codigo,
        'area': areaBercario,
        'volume': volumeBercario,
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
    _areaCtrl.dispose();
    _volumeCtrl.dispose();
    _areaBercarioCtrl.dispose();
    _volumeBercarioCtrl.dispose();
    _codigoBercarioCtrl.dispose();
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Cabeçalho visual padrão
                          const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(Icons.eco, size: 48, color: Colors.teal),
                              SizedBox(height: 8),
                              Text(
                                'Cadastro de Viveiro',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Preencha os dados para cadastrar um novo viveiro e, se desejar, um berçário vinculado.',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.teal,
                                  fontWeight: FontWeight.w400,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 20),
                            ],
                          ),
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
                                value == null || value.trim().isEmpty
                                ? 'Informe o nome'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _codigoCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Código do Viveiro (ex: 001)',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Informe o código'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _areaCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Área do Viveiro (m²)',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Informe a área'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _volumeCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Volume do Viveiro (m³)',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Informe o volume'
                                : null,
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
                                labelText:
                                    'Nome do Bercario (Ex: Bercario do 1)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _codigoBercarioCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Código do Berçário (ex: 001-B)',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                  ? 'Informe o código do berçário'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _areaBercarioCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Área do Berçário (m²)',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                  ? 'Informe a área do berçário'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _volumeBercarioCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Volume do Berçário (m³)',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                  ? 'Informe o volume do berçário'
                                  : null,
                            ),
                            const SizedBox(height: 12),
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
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text('Salvar'),
                            onPressed: _saving ? null : _onSubmit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(
                                255,
                                184,
                                255,
                                248,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
