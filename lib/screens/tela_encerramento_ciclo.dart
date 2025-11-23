// Tela de Encerramento de Ciclo - Finaliza um ciclo após despesca completa

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/degrade_fundo.dart';

class TelaEncerramentoCiclo extends StatefulWidget {
  const TelaEncerramentoCiclo({
    super.key,
    required this.codigoViveiro,
    required this.cicloAtivo,
  });
  final String codigoViveiro;
  final Map<String, dynamic> cicloAtivo;

  @override
  State<TelaEncerramentoCiclo> createState() => _TelaEncerramentoCicloState();
}

class _TelaEncerramentoCicloState extends State<TelaEncerramentoCiclo> {
  static const _corPrimaria = Color(0xFF049F56);
  String _formatarMilhares(num? n) =>
      NumberFormat.decimalPattern('pt_BR').format((n ?? 0).toInt());

  final _formKey = GlobalKey<FormState>();
  final _observacoesCtrl = TextEditingController();

  bool _carregando = false;
  bool _encerrando = false;
  Map<String, dynamic> _resumoDespesca = {};

  @override
  void initState() {
    super.initState();
    _carregarResumoDespesca();
  }

  Future<void> _carregarResumoDespesca() async {
    setState(() => _carregando = true);

    try {
      final despescas = await FirebaseFirestore.instance
          .collection('despescas')
          .where('codigo', isEqualTo: widget.codigoViveiro)
          .where('statusDespesca', isEqualTo: 'finalizada')
          .get();

      double pesoTotal = 0;
      double valorTotal = 0;
      int totalRegistros = despescas.docs.length;
      DateTime? primeiraDespesca;
      DateTime? ultimaDespesca;

      for (final doc in despescas.docs) {
        final data = doc.data();
        pesoTotal += (data['pesoTotal'] ?? 0.0);
        valorTotal += (data['valorTotal'] ?? 0.0);

        final dataHora = (data['dataHora'] as Timestamp).toDate();
        if (primeiraDespesca == null || dataHora.isBefore(primeiraDespesca)) {
          primeiraDespesca = dataHora;
        }
        if (ultimaDespesca == null || dataHora.isAfter(ultimaDespesca)) {
          ultimaDespesca = dataHora;
        }
      }

      setState(() {
        _resumoDespesca = {
          'pesoTotal': pesoTotal,
          'valorTotal': valorTotal,
          'totalRegistros': totalRegistros,
          'primeiraDespesca': primeiraDespesca,
          'ultimaDespesca': ultimaDespesca,
        };
      });
    } catch (e) {
      print('Erro ao carregar resumo da despesca: $e');
    } finally {
      setState(() => _carregando = false);
    }
  }

