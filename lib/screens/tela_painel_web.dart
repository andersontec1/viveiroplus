import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../widgets/painel_graficos.dart';

class TelaPainelWeb extends StatefulWidget {
  const TelaPainelWeb({super.key});

  @override
  State<TelaPainelWeb> createState() => _TelaPainelWebState();
}

enum PeriodoPainel { dia, semana, mes }

class _TelaPainelWebState extends State<TelaPainelWeb> {

  String _tipoSelecionado = 'viveiro';
  String? _codigoSelecionado;
  DateTime _dataSelecionada = DateTime.now();
  PeriodoPainel _periodo = PeriodoPainel.dia;
  Timer? _timer;

  int totalAnalises = 0;
  double mediaPh = 0.0;
  double mediaOxigenio = 0.0;
  double mediaTemperatura = 0.0;
  double totalRacao = 0.0;
  String horaUltimaAtualizacao = '--:--';
  Map<String, dynamic>? cicloAtivo;
  double? biomassaAtual;
  double? sobrevivenciaAtual;

  List<Map<String, dynamic>> historicoAnalises = [];
  List<Map<String, dynamic>> historicoRacao = [];

  @override
  void initState() {
    super.initState();
    _carregarDados();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _carregarDados());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    if (_codigoSelecionado == null) return;
    final id = _codigoSelecionado!;
    DateTime inicio, fim;
    switch (_periodo) {
      case PeriodoPainel.dia:
        inicio = DateTime(_dataSelecionada.year, _dataSelecionada.month, _dataSelecionada.day);
        fim = inicio.add(const Duration(days: 1));
        break;
      case PeriodoPainel.semana:
        inicio = _dataSelecionada.subtract(Duration(days: _dataSelecionada.weekday - 1));
        fim = inicio.add(const Duration(days: 7));
        break;
      case PeriodoPainel.mes:
        inicio = DateTime(_dataSelecionada.year, _dataSelecionada.month, 1);
        fim = DateTime(_dataSelecionada.year, _dataSelecionada.month + 1, 1);
        break;
    }
    await _carregarCicloAtivo(id);
    await _carregarBiomassaAtual(id);
    await _carregarHistoricoAnalises(id, inicio, fim);
    await _carregarHistoricoRacao(id, inicio, fim);
    // Médias e totais
    double somaPh = 0, somaOxigenio = 0, somaTemperatura = 0;
    for (final e in historicoAnalises) {
      somaPh += e['ph'];
      somaOxigenio += e['oxigenio'];
      somaTemperatura += e['temperatura'];
    }
    totalAnalises = historicoAnalises.length;
    mediaPh = totalAnalises > 0 ? somaPh / totalAnalises : 0;
    mediaOxigenio = totalAnalises > 0 ? somaOxigenio / totalAnalises : 0;
    mediaTemperatura = totalAnalises > 0 ? somaTemperatura / totalAnalises : 0;
    totalRacao = historicoRacao.fold(0.0, (a, b) => a + b['quantidade']);
    final agora = DateTime.now();
    horaUltimaAtualizacao = '${agora.hour.toString().padLeft(2, '0')}:${agora.minute.toString().padLeft(2, '0')}';
    if (mounted) setState(() {});
  }

  Future<void> _carregarCicloAtivo(String id) async {
    final snap = await FirebaseFirestore.instance
        .collection('ciclos')
        .where('codigo', isEqualTo: id)
        .where('encerrado', isEqualTo: false)
        .limit(1)
        .get();
    cicloAtivo = snap.docs.isNotEmpty ? snap.docs.first.data() : null;
  }

  Future<void> _carregarBiomassaAtual(String id) async {
    final snap = await FirebaseFirestore.instance
        .collection('biomassa')
        .where('codigo', isEqualTo: id)
        .orderBy('dataHora', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      biomassaAtual = (snap.docs.first['biomassaKg'] as num?)?.toDouble();
      sobrevivenciaAtual = (snap.docs.first['sobrevivencia'] as num?)?.toDouble();
    } else {
      biomassaAtual = null;
      sobrevivenciaAtual = null;
    }
  }

  Future<void> _carregarHistoricoAnalises(String id, DateTime inicio, DateTime fim) async {
    final snap = await FirebaseFirestore.instance
        .collection('${_tipoSelecionado}s')
        .doc(id)
        .collection('analises')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('timestamp', isLessThan: Timestamp.fromDate(fim))
        .orderBy('timestamp')
        .get();
    historicoAnalises = snap.docs.map((doc) => {
      'timestamp': (doc['timestamp'] as Timestamp).toDate(),
      'ph': (doc['ph'] as num).toDouble(),
      'oxigenio': (doc['oxigenio'] as num).toDouble(),
      'temperatura': (doc['temperatura'] as num).toDouble(),
    }).toList();
  }

  Future<void> _carregarHistoricoRacao(String id, DateTime inicio, DateTime fim) async {
    final snap = await FirebaseFirestore.instance
        .collection('racao')
        .where(_tipoSelecionado, isEqualTo: id)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('timestamp', isLessThan: Timestamp.fromDate(fim))
        .orderBy('timestamp')
        .get();
    historicoRacao = snap.docs.map((doc) => {
      'timestamp': (doc['timestamp'] as Timestamp).toDate(),
      'quantidade': (doc['quantidade'] as num).toDouble(),
    }).toList();
  }

  Future<List<String>> _carregarListaDeCodigos() async {
    final snap = await FirebaseFirestore.instance.collection('${_tipoSelecionado}s').get();
    return snap.docs.map((doc) => doc.id).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DegradeFundo(
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Painel Web',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ToggleButtons(
                            isSelected: [
                              _tipoSelecionado == 'viveiro',
                              _tipoSelecionado == 'bercario',
                            ],
                            onPressed: (idx) {
                              setState(() {
                                _tipoSelecionado = idx == 0 ? 'viveiro' : 'bercario';
                                _codigoSelecionado = null;
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            children: const [
                              Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Viveiro')),
                              Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Berçário')),
                            ],
                          ),
                          const SizedBox(width: 32),
                          Flexible(
                            child: FutureBuilder<List<String>>(
                              future: _carregarListaDeCodigos(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const CircularProgressIndicator();
                                }
                                final codigos = snapshot.data!;
                                return DropdownButton<String>(
                                  value: _codigoSelecionado,
                                  hint: Text('Selecione o $_tipoSelecionado'),
                                  items: codigos.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                                  onChanged: (value) {
                                    setState(() => _codigoSelecionado = value);
                                    _carregarDados();
                                  },
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 32),
                          Flexible(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final escolhida = await showDatePicker(
                                  context: context,
                                  initialDate: _dataSelecionada,
                                  firstDate: DateTime(2024),
                                  lastDate: DateTime.now(),
                                );
                                if (escolhida != null) {
                                  setState(() => _dataSelecionada = escolhida);
                                  _carregarDados();
                                }
                              },
                              icon: const Icon(Icons.calendar_today),
                              label: Text(DateFormat('dd/MM/yyyy').format(_dataSelecionada)),
                            ),
                          ),
                          const SizedBox(width: 32),
                          Flexible(
                            child: ToggleButtons(
                              isSelected: [
                                _periodo == PeriodoPainel.dia,
                                _periodo == PeriodoPainel.semana,
                                _periodo == PeriodoPainel.mes,
                              ],
                              onPressed: (idx) {
                                setState(() => _periodo = PeriodoPainel.values[idx]);
                                _carregarDados();
                              },
                              borderRadius: BorderRadius.circular(8),
                              children: const [
                                Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Dia')),
                                Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Semana')),
                                Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Mês')),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      if (_codigoSelecionado != null) ...[
                        if (cicloAtivo != null)
                          Card(
                            color: Colors.blue.shade50,
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Ciclo ativo', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                  Text('Status: ${cicloAtivo!['encerrado'] == true ? 'Encerrado' : 'Em andamento'}'),
                                  Text('Início: ${cicloAtivo!['dataInicio'] != null ? DateFormat('dd/MM/yyyy').format(cicloAtivo!['dataInicio'].toDate()) : '-'}'),
                                  Text('Estocagem: ${cicloAtivo!['quantidadeEstocada'] ?? '-'} camarões'),
                                  Text('Peso inicial: ${cicloAtivo!['pesoInicial'] ?? '-'} g'),
                                  if (cicloAtivo!['dataFim'] != null)
                                    Text('Previsão de término: ${DateFormat('dd/MM/yyyy').format(cicloAtivo!['dataFim'].toDate())}'),
                                  if (biomassaAtual != null)
                                    Text('Biomassa atual: ${biomassaAtual!.toStringAsFixed(2)} kg'),
                                  if (sobrevivenciaAtual != null)
                                    Text('Sobrevivência: ${sobrevivenciaAtual!.toStringAsFixed(1)}%'),
                                ],
                              ),
                            ),
                          ),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            return Wrap(
                              spacing: 24,
                              runSpacing: 24,
                              alignment: WrapAlignment.center,
                              children: [
                                _buildCard(Icons.water_drop, 'Análises de Água', '$totalAnalises'),
                                _buildCard(Icons.restaurant, 'Ração Total (g)', totalRacao.toStringAsFixed(1)),
                                _buildCard(Icons.grain, 'pH Médio', mediaPh.toStringAsFixed(2), alerta: mediaPh < 6.5 || mediaPh > 8.5),
                                _buildCard(Icons.air, 'Oxigênio Médio', mediaOxigenio.toStringAsFixed(2), alerta: mediaOxigenio < 3),
                                _buildCard(Icons.thermostat, 'Temperatura Média', mediaTemperatura.toStringAsFixed(1), alerta: mediaTemperatura < 24 || mediaTemperatura > 32),
                                _buildCard(Icons.access_time, 'Última atualização', horaUltimaAtualizacao),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 32),
                        PainelGraficos(
                          historicoAnalises: historicoAnalises,
                          historicoRacao: historicoRacao,
                          periodo: _periodo.name,
                        ),
                      ] else
                        const Text('Selecione um viveiro para visualizar os dados.'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(IconData icon, String titulo, String valor, {bool alerta = false}) {
    String? tooltip;
    if (titulo.contains('pH')) tooltip = 'Faixa ideal: 6.5 a 8.5';
    if (titulo.contains('Oxigênio')) tooltip = 'Mínimo recomendado: 3 mg/L';
    if (titulo.contains('Temperatura')) tooltip = 'Ideal: 24°C a 32°C';
    return Tooltip(
      message: alerta && tooltip != null ? tooltip : '',
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(20),
          width: 250,
          height: 130,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 40, color: alerta ? Colors.red : Colors.teal),
              Text(titulo, style: Theme.of(context).textTheme.bodyMedium),
              Text(valor, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: alerta ? Colors.red : null)),
            ],
          ),
        ),
      ),
    );
  }
}

class DegradeFundo extends StatelessWidget {

  const DegradeFundo({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade800, Colors.blue.shade300],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: child,
    );
  }
}