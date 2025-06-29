import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:viveiro_plus/screens/tela_analise_agua.dart' as analise;
import 'package:viveiro_plus/screens/tela_arracoador.dart' as arracoador;
import 'package:viveiro_plus/screens/tela_listagem_registros.dart';
import 'package:viveiro_plus/screens/tela_listagem_racao.dart';
import 'package:viveiro_plus/screens/tela_cadastro_viveiro.dart';
import 'package:viveiro_plus/screens/tela_listagem_viveiros.dart';
import 'package:viveiro_plus/screens/tela_gerenciar_usuarios.dart';
import 'package:viveiro_plus/screens/cadastro_usuarios.dart';
import 'package:viveiro_plus/screens/tela_listagem_bercarios.dart';
import 'package:viveiro_plus/screens/tela_relatorios.dart';
import 'package:viveiro_plus/screens/tela_login.dart';
import '../widgets/degrade_fundo.dart';

class MenuPrincipal extends StatefulWidget {
  const MenuPrincipal({super.key, this.resumoExpandido = false});
  final bool resumoExpandido;

  @override
  State<MenuPrincipal> createState() => _MenuPrincipalState();
}

class _MenuPrincipalState extends State<MenuPrincipal> {
  String? _nomeUsuario;
  String? _funcaoUsuario;
  String _versaoApp = '';

  final Map<String, List<String>> permissoesPorFuncao = {
    'arraçoador': [
      'registro_racao',
      'historico_racao',
      'listar_bercarios',
      'listar_viveiros',
    ],
    'registrador': [
      'analise_agua',
      'registros_analise',
      'listar_bercarios',
      'listar_viveiros',
    ],
    'supervisor': [
      'analise_agua',
      'registros_analise',
      'registro_racao',
      'historico_racao',
      'listar_bercarios',
      'listar_viveiros',
    ],
    'gerente': [
      'analise_agua',
      'registros_analise',
      'registro_racao',
      'historico_racao',
      'listar_bercarios',
      'listar_viveiros',
      'relatorios',
      'editar_viveiro',
      'cadastro_viveiro',
    ],
    'admin': [
      'analise_agua',
      'registros_analise',
      'registro_racao',
      'historico_racao',
      'listar_bercarios',
      'listar_viveiros',
      'relatorios',
      'editar_viveiro',
      'cadastro_viveiro',
      'usuarios',
      'gerenciar_usuarios',
    ],
  };

  bool temPermissao(String chave) {
    if (_funcaoUsuario == null) return false;
    final permissoes = permissoesPorFuncao[_funcaoUsuario!] ?? [];
    return permissoes.contains(chave) || _funcaoUsuario == 'admin';
  }

  @override
  void initState() {
    super.initState();
    _buscarUsuario();
    _carregarVersao();
  }

