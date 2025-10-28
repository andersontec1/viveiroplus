import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/app_scaffold.dart';
import '../helpers/auth_helper.dart';
import '../helpers/audit_helper.dart';
import '../helpers/estoque_helper.dart';
import '../helpers/racao_helper.dart';

class TelaEditarRacao extends StatefulWidget {
  const TelaEditarRacao({Key? key, required this.docId, required this.dados})
    : super(key: key);
  final String docId;
  final Map<String, dynamic> dados;

  @override
  State<TelaEditarRacao> createState() => _TelaEditarRacaoState();
}

class _TelaEditarRacaoState extends State<TelaEditarRacao> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _quantidadeController;
  late TextEditingController _sobrasController;
  late TextEditingController _observacoesController;

  bool _isLoading = false;
  bool _temProbiotico = false;
  bool _temSuplemento = false;

  @override
  void initState() {
    super.initState();
    _quantidadeController = TextEditingController(
      text: widget.dados['quantidade']?.toString() ?? '0',
    );
    _sobrasController = TextEditingController(
      text: widget.dados['sobras']?.toString() ?? '0',
    );
    _observacoesController = TextEditingController(
      text: widget.dados['observacoes'] ?? '',
    );

    // Verificar se probiótico foi aplicado (compatibilidade com campos antigos e novos)
    _temProbiotico =
        widget.dados['probioticoAplicado'] == true ||
        widget.dados['probióticoAplicado'] == true;

    // Verificar se suplemento foi aplicado
    _temSuplemento = widget.dados['suplementoAplicado'] == true;
  }

  @override
  void dispose() {
    _quantidadeController.dispose();
    _sobrasController.dispose();
    _observacoesController.dispose();
    super.dispose();
  }

  Future<void> _salvarAlteracoes() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final usuario = AuthHelper.obterUsuarioLogado();

        // Preparar dados para atualização (apenas campos editáveis)
        final dadosAtualizados = {
          'quantidade': double.parse(
            _quantidadeController.text.replaceAll(',', '.'),
          ),
          'sobras': double.parse(_sobrasController.text.replaceAll(',', '.')),
          'observacoes': _observacoesController.text.trim(),
          'ultimaEdicao': FieldValue.serverTimestamp(),
          'editadoPor': usuario?.displayName ?? 'Usuário',
        };

        // Atualização do documento + integridade de estoque
        final racaoRef = FirebaseFirestore.instance
            .collection('racao')
            .doc(widget.docId);

        // 1) Estornar saídas anteriores vinculadas a este registro
        try {
          await EstoqueHelper.estornarSaidasPorReferencia(
            origem: 'racao',
            referenciaId: widget.docId,
            responsavel: usuario?.displayName,
          );
        } catch (e) {
          // Prossegue, mas sinaliza no log
          // ignore: avoid_print
          print('Aviso: falha ao estornar saídas anteriores: $e');
        }

        // 2) Reaplicar saída FEFO com a nova quantidade
        try {
          final quantidadeKg = dadosAtualizados['quantidade'] as double;
          final String? insumoId = widget.dados['insumoId'] as String?;
          final String? insumoNome = widget.dados['insumoNome'] as String?;
          if (insumoId == null && (insumoNome == null || insumoNome.isEmpty)) {
            // Se não houver vínculo ao insumo, apenas atualiza doc e alerta
            await racaoRef.update(dadosAtualizados);
          } else {
            final usados = await EstoqueHelper.registrarSaidaFefo(
              insumoNomeOuId: insumoId ?? insumoNome!,
              quantidade: quantidadeKg,
              origem: 'racao',
              referenciaId: widget.docId,
              responsavel: usuario?.displayName,
            );
            await racaoRef.update({...dadosAtualizados, 'lotesUsados': usados});
          }
        } catch (e) {
          // Se falhar ao rebaixar estoque, pelo menos mantemos os dados do registro atualizados
          await racaoRef.update(dadosAtualizados);
        }

        // Registrar auditoria
        await AuditHelper.registrarAcao(
          acao: 'EDITAR_RACAO',
          modulo: 'ARRACOAMENTO',
          detalhes: {
            'docId': widget.docId,
            'quantidadeAnterior': widget.dados['quantidade'],
            'quantidadeNova': dadosAtualizados['quantidade'],
            'sobrasAnterior': widget.dados['sobras'] ?? 0,
            'sobrasNova': dadosAtualizados['sobras'],
          },
        );

        // 3) Reprocessar acumulado/dia do ciclo
        try {
          await RacaoHelper.reprocessarDestinoFromBase(widget.dados);
        } catch (e) {
          // ignore: avoid_print
          print('Falha ao reprocessar acumulados após edição: $e');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Registro atualizado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        print('Erro ao atualizar registro: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ Erro ao atualizar: ${e.toString()}')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  // Função helper para obter o nome do destino com compatibilidade
  String _obterNomeDestino() {
    if (widget.dados['destinoNome'] != null &&
        widget.dados['destinoNome'].toString().isNotEmpty) {
      return widget.dados['destinoNome'];
    }
    return widget.dados['viveiro'] ?? 'Sem destino';
  }

  @override
  Widget build(BuildContext context) {
    final timestamp = widget.dados['dataRegistro'] as Timestamp?;
    final dataRegistro = timestamp?.toDate() ?? DateTime.now();
    final destino = _obterNomeDestino();

    return AppScaffold(
      title: 'Editar Registro de Ração',
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Card de informações não editáveis
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Informações do Registro',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildInfoRow('Destino:', destino),
                            _buildInfoRow(
                              'Data:',
                              '${dataRegistro.day}/${dataRegistro.month}/${dataRegistro.year}',
                            ),
                            _buildInfoRow(
                              'Horário:',
                              widget.dados['horario'] ?? 'Não informado',
                            ),
                            _buildInfoRow(
                              'Registrado por:',
                              widget.dados['registradoPor'] ?? 'Desconhecido',
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Card de aditivos aplicados (somente leitura)
                    if (_temProbiotico || _temSuplemento)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Aditivos Aplicados',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (_temProbiotico)
                                Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: Colors.green[600],
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Probiótico aplicado',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ],
                                ),
                              if (_temProbiotico && _temSuplemento)
                                const SizedBox(height: 8),
                              if (_temSuplemento)
                                Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: Colors.orange[600],
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Suplemento aplicado',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 8),
                              Text(
                                'Nota: Os aditivos não podem ser alterados após o registro',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Card de campos editáveis
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Informações Editáveis',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _quantidadeController,
                              decoration: const InputDecoration(
                                labelText: 'Quantidade (kg)',
                                border: OutlineInputBorder(),
                                suffixText: 'kg',
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Por favor, insira a quantidade';
                                }
                                final numero = double.tryParse(
                                  value.replaceAll(',', '.'),
                                );
                                if (numero == null || numero <= 0) {
                                  return 'Insira um valor válido';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _sobrasController,
                              decoration: const InputDecoration(
                                labelText: 'Sobras (kg)',
                                border: OutlineInputBorder(),
                                suffixText: 'kg',
                                helperText: 'Quantidade que sobrou no viveiro',
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return null; // Sobras é opcional
                                }
                                final numero = double.tryParse(
                                  value.replaceAll(',', '.'),
                                );
                                if (numero == null || numero < 0) {
                                  return 'Insira um valor válido';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _observacoesController,
                              decoration: const InputDecoration(
                                labelText: 'Observações',
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 3,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _salvarAlteracoes,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Salvar Alterações'),
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
