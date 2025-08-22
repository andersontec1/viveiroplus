import 'package:flutter/material.dart';

// Menu estilo dashboard com cards horizontais
class MenuDashboard extends StatelessWidget {
  const MenuDashboard({super.key});

  Widget _buildDashboardCard({
    required String titulo,
    required String subtitulo,
    required String valor,
    required IconData icone,
    required Color color,
    required VoidCallback onTap,
    bool isLarge = false,
  }) {
    return Container(
      height: isLarge ? 120 : 100,
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withOpacity(0.9),
                  color,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                // Informações
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        titulo,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitulo,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      if (isLarge) ...[
                        const SizedBox(height: 8),
                        Text(
                          valor,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Ícone e valor
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        icone,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    if (!isLarge) ...[
                      const SizedBox(height: 8),
                      Text(
                        valor,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAccessTile({
    required String titulo,
    required String descricao,
    required IconData icone,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icone, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Color(0xFF045D3A),
                        ),
                      ),
                      Text(
                        descricao,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
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
          // AppBar com gradiente
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF049F56),
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Dashboard',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF049F56),
                      Color(0xFF045D3A),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {},
              ),
            ],
          ),
          
          // Conteúdo
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Cards principais
                _buildDashboardCard(
                  titulo: 'Análises de Água',
                  subtitulo: 'Registros e monitoramento',
                  valor: '24',
                  icone: Icons.water_drop,
                  color: Colors.blue,
                  onTap: () {},
                  isLarge: true,
                ),
                
                _buildDashboardCard(
                  titulo: 'Controle de Ração',
                  subtitulo: 'Alimentação dos viveiros',
                  valor: '8',
                  icone: Icons.set_meal,
                  color: Colors.orange,
                  onTap: () {},
                ),
                
                _buildDashboardCard(
                  titulo: 'Viveiros Ativos',
                  subtitulo: 'Em produção',
                  valor: '12',
                  icone: Icons.water,
                  color: Colors.teal,
                  onTap: () {},
                ),
                
                const SizedBox(height: 24),
                
                // Seção de acesso rápido
                Row(
                  children: [
                    const Text(
                      'Acesso Rápido',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF045D3A),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {},
                      child: const Text('Ver todos'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Lista de acesso rápido
                _buildQuickAccessTile(
                  titulo: 'Insumos e Estoque',
                  descricao: 'Controlar materiais e suprimentos',
                  icone: Icons.inventory,
                  color: Colors.purple,
                  onTap: () {},
                ),
                
                _buildQuickAccessTile(
                  titulo: 'Gestão de Ciclos',
                  descricao: 'Biomassa, despesca e histórico',
                  icone: Icons.history_toggle_off,
                  color: Colors.green,
                  onTap: () {},
                ),
                
                _buildQuickAccessTile(
                  titulo: 'Gerenciar Usuários',
                  descricao: 'Equipe e permissões',
                  icone: Icons.people,
                  color: Colors.indigo,
                  onTap: () {},
                ),
                
                _buildQuickAccessTile(
                  titulo: 'Relatórios e Análises',
                  descricao: 'Dados e métricas detalhadas',
                  icone: Icons.bar_chart,
                  color: Colors.red,
                  onTap: () {},
                ),
                
                _buildQuickAccessTile(
                  titulo: 'Painel Web',
                  descricao: 'Dashboard completo do sistema',
                  icone: Icons.dashboard,
                  color: Colors.pink,
                  onTap: () {},
                ),
                
                const SizedBox(height: 20),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
