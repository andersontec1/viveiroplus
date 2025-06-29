import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:universal_html/html.dart' as html;

Future<void> exportarCSVWeb(List<List<String>> rows) async {
  final csv = const ListToCsvConverter().convert(rows);
  final bytes = utf8.encode(csv);
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', 'relatorio_racao.csv')
    ..click();
  html.Url.revokeObjectUrl(url);
}
