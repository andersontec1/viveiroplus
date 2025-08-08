// Tela Biomassa com salvamento de histórico por viveiro e listagem dos cálculos anteriores

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/degrade_fundo.dart';
import 'package:fl_chart/fl_chart.dart';

class TelaBiomassa extends StatefulWidget {
  const TelaBiomassa({super.key});

  @override
  State<TelaBiomassa> createState() => _TelaBiomassaState();
}

class _TelaBiomassaState extends State<TelaBiomassa> {
  final _formKey = GlobalKey<FormState>();
  final _sobrevivenciaCtrl = TextEditingController(text: '85');
  final _pesoAmostraCtrl = TextEditingController();
  final _qtdAmostraCtrl = TextEditingController();
  String? _codigoSelecionado;
  Map<String, String> _viveiros = {};
  Map<String, dynamic>? _cicloAtivo;
  bool _calculando = false;

  double? _pesoMedio, _biomassa, _sobrevivencia, _quantidadeViva;

  @override
  void initState() {
    super.initState();
    _carregarViveiros();
  }

  Future<void> _carregarViveiros() async {
    final snap = await FirebaseFirestore.instance.collection('viveiros').get();
    final mapa = <String, String>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      mapa[data['codigo']] = data['nome'];
    }
    setState(() => _viveiros = mapa);
  }

  Future<void> _buscarCicloAtivo(String codigo) async {
    final snap = await FirebaseFirestore.instance
        .collection('ciclos')
        .where('codigo', isEqualTo: codigo)
        .where('encerrado', isEqualTo: false)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      setState(() => _cicloAtivo = snap.docs.first.data());
    } else {
      setState(() => _cicloAtivo = null);
    }
  }

  Future<void> _calcularSalvar() async {
    if (!_formKey.currentState!.validate()) return;
    final qtdAmostra = int.tryParse(_qtdAmostraCtrl.text);
    final pesoAmostra = double.tryParse(_pesoAmostraCtrl.text.replaceAll(',', '.'));
    final taxaSobrevivencia = double.tryParse(_sobrevivenciaCtrl.text.replaceAll(',', '.'));
    if (_codigoSelecionado == null || qtdAmostra == null || pesoAmostra == null || _cicloAtivo == null || taxaSobrevivencia == null) return;

    setState(() => _calculando = true);

    _pesoMedio = pesoAmostra / qtdAmostra;
    _quantidadeViva = (_cicloAtivo!['quantidadeEstocada'] as int) * (taxaSobrevivencia / 100);
    _biomassa = _pesoMedio! * _quantidadeViva! / 1000; // em kg
    _sobrevivencia = (_quantidadeViva! / (_cicloAtivo!['quantidadeEstocada'] as int)) * 100;

    final user = FirebaseAuth.instance.currentUser;
    final nomeUsuario = user != null
        ? (((await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get()).data()?['nome']) ?? '—')
        : '—';

    await FirebaseFirestore.instance.collection('biomassa').add({
      'codigo': _codigoSelecionado,
      'nome': _viveiros[_codigoSelecionado] ?? '—',
      'pesoMedio': _pesoMedio,
      'biomassaKg': _biomassa,
      'sobrevivencia': _sobrevivencia,
      'quantidadeViva': _quantidadeViva,
      'taxaSobrevivencia': taxaSobrevivencia,
      'registradoPor': nomeUsuario,
      'dataHora': Timestamp.now(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Cálculo de biomassa salvo com sucesso!'),
        backgroundColor: Colors.green,
      ));
    }

    setState(() => _calculando = false);
  }

  @override
  void dispose() {
    _pesoAmostraCtrl.dispose();
    _qtdAmostraCtrl.dispose();
    _sobrevivenciaCtrl.dispose();
    super.dispose();
  }

  String _formatar(double? valor, {String sufixo = ''}) =>
      valor == null ? '—' : '${valor.toStringAsFixed(2)}$sufixo';

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Cálculo de Biomassa',
      body: DegradeFundo(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _codigoSelecionado,
                  decoration: const InputDecoration(
                    labelText: 'Viveiro',
                    prefixIcon: Icon(Icons.water),
                  ),
                  items: _viveiros.entries
                      .map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Text('${e.value} (cód: ${e.key})'),
                          ))
                      .toList(),
                  onChanged: (v) {
                    setState(() => _codigoSelecionado = v);
                    if (v != null) _buscarCicloAtivo(v);
                  },
                  validator: (v) => v == null ? 'Selecione o viveiro' : null,
                ),
                if (_cicloAtivo != null) ...[
                  const SizedBox(height: 8),
                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Ciclo ativo:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('Estocagem: ${_cicloAtivo!['quantidadeEstocada']} camarões'),
                          Text('Peso inicial: ${_cicloAtivo!['pesoInicial'] ?? '-'} g'),
                          Text('Início: ${_cicloAtivo!['dataInicio'] != null ? DateFormat('dd/MM/yyyy').format(_cicloAtivo!['dataInicio'].toDate()) : '-'}'),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _qtdAmostraCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantidade na amostra',
                    prefixIcon: Icon(Icons.group),
                  ),
                  validator: (v) {
                    final val = int.tryParse(v ?? '');
                    if (val == null || val <= 0) return 'Informe uma quantidade válida';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _pesoAmostraCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Peso total da amostra (g)',
                    prefixIcon: Icon(Icons.monitor_weight),
                  ),
                  validator: (v) {
                    final val = double.tryParse((v ?? '').replaceAll(',', '.'));
                    if (val == null || val <= 0) return 'Informe um peso válido';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _sobrevivenciaCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Taxa de sobrevivência (%)',
                    prefixIcon: Icon(Icons.percent),
                  ),
                  validator: (v) {
                    final val = double.tryParse((v ?? '').replaceAll(',', '.'));
                    if (val == null || val <= 0 || val > 100) return 'Informe uma taxa válida (0-100)';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _calculando ? null : _calcularSalvar,
                        icon: const Icon(Icons.calculate),
                        label: const Text('Calcular e Salvar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade300, foregroundColor: Colors.black),
                      onPressed: () {
                        _formKey.currentState?.reset();
                        _pesoAmostraCtrl.clear();
                        _qtdAmostraCtrl.clear();
                        _sobrevivenciaCtrl.text = '85';
                        setState(() {
                          _pesoMedio = null;
                          _biomassa = null;
                          _sobrevivencia = null;
                          _quantidadeViva = null;
                        });
                      },
                      icon: const Icon(Icons.clear),
                      label: const Text('Limpar'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(),
                const Text('Resultados:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (_calculando)
                  const Center(child: CircularProgressIndicator()),
                if (!_calculando) ...[
                  Text('Peso médio: ${_formatar(_pesoMedio, sufixo: ' g')}'),
                  Text('Biomassa estimada: ${_formatar(_biomassa, sufixo: ' kg')}'),
                  Text('Sobrevivência estimada: ${_formatar(_sobrevivencia, sufixo: ' %')}'),
                  Text('Quantidade viva estimada: ${_formatar(_quantidadeViva)} camarões'),
                ],
                const SizedBox(height: 24),
                const Divider(),
                const Text('Histórico de Cálculos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (_codigoSelecionado != null)
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('biomassa')
                        .where('codigo', isEqualTo: _codigoSelecionado)
                        .orderBy('dataHora', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const CircularProgressIndicator();
                      final docs = snapshot.data!.docs;
                      if (docs.isEmpty) return const Text('Nenhum histórico encontrado.');
                      // Histórico
                      final historico = Column(
                        children: docs.map((doc) {
                          final data = doc['dataHora'].toDate();
                          return ListTile(
                            leading: const Icon(Icons.history),
                            title: Text(DateFormat('dd/MM/yyyy HH:mm').format(data)),
                            subtitle: Text(
                                'Peso médio: ${_formatar(doc['pesoMedio'], sufixo: 'g')} • Biomassa: ${_formatar(doc['biomassaKg'], sufixo: 'kg')}'
                                '\nSobrevivência: ${_formatar(doc['sobrevivencia'], sufixo: '%')} • Taxa: ${_formatar(doc['taxaSobrevivencia'], sufixo: '%')} • Por: ${doc['registradoPor']}'
                            ),
                          );
                        }).toList(),
                      );
                      // Gráfico
                      final points = docs
                          .map((doc) => {
                                'x': (doc['dataHora'] as Timestamp).toDate().millisecondsSinceEpoch.toDouble(),
                                'y': (doc['biomassaKg'] as num?)?.toDouble() ?? 0.0,
                              })
                          .toList();
                      points.sort((a, b) => a['x']!.compareTo(b['x']!));
                      final minX = points.isNotEmpty ? points.first['x']! : 0.0;
                      final maxX = points.isNotEmpty ? points.last['x']! : 1.0;
                      final minY = points.isNotEmpty ? points.map((e) => e['y']!).reduce((a, b) => a < b ? a : b) : 0.0;
                      final maxY = points.isNotEmpty ? points.map((e) => e['y']!).reduce((a, b) => a > b ? a : b) : 1.0;
                      final lineSpots = points
                          .map((e) => FlSpot(
                                (e['x']! - minX) / (maxX - minX == 0 ? 1 : maxX - minX) * 6, // normaliza para 0-6
                                e['y']!,
                              ))
                          .toList();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          historico,
                          const SizedBox(height: 24),
                          if (points.length > 1)
                            SizedBox(
                              height: 220,
                              child: LineChart(
                                LineChartData(
                                  minY: minY.floorToDouble(),
                                  maxY: maxY.ceilToDouble(),
                                  minX: 0,
                                  maxX: 6,
                                  gridData: FlGridData(show: true, horizontalInterval: (maxY-minY)/4),
                                  titlesData: FlTitlesData(
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, meta) => Text('${v.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 11))),
                                    ),
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 36,
                                        getTitlesWidget: (v, meta) {
                                          final idx = v.round();
                                          if (idx < 0 || idx >= points.length) return const SizedBox.shrink();
                                          final dt = DateTime.fromMillisecondsSinceEpoch(points[idx]['x']!.toInt());
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 8),
                                            child: Text(DateFormat('dd/MM').format(dt), style: const TextStyle(fontSize: 11)),
                                          );
                                        },
                                        interval: 1,
                                      ),
                                    ),
                                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  ),
                                  borderData: FlBorderData(show: true, border: const Border.symmetric(horizontal: BorderSide(), vertical: BorderSide())),
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: lineSpots,
                                      isCurved: true,
                                      color: Colors.teal,
                                      barWidth: 3,
                                      dotData: const FlDotData(show: false),
                                      belowBarData: BarAreaData(show: true, color: Colors.teal.withOpacity(0.15)),
                                    ),
                                  ],
                                  lineTouchData: const LineTouchData(enabled: true),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Limpar tudo',
        onPressed: () {
          _formKey.currentState?.reset();
          _pesoAmostraCtrl.clear();
          _qtdAmostraCtrl.clear();
          _sobrevivenciaCtrl.text = '85';
          setState(() {
            _pesoMedio = null;
            _biomassa = null;
            _sobrevivencia = null;
            _quantidadeViva = null;
            _codigoSelecionado = null;
            _cicloAtivo = null;
          });
        },
        child: const Icon(Icons.refresh),
      ),
    );
  }
}