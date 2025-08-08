import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:universal_html/html.dart' as html;

Future<void> exportarCsv(List<List<dynamic>> data, {String nomeArquivo = 'dados.csv'}) async {
  final csv = const ListToCsvConverter().convert(data);
  final bytes = utf8.encode(csv);
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', nomeArquivo)
    ..click();
  html.Url.revokeObjectUrl(url);
}
