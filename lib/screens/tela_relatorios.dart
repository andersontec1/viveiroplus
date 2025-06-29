// tela_relatorios.dart adaptada para Flutter Mobile/Web
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/degrade_fundo.dart'; // adicione este import
import 'exportador_csv_mobile.dart' if (dart.library.html) 'exportador_csv_web.dart';

class TelaRelatorios extends StatefulWidget {
  const TelaRelatorios({super.key});

  @override
  State<TelaRelatorios> createState() => _TelaRelatoriosState();
}

class _TelaRelatoriosState extends State<TelaRelatorios> {
  String? tipoSelecionado;
  String? codigoSelecionado;
  DateTime? dataSelecionada = DateTime.now();
  Map<String, String> _destinos = {};
  List<Map<String, dynamic>> registrosAnalise = [];
  List<Map<String, dynamic>> registrosRacao = [];

  final List<Map<String, dynamic>> horariosAnalise = [
    {'label': '6h–7h', 'ini': 6 * 60, 'fim': 7 * 60},
    {'label': '9h–10h', 'ini': 9 * 60, 'fim': 10 * 60},
    {'label': '13h–14h', 'ini': 13 * 60, 'fim': 14 * 60},
    {'label': '16h–17h', 'ini': 16 * 60, 'fim': 17 * 60},
  ];

  final List<Map<String, dynamic>> horariosRacao = [
    {'label': 'Aplicação 1', 'ini': 7 * 60, 'fim': 8 * 60},
    {'label': 'Aplicação 2', 'ini': 12 * 60, 'fim': 13 * 60},
    {'label': 'Aplicação 3', 'ini': 17 * 60, 'fim': 18 * 60},
  ];

  @override
  void initState() {
    super.initState();
    _carregarDestinos();
    _carregarRegistros();
  }

  Future<void> _carregarDestinos() async {
    final mapa = <String, String>{};
    final snapViveiros = await FirebaseFirestore.instance.collection('viveiros').get();
    for (final doc in snapViveiros.docs) {
      final data = doc.data();
      mapa[data['codigo']] = data['nome'];
    }
    final snapBercarios = await FirebaseFirestore.instance.collection('bercarios').get();
    for (final doc in snapBercarios.docs) {
      final data = doc.data();
      mapa[data['codigo']] = data['nome'];
    }
    setState(() => _destinos = mapa);
  }

  Future<void> _carregarRegistros() async {
    final inicio = DateTime(dataSelecionada!.year, dataSelecionada!.month, dataSelecionada!.day);
    final fim = inicio.add(const Duration(days: 1));

    final analise = await FirebaseFirestore.instance
        .collection('registros_diarios')
        .where('dataHora', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('dataHora', isLessThan: Timestamp.fromDate(fim))
        .get();

    final racao = await FirebaseFirestore.instance
        .collection('racao')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('timestamp', isLessThan: Timestamp.fromDate(fim))
        .get();

    registrosAnalise = analise.docs
        .map((e) => e.data()..['hora'] = (e['dataHora'] as Timestamp).toDate())
        .where((e) => _filtrarRegistro(e))
        .toList();

    registrosRacao = racao.docs
        .map((e) => e.data()..['hora'] = (e['timestamp'] as Timestamp).toDate())
        .where((e) => _filtrarRegistro(e))
        .toList();

    setState(() {});
  }

  bool _filtrarRegistro(Map<String, dynamic> reg) {
    if (tipoSelecionado != null && reg['tipoDestino'] != tipoSelecionado) return false;
    if (codigoSelecionado != null && reg['codigo'] != codigoSelecionado) return false;
    return true;
  }

  String _status(List<DateTime> registros, int ini, int fim) {
    bool dentro = registros.any((dt) {
      final minuto = dt.hour * 60 + dt.minute;
      return minuto >= ini && minuto <= fim;
    });
    bool fora = registros.any((dt) {
      final minuto = dt.hour * 60 + dt.minute;
      return minuto < ini || minuto > fim;
    });
    if (dentro) return '✅';
    if (fora) return '⚠️';
    return '❌';
  }

  void _exportarCSV() {
    final List<List<dynamic>> rows = [
      ['Tipo', 'Código', 'Nome', 'Horário', 'Status']
    ];

    for (final h in horariosAnalise) {
      rows.add([
        'Análise de Água',
        codigoSelecionado ?? '-',
        _destinos[codigoSelecionado] ?? '-',
        h['label'],
        _status(registrosAnalise.map((r) => r['hora'] as DateTime).toList(), h['ini'], h['fim'])
      ]);
    }
    for (final h in horariosRacao) {
      rows.add([
        'Ração',
        codigoSelecionado ?? '-',
        _destinos[codigoSelecionado] ?? '-',
        h['label'],
        _status(registrosRacao.map((r) => r['hora'] as DateTime).toList(), h['ini'], h['fim'])
      ]);
    }

    exportarCsv(rows, nomeArquivo: 'relatorio.csv');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Relatório por Horário')),
      body: DegradeFundo(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: tipoSelecionado,
                    decoration: const InputDecoration(labelText: 'Tipo'),
                    items: const [
                      DropdownMenuItem(value: 'viveiro', child: Text('Viveiro')),
                      DropdownMenuItem(value: 'bercario', child: Text('Berçário')),
                    ],
                    onChanged: (v) => setState(() {
                      tipoSelecionado = v;
                      codigoSelecionado = null;
                      _carregarRegistros();
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: codigoSelecionado,
                    decoration: const InputDecoration(labelText: 'Código'),
                    items: _destinos.entries
                        .where((e) {
                          final isBercario = e.key.toLowerCase().contains('b');
                          return tipoSelecionado == 'bercario' ? isBercario : !isBercario;
                        })
                        .map((e) => DropdownMenuItem(
                              value: e.key,
                              child: Text('${e.value} (cód: ${e.key})'),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() {
                      codigoSelecionado = v;
                      _carregarRegistros();
                    }),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('Data: ${DateFormat('dd/MM/yyyy').format(dataSelecionada!)}'),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: const Text('Escolher Data'),
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: dataSelecionada!,
                        firstDate: DateTime(2024),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() => dataSelecionada = date);
                        _carregarRegistros();
                      }
                    },
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  children: [
                    const Text('Análise da Água:', style: TextStyle(fontWeight: FontWeight.bold)),
                    ...horariosAnalise.map((h) => ListTile(
                          leading: Text(
                            _status(registrosAnalise.map((r) => r['hora'] as DateTime).toList(), h['ini'], h['fim']),
                            style: const TextStyle(fontSize: 18),
                          ),
                          title: Text(h['label']),
                        )),
                    const SizedBox(height: 16),
                    const Text('Ração:', style: TextStyle(fontWeight: FontWeight.bold)),
                    ...horariosRacao.map((h) => ListTile(
                          leading: Text(
                            _status(registrosRacao.map((r) => r['hora'] as DateTime).toList(), h['ini'], h['fim']),
                            style: const TextStyle(fontSize: 18),
                          ),
                          title: Text(h['label']),
                        )),
                    const SizedBox(height: 16),
                    const Divider(),
                    const Text(
                      'Legenda: ✅ dentro do horário, ⚠️ fora do horário, ❌ não realizado',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _exportarCSV,
                icon: const Icon(Icons.download),
                label: const Text('Exportar CSV'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
