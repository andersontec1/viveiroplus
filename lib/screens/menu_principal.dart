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
import 'package:viveiro_plus/screens/tela_listagem_bercarios.dart';
import 'package:viveiro_plus/screens/cadastro_usuarios.dart';
import 'package:viveiro_plus/screens/tela_relatorios.dart';
import 'package:viveiro_plus/screens/tela_login.dart';
import 'package:viveiro_plus/screens/pendencias.dart';
import 'package:viveiro_plus/screens/tela_ciclos_viveiro.dart';
import 'package:viveiro_plus/screens/tela_resumo_detalhado.dart';
import 'package:viveiro_plus/screens/tela_painel_web.dart';
import 'package:viveiro_plus/screens/tela_Insumos.dart';
import 'package:viveiro_plus/screens/tela_estoque_insumos.dart';
import 'package:viveiro_plus/screens/tela_biomassa.dart';
import '../widgets/degrade_fundo.dart' as degrade_widget;

class MenuPrincipal extends StatefulWidget {
  const MenuPrincipal({super.key, this.resumoExpandido = false});
  final bool resumoExpandido;

  @override
  State<MenuPrincipal> createState() => _MenuPrincipalState();
}

class _MenuPrincipalState extends State<MenuPrincipal> {
  String? _nomeUsuario;
  String? _funcaoUsuario;
  List<String> _permissoes = [];
  String _versaoApp = '';

