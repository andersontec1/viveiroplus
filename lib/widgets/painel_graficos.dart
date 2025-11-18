import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PainelGraficos extends StatelessWidget {
  const PainelGraficos({
    required this.historicoAnalises,
    required this.historicoRacao,
    required this.periodo,
    super.key,
  });
  final List<Map<String, dynamic>> historicoAnalises;
  final List<Map<String, dynamic>> historicoRacao;
  final String periodo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildGraficoLinha(
          context,
          'pH',
          historicoAnalises,
          (e) => e['ph'] as double,
          color: const Color.fromARGB(255, 0, 184, 165),
        ),
        const SizedBox(height: 24),
        _buildGraficoLinha(
          context,
          'Oxigênio',
          historicoAnalises,
          (e) => e['oxigenio'] as double,
          color: Colors.blue,
        ),
        const SizedBox(height: 24),
        _buildGraficoLinha(
          context,
          'Temperatura',
          historicoAnalises,
          (e) => e['temperatura'] as double,
          color: Colors.orange,
        ),
        const SizedBox(height: 24),
        _buildGraficoLinha(
          context,
          'Ração (g)',
          historicoRacao,
          (e) => e['quantidade'] as double,
          color: Colors.green,
        ),
      ],
    );
  }

  Widget _buildGraficoLinha(
    BuildContext context,
    String titulo,
    List<Map<String, dynamic>> dados,
    double Function(Map<String, dynamic>) getY, {
    required Color color,
  }) {
    if (dados.isEmpty) {
      return Text(
        'Sem dados para $titulo',
        style: const TextStyle(color: Colors.grey),
      );
    }
    final spots = <FlSpot>[];
    for (var i = 0; i < dados.length; i++) {
      spots.add(FlSpot(i.toDouble(), getY(dados[i])));
    }
    final minY = spots
        .map((e) => e.y)
        .reduce((a, b) => a < b ? a : b)
        .floorToDouble();
    final maxY = spots
        .map((e) => e.y)
        .reduce((a, b) => a > b ? a : b)
        .ceilToDouble();
    // Escala adaptativa para gráfico de ração
    double intervaloY = (maxY - minY).clamp(1, double.infinity);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: Theme.of(context).textTheme.titleMedium),
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              minY: minY,
              maxY: maxY,
              minX: 0,
              maxX: spots.length > 1 ? (spots.length - 1).toDouble() : 1,
              gridData: FlGridData(
                show: true,
                horizontalInterval: intervaloY / 4,
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (v, meta) => Text(
                      v.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (v, meta) {
                      final idx = v.round();
                      if (idx < 0 || idx >= dados.length)
                        return const SizedBox.shrink();
                      final dt = dados[idx]['timestamp'] as DateTime?;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          dt != null ? DateFormat('dd/MM').format(dt) : '',
                          style: const TextStyle(fontSize: 11),
                        ),
                      );
                    },
                    interval: 1,
                  ),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: const Border.symmetric(
                  horizontal: BorderSide(),
                  vertical: BorderSide(),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: color,
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: color.withOpacity(0.15),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final idx = spot.x.round();
                      if (idx < 0 || idx >= dados.length) return null;
                      final dt = dados[idx]['timestamp'] as DateTime?;
                      final valor = spot.y;
                      return LineTooltipItem(
                        '${dt != null ? DateFormat('dd/MM/yyyy').format(dt) : ''}\n${valor.toStringAsFixed(2)}',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
