// Tela Ciclos por Viveiro - com edição e histórico
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/degrade_fundo.dart';
import 'tela_detalhes_ciclo.dart';
import 'tela_novo_ciclo.dart';
import 'tela_despesca.dart';

class TelaCiclosViveiro extends StatefulWidget {
  const TelaCiclosViveiro({super.key});

  @override
  State<TelaCiclosViveiro> createState() => _TelaCiclosViveiroState();
}

class _StatusTabOption {
  const _StatusTabOption({
    required this.value,
    required this.label,
    required this.subtitle,
    required this.icon,
  });

  final int value;
  final String label;
  final String subtitle;
  final IconData icon;
}

class _TelaCiclosViveiroState extends State<TelaCiclosViveiro> {
  // Estilos reutilizáveis
  static const _corPrimariaEscura = Color(0xFF045D3A);
  static const _corPrimaria = Color(0xFF049F56);

  // Campos de formulário antigos removidos do fluxo principal
  Map<String, String> _destinos = {};
  int _mostrarApenasAbertos = 1; // 1: em andamento, 2: encerrados
  DateTime? _previsaoEncerramento;
  final TextEditingController _buscaCtrl = TextEditingController();
  String _buscaTermo = '';

  // Filtros de busca
  String? _tipoFiltro; // 'viveiro', 'bercario' ou null (todos)
  String? _codigoFiltro; // código específico ou null (todos)

  @override
  void initState() {
    super.initState();
    _carregarDestinos();
    _verificarConectividadeFirestore();
  }

