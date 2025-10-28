import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';

Future<void> exportarCsv(List<List<dynamic>> data, {String nomeArquivo = 'dados.csv'}) async {
  final csv = const ListToCsvConverter().convert(data);
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$nomeArquivo');
  await file.writeAsString(csv);
  // Compartilhar usando nova API do SharePlus
  await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile.fromData(
          await file.readAsBytes(),
          name: nomeArquivo,
          mimeType: 'text/csv',
        ),
      ],
      text: 'Exportação CSV - Viveiro+',
      subject: 'Exportação CSV',
    ),
  );
}
