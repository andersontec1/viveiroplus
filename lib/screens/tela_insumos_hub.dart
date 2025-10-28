import 'package:flutter/material.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/degrade_fundo.dart';
import 'tela_Insumos.dart';
import 'tela_estoque_insumos.dart';
import 'tela_entrada_insumo.dart';

class TelaInsumosHub extends StatefulWidget {
  const TelaInsumosHub({super.key});

  @override
  State<TelaInsumosHub> createState() => _TelaInsumosHubState();
}

class _TelaInsumosHubState extends State<TelaInsumosHub> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Insumos',
      showAppBar: true,
      body: DegradeFundo(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF045D3A),
                indicatorColor: const Color(0xFF049F56),
                tabs: const [
                  Tab(icon: Icon(Icons.medical_services), text: 'Cadastro'),
                  Tab(icon: Icon(Icons.inventory_2_rounded), text: 'Estoque'),
                  Tab(icon: Icon(Icons.move_to_inbox_rounded), text: 'Entrada'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  // Reusa telas existentes como "subtelas". Elas já têm AppBar;
                  // então preferimos que internamente não mostrem app bar.
                  // Para isso, elas usam AppScaffold; ajustamos showAppBar na origem quando aplicável.
                  // No estado atual, envolvendo com Scaffold simples evita appbar duplicado.
                  _Embed(child: TelaInsumos()),
                  _Embed(child: TelaEstoqueInsumos()),
                  _Embed(child: TelaEntradaInsumo()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Embed extends StatelessWidget {
  const _Embed({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // As telas internas já retornam um Scaffold via AppScaffold. Para evitar barra dupla,
    // podemos simplesmente usar a própria tela; visualmente haverá AppBar interno.
    // Alternativamente, as telas poderiam aceitar um flag para ocultar AppBar.
    return child;
  }
}
