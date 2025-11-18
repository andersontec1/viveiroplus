import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as xls;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
// import 'package:printing/printing.dart'; // não mais usado para fluxo de download direto
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'web_download_stub.dart' if (dart.library.html) 'web_download.dart';
import 'package:path_provider/path_provider.dart';

typedef ExportProgress = void Function(double progress, String? stage);

class ExportHelper {
  static final DateFormat _dfDate = DateFormat('dd/MM/yyyy HH:mm');

  // Faixas ideais para destacar fora de faixa no PDF
  static const Map<String, List<double>> _faixas = {
    'ph': [7.0, 9.0],
    'oxigenio': [4.0, 14.0],
    'temperatura': [26.0, 32.0],
    'turbidez': [40.0, 60.0],
    'saturacao_percentual': [80.0, 120.0],
    'salinidade': [30.0, 45.0],
    'calcio': [100.0, 300.0],
    'nitrito': [0.0, 0.5],
    'amonia': [0.0, 1.5],
  };

  static Map<String, List<double>> get faixas => _faixas;

  // Sanitiza strings para ASCII básico, removendo acentos e substituindo caracteres não suportados
  static String _ascii(String input) {
    const mapa = {
      'á': 'a',
      'à': 'a',
      'ã': 'a',
      'â': 'a',
      'ä': 'a',
      'Á': 'A',
      'À': 'A',
      'Ã': 'A',
      'Â': 'A',
      'Ä': 'A',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'É': 'E',
      'È': 'E',
      'Ê': 'E',
      'Ë': 'E',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'Í': 'I',
      'Ì': 'I',
      'Î': 'I',
      'Ï': 'I',
      'ó': 'o',
      'ò': 'o',
      'õ': 'o',
      'ô': 'o',
      'ö': 'o',
      'Ó': 'O',
      'Ò': 'O',
      'Õ': 'O',
      'Ô': 'O',
      'Ö': 'O',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'Ú': 'U',
      'Ù': 'U',
      'Û': 'U',
      'Ü': 'U',
      'ç': 'c',
      'Ç': 'C',
      'ñ': 'n',
      'Ñ': 'N',
      '’': '\'',
      '“': '"',
      '”': '"',
      '•': '-',
      '–': '-',
      '—': '-',
    };
    final sb = StringBuffer();
    for (final codePoint in input.runes) {
      final ch = String.fromCharCode(codePoint);
      final mapped = mapa[ch];
      final out = mapped ?? ch;
      final unit = out.codeUnitAt(0);
      // manter apenas ASCII imprimível básico
      if (unit >= 32 && unit <= 126) {
        sb.write(out);
      } else {
        sb.write('?');
      }
    }
    return sb.toString();
  }

  static String _safe(String input, bool asciiOnly) {
    return asciiOnly ? _ascii(input) : input;
  }

