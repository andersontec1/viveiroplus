import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:viveiro_plus/screens/cadastro_usuarios.dart';
import '../widgets/degrade_fundo.dart';
import 'package:viveiro_plus/widgets/responsive_center.dart';
import '../helpers/audit_helper.dart';
import '../helpers/security_helper.dart';
import '../helpers/permissions_helper.dart';

class TelaGerenciarUsuarios extends StatefulWidget {
  const TelaGerenciarUsuarios({super.key});

  @override
  State<TelaGerenciarUsuarios> createState() => _TelaGerenciarUsuariosState();
}

class _TelaGerenciarUsuariosState extends State<TelaGerenciarUsuarios> {
  String? uidAtual;
  String buscaNome = '';
  String filtroFuncao = 'todos';
  final _buscaController = TextEditingController();
  final _filtroNotifier = ValueNotifier<String>('');
  final _funcaoNotifier = ValueNotifier<String>('todos');

  // Cache de contexto do usuário atual para evitar leituras repetidas
  String? _currentUserFuncao;
  bool _podeGerenciarCache = false;
  bool _segurancaCarregada = false;
  String? _currentUserNome;

  final funcoesDisponiveis = [
    'todos',
    'fornecedor',
    'registrador',
    'arraçoador',
    'supervisor',
    'gerente',
    'admin',
  ];

  final funcoesComIcone = {
    'fornecedor': Icons.local_shipping,
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
    _inicializarSeguranca();
  }

  @override
  void dispose() {
    _buscaController.dispose();
    _filtroNotifier.dispose();
    _funcaoNotifier.dispose();
    super.dispose();
  }

