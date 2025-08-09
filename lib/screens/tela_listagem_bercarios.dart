import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/degrade_fundo.dart';
import 'tela_editar_bercario.dart';
import 'tela_detalhes_bercario.dart';
import 'tela_cadastro_viveiro.dart';

class TelaListagemBercarios extends StatefulWidget {
  const TelaListagemBercarios({super.key});

  @override
  State<TelaListagemBercarios> createState() => _TelaListagemBercariosState();
}

class _TelaListagemBercariosState extends State<TelaListagemBercarios> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  @override
  Widget build(BuildContext context) {
    final bercariosQuery = FirebaseFirestore.instance
        .collection('bercarios')
        .orderBy('codigo');

    return AppScaffold(
      title: 'Berçários',
      body: DegradeFundo(
        child: Column(
          children: [
            const SizedBox(height: 10),
            Center(
              child: Column(
                children: [
                  const Icon(Icons.spa, size: 48, color: Colors.green),
                  const SizedBox(height: 6),
                  const Text(
                    'Berçários',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Gerencie e visualize todos os berçários cadastrados',
                    style: TextStyle(fontSize: 15, color: Colors.green, fontWeight: FontWeight.w400),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            // Botão de cadastrar berçário (usando cadastro de viveiro)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final resultado = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TelaCadastroViveiro()),
                    );
                    if (resultado == true && mounted) {
                      setState(() {});
                    }
                  },
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text(
                    'Cadastrar Novo Berçário',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
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
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TelaDetalhesBercario(
                                codigo: data['codigo'] ?? '',
                                nome: data['nome'] ?? '—',
                                dadosBercario: data,
                              ),
                            ),
                          ),
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
                                if (value == 'editar') {
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