  // Permissões padrão por função (compatibilidade)
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
    // Se o usuário tem o campo permissoes, usa ele; senão, usa permissoesPorFuncao herdadas da funcao
    if (_permissoes.isNotEmpty) {
      return _permissoes.contains(chave);
    } else if (_funcaoUsuario != null) {
      final permissoesFuncao = permissoesPorFuncao[_funcaoUsuario!] ?? [];
      return permissoesFuncao.contains(chave) || _funcaoUsuario == 'admin';
    }
    return false;
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
        final data = doc.data() ?? {};
        setState(() {
          _nomeUsuario = data['nome'] ?? 'Usuário';
          _funcaoUsuario = data['funcao'] ?? 'registrador';
          final permissoesFirestore = data['permissoes'];
          if (permissoesFirestore is List) {
            _permissoes = permissoesFirestore.map((e) => e.toString()).toList();
          } else {
            _permissoes = [];
          }
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

  Widget _buildCard({required String texto, required VoidCallback onTap, IconData? icone, String? customIcon}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.9),
                Colors.white.withOpacity(0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF049F56).withOpacity(0.15),
                blurRadius: 15,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.8),
                blurRadius: 8,
                spreadRadius: -5,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (customIcon != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF049F56).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Image.asset(
                    customIcon, 
                    width: 40, 
                    height: 40,
                    color: const Color(0xFF049F56),
                  ),
                )
              else if (icone != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF049F56).withOpacity(0.2),
                        const Color(0xFF045D3A).withOpacity(0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icone, 
                    size: 32, 
                    color: const Color(0xFF045D3A),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                texto,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF045D3A),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper para montar uma categoria expansível com ícone
  Widget _categoriaExpansivel(String titulo, List<Widget> conteudo, {bool inicialmenteAberto = false, IconData? icone}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.6),
          width: 1,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          expansionTileTheme: ExpansionTileThemeData(
            backgroundColor: Colors.transparent,
            collapsedBackgroundColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            collapsedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        child: ExpansionTile(
          leading: icone != null 
              ? Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF049F56).withOpacity(0.2),
                        const Color(0xFF045D3A).withOpacity(0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icone, 
                    color: const Color(0xFF045D3A), 
                    size: 24,
                  ),
                )
              : null,
          title: Text(
            titulo, 
            style: const TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.bold, 
              color: Color(0xFF045D3A),
              letterSpacing: 0.5,
            ),
          ),
          initiallyExpanded: inicialmenteAberto,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: const Color(0xFF049F56),
          collapsedIconColor: const Color(0xFF045D3A),
          children: conteudo,
        ),
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
        children: botoes.map((btn) => _buildCard(
          icone: btn.containsKey('icone') ? btn['icone'] as IconData? : null,
          customIcon: btn.containsKey('customIcon') ? btn['customIcon'] as String? : null,
          texto: btn['texto'] as String,
          onTap: btn['onTap'] as VoidCallback,
        )).toList(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> categorias = [];
    if (temPermissao('analise_agua') || temPermissao('registros_analise')) {
      categorias.add(_categoriaExpansivel(
        'Análises de Água',
        _montarGridCategoria([
          if (temPermissao('analise_agua'))
            {
              'icone': Icons.water,
              'texto': 'Análise da Água',
              'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const analise.TelaAnaliseAgua())),
            },
          if (temPermissao('registros_analise'))
            {
              'icone': Icons.list_alt,
              'texto': 'Registros de Análise',
              'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TelaListagemRegistros())),
            },
        ]),
        inicialmenteAberto: true,
        icone: Icons.water_drop,
      ));
    }
    if (temPermissao('registro_racao') || temPermissao('historico_racao')) {
      categorias.add(_categoriaExpansivel(
        'Rações',
        _montarGridCategoria([
          if (temPermissao('registro_racao'))
            {
              'icone': Icons.set_meal,
              'texto': 'Registro de Ração',
              'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const arracoador.TelaArracoador())),
            },
          if (temPermissao('historico_racao'))
            {
              'icone': Icons.history,
              'texto': 'Histórico de Ração',
              'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TelaListagemRacao())),
            },
        ]),
        icone: Icons.set_meal,
      ));
    }
    if (temPermissao('relatorios')) {
      categorias.add(_categoriaExpansivel(
        'Insumos e Suprimentos',
        _montarGridCategoria([
          {
            'icone': Icons.medical_services,
            'texto': 'Cadastro de Insumos',
            'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TelaInsumos())),
          },
          {
            'icone': Icons.inventory_2_rounded,
            'texto': 'Estoque de Insumos',
            'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TelaEstoqueInsumos())),
          },
        ]),
        icone: Icons.medical_services,
      ));
    }
    if (temPermissao('listar_viveiros')) {
      categorias.add(_categoriaExpansivel(
        'Gestão de Ciclos',
        _montarGridCategoria([
          {
            'icone': Icons.history_toggle_off,
            'texto': 'Ciclos por Viveiro',
            'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TelaCiclosViveiro())),
          },
          {
            'icone': Icons.monitor_weight,
            'texto': 'Cálculo de Biomassa',
            'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TelaBiomassa())),
          },
        ]),
        icone: Icons.history_toggle_off,
      ));
    }
    if (temPermissao('cadastro_viveiro') || temPermissao('editar_viveiro') || temPermissao('listar_viveiros') || temPermissao('listar_bercarios')) {
      categorias.add(_categoriaExpansivel(
        'Viveiros e Berçários',
        _montarGridCategoria([
          if (temPermissao('cadastro_viveiro'))
            {
              'icone': Icons.add_box,
              'texto': 'Cadastrar Viveiro',
              'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TelaCadastroViveiro())),
            },
          if (temPermissao('listar_viveiros'))
            {
              'icone': Icons.view_list,
              'texto': 'Listar Viveiros',
              'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => TelaListagemViveiros(funcaoUsuario: _funcaoUsuario))),
            },
          if (temPermissao('listar_bercarios'))
            {
              'icone': null,
              'texto': 'Listar Berçários',
              'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TelaListagemBercarios())),
              'customIcon': 'assets/images/camaraoico.png',
            },
        ]),
        icone: Icons.eco,
      ));
    }
    if (temPermissao('usuarios') || temPermissao('gerenciar_usuarios')) {
      categorias.add(_categoriaExpansivel(
        'Usuários',
        _montarGridCategoria([
          if (temPermissao('usuarios'))
            {
              'icone': Icons.person_add,
              'texto': 'Cadastrar Usuário',
              'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CadastroUsuarioScreen())),
            },
          if (temPermissao('gerenciar_usuarios'))
            {
              'icone': Icons.supervised_user_circle,
              'texto': 'Gerenciar Usuários',
              'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TelaGerenciarUsuarios())),
            },
        ]),
        icone: Icons.people,
      ));
    }
    // Relatórios sempre por último
    if (temPermissao('relatorios')) {
      categorias.add(_categoriaExpansivel(
        'Relatórios',
        _montarGridCategoria([
          {
            'icone': Icons.bar_chart,
            'texto': 'Relatório por Horário',
            'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TelaRelatorios())),
          },
          {
            'icone': Icons.summarize,
            'texto': 'Resumo Diário',
            'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TelaResumoDetalhado())),
          },
          {
            'icone': Icons.warning_amber_rounded,
            'texto': 'Pendências',
            'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TelaPendencias())),
          },          
          {
            'icone': Icons.dashboard_customize,
            'texto': 'Painel Web',
            'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TelaPainelWeb())),
          },
        ]),
        icone: Icons.bar_chart,
      ));
    }
    return Scaffold(
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF049F56),
                    const Color(0xFF045D3A),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/mascote.png',
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _nomeUsuario ?? 'Usuário',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_funcaoUsuario != null)
                    Text(
                      _funcaoUsuario![0].toUpperCase() + _funcaoUsuario!.substring(1),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.logout_rounded,
                  color: Colors.red.shade400,
                  size: 20,
                ),
              ),
              title: const Text(
                'Trocar de conta',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF045D3A),
                ),
              ),
              onTap: _deslogar,
            ),
            const Spacer(),
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Versão $_versaoApp',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: degrade_widget.DegradeFundo(
        child: SafeArea(
          child: DefaultTextStyle.merge(
            style: const TextStyle(fontWeight: FontWeight.bold),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Column(
                            children: [
                              // Container moderno para o avatar
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFF049F56),
                                      const Color(0xFF045D3A),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF049F56).withOpacity(0.4),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: ClipOval(
                                    child: Image.asset(
                                      'assets/images/mascote.png',
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Card de boas-vindas
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withOpacity(0.9),
                                      Colors.white.withOpacity(0.7),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.5),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 15,
                                      spreadRadius: 2,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      _nomeUsuario != null ? 'Olá, $_nomeUsuario! 👋' : 'Bem-vindo! 👋',
                                      style: const TextStyle(
                                        fontSize: 22, 
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF045D3A),
                                        letterSpacing: 0.5,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    if (_funcaoUsuario != null) ...[
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              const Color(0xFF049F56).withOpacity(0.2),
                                              const Color(0xFF045D3A).withOpacity(0.1),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          '${_funcaoUsuario![0].toUpperCase()}${_funcaoUsuario!.substring(1)}',
                                          style: const TextStyle(
                                            fontSize: 14, 
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF045D3A),
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                        ...categorias,
                        // Botão de logout modernizado
                        const SizedBox(height: 32),
                        Center(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.2),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                              label: const Text(
                                'Sair da Conta', 
                                style: TextStyle(
                                  color: Colors.white, 
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade400,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              ),
                              onPressed: () async {
                                final sair = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    title: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade100,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            Icons.help_outline_rounded,
                                            color: Colors.orange.shade600,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        const Text(
                                          'Confirmação',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF045D3A),
                                          ),
                                        ),
                                      ],
                                    ),
                                    content: const Text(
                                      'Deseja realmente sair da sua conta?',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Color(0xFF045D3A),
                                        height: 1.4,
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                        ),
                                        child: const Text(
                                          'Cancelar',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red.shade400,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                        ),
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text(
                                          'Sair', 
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                if (sair == true) _deslogar();
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Badge de versão modernizado
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.5),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: const Color(0xFF045D3A).withOpacity(0.6),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Versão $_versaoApp',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: const Color(0xFF045D3A).withOpacity(0.7),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
