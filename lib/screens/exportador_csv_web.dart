import 'dart:convert';
import 'package:csv/csv.dart';
import 'dart:typed_data';
import 'package:viveiro_plus/helpers/web_download.dart';

Future<void> exportarCsv(
  List<List<dynamic>> data, {
  String nomeArquivo = 'dados.csv',
}) async {
  final csv = const ListToCsvConverter().convert(data);
  final bytes = Uint8List.fromList(utf8.encode(csv));
  await webDownloadBytes(
    bytes,
    nomeArquivo,
    mimeType: 'text/csv;charset=utf-8',
  );
}
