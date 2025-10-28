import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../helpers/export_helper.dart';
import '../helpers/destinos_cache.dart';
import '../widgets/app_scaffold.dart';

class TelaRelatorioAnaliseAgua extends StatefulWidget {
  const TelaRelatorioAnaliseAgua({super.key});

  @override
  State<TelaRelatorioAnaliseAgua> createState() =>
      _TelaRelatorioAnaliseAguaState();
}

class _TelaRelatorioAnaliseAguaState extends State<TelaRelatorioAnaliseAgua> {
  DateTime? _inicio;
  DateTime? _fim;
  String? _tipo; // viveiro / bercario
  String? _codigo; // código filtrado
  bool _carregando = false;
  bool _exportando = false;
  double _progresso = 0;
  String? _progressoMsg;
  String? _ultimoArquivo;
  bool _atualizandoDestinos = false;
  Uint8List? _logoBytes;
  final _parametros = const [
    'ph',
    'oxigenio',
    'temperatura',
    'turbidez',
    'saturacao_percentual',
    'saturacao_oxigenio',
    'salinidade',
    'calcio',
    'nitrito',
    'amonia',
  ];
  String _parametroSelecionado = 'ph';
  List<Map<String, dynamic>> _registros = [];
  final Map<String, Map<String, dynamic>> _estatisticas = {};
  // Mapas separados para evitar heurísticas
  final Map<String, String> _viveiros = {}; // codigo -> nome
  final Map<String, String> _bercarios = {}; // codigo -> nome

  @override
  void initState() {
    super.initState();
    // Inicialmente sem intervalo definido; usuário escolhe manualmente
    _inicio = null;
    _fim = null;
    _carregarLogo();
    _carregarDestinos();
  }

  Future<void> _carregarLogo() async {
    try {
      final data = await rootBundle.load('assets/images/logo.png');
      setState(() => _logoBytes = data.buffer.asUint8List());
    } catch (_) {}
  }

  Future<void> _carregarDestinos() async {
    try {
      if (mounted) setState(() => _atualizandoDestinos = true);
      final v = await DestinosCache.obterViveiros();
      final b = await DestinosCache.obterBercarios();
      _viveiros
        ..clear()
        ..addAll(v);
      _bercarios
        ..clear()
        ..addAll(b);
      if (mounted) setState(() {});
    } catch (_) {
    } finally {
      if (mounted) setState(() => _atualizandoDestinos = false);
    }
  }

  bool _matchTipo(Map<String, dynamic> reg) {
    if (_tipo == null) return true;
    final t = reg['tipoDestino'];
    if (t == null) return false;
    return t == _tipo;
  }

  bool _matchCodigo(Map<String, dynamic> reg) {
    if (_codigo == null) return true;
    return reg['codigo'] == _codigo;
  }

