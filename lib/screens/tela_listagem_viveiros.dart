import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/app_scaffold.dart';
import 'tela_editar_viveiro.dart';
import 'tela_detalhes_viveiro.dart';
import 'tela_cadastro_viveiro.dart';
import '../widgets/degrade_fundo.dart';

class TelaListagemViveiros extends StatefulWidget {
  const TelaListagemViveiros({super.key, this.funcaoUsuario});
  final String? funcaoUsuario;
  @override
  _TelaListagemViveirosState createState() => _TelaListagemViveirosState();
}

class _TelaListagemViveirosState extends State<TelaListagemViveiros> {
  static const List<String> _filtros = ['Todos', 'Viveiro'];
  String _filtroSelecionado = _filtros.first;

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance.collection('viveiros');
    if (_filtroSelecionado == 'Viveiro') {
      query = query.where('temBercario', isEqualTo: false);
    }
    query = query.orderBy('codigo');

    return AppScaffold(
      title: 'Viveiros',
      backgroundColor: Colors.transparent,
      body: DegradeFundo(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 10),
              const Center(
                child: Column(
                  children: [
                    Icon(Icons.water, size: 48, color: Colors.teal),
                    SizedBox(height: 6),
                    Text(
                      'Viveiros',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.teal),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Gerencie e visualize todos os viveiros cadastrados',
                      style: TextStyle(fontSize: 15, color: Colors.teal, fontWeight: FontWeight.w400),
                    ),
                    SizedBox(height: 16),
                  ],
                ),
              ),
              // Botão de cadastrar viveiro
              if (widget.funcaoUsuario == 'admin' || widget.funcaoUsuario == 'gerente')
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
                        'Cadastrar Novo Viveiro',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
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
                child: DropdownButtonFormField<String>(
                  value: _filtroSelecionado,
                  decoration: InputDecoration(
                    labelText: 'Filtrar por tipo',
                    labelStyle: Theme.of(context).textTheme.bodyLarge,
                    border: const OutlineInputBorder(),
                  ),
                  style: Theme.of(context).textTheme.bodyLarge,
                  items: _filtros
                      .map((f) => DropdownMenuItem(value: f, child: Text(f)))
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
                        final area = data['area'] ?? '-';
                        final volume = data['volume'] ?? '-';
                        final ts = (data['criadoEm'] as Timestamp?)?.toDate();
                        final criadoStr = ts != null
                            ? DateFormat('dd/MM/yyyy HH:mm').format(ts)
                            : 'Data desconhecida';

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 3,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TelaDetalhesViveiro(
                                  codigo: codigo,
                                  nome: nome,
                                  dadosViveiro: data,
                                ),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                children: [
                                  Icon(
                                    temB ? Icons.spa : Icons.water,
                                    color: temB ? Colors.green : Colors.blue,
                                    size: 36,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('$nome  (cód: $codigo)', style: Theme.of(context).textTheme.titleMedium),
                                        Row(
                                          children: [
                                            Text('Área: $area m²', style: Theme.of(context).textTheme.bodySmall),
                                            const SizedBox(width: 12),
                                            Text('Volume: $volume m³', style: Theme.of(context).textTheme.bodySmall),
                                          ],
                                        ),
                                        Text('Possui berçário: ${temB ? 'Sim' : 'Não'}', style: Theme.of(context).textTheme.bodySmall),
                                        Text(criadoStr, style: Theme.of(context).textTheme.bodySmall),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (value) async {
                                      if (value == 'editar') {
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
                                      } else if (value == 'excluir') {
                                        final confirm1 = await showDialog<bool>(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title: const Text('Excluir Viveiro'),
                                            content: const Text('Tem certeza que deseja excluir este viveiro? Esta ação não pode ser desfeita.'),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                                              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
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
                                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                                                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
                                              ],
                                            ),
                                          );
                                          if (confirm2 == true) {
                                            await doc.reference.delete();
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Viveiro excluído com sucesso!', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white)),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                              setState(() {});
                                            }
                                          }
                                        }
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      if (widget.funcaoUsuario != 'arraçoador')
                                        const PopupMenuItem(value: 'editar', child: ListTile(leading: Icon(Icons.edit), title: Text('Editar'))),
                                      const PopupMenuItem(value: 'excluir', child: ListTile(leading: Icon(Icons.delete), title: Text('Excluir'))),
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
            ],
          ),
        ),
      ),
    );
  }

}
