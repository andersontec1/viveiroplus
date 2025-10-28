import 'package:flutter/material.dart';

/// Centraliza e limita a largura do conteúdo em telas largas (web/desktop),
/// com breakpoints simples para variar a largura máxima conforme a janela.
///
/// Defaults (quando [maxWidth] não for informado):
/// - <= 600: ocupa 100% (sem limite)
/// - 600–900: 680
/// - 900–1200: 960
/// - 1200–1600: 1100
/// - > 1600: 1280
class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth,
    this.maxWidthSm = 680,
    this.maxWidthMd = 960,
    this.maxWidthLg = 1100,
    this.maxWidthXl = 1280,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double? maxWidth; // se informado, tem prioridade
  final double maxWidthSm; // 600–900
  final double maxWidthMd; // 900–1200
  final double maxWidthLg; // 1200–1600
  final double maxWidthXl; // >1600
  final EdgeInsetsGeometry padding;
  final AlignmentGeometry alignment;

  double _computeMaxWidth(double screenWidth) {
    if (maxWidth != null) return maxWidth!;
    if (screenWidth <= 600) return double.infinity; // sem limitar
    if (screenWidth <= 900) return maxWidthSm;
    if (screenWidth <= 1200) return maxWidthMd;
    if (screenWidth <= 1600) return maxWidthLg;
    return maxWidthXl;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final effectiveMax = _computeMaxWidth(screenWidth);

    return Align(
      alignment: alignment,
      child: Container(
        constraints: BoxConstraints(maxWidth: effectiveMax),
        padding: padding,
        child: child,
      ),
    );
  }
}
