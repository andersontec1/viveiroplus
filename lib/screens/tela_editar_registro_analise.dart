import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../widgets/degrade_fundo.dart';

class TelaEditarRegistroAnalise extends StatefulWidget {
  const TelaEditarRegistroAnalise({required this.docId, required this.data, super.key, this.onSalvo});
  final String docId;
  final Map<String, dynamic> data;
  final void Function()? onSalvo;

  @override
  State<TelaEditarRegistroAnalise> createState() => _TelaEditarRegistroAnaliseState();
}

class _TelaEditarRegistroAnaliseState extends State<TelaEditarRegistroAnalise> {
  String? _nomeUsuario;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _phCtrl;
  late TextEditingController _oxCtrl;
  late TextEditingController _tempCtrl;
  late TextEditingController _salinityCtrl;
  late TextEditingController _calcCtrl;
  late TextEditingController _nitritoCtrl;
  late TextEditingController _amoniaCtrl;
  late TextEditingController _turbidezCtrl;
  late TextEditingController _saturacaoPorcCtrl;
  late TextEditingController _saturacaoOxCtrl;
  late TextEditingController _obsCtrl;
  late DateTime _registroDt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _phCtrl = TextEditingController(text: widget.data['ph']?.toString() ?? '');
    _oxCtrl = TextEditingController(text: widget.data['oxigenio']?.toString() ?? '');
    _tempCtrl = TextEditingController(text: widget.data['temperatura']?.toString() ?? '');
    _salinityCtrl = TextEditingController(text: widget.data['salinidade']?.toString() ?? '');
    _calcCtrl = TextEditingController(text: widget.data['calcio']?.toString() ?? '');
    _nitritoCtrl = TextEditingController(text: widget.data['nitrito']?.toString() ?? '');
    _amoniaCtrl = TextEditingController(text: widget.data['amonia']?.toString() ?? '');
    _turbidezCtrl = TextEditingController(text: widget.data['turbidez']?.toString() ?? '');
    _saturacaoPorcCtrl = TextEditingController(text: widget.data['saturacao_percentual']?.toString() ?? '');
    _saturacaoOxCtrl = TextEditingController(text: widget.data['saturacao_oxigenio']?.toString() ?? '');
    _obsCtrl = TextEditingController(text: widget.data['observacoes'] ?? '');
    _registroDt = (widget.data['dataHora'] as Timestamp).toDate();
    _carregarNomeUsuario();

  }

  Future<void> _carregarNomeUsuario() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      setState(() {
        _nomeUsuario = doc.data()?['nome'] ?? user.email ?? user.uid;
      });
    }
  }

  String _formatDateTime(DateTime dt) {
    return DateFormat('dd/MM/yyyy HH:mm').format(dt);
  }

  @override
  void dispose() {
    _phCtrl.dispose();
    _oxCtrl.dispose();
    _tempCtrl.dispose();
    _salinityCtrl.dispose();
    _calcCtrl.dispose();
    _nitritoCtrl.dispose();
    _amoniaCtrl.dispose();
    _turbidezCtrl.dispose();
    _saturacaoPorcCtrl.dispose();
    _saturacaoOxCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  bool _foraFaixa(String tipo, double valor) {
    switch (tipo) {
      case 'ph': return valor < 7.5 || valor > 8.5;
      case 'ox': return valor < 5.0 || valor > 8.0;
      case 'temp': return valor < 28.0 || valor > 32.0;
      case 'sal': return valor < 15.0 || valor > 25.0;
      case 'calc': return valor < 100 || valor > 300;
      case 'nitrito': return valor > 1.0;
      case 'amonia': return valor > 0.5;
      case 'turbidez': return valor < 0.0 || valor > 50.0;
      case 'saturacao_percentual': return valor < 80.0 || valor > 120.0;
      case 'saturacao_oxigenio': return valor < 80.0 || valor > 120.0;
      default: return false;
    }
  }

  Widget _campoNumComFaixa(TextEditingController controller, String label, IconData icon,
      double min, double max, String tipo, {bool obrigatorio = false}) {
    final text = controller.text;
    final valor = double.tryParse(text);
    final fora = valor != null && _foraFaixa(tipo, valor);
    Color? fillColor;
    Color? borderColor;
    if (fora) {
      fillColor = Colors.red.shade100;
      borderColor = Colors.red;
    }
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
            fillColor: fillColor,
            filled: fora,
            enabledBorder: borderColor != null
                ? OutlineInputBorder(
                    borderSide: BorderSide(color: borderColor, width: 1.5),
                    borderRadius: BorderRadius.circular(8),
                  )
                : null,
            focusedBorder: borderColor != null
                ? OutlineInputBorder(
                    borderSide: BorderSide(color: borderColor, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  )
                : null,
          ),
          validator: obrigatorio
              ? (v) => v == null || v.isEmpty ? 'Informe $label' : null
              : null,
          onChanged: (_) => setState(() {}),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 4),
          child: Text(
            'Faixa ideal: $min – $max Fora disso, notifique o supervisor.',
            style: TextStyle(fontSize: 15, color: fora ? Colors.red : Colors.teal),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Future<void> _onSalvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    
    print('DEBUG EDIT: Usuário editando: $_nomeUsuario');
    
    final updateData = {
      'ph': double.tryParse(_phCtrl.text) ?? 0.0,
      'oxigenio': double.tryParse(_oxCtrl.text) ?? 0.0,
      'temperatura': double.tryParse(_tempCtrl.text) ?? 0.0,
      'salinidade': double.tryParse(_salinityCtrl.text) ?? 0.0,
      'calcio': double.tryParse(_calcCtrl.text) ?? 0.0,
      'nitrito': double.tryParse(_nitritoCtrl.text) ?? 0.0,
      'amonia': double.tryParse(_amoniaCtrl.text) ?? 0.0,
      'turbidez': double.tryParse(_turbidezCtrl.text) ?? 0.0,
      'saturacao_percentual': double.tryParse(_saturacaoPorcCtrl.text) ?? 0.0,
      'saturacao_oxigenio': double.tryParse(_saturacaoOxCtrl.text) ?? 0.0,
      'observacoes': _obsCtrl.text.trim(),
      'dataHora': Timestamp.fromDate(_registroDt),
      'editadoPor': _nomeUsuario ?? '',
      'editadoEm': Timestamp.now(),
    };
    
    print('DEBUG EDIT: Dados de auditoria - editadoPor: ${updateData['editadoPor']}, editadoEm: ${updateData['editadoEm']}');
    
    await FirebaseFirestore.instance.collection('registros_diarios').doc(widget.docId).update(updateData);
    setState(() => _saving = false);
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Container(
          padding: const EdgeInsets.all(0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFB2DFDB),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                ),
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: const Column(
                  children: [
                    Icon(Icons.check_circle, color: Colors.teal, size: 38),
                    SizedBox(height: 6),
                    Text('Sucesso!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                child: Column(
                  children: [
                    Text('Registro atualizado com sucesso.', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (widget.onSalvo != null) widget.onSalvo!();
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Análise de Água'),
        backgroundColor: Colors.teal,
      ),
      body: DegradeFundo(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                _campoNumComFaixa(_phCtrl, 'pH da Água', Icons.grain, 7.5, 8.5, 'ph', obrigatorio: false),
                _campoNumComFaixa(_oxCtrl, 'Oxigênio Dissolvido (mg/L)', Icons.air, 5.0, 8.0, 'ox', obrigatorio: false),
                _campoNumComFaixa(_tempCtrl, 'Temperatura (°C)', Icons.thermostat, 28.0, 32.0, 'temp', obrigatorio: false),
                _campoNumComFaixa(_turbidezCtrl, 'Turbidez (NTU)', Icons.blur_on, 0.0, 50.0, 'turbidez', obrigatorio: false),
                _campoNumComFaixa(_saturacaoPorcCtrl, 'Porcentagem de Saturação (%)', Icons.percent, 80.0, 120.0, 'saturacao_percentual', obrigatorio: false),
                _campoNumComFaixa(_saturacaoOxCtrl, 'Saturação de O2 Dissolvido (%)', Icons.bubble_chart, 80.0, 120.0, 'saturacao_oxigenio', obrigatorio: false),
                _campoNumComFaixa(_salinityCtrl, 'Salinidade (ppt)', Icons.opacity, 15.0, 25.0, 'sal', obrigatorio: false),
                _campoNumComFaixa(_calcCtrl, 'Cálcio (mg/L)', Icons.science_outlined, 100.0, 300.0, 'calc', obrigatorio: false),
                _campoNumComFaixa(_nitritoCtrl, 'Nitrito (mg/L)', Icons.warning_amber, 0.0, 1.0, 'nitrito', obrigatorio: false),
                _campoNumComFaixa(_amoniaCtrl, 'Amônia (mg/L)', Icons.dangerous, 0.0, 0.5, 'amonia', obrigatorio: false),
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
                            setState(() => _registroDt = DateTime(dt.year, dt.month, dt.day, tm.hour, tm.minute));
                          }
                        }
                      },
                    ),
                    hintText: _formatDateTime(_registroDt),
                  ),
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
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : () => Navigator.of(context).pop(),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saving ? null : _onSalvar,
                        child: _saving ? const CircularProgressIndicator() : const Text('Salvar Alterações'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
