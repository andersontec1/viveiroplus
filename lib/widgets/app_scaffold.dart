import 'package:flutter/material.dart';
import 'responsive_center.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.title,
    required this.body,
    super.key,
    this.floatingActionButton,
    this.backgroundColor,
    this.showAppBar = true,
    this.responsiveCenter = true,
    this.maxContentWidth,
    this.contentPadding,
  });
  final String title;
  final Widget body;
  final Widget? floatingActionButton;
  final Color? backgroundColor;
  final bool showAppBar;
  // Novo: centraliza e limita largura do conteúdo em telas largas (web/desktop)
  final bool responsiveCenter;
  final double? maxContentWidth; // padrão aplicado no build (ex.: 1100)
  final EdgeInsetsGeometry? contentPadding; // padding interno padrão

  @override
  Widget build(BuildContext context) {
    final EdgeInsetsGeometry pad =
        contentPadding ??
        const EdgeInsets.symmetric(horizontal: 16, vertical: 12);

    Widget wrappedBody = body;
    if (responsiveCenter) {
      // Usa componente compartilhado com breakpoints para limitar largura.
      wrappedBody = ResponsiveCenter(
        maxWidth: maxContentWidth, // se informado, força valor fixo
        padding: pad,
        alignment: Alignment.topCenter,
        child: body,
      );
    }

    return Scaffold(
      backgroundColor:
          backgroundColor ??
          const Color(0xFFE8F5E9), // fundo verde claro por padrão
      appBar: showAppBar ? AppBar(title: Text(title)) : null,
      body: wrappedBody,
      floatingActionButton: floatingActionButton,
    );
  }
}