  Future<void> _buscarUsuario() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          _nomeUsuario = doc.data()?['nome'] ?? 'Usuário';
          _funcaoUsuario = doc.data()?['funcao'] ?? 'registrador';
        });
      }
    }
  }

  Future<void> _carregarVersao() async {
    final info = await PackageInfo.fromPlatform();
    setState(() => _versaoApp = info.version);
  }

  void _deslogar() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const TelaLogin()),
        (_) => false,
      );
    }
  }

  bool get isGerenteOuAdmin => _funcaoUsuario == 'gerente' || _funcaoUsuario == 'admin';
  bool get isSupervisorOuSuperior => _funcaoUsuario == 'supervisor' || isGerenteOuAdmin;

  Widget _buildCard({required IconData icone, required String texto, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.teal.withOpacity(0.3), blurRadius: 10, offset: const Offset(2, 4)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icone, size: 42, color: Colors.teal.shade700),
            const SizedBox(height: 10),
            Text(texto,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _categoria(String titulo) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Text(
        titulo,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
      ),
    );
  }

  List<Widget> _montarGridCategoria(List<Map<String, dynamic>> botoes) {
    return [
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
        children: botoes
            .map((btn) => _buildCard(icone: btn['icone'], texto: btn['texto'], onTap: btn['onTap']))
            .toList(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: Column(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.teal),
              child: Icon(Icons.person, size: 60, color: Colors.white),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Trocar de conta'),
              onTap: _deslogar, // Usando a função já existente para garantir navegação correta
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Versão $_versaoApp', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ),
          ],
        ),
      ),
      body: DegradeFundo(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOut,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color.fromARGB(255, 178, 223, 206),
                          boxShadow: [
                            BoxShadow(
                              color: const Color.fromARGB(255, 77, 182, 138),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/mascote.png',
                            width: 70,
                            height: 70,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _nomeUsuario != null ? 'Olá, $_nomeUsuario' : 'Bem-vindo',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                      ),
                      if (_funcaoUsuario != null)
                        Text('Função: $_funcaoUsuario',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400)),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                if (temPermissao('analise_agua') || temPermissao('registros_analise')) ...[
                  _categoria('Análises de Água'),
                  ..._montarGridCategoria([
                    if (temPermissao('analise_agua'))
                      {
                        'icone': Icons.water,
                        'texto': 'Análise da Água',
                        'onTap': () => Navigator.push(
                            context, MaterialPageRoute(builder: (_) => analise.TelaAnaliseAgua())),
                      },
                    if (temPermissao('registros_analise'))
                      {
                        'icone': Icons.list_alt,
                        'texto': 'Registros de Análise',
                        'onTap': () => Navigator.push(
                            context, MaterialPageRoute(builder: (_) => const TelaListagemRegistros())),
                      },
                  ]),
                ],
                if (temPermissao('registro_racao') || temPermissao('historico_racao')) ...[
                  _categoria('Rações'),
                  ..._montarGridCategoria([
                    if (temPermissao('registro_racao'))
                      {
                        'icone': Icons.restaurant,
                        'texto': 'Registro de Ração',
                        'onTap': () => Navigator.push(
                            context, MaterialPageRoute(builder: (_) => const arracoador.TelaArracoador())),
                      },
                    if (temPermissao('historico_racao'))
                      {
                        'icone': Icons.history,
                        'texto': 'Histórico de Ração',
                        'onTap': () => Navigator.push(
                            context, MaterialPageRoute(builder: (_) => const TelaListagemRacao())),
                      },
                  ]),
                ],
                if (temPermissao('relatorios')) ...[
                  _categoria('Relatórios'),
                  ..._montarGridCategoria([
                    {
                      'icone': Icons.bar_chart,
                      'texto': 'Relatório por Horário',
                      'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TelaRelatorios())),
                    },
                  ]),
                ],
                if (temPermissao('cadastro_viveiro') || temPermissao('editar_viveiro') || temPermissao('listar_viveiros') || temPermissao('listar_bercarios')) ...[
                  _categoria('Viveiros e Berçários'),
                  ..._montarGridCategoria([
                    if (temPermissao('cadastro_viveiro'))
                      {
                        'icone': Icons.add_box,
                        'texto': 'Cadastrar Viveiro',
                        'onTap': () => Navigator.push(
                            context, MaterialPageRoute(builder: (_) => const TelaCadastroViveiro())),
                      },
                    if (temPermissao('listar_viveiros'))
                      {
                        'icone': Icons.view_list,
                        'texto': 'Listar Viveiros',
                        'onTap': () => Navigator.push(
                            context, MaterialPageRoute(builder: (_) => const TelaListagemViveiros())),
                      },
                    if (temPermissao('listar_bercarios'))
                      {
                        'icone': Icons.nature_people,
                        'texto': 'Listar Berçários',
                        'onTap': () => Navigator.push(
                            context, MaterialPageRoute(builder: (_) => const TelaListagemBercarios())),
                      },
                  ]),
                ],
                if (temPermissao('usuarios') || temPermissao('gerenciar_usuarios')) ...[
                  _categoria('Usuários'),
                  ..._montarGridCategoria([
                    if (temPermissao('usuarios'))
                      {
                        'icone': Icons.person_add,
                        'texto': 'Cadastrar Usuário',
                        'onTap': () => Navigator.push(
                            context, MaterialPageRoute(builder: (_) => const CadastroUsuarioScreen())),
                      },
                    if (temPermissao('gerenciar_usuarios'))
                      {
                        'icone': Icons.supervised_user_circle,
                        'texto': 'Gerenciar Usuários',
                        'onTap': () => Navigator.push(
                            context, MaterialPageRoute(builder: (_) => const TelaGerenciarUsuarios())),
                      },
                  ]),
                ],
                // Botão de logout centralizado abaixo dos botões do menu
                const SizedBox(height: 32),
                Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                    label: const Text('Sair', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    ),
                    onPressed: () async {
                      final sair = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Confirmação'),
                          content: const Text('Deseja realmente sair da sua conta?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancelar'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Sair', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                      if (sair == true) _deslogar();
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text('Versão $_versaoApp', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
