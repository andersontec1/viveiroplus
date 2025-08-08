// Tela de Notificações / Pendências
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/degrade_fundo.dart';

class TelaPendencias extends StatefulWidget {
  const TelaPendencias({super.key});

  @override
  State<TelaPendencias> createState() => _TelaPendenciasState();
}

class _TelaPendenciasState extends State<TelaPendencias> {
  final DateTime hoje = DateTime.now();
  final List<int> horariosIdeais = [6, 9, 12, 15, 18];
  Map<String, String> _mapaDestinos = {};
  String? _tipoSelecionado = 'viveiro';

  @override
  void initState() {
    super.initState();
    _carregarDestinos();
  }

  Future<void> _carregarDestinos() async {
    final mapa = <String, String>{};
    final snapV = await FirebaseFirestore.instance.collection('viveiros').get();
    for (final doc in snapV.docs) {
      final d = doc.data();
      mapa[d['codigo']] = d['nome'];
    }
    final snapB = await FirebaseFirestore.instance.collection('bercarios').get();
    for (final doc in snapB.docs) {
      final d = doc.data();
      mapa[d['codigo']] = d['nome'];
    }
    setState(() => _mapaDestinos = mapa);
  }

  Future<List<Map<String, dynamic>>> _gerarPendencias() async {
    final List<Map<String, dynamic>> pendencias = [];
    final inicio = DateTime(hoje.year, hoje.month, hoje.day);
    final fim = inicio.add(const Duration(days: 1));

    final registrosRacao = await FirebaseFirestore.instance
        .collection('racao')
        .where('tipoDestino', isEqualTo: _tipoSelecionado)
        .where('timestamp', isGreaterThanOrEqualTo: inicio)
        .where('timestamp', isLessThan: fim)
        .get();

    final registrosAnalise = await FirebaseFirestore.instance
        .collection('registros_diarios')
        .where('tipoDestino', isEqualTo: _tipoSelecionado)
        .where('dataHora', isGreaterThanOrEqualTo: inicio)
        .where('dataHora', isLessThan: fim)
        .get();

    for (final codigo in _mapaDestinos.keys) {
      final nome = _mapaDestinos[codigo] ?? '—';

      final racaoDoDia = registrosRacao.docs.where((d) => d['codigo'] == codigo).toList();
      final analiseDoDia = registrosAnalise.docs.where((d) => d['codigo'] == codigo).toList();

      if (racaoDoDia.isEmpty) {
        pendencias.add({'codigo': codigo, 'nome': nome, 'tipo': 'Ração', 'status': '❌ Nenhum registro'});
      } else {
        for (final h in horariosIdeais) {
          final hasIdeal = racaoDoDia.any((doc) {
            final hora = (doc['timestamp'] as Timestamp).toDate().hour;
            return hora == h;
          });
          if (!hasIdeal) {
            pendencias.add({'codigo': codigo, 'nome': nome, 'tipo': 'Ração', 'status': '⚠️ Ausente no horário $h:00'});
          }
        }
      }

      if (analiseDoDia.isEmpty) {
        pendencias.add({'codigo': codigo, 'nome': nome, 'tipo': 'Análise', 'status': '❌ Nenhum registro'});
      } else {
        for (final h in horariosIdeais) {
          final hasIdeal = analiseDoDia.any((doc) {
            final hora = (doc['dataHora'] as Timestamp).toDate().hour;
            return hora == h;
          });
          if (!hasIdeal) {
            pendencias.add({'codigo': codigo, 'nome': nome, 'tipo': 'Análise', 'status': '⚠️ Ausente no horário $h:00'});
          }
        }
      }
    }

    return pendencias;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Pendências de Hoje',
      body: DegradeFundo(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: _tipoSelecionado,
                items: const [
                  DropdownMenuItem(value: 'viveiro', child: Text('Viveiro')),
                  DropdownMenuItem(value: 'bercario', child: Text('Berçário')),
                ],
                onChanged: (val) => setState(() => _tipoSelecionado = val),
                decoration: const InputDecoration(labelText: 'Tipo de Destino'),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _gerarPendencias(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final pendencias = snapshot.data!;
                    if (pendencias.isEmpty) {
                      return const Center(child: Text('Nenhuma pendência encontrada!'));
                    }
                    return ListView.builder(
                      itemCount: pendencias.length,
                      itemBuilder: (context, index) {
                        final item = pendencias[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.warning_amber, color: Colors.orange),
                            title: Text('${item['nome']} (${item['codigo']})'),
                            subtitle: Text('${item['tipo']} • ${item['status']}'),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
