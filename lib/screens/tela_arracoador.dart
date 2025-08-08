import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/degrade_fundo.dart';

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
  String? _probioticoSelecionado;
  bool _aplicarProbiotico = false;

  Map<String, String> _viveiros = {};
  Map<String, String> _bercarios = {};
  List<String> _listaProbioticos = [];
  List<String> _listaSuplementos = [];
  String? _suplementoSelecionado;
  bool _aplicarSuplemento = false;

  DateTime _horaAtual = DateTime.now();
  String _funcaoUsuario = '';
  bool _saving = false;
  bool _temCampoPreenchido = false;

  @override
  void initState() {
    super.initState();
    _carregarDestinos();
    _carregarProbioticos();
    _carregarSuplementos();
    _carregarFuncao();
    _quantidadeCtrl.addListener(_verificarCampos);
    _sobrasCtrl.addListener(_verificarCampos);
    _obsCtrl.addListener(_verificarCampos);
  }

  void _verificarCampos() {
    setState(() {
      _temCampoPreenchido = _quantidadeCtrl.text.isNotEmpty ||
          _sobrasCtrl.text.isNotEmpty ||
          _obsCtrl.text.isNotEmpty ||
          _aplicarProbiotico;
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
    try {
      // Carregar viveiros
      final snapshotViveiros = await FirebaseFirestore.instance.collection('viveiros').get();
      final viveiros = <String, String>{};
      for (final doc in snapshotViveiros.docs) {
        final data = doc.data();
        final codigo = data['codigo']?.toString() ?? '';
        final nome = data['nome']?.toString() ?? '';
        if (codigo.isNotEmpty && nome.isNotEmpty) {
          viveiros[codigo] = nome;
        }
      }
      
      // Carregar berçários
      final snapshotBercarios = await FirebaseFirestore.instance.collection('bercarios').get();
      final bercarios = <String, String>{};
      for (final doc in snapshotBercarios.docs) {
        final data = doc.data();
        final codigo = data['codigo']?.toString() ?? '';
        final nome = data['nome']?.toString() ?? '';
        if (codigo.isNotEmpty && nome.isNotEmpty) {
          bercarios[codigo] = nome;
        }
      }
      
      setState(() {
        _viveiros = viveiros;
        _bercarios = bercarios;
      });
      
      print('DEBUG REGISTRO: Viveiros carregados: $_viveiros');
      print('DEBUG REGISTRO: Berçários carregados: $_bercarios');
    } catch (e) {
      print('DEBUG REGISTRO: Erro ao carregar destinos: $e');
    }
  }

  Future<void> _carregarProbioticos() async {
    final snap = await FirebaseFirestore.instance
        .collection('insumos')
        .where('tipo', isEqualTo: 'Probiótico')
        .get();

    setState(() {
      _listaProbioticos = snap.docs.map((doc) => doc['nome'].toString()).toList();
    });
  }

  Future<void> _carregarSuplementos() async {
    final snap = await FirebaseFirestore.instance
        .collection('insumos')
        .where('tipo', isEqualTo: 'Suplemento')
        .get();
    setState(() {
      _listaSuplementos = snap.docs.map((doc) => doc['nome'].toString()).toList();
    });
  }

  Future<bool> _destinoExiste(String codigo, String tipo) async {
    final col = tipo == 'viveiro' ? 'viveiros' : 'bercarios';
    final snap = await FirebaseFirestore.instance.collection(col).where('codigo', isEqualTo: codigo).get();
    return snap.docs.isNotEmpty;
  }

  Future<void> _darBaixaEstoque(String nome, num quantidade) async {
    final snap = await FirebaseFirestore.instance
        .collection('insumos')
        .where('nome', isEqualTo: nome)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      final doc = snap.docs.first;
      final estoqueAtual = (doc['estoque'] ?? 0) as num;
      await doc.reference.update({'estoque': estoqueAtual - quantidade});
    }
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
    final nome = _tipoSelecionado == 'viveiro' 
        ? (_viveiros[_codigoSelecionado!] ?? '---')
        : (_bercarios[_codigoSelecionado!] ?? '---');
    final doc = FirebaseFirestore.instance.collection('racao').doc();
    final user = FirebaseAuth.instance.currentUser;
    String registradoPor = '—';
    if (user != null) {
      final usuarioDoc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      registradoPor = usuarioDoc.data()?['nome'] ?? '—';
    }
    final quantidadeRacao = double.tryParse(_quantidadeCtrl.text.replaceAll(',', '.')) ?? 0;
    final suplementoAplicado = _aplicarSuplemento ? _suplementoSelecionado : null;
    await doc.set({
      'tipoDestino': _tipoSelecionado,
      'codigo': _codigoSelecionado,
      'viveiro': nome,
      'quantidade': quantidadeRacao,
      'sobras': double.tryParse(_sobrasCtrl.text.replaceAll(',', '.')) ?? 0,
      'observacoes': _obsCtrl.text.trim(),
      'probióticoAplicado': _aplicarProbiotico ? _probioticoSelecionado : null,
      'suplementoAplicado': suplementoAplicado,
      'timestamp': Timestamp.fromDate(_horaAtual),
      'registradoPor': registradoPor,
    });
    // Dar baixa no estoque
    await _darBaixaEstoque('Ração', quantidadeRacao);
    if (_aplicarProbiotico && _probioticoSelecionado != null) {
      await _darBaixaEstoque(_probioticoSelecionado!, 1);
    }
    if (_aplicarSuplemento && _suplementoSelecionado != null) {
      await _darBaixaEstoque(_suplementoSelecionado!, 1);
    }
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
                  const Center(
                    child: Column(
                      children: [
                        Icon(Icons.set_meal, size: 48, color: Colors.teal),
                        SizedBox(height: 6),
                        Text(
                          'Registrar Ração',
                          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.teal),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Registre a quantidade de ração fornecida e sobras para cada viveiro ou berçário',
                          style: TextStyle(fontSize: 15, color: Colors.teal, fontWeight: FontWeight.w400),
                          textAlign: TextAlign.center,
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
                    onChanged: (value) => setState(() {
                      _tipoSelecionado = value;
                      _codigoSelecionado = null; // Limpar código quando tipo muda
                    }),
                    validator: (v) => v == null ? 'Escolha viveiro ou berçário' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _codigoSelecionado,
                    decoration: const InputDecoration(
                      labelText: 'Código',
                      prefixIcon: Icon(Icons.code),
                    ),
                    items: (() {
                      List<DropdownMenuItem<String>> items = [];
                      
                      if (_tipoSelecionado == 'viveiro') {
                        // Mostrar apenas viveiros
                        final viveirosSorted = _viveiros.entries.toList()
                          ..sort((a, b) => a.key.compareTo(b.key));
                        
                        items = viveirosSorted
                            .map((e) => DropdownMenuItem<String>(
                                  value: e.key,
                                  child: Text('${e.value} (${e.key})'),
                                ))
                            .toList();
                      } else if (_tipoSelecionado == 'bercario') {
                        // Mostrar apenas berçários
                        final bercariosSorted = _bercarios.entries.toList()
                          ..sort((a, b) => a.key.compareTo(b.key));
                        
                        items = bercariosSorted
                            .map((e) => DropdownMenuItem<String>(
                                  value: e.key,
                                  child: Text('${e.value} (${e.key})'),
                                ))
                            .toList();
                      }
                      
                      return items;
                    })(),
                    onChanged: (value) => setState(() => _codigoSelecionado = value),
                    validator: (v) => v == null ? 'Selecione o código' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _quantidadeCtrl,
                    keyboardType: TextInputType.number,
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
                    decoration: const InputDecoration(
                      labelText: 'Sobras da Última (Kg)',
                      prefixIcon: Icon(Icons.restore_from_trash),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: _aplicarProbiotico,
                    onChanged: (val) => setState(() {
                      _aplicarProbiotico = val ?? false;
                      if (!_aplicarProbiotico) _probioticoSelecionado = null;
                    }),
                    title: const Text('Aplicar Probiótico'),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  if (_aplicarProbiotico)
                    DropdownButtonFormField<String>(
                      value: _probioticoSelecionado,
                      decoration: const InputDecoration(
                        labelText: 'Probiótico',
                        prefixIcon: Icon(Icons.medication),
                      ),
                      items: _listaProbioticos
                          .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                          .toList(),
                      onChanged: (val) => setState(() => _probioticoSelecionado = val),
                      validator: (v) => _aplicarProbiotico && v == null ? 'Selecione o probiótico' : null,
                    ),
                  // Suplemento
                  CheckboxListTile(
                    value: _aplicarSuplemento,
                    onChanged: (val) => setState(() {
                      _aplicarSuplemento = val ?? false;
                      if (!_aplicarSuplemento) _suplementoSelecionado = null;
                    }),
                    title: const Text('Aplicar Suplemento'),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  if (_aplicarSuplemento)
                    DropdownButtonFormField<String>(
                      value: _suplementoSelecionado,
                      decoration: const InputDecoration(
                        labelText: 'Suplemento',
                        prefixIcon: Icon(Icons.medical_services),
                      ),
                      items: _listaSuplementos
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (val) => setState(() => _suplementoSelecionado = val),
                      validator: (v) => _aplicarSuplemento && v == null ? 'Selecione o suplemento' : null,
                    ),
                  const SizedBox(height: 12),
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
                                setState(() => _horaAtual = DateTime(dt.year, dt.month, dt.day, tm.hour, tm.minute));
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
