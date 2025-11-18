import 'package:flutter/material.dart';
import 'package:viveiro_plus/helpers/parametros_analise_helper.dart';
import 'package:viveiro_plus/widgets/app_scaffold.dart';
import 'package:viveiro_plus/widgets/degrade_fundo.dart';

class TelaParametrizacaoAgua extends StatefulWidget {
  const TelaParametrizacaoAgua({super.key});

  @override
  State<TelaParametrizacaoAgua> createState() => _TelaParametrizacaoAguaState();
}

class _TelaParametrizacaoAguaState extends State<TelaParametrizacaoAgua> {
  Map<String, Map<String, double>> _faixas =
      ParametrosAnaliseHelper.getDefaultsAsDouble();
  bool _salvando = false;
  bool _carregando = true;

  final List<Map<String, String>> _parametros = const [
    {'chave': 'ph', 'rotulo': 'pH da Água'},
    {'chave': 'oxigenio', 'rotulo': 'Oxigênio Dissolvido (mg/L)'},
    {'chave': 'saturacao_percentual', 'rotulo': 'Saturação (%)'},
    {'chave': 'temperatura', 'rotulo': 'Temperatura (°C)'},
    {'chave': 'turbidez', 'rotulo': 'Turbidez (NTU)'},
    {'chave': 'salinidade', 'rotulo': 'Salinidade (ppt)'},
    {'chave': 'calcio', 'rotulo': 'Cálcio (mg/L)'},
    {'chave': 'nitrito', 'rotulo': 'Nitrito (mg/L)'},
    {'chave': 'amonia', 'rotulo': 'Amônia (mg/L)'},
  ];

  final Map<String, TextEditingController> _minCtrls = {};
  final Map<String, TextEditingController> _maxCtrls = {};

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final mapa = await ParametrosAnaliseHelper.carregarTodos();
    if (!mounted) return;
    setState(() {
      _faixas = mapa;
      _carregando = false;
    });
    _inicializarControllers();
  }

  void _inicializarControllers() {
    for (final p in _parametros) {
      final faixa = _faixas[p['chave']]!;
      _minCtrls[p['chave']!] = TextEditingController(
        text: faixa['min'].toString(),
      );
      _maxCtrls[p['chave']!] = TextEditingController(
        text: faixa['max'].toString(),
      );
    }
  }

  Future<void> _salvar() async {
    if (_salvando) return;
    setState(() => _salvando = true);
    try {
      final novo = <String, Map<String, double>>{};
      for (final p in _parametros) {
        final chave = p['chave']!;
        final min = double.tryParse(
          _minCtrls[chave]!.text.replaceAll(',', '.'),
        );
        final max = double.tryParse(
          _maxCtrls[chave]!.text.replaceAll(',', '.'),
        );
        if (min == null || max == null) {
          throw Exception('Valores inválidos em ${p['rotulo']}');
        }
        novo[chave] = {'min': min, 'max': max};
      }
      await ParametrosAnaliseHelper.salvarLote(novo);
      if (mounted) {
        setState(() => _faixas = novo);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Parâmetros atualizados com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  void dispose() {
    for (final c in _minCtrls.values) c.dispose();
    for (final c in _maxCtrls.values) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Parametrização - Água',
      body: DegradeFundo(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _carregando
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    const SizedBox(height: 8),
                    Card(
                      elevation: 0,
                      color: Colors.teal.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Limites de Alertas',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Defina os limites mínimo e máximo de cada parâmetro. Valores fora da faixa serão destacados nas análises.',
                              style: TextStyle(color: Colors.teal),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        itemCount: _parametros.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final p = _parametros[i];
                          final chave = p['chave']!;
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    p['rotulo']!,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _minCtrls[chave],
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: const InputDecoration(
                                      labelText: 'Mín',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _maxCtrls[chave],
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: const InputDecoration(
                                      labelText: 'Máx',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _salvando
                                ? null
                                : () => Navigator.of(context).pop(),
                            child: const Text('Voltar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.save),
                            onPressed: _salvando ? null : _salvar,
                            label: _salvando
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Salvar Alterações'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