  Future<void> _buscar() async {
    if (_inicio == null || _fim == null) return;
    if (_fim!.isBefore(_inicio!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data fim não pode ser anterior à data início'),
        ),
      );
      return;
    }
    setState(() => _carregando = true);
    try {
      final inicioDay = DateTime(
        _inicio!.year,
        _inicio!.month,
        _inicio!.day,
        0,
        0,
        0,
      );
      final fimDay = DateTime(_fim!.year, _fim!.month, _fim!.day, 23, 59, 59);
      final registros = await ExportHelper.obterAnalises(
        inicio: inicioDay,
        fim: fimDay,
        codigo: null,
      );
      _registros = registros.where(_matchTipo).where(_matchCodigo).toList();
      _calcularEstatisticas();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao buscar: $e')));
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _calcularEstatisticas() {
    _estatisticas.clear();
    for (final p in _parametros) {
      final valores = <double>[];
      for (final r in _registros) {
        final v = r[p];
        if (v is num) valores.add(v.toDouble());
      }
      if (valores.isEmpty) continue;
      valores.sort();
      final media = valores.reduce((a, b) => a + b) / valores.length;
      final min = valores.first;
      final max = valores.last;
      // Mediana
      final n = valores.length;
      final mediana = (n % 2 == 1)
          ? valores[n ~/ 2]
          : ((valores[n ~/ 2 - 1] + valores[n ~/ 2]) / 2);
      // Desvio padrão (populacional)
      double soma2 = 0;
      for (final x in valores) {
        final d = x - media;
        soma2 += d * d;
      }
      final desvio = (n == 0) ? 0.0 : math.sqrt(soma2 / n);
      final foraFaixa = _contarForaFaixa(p, valores);
      _estatisticas[p] = {
        'media': media,
        'mediana': mediana,
        'desvio': desvio,
        'min': min,
        'max': max,
        'qtd': valores.length,
        'fora': foraFaixa,
      };
    }
    setState(() {});
  }

  String _tituloParametro(String nome) {
    switch (nome) {
      case 'ph':
        return 'pH';
      case 'oxigenio':
        return 'Oxigênio';
      case 'temperatura':
        return 'Temperatura';
      case 'turbidez':
        return 'Turbidez';
      case 'saturacao_percentual':
        return 'Saturação %';
      case 'saturacao_oxigenio':
        return 'Sat. O2 %';
      case 'salinidade':
        return 'Salinidade';
      case 'calcio':
        return 'Cálcio';
      case 'nitrito':
        return 'Nitrito';
      case 'amonia':
        return 'Amônia';
    }
    return nome;
  }

  List<Map<String, dynamic>> _dadosParaGrafico(String parametro) {
    // Converte registros filtrados em lista ordenada com timestamp e valor numérico
    final lista = <Map<String, dynamic>>[];
    for (final r in _registros) {
      final ts = r['dataHora'];
      DateTime? dt;
      if (ts is Timestamp) dt = ts.toDate();
      if (dt == null) continue;
      final v = r[parametro];
      double? valor;
      if (v is num) {
        valor = v.toDouble();
      } else if (v is String) {
        valor = double.tryParse(v.replaceAll(',', '.'));
      }
      if (valor == null) continue;
      lista.add({'timestamp': dt, 'valor': valor});
    }
    lista.sort(
      (a, b) =>
          (a['timestamp'] as DateTime).compareTo(b['timestamp'] as DateTime),
    );
    return lista;
  }

  int _contarForaFaixa(String p, List<double> valores) {
    // Usa faixas globais expostas pelo ExportHelper para manter consistência com exportação PDF/Excel
    final faixa = ExportHelper.faixas[p];
    if (faixa == null) return 0;
    return valores.where((v) => v < faixa[0] || v > faixa[1]).length;
  }

  Future<void> _exportarPdf() async {
    if (_exportando) return;
    if (!await _validarAntesDeExportarAsync()) return;
    setState(() => _exportando = true);
    try {
      await ExportHelper.exportarPdf(
        codigo: _codigo,
        tipo: _tipo,
        inicio: _inicio,
        fim: _fim,
        logoBytes: _logoBytes,
        onProgress: (p, stage) {
          if (mounted) {
            setState(() {
              _progresso = p;
              _progressoMsg = stage;
            });
          }
        },
        onDone: (nome, path) {
          if (!mounted) return;
          setState(() => _ultimoArquivo = nome);
          final msg = path == null
              ? 'PDF baixado: $nome'
              : 'PDF salvo: $nome\n$path';
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
        },
      );
      if (mounted) {}
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Falha ao exportar PDF: $e')));
      }
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  void _limparFiltros() {
    setState(() {
      _inicio = null;
      _fim = null;
      _tipo = null;
      _codigo = null;
      _registros.clear();
      _estatisticas.clear();
    });
  }

  Future<void> _exportarExcel() async {
    if (_exportando) return;
    if (!await _validarAntesDeExportarAsync()) return;
    setState(() => _exportando = true);
    try {
      await ExportHelper.exportarExcel(
        codigo: _codigo,
        tipo: _tipo,
        inicio: _inicio,
        fim: _fim,
        onProgress: (p, stage) {
          if (mounted) {
            setState(() {
              _progresso = p;
              _progressoMsg = stage;
            });
          }
        },
        onDone: (nome, path) {
          if (!mounted) return;
          setState(() => _ultimoArquivo = nome);
          final msg = path == null
              ? 'Excel baixado: $nome'
              : 'Excel salvo: $nome\n$path';
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
        },
      );
      if (mounted) {}
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Falha ao exportar Excel: $e')));
      }
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  Future<void> _pickInicio() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _inicio ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (d != null) {
      setState(() => _inicio = d);
      if (_inicio != null && _fim != null) {
        _buscar();
      }
    }
  }

  Future<void> _pickFim() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _fim ?? _inicio ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (d != null) {
      setState(() => _fim = d);
      if (_inicio != null && _fim != null) {
        _buscar();
      }
    }
  }

  String _format(DateTime? d) {
    if (d == null) return '-';
    return DateFormat('dd/MM/yyyy').format(d);
  }

  List<DropdownMenuItem<String>> _buildCodigoItems() {
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: null, child: Text('Todos')),
    ];

