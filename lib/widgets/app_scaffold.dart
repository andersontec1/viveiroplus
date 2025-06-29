import 'package:flutter/material.dart';

class AppScaffold extends StatelessWidget {

  const AppScaffold({
    required this.title, required this.body, super.key,
    this.floatingActionButton,
    this.backgroundColor,
  });
  final String title;
  final Widget body;
  final Widget? floatingActionButton;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? const Color(0xFFE8F5E9), // fundo verde claro por padrão
      appBar: AppBar(
        title: Text(title),
      ),
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}
