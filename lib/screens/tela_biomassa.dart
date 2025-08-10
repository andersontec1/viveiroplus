// Tela Biomassa com salvamento de histórico por viveiro e listagem dos cálculos anteriores

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/degrade_fundo.dart';
import 'package:fl_chart/fl_chart.dart';

class TelaBiomassa extends StatefulWidget {
  const TelaBiomassa({super.key});

  @override
  State<TelaBiomassa> createState() => _TelaBiomassaState();
}

class _TelaBiomassaState extends State<TelaBiomassa> {
  final _formKey = GlobalKey<FormState>();
  final _sobrevivenciaCtrl = TextEditingController(text: '85');
  final _pesoAmostraCtrl = TextEditingController();
  final _qtdAmostraCtrl = TextEditingController();
  String? _codigoSelecionado;
  Map<String, String> _viveiros = {};
  Map<String, dynamic>? _cicloAtivo;
  bool _calculando = false;

  double? _pesoMedio, _biomassa, _sobrevivencia, _quantidadeViva;

  @override
  void initState() {
    super.initState();
    _carregarViveiros();
  }

  Future<void> _carregarViveiros() async {
    final snap = await FirebaseFirestore.instance
        .collection('viveiros')
        .orderBy('codigo')  // Ordenar por código
        .get();
    final mapa = <String, String>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      mapa[data['codigo']] = data['nome'];
    }
    setState(() => _viveiros = mapa);
  }

  Future<void> _buscarCicloAtivo(String codigo) async {
    print('Debug: Buscando ciclo ativo para código: $codigo');
    try {
      final snap = await FirebaseFirestore.instance
          .collection('ciclos')
          .where('codigo', isEqualTo: codigo)
          .where('encerrado', isEqualTo: false)
          .limit(1)
          .get();
      
      print('Debug: Encontrados ${snap.docs.length} ciclos ativos');
      
      if (snap.docs.isNotEmpty) {
        final dadosCiclo = snap.docs.first.data();
        print('Debug: Dados do ciclo: $dadosCiclo');
        setState(() => _cicloAtivo = dadosCiclo);
      } else {
        print('Debug: Nenhum ciclo ativo encontrado');
        setState(() => _cicloAtivo = null);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('⚠️ Nenhum ciclo ativo encontrado para este viveiro'),
            backgroundColor: Colors.orange,
          ));
        }
      }
    } catch (e) {
      print('Debug: Erro ao buscar ciclo ativo: $e');
      setState(() => _cicloAtivo = null);
    }
  }

  Future<void> _calcularSalvar() async {
    print('Debug: Iniciando _calcularSalvar');
    
    if (!_formKey.currentState!.validate()) {
      print('Debug: Validação do formulário falhou');
      return;
    }
    
    final qtdAmostra = int.tryParse(_qtdAmostraCtrl.text);
    final pesoAmostra = double.tryParse(_pesoAmostraCtrl.text.replaceAll(',', '.'));
    final taxaSobrevivencia = double.tryParse(_sobrevivenciaCtrl.text.replaceAll(',', '.'));
    
    print('Debug: qtdAmostra=$qtdAmostra, pesoAmostra=$pesoAmostra, taxaSobrevivencia=$taxaSobrevivencia');
    print('Debug: _codigoSelecionado=$_codigoSelecionado, _cicloAtivo=$_cicloAtivo');
    
    if (_codigoSelecionado == null || qtdAmostra == null || pesoAmostra == null || _cicloAtivo == null || taxaSobrevivencia == null) {
      print('Debug: Algum campo obrigatório está nulo');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('❌ Verifique se todos os campos estão preenchidos corretamente'),
          backgroundColor: Colors.red,
        ));
      }
      return;
    }

    try {
      setState(() => _calculando = true);
      print('Debug: Iniciando cálculos');

      _pesoMedio = pesoAmostra / qtdAmostra;
      _quantidadeViva = (_cicloAtivo!['quantidadeEstocada'] as int) * (taxaSobrevivencia / 100);
      _biomassa = _pesoMedio! * _quantidadeViva! / 1000; // em kg
      _sobrevivencia = (_quantidadeViva! / (_cicloAtivo!['quantidadeEstocada'] as int)) * 100;

      print('Debug: Cálculos concluídos - pesoMedio=$_pesoMedio, biomassa=$_biomassa');

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('Debug: Usuário não autenticado');
        throw Exception('Usuário não autenticado');
      }
      
      final nomeUsuario = (await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get()).data()?['nome'] ?? '—';

      print('Debug: Salvando no Firestore');
      await FirebaseFirestore.instance.collection('biomassa').add({
        'codigo': _codigoSelecionado,
        'nome': _viveiros[_codigoSelecionado] ?? '—',
        'pesoMedio': _pesoMedio,
        'biomassaKg': _biomassa,
        'sobrevivencia': _sobrevivencia,
        'quantidadeViva': _quantidadeViva,
        'taxaSobrevivencia': taxaSobrevivencia,
        'registradoPor': nomeUsuario,
        'dataHora': Timestamp.now(),
      });

      print('Debug: Dados salvos com sucesso');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Cálculo de biomassa salvo com sucesso!'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      print('Debug: Erro durante o processo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Erro ao calcular/salvar: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) {
        setState(() => _calculando = false);
      }
    }
  }

  Future<void> _excluirCalculoIndividual(String docId) async {
    try {
      await FirebaseFirestore.instance.collection('biomassa').doc(docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Cálculo excluído com sucesso!'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Erro ao excluir: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _zerarHistoricoViveiro() async {
    if (_codigoSelecionado == null) return;
    
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text(
          'Tem certeza que deseja excluir TODO o histórico de cálculos do viveiro $_codigoSelecionado?\n\n'
          'Esta ação não pode ser desfeita!'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir Tudo', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        final batch = FirebaseFirestore.instance.batch();
        final docs = await FirebaseFirestore.instance
            .collection('biomassa')
            .where('codigo', isEqualTo: _codigoSelecionado)
            .get();

        for (final doc in docs.docs) {
          batch.delete(doc.reference);
        }

        await batch.commit();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('✅ Histórico do viveiro $_codigoSelecionado zerado com sucesso!'),
            backgroundColor: Colors.green,
          ));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('❌ Erro ao zerar histórico: $e'),
            backgroundColor: Colors.red,
          ));
        }
      }
    }
  }

  @override
  void dispose() {
    _pesoAmostraCtrl.dispose();
    _qtdAmostraCtrl.dispose();
    _sobrevivenciaCtrl.dispose();
    super.dispose();
  }

  String _formatar(double? valor, {String sufixo = ''}) =>
      valor == null ? '—' : '${valor.toStringAsFixed(2)}$sufixo';

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Cálculo de Biomassa',
      body: DegradeFundo(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _codigoSelecionado,
                  decoration: const InputDecoration(
                    labelText: 'Viveiro',
                    prefixIcon: Icon(Icons.water),
                  ),
                  items: (_viveiros.entries.toList()
                      ..sort((a, b) => a.key.compareTo(b.key))) // Ordenar por código
                      .map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Text('${e.value} (cód: ${e.key})'),
                          ))
                      .toList(),
                  onChanged: (v) {
                    setState(() => _codigoSelecionado = v);
                    if (v != null) _buscarCicloAtivo(v);
                  },
                  validator: (v) => v == null ? 'Selecione o viveiro' : null,
                ),
                if (_cicloAtivo != null) ...[
                  const SizedBox(height: 8),
                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Ciclo ativo:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('Estocagem: ${_cicloAtivo!['quantidadeEstocada']} camarões'),
                          Text('Peso inicial: ${_cicloAtivo!['pesoInicial'] ?? '-'} g'),
                          Text('Início: ${_cicloAtivo!['dataInicio'] != null ? DateFormat('dd/MM/yyyy').format(_cicloAtivo!['dataInicio'].toDate()) : '-'}'),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _qtdAmostraCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantidade na amostra',
                    prefixIcon: Icon(Icons.group),
                  ),
                  validator: (v) {
                    final val = int.tryParse(v ?? '');
                    if (val == null || val <= 0) return 'Informe uma quantidade válida';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _pesoAmostraCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Peso total da amostra (g)',
                    prefixIcon: Icon(Icons.monitor_weight),
                  ),
                  validator: (v) {
                    final val = double.tryParse((v ?? '').replaceAll(',', '.'));
                    if (val == null || val <= 0) return 'Informe um peso válido';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _sobrevivenciaCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Taxa de sobrevivência (%)',
                    prefixIcon: Icon(Icons.percent),
                  ),
                  validator: (v) {
                    final val = double.tryParse((v ?? '').replaceAll(',', '.'));
                    if (val == null || val <= 0 || val > 100) return 'Informe uma taxa válida (0-100)';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _calculando ? null : () {
                          print('Debug: Botão calcular pressionado');
                          _calcularSalvar();
                        },
                        icon: _calculando 
                            ? const SizedBox(
                                width: 16, 
                                height: 16, 
                                child: CircularProgressIndicator(strokeWidth: 2)
                              )
                            : const Icon(Icons.calculate),
                        label: Text(_calculando ? 'Calculando...' : 'Calcular e Salvar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade300, foregroundColor: Colors.black),
                      onPressed: () {
                        _formKey.currentState?.reset();
                        _pesoAmostraCtrl.clear();
                        _qtdAmostraCtrl.clear();
                        _sobrevivenciaCtrl.text = '85';
                        setState(() {
                          _pesoMedio = null;
                          _biomassa = null;
                          _sobrevivencia = null;
                          _quantidadeViva = null;
                        });
                      },
                      icon: const Icon(Icons.clear),
                      label: const Text('Limpar'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(),
                const Text('Resultados:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (_calculando)
                  const Center(child: CircularProgressIndicator()),
                if (!_calculando) ...[
                  Text('Peso médio: ${_formatar(_pesoMedio, sufixo: ' g')}'),
                  Text('Biomassa estimada: ${_formatar(_biomassa, sufixo: ' kg')}'),
                  Text('Sobrevivência estimada: ${_formatar(_sobrevivencia, sufixo: ' %')}'),
                  Text('Quantidade viva estimada: ${_formatar(_quantidadeViva)} camarões'),
                ],
                const SizedBox(height: 24),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Histórico de Cálculos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    if (_codigoSelecionado != null)
                      IconButton(
                        onPressed: _zerarHistoricoViveiro,
                        icon: const Icon(Icons.delete_sweep, color: Colors.red),
                        tooltip: 'Zerar todo o histórico',
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_codigoSelecionado != null)
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('biomassa')
                        .where('codigo', isEqualTo: _codigoSelecionado)
                        .snapshots(),
                    builder: (context, snapshot) {
                      // Debug e tratamento de erros
                      if (snapshot.hasError) {
                        print('Erro no StreamBuilder: ${snapshot.error}');
                        return Text('Erro ao carregar histórico: ${snapshot.error}');
                      }
                      
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      if (!snapshot.hasData || snapshot.data == null) {
                        return const Text('Nenhum dado disponível.');
                      }
                      
                      final docs = snapshot.data!.docs;
                      if (docs.isEmpty) {
                        return Card(
                          color: Colors.grey.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                const Icon(Icons.info_outline, size: 48, color: Colors.grey),
                                const SizedBox(height: 8),
                                const Text('Nenhum histórico encontrado para este viveiro.'),
                                const SizedBox(height: 4),
                                const Text(
                                  'Faça o primeiro cálculo de biomassa preenchendo os campos acima.',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Dica: Para um novo ciclo, sempre comece com um histórico limpo.',
                                  style: TextStyle(fontSize: 11, color: Colors.blue.shade600, fontStyle: FontStyle.italic),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      
                      // Ordenar manualmente no client-side
                      docs.sort((a, b) {
                        final dataA = (a['dataHora'] as Timestamp).toDate();
                        final dataB = (b['dataHora'] as Timestamp).toDate();
                        return dataB.compareTo(dataA); // Mais recente primeiro
                      });
                      // Histórico
                      final historico = Column(
                        children: docs.map((doc) {
                          final data = doc['dataHora'].toDate();
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            child: ListTile(
                              leading: const Icon(Icons.history),
                              title: Text(DateFormat('dd/MM/yyyy HH:mm').format(data)),
                              subtitle: Text(
                                  'Peso médio: ${_formatar(doc['pesoMedio'], sufixo: 'g')} • Biomassa: ${_formatar(doc['biomassaKg'], sufixo: 'kg')}'
                                  '\nSobrevivência: ${_formatar(doc['sobrevivencia'], sufixo: '%')} • Taxa: ${_formatar(doc['taxaSobrevivencia'], sufixo: '%')} • Por: ${doc['registradoPor']}'
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                onPressed: () async {
                                  final confirmar = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Excluir cálculo'),
                                      content: Text('Excluir o cálculo de ${DateFormat('dd/MM/yyyy HH:mm').format(data)}?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: const Text('Cancelar'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                          child: const Text('Excluir', style: TextStyle(color: Colors.white)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmar == true) {
                                    _excluirCalculoIndividual(doc.id);
                                  }
                                },
                                tooltip: 'Excluir este cálculo',
                              ),
                            ),
                          );
                        }).toList(),
                      );
                      // Gráfico simplificado
                      if (docs.length > 1) {
                        // Reverter para ordem cronológica para o gráfico
                        final docsParaGrafico = docs.reversed.toList();
                        final pontosBiomassa = docsParaGrafico.asMap().entries
                            .map((entry) => FlSpot(
                                  entry.key.toDouble(), 
                                  (entry.value['biomassaKg'] as num?)?.toDouble() ?? 0.0,
                                ))
                            .toList();
                        
                        final minY = pontosBiomassa.map((p) => p.y).reduce((a, b) => a < b ? a : b);
                        final maxY = pontosBiomassa.map((p) => p.y).reduce((a, b) => a > b ? a : b);
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            historico,
                            const SizedBox(height: 24),
                            const Text('Evolução da Biomassa', 
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 220,
                              child: LineChart(
                                LineChartData(
                                  minY: minY > 0 ? (minY * 0.9).floorToDouble() : 0,
                                  maxY: (maxY * 1.1).ceilToDouble(),
                                  minX: 0,
                                  maxX: (pontosBiomassa.length - 1).toDouble(),
                                  gridData: const FlGridData(show: true),
                                  titlesData: FlTitlesData(
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true, 
                                        reservedSize: 40, 
                                        getTitlesWidget: (v, meta) => Text(
                                          '${v.toStringAsFixed(1)}kg', 
                                          style: const TextStyle(fontSize: 10)
                                        )
                                      ),
                                    ),
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 36,
                                        getTitlesWidget: (v, meta) {
                                          final idx = v.round();
                                          if (idx < 0 || idx >= docsParaGrafico.length) return const SizedBox.shrink();
                                          final doc = docsParaGrafico[idx];
                                          final dt = (doc['dataHora'] as Timestamp).toDate();
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 8),
                                            child: Text(
                                              DateFormat('dd/MM').format(dt), 
                                              style: const TextStyle(fontSize: 10)
                                            ),
                                          );
                                        },
                                        interval: docsParaGrafico.length > 5 ? 2 : 1,
                                      ),
                                    ),
                                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  ),
                                  borderData: FlBorderData(show: true),
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: pontosBiomassa,
                                      isCurved: true,
                                      color: Colors.teal,
                                      barWidth: 3,
                                      dotData: FlDotData(
                                        show: true, 
                                        getDotPainter: (spot, percent, barData, index) => 
                                          FlDotCirclePainter(radius: 4, color: Colors.teal)
                                      ),
                                      belowBarData: BarAreaData(
                                        show: true, 
                                        color: Colors.teal.withOpacity(0.15)
                                      ),
                                    ),
                                  ],
                                  lineTouchData: LineTouchData(
                                    enabled: true,
                                    touchTooltipData: LineTouchTooltipData(
                                      getTooltipItems: (touchedSpots) {
                                        return touchedSpots.map((spot) {
                                          final idx = spot.x.round();
                                          if (idx >= 0 && idx < docsParaGrafico.length) {
                                            final doc = docsParaGrafico[idx];
                                            final data = (doc['dataHora'] as Timestamp).toDate();
                                            return LineTooltipItem(
                                              '${DateFormat('dd/MM').format(data)}\n${spot.y.toStringAsFixed(2)} kg',
                                              const TextStyle(color: Colors.white),
                                            );
                                          }
                                          return LineTooltipItem(
                                            '${spot.y.toStringAsFixed(2)} kg',
                                            const TextStyle(color: Colors.white),
                                          );
                                        }).toList();
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      } else {
                        return historico;
                      }
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Limpar tudo',
        onPressed: () {
          _formKey.currentState?.reset();
          _pesoAmostraCtrl.clear();
          _qtdAmostraCtrl.clear();
          _sobrevivenciaCtrl.text = '85';
          setState(() {
            _pesoMedio = null;
            _biomassa = null;
            _sobrevivencia = null;
            _quantidadeViva = null;
            _codigoSelecionado = null;
            _cicloAtivo = null;
          });
        },
        child: const Icon(Icons.refresh),
      ),
    );
  }
}