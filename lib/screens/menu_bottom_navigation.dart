import 'package:flutter/material.dart';

// Menu com bottom navigation e quick actions
class MenuBottomNavigation extends StatefulWidget {
  const MenuBottomNavigation({super.key});

  @override
  State<MenuBottomNavigation> createState() => _MenuBottomNavigationState();
}

class _MenuBottomNavigationState extends State<MenuBottomNavigation> {
  int _currentIndex = 0;
  
  final List<Widget> _pages = [
    const _HomeTab(),
    const _AnaliseTab(),
    const _RacaoTab(),
    const _RelatoriosTab(),
    const _ConfigTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF049F56),
              Color(0xFF045D3A),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white60,
          selectedFontSize: 12,
          unselectedFontSize: 10,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Início',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.water_drop),
              label: 'Análise',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.set_meal),
              label: 'Ração',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart),
              label: 'Relatórios',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Config',
            ),
          ],
        ),
      ),
    );
  }
}

// Tab principal com quick actions
class _HomeTab extends StatelessWidget {
  const _HomeTab();

  Widget _buildQuickAction({
    required String titulo,
    required IconData icone,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 80,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.8),
                  color,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icone, color: Colors.white, size: 28),
                const SizedBox(height: 4),
                Text(
                  titulo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
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
      appBar: AppBar(
        title: const Text('Viveiro Plus'),
        backgroundColor: const Color(0xFF049F56),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick Actions
            const Text(
              'Ações Rápidas',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF045D3A),
              ),
            ),
            const SizedBox(height: 16),
            
            // Primeira linha de ações
            Row(
              children: [
                _buildQuickAction(
                  titulo: 'Nova\nAnálise',
                  icone: Icons.add_circle,
                  color: Colors.blue,
                  onTap: () {},
                ),
                _buildQuickAction(
                  titulo: 'Registrar\nRação',
                  icone: Icons.restaurant,
                  color: Colors.orange,
                  onTap: () {},
                ),
                _buildQuickAction(
                  titulo: 'Ver\nViveiros',
                  icone: Icons.water,
                  color: Colors.teal,
                  onTap: () {},
                ),
                _buildQuickAction(
                  titulo: 'Estoque',
                  icone: Icons.inventory,
                  color: Colors.purple,
                  onTap: () {},
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Status Cards
            const Text(
              'Status Geral',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF045D3A),
              ),
            ),
            const SizedBox(height: 16),
            
            // Cards de status
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.9),
                    Colors.white.withOpacity(0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatusItem('Viveiros Ativos', '12', Icons.water, Colors.blue),
                      _buildStatusItem('Análises Hoje', '8', Icons.science, Colors.green),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatusItem('Pendências', '3', Icons.warning, Colors.orange),
                      _buildStatusItem('Última Ração', '2h', Icons.schedule, Colors.purple),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Menu completo em lista
            const Text(
              'Menu Completo',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF045D3A),
              ),
            ),
            const SizedBox(height: 16),
            
            _buildMenuTile(
              'Gestão de Ciclos',
              'Biomassa, despesca e histórico',
              Icons.history_toggle_off,
              Colors.green,
              () {},
            ),
            _buildMenuTile(
              'Gerenciar Usuários',
              'Equipe e permissões',
              Icons.people,
              Colors.indigo,
              () {},
            ),
            _buildMenuTile(
              'Painel Web',
              'Dashboard completo',
              Icons.dashboard,
              Colors.red,
              () {},
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatusItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
  
  Widget _buildMenuTile(String titulo, String subtitulo, IconData icon, Color color, VoidCallback onTap) {
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
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
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
                        ),
                      ),
                      Text(
                        subtitulo,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Tabs simples para as outras abas
class _AnaliseTab extends StatelessWidget {
  const _AnaliseTab();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Tab Análise')),
    );
  }
}

class _RacaoTab extends StatelessWidget {
  const _RacaoTab();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Tab Ração')),
    );
  }
}

class _RelatoriosTab extends StatelessWidget {
  const _RelatoriosTab();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Tab Relatórios')),
    );
  }
}

class _ConfigTab extends StatelessWidget {
  const _ConfigTab();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Tab Configurações')),
    );
  }
}
