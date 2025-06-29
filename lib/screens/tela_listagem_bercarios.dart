import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/degrade_fundo.dart'; // adicione este import

class TelaListagemBercarios extends StatefulWidget {
  const TelaListagemBercarios({super.key});

  @override
  State<TelaListagemBercarios> createState() => _TelaListagemBercariosState();
}

class _TelaListagemBercariosState extends State<TelaListagemBercarios> {
  Future<void> _mostrarOpcoesBercario(Map<String, dynamic> data, String docId) async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('Detalhes'),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Dados do Berçário'),
                    content: Text('Nome: ${data['nome'] ?? 'Sem nome'}\nCódigo: ${data['codigo'] ?? '---'}'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Fechar'),
                      ),
                    ],
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Editar'),
              onTap: () {
                Navigator.pop(context);
                // Implemente aqui a navegação para tela de edição, se desejar
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Funcionalidade de edição não implementada.')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Excluir', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Excluir berçário?'),
                    content: const Text('Tem certeza que deseja excluir este berçário?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Excluir', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await FirebaseFirestore.instance.collection('bercarios').doc(docId).delete();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Berçário excluído com sucesso!')),
                  );
                }
              },
            ),
          ],
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
      ),
      body: DegradeFundo(
        child: StreamBuilder<QuerySnapshot>(
          stream: bercariosQuery.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Center(child: Text('Nenhum berçário encontrado.'));
            }

            return ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final codigo = data['codigo'] ?? '---';
                final nome = data['nome'] ?? 'Sem nome';
                final docId = docs[index].id;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: const Icon(Icons.child_care),
                    title: Text(nome),
                    subtitle: Text('Código: $codigo'),
                    trailing: const Icon(Icons.more_vert),
                    onTap: () => _mostrarOpcoesBercario(data, docId),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}