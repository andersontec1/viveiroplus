import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/degrade_fundo.dart'; // adicione este import

class TelaArracoador extends StatefulWidget {
  const TelaArracoador({super.key});

  @override
  State<TelaArracoador> createState() => _TelaArracoadorState();
}

class _TelaArracoadorState extends State<TelaArracoador> {
  final _formKey = GlobalKey<FormState>();
  final _quantidadeCtrl = TextEditingController();
  final _sobrasCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();

  String? _tipoSelecionado;
  String? _codigoSelecionado;
  Map<String, String> _destinos = {};
  DateTime _horaAtual = DateTime.now();
  String _funcaoUsuario = '';
  bool _saving = false;
  bool _temCampoPreenchido = false;

  @override
  void initState() {
    super.initState();
    _carregarDestinos();
    _carregarFuncao();
    _quantidadeCtrl.addListener(_verificarCampos);
    _sobrasCtrl.addListener(_verificarCampos);
    _obsCtrl.addListener(_verificarCampos);
  }

  void _verificarCampos() {
    setState(() {
      _temCampoPreenchido = _quantidadeCtrl.text.isNotEmpty ||
          _sobrasCtrl.text.isNotEmpty ||
          _obsCtrl.text.isNotEmpty;
    });
  }

  Future<void> _carregarFuncao() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snap = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      _funcaoUsuario = snap.data()?['funcao'] ?? '';
      setState(() {});
    }
  }

  Future<void> _carregarDestinos() async {
    final mapa = <String, String>{};
    final snapshotViveiros = await FirebaseFirestore.instance.collection('viveiros').get();
    for (final doc in snapshotViveiros.docs) {
      final data = doc.data();
      mapa[data['codigo']] = data['nome'];
    }
    final snapshotBercarios = await FirebaseFirestore.instance.collection('bercarios').get();
    for (final doc in snapshotBercarios.docs) {
      final data = doc.data();
      mapa[data['codigo']] = data['nome'];
    }
    setState(() => _destinos = mapa);
  }

  Future<bool> _destinoExiste(String codigo, String tipo) async {
    final col = tipo == 'viveiro' ? 'viveiros' : 'bercarios';
    final snap = await FirebaseFirestore.instance.collection(col).where('codigo', isEqualTo: codigo).get();
    return snap.docs.isNotEmpty;
  }

  Future<void> _salvarRegistro() async {
    if (!_formKey.currentState!.validate()) return;
    if (_tipoSelecionado == null || _codigoSelecionado == null) return;

    setState(() => _saving = true);

    final existe = await _destinoExiste(_codigoSelecionado!, _tipoSelecionado!);
    if (!existe) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Código não encontrado. Verifique se o destino foi cadastrado.')),
            ],
          ),
        ),
      );
      return;
    }

    final nome = _destinos[_codigoSelecionado!] ?? '---';
    final doc = FirebaseFirestore.instance.collection('racao').doc();

    final user = FirebaseAuth.instance.currentUser;
    String registradoPor = '—';
    if (user != null) {
      final usuarioDoc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      registradoPor = usuarioDoc.data()?['nome'] ?? '—';
    }

    await doc.set({
      'tipoDestino': _tipoSelecionado,
      'codigo': _codigoSelecionado,
      'viveiro': nome,
      'quantidade': double.tryParse(_quantidadeCtrl.text.replaceAll(',', '.')) ?? 0,
      'sobras': double.tryParse(_sobrasCtrl.text.replaceAll(',', '.')) ?? 0,
      'observacoes': _obsCtrl.text.trim(),
      'timestamp': Timestamp.fromDate(_horaAtual),
      'registradoPor': registradoPor,
    });

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sucesso'),
        content: const Text('Ração registrada com sucesso!'),
        actions: [
          ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Fechar')),
        ],
      ),
    );
    Navigator.of(context).pop();
  }

  Future<bool> _confirmarSaida() async {
    if (!_temCampoPreenchido) return true;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Descartar dados?'),
        content: const Text('Há dados preenchidos. Tem certeza que deseja sair?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sair')),
        ],
      ),
    );
    return confirm == true;
  }

  String _formatDateTime(DateTime dt) {
    return DateFormat('dd/MM/yyyy HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _confirmarSaida,
      child: AppScaffold(
        title: 'Registrar Ração',
        body: DegradeFundo(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  const SizedBox(height: 10),
                  Center(
                    child: Column(
                      children: const [
                        Icon(Icons.restaurant_menu, size: 48),
                        SizedBox(height: 6),
                        Text(
                          'Registrar Ração',
                          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 20),
                      ],
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    value: _tipoSelecionado,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de Destino',
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'viveiro', child: Text('Viveiro')),
                      DropdownMenuItem(value: 'bercario', child: Text('Berçário')),
                    ],
                    onChanged: (value) => setState(() => _tipoSelecionado = value),
                    validator: (v) => v == null ? 'Escolha viveiro ou berçário' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _codigoSelecionado,
                    decoration: const InputDecoration(
                      labelText: 'Código',
                      prefixIcon: Icon(Icons.code),
                    ),
                    items: _destinos.entries
                        .where((e) {
                          final isBercario = e.key.toLowerCase().contains('b');
                          return _tipoSelecionado == 'bercario' ? isBercario : !isBercario;
                        })
                        .map((e) => DropdownMenuItem(
                              value: e.key,
                              child: Text('${e.value} (cód: ${e.key})'),
                            ))
                        .toList(),
                    onChanged: (value) => setState(() => _codigoSelecionado = value),
                    validator: (v) => v == null ? 'Selecione o código' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _quantidadeCtrl,
                    keyboardType: TextInputType.number,
                    style: Theme.of(context).textTheme.bodyLarge,
                    decoration: const InputDecoration(
                      labelText: 'Quantidade de Ração (Kg)',
                      prefixIcon: Icon(Icons.restaurant),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Informe a quantidade' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _sobrasCtrl,
                    keyboardType: TextInputType.number,
                    style: Theme.of(context).textTheme.bodyLarge,
                    decoration: const InputDecoration(
                      labelText: 'Sobras da Última (Kg)',
                      prefixIcon: Icon(Icons.restore_from_trash),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _obsCtrl,
                    maxLines: 2,
                    style: Theme.of(context).textTheme.bodyLarge,
                    decoration: const InputDecoration(
                      labelText: 'Observações',
                      prefixIcon: Icon(Icons.note_alt),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_funcaoUsuario == 'admin' || _funcaoUsuario == 'gerente') ...[
                    TextFormField(
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Data/Hora do Registro',
                        prefixIcon: const Icon(Icons.calendar_today),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.access_time),
                          onPressed: () async {
                            final dt = await showDatePicker(
                              context: context,
                              initialDate: _horaAtual,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (dt != null) {
                              final tm = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.fromDateTime(_horaAtual),
                              );
                              if (tm != null) {
                                setState(() => _horaAtual =
                                    DateTime(dt.year, dt.month, dt.day, tm.hour, tm.minute));
                              }
                            }
                          },
                        ),
                        hintText: _formatDateTime(_horaAtual),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final sair = await _confirmarSaida();
                            if (sair) Navigator.of(context).pop();
                          },
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saving ? null : _salvarRegistro,
                          child: _saving ? const CircularProgressIndicator() : const Text('Salvar'),
                        ),
                      ),
                    ],
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
