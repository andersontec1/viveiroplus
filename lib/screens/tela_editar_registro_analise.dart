import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/degrade_fundo.dart';
import '../widgets/analise_agua_form.dart';

class TelaEditarRegistroAnalise extends StatefulWidget {
  const TelaEditarRegistroAnalise({required this.docId, required this.data, super.key, this.onSalvo});
  final String docId;
  final Map<String, dynamic> data;
  final void Function()? onSalvo;

  @override
  State<TelaEditarRegistroAnalise> createState() => _TelaEditarRegistroAnaliseState();
}

class _TelaEditarRegistroAnaliseState extends State<TelaEditarRegistroAnalise> {
  bool _saving = false;

  Future<void> _onSalvar(Map<String, dynamic> dados) async {
    setState(() => _saving = true);
    
    try {
      await FirebaseFirestore.instance.collection('registros_diarios').doc(widget.docId).update(dados);
      
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar: $e')),
      );
    } finally {
      setState(() => _saving = false);
    }
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
          child: AnaliseAguaForm(
            modoEdicao: true,
            dadosIniciais: widget.data,
            mostrarSeletorDestino: false,
            onSalvar: _saving ? null : _onSalvar,
            onCancelar: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }
}
