import 'package:flutter/material.dart';

class RacaoMetaChips extends StatelessWidget {
  const RacaoMetaChips({
    super.key,
    this.trato,
    this.diaCiclo,
    this.totalAcumulado,
    this.baseSwatch = Colors.teal,
    this.spacing = 8,
    this.runSpacing = 4,
    this.compact = true,
    this.padding,
  });

  final int? trato;
  final int? diaCiclo;
  final double? totalAcumulado;
  final MaterialColor baseSwatch;
  final double spacing;
  final double runSpacing;
  final bool compact;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final hasAny = trato != null || diaCiclo != null || totalAcumulado != null;
    if (!hasAny) return const SizedBox.shrink();

    final density = compact ? VisualDensity.compact : VisualDensity.standard;

    final chips = <Widget>[];

    if (trato != null) {
      chips.add(
        Chip(
          avatar: Icon(Icons.fastfood, size: 16, color: baseSwatch),
          label: Text('${trato}º Trato'),
          backgroundColor: baseSwatch.shade50,
          visualDensity: density,
          shape: StadiumBorder(side: BorderSide(color: baseSwatch.shade200)),
        ),
      );
    }

    if (diaCiclo != null) {
      chips.add(
        Chip(
          avatar: Icon(Icons.calendar_view_day, size: 16, color: baseSwatch),
          label: Text('Dia $diaCiclo'),
          backgroundColor: baseSwatch.shade50,
          visualDensity: density,
          shape: StadiumBorder(side: BorderSide(color: baseSwatch.shade200)),
        ),
      );
    }

    if (totalAcumulado != null) {
      chips.add(
        Chip(
          avatar: Icon(Icons.summarize, size: 16, color: baseSwatch),
          label: Text(
            'Total até aqui: ${totalAcumulado!.toStringAsFixed(2)} kg',
            style: const TextStyle(fontSize: 11),
          ),
          backgroundColor: baseSwatch.shade50,
          visualDensity: density,
          shape: StadiumBorder(side: BorderSide(color: baseSwatch.shade200)),
        ),
      );
    }

    final wrap = Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      children: chips,
    );

    if (padding != null) {
      return Padding(padding: padding!, child: wrap);
    }
    return wrap;
  }
}
