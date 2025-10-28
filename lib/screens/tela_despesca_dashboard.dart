import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/degrade_fundo.dart';

class TelaDespescaDashboard extends StatefulWidget {
  const TelaDespescaDashboard({super.key});

  @override
  State<TelaDespescaDashboard> createState() => _TelaDespescaDashboardState();
}

class _TelaDespescaDashboardState extends State<TelaDespescaDashboard> {
  List<Map<String, dynamic>> _despescas = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarDespescas();
  }

  Future<void> _carregarDespescas() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('despescas')
          .orderBy('dataCriacao', descending: true)
          .get();

      setState(() {
        _despescas = snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();
        _carregando = false;
      });
    } catch (e) {
      setState(() => _carregando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar despescas: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const AppScaffold(
        title: '🦐 Dashboard de Despescas',
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final despescasAtivas = _despescas
        .where((d) => !(d['despescaFinalizada'] ?? false))
        .toList();
    final despescasFinalizadas = _despescas
        .where((d) => d['despescaFinalizada'] ?? false)
        .toList();
    final despescasAuditadas = _despescas
        .where((d) => d['auditado'] ?? false)
        .length;

    return AppScaffold(
      title: '🦐 Dashboard de Despescas',
      body: DegradeFundo(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: ListView(
            children: [
              // Header principal
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.teal.shade600, Colors.teal.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.set_meal, size: 48, color: Colors.white),
                    SizedBox(height: 12),
                    Text(
                      'Controle de Despescas',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Gerencie e monitore todas as despescas do sistema',
                      style: TextStyle(fontSize: 16, color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Cards de estatísticas
              Row(
                children: [
                  Expanded(
                    child: _buildCardEstatistica(
                      'Total de Despescas',
                      _despescas.length.toString(),
                      Icons.inventory,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildCardEstatistica(
                      'Despescas Ativas',
                      despescasAtivas.length.toString(),
                      Icons.access_time,
                      Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildCardEstatistica(
                      'Finalizadas',
                      despescasFinalizadas.length.toString(),
                      Icons.check_circle,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildCardEstatistica(
                      'Auditadas',
                      despescasAuditadas.toString(),
                      Icons.verified,
                      Colors.purple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Botão para nova despesca
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/despesca');
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Nova Despesca'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Seção de despescas ativas
              if (despescasAtivas.isNotEmpty) ...[
                _buildSecaoDespescas(
                  'Despescas em Andamento',
                  despescasAtivas,
                  Icons.access_time,
                  Colors.orange,
                ),
                const SizedBox(height: 24),
              ],

              // Seção de despescas finalizadas
              if (despescasFinalizadas.isNotEmpty) ...[
                _buildSecaoDespescas(
                  'Despescas Finalizadas',
                  despescasFinalizadas,
                  Icons.check_circle,
                  Colors.green,
                ),
              ],

              // Mensagem quando não há despescas
              if (_despescas.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Nenhuma despesca registrada',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Clique em "Nova Despesca" para começar',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardEstatistica(
    String titulo,
    String valor,
    IconData icone,
    Color cor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: cor.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icone, size: 32, color: cor),
          const SizedBox(height: 8),
          Text(
            valor,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: cor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            titulo,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSecaoDespescas(
    String titulo,
    List<Map<String, dynamic>> despescas,
    IconData icone,
    Color cor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icone, color: cor, size: 20),
            const SizedBox(width: 8),
            Text(
              titulo,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: cor,
              ),
            ),
            const Spacer(),
            Text(
              '${despescas.length} item${despescas.length != 1 ? 's' : ''}',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...despescas.map((despesca) => _buildCardDespesca(despesca)),
      ],
    );
  }

  Widget _buildCardDespesca(Map<String, dynamic> despesca) {
    final dataCriacao = despesca['dataCriacao'] as Timestamp?;
    final dataDespesca = dataCriacao?.toDate() ?? DateTime.now();
    final auditado = despesca['auditado'] ?? false;
    final pesoTotal = despesca['pesoTotal'] ?? 0.0;
    final basquetasTotal = despesca['basquetasTotal'] ?? 0;
    final responsavelNome = despesca['criadoPor'] ?? '—';
    final codigo = despesca['codigo'] ?? '—';
    final nome = despesca['nome'] ?? '—';
    final statusDespesca = despesca['statusDespesca'] ?? 'planejada';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _mostrarDetalhesCompletos(despesca),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header com viveiro e status
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: _getStatusColor(statusDespesca).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getStatusIcon(statusDespesca),
                      color: _getStatusColor(statusDespesca),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$codigo - $nome',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(statusDespesca),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _getStatusText(statusDespesca),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (auditado) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.purple,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'AUDITADO',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Menu de ações
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) => _acaoSelecionada(value, despesca),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'visualizar',
                        child: Row(
                          children: [
                            Icon(Icons.visibility, size: 20),
                            SizedBox(width: 8),
                            Text('Visualizar Detalhes'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'editar',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 8),
                            Text('Editar'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'excluir',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text(
                              'Excluir',
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Informações principais
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildInfoItem(
                      Icons.calendar_today,
                      'Data',
                      DateFormat('dd/MM/yyyy').format(dataDespesca),
                      Colors.blue,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: _buildInfoItem(
                      Icons.person,
                      'Responsável',
                      responsavelNome,
                      Colors.green,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      Icons.monitor_weight,
                      'Peso Total',
                      '${pesoTotal.toStringAsFixed(1)} kg',
                      Colors.green,
                    ),
                  ),
                  Expanded(
                    child: _buildInfoItem(
                      Icons.shopping_basket,
                      'Basquetas',
                      '$basquetasTotal unid.',
                      Colors.blue,
                    ),
                  ),
                ],
              ),

              // Informações das basquetas se disponível
              if (basquetasTotal > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.shopping_basket,
                        size: 20,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Basquetas: $basquetasTotal unid.',
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'Peso total: ${pesoTotal.toStringAsFixed(1)} kg',
                              style: TextStyle(
                                color: Colors.blue.shade600,
                                fontSize: 12,
                              ),
                            ),
                            if (basquetasTotal > 0 && pesoTotal > 0)
                              Text(
                                'Peso médio: ${(pesoTotal / basquetasTotal).toStringAsFixed(1)} kg/cada',
                                style: TextStyle(
                                  color: Colors.blue.shade600,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Icon(
                        statusDespesca == 'finalizada'
                            ? Icons.check_circle
                            : Icons.pending,
                        color: statusDespesca == 'finalizada'
                            ? Colors.green
                            : Colors.orange,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Métodos auxiliares para cores e textos
  Color _getStatusColor(String status) {
    switch (status) {
      case 'planejada':
        return Colors.blue;
      case 'em_andamento':
        return Colors.orange;
      case 'concluida':
        return Colors.green;
      case 'auditada':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'planejada':
        return Icons.schedule;
      case 'em_andamento':
        return Icons.play_circle;
      case 'concluida':
        return Icons.check_circle;
      case 'auditada':
        return Icons.verified;
      default:
        return Icons.help;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'planejada':
        return 'PLANEJADA';
      case 'em_andamento':
        return 'EM ANDAMENTO';
      case 'concluida':
        return 'CONCLUÍDA';
      case 'auditada':
        return 'AUDITADA';
      default:
        return 'DESCONHECIDO';
    }
  }

  String _getQualidadeText(String qualidade) {
    switch (qualidade) {
      case 'excelente':
        return 'Excelente';
      case 'boa':
        return 'Boa';
      case 'regular':
        return 'Regular';
      case 'ruim':
        return 'Ruim';
      default:
        return 'N/A';
    }
  }

  String _getEstadoBasquetaText(String estado) {
    switch (estado) {
      case 'boa':
        return 'Boa';
      case 'danificada':
        return 'Danificada';
      case 'necessita_reparo':
        return 'Necessita Reparo';
      default:
        return 'N/A';
    }
  }

  Widget _buildInfoItem(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _acaoSelecionada(String acao, Map<String, dynamic> despesca) {
    switch (acao) {
      case 'visualizar':
        _mostrarDetalhesCompletos(despesca);
        break;
      case 'editar':
        _editarDespesca(despesca);
        break;
      case 'excluir':
        _confirmarExclusao(despesca);
        break;
    }
  }

  void _editarDespesca(Map<String, dynamic> despesca) {
    Navigator.pushNamed(
      context,
      '/despesca',
      arguments: despesca, // Passar dados para edição
    ).then((_) => _carregarDespescas());
  }

  void _confirmarExclusao(Map<String, dynamic> despesca) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text(
          'Tem certeza que deseja excluir a despesca do viveiro ${despesca['codigo']}?\n\nEsta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _excluirDespesca(despesca);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _excluirDespesca(Map<String, dynamic> despesca) async {
    try {
      await FirebaseFirestore.instance
          .collection('despescas')
          .doc(despesca['id'])
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Despesca excluída com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );

      _carregarDespescas(); // Recarregar lista
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erro ao excluir despesca: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _mostrarDetalhesCompletos(Map<String, dynamic> despesca) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 24,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Detalhes da Despesca',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Divider(height: 24),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetalheSecao('Informações Básicas', [
                          _buildDetalheLinha(
                            'Viveiro',
                            '${despesca['codigo']} - ${despesca['nome']}',
                          ),
                          if (despesca['dataDespesca'] != null)
                            _buildDetalheLinha(
                              'Data da Despesca',
                              DateFormat('dd/MM/yyyy').format(
                                (despesca['dataDespesca'] as Timestamp)
                                    .toDate(),
                              ),
                            ),
                          _buildDetalheLinha(
                            'Status',
                            _getStatusText(
                              despesca['statusDespesca'] ?? 'planejada',
                            ),
                          ),
                          _buildDetalheLinha(
                            'Responsável',
                            despesca['responsavelNome'] ?? '—',
                          ),
                          if (despesca['dataHoraInicio'] != null)
                            _buildDetalheLinha(
                              'Hora Início',
                              DateFormat('HH:mm').format(
                                (despesca['dataHoraInicio'] as Timestamp)
                                    .toDate(),
                              ),
                            ),
                          if (despesca['dataHoraFim'] != null)
                            _buildDetalheLinha(
                              'Hora Fim',
                              DateFormat('HH:mm').format(
                                (despesca['dataHoraFim'] as Timestamp).toDate(),
                              ),
                            ),
                        ]),

                        const SizedBox(height: 20),

                        _buildDetalheSecao('Produção e Qualidade', [
                          _buildDetalheLinha(
                            'Peso Registrado',
                            '${despesca['pesoOperador'] ?? 0} kg',
                          ),
                          if (despesca['pesoAuditado'] != null)
                            _buildDetalheLinha(
                              'Peso Auditado',
                              '${despesca['pesoAuditado']} kg',
                            ),
                          _buildDetalheLinha(
                            'Qualidade Geral',
                            _getQualidadeText(
                              despesca['qualidadeGeral'] ?? 'boa',
                            ),
                          ),
                          _buildDetalheLinha(
                            'Condições Climáticas',
                            _getClimaText(
                              despesca['condicoesClimaticas'] ?? 'sol',
                            ),
                          ),
                          _buildDetalheLinha(
                            'Despesca Finalizada',
                            despesca['despescaFinalizada'] == true
                                ? 'Sim'
                                : 'Não',
                          ),
                        ]),

                        if (despesca['basquetas'] != null) ...[
                          const SizedBox(height: 20),
                          _buildDetalheSecaoBasquetas(despesca['basquetas']),
                        ],

                        if (_temInformacoesComplementares(despesca)) ...[
                          const SizedBox(height: 20),
                          _buildDetalheSecao('Informações Complementares', [
                            if (despesca['equipamentosUsados'] != null &&
                                despesca['equipamentosUsados']
                                    .toString()
                                    .isNotEmpty)
                              _buildDetalheLinha(
                                'Equipamentos Utilizados',
                                despesca['equipamentosUsados'],
                              ),
                            if (despesca['problemasEnfrentados'] != null &&
                                despesca['problemasEnfrentados']
                                    .toString()
                                    .isNotEmpty)
                              _buildDetalheLinha(
                                'Problemas Enfrentados',
                                despesca['problemasEnfrentados'],
                              ),
                            if (despesca['qualidadeCamaroes'] != null &&
                                despesca['qualidadeCamaroes']
                                    .toString()
                                    .isNotEmpty)
                              _buildDetalheLinha(
                                'Qualidade dos Camarões',
                                despesca['qualidadeCamaroes'],
                              ),
                            if (despesca['observacoes'] != null &&
                                despesca['observacoes'].toString().isNotEmpty)
                              _buildDetalheLinha(
                                'Observações Gerais',
                                despesca['observacoes'],
                              ),
                          ]),
                        ],

                        const SizedBox(height: 20),

                        _buildDetalheSecao('Auditoria', [
                          _buildDetalheLinha(
                            'Registrado por',
                            despesca['registradoPor'] ?? '—',
                          ),
                          if (despesca['criadoEm'] != null)
                            _buildDetalheLinha(
                              'Data de Registro',
                              DateFormat('dd/MM/yyyy HH:mm').format(
                                (despesca['criadoEm'] as Timestamp).toDate(),
                              ),
                            ),
                          if (despesca['editadoPor'] != null)
                            _buildDetalheLinha(
                              'Editado por',
                              despesca['editadoPor'],
                            ),
                          if (despesca['editadoEm'] != null)
                            _buildDetalheLinha(
                              'Data de Edição',
                              DateFormat('dd/MM/yyyy HH:mm').format(
                                (despesca['editadoEm'] as Timestamp).toDate(),
                              ),
                            ),
                        ]),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Botões de ação
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _editarDespesca(despesca);
                        },
                        icon: const Icon(Icons.edit),
                        label: const Text('Editar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        label: const Text('Fechar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getClimaText(String clima) {
    switch (clima) {
      case 'sol':
        return 'Sol';
      case 'nublado':
        return 'Nublado';
      case 'chuva':
        return 'Chuva';
      case 'vento_forte':
        return 'Vento Forte';
      default:
        return 'N/A';
    }
  }

  bool _temInformacoesComplementares(Map<String, dynamic> despesca) {
    return (despesca['equipamentosUsados'] != null &&
            despesca['equipamentosUsados'].toString().isNotEmpty) ||
        (despesca['problemasEnfrentados'] != null &&
            despesca['problemasEnfrentados'].toString().isNotEmpty) ||
        (despesca['qualidadeCamaroes'] != null &&
            despesca['qualidadeCamaroes'].toString().isNotEmpty) ||
        (despesca['observacoes'] != null &&
            despesca['observacoes'].toString().isNotEmpty);
  }

  Widget _buildDetalheSecao(String titulo, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.teal,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items,
          ),
        ),
      ],
    );
  }

  Widget _buildDetalheSecaoBasquetas(Map<String, dynamic> basquetas) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Controle de Basquetas',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetalheLinha(
                'Número de Basquetas',
                '${basquetas['numeroBasquetas'] ?? 0} unidades',
              ),
              if (basquetas['capacidadePorBasqueta'] != null &&
                  basquetas['capacidadePorBasqueta'] > 0)
                _buildDetalheLinha(
                  'Capacidade por Basqueta',
                  '${basquetas['capacidadePorBasqueta']} kg',
                ),
              if (basquetas['pesoMedioPorBasqueta'] != null &&
                  basquetas['pesoMedioPorBasqueta'] > 0)
                _buildDetalheLinha(
                  'Peso Médio por Basqueta',
                  '${basquetas['pesoMedioPorBasqueta']} kg',
                ),
              _buildDetalheLinha(
                'Estado das Basquetas',
                _getEstadoBasquetaText(basquetas['estadoBasquetas'] ?? 'boa'),
              ),
              if (basquetas['totalEstimadoBasquetas'] != null &&
                  basquetas['totalEstimadoBasquetas'] > 0)
                _buildDetalheLinha(
                  'Total Estimado',
                  '${basquetas['totalEstimadoBasquetas']} kg',
                ),
              if (basquetas['observacoesBasquetas'] != null &&
                  basquetas['observacoesBasquetas'].toString().isNotEmpty)
                _buildDetalheLinha(
                  'Observações',
                  basquetas['observacoesBasquetas'],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetalheLinha(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
