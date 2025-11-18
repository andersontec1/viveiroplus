import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

/// Monitora inatividade e ciclo de vida do app.
class SessionManager extends WidgetsBindingObserver {
  SessionManager({required this.onSessionTimeout}) {
    WidgetsBinding.instance.addObserver(this);
    _resetTimer();
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointerEvent);
  }
  static const timeout = Duration(minutes: 10);

  final VoidCallback onSessionTimeout;
  Timer? _inactivityTimer;

  void _onPointerEvent(PointerEvent _) => _resetTimer();

  // expõe para uso externo
  void reset() => _resetTimer();

  void _resetTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(timeout, _expireSession);
  }

  void _expireSession() {
    onSessionTimeout();
    dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_inactivityTimer?.isActive == false) {
        _expireSession();
      } else {
        _resetTimer();
      }
    }
    if (state == AppLifecycleState.paused) {
      _inactivityTimer?.cancel();
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inactivityTimer?.cancel();
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointerEvent);
  }
}
