import 'package:flutter/material.dart';
import 'dart:math' as math;

// Menu com Floating Action expandível
class MenuFloatingAction extends StatefulWidget {
  const MenuFloatingAction({super.key});

  @override
  State<MenuFloatingAction> createState() => _MenuFloatingActionState();
}

class _MenuFloatingActionState extends State<MenuFloatingAction>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
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
      ),
      body: Stack(
        children: [
          // Conteúdo principal da tela
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cards de resumo
                _buildSummaryCard(),
                const SizedBox(height: 20),
                
                // Atividades recentes
                const Text(
                  'Atividades Recentes',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF045D3A),
                  ),
                ),
                const SizedBox(height: 16),
                
                _buildActivityTile(
                  'Análise de água - Viveiro 01',
                  '2 horas atrás',
                  Icons.water_drop,
                  Colors.blue,
                ),
                _buildActivityTile(
                  'Ração aplicada - Berçário 03',
                  '4 horas atrás',
                  Icons.set_meal,
                  Colors.orange,
                ),
                _buildActivityTile(
                  'Biomassa calculada - Viveiro 05',
                  '1 dia atrás',
                  Icons.monitor_weight,
                  Colors.green,
                ),
                
                const SizedBox(height: 100), // Espaço para o FAB
              ],
            ),
          ),
          
          // Overlay escuro quando menu está aberto
          if (_isOpen)
            GestureDetector(
              onTap: _toggle,
              child: AnimatedOpacity(
                opacity: _animation.value * 0.7,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  color: Colors.black,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
          
          // Botões do menu circular
          ..._buildMenuButtons(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _toggle,
        backgroundColor: const Color(0xFF049F56),
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Transform.rotate(
              angle: _animation.value * math.pi * 0.25, // 45 graus
              child: Icon(
                _isOpen ? Icons.close : Icons.add,
                color: Colors.white,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF049F56),
            Color(0xFF045D3A),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF049F56).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Status Geral',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem('Viveiros', '12', Icons.water),
              _buildSummaryItem('Análises', '24', Icons.science),
              _buildSummaryItem('Pendências', '3', Icons.warning),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildActivityTile(String titulo, String tempo, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
                    fontSize: 14,
                  ),
                ),
                Text(
                  tempo,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMenuButtons() {
    final buttons = [
      _FloatingButton(
        icon: Icons.water_drop,
        label: 'Análise',
        color: Colors.blue,
        onPressed: () {},
      ),
      _FloatingButton(
        icon: Icons.set_meal,
        label: 'Ração',
        color: Colors.orange,
        onPressed: () {},
      ),
      _FloatingButton(
        icon: Icons.water,
        label: 'Viveiros',
        color: Colors.teal,
        onPressed: () {},
      ),
      _FloatingButton(
        icon: Icons.inventory,
        label: 'Estoque',
        color: Colors.purple,
        onPressed: () {},
      ),
      _FloatingButton(
        icon: Icons.people,
        label: 'Usuários',
        color: Colors.indigo,
        onPressed: () {},
      ),
      _FloatingButton(
        icon: Icons.bar_chart,
        label: 'Relatórios',
        color: Colors.red,
        onPressed: () {},
      ),
    ];

    return buttons.asMap().entries.map((entry) {
      final index = entry.key;
      final button = entry.value;
      
      // Cálculo da posição circular
      final angle = (index * 60.0) * (math.pi / 180.0); // 60 graus entre cada botão
      final radius = 120.0;
      final x = math.cos(angle - math.pi / 2) * radius;
      final y = math.sin(angle - math.pi / 2) * radius;

      return AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Positioned(
            right: 16 - (x * _animation.value),
            bottom: 16 - (y * _animation.value),
            child: Transform.scale(
              scale: _animation.value,
              child: Opacity(
                opacity: _animation.value,
                child: button,
              ),
            ),
          );
        },
      );
    }).toList();
  }
}

class _FloatingButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _FloatingButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: label,
          onPressed: onPressed,
          backgroundColor: color,
          mini: true,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
