import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TelaPainelWeb extends StatefulWidget {
  const TelaPainelWeb({super.key});

  @override
  State<TelaPainelWeb> createState() => _TelaPainelWebState();
}

class _TelaPainelWebState extends State<TelaPainelWeb> {
  String? _viveiroSelecionado;
  DateTime _dataSelecionada = DateTime.now();
  Timer? _timer;

  int totalAnalises = 0;
  double mediaPh = 0.0;
  double mediaOxigenio = 0.0;
  double mediaTemperatura = 0.0;
  double totalRacao = 0.0;
  String horaUltimaAtualizacao = '--:--';

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
    if (_viveiroSelecionado == null) return;

    final inicioDoDia = DateTime(
      _dataSelecionada.year,
      _dataSelecionada.month,
      _dataSelecionada.day,
    );

    final fimDoDia = inicioDoDia.add(const Duration(days: 1));

    final viveiroId = _viveiroSelecionado!;

    // 🔹 Analises de água
    final analisesSnap = await FirebaseFirestore.instance
        .collection('viveiros')
        .doc(viveiroId)
        .collection('analises')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioDoDia))
        .where('timestamp', isLessThan: Timestamp.fromDate(fimDoDia))
        .get();

    double somaPh = 0;
    double somaOxigenio = 0;
    double somaTemperatura = 0;

    for (final doc in analisesSnap.docs) {
      somaPh += (doc['ph'] as num).toDouble();
      somaOxigenio += (doc['oxigenio'] as num).toDouble();
      somaTemperatura += (doc['temperatura'] as num).toDouble();
    }

    totalAnalises = analisesSnap.docs.length;
    mediaPh = totalAnalises > 0 ? somaPh / totalAnalises : 0;
    mediaOxigenio = totalAnalises > 0 ? somaOxigenio / totalAnalises : 0;
    mediaTemperatura = totalAnalises > 0 ? somaTemperatura / totalAnalises : 0;

    // 🔸 Ração
    final racaoSnap = await FirebaseFirestore.instance
        .collection('racao')
        .where('viveiro', isEqualTo: viveiroId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioDoDia))
        .where('timestamp', isLessThan: Timestamp.fromDate(fimDoDia))
        .get();

    double somaRacao = 0;
    for (final doc in racaoSnap.docs) {
      somaRacao += (doc['quantidade'] as num).toDouble();
    }
    totalRacao = somaRacao;

    final agora = DateTime.now();
    horaUltimaAtualizacao = '${agora.hour.toString().padLeft(2, '0')}:${agora.minute.toString().padLeft(2, '0')}';

    if (mounted) setState(() {});
  }

  Future<List<String>> _carregarListaDeViveiros() async {
    final snap = await FirebaseFirestore.instance.collection('viveiros').get();
    return snap.docs.map((doc) => doc.id).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DegradeFundo(
        child: SafeArea(
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
                        FutureBuilder<List<String>>(
                          future: _carregarListaDeViveiros(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const CircularProgressIndicator();
                            }
                            final viveiros = snapshot.data!;
                            return DropdownButton<String>(
                              value: _viveiroSelecionado,
                              hint: const Text('Selecione o viveiro'),
                              items: viveiros.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                              onChanged: (value) {
                                setState(() => _viveiroSelecionado = value);
                                _carregarDados();
                              },
                            );
                          },
                        ),
                        const SizedBox(width: 32),
                        ElevatedButton.icon(
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
                      ],
                    ),
                    const SizedBox(height: 30),
                    if (_viveiroSelecionado != null)
                      Wrap(
                        spacing: 24,
                        runSpacing: 24,
                        children: [
                          _buildCard(Icons.water_drop, 'Análises de Água', '$totalAnalises'),
                          _buildCard(Icons.restaurant, 'Ração Total (g)', totalRacao.toStringAsFixed(1)),
                          _buildCard(Icons.grain, 'pH Médio', mediaPh.toStringAsFixed(2)),
                          _buildCard(Icons.air, 'Oxigênio Médio', mediaOxigenio.toStringAsFixed(2)),
                          _buildCard(Icons.thermostat, 'Temperatura Média', mediaTemperatura.toStringAsFixed(1)),
                          _buildCard(Icons.access_time, 'Última atualização', horaUltimaAtualizacao),
                        ],
                      )
                    else
                      const Text('Selecione um viveiro para visualizar os dados.'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(IconData icon, String titulo, String valor) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        width: 250,
        height: 130,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, size: 40, color: Colors.teal),
            Text(titulo, style: Theme.of(context).textTheme.bodyMedium),
            Text(valor, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class DegradeFundo extends StatelessWidget {
  final Widget child;

  const DegradeFundo({super.key, required this.child});

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