  Future<void> _inicializarSeguranca() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(currentUser.uid)
          .get();
      final data = doc.data();
      final funcao = (data?['funcao'] as String?) ?? '';
      final podeGerenciar = await SecurityHelper.podeGerenciarUsuarios();
      setState(() {
        _currentUserFuncao = funcao;
        _podeGerenciarCache = podeGerenciar;
        _segurancaCarregada = true;
        _currentUserNome = (data?['nome'] as String?) ?? currentUser.uid;
      });
    } catch (_) {
      // Mantém defaults em caso de erro
    }
  }

  Future<void> _editarUsuario(
    BuildContext context,
    String uid,
    String nomeAtual,
    String funcaoAtual,
  ) async {
    // 🔒 VALIDAÇÃO DE SEGURANÇA
    if (!await SecurityHelper.podeEditarUsuarios()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Você não tem permissão para editar usuários.'),
          backgroundColor: Colors.red,
        ),
      );

      // 📝 LOG DE AUDITORIA - Acesso negado
      await AuditHelper.registrarAcessoNegado(
        acao: 'EDITAR_USUARIO',
        motivo: 'Permissão insuficiente',
        detalhes: {'usuario_tentativa': uid},
      );
      return;
    }

    // 🔒 VERIFICAR HIERARQUIA
    if (!await SecurityHelper.podeAlterarUsuario(uid)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Você não pode editar este usuário (hierarquia).'),
          backgroundColor: Colors.red,
        ),
      );

      await AuditHelper.registrarAcessoNegado(
        acao: 'EDITAR_USUARIO',
        motivo: 'Hierarquia insuficiente',
        detalhes: {'usuario_tentativa': uid},
      );
      return;
    }

    // 🔒 RATE LIMITING
    if (!SecurityHelper.verificarRateLimit('editar_usuario')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '⚠️ Muitas tentativas. Aguarde antes de tentar novamente.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final nomeController = TextEditingController(text: nomeAtual);
    final usuarioController = TextEditingController();
    final senhaController = TextEditingController();
    String novaFuncao = funcoesDisponiveis.contains(funcaoAtual)
        ? funcaoAtual
        : 'registrador';

    // Buscar dados anteriores para auditoria
    final doc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(uid)
        .get();
    final dadosAnteriores = doc.data() ?? {};
    final usernameAnterior =
        (dadosAnteriores['nomeUsuario'] ?? dadosAnteriores['nomeusuario'] ?? '')
            .toString();
    if (usernameAnterior.isNotEmpty) {
      usuarioController.text = usernameAnterior;
    }

    // Buscar permissões atuais do usuário (normalizadas)
    List<String> permissoesSelecionadas = [];
    if (doc.exists &&
        doc.data() != null &&
        doc.data()!.containsKey('permissoes')) {
      permissoesSelecionadas = PermissionsHelper.normalize(doc['permissoes']);
    } else {
      permissoesSelecionadas = PermissionsHelper.forRole(novaFuncao);
    }

    // Todas as permissões conhecidas (chaves canônicas)
    final List<String> todasTelas = PermissionsHelper.allKeys();

    // 🔒 Verificar se pode alterar funções
    final podeAlterarFuncoes = await SecurityHelper.podeAlterarFuncoes();

    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Editar Usuário'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nomeController,
                  decoration: const InputDecoration(labelText: 'Nome completo'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: usuarioController,
                  decoration: const InputDecoration(
                    labelText: 'Nome de usuário',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: senhaController,
                  decoration: const InputDecoration(
                    labelText: 'Nova senha (opcional)',
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 18),
                const Text(
                  'Função do usuário',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                DropdownButtonFormField<String>(
                  initialValue: novaFuncao,
                  items: funcoesDisponiveis
                      .where((f) => f != 'todos')
                      .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                      .toList(),
                  onChanged: podeAlterarFuncoes
                      ? (value) {
                          if (value != null) {
                            setState(() {
                              novaFuncao = value;
                              // Se mudar a função, sugerir as permissões padrão da função
                              permissoesSelecionadas =
                                  PermissionsHelper.forRole(novaFuncao);
                            });
                          }
                        }
                      : null, // 🔒 Desabilita se não pode alterar funções
                  decoration: InputDecoration(
                    labelText: 'Função',
                    helperText: podeAlterarFuncoes
                        ? null
                        : 'Apenas administradores podem alterar funções',
                    helperStyle: const TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Telas/permissões de acesso',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 8),
                ...PermissionsHelper.categorizedKeys(
                  only: todasTelas,
                ).entries.map((entry) {
                  final categoria = entry.key;
                  final chaves = entry.value;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4),
                        child: Text(
                          categoria,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.teal,
                          ),
                        ),
                      ),
                      ...chaves.map(
                        (p) => CheckboxListTile(
                          value: permissoesSelecionadas.contains(p),
                          title: Text(
                            PermissionsHelper.labels[p] ?? p,
                            style: const TextStyle(fontSize: 13),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                permissoesSelecionadas.add(p);
                              } else {
                                permissoesSelecionadas.remove(p);
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    if (resultado == true) {
      final novoNome = nomeController.text.trim();
      final novoUsuario = usuarioController.text.trim().toLowerCase();
      final novaSenha = senhaController.text.trim();

      // 🔒 VALIDAÇÕES DE SEGURANÇA
      if (novoNome.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Nome não pode estar vazio.')),
        );
        return;
      }

      if (novoUsuario.isNotEmpty &&
          !SecurityHelper.nomeUsuarioValido(novoUsuario)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '❌ Nome de usuário inválido. Use apenas letras, números e underscore.',
            ),
          ),
        );
        return;
      }

      if (novoUsuario.isNotEmpty &&
          await SecurityHelper.nomeUsuarioExiste(
            novoUsuario,
            uidIgnorar: uid,
          )) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Nome de usuário já existe.')),
        );
        return;
      }

      if (novaSenha.isNotEmpty && !SecurityHelper.senhaForte(novaSenha)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '❌ Senha fraca. Use pelo menos 8 caracteres com maiúscula, minúscula, número e símbolo.',
            ),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      try {
        // Monta apenas os campos alterados para evitar sobrescrever com vazio
        final Map<String, dynamic> updates = {};
        if (novoNome != nomeAtual) updates['nome'] = novoNome;
        if (novaFuncao != funcaoAtual) updates['funcao'] = novaFuncao;
        // Sincroniza ambos campos de usuário somente se informado e alterado
        if (novoUsuario.isNotEmpty && novoUsuario != usernameAnterior) {
          updates['nomeusuario'] = novoUsuario;
          updates['nomeUsuario'] = novoUsuario;
        }
        // Atualiza permissões se houve mudança
        final permissoesAnteriorNorm = PermissionsHelper.normalize(
          (dadosAnteriores['permissoes'] is List)
              ? dadosAnteriores['permissoes']
              : PermissionsHelper.forRole(funcaoAtual),
        );
        final iguais =
            Set.of(permissoesAnteriorNorm).length ==
                Set.of(permissoesSelecionadas).length &&
            Set.of(permissoesAnteriorNorm).containsAll(permissoesSelecionadas);
        if (!iguais) {
          updates['permissoes'] = permissoesSelecionadas;
        }

        if (updates.isNotEmpty) {
          updates['alteradoEm'] = FieldValue.serverTimestamp();
          updates['alteradoPor'] =
              _currentUserNome ?? FirebaseAuth.instance.currentUser?.uid;
        }

        if (updates.isEmpty && novaSenha.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nenhuma alteração realizada.')),
          );
        } else {
          // Atualiza no Firestore
          await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(uid)
              .update(updates);
        }

        // Atualiza senha se for o próprio usuário
        if (novaSenha.isNotEmpty &&
            uid == FirebaseAuth.instance.currentUser?.uid) {
          await FirebaseAuth.instance.currentUser!.updatePassword(novaSenha);
        } else if (novaSenha.isNotEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Você só pode alterar sua própria senha.'),
            ),
          );
          return;
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Usuário atualizado com sucesso!')),
        );

        // 📝 LOG DE AUDITORIA - Usuário editado
        await AuditHelper.registrarEdicaoUsuario(
          uidEditado: uid,
          dadosAnteriores: dadosAnteriores,
          dadosNovos: updates.isEmpty
              ? {if (novaSenha.isNotEmpty) 'senhaAlterada': true}
              : updates,
        );
      } catch (e) {
        // Removido print para produção
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Erro ao atualizar: $e')));

        // 📝 LOG DE AUDITORIA - Erro na edição
        await AuditHelper.registrarAcao(
          acao: 'ERRO_EDICAO_USUARIO',
          modulo: 'GERENCIAMENTO_USUARIOS',
          usuarioAfetado: uid,
          detalhes: {'erro': e.toString()},
        );
      }
    }
  }

  Future<void> _excluirUsuario(BuildContext context, String uid) async {
    // 🔐 VALIDAÇÕES DE SEGURANÇA
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Erro: Usuário não autenticado.')),
      );
      return;
    }

    // 🚫 Impedir auto-exclusão
    if (uid == currentUser.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Você não pode excluir a si mesmo.'),
          backgroundColor: Colors.red,
        ),
      );

      // 📝 LOG DE AUDITORIA - Tentativa de auto-exclusão
      await AuditHelper.registrarAcao(
        acao: 'TENTATIVA_AUTO_EXCLUSAO',
        modulo: 'GERENCIAMENTO_USUARIOS',
        detalhes: {
          'motivo': 'Usuario tentou excluir a propria conta',
          'uid_tentativa': uid,
        },
      );
      return;
    }

    // ⚡ Verificar rate limiting
    final podeExecutar = SecurityHelper.verificarRateLimit(
      'exclusao_usuario',
      limite: 5, // máximo 5 exclusões por minuto
    );
    if (!podeExecutar) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏱️ Muitas ações seguidas. Aguarde um momento.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 🛡️ Verificar permissões hierárquicas
    final currentUserDoc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(currentUser.uid)
        .get();

    final currentUserData = currentUserDoc.data();
    final currentUserFuncao = currentUserData?['funcao'] ?? '';

    // Buscar dados do usuário a ser excluído
    final userToDeleteDoc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(uid)
        .get();

    if (!userToDeleteDoc.exists) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Usuário não encontrado.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final userToDeleteData = userToDeleteDoc.data()!;
    final userToDeleteFuncao = userToDeleteData['funcao'] ?? '';

    // Verificar se tem permissão para gerenciar usuários
    final podeGerenciar = await SecurityHelper.podeGerenciarUsuarios();
    if (!podeGerenciar) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Você não tem permissão para excluir usuários.'),
          backgroundColor: Colors.red,
        ),
      );

      // 📝 LOG DE AUDITORIA - Tentativa sem permissão
      await AuditHelper.registrarAcao(
        acao: 'TENTATIVA_EXCLUSAO_SEM_PERMISSAO',
        modulo: 'GERENCIAMENTO_USUARIOS',
        usuarioAfetado: uid,
        detalhes: {
          'funcao_usuario_atual': currentUserFuncao,
          'funcao_usuario_alvo': userToDeleteFuncao,
        },
      );
      return;
    }

    // 🏗️ Verificar hierarquia (não pode excluir superior ou igual)
    final podePorHierarquia = SecurityHelper.funcaoSuperior(
      currentUserFuncao,
      userToDeleteFuncao,
    );
    if (!podePorHierarquia) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '❌ Você não pode excluir usuários com função "$userToDeleteFuncao".',
          ),
          backgroundColor: Colors.red,
        ),
      );

      // 📝 LOG DE AUDITORIA - Tentativa de exclusão hierárquica inválida
      await AuditHelper.registrarAcao(
        acao: 'TENTATIVA_EXCLUSAO_HIERARQUIA_INVALIDA',
        modulo: 'GERENCIAMENTO_USUARIOS',
        usuarioAfetado: uid,
        detalhes: {
          'funcao_usuario_atual': currentUserFuncao,
          'funcao_usuario_alvo': userToDeleteFuncao,
          'motivo': 'Tentativa de excluir usuario com funcao superior ou igual',
        },
      );
      return;
    }

    // 📋 Preparar dados para confirmação
    final nome = userToDeleteData['nome'] ?? 'Sem nome';
    final email = userToDeleteData['email'] ?? 'Sem email';
    final permissoes = (userToDeleteData['permissoes'] is List)
        ? PermissionsHelper.normalize(userToDeleteData['permissoes'])
        : PermissionsHelper.forRole(userToDeleteFuncao);

    // 🔍 Primeira confirmação visual detalhada
    final confirmar1 = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Confirmar exclusão'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            nome,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.email, size: 18, color: Colors.red),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            email,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.verified_user,
                          size: 18,
                          color: Colors.red,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Função: ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          userToDeleteFuncao,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Permissões que serão removidas:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 4),
              ...permissoes.map(
                (p) => Padding(
                  padding: const EdgeInsets.only(top: 2, left: 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.remove_circle,
                        size: 16,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 6),
                      Text(p, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange.shade200),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '⚠️ Esta ação removerá o usuário do sistema. A conta de autenticação permanecerá ativa e pode ser reativada.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Deseja realmente excluir este usuário?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );

    if (confirmar1 != true) {
      // 📝 LOG DE AUDITORIA - Exclusão cancelada na primeira confirmação
      await AuditHelper.registrarAcao(
        acao: 'EXCLUSAO_CANCELADA_PRIMEIRA_CONFIRMACAO',
        modulo: 'GERENCIAMENTO_USUARIOS',
        usuarioAfetado: uid,
        detalhes: {
          'nome_usuario_alvo': nome,
          'funcao_usuario_alvo': userToDeleteFuncao,
        },
      );
      return;
    }

    // ⚠️ Segunda confirmação crítica
    final confirmar2 = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.dangerous, color: Colors.red, size: 32),
            SizedBox(width: 8),
            Text('ÚLTIMA CONFIRMAÇÃO'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                border: Border.all(color: Colors.red, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  const Text(
                    'ATENÇÃO: AÇÃO IRREVERSÍVEL',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Você está prestes a excluir "$nome" ($userToDeleteFuncao).',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Esta ação não pode ser desfeita.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('❌ Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('🗑️ EXCLUIR DEFINITIVAMENTE'),
          ),
        ],
      ),
    );

    if (confirmar2 != true) {
      // 📝 LOG DE AUDITORIA - Exclusão cancelada na segunda confirmação
      await AuditHelper.registrarAcao(
        acao: 'EXCLUSAO_CANCELADA_SEGUNDA_CONFIRMACAO',
        modulo: 'GERENCIAMENTO_USUARIOS',
        usuarioAfetado: uid,
        detalhes: {
          'nome_usuario_alvo': nome,
          'funcao_usuario_alvo': userToDeleteFuncao,
        },
      );
      return;
    }

    // 🔥 EXECUTAR EXCLUSÃO
    try {
      // Salvar dados antes da exclusão para auditoria
      final dadosExcluidos = Map<String, dynamic>.from(userToDeleteData);

      // IMPORTANTE: Remove apenas do Firestore
      // Firebase Auth não permite exclusão de outros usuários via client SDK
      // Para exclusão completa seria necessário Firebase Admin SDK no backend
      await FirebaseFirestore.instance.collection('usuarios').doc(uid).delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '✅ Usuário "$nome" removido do sistema.\n'
                  '⚠️ Nota: A conta de autenticação permanece ativa e pode ser reativada.',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );

      // 📝 LOG DE AUDITORIA - Exclusão bem-sucedida
      await AuditHelper.registrarExclusaoUsuario(
        uidExcluido: uid,
        dadosUsuario: dadosExcluidos,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('❌ Erro ao excluir usuário: $e')),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );

      // 📝 LOG DE AUDITORIA - Erro na exclusão
      await AuditHelper.registrarAcao(
        acao: 'ERRO_EXCLUSAO_USUARIO',
        modulo: 'GERENCIAMENTO_USUARIOS',
        usuarioAfetado: uid,
        detalhes: {
          'erro': e.toString(),
          'nome_usuario_alvo': nome,
          'funcao_usuario_alvo': userToDeleteFuncao,
        },
      );
    }
  }

  /// 🛡️ Obtém status de segurança do usuário atual
  Future<Map<String, dynamic>> _obterStatusSeguranca() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return {
        'podeGerenciar': false,
        'funcaoAtual': 'Não autenticado',
        'isAdmin': false,
      };
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(currentUser.uid)
          .get();

      if (!doc.exists) {
        return {
          'podeGerenciar': false,
          'funcaoAtual': 'Usuário não encontrado',
          'isAdmin': false,
        };
      }

      final data = doc.data()!;
      final funcao = data['funcao'] as String? ?? 'indefinida';
      final isAdmin = funcao == 'admin';
      final podeGerenciar = await SecurityHelper.podeGerenciarUsuarios();

      return {
        'podeGerenciar': podeGerenciar,
        'funcaoAtual': funcao,
        'isAdmin': isAdmin,
      };
    } catch (e) {
      return {
        'podeGerenciar': false,
        'funcaoAtual': 'Erro ao verificar',
        'isAdmin': false,
      };
    }
  }

  /// 🔍 Verifica permissões específicas para um usuário
  Future<Map<String, bool>> _verificarPermissoesParaUsuario(
    String targetUid,
    String targetFuncao,
  ) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return {
        'podeEditar': false,
        'podeExcluir': false,
        'podeVerDetalhes': false,
      };
    }

    // Usa cache quando disponível para evitar N+1 leituras
    if (_segurancaCarregada) {
      final isCurrentUser = targetUid == currentUser.uid;
      final podeEditarPorHierarquia = SecurityHelper.funcaoSuperior(
        _currentUserFuncao ?? '',
        targetFuncao,
      );
      return {
        'podeEditar':
            _podeGerenciarCache && (podeEditarPorHierarquia || isCurrentUser),
        'podeExcluir':
            _podeGerenciarCache && !isCurrentUser && podeEditarPorHierarquia,
        'podeVerDetalhes': true,
      };
    }

    // Fallback: busca uma vez caso o cache não esteja pronto
    try {
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(currentUser.uid)
          .get();
      final funcao = (currentUserDoc.data()?['funcao'] as String?) ?? '';
      final podeGerenciar = await SecurityHelper.podeGerenciarUsuarios();
      setState(() {
        _currentUserFuncao = funcao;
        _podeGerenciarCache = podeGerenciar;
        _segurancaCarregada = true;
      });
      final isCurrentUser = targetUid == currentUser.uid;
      final podeEditarPorHierarquia = SecurityHelper.funcaoSuperior(
        funcao,
        targetFuncao,
      );
      return {
        'podeEditar':
            podeGerenciar && (podeEditarPorHierarquia || isCurrentUser),
        'podeExcluir':
            podeGerenciar && !isCurrentUser && podeEditarPorHierarquia,
        'podeVerDetalhes': true,
      };
    } catch (_) {
      return {
        'podeEditar': false,
        'podeExcluir': false,
        'podeVerDetalhes': false,
      };
    }
  }

  /// 📋 Mostra detalhes completos do usuário
  Future<void> _mostrarDetalhesUsuario(
    BuildContext context,
    Map<String, dynamic> data,
    String uid,
  ) async {
    final nome = data['nome'] ?? 'Sem nome';
    final email = data['email'] ?? 'Sem email';
    final nomeUsuario = (data['nomeUsuario'] ?? data['nomeusuario'] ?? '')
        .toString();
    final funcao = data['funcao'] ?? 'indefinida';
    final criadoEmTs = data['criadoEm'];
    final Timestamp? criadoEmTimestamp = (criadoEmTs is Timestamp)
        ? criadoEmTs
        : null;
    final DateTime? criadoEm = criadoEmTimestamp != null
        ? criadoEmTimestamp.toDate()
        : null;
    final ultimoLoginTs = data['ultimoLogin'];
    final Timestamp? ultimoLoginTimestamp = (ultimoLoginTs is Timestamp)
        ? ultimoLoginTs
        : null;
    final DateTime? ultimoLogin = ultimoLoginTimestamp != null
        ? ultimoLoginTimestamp.toDate()
        : null;

    final permissoes = (data['permissoes'] is List)
        ? PermissionsHelper.normalize(data['permissoes'])
        : PermissionsHelper.forRole(funcao);

    final isCurrentUser = uid == uidAtual;

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                funcoesComIcone[funcao] ?? Icons.person,
                color: isCurrentUser ? Colors.blue : Colors.teal,
              ),
              const SizedBox(width: 8),
              const Text('Detalhes do Usuário'),
              const SizedBox(width: 6),
              if (isCurrentUser)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    border: Border.all(color: Colors.blue.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'VOCÊ',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 👤 Informações básicas
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    border: Border.all(color: Colors.blue.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              nome,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (nomeUsuario.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.badge,
                              size: 18,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Usuário: ',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Expanded(
                              child: Text(
                                nomeUsuario,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(width: 6),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.verified_user,
                            size: 18,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Função: ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(funcao, style: const TextStyle(fontSize: 15)),
                          if (funcao == 'admin')
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                border: Border.all(color: Colors.red.shade300),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'ADMIN',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 18,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Último acesso: ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Expanded(
                            child: Text(
                              ultimoLogin == null
                                  ? 'Nunca acessou'
                                  : '${ultimoLogin.day.toString().padLeft(2, '0')}/${ultimoLogin.month.toString().padLeft(2, '0')}/${ultimoLogin.year} às ${ultimoLogin.hour.toString().padLeft(2, '0')}:${ultimoLogin.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // 🔐 Permissões
                const Text(
                  'Permissões do sistema:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    border: Border.all(color: Colors.green.shade200),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    children: permissoes
                        .map(
                          (p) => Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  size: 16,
                                  color: Colors.green,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    PermissionsHelper.labels[p] ?? p,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),

                // 📅 Informações de auditoria (se disponíveis)
                if (criadoEm != null) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Informações de auditoria:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      border: Border.all(color: Colors.orange.shade200),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Criado em: ',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Expanded(
                              child: Text(
                                '${criadoEm.day.toString().padLeft(2, '0')}/${criadoEm.month.toString().padLeft(2, '0')}/${criadoEm.year} às ${criadoEm.hour.toString().padLeft(2, '0')}:${criadoEm.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                // 🔒 ID do usuário (para administradores)
                FutureBuilder<bool>(
                  future: SecurityHelper.temFuncaoAdministrativa(),
                  builder: (context, snapshot) {
                    if (snapshot.data == true) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          const Text(
                            'Informações técnicas (Admin):',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              border: Border.all(color: Colors.red.shade200),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.fingerprint,
                                  size: 16,
                                  color: Colors.red,
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'UID: ',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Expanded(
                                  child: Text(
                                    uid,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuariosRef = FirebaseFirestore.instance.collection('usuarios');

    return Scaffold(
      appBar: AppBar(title: const Text('Gerenciar Usuários')),
      body: DegradeFundo(
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

            return ValueListenableBuilder<String>(
              valueListenable: _filtroNotifier,
              builder: (context, termoBusca, _) {
                return ValueListenableBuilder<String>(
                  valueListenable: _funcaoNotifier,
                  builder: (context, funcaoFiltro, _) {
                    String _normalizar(String v) {
                      final lower = v.toLowerCase();
                      const acentos = {
                        'á': 'a',
                        'à': 'a',
                        'ã': 'a',
                        'â': 'a',
                        'ä': 'a',
                        'é': 'e',
                        'è': 'e',
                        'ê': 'e',
                        'ë': 'e',
                        'í': 'i',
                        'ì': 'i',
                        'î': 'i',
                        'ï': 'i',
                        'ó': 'o',
                        'ò': 'o',
                        'ô': 'o',
                        'õ': 'o',
                        'ö': 'o',
                        'ú': 'u',
                        'ù': 'u',
                        'û': 'u',
                        'ü': 'u',
                        'ç': 'c',
                      };
                      final buffer = StringBuffer();
                      for (final ch in lower.split('')) {
                        buffer.write(acentos[ch] ?? ch);
                      }
                      return buffer.toString();
                    }

                    final termoBuscaNormalizado = _normalizar(termoBusca);

                    final filtrados = todos.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final nomeOriginal = (data['nome'] ?? '').toString();
                      final nome = _normalizar(nomeOriginal);
                      final funcao = (data['funcao'] ?? 'indefinida')
                          .toString();
                      final usuarioNorm = _normalizar(
                        (data['nomeUsuario'] ?? data['nomeusuario'] ?? '')
                            .toString(),
                      );
                      final emailNorm = _normalizar(
                        (data['email'] ?? '').toString(),
                      );
                      final nomeConfere =
                          termoBuscaNormalizado.isEmpty ||
                          nome.contains(termoBuscaNormalizado) ||
                          usuarioNorm.contains(termoBuscaNormalizado) ||
                          emailNorm.contains(termoBuscaNormalizado);
                      final funcaoConfere =
                          funcaoFiltro == 'todos' || funcao == funcaoFiltro;
                      return nomeConfere && funcaoConfere;
                    }).toList();

                    return ResponsiveCenter(
                      child: ListView(
                        children: [
                          // Cabeçalho que vai subir junto com a lista
                          const Padding(
                            padding: EdgeInsets.only(
                              top: 24,
                              left: 24,
                              right: 24,
                              bottom: 8,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.people,
                                  size: 48,
                                  color: Colors.teal,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Gerenciar Usuários',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Visualize, edite e exclua usuários cadastrados no sistema.',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.teal,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),

                          // Botão de Cadastro de Novo Usuário
                          FutureBuilder<bool>(
                            future: SecurityHelper.podeGerenciarUsuarios(),
                            builder: (context, snapshot) {
                              if (snapshot.data == true) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 8,
                                  ),
                                  child: ElevatedButton.icon(
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const CadastroUsuarioScreen(),
                                      ),
                                    ),
                                    icon: const Icon(Icons.person_add),
                                    label: const Text('Cadastrar Novo Usuário'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.teal,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                        horizontal: 16,
                                      ),
                                      minimumSize: const Size(
                                        double.infinity,
                                        48,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),

                          // Indicadores de Segurança
                          FutureBuilder<Map<String, dynamic>>(
                            future: _obterStatusSeguranca(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData)
                                return const SizedBox.shrink();

                              final status = snapshot.data!;
                              final podeGerenciar =
                                  status['podeGerenciar'] as bool;
                              final funcaoAtual =
                                  status['funcaoAtual'] as String;
                              final isAdmin = status['isAdmin'] as bool;

                              return Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: podeGerenciar
                                      ? Colors.green.shade50
                                      : Colors.orange.shade50,
                                  border: Border.all(
                                    color: podeGerenciar
                                        ? Colors.green.shade300
                                        : Colors.orange.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      podeGerenciar
                                          ? Icons.verified_user
                                          : Icons.info,
                                      color: podeGerenciar
                                          ? Colors.green
                                          : Colors.orange,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Nível de acesso: $funcaoAtual${isAdmin ? ' (Administrador)' : ''}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: podeGerenciar
                                                  ? Colors.green.shade700
                                                  : Colors.orange.shade700,
                                            ),
                                          ),
                                          Text(
                                            podeGerenciar
                                                ? '✅ Você pode criar, editar e excluir usuários'
                                                : '⚠️ Acesso limitado - apenas visualização',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: podeGerenciar
                                                  ? Colors.green.shade600
                                                  : Colors.orange.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isAdmin)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade100,
                                          border: Border.all(
                                            color: Colors.red.shade300,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: const Text(
                                          'ADMIN',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),

                          // Campos de filtro
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                TextField(
                                  controller: _buscaController,
                                  decoration: const InputDecoration(
                                    labelText: 'Buscar por nome',
                                    prefixIcon: Icon(Icons.search),
                                  ),
                                  onChanged: (value) {
                                    _filtroNotifier.value = value
                                        .trim()
                                        .toLowerCase();
                                  },
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  value: funcaoFiltro,
                                  items: funcoesDisponiveis
                                      .map(
                                        (f) => DropdownMenuItem(
                                          value: f,
                                          child: Text(
                                            f == 'todos'
                                                ? 'Todas as funções'
                                                : f,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    _funcaoNotifier.value = value!;
                                  },
                                  decoration: const InputDecoration(
                                    labelText: 'Filtrar por função',
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Mensagem quando não há resultados
                          if (filtrados.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Nenhum usuário encontrado',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tente ajustar os filtros de busca',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Lista de usuários
                          ...filtrados.map((doc) {
                            final uid = doc.id;
                            final data = doc.data() as Map<String, dynamic>;
                            final nome = data['nome'] ?? 'Sem nome';
                            final email = data['email'] ?? 'Sem email';
                            final funcao = data.containsKey('funcao')
                                ? data['funcao']
                                : 'indefinida';
                            final icone =
                                funcoesComIcone[funcao] ?? Icons.person;
                            final isCurrentUser = uid == uidAtual;

                            return FutureBuilder<Map<String, bool>>(
                              future: _verificarPermissoesParaUsuario(
                                uid,
                                funcao,
                              ),
                              builder: (context, permSnapshot) {
                                final permissoes =
                                    permSnapshot.data ??
                                    {
                                      'podeEditar': false,
                                      'podeExcluir': false,
                                      'podeVerDetalhes': true,
                                    };

                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 6,
                                  ),
                                  elevation: isCurrentUser ? 4 : 2,
                                  color: isCurrentUser
                                      ? Colors.blue.shade50
                                      : null,
                                  child: ListTile(
                                    leading: Stack(
                                      children: [
                                        Icon(
                                          icone,
                                          color: isCurrentUser
                                              ? Colors.blue
                                              : Colors.teal,
                                          size: 28,
                                        ),
                                        if (isCurrentUser)
                                          Positioned(
                                            right: 0,
                                            top: 0,
                                            child: Container(
                                              width: 12,
                                              height: 12,
                                              decoration: const BoxDecoration(
                                                color: Colors.green,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.check,
                                                size: 8,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            nome,
                                            style: TextStyle(
                                              fontWeight: isCurrentUser
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                              color: isCurrentUser
                                                  ? Colors.blue.shade700
                                                  : null,
                                            ),
                                          ),
                                        ),
                                        if (isCurrentUser)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade100,
                                              border: Border.all(
                                                color: Colors.blue.shade300,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'VOCÊ',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue,
                                              ),
                                            ),
                                          ),
                                        if (funcao == 'admin')
                                          Container(
                                            margin: const EdgeInsets.only(
                                              left: 4,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade100,
                                              border: Border.all(
                                                color: Colors.red.shade300,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'ADMIN',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.red,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('Função: $funcao'),
                                        if (email.isNotEmpty &&
                                            email != 'Sem email')
                                          Text(
                                            email,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        // 🛡️ Indicadores de permissão
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            if (permissoes['podeEditar']!)
                                              Container(
                                                margin: const EdgeInsets.only(
                                                  right: 4,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 4,
                                                      vertical: 1,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.green.shade100,
                                                  borderRadius:
                                                      BorderRadius.circular(3),
                                                ),
                                                child: const Text(
                                                  '✏️ Editável',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    color: Colors.green,
                                                  ),
                                                ),
                                              ),
                                            if (permissoes['podeExcluir']!)
                                              Container(
                                                margin: const EdgeInsets.only(
                                                  right: 4,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 4,
                                                      vertical: 1,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.shade100,
                                                  borderRadius:
                                                      BorderRadius.circular(3),
                                                ),
                                                child: const Text(
                                                  '🗑️ Excluível',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    color: Colors.red,
                                                  ),
                                                ),
                                              ),
                                            if (!permissoes['podeEditar']! &&
                                                !permissoes['podeExcluir']!)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 4,
                                                      vertical: 1,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade200,
                                                  borderRadius:
                                                      BorderRadius.circular(3),
                                                ),
                                                child: const Text(
                                                  '👁️ Apenas leitura',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    trailing:
                                        permissoes['podeEditar']! ||
                                            permissoes['podeExcluir']!
                                        ? PopupMenuButton<String>(
                                            onSelected: (value) {
                                              if (value == 'editar') {
                                                _editarUsuario(
                                                  context,
                                                  uid,
                                                  nome,
                                                  funcao,
                                                );
                                              } else if (value == 'excluir') {
                                                _excluirUsuario(context, uid);
                                              }
                                            },
                                            itemBuilder: (context) => [
                                              if (permissoes['podeEditar']!)
                                                const PopupMenuItem(
                                                  value: 'editar',
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.edit,
                                                        size: 16,
                                                      ),
                                                      SizedBox(width: 8),
                                                      Text('Editar'),
                                                    ],
                                                  ),
                                                ),
                                              if (permissoes['podeExcluir']!)
                                                const PopupMenuItem(
                                                  value: 'excluir',
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.delete,
                                                        size: 16,
                                                        color: Colors.red,
                                                      ),
                                                      SizedBox(width: 8),
                                                      Text(
                                                        'Excluir',
                                                        style: TextStyle(
                                                          color: Colors.red,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          )
                                        : const Icon(
                                            Icons.lock,
                                            size: 20,
                                            color: Colors.grey,
                                          ),
                                    onTap: permissoes['podeVerDetalhes']!
                                        ? () => _mostrarDetalhesUsuario(
                                            context,
                                            data,
                                            uid,
                                          )
                                        : null,
                                  ),
                                );
                              },
                            );
                          }),
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
    );
  }
}
