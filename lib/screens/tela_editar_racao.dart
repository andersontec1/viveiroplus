import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/degrade_fundo.dart';

class TelaEditarRacao extends StatefulWidget {
  const TelaEditarRacao({required this.docId, required this.data, super.key, this.onSalvo});
  final String docId;
  final Map<String, dynamic> data;
  final void Function()? onSalvo;

  @override
  State<TelaEditarRacao> createState() => _TelaEditarRacaoState();
}

class _TelaEditarRacaoState extends State<TelaEditarRacao> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _qtdCtrl;
  late TextEditingController _sobrasCtrl;
  late TextEditingController _obsCtrl;
  late TextEditingController _probioticoCtrl;
  late DateTime _registroDt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _qtdCtrl = TextEditingController(text: widget.data['quantidade']?.toString() ?? '');
    _sobrasCtrl = TextEditingController(text: widget.data['sobras']?.toString() ?? '');
    _obsCtrl = TextEditingController(text: widget.data['observacoes'] ?? '');
    _probioticoCtrl = TextEditingController(text: widget.data['probióticoAplicado'] ?? '');
    _registroDt = (widget.data['timestamp'] as Timestamp).toDate();
  }

  @override
  void dispose() {
    _qtdCtrl.dispose();
    _sobrasCtrl.dispose();
    _obsCtrl.dispose();
    _probioticoCtrl.dispose();
    super.dispose();
  }

  String _formatDateTime(DateTime dt) {
    return DateFormat('dd/MM/yyyy HH:mm').format(dt);
  }

  Future<void> _onSalvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await FirebaseFirestore.instance.collection('racao').doc(widget.docId).update({
      'quantidade': double.tryParse(_qtdCtrl.text) ?? 0.0,
      'sobras': double.tryParse(_sobrasCtrl.text) ?? 0.0,
      'observacoes': _obsCtrl.text.trim(),
      'probióticoAplicado': _probioticoCtrl.text.trim(),
      'timestamp': Timestamp.fromDate(_registroDt),
    });
    setState(() => _saving = false);
    if (widget.onSalvo != null) widget.onSalvo!();
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Registro de Ração'),
        backgroundColor: Colors.teal,
      ),
      body: DegradeFundo(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  controller: _qtdCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Quantidade (kg)',
                    prefixIcon: Icon(Icons.scale_rounded),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Informe a quantidade' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _sobrasCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Sobras (kg)',
                    prefixIcon: Icon(Icons.recycling_rounded),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Informe as sobras' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _probioticoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Probiótico Aplicado',
                    prefixIcon: Icon(Icons.medical_services_rounded),
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
                const SizedBox(height: 12),
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
