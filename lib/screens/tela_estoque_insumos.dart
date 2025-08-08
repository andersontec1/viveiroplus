import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/degrade_fundo.dart';

class TelaEstoqueInsumos extends StatefulWidget {
  const TelaEstoqueInsumos({super.key});

  @override
  State<TelaEstoqueInsumos> createState() => _TelaEstoqueInsumosState();
}

class _TelaEstoqueInsumosState extends State<TelaEstoqueInsumos> {
  String _busca = '';
  String? _filtroTipo;

  void _abrirMovimentacaoDialog(Map<String, dynamic> insumo, String docId) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _MovimentacaoDialog(insumo: insumo),
    );
    if (result != null) {
      final mov = {
        'insumoId': docId,
        'nome': insumo['nome'],
        'tipo': insumo['tipo'],
        'quantidade': result['quantidade'],
        'tipoMov': result['tipoMov'],
        'observacao': result['observacao'],
        'timestamp': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance.collection('movimentacoes_estoque').add(mov);
      // Atualiza estoque no insumo
      final ref = FirebaseFirestore.instance.collection('insumos').doc(docId);
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final atual = (snap.data()?['estoque'] ?? 0) as num;
        final novo = result['tipoMov'] == 'entrada'
            ? atual + result['quantidade']
            : atual - result['quantidade'];
        tx.update(ref, {'estoque': novo});
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Movimentação registrada com sucesso!')),
      );
    }
  }

  void _abrirHistoricoMovimentacoes(String insumoId, String nome) {
    showDialog(
      context: context,
      builder: (_) => _HistoricoMovimentacoesDialog(insumoId: insumoId, nome: nome),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Estoque de Insumos',
      body: DegradeFundo(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Buscar insumo',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) => setState(() => _busca = val),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _filtroTipo,
                    hint: const Text('Tipo'),
                    items: const [
                      DropdownMenuItem(value: 'Probiótico', child: Text('Probiótico')),
                      DropdownMenuItem(value: 'Ração', child: Text('Ração')),
                      DropdownMenuItem(value: 'Suplemento', child: Text('Suplemento')),
                      DropdownMenuItem(value: 'Outro', child: Text('Outro')),
                    ],
                    onChanged: (val) => setState(() => _filtroTipo = val),
                  ),
                  IconButton(
                    icon: const Icon(Icons.filter_alt_off_rounded),
                    tooltip: 'Limpar filtros',
                    onPressed: () => setState(() { _busca = ''; _filtroTipo = null; }),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('insumos').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final docs = snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final nome = (data['nome'] ?? '').toString().toLowerCase();
                      final tipo = (data['tipo'] ?? '').toString();
                      final buscaOk = nome.contains(_busca.toLowerCase());
                      final tipoOk = _filtroTipo == null || tipo == _filtroTipo;
                      return buscaOk && tipoOk;
                    }).toList();
                    if (docs.isEmpty) return const Center(child: Text('Nenhum insumo encontrado.'));
                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final insumo = docs[index];
                        final data = insumo.data() as Map<String, dynamic>;
                        final estoque = data.containsKey('estoque')
                            ? (data['estoque'] ?? 0) as num
                            : (data['quantidade_inicial'] ?? 0) as num;
                        final baixo = estoque < 5;
                        final validade = data['validade'] is Timestamp ? (data['validade'] as Timestamp).toDate() : null;
                        final vencido = validade != null && validade.isBefore(DateTime.now());
                        final pertoVencer = validade != null && !vencido && validade.difference(DateTime.now()).inDays <= 7;
                        List<Widget> chips = [];
                        if (baixo) {
                          chips.add(const Chip(label: Text('Estoque baixo'), backgroundColor: Colors.redAccent, labelStyle: TextStyle(color: Colors.white), visualDensity: VisualDensity.compact));
                        }
                        if (vencido) {
                          chips.add(const Chip(label: Text('Vencido'), backgroundColor: Colors.black54, labelStyle: TextStyle(color: Colors.white), visualDensity: VisualDensity.compact));
                        } else if (pertoVencer) {
                          chips.add(const Chip(label: Text('Vence em breve'), backgroundColor: Colors.orange, labelStyle: TextStyle(color: Colors.white), visualDensity: VisualDensity.compact));
                        }
                        return Card(
                          elevation: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          color: baixo ? Colors.red[50] : Colors.white,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => _abrirHistoricoMovimentacoes(insumo.id, data['nome']),
                            onLongPress: () => _abrirMovimentacaoDialog(data, insumo.id),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: baixo ? Colors.red[100] : Colors.teal[50],
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    padding: const EdgeInsets.all(12),
                                    child: Icon(Icons.inventory_2_rounded, color: baixo ? Colors.red : Colors.teal, size: 36),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                data['nome'],
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (chips.isNotEmpty)
                                              Row(children: chips.map((c) => Padding(padding: const EdgeInsets.only(left: 4), child: c)).toList()),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text('${data['tipo']} • ${data['categoria'] ?? ''}', style: const TextStyle(fontSize: 14, color: Colors.black54)),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(Icons.straighten_rounded, size: 16, color: Colors.teal[300]),
                                            const SizedBox(width: 4),
                                            Text('Unidade: ${data['unidade'] ?? '-'}', style: const TextStyle(fontSize: 13)),
                                            if (validade != null)
                                              Padding(
                                                padding: const EdgeInsets.only(left: 16),
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.event_rounded, size: 16, color: vencido ? Colors.red : (pertoVencer ? Colors.orange : Colors.teal)),
                                                    const SizedBox(width: 3),
                                                    Text('Validade: ${validade.day.toString().padLeft(2, '0')}/${validade.month.toString().padLeft(2, '0')}/${validade.year}',
                                                      style: TextStyle(fontSize: 13, color: vencido ? Colors.red : (pertoVencer ? Colors.orange : Colors.teal))),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(Icons.local_shipping_rounded, size: 16, color: Colors.teal[300]),
                                            const SizedBox(width: 4),
                                            Text('Fornecedor: ${data['fornecedor'] ?? '-'}', style: const TextStyle(fontSize: 13)),
                                            if ((data['lote'] ?? '').toString().isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(left: 16),
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.confirmation_number_rounded, size: 16, color: Colors.teal[300]),
                                                    const SizedBox(width: 3),
                                                    Text('Lote: ${data['lote']}', style: const TextStyle(fontSize: 13)),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('Estoque', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                                      const SizedBox(height: 2),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: baixo ? Colors.red[100] : Colors.teal[50],
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '$estoque',
                                          style: TextStyle(
                                            color: baixo ? Colors.red : Colors.teal[800],
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.orange),
                                        tooltip: 'Editar quantidade',
                                        onPressed: () async {
                                          final controller = TextEditingController(text: estoque.toString());
                                          final result = await showDialog<num?>(
                                            context: context,
                                            builder: (_) => AlertDialog(
                                              title: Text('Editar Estoque: ${data['nome']}'),
                                              content: TextFormField(
                                                controller: controller,
                                                keyboardType: TextInputType.number,
                                                decoration: const InputDecoration(labelText: 'Nova quantidade'),
                                              ),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                                                ElevatedButton(
                                                  onPressed: () {
                                                    final novo = num.tryParse(controller.text);
                                                    if (novo == null || novo < 0) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        const SnackBar(content: Text('Informe um valor válido!')),
                                                      );
                                                      return;
                                                    }
                                                    Navigator.pop(context, novo);
                                                  },
                                                  child: const Text('Salvar'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (result != null) {
                                            // Se não existe campo estoque, atualiza ambos estoque e quantidade_inicial
                                            if (!data.containsKey('estoque')) {
                                              await FirebaseFirestore.instance.collection('insumos').doc(insumo.id).update({
                                                'estoque': result,
                                                'quantidade_inicial': result,
                                              });
                                            } else {
                                              await FirebaseFirestore.instance.collection('insumos').doc(insumo.id).update({'estoque': result});
                                            }
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Estoque atualizado!')),
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.grey),
                  SizedBox(width: 4),
                  Text('Toque para ver histórico, pressione para movimentar', style: TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MovimentacaoDialog extends StatefulWidget {
  const _MovimentacaoDialog({required this.insumo});
  final Map<String, dynamic> insumo;

  @override
  State<_MovimentacaoDialog> createState() => _MovimentacaoDialogState();
}

class _MovimentacaoDialogState extends State<_MovimentacaoDialog> {
  String _tipoMov = 'entrada';
  final _qtdController = TextEditingController();
  final _obsController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Movimentar Estoque: ${widget.insumo['nome']}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: _tipoMov,
            items: const [
              DropdownMenuItem(value: 'entrada', child: Text('Entrada')),
              DropdownMenuItem(value: 'saida', child: Text('Saída')),
            ],
            onChanged: (val) => setState(() => _tipoMov = val!),
            decoration: const InputDecoration(labelText: 'Tipo de Movimentação'),
          ),
          TextFormField(
            controller: _qtdController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Quantidade'),
          ),
          TextFormField(
            controller: _obsController,
            decoration: const InputDecoration(labelText: 'Observação (opcional)'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () {
            final qtd = num.tryParse(_qtdController.text);
            if (qtd == null || qtd <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Informe uma quantidade válida!')),
              );
              return;
            }
            Navigator.pop(context, {
              'tipoMov': _tipoMov,
              'quantidade': qtd,
              'observacao': _obsController.text.trim(),
            });
          },
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}

class _HistoricoMovimentacoesDialog extends StatelessWidget {
  const _HistoricoMovimentacoesDialog({required this.insumoId, required this.nome});
  final String insumoId;
  final String nome;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Histórico: $nome'),
      content: SizedBox(
        width: 350,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('movimentacoes_estoque')
              .where('insumoId', isEqualTo: insumoId)
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) return const Text('Nenhuma movimentação encontrada.');
            return ListView.builder(
              shrinkWrap: true,
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final mov = docs[index].data() as Map<String, dynamic>;
                final tipo = mov['tipoMov'] == 'entrada' ? 'Entrada' : 'Saída';
                final cor = mov['tipoMov'] == 'entrada' ? Colors.green : Colors.red;
                final qtd = mov['quantidade'];
                final obs = mov['observacao'] ?? '';
                final data = (mov['timestamp'] as Timestamp?)?.toDate();
                return ListTile(
                  leading: Icon(mov['tipoMov'] == 'entrada' ? Icons.add : Icons.remove, color: cor),
                  title: Text('$tipo: $qtd'),
                  subtitle: Text(obs.isNotEmpty ? obs : '-'),
                  trailing: data != null ? Text('${data.day}/${data.month}/${data.year} ${data.hour}:${data.minute.toString().padLeft(2, '0')}') : null,
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
      ],
    );
  }
}