  /// Busca registros de `registros_diarios` opcionalmente filtrando por codigo
  static Future<List<Map<String, dynamic>>> obterAnalises({
    String? codigo,
    DateTime? inicio,
    DateTime? fim,
  }) async {
    Query query = FirebaseFirestore.instance.collection('registros_diarios');
    if (inicio != null) {
      query = query.where(
        'dataHora',
        isGreaterThanOrEqualTo: Timestamp.fromDate(inicio),
      );
    }
    if (fim != null) {
      query = query.where(
        'dataHora',
        isLessThanOrEqualTo: Timestamp.fromDate(fim),
      );
    }
    if (codigo != null) {
      query = query.where('codigo', isEqualTo: codigo);
    }
    try {
      final snap = await query.get();
      final List<Map<String, dynamic>> lista = [];
      for (final doc in snap.docs) {
        final raw = doc.data();
        final map = (raw is Map<String, dynamic>)
            ? Map<String, dynamic>.from(raw)
            : <String, dynamic>{};
        map['id'] = doc.id;
        lista.add(map);
      }
      return lista;
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition') {
        // Fallback: reduzir filtros para evitar índice composto
        final List<Map<String, dynamic>> lista = [];
        Query fallback;
        if (codigo != null) {
          // Buscar por código apenas e filtrar datas em memória
          fallback = FirebaseFirestore.instance
              .collection('registros_diarios')
              .where('codigo', isEqualTo: codigo);
        } else if (inicio != null || fim != null) {
          // Buscar apenas por intervalo de data (sem combinar código)
          fallback = FirebaseFirestore.instance.collection('registros_diarios');
          if (inicio != null) {
            fallback = fallback.where(
              'dataHora',
              isGreaterThanOrEqualTo: Timestamp.fromDate(inicio),
            );
          }
          if (fim != null) {
            fallback = fallback.where(
              'dataHora',
              isLessThanOrEqualTo: Timestamp.fromDate(fim),
            );
          }
        } else {
          // Sem filtros: retornar tudo (cuidado com volume)
          fallback = FirebaseFirestore.instance.collection('registros_diarios');
        }
        final snap = await fallback.get();
        for (final doc in snap.docs) {
          final raw = doc.data();
          final map = (raw is Map<String, dynamic>)
              ? Map<String, dynamic>.from(raw)
              : <String, dynamic>{};
          map['id'] = doc.id;
          // Pós-filtrar datas se necessário
          if (inicio != null || fim != null) {
            final ts = map['dataHora'];
            DateTime? d;
            if (ts is Timestamp) {
              d = ts.toDate();
            }
            if (d == null) {
              continue;
            }
            if (inicio != null && d.isBefore(inicio)) {
              continue;
            }
            if (fim != null && d.isAfter(fim)) {
              continue;
            }
          }
          lista.add(map);
        }
        return lista;
      }
      rethrow;
    }
  }

  /// Conta registros rapidamente usando aggregate count()
  static Future<int> contarAnalises({
    String? codigo,
    DateTime? inicio,
    DateTime? fim,
  }) async {
    Query query = FirebaseFirestore.instance.collection('registros_diarios');
    if (inicio != null) {
      query = query.where(
        'dataHora',
        isGreaterThanOrEqualTo: Timestamp.fromDate(inicio),
      );
    }
    if (fim != null) {
      query = query.where(
        'dataHora',
        isLessThanOrEqualTo: Timestamp.fromDate(fim),
      );
    }
    if (codigo != null) {
      query = query.where('codigo', isEqualTo: codigo);
    }
    try {
      final agg = await query.count().get();
      return agg.count ?? 0;
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition') {
        // Fallback: evitar índice composto
        if (codigo != null) {
          // Contar apenas por código e filtrar datas em memória com limite para evitar grandes downloads
          final snap = await FirebaseFirestore.instance
              .collection('registros_diarios')
              .where('codigo', isEqualTo: codigo)
              .limit(10001)
              .get();
          int c = 0;
          for (final doc in snap.docs) {
            if (inicio == null && fim == null) {
              c++;
            } else {
              final ts = doc.data()['dataHora'];
              DateTime? d;
              if (ts is Timestamp) {
                d = ts.toDate();
              }
              if (d == null) {
                continue;
              }
              if (inicio != null && d.isBefore(inicio)) {
                continue;
              }
              if (fim != null && d.isAfter(fim)) {
                continue;
              }
              c++;
              if (c > 10000) {
                break; // early stop
              }
            }
          }
          return c;
        } else {
          // Sem código: podemos contar apenas por intervalo de datas (sem índice composto)
          Query q = FirebaseFirestore.instance.collection('registros_diarios');
          if (inicio != null) {
            q = q.where(
              'dataHora',
              isGreaterThanOrEqualTo: Timestamp.fromDate(inicio),
            );
          }
          if (fim != null) {
            q = q.where(
              'dataHora',
              isLessThanOrEqualTo: Timestamp.fromDate(fim),
            );
          }
          try {
            final agg2 = await q.count().get();
            return agg2.count ?? 0;
          } catch (_) {
            final snap = await q.limit(10001).get();
            return snap.size;
          }
        }
      }
      // outro erro
      rethrow;
    }
  }

  /// Gera arquivo Excel em memória
  static Future<Uint8List> gerarExcelAnalises(
    List<Map<String, dynamic>> registros, {
    ExportProgress? onProgress,
  }) async {
    final workbook = xls.Excel.createExcel();
    // Criar sheet de resumo antes da sheet detalhada
    final resumoSheet = workbook['Resumo'];
    final sheet = workbook['Analises'];
    // Definir sheet padrão e remover Sheet1 agora que já existem nossas sheets
    workbook.setDefaultSheet('Resumo');
    if (workbook.sheets.keys.contains('Sheet1')) {
      workbook.delete('Sheet1');
    }

    // Definir estilos de cabeçalho (a lib excel não tem tema global, aplicamos célula a célula)
    final headerStyle = xls.CellStyle(
      bold: true,
      horizontalAlign: xls.HorizontalAlign.Center,
      verticalAlign: xls.VerticalAlign.Center,
    );

    onProgress?.call(0.08, 'Preparando resumo');
    // Parâmetros conhecidos (usar mesma lista que PDF para consistência)
    final parametros = [
      'ph',
      'oxigenio',
      'temperatura',
      'turbidez',
      'saturacao_percentual',
      'salinidade',
      'calcio',
      'nitrito',
      'amonia',
    ];

    // Construir estatísticas por parâmetro
    final resumoHeaders = [
      'PARAMETRO',
      'QTD',
      'MIN',
      'MAX',
      'MEDIA',
      'MEDIANA',
      'DESVIO PADRAO',
      'QTD FORA',
      '% FORA',
      'FAIXA IDEAL',
    ];
    resumoSheet.appendRow(
      resumoHeaders.map((h) => xls.TextCellValue(h)).toList(),
    );
    // Aplicar estilo à linha de cabeçalho do resumo
    for (int c = 0; c < resumoHeaders.length; c++) {
      final cell = resumoSheet.cell(
        xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0),
      );
      cell.cellStyle = headerStyle;
    }

    for (final p in parametros) {
      final valores = <double>[];
      for (final r in registros) {
        final v = r[p];
        if (v is num) {
          valores.add(v.toDouble());
        } else if (v is String) {
          final parsed = double.tryParse(v.replaceAll(',', '.'));
          if (parsed != null) {
            valores.add(parsed);
          }
        }
      }
      if (valores.isEmpty) {
        resumoSheet.appendRow([
          xls.TextCellValue(p),
          xls.TextCellValue('0'),
          xls.TextCellValue(''),
          xls.TextCellValue(''),
          xls.TextCellValue(''),
          xls.TextCellValue(''),
          xls.TextCellValue(''),
          xls.TextCellValue('0'),
          xls.TextCellValue('0%'),
          xls.TextCellValue(
            _faixas[p] != null ? '${_faixas[p]![0]} - ${_faixas[p]![1]}' : '',
          ),
        ]);
        continue;
      }
      valores.sort();
      final qtd = valores.length;
      final min = valores.first;
      final max = valores.last;
      final media = valores.reduce((a, b) => a + b) / qtd;
      // Mediana
      final mediana = (qtd % 2 == 1)
          ? valores[qtd ~/ 2]
          : ((valores[qtd ~/ 2 - 1] + valores[qtd ~/ 2]) / 2);
      // Desvio padrão (populacional)
      double soma2 = 0;
      for (final v in valores) {
        final d = v - media;
        soma2 += d * d;
      }
      final desvio = (qtd == 0) ? 0.0 : math.sqrt(soma2 / qtd);
      // Como não temos sqrt em double direto, calcular via math
      // Ajuste: usaremos dart:math abaixo
      int fora = 0;
      final faixa = _faixas[p];
      if (faixa != null) {
        for (final v in valores) {
          if (v < faixa[0] || v > faixa[1]) fora++;
        }
      }
      final percFora = qtd == 0 ? 0 : (fora / qtd * 100);
      resumoSheet.appendRow([
        xls.TextCellValue(p),
        xls.TextCellValue(qtd.toString()),
        xls.TextCellValue(min.toStringAsFixed(2)),
        xls.TextCellValue(max.toStringAsFixed(2)),
        xls.TextCellValue(media.toStringAsFixed(2)),
        xls.TextCellValue(mediana.toStringAsFixed(2)),
        xls.TextCellValue(desvio.toStringAsFixed(2)),
        xls.TextCellValue(fora.toString()),
        xls.TextCellValue('${percFora.toStringAsFixed(1)}%'),
        xls.TextCellValue(faixa != null ? '${faixa[0]} - ${faixa[1]}' : ''),
      ]);
    }

    onProgress?.call(0.2, 'Preparando planilha de análises');
    // Cabeçalho dinâmico
    final Set<String> chaves = {};
    for (final r in registros) {
      chaves.addAll(r.keys);
    }
    // Remover campos técnicos que não interessam na planilha ou ordenar melhor
    final ordemPreferida = [
      'dataHora',
      'tipoDestino',
      'codigo',
      'nome',
      'registradoPor',
      'ph',
      'oxigenio',
      'temperatura',
      'turbidez',
      'saturacao_percentual',
      'salinidade',
      'calcio',
      'nitrito',
      'amonia',
      'observacoes',
    ];
    final cabecalho = ordemPreferida.where((c) => chaves.contains(c)).toList();
    final cabecalhoFallback =
        ordemPreferida; // usa ordem preferida completa se não houver nenhum registro
    final cabecalhoUsado = cabecalho.isEmpty ? cabecalhoFallback : cabecalho;
    // Labels amigáveis para cabeçalho da aba Analises
    final labelMap = <String, String>{
      'dataHora': 'Data/Hora',
      'tipoDestino': 'Tipo',
      'codigo': 'Código',
      'nome': 'Nome',
      'registradoPor': 'Registrado Por',
      'ph': 'pH',
      'oxigenio': 'Oxigênio',
      'temperatura': 'Temperatura',
      'turbidez': 'Turbidez',
      'saturacao_percentual': 'Sat. %',
      'salinidade': 'Salinidade',
      'calcio': 'Cálcio',
      'nitrito': 'Nitrito',
      'amonia': 'Amônia',
      'observacoes': 'Observações',
    };
    final displayHeaders = cabecalhoUsado
        .map((k) => (labelMap[k] ?? k).toUpperCase())
        .toList();
    sheet.appendRow(displayHeaders.map((c) => xls.TextCellValue(c)).toList());
    for (int c = 0; c < displayHeaders.length; c++) {
      final cell = sheet.cell(
        xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0),
      );
      cell.cellStyle = headerStyle;
    }

    if (registros.isEmpty) {
      // Linha informativa para deixar claro que exportação não tinha dados no intervalo
      sheet.appendRow([
        xls.TextCellValue('Sem registros no intervalo selecionado'),
      ]);
    } else {
      final total = registros.length;
      final batch = math.max(1, total ~/ 50); // atualizar a cada ~2% (50 lotes)
      int i = 0;
      for (final r in registros) {
        final row = <dynamic>[];
        for (final chave in cabecalhoUsado) {
          final valor = r[chave];
          if (valor is Timestamp) {
            row.add(_dfDate.format(valor.toDate()));
          } else {
            row.add(valor?.toString() ?? '');
          }
        }
        sheet.appendRow(
          row.map((c) => xls.TextCellValue(c?.toString() ?? '')).toList(),
        );
        i++;
        if (i % batch == 0) {
          final p = 0.2 + (i / total) * 0.7; // 20%..90% durante escrita
          onProgress?.call(p.clamp(0.0, 0.9), 'Escrevendo linhas ($i/$total)');
        }
      }
    }

    onProgress?.call(0.95, 'Finalizando');
    final bytes = workbook.encode()!;
    onProgress?.call(1.0, 'Concluído');
    return Uint8List.fromList(bytes);
  }

  /// Gera PDF estilizado
  static Future<Uint8List> gerarPdfAnalises(
    List<Map<String, dynamic>> registros, {
    String? codigo,
    DateTime? inicio,
    DateTime? fim,
    Uint8List? logoBytes,
    bool incluirLegenda = true,
    ExportProgress? onProgress,
  }) async {
    try {
      // Tentar carregar fontes Unicode dos assets (opcional). Se não houver, usar ASCII-only.
      pw.Font? baseFont;
      pw.Font? boldFont;
      bool asciiOnly = true;
      // Preferir Boldonse primeiro (já incluída no projeto) para evitar 404 de NotoSans
      try {
        final dataReg = await rootBundle.load(
          'assets/fonts/Boldonse-Regular.ttf',
        );
        baseFont = pw.Font.ttf(dataReg);
        boldFont = baseFont; // sem variante bold, usar a mesma
        asciiOnly = false;
        debugPrint('[PDF] Fonte Boldonse-Regular carregada dos assets.');
      } catch (_) {
        try {
          final dataReg = await rootBundle.load(
            'assets/fonts/NotoSans-Regular.ttf',
          );
          final dataBold = await rootBundle.load(
            'assets/fonts/NotoSans-Bold.ttf',
          );
          baseFont = pw.Font.ttf(dataReg);
          boldFont = pw.Font.ttf(dataBold);
          asciiOnly = false;
          debugPrint('[PDF] Fonte NotoSans carregada dos assets.');
        } catch (e) {
          debugPrint(
            '[PDF] Sem fontes Unicode nos assets. Usando modo ASCII-only. Erro: $e',
          );
        }
      }
      final pdf = (baseFont != null && boldFont != null)
          ? pw.Document(
              theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
            )
          : pw.Document();

      // Preparar colunas de parâmetros principais
      final parametros = [
        'ph',
        'oxigenio',
        'temperatura',
        'turbidez',
        'saturacao_percentual',
        'salinidade',
        'calcio',
        'nitrito',
        'amonia',
      ];

      registros.sort((a, b) {
        final ta = a['dataHora'];
        final tb = b['dataHora'];
        if (ta is Timestamp && tb is Timestamp) {
          return ta.toDate().compareTo(tb.toDate());
        }
        return 0;
      });

      onProgress?.call(0.15, 'Preparando conteúdo');
      // Pré-computar linhas com progresso
      final total = registros.length;
      final rows = <List<String>>[];
      if (total == 0) {
        // Sem linhas
      } else {
        final batch = math.max(1, total ~/ 50); // ~50 atualizações (~2%)
        for (var i = 0; i < total; i++) {
          final r = registros[i];
          String dataStr = '';
          if (r['dataHora'] is Timestamp) {
            dataStr = DateFormat(
              'dd/MM HH:mm',
            ).format((r['dataHora'] as Timestamp).toDate());
          }
          rows.add([
            dataStr,
            (r['tipoDestino'] ?? '').toString(),
            (r['codigo'] ?? '').toString(),
            ...parametros.map((p) => (r[p] ?? '').toString()),
            (r['observacoes'] ?? '').toString(),
          ]);
          if ((i + 1) % batch == 0) {
            final p = 0.15 + ((i + 1) / total) * 0.6; // 15%..75%
            onProgress?.call(
              p.clamp(0.0, 0.9),
              'Montando PDF (${i + 1}/$total)',
            );
          }
        }
      }

      pdf.addPage(
        pw.MultiPage(
          pageTheme: const pw.PageTheme(
            margin: pw.EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          ),
          // Evita TooManyPagesException em exportações com milhares de linhas
          maxPages: 2000,
          header: (ctx) => pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    _safe('Relatorio de Analises de Agua', asciiOnly),
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  if (codigo != null)
                    pw.Text(
                      _safe('Filtro codigo: $codigo', asciiOnly),
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  if (inicio != null && fim != null)
                    pw.Text(
                      _safe(
                        'Periodo: ${DateFormat('dd/MM/yyyy').format(inicio)} - ${DateFormat('dd/MM/yyyy').format(fim)}',
                        asciiOnly,
                      ),
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  pw.SizedBox(height: 4),
                  pw.Container(height: 1, width: 250, color: PdfColors.grey400),
                ],
              ),
              if (logoBytes != null)
                pw.Container(
                  height: 40,
                  width: 40,
                  child: pw.Image(
                    pw.MemoryImage(logoBytes),
                    fit: pw.BoxFit.contain,
                  ),
                ),
            ],
          ),
          footer: (ctx) => pw.Align(
            alignment: pw.Alignment.centerRight,
            // Evitar caractere bullet (U+2022) e acentos
            child: pw.Text(
              _safe(
                'Gerado em ${_dfDate.format(DateTime.now())} - Pagina ${ctx.pageNumber}/${ctx.pagesCount}',
                asciiOnly,
              ),
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
          build: (ctx) {
            onProgress?.call(0.9, 'Renderizando');
            if (registros.isEmpty) {
              return [
                pw.Text(
                  _safe('Nenhum registro encontrado.', asciiOnly),
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ];
            }
            // Montar header e linhas manualmente para permitir estilização condicional
            final List<String> tableHeaders = [
              _safe('Data/Hora', asciiOnly),
              _safe('Tipo', asciiOnly),
              _safe('Codigo', asciiOnly),
              ...parametros.map((p) => _safe(p, asciiOnly)),
              _safe('Obs', asciiOnly),
            ];

            final widgets = <pw.Widget>[
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey400,
                  width: 0.4,
                ),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.blueGrey700,
                    ),
                    children: tableHeaders
                        .map(
                          (h) => pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(
                              vertical: 6,
                              horizontal: 4,
                            ),
                            child: pw.Text(
                              h,
                              style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  ...rows.map((cols) {
                    return pw.TableRow(
                      children: [
                        for (int i = 0; i < cols.length; i++)
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 4,
                            ),
                            color: _cellColor(
                              parametros,
                              i,
                              cols,
                              tableHeaders,
                              registros,
                              _faixas,
                            ),
                            child: pw.Text(
                              _safe(cols[i], asciiOnly),
                              style: const pw.TextStyle(fontSize: 8),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 14),
              pw.Text(
                _safe('Total de registros: ${registros.length}', asciiOnly),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ];
            if (incluirLegenda) {
              widgets.add(pw.SizedBox(height: 10));
              widgets.add(
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      width: 14,
                      height: 14,
                      color: PdfColors.red100,
                      margin: const pw.EdgeInsets.only(right: 6),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        _safe(
                          'Celulas destacadas em vermelho indicam valores fora da faixa ideal definida para cada parametro.',
                          asciiOnly,
                        ),
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                  ],
                ),
              );
            }
            return widgets;
          },
        ),
      );

      final out = await pdf.save();
      onProgress?.call(1.0, 'Concluído');
      return out;
    } catch (e, st) {
      debugPrint('Erro ao gerar PDF: $e');
      debugPrint('Stack: $st');
      rethrow;
    }
  }

  /// Salva/compartilha Excel conforme plataforma
  static Future<void> exportarExcel({
    String? codigo,
    String? tipo,
    DateTime? inicio,
    DateTime? fim,
    ExportProgress? onProgress,
    void Function(String nome, String? path)? onDone,
  }) async {
    // Normalizar datas para início/fim do dia se apenas datas foram passadas (time 00:00:00)
    DateTime? inicioNorm = inicio != null
        ? DateTime(inicio.year, inicio.month, inicio.day, 0, 0, 0)
        : null;
    DateTime? fimNorm = fim != null
        ? DateTime(fim.year, fim.month, fim.day, 23, 59, 59, 999)
        : null;
    onProgress?.call(0.02, 'Consultando dados (pode levar alguns segundos)');
    final registros = await obterAnalises(
      codigo: codigo,
      inicio: inicioNorm,
      fim: fimNorm,
    );
    final bytes = await gerarExcelAnalises(registros, onProgress: onProgress);
    final nome = _montarNomeArquivo(
      'analises',
      extensao: 'xlsx',
      codigo: codigo,
      tipo: tipo,
      inicio: inicio,
      fim: fim,
      quantidade: registros.length,
    );

    if (kIsWeb) {
      onProgress?.call(0.98, 'Baixando');
      await webDownloadBytes(
        bytes,
        nome,
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      try {
        onDone?.call(nome, null);
      } catch (_) {}
      onProgress?.call(1.0, 'Concluído');
    } else {
      final file = await _salvarEmDispositivo(
        bytes,
        nome,
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      if (file == null) {
        // Fallback share se não conseguiu salvar (API nova do SharePlus)
        await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile.fromData(
                bytes,
                name: nome,
                mimeType:
                    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
              ),
            ],
          ),
        );
        try {
          onDone?.call(nome, null);
        } catch (_) {}
      } else {
        // opcional: compartilhar após salvar? Mantendo apenas salvamento silencioso por enquanto
        try {
          onDone?.call(nome, file.path);
        } catch (_) {}
      }
      onProgress?.call(1.0, 'Concluído');
    }
  }

  /// Salva/compartilha PDF conforme plataforma
  static Future<void> exportarPdf({
    String? codigo,
    String? tipo,
    DateTime? inicio,
    DateTime? fim,
    Uint8List? logoBytes,
    bool incluirLegenda = true,
    ExportProgress? onProgress,
    void Function(String nome, String? path)? onDone,
  }) async {
    try {
      DateTime? inicioNorm = inicio != null
          ? DateTime(inicio.year, inicio.month, inicio.day, 0, 0, 0)
          : null;
      DateTime? fimNorm = fim != null
          ? DateTime(fim.year, fim.month, fim.day, 23, 59, 59, 999)
          : null;
      onProgress?.call(0.02, 'Consultando dados (pode levar alguns segundos)');
      debugPrint(
        '[PDF] Iniciando exportação. Filtros: codigo=$codigo, tipo=$tipo, inicio=$inicio, fim=$fim',
      );
      final registros = await obterAnalises(
        codigo: codigo,
        inicio: inicioNorm,
        fim: fimNorm,
      );
      debugPrint('[PDF] Registros obtidos: ${registros.length}');
      final bytes = await gerarPdfAnalises(
        registros,
        codigo: codigo,
        inicio: inicio,
        fim: fim,
        logoBytes: logoBytes,
        incluirLegenda: incluirLegenda,
        onProgress: onProgress,
      );
      debugPrint('[PDF] Bytes gerados: ${bytes.length}');
      final nome = _montarNomeArquivo(
        'analises',
        extensao: 'pdf',
        codigo: codigo,
        tipo: tipo,
        inicio: inicio,
        fim: fim,
        quantidade: registros.length,
      );

      if (kIsWeb) {
        onProgress?.call(0.98, 'Baixando');
        await webDownloadBytes(bytes, nome, mimeType: 'application/pdf');
        debugPrint('[PDF] Download web disparado: $nome');
        try {
          onDone?.call(nome, null);
        } catch (_) {}
        onProgress?.call(1.0, 'Concluído');
      } else {
        final file = await _salvarEmDispositivo(
          bytes,
          nome,
          mimeType: 'application/pdf',
        );
        if (file == null) {
          debugPrint('[PDF] Salvamento direto indisponível. Fazendo share...');
          await SharePlus.instance.share(
            ShareParams(
              files: [
                XFile.fromData(bytes, name: nome, mimeType: 'application/pdf'),
              ],
            ),
          );
          try {
            onDone?.call(nome, null);
          } catch (_) {}
        } else {
          debugPrint('[PDF] Arquivo salvo em: ${file.path}');
          try {
            onDone?.call(nome, file.path);
          } catch (_) {}
        }
        onProgress?.call(1.0, 'Concluído');
      }
    } catch (e, st) {
      debugPrint('Erro em exportarPdf: $e');
      debugPrint('Stack: $st');
      rethrow;
    }
  }
}

/// Salva arquivo em Downloads no Android (quando possível) ou em diretório temporário como fallback.
Future<File?> _salvarEmDispositivo(
  Uint8List bytes,
  String nome, {
  required String mimeType,
}) async {
  try {
    // Permissões no Android (WRITE_EXTERNAL_STORAGE é legacy; permission_handler abstrai)
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        return null; // sem permissão -> fallback share
      }
      // API recente: sem acesso direto ao Downloads. Usar external storage app-specific
      final ext = await getExternalStorageDirectory();
      if (ext != null) {
        final dir = Directory('${ext.path}/Documents');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        final file = File('${dir.path}/$nome');
        await file.writeAsBytes(bytes, flush: true);
        return file;
      }
    }
    // Outras plataformas ou se falhou -> temp directory
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$nome');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  } catch (_) {
    return null;
  }
}

