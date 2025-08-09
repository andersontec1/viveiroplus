import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/degrade_fundo.dart';

class TelaDetalhesViveiro extends StatefulWidget {
  const TelaDetalhesViveiro({
    super.key,
    required this.codigo,
    required this.nome,
    required this.dadosViveiro,
  });

  final String codigo;
  final String nome;
  final Map<String, dynamic> dadosViveiro;

  @override
  State<TelaDetalhesViveiro> createState() => _TelaDetalhesViveiroState();
}

class _TelaDetalhesViveiroState extends State<TelaDetalhesViveiro> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildInfoCard() {
    final area = widget.dadosViveiro['area'] ?? '—';
    final volume = widget.dadosViveiro['volume'] ?? '—';
    final temBercario = widget.dadosViveiro['temBercario'] as bool? ?? false;
    final ts = (widget.dadosViveiro['criadoEm'] as Timestamp?)?.toDate();
    final criadoStr = ts != null ? DateFormat('dd/MM/yyyy HH:mm').format(ts) : 'Data desconhecida';

    Widget infoDetalhe(String label, String valor, {IconData? icon}) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.teal.shade50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.teal, size: 20),
              const SizedBox(width: 8),
            ],
            Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(valor, style: TextStyle(color: Colors.teal.shade900, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.water, color: Colors.teal, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.nome,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Código: ${widget.codigo}',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            infoDetalhe('Área', '$area m²', icon: Icons.square_foot),
            infoDetalhe('Volume', '$volume m³', icon: Icons.water_drop),
            infoDetalhe('Possui berçário', temBercario ? 'Sim' : 'Não', icon: Icons.spa),
            infoDetalhe('Criado em', criadoStr, icon: Icons.calendar_today),
          ],
        ),
      ),
    );
  }

  Widget _buildRegistrosAnalise() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('registros_diarios')
          .where('codigo', isEqualTo: widget.codigo)
          .where('tipoDestino', isEqualTo: 'viveiro')
          .orderBy('dataHora', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Nenhum registro de análise encontrado',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final dataHora = (data['dataHora'] as Timestamp).toDate();
            final registradoPor = data['registradoPor'] ?? '—';

            // Criar chips de status como na listagem
            final List<Widget> chips = [];
            void addChip(bool condicao, String texto, Color cor) {
              if (condicao) {
                chips.add(Container(
                  margin: const EdgeInsets.only(right: 4),
                  child: Chip(
                    label: Text(texto, style: const TextStyle(fontSize: 10, color: Colors.white)),
                    backgroundColor: cor,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ));
              }
            }

            // Verificar parâmetros fora do ideal
            addChip(_foraDoIdeal('ph', data['ph']), 'pH fora', Colors.red);
            addChip(_foraDoIdeal('oxigenio', data['oxigenio']), 'O₂ fora', Colors.orange);
            addChip(_foraDoIdeal('temperatura', data['temperatura']), 'Temp fora', Colors.blue);
            addChip(_foraDoIdeal('salinidade', data['salinidade']), 'Sal fora', Colors.purple);

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              child: ListTile(
                onTap: () => _mostrarDetalhesAnalise(data),
                leading: const Icon(Icons.analytics, color: Colors.teal),
                title: Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(dataHora),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Por: $registradoPor', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    if (chips.isNotEmpty)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: chips),
                      ),
                  ],
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              ),
            );
          },
        );
      },
    );
  }

  bool _foraDoIdeal(String parametro, dynamic valor) {
    if (valor == null) return false;
    
    try {
      final double val = double.parse(valor.toString());
      switch (parametro) {
        case 'ph':
          return val < 7.5 || val > 8.5;
        case 'oxigenio':
          return val < 5.0;
        case 'temperatura':
          return val < 26.0 || val > 30.0;
        case 'salinidade':
          return val < 15.0 || val > 25.0;
        default:
          return false;
      }
    } catch (_) {
      return false;
    }
  }

  Widget _buildRegistrosRacao() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('racao')
          .where('codigo', isEqualTo: widget.codigo)
          .where('tipoDestino', isEqualTo: 'viveiro')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Nenhum registro de ração encontrado',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final timestamp = (data['timestamp'] as Timestamp).toDate();
            final quantidade = data['quantidade'] ?? 0;
            final sobras = data['sobras'] ?? 0;
            final registradoPor = data['registradoPor'] ?? '—';

            // Calcular a ração efetivamente consumida
            final consumo = quantidade - sobras;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              child: ListTile(
                onTap: () => _mostrarDetalhesRacao(data),
                leading: const Icon(Icons.set_meal, color: Colors.teal),
                title: Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(timestamp),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Fornecido: ${quantidade}kg | Consumo: ${consumo}kg'),
                    if (sobras > 0) Text('Sobras: ${sobras}kg', style: TextStyle(color: Colors.orange[700])),
                    Text('Por: $registradoPor', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_forward_ios, size: 16),
                    if (sobras > quantidade * 0.2) // Se sobras > 20%
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        child: const Icon(Icons.warning, color: Colors.orange, size: 14),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _mostrarDetalhesAnalise(Map<String, dynamic> data) {
    final dt = (data['dataHora'] as Timestamp).toDate();
    
    Widget paramDetalhe(String label, String campo, String unidade, {String? ideal}) {
      final valor = data[campo];
      final fora = _foraDoIdeal(campo, valor);
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: fora ? Colors.red.shade50 : Colors.teal.shade50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (fora)
              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
            if (!fora)
              const Icon(Icons.check_circle, color: Colors.teal, size: 18),
            const SizedBox(width: 6),
            Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
              valor != null ? valor.toString() : '—',
              style: TextStyle(
                color: fora ? Colors.red : Colors.teal.shade900,
                fontWeight: fora ? FontWeight.bold : FontWeight.w600,
              ),
            ),
            if (unidade.isNotEmpty) Text(' $unidade'),
            if (fora && ideal != null)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text('(Ideal: $ideal)', style: const TextStyle(color: Colors.teal, fontSize: 12)),
              ),
          ],
        ),
      );
    }

    final editadoPor = data['editadoPor'];
    final editadoEm = data['editadoEm'];
    
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Container(
          padding: const EdgeInsets.all(0),
          constraints: const BoxConstraints(maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFB2DFDB),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.analytics, color: Colors.teal, size: 28),
                    SizedBox(width: 8),
                    Text('Análise de Água', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, color: Colors.teal, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'Data: ${DateFormat('dd/MM/yyyy HH:mm').format(dt)}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      paramDetalhe('pH', 'ph', '', ideal: '7.5 - 8.5'),
                      paramDetalhe('Oxigênio', 'oxigenio', 'mg/L', ideal: '≥ 5.0'),
                      paramDetalhe('Temperatura', 'temperatura', '°C', ideal: '26 - 30'),
                      paramDetalhe('Salinidade', 'salinidade', 'ppt', ideal: '15 - 25'),
                      if (data['nitrito'] != null) paramDetalhe('Nitrito', 'nitrito', 'mg/L'),
                      if (data['amonia'] != null) paramDetalhe('Amônia', 'amonia', 'mg/L'),
                      if (data['alcalinidade'] != null) paramDetalhe('Alcalinidade', 'alcalinidade', 'mg/L'),
                      if (data['dureza'] != null) paramDetalhe('Dureza', 'dureza', 'mg/L'),
                      if (data['transparencia'] != null) paramDetalhe('Transparência', 'transparencia', 'cm'),
                      if (data['calcio'] != null) paramDetalhe('Cálcio', 'calcio', 'mg/L'),
                      
                      if (data['observacoes'] != null && data['observacoes'].toString().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.note, color: Colors.blue, size: 18),
                                  SizedBox(width: 6),
                                  Text('Observações:', style: TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(data['observacoes'].toString()),
                            ],
                          ),
                        ),
                      ],

                      if (editadoPor != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Editado:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              Text('Por: $editadoPor', style: const TextStyle(fontSize: 12)),
                              if (editadoEm != null)
                                Text(
                                  'Em: ${DateFormat('dd/MM/yyyy HH:mm').format((editadoEm as Timestamp).toDate())}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fechar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _mostrarDetalhesRacao(Map<String, dynamic> data) {
    final dt = (data['timestamp'] as Timestamp).toDate();
    final quantidade = data['quantidade'] ?? 0;
    final sobras = data['sobras'] ?? 0;
    final consumo = quantidade - sobras;
    final eficiencia = quantidade > 0 ? ((consumo / quantidade) * 100).toStringAsFixed(1) : '0';
    
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Container(
          padding: const EdgeInsets.all(0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFB2DFDB),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.set_meal, color: Colors.teal, size: 28),
                    SizedBox(width: 8),
                    Text('Registro de Ração', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: Colors.teal, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'Data: ${DateFormat('dd/MM/yyyy HH:mm').format(dt)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.restaurant, color: Colors.teal, size: 18),
                          const SizedBox(width: 6),
                          Text('Quantidade fornecida: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('${quantidade} kg', style: TextStyle(color: Colors.teal.shade900, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: sobras > 0 ? Colors.orange.shade50 : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            sobras > 0 ? Icons.warning : Icons.check_circle,
                            color: sobras > 0 ? Colors.orange : Colors.green,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text('Sobras: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('${sobras} kg', style: TextStyle(
                            color: sobras > 0 ? Colors.orange.shade900 : Colors.green.shade900,
                            fontWeight: FontWeight.w600,
                          )),
                        ],
                      ),
                    ),
                    
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.trending_up, color: Colors.blue, size: 18),
                          const SizedBox(width: 6),
                          Text('Consumo efetivo: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('${consumo} kg (${eficiencia}%)', style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),

                    if (data['probióticoAplicado'] != null && data['probióticoAplicado'].toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.science, color: Colors.purple, size: 18),
                                SizedBox(width: 6),
                                Text('Probiótico aplicado:', style: TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(data['probióticoAplicado'].toString()),
                          ],
                        ),
                      ),
                    ],
                    
                    if (data['observacoes'] != null && data['observacoes'].toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.note, color: Colors.amber, size: 18),
                                SizedBox(width: 6),
                                Text('Observações:', style: TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(data['observacoes'].toString()),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fechar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: widget.nome,
      body: DegradeFundo(
        child: Column(
          children: [
            _buildInfoCard(),
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.teal,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.teal,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.analytics),
                    text: 'Análise de Água',
                  ),
                  Tab(
                    icon: Icon(Icons.set_meal),
                    text: 'Ração',
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildRegistrosAnalise(),
                  _buildRegistrosRacao(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