  Widget _buildListaVazia() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.water_damage_outlined,
            size: 56,
            color: const Color(0xFF049F56).withValues(alpha: 0.7),
          ),
          const SizedBox(height: 12),
          const Text(
            'Nenhum ciclo encontrado',
            style: TextStyle(
              color: Color(0xFF045D3A),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _getBuildEmptyMessage(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF045D3A).withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag({
    required String label,
    required Color color,
    bool subtle = false,
  }) {
    final background = subtle ? color.withValues(alpha: 0.08) : color;
    final textColor = subtle ? color : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: subtle ? background : background.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool encerrado) {
    final color = encerrado ? Colors.grey : const Color(0xFF049F56);
    final label = encerrado ? 'Encerrado' : 'Em andamento';
    final icon = encerrado ? Icons.lock_outline : Icons.autorenew;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusToggle() {
    const List<_StatusTabOption> tabs = [
      _StatusTabOption(
        value: 1,
        label: 'Em andamento',
        subtitle: 'Ciclos ativos',
        icon: Icons.autorenew,
      ),
      _StatusTabOption(
        value: 2,
        label: 'Histórico',
        subtitle: 'Ciclos encerrados',
        icon: Icons.history_toggle_off,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final showSubtitle = constraints.maxWidth > 420;
        final selectedIndex = tabs.indexWhere(
          (tab) => tab.value == _mostrarApenasAbertos,
        );
        final clampedIndex = selectedIndex >= 0 ? selectedIndex : 0;
        final alignmentX = tabs.length == 1
            ? 0.0
            : -1 + (2 * clampedIndex / (tabs.length - 1));

        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Stack(
            children: [
              AnimatedAlign(
                alignment: Alignment(alignmentX, 0),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                child: FractionallySizedBox(
                  widthFactor: 1 / tabs.length,
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFDDF8EC), Color(0xFFBCEBD9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF7BC9A4,
                          ).withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                children: tabs.map((tab) {
                  final selected = tab.value == _mostrarApenasAbertos;
                  const activeTextColor = Color(0xFF06412B);
                  const inactiveTextColor = Color(0xFF355849);
                  const subtitleInactiveColor = Color(0xFF6D8076);
                  final subtitleColor = selected
                      ? activeTextColor.withValues(alpha: 0.85)
                      : subtitleInactiveColor;
                  return Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: selected
                            ? null
                            : () => setState(
                                () => _mostrarApenasAbertos = tab.value,
                              ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOutCubic,
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? Colors.white.withValues(alpha: 0.25)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  tab.icon,
                                  size: 18,
                                  color: selected
                                      ? activeTextColor
                                      : inactiveTextColor,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AnimatedDefaultTextStyle(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      curve: Curves.easeOutCubic,
                                      style: TextStyle(
                                        color: selected
                                            ? activeTextColor
                                            : inactiveTextColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      child: Text(tab.label),
                                    ),
                                    if (showSubtitle)
                                      AnimatedOpacity(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        opacity: selected ? 0.9 : 0.7,
                                        child: Text(
                                          tab.subtitle,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: subtitleColor,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickStat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF049F56)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF045D3A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF049F56)),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Color(0xFF045D3A)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutlinedAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }

  Future<void> _verificarConectividadeFirestore() async {
    try {
      print('Debug: Testando conectividade com Firestore...');
      final testDoc = await FirebaseFirestore.instance
          .collection('ciclos')
          .limit(1)
          .get();
      print(
        'Debug: Conectividade OK! Encontrados ${testDoc.docs.length} documentos',
      );

      // Teste de listagem de todas as coleções (se possível)
      final todasColecoes = await FirebaseFirestore.instance
          .collection('ciclos')
          .get();
      print(
        'Debug: Total de documentos na coleção ciclos: ${todasColecoes.docs.length}',
      );

      for (var doc in todasColecoes.docs) {
        print('Debug: Doc ID: ${doc.id}, Dados: ${doc.data()}');
      }
    } catch (e) {
      print('Debug: Erro de conectividade com Firestore: $e');
    }
  }

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }

  String _formatarData(DateTime dt) => DateFormat('dd/MM/yyyy').format(dt);
  String _formatarMilhares(num? n) =>
      NumberFormat.decimalPattern('pt_BR').format((n ?? 0).toInt());
  String _formatarDecimal(num? n, {int casas = 1}) {
    final formatador = NumberFormat.decimalPattern('pt_BR')
      ..minimumFractionDigits = casas
      ..maximumFractionDigits = casas;
    return formatador.format((n ?? 0).toDouble());
  }

  List<DropdownMenuItem<String>> _buildCodigoDropdownItems() {
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: null, child: Text('Todos')),
    ];

    // Filtrar códigos baseado no tipo selecionado
    final codigosFiltrados = <String, String>{};

    if (_tipoFiltro == null) {
      // Mostrar todos se não há filtro de tipo
      codigosFiltrados.addAll(_destinos);
    } else {
      // Filtrar por tipo
      final prefixo = _tipoFiltro == 'viveiro' ? 'V-' : 'B-';
      for (final entry in _destinos.entries) {
        if (entry.key.startsWith(prefixo)) {
          codigosFiltrados[entry.key] = entry.value;
        }
      }
    }

    // Ordenar e adicionar aos items
    final sortedEntries = codigosFiltrados.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    for (final entry in sortedEntries) {
      items.add(DropdownMenuItem(value: entry.key, child: Text(entry.value)));
    }

    return items;
  }

  String _getBuildEmptyMessage() {
    if (_tipoFiltro != null || _codigoFiltro != null) {
      return 'Nenhum ciclo encontrado com os filtros aplicados';
    }

    if (_mostrarApenasAbertos == 1) {
      return 'Nenhum ciclo ativo encontrado';
    } else if (_mostrarApenasAbertos == 2) {
      return 'Nenhum ciclo encerrado encontrado';
    }

    return 'Crie um novo ciclo para começar';
  }

  String _getActiveFiltersText() {
    final filters = <String>[];

    if (_tipoFiltro != null) {
      filters.add(_tipoFiltro == 'viveiro' ? 'Viveiros' : 'Berçários');
    }

    if (_codigoFiltro != null) {
      final nome =
          _destinos[_codigoFiltro]
              ?.replaceAll(RegExp(r'🐟|🦐|\s*\(.*\)'), '')
              .trim() ??
          _codigoFiltro!;
      filters.add(nome);
    }

    if (_buscaTermo.isNotEmpty) {
      filters.add('Busca "$_buscaTermo"');
    }

    return filters.join(', ');
  }

  Widget _buildCicloCard(QueryDocumentSnapshot ciclo) {
    final dataMap = (ciclo.data() as Map<String, dynamic>?) ?? {};
    final DateTime data =
        (dataMap['dataInicio'] as Timestamp?)?.toDate() ?? DateTime.now();
    final bool encerrado = dataMap['encerrado'] == true;
    final DateTime? dataEncerramento =
        (dataMap['dataEncerramento'] as Timestamp?)?.toDate();
    final DateTime? previsaoEncerramento =
        (dataMap['previsaoEncerramento'] as Timestamp?)?.toDate();
    final String abertoPor = (dataMap['abertoPor'] ?? '—').toString();
    final String fechadoPor = (dataMap['fechadoPor'] ?? '').toString();
    final num? pesoFinal = (dataMap['pesoFinal'] as num?);
    final num pesoInicial = (dataMap['pesoInicial'] as num?) ?? 0;
    final String tipoLocal = (dataMap['tipo'] as String?) ?? 'viveiro';
    final String nomeLocal = (dataMap['nome'] ?? '—').toString();
    final String codigoLocal = (dataMap['codigo'] ?? '').toString();

    final int duracaoDias = (encerrado && dataEncerramento != null)
        ? dataEncerramento.difference(data).inDays
        : DateTime.now().difference(data).inDays;
    final num? ganhoPeso = (encerrado && pesoFinal != null && pesoInicial > 0)
        ? (pesoFinal - pesoInicial)
        : null;

    final typeColor = tipoLocal == 'viveiro'
        ? const Color(0xFF1E88E5)
        : Colors.deepOrange;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 1.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
          final resultado = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  TelaDetalhesCiclo(cicloId: ciclo.id, dadosCiclo: dataMap),
            ),
          );
          if (resultado == true) setState(() {});
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: typeColor.withValues(alpha: 0.15),
                    child: Icon(
                      tipoLocal == 'viveiro'
                          ? Icons.water_damage_outlined
                          : Icons.grass,
                      color: typeColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nomeLocal,
                          style: const TextStyle(
                            color: Color(0xFF045D3A),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _buildTag(
                              label: tipoLocal == 'viveiro'
                                  ? '🐟 Viveiro'
                                  : '🦐 Berçário',
                              color: typeColor,
                            ),
                            _buildTag(
                              label: 'Código: $codigoLocal',
                              color: const Color(0xFF045D3A),
                              subtle: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildStatusBadge(encerrado),
                      const SizedBox(height: 8),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stats = <Widget>[
                    _buildQuickStat(
                      icon: Icons.calendar_month,
                      label: 'Início',
                      value: _formatarData(data),
                    ),
                  ];

                  if (previsaoEncerramento != null) {
                    stats.add(
                      _buildQuickStat(
                        icon: Icons.flag_outlined,
                        label: 'Previsão',
                        value: _formatarData(previsaoEncerramento),
                      ),
                    );
                  }

                  if (encerrado && dataEncerramento != null) {
                    stats.add(
                      _buildQuickStat(
                        icon: Icons.lock_clock,
                        label: 'Encerrado',
                        value: _formatarData(dataEncerramento),
                      ),
                    );
                  }

                  stats.addAll([
                    _buildQuickStat(
                      icon: Icons.inventory_2_outlined,
                      label: 'Estocados',
                      value:
                          '${_formatarMilhares(dataMap['quantidadeEstocada'] as num?)} pós-larvas',
                    ),
                    _buildQuickStat(
                      icon: Icons.timelapse,
                      label: 'Duração',
                      value: '$duracaoDias dias',
                    ),
                  ]);

                  if (dataMap['plDia'] != null) {
                    stats.add(
                      _buildQuickStat(
                        icon: Icons.insights_outlined,
                        label: 'PL / Dia',
                        value: dataMap['plDia'].toString().replaceAll('.', ','),
                      ),
                    );
                  }

                  if (dataMap['plGrama'] != null &&
                      dataMap['tipo'] == 'bercario') {
                    stats.add(
                      _buildQuickStat(
                        icon: Icons.scale_outlined,
                        label: 'PL / g',
                        value: dataMap['plGrama'].toString().replaceAll(
                          '.',
                          ',',
                        ),
                      ),
                    );
                  }

                  if (ganhoPeso != null) {
                    stats.add(
                      _buildQuickStat(
                        icon: Icons.trending_up,
                        label: 'Ganho médio',
                        value: '${ganhoPeso.toString().replaceAll('.', ',')} g',
                      ),
                    );
                  }

                  final availableWidth = constraints.maxWidth;
                  final double chipMaxWidth = availableWidth >= 560
                      ? (availableWidth - 12) / 2
                      : availableWidth;

                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: stats
                        .map(
                          (stat) => ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: chipMaxWidth),
                            child: stat,
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 16),
              _buildDespescaResumo(
                cicloId: ciclo.id,
                codigoLocal: codigoLocal,
                nomeLocal: nomeLocal,
                encerrado: encerrado,
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMetaRow(
                      icon: Icons.badge_outlined,
                      label: 'Aberto por',
                      value: abertoPor,
                    ),
                    if (fechadoPor.isNotEmpty)
                      _buildMetaRow(
                        icon: Icons.verified_user_outlined,
                        label: 'Fechado por',
                        value: fechadoPor,
                      ),
                  ],
                ),
              ),
              if (!encerrado) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildOutlinedAction(
                      icon: Icons.edit_outlined,
                      label: 'Editar ciclo',
                      color: Colors.blue,
                      onTap: () async {
                        await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TelaNovoCiclo(
                              cicloExistente:
                                  ciclo.data() as Map<String, dynamic>,
                              cicloId: ciclo.id,
                            ),
                          ),
                        );
                        if (mounted) setState(() {});
                      },
                    ),
                    _buildOutlinedAction(
                      icon: Icons.add_circle_outline,
                      label: 'Registrar povoamento',
                      color: const Color(0xFF049F56),
                      onTap: () => _abrirRegistroPovoamento(context, ciclo),
                    ),
                    _buildOutlinedAction(
                      icon: Icons.lock_outline,
                      label: 'Encerrar ciclo',
                      color: Colors.red,
                      onTap: () => _encerrarCiclo(ciclo),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDespescaResumo({
    required String cicloId,
    required String codigoLocal,
    required String nomeLocal,
    required bool encerrado,
  }) {
    return FutureBuilder<_DespescaVinculada?>(
      future: _obterDespescaVinculada(cicloId, codigoLocal),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Row(
              children: [
                SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Expanded(child: Text('Carregando dados da despesca...')),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.redAccent.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Não foi possível carregar a despesca vinculada.',
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
              ],
            ),
          );
        }

        final vinculo = snapshot.data;
        if (vinculo == null) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Nenhuma despesca registrada para este ciclo. '
                    'Finalize a despesca para garantir os dados antes de encerrar o ciclo.',
                    style: TextStyle(color: Colors.orange.shade900),
                  ),
                ),
              ],
            ),
          );
        }

        final doc = vinculo.documento;
        final dados = doc.data();
        final statusRaw = (dados['statusDespesca'] ?? 'planejada').toString();
        final status = _mapearStatusDespesca(statusRaw);
        final pesoTotal = (dados['pesoTotal'] as num?)?.toDouble() ?? 0.0;
        final basquetasTotal = (dados['basquetasTotal'] as num?)?.toInt() ?? 0;
        final dias = List<Map<String, dynamic>>.from(dados['dias'] ?? []);
        final dataFinalizacao = (dados['dataFinalizacao'] as Timestamp?)
            ?.toDate();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: status.backgroundColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(status.icon, size: 16, color: status.textColor),
                        const SizedBox(width: 4),
                        Text(
                          status.label,
                          style: TextStyle(
                            color: status.textColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (dataFinalizacao != null)
                    Text(
                      'Finalizada em ${_formatarData(dataFinalizacao)}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  _buildChipInfo('Dias', dias.length.toString()),
                  _buildChipInfo(
                    'Peso total',
                    '${_formatarDecimal(pesoTotal)} kg',
                  ),
                  _buildChipInfo('Basquetas', basquetasTotal.toString()),
                ],
              ),
              if (vinculo.vinculoRecuperado)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Despesca antiga vinculada automaticamente a este ciclo.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                  ),
                ),
              if (!encerrado) ...[
                const SizedBox(height: 8),
                Text(
                  'Use o botão abaixo para revisar a despesca antes de encerrar o ciclo.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _abrirTelaDespesca(
                    despescaId: doc.id,
                    codigo: codigoLocal,
                    nome: nomeLocal,
                  ),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Abrir despesca'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<_DespescaVinculada?> _obterDespescaVinculada(
    String cicloId,
    String codigoLocal,
  ) async {
    final porCiclo = await _consultarDespescaPorCampo('cicloId', cicloId);
    if (porCiclo != null) return _DespescaVinculada(porCiclo);

    final porCodigo = await _consultarDespescaPorCampo('codigo', codigoLocal);
    if (porCodigo == null) return null;

    final possuiCiclo =
        ((porCodigo.data()['cicloId'] as String?)?.isNotEmpty ?? false);
    if (!possuiCiclo) {
      await porCodigo.reference.update({
        'cicloId': cicloId,
        'ultimaAtualizacao': FieldValue.serverTimestamp(),
      });
      return _DespescaVinculada(porCodigo, vinculoRecuperado: true);
    }

    return _DespescaVinculada(porCodigo);
  }

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?>
  _consultarDespescaPorCampo(String campo, String valor) async {
    final baseQuery = FirebaseFirestore.instance
        .collection('despescas')
        .where(campo, isEqualTo: valor);
    try {
      final snapshot = await baseQuery
          .orderBy('dataCriacao', descending: true)
          .limit(1)
          .get();
      return snapshot.docs.isEmpty ? null : snapshot.docs.first;
    } on FirebaseException catch (e) {
      if (_ehErroDeIndice(e)) {
        final fallback = await baseQuery.limit(1).get();
        return fallback.docs.isEmpty ? null : fallback.docs.first;
      }
      rethrow;
    }
  }

  bool _ehErroDeIndice(FirebaseException e) {
    return e.code == 'failed-precondition' &&
        (e.message?.toLowerCase().contains('index') ?? false);
  }

  Widget _buildChipInfo(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(value, style: TextStyle(color: Colors.grey.shade900)),
        ],
      ),
    );
  }

  Future<void> _abrirTelaDespesca({
    required String despescaId,
    required String codigo,
    required String nome,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TelaDespesca(
          despescaId: despescaId,
          codigoViveiro: codigo,
          nomeViveiro: nome,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  _StatusDespescaStyle _mapearStatusDespesca(String status) {
    switch (status) {
      case 'concluida':
        return _StatusDespescaStyle(
          label: 'Concluída',
          textColor: const Color(0xFF045D3A),
          backgroundColor: const Color(0xFFADF0CB),
          icon: Icons.check_circle_outline,
        );
      case 'em_andamento':
        return _StatusDespescaStyle(
          label: 'Em andamento',
          textColor: const Color(0xFF0D47A1),
          backgroundColor: const Color(0xFFD7E3FC),
          icon: Icons.autorenew,
        );
      case 'planejada':
      default:
        return _StatusDespescaStyle(
          label: 'Planejada',
          textColor: const Color(0xFF8E6200),
          backgroundColor: const Color(0xFFFFF2CC),
          icon: Icons.schedule_outlined,
        );
    }
  }

  Future<void> _encerrarCiclo(QueryDocumentSnapshot ciclo) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Encerramento'),
        content: Text(
          'Deseja realmente encerrar o ciclo do ${ciclo['nome']}?\n\nEsta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Encerrar'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        final userData = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user?.uid)
            .get();
        final nomeUsuario = userData.data()?['nome'] ?? 'Usuário';

        await FirebaseFirestore.instance
            .collection('ciclos')
            .doc(ciclo.id)
            .update({
              'encerrado': true,
              'dataEncerramento': Timestamp.now(),
              'fechadoPor': nomeUsuario,
            });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Ciclo encerrado com sucesso!'),
              backgroundColor: Color(0xFF049F56),
            ),
          );
          setState(() {});
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Erro ao encerrar ciclo: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _carregarDestinos() async {
    try {
      // Carregar viveiros
      final viveirosSnapshot = await FirebaseFirestore.instance
          .collection('viveiros')
          .get();

      // Carregar berçários
      final bercariosSnapshot = await FirebaseFirestore.instance
          .collection('bercarios')
          .get();

      final novosDestinos = <String, String>{};

      for (var doc in viveirosSnapshot.docs) {
        final data = doc.data();
        final codigo = data['codigo']?.toString() ?? '';
        final nome = data['nome']?.toString() ?? '';
        if (codigo.isNotEmpty && nome.isNotEmpty) {
          novosDestinos['V-$codigo'] = '🐟 $nome (V-$codigo)';
        }
      }

      for (var doc in bercariosSnapshot.docs) {
        final data = doc.data();
        final codigo = data['codigo']?.toString() ?? '';
        final nome = data['nome']?.toString() ?? '';
        if (codigo.isNotEmpty && nome.isNotEmpty) {
          novosDestinos['B-$codigo'] = '🦐 $nome (B-$codigo)';
        }
      }

      setState(() {
        _destinos = novosDestinos;
      });
    } catch (e) {
      print('Erro ao carregar destinos: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Gestão de Ciclos',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final criadoOuEditado = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const TelaNovoCiclo()),
          );
          if (criadoOuEditado == true && mounted) {
            setState(() {});
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Novo Ciclo'),
      ),
      body: DegradeFundo(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF049F56,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.dashboard_customize_outlined,
                                color: Color(0xFF049F56),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Acompanhe os ciclos ativos ou revisite o histórico sem sair desta tela.\nUse as guias e filtros para encontrar rapidamente o que precisa.',
                                style: TextStyle(
                                  color: Color(0xFF045D3A),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildStatusToggle(),
                      ],
                    ),
                  ),
                ),

                Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _buscaCtrl,
                          decoration: InputDecoration(
                            labelText: 'Buscar por nome ou código',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _buscaTermo.isNotEmpty
                                ? IconButton(
                                    tooltip: 'Limpar busca',
                                    onPressed: () {
                                      setState(() {
                                        _buscaTermo = '';
                                        _buscaCtrl.clear();
                                      });
                                    },
                                    icon: const Icon(Icons.close),
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onChanged: (value) =>
                              setState(() => _buscaTermo = value.trim()),
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final bool useTwoColumns =
                                constraints.maxWidth >= 600;
                            final double fieldWidth = useTwoColumns
                                ? (constraints.maxWidth - 12) / 2
                                : constraints.maxWidth;

                            Widget buildTipoDropdown() {
                              return DropdownButtonFormField<String>(
                                value: _tipoFiltro,
                                decoration: InputDecoration(
                                  labelText: 'Tipo',
                                  prefixIcon: const Icon(Icons.category),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: null,
                                    child: Text('Todos os tipos'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'viveiro',
                                    child: Text('🐟 Viveiros'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'bercario',
                                    child: Text('🦐 Berçários'),
                                  ),
                                ],
                                onChanged: (value) => setState(() {
                                  _tipoFiltro = value;
                                  _codigoFiltro = null;
                                }),
                              );
                            }

                            Widget buildCodigoDropdown() {
                              return DropdownButtonFormField<String>(
                                value: _codigoFiltro,
                                decoration: InputDecoration(
                                  labelText: 'Código',
                                  prefixIcon: const Icon(Icons.water_damage),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                items: _buildCodigoDropdownItems(),
                                onChanged: (value) =>
                                    setState(() => _codigoFiltro = value),
                              );
                            }

                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                SizedBox(
                                  width: fieldWidth,
                                  child: buildTipoDropdown(),
                                ),
                                SizedBox(
                                  width: fieldWidth,
                                  child: buildCodigoDropdown(),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _buscaTermo = '';
                                _buscaCtrl.clear();
                                _tipoFiltro = null;
                                _codigoFiltro = null;
                              });
                            },
                            icon: const Icon(Icons.filter_alt_off),
                            label: const Text('Limpar filtros'),
                          ),
                        ),
                        if (_tipoFiltro != null ||
                            _codigoFiltro != null ||
                            _buscaTermo.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF049F56,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.tune,
                                  color: Color(0xFF049F56),
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    _getActiveFiltersText(),
                                    style: const TextStyle(
                                      color: Color(0xFF049F56),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('ciclos')
                      .snapshots(),
                  builder: (context, snapshot) {
                    // Verificar se há erro
                    if (snapshot.hasError) {
                      return Center(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Colors.red.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error,
                                color: Colors.red,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Erro ao carregar ciclos',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                snapshot.error.toString(),
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () => setState(() {}),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Tentar Novamente'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    // Verificar estado de carregamento
                    if (snapshot.connectionState == ConnectionState.waiting ||
                        !snapshot.hasData) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF049F56),
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Carregando ciclos...',
                              style: TextStyle(color: Color(0xFF045D3A)),
                            ),
                          ],
                        ),
                      );
                    }

                    // Filtrar os dados na aplicação
                    final todosDocs = snapshot.data!.docs;
                    List<QueryDocumentSnapshot> docs = todosDocs.where((doc) {
                      final dados = (doc.data() as Map<String, dynamic>?) ?? {};
                      final encerrado = dados['encerrado'] == true;
                      return _mostrarApenasAbertos == 1
                          ? !encerrado
                          : encerrado;
                    }).toList();

                    // Filtrar por tipo (viveiro/berçário)
                    if (_tipoFiltro != null) {
                      docs = docs.where((doc) {
                        final m = (doc.data() as Map<String, dynamic>?) ?? {};
                        final tipo = (m['tipo'] as String?) ?? 'viveiro';
                        return tipo == _tipoFiltro;
                      }).toList();
                    }

                    // Filtrar por código específico
                    if (_codigoFiltro != null) {
                      final codigoLimpo = _codigoFiltro!.substring(2);
                      docs = docs.where((doc) {
                        final m = (doc.data() as Map<String, dynamic>?) ?? {};
                        return (m['codigo']?.toString() ?? '') == codigoLimpo;
                      }).toList();
                    }

                    if (_buscaTermo.isNotEmpty) {
                      final termo = _buscaTermo.toLowerCase();
                      docs = docs.where((doc) {
                        final data =
                            (doc.data() as Map<String, dynamic>?) ?? {};
                        final nome = (data['nome'] ?? '')
                            .toString()
                            .toLowerCase();
                        final codigo = (data['codigo'] ?? '')
                            .toString()
                            .toLowerCase();
                        return nome.contains(termo) || codigo.contains(termo);
                      }).toList();
                    }

                    // Filtrar apenas viveiros e berçários cadastrados
                    docs = docs.where((doc) {
                      final m = (doc.data() as Map<String, dynamic>?) ?? {};
                      final tipo = (m['tipo'] as String?) ?? 'viveiro';
                      final codigo = (m['codigo']?.toString() ?? '');
                      final key = (tipo == 'viveiro' ? 'V-' : 'B-') + codigo;
                      return _destinos.containsKey(key);
                    }).toList();

                    // Ordenar por data de início (mais recente primeiro)
                    docs.sort((a, b) {
                      final ma = (a.data() as Map<String, dynamic>?) ?? {};
                      final mb = (b.data() as Map<String, dynamic>?) ?? {};
                      final dateA =
                          (ma['dataInicio'] as Timestamp?)?.toDate() ??
                          DateTime(1970);
                      final dateB =
                          (mb['dataInicio'] as Timestamp?)?.toDate() ??
                          DateTime(1970);
                      return dateB.compareTo(dateA);
                    });

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (docs.isEmpty)
                          _buildListaVazia()
                        else
                          ...docs.map(_buildCicloCard),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20), // Espaço adicional no final
              ], // Fecha children do Column principal
            ), // Fecha Column
          ), // Fecha Padding
        ), // Fecha SingleChildScrollView
      ), // Fecha DegradeFundo (body)
    ); // Fecha AppScaffold
  }

  void _abrirRegistroPovoamento(
    BuildContext context,
    QueryDocumentSnapshot ciclo,
  ) async {
    final TextEditingController qtdCtrl = TextEditingController();
    final TextEditingController obsCtrl = TextEditingController();
    final user = FirebaseAuth.instance.currentUser;
    final nomeUsuario = user != null
        ? (((await FirebaseFirestore.instance
                      .collection('usuarios')
                      .doc(user.uid)
                      .get())
                  .data()?['nome']) ??
              '—')
        : '—';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.95),
                Colors.white.withValues(alpha: 0.85),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF045D3A), Color(0xFF049F56)],
                        ),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.add_circle,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Flexible(
                      child: Text(
                        'Registro de Povoamento',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF045D3A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF049F56).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: const Color(0xFF049F56).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.water_damage, color: Color(0xFF049F56)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Local: ${ciclo['nome']} (${ciclo['codigo']})',
                          style: const TextStyle(
                            color: Color(0xFF045D3A),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: qtdCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Color(0xFF045D3A)),
                  decoration: InputDecoration(
                    labelText: 'Quantidade adicionada',
                    labelStyle: TextStyle(
                      color: const Color(0xFF045D3A).withValues(alpha: 0.7),
                    ),
                    prefixIcon: const Icon(
                      Icons.numbers,
                      color: Color(0xFF049F56),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF049F56).withValues(alpha: 0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(
                        color: const Color(0xFF049F56).withValues(alpha: 0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(
                        color: Color(0xFF049F56),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: obsCtrl,
                  style: const TextStyle(color: Color(0xFF045D3A)),
                  decoration: InputDecoration(
                    labelText: 'Observações',
                    labelStyle: TextStyle(
                      color: const Color(0xFF045D3A).withValues(alpha: 0.7),
                    ),
                    prefixIcon: const Icon(
                      Icons.notes,
                      color: Color(0xFF049F56),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF049F56).withValues(alpha: 0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(
                        color: const Color(0xFF049F56).withValues(alpha: 0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(
                        color: Color(0xFF049F56),
                        width: 2,
                      ),
                    ),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: Colors.grey.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF045D3A), Color(0xFF049F56)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF045D3A,
                              ).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () async {
                            final qtd = int.tryParse(qtdCtrl.text);
                            if (qtd == null || qtd <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Row(
                                    children: [
                                      Icon(Icons.warning, color: Colors.white),
                                      SizedBox(width: 8),
                                      Text('⚠️ Informe uma quantidade válida!'),
                                    ],
                                  ),
                                  backgroundColor: Colors.orange,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                              return;
                            }

                            try {
                              await FirebaseFirestore.instance
                                  .collection('povoamentos')
                                  .add({
                                    'cicloId': ciclo.id,
                                    'codigo': ciclo['codigo'],
                                    'nome': ciclo['nome'],
                                    'quantidade': qtd,
                                    'responsavel': nomeUsuario,
                                    'observacoes': obsCtrl.text.trim(),
                                    'dataRegistro': Timestamp.now(),
                                  });
                              // Atualiza quantidadeEstocada somando novo povoamento
                              await FirebaseFirestore.instance
                                  .collection('ciclos')
                                  .doc(ciclo.id)
                                  .update({
                                    'quantidadeEstocada': FieldValue.increment(
                                      qtd,
                                    ),
                                  });

                              if (context.mounted) Navigator.pop(context);

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        '✅ Povoamento registrado com sucesso!',
                                      ),
                                    ],
                                  ),
                                  backgroundColor: const Color(0xFF049F56),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(
                                        Icons.error,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text('❌ Erro: $e')),
                                    ],
                                  ),
                                  backgroundColor: Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Salvar',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusDespescaStyle {
  final String label;
  final Color textColor;
  final Color backgroundColor;
  final IconData icon;

  const _StatusDespescaStyle({
    required this.label,
    required this.textColor,
    required this.backgroundColor,
    required this.icon,
  });
}

class _DespescaVinculada {
  final QueryDocumentSnapshot<Map<String, dynamic>> documento;
  final bool vinculoRecuperado;

  const _DespescaVinculada(this.documento, {this.vinculoRecuperado = false});
}
