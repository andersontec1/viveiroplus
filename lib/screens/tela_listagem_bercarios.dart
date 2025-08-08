import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/degrade_fundo.dart';
import 'tela_editar_bercario.dart';

class TelaListagemBercarios extends StatefulWidget {
  const TelaListagemBercarios({super.key});

  @override
  State<TelaListagemBercarios> createState() => _TelaListagemBercariosState();
}

class _TelaListagemBercariosState extends State<TelaListagemBercarios> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  Future<void> _mostrarDetalhes(Map<String, dynamic> data) async {
    final nome = data['nome'] ?? 'Sem nome';
    final codigo = data['codigo'] ?? '---';
    final area = data['area'] ?? '—';
    final volume = data['volume'] ?? '—';
    Widget infoDetalhe(String label, String valor, {IconData? icon, Color? cor}) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: cor ?? Colors.teal.shade50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.teal, size: 18),
              const SizedBox(width: 6),
            ],
            Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(valor, style: TextStyle(color: Colors.teal.shade900, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Container(
          padding: const EdgeInsets.all(0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFB2DFDB),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                ),
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: const Column(
                  children: [
                    Icon(Icons.child_care, color: Colors.teal, size: 38),
                    SizedBox(height: 6),
                    Text('Detalhes do Berçário', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    infoDetalhe('Nome', nome, icon: Icons.label),
                    infoDetalhe('Código', codigo, icon: Icons.confirmation_number),
                    infoDetalhe('Área', '$area m²', icon: Icons.square_foot),
                    infoDetalhe('Volume', '$volume m³', icon: Icons.water_drop),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fechar', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
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
    final bercariosQuery = FirebaseFirestore.instance
        .collection('bercarios')
        .orderBy('codigo');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Berçários'),
        backgroundColor: Colors.teal,
        elevation: 0,
      ),
      body: DegradeFundo(
        child: Column(
          children: [
            const SizedBox(height: 10),
            Center(
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/camaraoico.png',
                    width: 48,
                    height: 48,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Listagem de Berçários',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.teal),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Gerencie e visualize todos os berçários cadastrados',
                    style: TextStyle(fontSize: 15, color: Colors.teal, fontWeight: FontWeight.w400),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchText = v),
                decoration: InputDecoration(
                  hintText: 'Buscar por nome ou código',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.9),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: bercariosQuery.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data?.docs ?? [];
                  final filteredDocs = docs.where((doc) {
                    final data = doc.data()! as Map<String, dynamic>;
                    final nome = (data['nome'] ?? '').toString().toLowerCase();
                    final codigo = (data['codigo'] ?? '').toString().toLowerCase();
                    return _searchText.isEmpty ||
                        nome.contains(_searchText.toLowerCase()) ||
                        codigo.contains(_searchText.toLowerCase());
                  }).toList();

                  if (filteredDocs.isEmpty) {
                    return const Center(child: Text('Nenhum berçário encontrado.'));
                  }

                  return ListView.separated(
                    itemCount: filteredDocs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final doc = filteredDocs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final codigo = data['codigo'] ?? '---';
                      final nome = data['nome'] ?? 'Sem nome';
                      final docId = doc.id;
                      return Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _mostrarDetalhes(data),
                          child: ListTile(
                            leading: Padding(
                              padding: const EdgeInsets.all(2.0),
                              child: Image.asset(
                                'assets/images/camaraoico.png',
                                width: 32,
                                height: 32,
                              ),
                            ),
                            title: Text(nome, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            subtitle: Text('Código: $codigo', style: Theme.of(context).textTheme.bodySmall),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'detalhes') {
                                  await _mostrarDetalhes(data);
                                } else if (value == 'editar') {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => TelaEditarBercario(docId: docId, dados: data),
                                    ),
                                  );
                                } else if (value == 'excluir') {
                                  final confirm1 = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text('Excluir Berçário'),
                                      content: const Text('Tem certeza que deseja excluir este berçário? Esta ação não pode ser desfeita.'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: const Text('Cancelar'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          child: const Text('Excluir', style: TextStyle(color: Colors.red)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm1 == true) {
                                    final confirm2 = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text('Confirmação Final'),
                                        content: const Text('Esta ação é irreversível. Deseja realmente excluir?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: const Text('Cancelar'),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm2 == true) {
                                      try {
                                        await FirebaseFirestore.instance.collection('bercarios').doc(docId).delete();
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Berçário excluído com sucesso!'), backgroundColor: Colors.green),
                                          );
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Erro ao excluir: $e')),
                                          );
                                        }
                                      }
                                    }
                                  }
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: 'detalhes', child: ListTile(leading: Icon(Icons.info), title: Text('Detalhes'))),
                                const PopupMenuItem(value: 'editar', child: ListTile(leading: Icon(Icons.edit), title: Text('Editar'))),
                                const PopupMenuItem(value: 'excluir', child: ListTile(leading: Icon(Icons.delete), title: Text('Excluir'))),
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
          ],
        ),
      ),
    );
  }
}