    int? numeroFrom(String codigo) {
      final match = RegExp(r'(\d+)').firstMatch(codigo);
      if (match == null) return null;
      return int.tryParse(match.group(0)!);
    }

    List<MapEntry<String, String>> ordenar(Map<String, String> mapa) {
      final list = mapa.entries.toList();
      list.sort((a, b) {
        final na = numeroFrom(a.key);
        final nb = numeroFrom(b.key);
        if (na != null && nb != null) return na.compareTo(nb);
        return a.key.compareTo(b.key);
      });
      return list;
    }

    if (_tipo == 'viveiro') {
      for (final e in ordenar(_viveiros)) {
        items.add(
          DropdownMenuItem(value: e.key, child: Text('${e.value} (${e.key})')),
        );
      }
    } else if (_tipo == 'bercario') {
      for (final e in ordenar(_bercarios)) {
        items.add(
          DropdownMenuItem(value: e.key, child: Text('${e.value} (${e.key})')),
        );
      }
    } else {
      // Agrupado com cabeçalhos visuais (desabilitados)
      if (_viveiros.isNotEmpty) {
        items.add(
          DropdownMenuItem<String>(
            enabled: false,
            value: '__HEADER_VIVEIROS__',
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Viveiros (${_viveiros.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
            ),
          ),
        );
        for (final e in ordenar(_viveiros)) {
          // Valor carrega o tipo para desambiguar códigos iguais entre grupos
          items.add(
            DropdownMenuItem(
              value: 'viveiro|${e.key}',
              child: Text('${e.value} (${e.key})'),
            ),
          );
        }
      }
      if (_bercarios.isNotEmpty) {
        items.add(
          DropdownMenuItem<String>(
            enabled: false,
            value: '__HEADER_BERCARIOS__',
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Berçários (${_bercarios.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
            ),
          ),
        );
        for (final e in ordenar(_bercarios)) {
          items.add(
            DropdownMenuItem(
              value: 'bercario|${e.key}',
              child: Text('${e.value} (${e.key})'),
            ),
          );
        }
      }
    }
    return items;
  }

  Future<bool> _validarAntesDeExportarAsync() async {
    // Datas
    if (_inicio != null && _fim == null) {
      _snack('Selecione também a data final.');
      return false;
    }
    if (_fim != null && _inicio == null) {
      _snack('Selecione a data inicial.');
      return false;
    }
    if (_inicio != null && _fim != null && _fim!.isBefore(_inicio!)) {
      _snack('Data final não pode ser anterior à inicial.');
      return false;
    }
    if (_inicio != null && _fim != null) {
      final diff = _fim!.difference(_inicio!).inDays + 1;
      if (diff > 31) {
        _snack('Intervalo muito grande ($diff dias). Limite: 31 dias.');
        return false;
      }
    }
    // Código exige intervalo
    if (_codigo != null && (_inicio == null || _fim == null)) {
      _snack('Defina intervalo de datas para exportar um destino específico.');
      return false;
    }
    // Sem filtros e sem datas -> confirmar
    final exportGeral =
        _tipo == null && _codigo == null && _inicio == null && _fim == null;
    if (exportGeral) {
      // Confirmação 1 (geral)
      final r1 = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Confirmar'),
          content: const Text(
            'Exportar TODOS os registros? Isso pode gerar um arquivo grande.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );
      if (r1 != true) return false;

      // Pré-checagem de volume (threshold)
      const limite = 5000;
      try {
        final count = await ExportHelper.contarAnalises();
        if (count > limite) {
          if (!mounted) return false;
          final r2 = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Muitos registros'),
              content: Text(
                'Serão exportados aproximadamente $count registros. Deseja continuar mesmo assim?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Continuar'),
                ),
              ],
            ),
          );
          if (r2 != true) return false;
        }
      } catch (_) {}
      return true;
    }
    return true;
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Relatório - Análise de Água',
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.water_drop, size: 52, color: Colors.teal),
                  SizedBox(height: 8),
                  Text(
                    'Relatório - Análise de Água',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Filtre, visualize estatísticas e exporte análises de água em PDF ou Excel. Valores fora de faixa ajudam a detectar desvios rapidamente.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.teal,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  SizedBox(height: 20),
                ],
              ),
              if (_inicio != null ||
                  _fim != null ||
                  _tipo != null ||
                  _codigo != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Ativo: ${[if (_inicio != null && _fim != null) 'Período ${DateFormat('dd/MM').format(_inicio!)} a ${DateFormat('dd/MM').format(_fim!)}', if (_tipo != null) 'Tipo $_tipo', if (_codigo != null) 'Código $_codigo'].join(' • ')}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Filtros',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Ajuda/legenda de filtros
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blue.shade100),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue),
                            SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Dicas para filtrar',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    '• Defina Início e Fim (máx. 31 dias) para carregar dados e estatísticas.',
                                  ),
                                  Text(
                                    '• Use Tipo e Código para refinar: a lista é agrupada por Viveiros/Berçários e aceita códigos iguais em grupos.',
                                  ),
                                  Text(
                                    '• Ao escolher um Código sem Tipo, o tipo é definido automaticamente.',
                                  ),
                                  Text(
                                    '• “Atualizar lista” recarrega viveiros/berçários do Firestore.',
                                  ),
                                  Text(
                                    '• Exportar sem filtros exporta geral (pode gerar arquivos grandes).',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        children: [
                          _FiltroBox(
                            label: 'Início',
                            value: _format(_inicio),
                            icon: Icons.calendar_month,
                            onTap: _pickInicio,
                          ),
                          _FiltroBox(
                            label: 'Fim',
                            value: _format(_fim),
                            icon: Icons.event,
                            onTap: _pickFim,
                          ),
                          SizedBox(
                            width: 190,
                            child: DropdownButtonFormField<String>(
                              initialValue: _tipo,
                              decoration: const InputDecoration(
                                labelText: 'Tipo',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'viveiro',
                                  child: Text('Viveiro'),
                                ),
                                DropdownMenuItem(
                                  value: 'bercario',
                                  child: Text('Berçário'),
                                ),
                              ],
                              onChanged: (v) {
                                setState(() {
                                  _tipo = v;
                                  _codigo = null;
                                });
                                _buscar();
                              },
                            ),
                          ),
                          SizedBox(
                            width: 240,
                            child: DropdownButtonFormField<String>(
                              initialValue: (_tipo == null)
                                  ? ((_codigo != null && _tipo != null)
                                        ? '$_tipo|$_codigo'
                                        : null)
                                  : _codigo,
                              decoration: const InputDecoration(
                                labelText: 'Código',
                              ),
                              items: _buildCodigoItems(),
                              onChanged: (v) {
                                if (v == null) {
                                  setState(() {
                                    _codigo = null;
                                  });
                                  _buscar();
                                  return;
                                }
                                if (v.contains('|')) {
                                  final parts = v.split('|');
                                  final t = parts.isNotEmpty ? parts[0] : null;
                                  final c = parts.length > 1 ? parts[1] : null;
                                  setState(() {
                                    _tipo = t;
                                    _codigo = c;
                                  });
                                  _buscar();
                                } else {
                                  setState(() => _codigo = v);
                                  _buscar();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final exportGeral =
                              _tipo == null &&
                              _codigo == null &&
                              _inicio == null &&
                              _fim == null;
                          final children = <Widget>[
                            Tooltip(
                              message: 'Limpar filtros e estatísticas',
                              child: OutlinedButton.icon(
                                onPressed: _carregando && _registros.isNotEmpty
                                    ? null
                                    : _limparFiltros,
                                icon: const Icon(Icons.filter_alt_off),
                                label: const Text('Limpar'),
                              ),
                            ),
                            Tooltip(
                              message:
                                  'Exportar PDF (salva/baixa conforme plataforma)',
                              child: ElevatedButton.icon(
                                onPressed:
                                    _exportando ||
                                        (_registros.isEmpty && !exportGeral)
                                    ? null
                                    : _exportarPdf,
                                icon: const Icon(Icons.picture_as_pdf),
                                label: Text(
                                  _exportando
                                      ? 'Processando...'
                                      : 'Exportar PDF',
                                ),
                              ),
                            ),
                            Tooltip(
                              message:
                                  'Exportar Excel (salva/baixa conforme plataforma)',
                              child: ElevatedButton.icon(
                                onPressed:
                                    _exportando ||
                                        (_registros.isEmpty && !exportGeral)
                                    ? null
                                    : _exportarExcel,
                                icon: const Icon(Icons.table_view),
                                label: Text(
                                  _exportando
                                      ? 'Processando...'
                                      : 'Exportar Excel',
                                ),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: _atualizandoDestinos
                                  ? null
                                  : () async {
                                      DestinosCache.limpar();
                                      await _carregarDestinos();
                                      setState(() => _codigo = null);
                                    },
                              icon: _atualizandoDestinos
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.refresh),
                              label: Text(
                                _atualizandoDestinos
                                    ? 'Atualizando...'
                                    : 'Atualizar lista',
                              ),
                            ),
                            if (_exportando)
                              Padding(
                                padding: const EdgeInsets.only(left: 12),
                                child: SizedBox(
                                  width: 240,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      LinearProgressIndicator(
                                        value:
                                            (_progresso >= 0.05 &&
                                                _progresso < 1)
                                            ? _progresso
                                            : null,
                                      ),
                                      const SizedBox(height: 4),
                                      if (_progressoMsg != null)
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                _progressoMsg!,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.black54,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '${(_progresso * 100).clamp(0, 100).toStringAsFixed(0)}%',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.black54,
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            if (_ultimoArquivo != null && !_exportando)
                              Tooltip(
                                message: 'Último nome de arquivo gerado',
                                child: Text(
                                  'Último arquivo: $_ultimoArquivo',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                            if (_carregando)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                          ];
                          // Se a largura é pequena, usar Wrap vertical / quebra automática
                          if (constraints.maxWidth < 600) {
                            return Wrap(
                              spacing: 12,
                              runSpacing: 10,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: children,
                            );
                          }
                          return Row(
                            children: [
                              ...children
                                  .expand((w) => [w, const SizedBox(width: 12)])
                                  .toList()
                                  .sublist(0, children.length * 2 - 1),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              // Card de gráfico por parâmetro
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.show_chart, color: Colors.teal),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Gráfico por parâmetro',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 220,
                            child: DropdownButtonFormField<String>(
                              initialValue: _parametroSelecionado,
                              decoration: const InputDecoration(
                                labelText: 'Parâmetro',
                              ),
                              items: _parametros
                                  .map(
                                    (p) => DropdownMenuItem(
                                      value: p,
                                      child: Text(_tituloParametro(p)),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v != null)
                                  setState(() => _parametroSelecionado = v);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Builder(
                        builder: (_) {
                          final dados = _dadosParaGrafico(
                            _parametroSelecionado,
                          );
                          if ((_inicio == null || _fim == null)) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'Selecione um intervalo de datas para exibir o gráfico.',
                              ),
                            );
                          }
                          if (dados.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text('Sem dados para o período/filtros.'),
                            );
                          }
                          final spots = <FlSpot>[];
                          for (var i = 0; i < dados.length; i++) {
                            spots.add(
                              FlSpot(
                                i.toDouble(),
                                (dados[i]['valor'] as double),
                              ),
                            );
                          }
                          final ys = spots.map((e) => e.y).toList();
                          double minY = ys.reduce((a, b) => a < b ? a : b);
                          double maxY = ys.reduce((a, b) => a > b ? a : b);
                          if (minY == maxY) {
                            minY -= 1;
                            maxY += 1;
                          }
                          final faixa =
                              ExportHelper.faixas[_parametroSelecionado];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: 240,
                                child: LineChart(
                                  LineChartData(
                                    minY: minY.floorToDouble(),
                                    maxY: maxY.ceilToDouble(),
                                    minX: 0,
                                    maxX: spots.length > 1
                                        ? (spots.length - 1).toDouble()
                                        : 1,
                                    gridData: const FlGridData(show: true),
                                    titlesData: FlTitlesData(
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 40,
                                          getTitlesWidget: (v, meta) => Text(
                                            v.toStringAsFixed(1),
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 36,
                                          getTitlesWidget: (v, meta) {
                                            final idx = v.round();
                                            if (idx < 0 || idx >= dados.length)
                                              return const SizedBox.shrink();
                                            final dt =
                                                dados[idx]['timestamp']
                                                    as DateTime;
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                top: 8,
                                              ),
                                              child: Text(
                                                DateFormat('dd/MM').format(dt),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                ),
                                              ),
                                            );
                                          },
                                          interval: (spots.length / 6)
                                              .clamp(1, double.infinity)
                                              .toDouble(),
                                        ),
                                      ),
                                      rightTitles: const AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                      topTitles: const AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                    ),
                                    borderData: FlBorderData(
                                      show: true,
                                      border: const Border.symmetric(
                                        horizontal: BorderSide(),
                                        vertical: BorderSide(),
                                      ),
                                    ),
                                    lineBarsData: [
                                      LineChartBarData(
                                        spots: spots,
                                        isCurved: true,
                                        color: Colors.teal,
                                        barWidth: 3,
                                        dotData: FlDotData(
                                          show: true,
                                          getDotPainter:
                                              (spot, percent, bar, index) {
                                                if (faixa != null) {
                                                  final y = spot.y;
                                                  final fora =
                                                      y < faixa[0] ||
                                                      y > faixa[1];
                                                  if (fora) {
                                                    return FlDotCirclePainter(
                                                      radius: 3,
                                                      color: Colors.red,
                                                      strokeWidth: 1,
                                                      strokeColor:
                                                          Colors.redAccent,
                                                    );
                                                  }
                                                }
                                                return FlDotCirclePainter(
                                                  radius: 3,
                                                  color: Colors.teal,
                                                  strokeWidth: 1,
                                                  strokeColor:
                                                      Colors.teal.shade700,
                                                );
                                              },
                                        ),
                                        belowBarData: BarAreaData(
                                          show: true,
                                          color: Colors.teal.withValues(
                                            alpha: 0.12,
                                          ),
                                        ),
                                      ),
                                    ],
                                    lineTouchData: LineTouchData(
                                      enabled: true,
                                      touchTooltipData: LineTouchTooltipData(
                                        getTooltipItems: (touched) => touched
                                            .map((s) {
                                              final idx = s.x.round();
                                              if (idx < 0 ||
                                                  idx >= dados.length)
                                                return null;
                                              final dt =
                                                  dados[idx]['timestamp']
                                                      as DateTime;
                                              return LineTooltipItem(
                                                '${DateFormat('dd/MM/yyyy HH:mm').format(dt)}\n${s.y.toStringAsFixed(2)}',
                                                const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              );
                                            })
                                            .whereType<LineTooltipItem>()
                                            .toList(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (faixa != null)
                                Text(
                                  'Faixa ideal: ${faixa[0]} - ${faixa[1]}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estatísticas (${_registros.length} registros filtrados)',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _estatisticas.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: Text(
                                  (_inicio == null || _fim == null)
                                      ? 'Selecione um intervalo de datas para visualizar estatísticas.'
                                      : 'Sem dados no período / filtros.',
                                ),
                              ),
                            )
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: WidgetStatePropertyAll(
                                  Colors.green.shade100,
                                ),
                                columns: const [
                                  DataColumn(label: Text('Parâmetro')),
                                  DataColumn(label: Text('Média')),
                                  DataColumn(label: Text('Mediana')),
                                  DataColumn(label: Text('Desvio')),
                                  DataColumn(label: Text('Mín')),
                                  DataColumn(label: Text('Máx')),
                                  DataColumn(label: Text('Qtd')),
                                  DataColumn(label: Text('Fora')),
                                ],
                                rows: _estatisticas.entries.map((e) {
                                  final nome = e.key;
                                  final dados = e.value;
                                  String titulo = nome;
                                  switch (nome) {
                                    case 'ph':
                                      titulo = 'pH';
                                      break;
                                    case 'oxigenio':
                                      titulo = 'Oxigênio';
                                      break;
                                    case 'temperatura':
                                      titulo = 'Temperatura';
                                      break;
                                    case 'turbidez':
                                      titulo = 'Turbidez';
                                      break;
                                    case 'saturacao_percentual':
                                      titulo = 'Sat. %';
                                      break;
                                    case 'saturacao_oxigenio':
                                      titulo = 'Sat. O2 %';
                                      break;
                                    case 'salinidade':
                                      titulo = 'Salinidade';
                                      break;
                                    case 'calcio':
                                      titulo = 'Cálcio';
                                      break;
                                    case 'nitrito':
                                      titulo = 'Nitrito';
                                      break;
                                    case 'amonia':
                                      titulo = 'Amônia';
                                      break;
                                  }
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(titulo)),
                                      DataCell(Text(_fmt(dados['media']))),
                                      DataCell(Text(_fmt(dados['mediana']))),
                                      DataCell(Text(_fmt(dados['desvio']))),
                                      DataCell(Text(_fmt(dados['min']))),
                                      DataCell(Text(_fmt(dados['max']))),
                                      DataCell(Text(dados['qtd'].toString())),
                                      DataCell(
                                        Text(
                                          dados['fora'].toString(),
                                          style: TextStyle(
                                            color: (dados['fora'] as int) > 0
                                                ? Colors.red
                                                : Colors.green,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(dynamic v) {
    if (v is num) {
      return v.toStringAsFixed(v % 1 == 0 ? 0 : 2);
    }
    return '-';
  }
}

class _FiltroBox extends StatelessWidget {
  const _FiltroBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: Colors.green.shade700),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
