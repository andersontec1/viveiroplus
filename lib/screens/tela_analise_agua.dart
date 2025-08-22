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
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Registre os parâmetros de qualidade da água dos viveiros e berçários de forma rápida e segura',
                      style: TextStyle(fontSize: 15, color: Colors.teal, fontWeight: FontWeight.w400),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 20),
                  ],
                ),
              ),
              // Card informativo de horários e parâmetros
              Card(
                color: const Color(0xFFe3f2fd),
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 18),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.schedule, color: Colors.blue, size: 22),
                          SizedBox(width: 8),
                          Text('Horários e Parâmetros de Análise', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _linhaHorario('4:00', 'Oxigênio e Saturação'),
                      _linhaHorario('8:00', 'pH, Amônia e Nitrito'),
                      _linhaHorario('13:00', 'Turbidez(NTU), Temperatura e Salinidade'),
                      _linhaHorario('16:00', 'pH, Oxigênio e Saturação'),
                      const SizedBox(height: 8),
                      const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange, size: 18),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Obs: Amônia e Nitrito — 1 Vez por semana nos Viveiros, e 3 Vezes por Semana nos Berçários.',
                              style: TextStyle(fontSize: 13, color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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
    try {
      await FirebaseFirestore.instance.collection('registros_diarios').add(dados);
      
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: Colors.green.shade50,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 32),
              SizedBox(width: 8),
              Text('Registro Salvo!', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('A análise foi registrada com sucesso.', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              Text('Você pode consultar ou editar este registro na tela de listagem.', style: TextStyle(color: Colors.teal)),
            ],
          ),
          actions: [
            ElevatedButton.icon(
              icon: const Icon(Icons.done, color: Colors.white),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () => Navigator.of(context).pop(),
              label: const Text('Fechar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar registro: $e')),
      );
    }
  }

  Widget _linhaHorario(String hora, String parametros) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(hora, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(parametros, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }
}
