import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/degrade_fundo.dart';
import '../widgets/analise_agua_form.dart';

class TelaAnaliseAgua extends StatefulWidget {
  const TelaAnaliseAgua({super.key});
  @override
  _TelaAnaliseAguaState createState() => _TelaAnaliseAguaState();
}

class _TelaAnaliseAguaState extends State<TelaAnaliseAgua> {
  bool _salvando = false;
  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Análise da Água',
      body: DegradeFundo(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 10),
              const Center(
                child: Column(
                  children: [
                    Icon(Icons.science, size: 48),
                    SizedBox(height: 6),
                    Text(
                      'Análise da Água',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Registre os parâmetros de qualidade da água dos viveiros e berçários de forma rápida e segura',
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
              ),
              Expanded(
                child: AnaliseAguaForm(
                  modoEdicao: false,
                  mostrarSeletorDestino: true,
                  onSalvar: _salvarRegistro,
                  onCancelar: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _salvarRegistro(Map<String, dynamic> dados) async {
    if (_salvando) return; // evita múltiplos envios
    setState(() => _salvando = true);
    try {
      // Uso de ID automático novamente para permitir múltiplas leituras no mesmo minuto
      await FirebaseFirestore.instance
          .collection('registros_diarios')
          .add(dados);

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: Colors.green.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 32),
              SizedBox(width: 8),
              Text(
                'Registro Salvo!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A análise foi registrada com sucesso.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                'Você pode consultar ou editar este registro na tela de listagem.',
                style: TextStyle(color: Colors.teal),
              ),
            ],
          ),
          actions: [
            ElevatedButton.icon(
              icon: const Icon(Icons.done, color: Colors.white),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () => Navigator.of(context).pop(),
              label: const Text(
                'Fechar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao salvar registro: $e')));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }
}
