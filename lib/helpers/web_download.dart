// Implementação Web para download de bytes usando package:web (sem dart:html)
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:web/web.dart' as web;

/// Dispara download de bytes no Flutter Web usando package:web (sem dart:html).
/// - bytes: conteúdo do arquivo
/// - filename: nome sugerido para salvar
/// - mimeType: tipo MIME (ex: application/pdf, application/vnd.ms-excel)
Future<void> webDownloadBytes(
  Uint8List bytes,
  String filename, {
  String mimeType = 'application/octet-stream',
}) async {
  if (!kIsWeb) return; // Apenas relevante no alvo Web

  // Usa data URL para evitar interop de JS/TypedArray e seguir com package:web.
  final base64Data = base64Encode(bytes);
  final url = 'data:$mimeType;base64,$base64Data';

  final anchor = web.HTMLAnchorElement();
  anchor.href = url;
  anchor.download = filename;
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
}
