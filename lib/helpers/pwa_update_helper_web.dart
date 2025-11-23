// ignore_for_file: avoid_web_libraries_in_flutter
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:html' as html;

// Estratégia simples para Web: baixar periodicamente o flutter_service_worker.js
// sem cache e comparar com a versão carregada inicialmente. Se mudar, avisar.
void initPwaUpdate(GlobalKey<NavigatorState> navigatorKey) {
  String? _baseline;

  Future<String> _fetchServiceWorker() async {
    try {
      final resp = await html.HttpRequest.request(
        '/flutter_service_worker.js?cb=${DateTime.now().millisecondsSinceEpoch}',
        method: 'GET',
        requestHeaders: {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'},
      );
      return resp.responseText ?? '';
    } catch (_) {
      return '';
    }
  }

  void _showUpdate() {
    final ctx = navigatorKey.currentContext;
    if (ctx != null) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: const Text('Nova versão disponível'),
          action: SnackBarAction(
            label: 'Atualizar',
            onPressed: () => html.window.location.reload(),
          ),
          duration: const Duration(seconds: 25),
        ),
      );
    } else {
      html.window.location.reload();
    }
  }

  Future<void> _check() async {
    final txt = await _fetchServiceWorker();
    if (txt.isEmpty) return;
    if (_baseline == null) {
      _baseline = txt;
      return;
    }
    if (txt != _baseline) {
      _showUpdate();
    }
  }

  // Primeira checagem após carregar a UI
  unawaited(Future.delayed(const Duration(seconds: 2), _check));
  // Checagem periódica (a cada 2 minutos)
  Timer.periodic(const Duration(minutes: 2), (_) => _check());
}