String _sanitize(String v) {
  return v.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_\-]'), '');
}

String _montarNomeArquivo(
  String base, {
  required String extensao,
  String? codigo,
  String? tipo,
  DateTime? inicio,
  DateTime? fim,
  int? quantidade,
}) {
  final partes = <String>[base];
  if (tipo != null) partes.add(_sanitize(tipo));
  if (codigo != null) partes.add(_sanitize(codigo));
  if (inicio != null && fim != null) {
    final df = DateFormat('yyyyMMdd');
    partes.add('${df.format(inicio)}_${df.format(fim)}');
  }
  if (quantidade != null) partes.add('q${quantidade.toString()}');
  final nome = partes.join('_');
  return '$nome.$extensao';
}

// Função auxiliar para colorir células de valores fora da faixa
PdfColor? _cellColor(
  List<String> parametros,
  int index,
  List<String> cols,
  List<String> headers,
  List<Map<String, dynamic>> registros,
  Map<String, List<double>> faixas,
) {
  // Índices: Data/Hora(0), Tipo(1), Código(2), parametros..., Obs(ultimo)
  if (index < 3) return null; // não colorir meta info
  if (index == headers.length - 1) return null; // obs
  final paramIndex = index - 3; // deslocar
  if (paramIndex < 0 || paramIndex >= parametros.length) return null;
  final paramName = parametros[paramIndex];
  final faixa = faixas[paramName];
  if (faixa == null) return null;
  final valorStr = cols[index];
  final valor = double.tryParse(valorStr.replaceAll(',', '.'));
  if (valor == null) return null;
  if (valor < faixa[0] || valor > faixa[1]) {
    return PdfColors.red100;
  }
  return null;
}
