import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import removido pois não é utilizado diretamente nesta tela

// Exemplo de menu em lista vertical moderna
class MenuListaVertical extends StatefulWidget {
  const MenuListaVertical({super.key, this.resumoExpandido = false});
  final bool resumoExpandido;

  @override
  State<MenuListaVertical> createState() => _MenuListaVerticalState();
}

class _MenuListaVerticalState extends State<MenuListaVertical> {
  String? _nomeUsuario;
  // Removidos campos não utilizados para evitar lints de "unused field"

  @override
  void initState() {
    super.initState();
    _buscarUsuario();
  }

  Future<void> _buscarUsuario() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        setState(() {
          _nomeUsuario = data['nome'] ?? 'Usuário';
          // Campos de função/permissões removidos por não serem utilizados nesta tela
        });
      }
    }
  }

  // Lista de opções do menu em formato de cards horizontais
  Widget _buildListTile({
    required String titulo,
    required String subtitulo,
    required IconData icone,
    required VoidCallback onTap,
    Color? iconColor,
    bool isHighlighted = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        gradient: isHighlighted
            ? LinearGradient(
                colors: [
                  const Color(0xFF049F56).withOpacity(0.1),
                  const Color(0xFF045D3A).withOpacity(0.05),
                ],
              )
            : LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.9),
                  Colors.white.withOpacity(0.7),
                ],
              ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Container do ícone
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        iconColor ?? const Color(0xFF049F56),
                        (iconColor ?? const Color(0xFF049F56)).withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: (iconColor ?? const Color(0xFF049F56))
                            .withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(icone, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),

                // Texto
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF045D3A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitulo,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),

                // Seta
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          // AppBar moderno
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF049F56),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Olá, ${_nomeUsuario ?? "Usuário"}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF049F56), Color(0xFF045D3A)],
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.waves, size: 80, color: Colors.white24),
                ),
              ),
            ),
          ),

          // Lista de opções
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  // Análises de Água
                  _buildListTile(
                    titulo: 'Análises de Água',
                    subtitulo: 'Registrar e visualizar análises dos viveiros',
                    icone: Icons.water_drop,
                    iconColor: Colors.blue,
                    onTap: () {}, // Navegação aqui
                    isHighlighted: true,
                  ),

                  // Ração
                  _buildListTile(
                    titulo: 'Controle de Ração',
                    subtitulo: 'Gerenciar alimentação dos camarões',
                    icone: Icons.set_meal,
                    iconColor: Colors.orange,
                    onTap: () {},
                  ),

                  // Viveiros
                  _buildListTile(
                    titulo: 'Viveiros e Berçários',
                    subtitulo: 'Administrar tanques e cultivos',
                    icone: Icons.water,
                    iconColor: Colors.teal,
                    onTap: () {},
                  ),

                  // Insumos
                  _buildListTile(
                    titulo: 'Insumos e Estoque',
                    subtitulo: 'Controlar materiais e suprimentos',
                    icone: Icons.inventory,
                    iconColor: Colors.purple,
                    onTap: () {},
                  ),

                  // Ciclos
                  _buildListTile(
                    titulo: 'Gestão de Ciclos',
                    subtitulo: 'Acompanhar biomassa e despesca',
                    icone: Icons.history_toggle_off,
                    iconColor: Colors.green,
                    onTap: () {},
                  ),

                  // Usuários
                  _buildListTile(
                    titulo: 'Gerenciar Usuários',
                    subtitulo: 'Administrar equipe e permissões',
                    icone: Icons.people,
                    iconColor: Colors.indigo,
                    onTap: () {},
                  ),

                  // Relatórios
                  _buildListTile(
                    titulo: 'Relatórios e Análises',
                    subtitulo: 'Visualizar dados e métricas',
                    icone: Icons.bar_chart,
                    iconColor: Colors.red,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
