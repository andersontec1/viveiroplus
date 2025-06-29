import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/app_scaffold.dart';
import 'tela_editar_viveiro.dart';
import '../widgets/degrade_fundo.dart';

class TelaListagemViveiros extends StatefulWidget {
  const TelaListagemViveiros({super.key});
  @override
  _TelaListagemViveirosState createState() => _TelaListagemViveirosState();
}

class _TelaListagemViveirosState extends State<TelaListagemViveiros> {
  static const List<String> _filtros = ['Todos', 'Viveiro', 'Bercario'];
  String _filtroSelecionado = _filtros.first;

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance.collection('viveiros');
    if (_filtroSelecionado == 'Viveiro') {
      query = query.where('temBercario', isEqualTo: false);
    } else if (_filtroSelecionado == 'Bercario') {
      query = query.where('temBercario', isEqualTo: true);
    }
    query = query.orderBy('codigo');

    return AppScaffold(
      title: 'Listar Viveiros',
      backgroundColor: Colors.transparent, // Remove cor fixa
      body: DegradeFundo(
        child: RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: DropdownButtonFormField<String>(
                  value: _filtroSelecionado,
                  decoration: InputDecoration(
                    labelText: 'Filtrar por tipo',
                    labelStyle: Theme.of(context).textTheme.bodyLarge,
                    border: const OutlineInputBorder(),
                  ),
                  style: Theme.of(context).textTheme.bodyLarge,
                  items: _filtros
                      .map((f) => DropdownMenuItem(value: f, child: Text(f, style: Theme.of(context).textTheme.bodyLarge)))
                      .toList(),
                  onChanged: (v) => setState(() => _filtroSelecionado = v!),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: query.snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return Center(child: Text('Nenhum viveiro encontrado.', style: Theme.of(context).textTheme.bodyLarge));
                    }

                    return ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        final doc = docs[i];
                        final data = doc.data()! as Map<String, dynamic>;
                        final nome = data['nome'] ?? '—';
                        final codigo = data['codigo'] ?? '';
                        final temB = data['temBercario'] as bool? ?? false;
                        final ts = (data['criadoEm'] as Timestamp?)?.toDate();
                        final criadoStr = ts != null
                            ? DateFormat('dd/MM/yyyy HH:mm').format(ts)
                            : 'Data desconhecida';

                        return FutureBuilder<QuerySnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('bercarios')
                              .where('viveiroCodigo', isEqualTo: codigo)
                              .limit(1)
                              .get(),
                          builder: (context, snapshotBercario) {
                            String extraInfo = temB ? 'Bercario: ' : '';
                            String? nomeBercario;

                            if (snapshotBercario.hasData && snapshotBercario.data!.docs.isNotEmpty) {
                              final bData = snapshotBercario.data!.docs.first.data() as Map<String, dynamic>;
                              nomeBercario = bData['nome'];
                              extraInfo += nomeBercario ?? '';
                            } else if (temB) {
                              extraInfo += 'não encontrado';
                            }

                            return ListTile(
                              leading: Icon(
                                temB ? Icons.spa : Icons.water,
                                color: temB ? Colors.green : Colors.blue,
                              ),
                              title: Text('$nome  (cód: $codigo)', style: Theme.of(context).textTheme.titleMedium),
                              subtitle: Text('$extraInfo\n$criadoStr', style: Theme.of(context).textTheme.bodySmall),
                              isThreeLine: true,
                              onTap: () => _mostrarDetalhes(context, data, nomeBercario),
                              trailing: Wrap(
                                spacing: 4,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () async {
                                      final atualizado = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => TelaEditarViveiro(
                                            docId: doc.id,
                                            dados: data,
                                          ),
                                        ),
                                      );
                                      if (atualizado == true && mounted) {
                                        setState(() {});
                                      }
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          title: Text('Excluir Viveiro', style: Theme.of(context).textTheme.titleLarge),
                                          content: Text(
                                            'Tem certeza? Esta ação não pode ser desfeita.',
                                            style: Theme.of(context).textTheme.bodyMedium,
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, false),
                                              child: Text('Cancelar', style: Theme.of(context).textTheme.labelLarge),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, true),
                                              child: Text('Excluir', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.red)),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await doc.reference.delete();
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Viveiro excluído com sucesso!', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white)),
                                            ),
                                          );
                                          setState(() {});
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _mostrarDetalhes(BuildContext context, Map<String, dynamic> data, String? nomeBercario) {
    final criadoEm = (data['criadoEm'] as Timestamp?)?.toDate();
    final criadoStr = criadoEm != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(criadoEm)
        : 'Data desconhecida';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Detalhes do Viveiro'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nome: ${data['nome']}'),
            Text('Código: ${data['codigo']}'),
            Text('Criado em: $criadoStr'),
            Text('Possui bercario: ${data['temBercario'] ? 'Sim' : 'Não'}'),
            if (nomeBercario != null) Text('Nome do Bercario: $nomeBercario'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}