  Future<void> _encerrarCiclo() async {
    if (!_formKey.currentState!.validate()) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Encerramento'),
        content: const Text(
          'Tem certeza que deseja encerrar este ciclo?\n\n'
          '⚠️ Esta ação não pode ser desfeita!\n\n'
          'O ciclo será marcado como encerrado e não poderá mais receber registros.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: _corPrimaria),
            child: const Text(
              'Encerrar Ciclo',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _encerrando = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuário não autenticado');

      final nomeUsuario =
          (await FirebaseFirestore.instance
                  .collection('usuarios')
                  .doc(user.uid)
                  .get())
              .data()?['nome'] ??
          '—';

      // Buscar o documento do ciclo
      final ciclosQuery = await FirebaseFirestore.instance
          .collection('ciclos')
          .where('codigo', isEqualTo: widget.codigoViveiro)
          .where('encerrado', isEqualTo: false)
          .limit(1)
          .get();

      if (ciclosQuery.docs.isEmpty) {
        throw Exception('Ciclo ativo não encontrado');
      }

      final cicloDoc = ciclosQuery.docs.first;

      // Atualizar o ciclo
      await cicloDoc.reference.update({
        'encerrado': true,
        'dataEncerramento': Timestamp.now(),
        'observacoesEncerramento': _observacoesCtrl.text.trim(),
        'encerradoPor': nomeUsuario,
        'resumoFinal': {
          'pesoTotalDespescado': _resumoDespesca['pesoTotal'] ?? 0,
          'valorTotalFaturado': _resumoDespesca['valorTotal'] ?? 0,
          'duracaoCicloEmDias': DateTime.now()
              .difference(
                (widget.cicloAtivo['dataInicio'] as Timestamp).toDate(),
              )
              .inDays,
          'quantidadeEstocadaInicial': widget.cicloAtivo['quantidadeEstocada'],
        },
      });

      if (mounted) {
        Navigator.pop(context); // Volta para a tela anterior
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Ciclo encerrado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erro ao encerrar ciclo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _encerrando = false);
    }
  }

  String _formatar(double valor, {String sufixo = ''}) =>
      '${valor.toStringAsFixed(2)}$sufixo';

  @override
  void dispose() {
    _observacoesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Encerramento de Ciclo',
      body: DegradeFundo(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _carregando
              ? const Center(child: CircularProgressIndicator())
              : Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      // Cabeçalho do viveiro
                      Card(
                        color: Colors.blue.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '🏁 Finalizando Ciclo',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: _corPrimaria,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text('Viveiro: ${widget.codigoViveiro}'),
                              Text(
                                'Início: ${DateFormat('dd/MM/yyyy').format((widget.cicloAtivo['dataInicio'] as Timestamp).toDate())}',
                              ),
                              Text(
                                'Duração: ${DateTime.now().difference((widget.cicloAtivo['dataInicio'] as Timestamp).toDate()).inDays} dias',
                              ),
                              Text(
                                'Quantidade estocada: ${_formatarMilhares(widget.cicloAtivo['quantidadeEstocada'] as num?)} camarões',
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Resumo da despesca
                      const Text(
                        '📊 Resumo da Despesca',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        color: Colors.green.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _buildResumoItem(
                                'Peso Total Despescado',
                                '${_formatar(_resumoDespesca['pesoTotal'] ?? 0)} kg',
                                Icons.monitor_weight,
                                Colors.blue,
                              ),
                              const Divider(),
                              _buildResumoItem(
                                'Valor Total Faturado',
                                'R\$ ${_formatar(_resumoDespesca['valorTotal'] ?? 0)}',
                                Icons.attach_money,
                                Colors.green,
                              ),
                              const Divider(),
                              _buildResumoItem(
                                'Registros de Despesca',
                                '${_resumoDespesca['totalRegistros'] ?? 0} registros',
                                Icons.list,
                                Colors.orange,
                              ),
                              if (_resumoDespesca['primeiraDespesca'] !=
                                  null) ...[
                                const Divider(),
                                _buildResumoItem(
                                  'Período da Despesca',
                                  '${DateFormat('dd/MM/yyyy').format(_resumoDespesca['primeiraDespesca'])} até ${DateFormat('dd/MM/yyyy').format(_resumoDespesca['ultimaDespesca'] ?? _resumoDespesca['primeiraDespesca'])}',
                                  Icons.date_range,
                                  Colors.purple,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Indicadores de produtividade
                      const Text(
                        '📈 Indicadores de Produtividade',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        color: Colors.amber.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _buildIndicador(
                                'Produtividade',
                                '${_formatar((_resumoDespesca['pesoTotal'] ?? 0) / (widget.cicloAtivo['quantidadeEstocada'] ?? 1) * 1000)} g/camarão médio',
                                Icons.trending_up,
                              ),
                              const Divider(),
                              _buildIndicador(
                                'Faturamento por kg',
                                'R\$ ${_formatar((_resumoDespesca['valorTotal'] ?? 0) / ((_resumoDespesca['pesoTotal'] ?? 0) == 0 ? 1 : _resumoDespesca['pesoTotal']))}/kg',
                                Icons.monetization_on,
                              ),
                              const Divider(),
                              _buildIndicador(
                                'Duração do Ciclo',
                                '${DateTime.now().difference((widget.cicloAtivo['dataInicio'] as Timestamp).toDate()).inDays} dias',
                                Icons.schedule,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Observações finais
                      const Text(
                        '📝 Observações Finais (Opcional)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _observacoesCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Observações sobre o encerramento',
                          hintText:
                              'Ex: Resultado satisfatório, mortalidade baixa, problemas identificados...',
                          prefixIcon: Icon(Icons.note),
                        ),
                        maxLines: 4,
                      ),

                      const SizedBox(height: 30),

                      // Botão de encerramento
                      Container(
                        width: double.infinity,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _corPrimaria,
                              _corPrimaria.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: _corPrimaria.withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _encerrando ? null : _encerrarCiclo,
                          icon: _encerrando
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.flag, color: Colors.white),
                          label: Text(
                            _encerrando
                                ? 'Encerrando Ciclo...'
                                : 'Encerrar Ciclo Definitivamente',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Aviso importante
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.orange.shade600,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Atenção: Após o encerramento, não será possível adicionar novos registros a este ciclo.',
                                style: TextStyle(
                                  color: Colors.orange.shade800,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildResumoItem(
    String titulo,
    String valor,
    IconData icone,
    Color cor,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: cor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icone, color: cor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            titulo,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          valor,
          style: TextStyle(fontWeight: FontWeight.bold, color: cor),
        ),
      ],
    );
  }

  Widget _buildIndicador(String titulo, String valor, IconData icone) {
    return Row(
      children: [
        Icon(icone, color: _corPrimaria, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            titulo,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          valor,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: _corPrimaria,
          ),
        ),
      ],
    );
  }
}
