import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/degrade_fundo.dart'; // adicione este import

class TelaAnaliseAgua extends StatefulWidget {
  const TelaAnaliseAgua({super.key});
  @override
  _TelaAnaliseAguaState createState() => _TelaAnaliseAguaState();
}

class _TelaAnaliseAguaState extends State<TelaAnaliseAgua> {
  final _formKey = GlobalKey<FormState>();
  final _phCtrl = TextEditingController();
  final _oxCtrl = TextEditingController();
  final _tempCtrl = TextEditingController();
  final _salinityCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();

  DateTime _registroDt = DateTime.now();
  bool _saving = false;
  String? _codigoSelecionado;
  String? _tipoSelecionado;
  Map<String, String> _mapaDestinos = {};
  String _funcaoUsuario = '';
  bool _temCampoPreenchido = false;

  @override
  void initState() {
    super.initState();
    _carregarDestinos();
    _carregarFuncao();
    _phCtrl.addListener(_verificarCampos);
    _oxCtrl.addListener(_verificarCampos);
    _tempCtrl.addListener(_verificarCampos);
    _salinityCtrl.addListener(_verificarCampos);
    _obsCtrl.addListener(_verificarCampos);
  }

  void _verificarCampos() {
    setState(() {
      _temCampoPreenchido = _phCtrl.text.isNotEmpty ||
          _oxCtrl.text.isNotEmpty ||
          _tempCtrl.text.isNotEmpty ||
          _salinityCtrl.text.isNotEmpty ||
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
    final snapshot = await FirebaseFirestore.instance.collection('viveiros').get();
    final mapa = <String, String>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      mapa[data['codigo']] = data['nome'];
    }
    final bercarios = await FirebaseFirestore.instance.collection('bercarios').get();
    for (final doc in bercarios.docs) {
      final data = doc.data();
      mapa[data['codigo']] = data['nome'];
    }
    setState(() {
      _mapaDestinos = mapa;
    });
  }

  String _formatDateTime(DateTime dt) {
    return DateFormat('dd/MM/yyyy HH:mm').format(dt);
  }

  bool _foraFaixa(String tipo, double valor) {
    switch (tipo) {
      case 'ph':
        return valor < 7.5 || valor > 8.5;
      case 'ox':
        return valor < 5.0 || valor > 8.0;
      case 'temp':
        return valor < 28.0 || valor > 32.0;
      case 'sal':
        return valor < 15.0 || valor > 25.0;
      default:
        return false;
    }
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_codigoSelecionado == null || _tipoSelecionado == null) return;

    final ph = double.tryParse(_phCtrl.text) ?? 0.0;
    final ox = double.tryParse(_oxCtrl.text) ?? 0.0;
    final temp = double.tryParse(_tempCtrl.text) ?? 0.0;
    final sal = double.tryParse(_salinityCtrl.text) ?? 0.0;

    final fora = <String>[];
    if (_foraFaixa('ph', ph)) fora.add('pH');
    if (_foraFaixa('ox', ox)) fora.add('Oxigênio');
    if (_foraFaixa('temp', temp)) fora.add('Temperatura');
    if (_foraFaixa('sal', sal)) fora.add('Salinidade');

    if (fora.isNotEmpty) {
      final continuar = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Parâmetro(s) fora da faixa'),
          content: Text(
              'Os seguintes parâmetros estão fora da faixa ideal:\n\n${fora.join(', ')}\n\nDeseja continuar mesmo assim?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continuar')),
          ],
        ),
      );
      if (continuar != true) return;
    }

    setState(() => _saving = true);

    final col = FirebaseFirestore.instance.collection('registros_diarios');
    final nome = _mapaDestinos[_codigoSelecionado!] ?? '—';
    String nomeUsuario = '—';

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      nomeUsuario = doc.data()?['nome'] ?? '—';
    }

    await col.add({
      'tipoDestino': _tipoSelecionado,
      'codigo': _codigoSelecionado,
      'nome': nome,
      'ph': ph,
      'oxigenio': ox,
      'temperatura': temp,
      'salinidade': sal,
      'observacoes': _obsCtrl.text.trim(),
      'dataHora': Timestamp.fromDate(_registroDt),
      'criadoEm': Timestamp.now(),
      'registradoPor': nomeUsuario,
    });

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sucesso'),
        content: const Text('Análise registrada com sucesso!'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
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

  @override
  void dispose() {
    _phCtrl.dispose();
    _oxCtrl.dispose();
    _tempCtrl.dispose();
    _salinityCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _confirmarSaida,
      child: AppScaffold(
        title: 'Análise da Água',
        body: DegradeFundo( // <-- Aqui aplica o degradê
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
                        Icon(Icons.science, size: 48),
                        SizedBox(height: 6),
                        Text(
                          'Análise da Água',
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
                      prefixIcon: Icon(Icons.water_damage_outlined),
                    ),
                    items: _mapaDestinos.entries
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
                    validator: (v) => v == null || v.isEmpty ? 'Selecione o código' : null,
                  ),
                  const SizedBox(height: 12),
                  _campoNumComFaixa(_phCtrl, 'pH da Água', Icons.grain, 7.5, 8.5, 'ph'),
                  _campoNumComFaixa(_oxCtrl, 'Oxigênio Dissolvido (mg/L)', Icons.air, 5.0, 8.0, 'ox'),
                  _campoNumComFaixa(_tempCtrl, 'Temperatura (°C)', Icons.thermostat, 28.0, 32.0, 'temp'),
                  _campoNumComFaixa(_salinityCtrl, 'Salinidade (ppt)', Icons.opacity, 15.0, 25.0, 'sal'),
                  TextFormField(
                    controller: _obsCtrl,
                    maxLines: 2,
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
                              initialDate: _registroDt,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (dt != null) {
                              final tm = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.fromDateTime(_registroDt),
                              );
                              if (tm != null) {
                                setState(() => _registroDt =
                                    DateTime(dt.year, dt.month, dt.day, tm.hour, tm.minute));
                              }
                            }
                          },
                        ),
                        hintText: _formatDateTime(_registroDt),
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
                          onPressed: _saving ? null : _onSubmit,
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

  Widget _campoNumComFaixa(TextEditingController controller, String label, IconData icon,
      double min, double max, String tipo) {
    final text = controller.text;
    final valor = double.tryParse(text);
    final fora = valor != null && _foraFaixa(tipo, valor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          style: const TextStyle(fontSize: 18),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
            fillColor: fora ? Colors.red.shade100 : null,
            filled: fora,
          ),
          validator: (v) => v == null || v.isEmpty ? 'Informe $label' : null,
          onChanged: (_) => setState(() {}), // força rebuild para mudar cor se necessário
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 4),
          child: Text(
            'Faixa ideal: $min – $max. Fora disso, notifique o supervisor.',
            style: const TextStyle(fontSize: 15, color: Colors.red),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
