// tela_relatorios.dart adaptada para Flutter Mobile/Web
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/degrade_fundo.dart'; // adicione este import
import '../widgets/responsive_center.dart';
import 'exportador_csv_mobile.dart'
    if (dart.library.html) 'exportador_csv_web.dart'
    as exportador;
import '../helpers/export_helper.dart';
import 'package:fl_chart/fl_chart.dart';

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
  bool _exportando = false;

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
    final snapViveiros = await FirebaseFirestore.instance
        .collection('viveiros')
        .get();
    for (final doc in snapViveiros.docs) {
      final data = doc.data();
      mapa[data['codigo']] = data['nome'];
    }
    final snapBercarios = await FirebaseFirestore.instance
        .collection('bercarios')
        .get();
    for (final doc in snapBercarios.docs) {
      final data = doc.data();
      mapa[data['codigo']] = data['nome'];
    }
    setState(() => _destinos = mapa);
  }

  Future<void> _carregarRegistros() async {
    final inicio = DateTime(
      dataSelecionada!.year,
      dataSelecionada!.month,
      dataSelecionada!.day,
    );
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
    if (tipoSelecionado != null && reg['tipoDestino'] != tipoSelecionado)
      return false;
    if (codigoSelecionado != null && reg['codigo'] != codigoSelecionado)
      return false;
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
      ['Tipo', 'Código', 'Nome', 'Horário', 'Status'],
    ];

    for (final h in horariosAnalise) {
      rows.add([
        'Análise de Água',
        codigoSelecionado ?? '-',
        _destinos[codigoSelecionado] ?? '-',
        h['label'],
        _status(
          registrosAnalise.map((r) => r['hora'] as DateTime).toList(),
          h['ini'],
          h['fim'],
        ),
      ]);
    }
    for (final h in horariosRacao) {
      rows.add([
        'Ração',
        codigoSelecionado ?? '-',
        _destinos[codigoSelecionado] ?? '-',
        h['label'],
        _status(
          registrosRacao.map((r) => r['hora'] as DateTime).toList(),
          h['ini'],
          h['fim'],
        ),
      ]);
    }

    exportador.exportarCsv(rows, nomeArquivo: 'relatorio.csv');
  }

  Widget _buildLegenda(String simbolo, String descricao, Color cor) {
    return Row(
      children: [
        Text(simbolo, style: TextStyle(fontSize: 18, color: cor)),
        const SizedBox(width: 4),
        Text(descricao, style: const TextStyle(fontSize: 16)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Cálculo dos status para gráfico
    final analiseStatus = horariosAnalise
        .map(
          (h) => _status(
            registrosAnalise.map((r) => r['hora'] as DateTime).toList(),
            h['ini'],
            h['fim'],
          ),
        )
        .toList();
    final racaoStatus = horariosRacao
        .map(
          (h) => _status(
            registrosRacao.map((r) => r['hora'] as DateTime).toList(),
            h['ini'],
            h['fim'],
          ),
        )
        .toList();
    final analiseCount = [
      analiseStatus.where((s) => s == '✅').length,
      analiseStatus.where((s) => s == '⚠️').length,
      analiseStatus.where((s) => s == '❌').length,
    ];
    final racaoCount = [
      racaoStatus.where((s) => s == '✅').length,
      racaoStatus.where((s) => s == '⚠️').length,
      racaoStatus.where((s) => s == '❌').length,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Relatório por Horário')),
      body: DegradeFundo(
        child: ResponsiveCenter(
          padding: const EdgeInsets.all(16),
          alignment: Alignment.topCenter,
          child: Column(
            children: [
              // Gráfico de barras resumo
              SizedBox(
                height: 180,
                child: BarChart(
                  BarChartData(
                    barGroups: [
                      BarChartGroupData(
                        x: 0,
                        barRods: [
                          BarChartRodData(
                            toY: analiseCount[0].toDouble(),
                            color: Colors.green,
                            width: 18,
                          ),
                          BarChartRodData(
                            toY: analiseCount[1].toDouble(),
                            color: Colors.orange,
                            width: 18,
                          ),
                          BarChartRodData(
                            toY: analiseCount[2].toDouble(),
                            color: Colors.red,
                            width: 18,
                          ),
                        ],
                      ),
                      BarChartGroupData(
                        x: 1,
                        barRods: [
                          BarChartRodData(
                            toY: racaoCount[0].toDouble(),
                            color: Colors.green,
                            width: 18,
                          ),
                          BarChartRodData(
                            toY: racaoCount[1].toDouble(),
                            color: Colors.orange,
                            width: 18,
                          ),
                          BarChartRodData(
                            toY: racaoCount[2].toDouble(),
                            color: Colors.red,
                            width: 18,
                          ),
                        ],
                      ),
                    ],
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            switch (value.toInt()) {
                              case 0:
                                return const Text(
                                  'Análise',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                );
                              case 1:
                                return const Text(
                                  'Ração',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                );
                            }
                            return const SizedBox();
                          },
                        ),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    barTouchData: const BarTouchData(enabled: true),
                    gridData: const FlGridData(show: true),
                    borderData: FlBorderData(show: false),
                    groupsSpace: 32,
                    maxY:
                        [analiseCount, racaoCount]
                            .expand((e) => e)
                            .fold(0, (a, b) => a > b ? a : b)
                            .toDouble() +
                        1,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegenda('✅', 'No horário', Colors.green),
                  const SizedBox(width: 12),
                  _buildLegenda('⚠️', 'Fora horário', Colors.orange),
                  const SizedBox(width: 12),
                  _buildLegenda('❌', 'Não realizado', Colors.red),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: tipoSelecionado,
                      decoration: const InputDecoration(labelText: 'Tipo'),
                      items: const [
                        DropdownMenuItem(
                          value: 'viveiro',
                          child: Text('Viveiro'),
                        ),
                        DropdownMenuItem(
                          value: 'bercario',
                          child: Text('Berçário'),
                        ),
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
                      initialValue: codigoSelecionado,
                      decoration: const InputDecoration(labelText: 'Código'),
                      items: _destinos.entries
                          .where((e) {
                            final isBercario = e.key.toLowerCase().contains(
                              'b',
                            );
                            return tipoSelecionado == 'bercario'
                                ? isBercario
                                : !isBercario;
                          })
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text('${e.value} (cód: ${e.key})'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() {
                        codigoSelecionado = v;
                        _carregarRegistros();
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'Data: ${DateFormat('dd/MM/yyyy').format(dataSelecionada!)}',
                  ),
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
                    const Text(
                      'Análise da Água:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ...horariosAnalise.map(
                      (h) => ListTile(
                        leading: Text(
                          _status(
                            registrosAnalise
                                .map((r) => r['hora'] as DateTime)
                                .toList(),
                            h['ini'],
                            h['fim'],
                          ),
                          style: const TextStyle(fontSize: 18),
                        ),
                        title: Text(h['label']),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Ração:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ...horariosRacao.map(
                      (h) => ListTile(
                        leading: Text(
                          _status(
                            registrosRacao
                                .map((r) => r['hora'] as DateTime)
                                .toList(),
                            h['ini'],
                            h['fim'],
                          ),
                          style: const TextStyle(fontSize: 18),
                        ),
                        title: Text(h['label']),
                      ),
                    ),
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
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _exportando
                          ? null
                          : () async {
                              setState(() => _exportando = true);
                              try {
                                await ExportHelper.exportarExcel(
                                  codigo: codigoSelecionado,
                                );
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Falha ao exportar Excel: $e',
                                      ),
                                    ),
                                  );
                                }
                              } finally {
                                if (mounted)
                                  setState(() => _exportando = false);
                              }
                            },
                      icon: const Icon(Icons.table_view),
                      label: Text(
                        _exportando ? 'Gerando...' : 'Exportar Excel',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _exportando
                          ? null
                          : () async {
                              setState(() => _exportando = true);
                              try {
                                await ExportHelper.exportarPdf(
                                  codigo: codigoSelecionado,
                                  onDone: (nome, path) {
                                    if (mounted) {
                                      final msg = path == null
                                          ? 'PDF baixado: ' + nome
                                          : 'PDF salvo: ' +
                                                nome +
                                                ("\n" + path);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(content: Text(msg)),
                                      );
                                    }
                                  },
                                );
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Falha ao exportar PDF: $e',
                                      ),
                                    ),
                                  );
                                }
                              } finally {
                                if (mounted)
                                  setState(() => _exportando = false);
                              }
                            },
                      icon: const Icon(Icons.picture_as_pdf),
                      label: Text(_exportando ? 'Gerando...' : 'Exportar PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent.shade400,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
