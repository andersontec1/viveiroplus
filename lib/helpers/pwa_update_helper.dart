import 'package:flutter/material.dart';
import 'pwa_update_helper_stub.dart'
    if (dart.library.html) 'pwa_update_helper_web.dart'
    as impl;

class PwaUpdateHelper {
  /// Inicia o listener de atualização do PWA (Web).
  /// Em outras plataformas é no-op.
  static void init(GlobalKey<NavigatorState> navigatorKey) {
    impl.initPwaUpdate(navigatorKey);
  }
}
