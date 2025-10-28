// Stub para plataformas não-web
import 'dart:typed_data';

Future<void> webDownloadBytes(Uint8List bytes, String filename, {String mimeType = 'application/octet-stream'}) async {
  // Não faz nada em plataformas não-web.
}
