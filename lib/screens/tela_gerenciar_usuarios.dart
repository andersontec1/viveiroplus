import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:viveiro_plus/screens/cadastro_usuarios.dart';
import '../widgets/degrade_fundo.dart'; // adicione este import

class TelaGerenciarUsuarios extends StatefulWidget {
  const TelaGerenciarUsuarios({super.key});

  @override
  State<TelaGerenciarUsuarios> createState() => _TelaGerenciarUsuariosState();
}

class _TelaGerenciarUsuariosState extends State<TelaGerenciarUsuarios> {
  String? uidAtual;
  String buscaNome = '';
  String filtroFuncao = 'todos';

  final funcoesDisponiveis = [
    'todos',
    'registrador',
    'arraçoador',
    'supervisor',
    'gerente',
    'admin',
  ];

  final funcoesComIcone = {
    'registrador': Icons.water,
    'arraçoador': Icons.restaurant,
    'supervisor': Icons.search,
    'gerente': Icons.manage_accounts,
    'admin': Icons.verified_user,
  };

  @override
  void initState() {
    super.initState();
    uidAtual = FirebaseAuth.instance.currentUser?.uid;
  }

Future<void> _editarUsuario(
  BuildContext context,
  String uid,
  String nomeAtual,
  String funcaoAtual,
) async {
  final nomeController = TextEditingController(text: nomeAtual);
  final usuarioController = TextEditingController();
  final senhaController = TextEditingController();
  String novaFuncao = funcoesDisponiveis.contains(funcaoAtual) ? funcaoAtual : 'registrador';

  final resultado = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Editar Usuário'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomeController,
              decoration: const InputDecoration(labelText: 'Nome completo'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: usuarioController,
              decoration: const InputDecoration(labelText: 'Nome de usuário'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: senhaController,
              decoration: const InputDecoration(labelText: 'Nova senha (opcional)'),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: novaFuncao,
              items: funcoesDisponiveis
                  .where((f) => f != 'todos')
                  .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                  .toList(),
              onChanged: (value) => novaFuncao = value!,
              decoration: const InputDecoration(labelText: 'Função'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salvar')),
      ],
    ),
  );

  if (resultado == true) {
    final novoNome = nomeController.text.trim();
    final novoUsuario = usuarioController.text.trim().toLowerCase();
    final novaSenha = senhaController.text.trim();

    try {
      // Atualiza no Firestore
      await FirebaseFirestore.instance.collection('usuarios').doc(uid).update({
        'nome': novoNome,
        'nomeusuario': novoUsuario,
        'funcao': novaFuncao,
      });

      // Atualiza senha se for o próprio usuário
      if (novaSenha.isNotEmpty && uid == FirebaseAuth.instance.currentUser?.uid) {
        await FirebaseAuth.instance.currentUser!.updatePassword(novaSenha);
      } else if (novaSenha.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Você só pode alterar sua própria senha.')),
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuário atualizado com sucesso!')),
      );
    } catch (e) {
      print('Erro ao atualizar: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar: $e')),
      );
    }
  }
}

  Future<void> _excluirUsuario(BuildContext context, String uid) async {
    if (uid == uidAtual) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Você não pode excluir a si mesmo.')),
      );
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: const Text('Tem certeza que deseja excluir este usuário?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await FirebaseFirestore.instance.collection('usuarios').doc(uid).delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuário excluído com sucesso.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuariosRef = FirebaseFirestore.instance.collection('usuarios');

    return Scaffold(
      appBar: AppBar(title: const Text('Gerenciar Usuários')),
      body: DegradeFundo(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Buscar por nome',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) {
                      setState(() {
                        buscaNome = value.trim().toLowerCase();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: filtroFuncao,
                    items: funcoesDisponiveis
                        .map((f) => DropdownMenuItem(
                            value: f,
                            child: Text(f == 'todos' ? 'Todas as funções' : f)))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        filtroFuncao = value!;
                      });
                    },
                    decoration: const InputDecoration(labelText: 'Filtrar por função'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: usuariosRef.orderBy('nome').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('Nenhum usuário encontrado.'));
                  }

                  final todos = snapshot.data!.docs;
                  final filtrados = todos.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final nome = (data['nome'] ?? '').toString().toLowerCase();
                    final funcao = (data.containsKey('funcao') ? data['funcao'] : 'indefinida').toString();
                    final nomeConfere = nome.contains(buscaNome);
                    final funcaoConfere = filtroFuncao == 'todos' || funcao == filtroFuncao;
                    return nomeConfere && funcaoConfere;
                  }).toList();

                  if (filtrados.isEmpty) {
                    return const Center(child: Text('Nenhum usuário encontrado com os filtros.'));
                  }

                  return ListView.builder(
                    itemCount: filtrados.length,
                    itemBuilder: (context, index) {
                      final doc = filtrados[index];
                      final uid = doc.id;
                      final data = doc.data() as Map<String, dynamic>;
                      final nome = data['nome'] ?? 'Sem nome';
                      final funcao = data.containsKey('funcao') ? data['funcao'] : 'indefinida';
                      final icone = funcoesComIcone[funcao] ?? Icons.person;

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: ListTile(
                          leading: Icon(icone, color: Colors.blue),
                          title: Text(nome),
                          subtitle: Text('Função: $funcao'),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'editar') {
                                _editarUsuario(context, uid, nome, funcao);
                              } else if (value == 'excluir') {
                                _excluirUsuario(context, uid);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'editar', child: Text('Editar')),
                              if (uid != uidAtual)
                                const PopupMenuItem(value: 'excluir', child: Text('Excluir')),
                            ],
                          ),
                          onTap: () async {
                            // Exibe todos os dados do usuário (exceto senha) e permite edição direta
                            final nomeController = TextEditingController(text: data['nome'] ?? '');
                            final usuarioController = TextEditingController(text: data['nomeusuario'] ?? '');
                            String funcaoAtual = data['funcao'] ?? 'registrador';
                            await showDialog(
                              context: context,
                              builder: (ctx) {
                                return AlertDialog(
                                  title: const Text('Detalhes do Usuário'),
                                  content: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TextField(
                                          controller: nomeController,
                                          decoration: const InputDecoration(labelText: 'Nome completo'),
                                        ),
                                        const SizedBox(height: 8),
                                        TextField(
                                          controller: usuarioController,
                                          decoration: const InputDecoration(labelText: 'Nome de usuário'),
                                        ),
                                        const SizedBox(height: 8),
                                        DropdownButtonFormField<String>(
                                          value: funcaoAtual,
                                          items: funcoesDisponiveis
                                              .where((f) => f != 'todos')
                                              .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                                              .toList(),
                                          onChanged: (value) {
                                            if (value != null) funcaoAtual = value;
                                          },
                                          decoration: const InputDecoration(labelText: 'Função'),
                                        ),
                                        const SizedBox(height: 12),
                                        ...data.entries.where((e) => e.key != 'nome' && e.key != 'nomeusuario' && e.key != 'funcao').map((e) => Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 2),
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text('${e.key}: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                                                  Expanded(child: Text('${e.value}')),
                                                ],
                                              ),
                                            )),
                                        const SizedBox(height: 12),
                                        const Text(
                                          'A senha não pode ser exibida por segurança. Para alterar, use a opção Editar Usuário.',
                                          style: TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('Cancelar'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () async {
                                        final novoNome = nomeController.text.trim();
                                        final novoUsuario = usuarioController.text.trim().toLowerCase();
                                        try {
                                          await FirebaseFirestore.instance.collection('usuarios').doc(uid).update({
                                            'nome': novoNome,
                                            'nomeusuario': novoUsuario,
                                            'funcao': funcaoAtual,
                                          });
                                          if (ctx.mounted) {
                                            Navigator.pop(ctx);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Usuário atualizado com sucesso!')),
                                            );
                                          }
                                        } catch (e) {
                                          if (ctx.mounted) {
                                            Navigator.pop(ctx);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Erro ao atualizar: $e')),
                                            );
                                          }
                                        }
                                      },
                                      child: const Text('Salvar Alterações'),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal,
        child: const Icon(Icons.person_add),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CadastroUsuarioScreen()),
        ),
      ),
    );
  }
}