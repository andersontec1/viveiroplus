import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/degrade_fundo.dart';
import 'tela_entrada_insumo.dart';
import '../helpers/estoque_helper.dart';
import '../helpers/security_helper.dart';
import '../helpers/audit_helper.dart';

class TelaEstoqueInsumos extends StatefulWidget {
  const TelaEstoqueInsumos({super.key});

  @override
  State<TelaEstoqueInsumos> createState() => _TelaEstoqueInsumosState();
}

class _TelaEstoqueInsumosState extends State<TelaEstoqueInsumos> {
  String _busca = '';
  String? _filtroTipo;
  bool _podeGerenciarPontos = false;

  @override
  void initState() {
    super.initState();
    _carregarPermissoes();
  }

  Future<void> _carregarPermissoes() async {
    try {
      final adm = await SecurityHelper.temFuncaoAdministrativa();
      if (mounted) setState(() => _podeGerenciarPontos = adm);
    } catch (_) {}
  }

  void _abrirMovimentacaoDialog(
    Map<String, dynamic> insumo,
    String docId,
  ) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _MovimentacaoDialog(insumo: insumo),
    );
    if (result == null) return;

    try {
      final tipo = (result['tipoMov'] as String?) ?? 'entrada';
      final qtd = (result['quantidade'] as num);
      final obs = (result['observacao'] as String?)?.trim();

      if (tipo == 'entrada') {
        // Entrada simples cria um lote sem validade/lote definidos
        await EstoqueHelper.registrarEntradaLote(
          insumoId: docId,
          quantidade: qtd,
          unidade: insumo['unidade'],
          fornecedor: insumo['fornecedor'],
          observacoes: obs,
        );
      } else {
        // Saída via FEFO para manter consistência com lotes
        await EstoqueHelper.registrarSaidaFefo(
          insumoNomeOuId: docId,
          quantidade: qtd,
          origem: 'ajuste',
          referenciaId: null,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Movimentação registrada com sucesso!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao movimentar: $e')));
    }
  }

  void _abrirHistoricoMovimentacoes(String insumoId, String nome) {
    showDialog(
      context: context,
      builder: (_) =>
          _HistoricoMovimentacoesDialog(insumoId: insumoId, nome: nome),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Estoque de Insumos',
      body: DegradeFundo(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Buscar insumo',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) => setState(() => _busca = val),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _filtroTipo,
                    hint: const Text('Tipo'),
                    items: const [
                      DropdownMenuItem(
                        value: 'Probiótico',
                        child: Text('Probiótico'),
                      ),
                      DropdownMenuItem(value: 'Ração', child: Text('Ração')),
                      DropdownMenuItem(
                        value: 'Suplemento',
                        child: Text('Suplemento'),
                      ),
                      DropdownMenuItem(value: 'Outro', child: Text('Outro')),
                    ],
                    onChanged: (val) => setState(() => _filtroTipo = val),
                  ),
                  IconButton(
                    icon: const Icon(Icons.filter_alt_off_rounded),
                    tooltip: 'Limpar filtros',
                    onPressed: () => setState(() {
                      _busca = '';
                      _filtroTipo = null;
                    }),
                  ),
                  const SizedBox(width: 8),
                  if (_podeGerenciarPontos)
                    Tooltip(
                      message: 'Gerenciar pontos de entrega',
                      child: IconButton(
                        icon: const Icon(Icons.warehouse_rounded),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) =>
                                const _GerenciarPontosEntregaDialog(),
                          );
                        },
                      ),
                    ),
                  const SizedBox(width: 4),
                  Tooltip(
                    message: 'Relatório de ração (período)',
                    child: IconButton(
                      icon: const Icon(Icons.assessment_outlined),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => const _RelatorioRacaoDialog(),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 4),
                  Tooltip(
                    message: 'Exportar entradas (distribuição)',
                    child: IconButton(
                      icon: const Icon(Icons.file_download_outlined),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) =>
                              const _ExportEntradasDistribuicaoDialog(),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('insumos')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData)
                      return const Center(child: CircularProgressIndicator());
                    final todos = snapshot.data!.docs;
                    final filtrados = todos.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final nome = (data['nome'] ?? '')
                          .toString()
                          .toLowerCase();
                      final tipo = (data['tipo'] ?? '').toString();
                      final buscaOk = nome.contains(_busca.toLowerCase());
                      final tipoOk = _filtroTipo == null || tipo == _filtroTipo;
                      return buscaOk && tipoOk;
                    }).toList();
                    if (filtrados.isEmpty) {
                      return const Center(
                        child: Text('Nenhum insumo encontrado.'),
                      );
                    }
                    filtrados.sort((a, b) {
                      final an =
                          (a.data() as Map<String, dynamic>)['nome']
                              ?.toString()
                              .toLowerCase() ??
                          '';
                      final bn =
                          (b.data() as Map<String, dynamic>)['nome']
                              ?.toString()
                              .toLowerCase() ??
                          '';
                      return an.compareTo(bn);
                    });
                    return ListView.separated(
                      itemCount: filtrados.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final insumo = filtrados[index];
                        final data = insumo.data() as Map<String, dynamic>;
                        final estoque =
                            (data['estoque'] ?? data['quantidade_inicial'] ?? 0)
                                as num;
                        final estoqueMin = (data['estoque_minimo'] ?? 0) as num;
                        final bool baixo =
                            estoqueMin > 0 && estoque <= estoqueMin;
                        // Validade básica (campo direto) - lotes detalhados já aparecem no histórico
                        DateTime? proxVal = (data['validade'] as Timestamp?)
                            ?.toDate();
                        if (proxVal != null) {
                          proxVal = DateTime(
                            proxVal.year,
                            proxVal.month,
                            proxVal.day,
                          );
                        }
                        final bool vencido =
                            proxVal != null && proxVal.isBefore(DateTime.now());
                        final bool pertoVencer =
                            proxVal != null &&
                            !vencido &&
                            proxVal.difference(DateTime.now()).inDays <= 7;
                        // Chips de status
                        final List<Widget> chips = [];
                        if (vencido) {
                          chips.add(
                            Chip(
                              label: const Text('Vencido'),
                              backgroundColor: Colors.red[100],
                              labelStyle: const TextStyle(color: Colors.red),
                            ),
                          );
                        } else if (pertoVencer) {
                          chips.add(
                            Chip(
                              label: Text(
                                'Vence em ${proxVal.difference(DateTime.now()).inDays}d',
                              ),
                              backgroundColor: Colors.orange[100],
                              labelStyle: const TextStyle(color: Colors.orange),
                            ),
                          );
                        }
                        if (baixo) {
                          chips.add(
                            Chip(
                              label: const Text('Baixo'),
                              backgroundColor: Colors.red[50],
                              labelStyle: const TextStyle(color: Colors.red),
                            ),
                          );
                        }
                        return Container(
                          decoration: BoxDecoration(
                            color: baixo ? Colors.red[50] : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => _abrirHistoricoMovimentacoes(
                              insumo.id,
                              data['nome'],
                            ),
                            onLongPress: () =>
                                _abrirMovimentacaoDialog(data, insumo.id),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 16,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: baixo
                                          ? Colors.red[100]
                                          : Colors.teal[50],
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    padding: const EdgeInsets.all(12),
                                    child: Icon(
                                      Icons.inventory_2_rounded,
                                      color: baixo ? Colors.red : Colors.teal,
                                      size: 36,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                data['nome'] ?? '-',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (chips.isNotEmpty)
                                              Flexible(
                                                child: SingleChildScrollView(
                                                  scrollDirection:
                                                      Axis.horizontal,
                                                  child: Row(
                                                    children: chips
                                                        .map(
                                                          (c) => Padding(
                                                            padding:
                                                                const EdgeInsets.only(
                                                                  left: 4,
                                                                ),
                                                            child: c,
                                                          ),
                                                        )
                                                        .toList(),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '${data['tipo']} • ${data['categoria'] ?? ''}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.black54,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 12,
                                          runSpacing: 4,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.straighten_rounded,
                                                  size: 16,
                                                  color: Colors.teal[300],
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Unidade: ${data['unidade'] ?? '-'}',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (proxVal != null)
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.event_rounded,
                                                    size: 16,
                                                    color: vencido
                                                        ? Colors.red
                                                        : (pertoVencer
                                                              ? Colors.orange
                                                              : Colors.teal),
                                                  ),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    'Próx. validade: ${proxVal.day.toString().padLeft(2, '0')}/${proxVal.month.toString().padLeft(2, '0')}/${proxVal.year}',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: vencido
                                                          ? Colors.red
                                                          : (pertoVencer
                                                                ? Colors.orange
                                                                : Colors.teal),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        LayoutBuilder(
                                          builder: (ctx, constraints) {
                                            final hasLote = (data['lote'] ?? '')
                                                .toString()
                                                .isNotEmpty;
                                            return Wrap(
                                              spacing: 16,
                                              runSpacing: 4,
                                              crossAxisAlignment:
                                                  WrapCrossAlignment.center,
                                              children: [
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .local_shipping_rounded,
                                                      size: 16,
                                                      color: Colors.teal[300],
                                                    ),
                                                    const SizedBox(width: 4),
                                                    ConstrainedBox(
                                                      constraints:
                                                          const BoxConstraints(
                                                            maxWidth: 180,
                                                          ),
                                                      child: Text(
                                                        'Fornecedor: ${data['fornecedor'] ?? '-'}',
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (hasLote)
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .confirmation_number_rounded,
                                                        size: 16,
                                                        color: Colors.teal[300],
                                                      ),
                                                      const SizedBox(width: 3),
                                                      Text(
                                                        'Lote: ${data['lote']}',
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                              ],
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Estoque',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: baixo
                                              ? Colors.red[100]
                                              : Colors.teal[50],
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          '$estoque',
                                          style: TextStyle(
                                            color: baixo
                                                ? Colors.red
                                                : Colors.teal[800],
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.edit,
                                              color: Colors.orange,
                                            ),
                                            tooltip: 'Editar quantidade',
                                            onPressed: () async {
                                              final controller =
                                                  TextEditingController(
                                                    text: estoque.toString(),
                                                  );
                                              final result = await showDialog<num?>(
                                                context: context,
                                                builder: (_) => AlertDialog(
                                                  title: Text(
                                                    'Editar Estoque: ${data['nome']}',
                                                  ),
                                                  content: TextFormField(
                                                    controller: controller,
                                                    keyboardType:
                                                        TextInputType.number,
                                                    decoration:
                                                        const InputDecoration(
                                                          labelText:
                                                              'Nova quantidade',
                                                        ),
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                            context,
                                                          ),
                                                      child: const Text(
                                                        'Cancelar',
                                                      ),
                                                    ),
                                                    ElevatedButton(
                                                      onPressed: () {
                                                        final novo =
                                                            num.tryParse(
                                                              controller.text,
                                                            );
                                                        if (novo == null ||
                                                            novo < 0) {
                                                          ScaffoldMessenger.of(
                                                            context,
                                                          ).showSnackBar(
                                                            const SnackBar(
                                                              content: Text(
                                                                'Informe um valor válido!',
                                                              ),
                                                            ),
                                                          );
                                                          return;
                                                        }
                                                        Navigator.pop(
                                                          context,
                                                          novo,
                                                        );
                                                      },
                                                      child: const Text(
                                                        'Salvar',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                              if (result != null) {
                                                if (!data.containsKey(
                                                  'estoque',
                                                )) {
                                                  await FirebaseFirestore
                                                      .instance
                                                      .collection('insumos')
                                                      .doc(insumo.id)
                                                      .update({
                                                        'estoque': result,
                                                        'quantidade_inicial':
                                                            result,
                                                      });
                                                } else {
                                                  await FirebaseFirestore
                                                      .instance
                                                      .collection('insumos')
                                                      .doc(insumo.id)
                                                      .update({
                                                        'estoque': result,
                                                      });
                                                }
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Estoque atualizado!',
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.move_to_inbox_rounded,
                                              color: Colors.teal,
                                            ),
                                            tooltip: 'Entrada por Lote',
                                            onPressed: () async {
                                              await Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      TelaEntradaInsumo(
                                                        insumoIdPreSelecionado:
                                                            insumo.id,
                                                      ),
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.grey),
                  SizedBox(width: 4),
                  Text(
                    'Toque para ver histórico, pressione para movimentar',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TelaEntradaInsumo()),
          );
        },
        icon: const Icon(Icons.move_to_inbox_rounded),
        label: const Text('Entrada por Lote'),
      ),
    );
  }
}

class _MovimentacaoDialog extends StatefulWidget {
  const _MovimentacaoDialog({required this.insumo});
  final Map<String, dynamic> insumo;

  @override
  State<_MovimentacaoDialog> createState() => _MovimentacaoDialogState();
}

class _MovimentacaoDialogState extends State<_MovimentacaoDialog> {
  String _tipoMov = 'entrada';
  final _qtdController = TextEditingController();
  final _obsController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Movimentar Estoque: ${widget.insumo['nome']}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _tipoMov,
            items: const [
              DropdownMenuItem(value: 'entrada', child: Text('Entrada')),
              DropdownMenuItem(value: 'saida', child: Text('Saída')),
            ],
            onChanged: (val) => setState(() => _tipoMov = val!),
            decoration: const InputDecoration(
              labelText: 'Tipo de Movimentação',
            ),
          ),
          TextFormField(
            controller: _qtdController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Quantidade'),
          ),
          TextFormField(
            controller: _obsController,
            decoration: const InputDecoration(
              labelText: 'Observação (opcional)',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            final qtd = num.tryParse(_qtdController.text);
            if (qtd == null || qtd <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Informe uma quantidade válida!')),
              );
              return;
            }
            Navigator.pop(context, {
              'tipoMov': _tipoMov,
              'quantidade': qtd,
              'observacao': _obsController.text.trim(),
            });
          },
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}

class _HistoricoMovimentacoesDialog extends StatelessWidget {
  const _HistoricoMovimentacoesDialog({
    required this.insumoId,
    required this.nome,
  });
  final String insumoId;
  final String nome;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Histórico: $nome'),
      content: SizedBox(
        width: 350,
        child: DefaultTabController(
          length: 2,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const TabBar(
                tabs: [
                  Tab(icon: Icon(Icons.history), text: 'Movimentações'),
                  Tab(icon: Icon(Icons.list_alt), text: 'Lotes'),
                ],
              ),
              // Altura adaptativa: proporcional à altura da tela com limites para evitar overflow ou espaço vazio excessivo
              Builder(
                builder: (context) {
                  final h = MediaQuery.of(context).size.height;
                  final maxAltura = (h * 0.55).clamp(300.0, 520.0);
                  return SizedBox(
                    height: maxAltura,
                    child: TabBarView(
                      children: [
                        // Movimentações
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('movimentacoes_estoque')
                              .where('insumoId', isEqualTo: insumoId)
                              .orderBy('timestamp', descending: true)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData)
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            final docs = snapshot.data!.docs;
                            if (docs.isEmpty)
                              return const Center(
                                child: Text('Nenhuma movimentação encontrada.'),
                              );
                            return ListView.builder(
                              itemCount: docs.length,
                              itemBuilder: (context, index) {
                                final mov =
                                    docs[index].data() as Map<String, dynamic>;
                                final tipo = mov['tipoMov'] == 'entrada'
                                    ? 'Entrada'
                                    : 'Saída';
                                final cor = mov['tipoMov'] == 'entrada'
                                    ? Colors.green
                                    : Colors.red;
                                final qtd = mov['quantidade'];
                                final obs = mov['observacao'] ?? '';
                                final data = (mov['timestamp'] as Timestamp?)
                                    ?.toDate();
                                final entregas =
                                    (mov['entregasPorPonto'] is List)
                                    ? (mov['entregasPorPonto'] as List)
                                    : const [];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4.0,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(
                                          mov['tipoMov'] == 'entrada'
                                              ? Icons.add
                                              : Icons.remove,
                                          color: cor,
                                        ),
                                        title: Text('$tipo: $qtd'),
                                        subtitle: Text(
                                          obs.isNotEmpty ? obs : '-',
                                        ),
                                        trailing: data != null
                                            ? Text(
                                                '${data.day}/${data.month}/${data.year} ${data.hour}:${data.minute.toString().padLeft(2, '0')}',
                                              )
                                            : null,
                                      ),
                                      if (entregas.isNotEmpty &&
                                          mov['tipoMov'] == 'entrada')
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            left: 56.0,
                                          ),
                                          child: Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            children: entregas
                                                .map(
                                                  (e) => Chip(
                                                    label: Text(
                                                      '${(e['nomePonto'] ?? '').toString()} • ${(e['quantidade'] ?? 0)} kg',
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                  ),
                                                )
                                                .toList()
                                                .cast<Widget>(),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),

                        // Lotes
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('lotes_insumo')
                              .where('insumoId', isEqualTo: insumoId)
                              .where('status', isEqualTo: 'ativo')
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData)
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            final docs = snapshot.data!.docs;
                            if (docs.isEmpty)
                              return const Center(
                                child: Text('Nenhum lote ativo.'),
                              );
                            docs.sort((a, b) {
                              final av = (a['validade'] as Timestamp?)
                                  ?.toDate();
                              final bv = (b['validade'] as Timestamp?)
                                  ?.toDate();
                              if (av == null && bv == null) return 0;
                              if (av == null) return 1;
                              if (bv == null) return -1;
                              return av.compareTo(bv);
                            });
                            return ListView.builder(
                              itemCount: docs.length,
                              itemBuilder: (context, index) {
                                final d = docs[index];
                                final data = d.data() as Map<String, dynamic>;
                                final qtd = (data['quantidade'] ?? 0) as num;
                                final val = (data['validade'] as Timestamp?)
                                    ?.toDate();
                                final vencido =
                                    val != null &&
                                    DateTime(
                                      val.year,
                                      val.month,
                                      val.day,
                                    ).isBefore(DateTime.now());
                                return ListTile(
                                  leading: Icon(
                                    Icons.confirmation_number,
                                    color: vencido ? Colors.red : Colors.teal,
                                  ),
                                  title: Text(
                                    'Lote: ${data['lote']?.toString().isNotEmpty == true ? data['lote'] : '-'}',
                                  ),
                                  subtitle: Text(
                                    'Qtd: $qtd  •  Validade: ${val != null ? '${val.day.toString().padLeft(2, '0')}/${val.month.toString().padLeft(2, '0')}/${val.year}' : '-'}',
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.delete_forever,
                                      color: Colors.red,
                                    ),
                                    tooltip: 'Inativar lote',
                                    onPressed: () async {
                                      final ok = await showDialog<bool>(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          title: const Text('Inativar lote?'),
                                          content: const Text(
                                            'Isso não apaga os movimentos, apenas marca o lote como inativo.',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text('Cancelar'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: const Text('Inativar'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (ok == true) {
                                        await EstoqueHelper.inativarLote(
                                          loteId: d.id,
                                        );
                                      }
                                    },
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}

// Dialogo para gerenciar pontos de entrega (CRUD básico)
class _GerenciarPontosEntregaDialog extends StatelessWidget {
  const _GerenciarPontosEntregaDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pontos de entrega'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [Expanded(child: _BuscaPontosWidget())]),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Novo ponto'),
                onPressed: () async {
                  await showDialog(
                    context: context,
                    builder: (_) => const _EditarPontoEntregaDialog(),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('pontos_entrega')
                    .orderBy('nome')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  }
                  var docs = snapshot.data!.docs;
                  final filtro = _BuscaPontosInherited.of(context);
                  if (filtro != null) {
                    if (filtro.ativosSomente != null) {
                      docs = docs
                          .where(
                            (d) =>
                                ((d.data() as Map<String, dynamic>)['ativo'] !=
                                    false) ==
                                filtro.ativosSomente,
                          )
                          .toList();
                    }
                    if (filtro.termoBusca.trim().isNotEmpty) {
                      final t = filtro.termoBusca.toLowerCase();
                      docs = docs
                          .where(
                            (d) =>
                                ((d.data() as Map<String, dynamic>)['nome'] ??
                                        '')
                                    .toString()
                                    .toLowerCase()
                                    .contains(t),
                          )
                          .toList();
                    }
                  }
                  if (docs.isEmpty) {
                    return const Center(
                      child: Text('Nenhum ponto cadastrado.'),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const Divider(height: 12),
                    itemBuilder: (context, index) {
                      final d = docs[index];
                      final m = d.data() as Map<String, dynamic>;
                      final nome = (m['nome'] ?? '').toString();
                      final ativo = m['ativo'] != false;
                      final viveiros = (m['atendeViveiros'] is List)
                          ? (m['atendeViveiros'] as List)
                                .map((e) => e.toString())
                                .toList()
                          : <String>[];
                      final bercarios = (m['atendeBercarios'] is List)
                          ? (m['atendeBercarios'] as List)
                                .map((e) => e.toString())
                                .toList()
                          : <String>[];
                      return ListTile(
                        title: Row(
                          children: [
                            Expanded(child: Text(nome)),
                            if (!ativo)
                              const Padding(
                                padding: EdgeInsets.only(left: 6.0),
                                child: Chip(
                                  label: Text('Inativo'),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                          ],
                        ),
                        subtitle: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            ...viveiros.map(
                              (v) => Chip(
                                label: Text('Viveiro $v'),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                            ...bercarios.map(
                              (b) => Chip(
                                label: Text('Berçário $b'),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (acao) async {
                            if (acao == 'editar') {
                              await showDialog(
                                context: context,
                                builder: (_) => _EditarPontoEntregaDialog(
                                  pontoId: d.id,
                                  dados: m,
                                ),
                              );
                            } else if (acao == 'ativar') {
                              await d.reference.update({'ativo': true});
                              await AuditHelper.registrarAcao(
                                acao: 'PONTO_ENTREGA_ATIVAR',
                                modulo: 'ESTOQUE',
                                detalhes: {'pontoId': d.id},
                              );
                            } else if (acao == 'inativar') {
                              await d.reference.update({'ativo': false});
                              await AuditHelper.registrarAcao(
                                acao: 'PONTO_ENTREGA_INATIVAR',
                                modulo: 'ESTOQUE',
                                detalhes: {'pontoId': d.id},
                              );
                            } else if (acao == 'excluir') {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Excluir ponto?'),
                                  content: const Text(
                                    'Esta ação não remove movimentações antigas que o referenciem.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancelar'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Excluir'),
                                    ),
                                  ],
                                ),
                              );
                              if (ok == true) {
                                await d.reference.delete();
                                await AuditHelper.registrarAcao(
                                  acao: 'PONTO_ENTREGA_EXCLUIR',
                                  modulo: 'ESTOQUE',
                                  detalhes: {'pontoId': d.id},
                                );
                              }
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'editar',
                              child: Text('Editar'),
                            ),
                            if (!ativo)
                              const PopupMenuItem(
                                value: 'ativar',
                                child: Text('Ativar'),
                              )
                            else
                              const PopupMenuItem(
                                value: 'inativar',
                                child: Text('Inativar'),
                              ),
                            const PopupMenuDivider(),
                            const PopupMenuItem(
                              value: 'excluir',
                              child: Text('Excluir'),
                            ),
                          ],
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}

// Inherited para fornecer filtros de busca/ativos
class _BuscaPontosInherited extends InheritedWidget {
  const _BuscaPontosInherited({
    required this.termoBusca,
    required this.ativosSomente,
    required super.child,
  });
  final String termoBusca;
  final bool? ativosSomente;

  static _BuscaPontosInherited? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_BuscaPontosInherited>();

  @override
  bool updateShouldNotify(covariant _BuscaPontosInherited oldWidget) {
    return termoBusca != oldWidget.termoBusca ||
        ativosSomente != oldWidget.ativosSomente;
  }
}

class _BuscaPontosWidget extends StatefulWidget {
  @override
  State<_BuscaPontosWidget> createState() => _BuscaPontosWidgetState();
}

class _BuscaPontosWidgetState extends State<_BuscaPontosWidget> {
  String _busca = '';
  String _status = 'todos';

  @override
  Widget build(BuildContext context) {
    bool? ativos;
    if (_status == 'ativos') ativos = true;
    if (_status == 'inativos') ativos = false;
    return _BuscaPontosInherited(
      termoBusca: _busca,
      ativosSomente: ativos,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar ponto…',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _busca = v),
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: _status,
            items: const [
              DropdownMenuItem(value: 'todos', child: Text('Todos')),
              DropdownMenuItem(value: 'ativos', child: Text('Ativos')),
              DropdownMenuItem(value: 'inativos', child: Text('Inativos')),
            ],
            onChanged: (v) => setState(() => _status = v ?? 'todos'),
          ),
        ],
      ),
    );
  }
}

class _EditarPontoEntregaDialog extends StatefulWidget {
  const _EditarPontoEntregaDialog({this.pontoId, this.dados});
  final String? pontoId;
  final Map<String, dynamic>? dados;

  @override
  State<_EditarPontoEntregaDialog> createState() =>
      _EditarPontoEntregaDialogState();
}

class _EditarPontoEntregaDialogState extends State<_EditarPontoEntregaDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  bool _ativo = true;
  final Set<String> _viveirosSel = {};
  final Set<String> _bercariosSel = {};
  bool _carregando = true;
  List<String> _viveiros = [];
  List<String> _bercarios = [];

  @override
  void initState() {
    super.initState();
    _carregarReferencias();
  }

  Future<void> _carregarReferencias() async {
    try {
      final vSnap = await FirebaseFirestore.instance
          .collection('viveiros')
          .orderBy('codigo')
          .get();
      final bSnap = await FirebaseFirestore.instance
          .collection('bercarios')
          .orderBy('codigo')
          .get();
      setState(() {
        _viveiros = vSnap.docs
            .map((d) => ((d.data()['codigo'] ?? d.id).toString()))
            .toList();
        _bercarios = bSnap.docs
            .map((d) => ((d.data()['codigo'] ?? d.id).toString()))
            .toList();
      });
    } finally {
      if (widget.dados != null) {
        _nomeCtrl.text = (widget.dados!['nome'] ?? '').toString();
        _ativo = widget.dados!['ativo'] != false;
        final v = (widget.dados!['atendeViveiros'] is List)
            ? (widget.dados!['atendeViveiros'] as List)
            : const [];
        final b = (widget.dados!['atendeBercarios'] is List)
            ? (widget.dados!['atendeBercarios'] as List)
            : const [];
        _viveirosSel
          ..clear()
          ..addAll(v.map((e) => e.toString()));
        _bercariosSel
          ..clear()
          ..addAll(b.map((e) => e.toString()));
      }
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.pontoId == null
            ? 'Novo ponto de entrega'
            : 'Editar ponto de entrega',
      ),
      content: SizedBox(
        width: 520,
        child: _carregando
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _nomeCtrl,
                        decoration: const InputDecoration(labelText: 'Nome'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Informe o nome'
                            : null,
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        value: _ativo,
                        onChanged: (v) => setState(() => _ativo = v),
                        title: const Text('Ativo'),
                      ),
                      const SizedBox(height: 8),
                      const Text('Viveiros atendidos:'),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: _viveiros
                            .map(
                              (v) => FilterChip(
                                label: Text(v),
                                selected: _viveirosSel.contains(v),
                                onSelected: (sel) => setState(() {
                                  if (sel) {
                                    _viveirosSel.add(v);
                                  } else {
                                    _viveirosSel.remove(v);
                                  }
                                }),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 8),
                      const Text('Berçários atendidos:'),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: _bercarios
                            .map(
                              (b) => FilterChip(
                                label: Text(b),
                                selected: _bercariosSel.contains(b),
                                onSelected: (sel) => setState(() {
                                  if (sel) {
                                    _bercariosSel.add(b);
                                  } else {
                                    _bercariosSel.remove(b);
                                  }
                                }),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (!_formKey.currentState!.validate()) return;
            final data = {
              'nome': _nomeCtrl.text.trim(),
              'ativo': _ativo,
              'atendeViveiros': _viveirosSel.toList(),
              'atendeBercarios': _bercariosSel.toList(),
              'atualizadoEm': FieldValue.serverTimestamp(),
            };
            if (widget.pontoId == null) {
              await FirebaseFirestore.instance.collection('pontos_entrega').add(
                {...data, 'criadoEm': FieldValue.serverTimestamp()},
              );
            } else {
              await FirebaseFirestore.instance
                  .collection('pontos_entrega')
                  .doc(widget.pontoId)
                  .update(data);
            }
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

class _RelatorioRacaoDialog extends StatefulWidget {
  const _RelatorioRacaoDialog();
  @override
  State<_RelatorioRacaoDialog> createState() => _RelatorioRacaoDialogState();
}

class _RelatorioRacaoDialogState extends State<_RelatorioRacaoDialog> {
  DateTime _inicio = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _fim = DateTime.now();
  bool _gerando = false;
  Map<String, dynamic>? _resultado;

  Future<void> _gerar() async {
    setState(() {
      _gerando = true;
      _resultado = null;
    });
    try {
      final ini = Timestamp.fromDate(
        DateTime(_inicio.year, _inicio.month, _inicio.day),
      );
      final end = Timestamp.fromDate(
        DateTime(_fim.year, _fim.month, _fim.day + 1),
      );

      // Entradas (movimentacoes_estoque)
      final movsSnap = await FirebaseFirestore.instance
          .collection('movimentacoes_estoque')
          .where('tipoMov', isEqualTo: 'entrada')
          .where('tipo', isEqualTo: 'Ração')
          .where('timestamp', isGreaterThanOrEqualTo: ini)
          .where('timestamp', isLessThan: end)
          .get();
      num totalRecebido = 0;
      final porPonto = <String, num>{};
      final porFornecedor = <String, num>{};
      for (final d in movsSnap.docs) {
        final m = d.data();
        final q = (m['quantidade'] ?? 0) as num;
        totalRecebido += q;
        final forn = (m['fornecedor'] ?? '').toString();
        if (forn.isNotEmpty) {
          porFornecedor.update(forn, (v) => v + q, ifAbsent: () => q);
        }
        final entregas = (m['entregasPorPonto'] is List)
            ? (m['entregasPorPonto'] as List)
            : const [];
        for (final e in entregas) {
          final nome = (e['nomePonto'] ?? '').toString();
          final qE = (e['quantidade'] ?? 0) as num;
          if (nome.isNotEmpty) {
            porPonto.update(nome, (v) => v + qE, ifAbsent: () => qE);
          }
        }
      }

      // Consumo (racao)
      final racaoSnap = await FirebaseFirestore.instance
          .collection('racao')
          .where('dataRegistro', isGreaterThanOrEqualTo: ini)
          .where('dataRegistro', isLessThan: end)
          .get();
      final consumoPorDestino = <String, num>{};
      num totalConsumido = 0;
      for (final d in racaoSnap.docs) {
        final m = d.data();
        final q = (m['quantidade'] ?? 0) as num;
        totalConsumido += q;
        final tipo = (m['tipoDestino'] ?? '').toString();
        final cod = (m['codigoDestino'] ?? m['codigo'] ?? '').toString();
        final chave = '${tipo.isEmpty ? '-' : tipo}:${cod.isEmpty ? '-' : cod}';
        consumoPorDestino.update(chave, (v) => v + q, ifAbsent: () => q);
      }

      setState(() {
        _resultado = {
          'totalRecebido': totalRecebido,
          'porPonto': porPonto,
          'porFornecedor': porFornecedor,
          'totalConsumido': totalConsumido,
          'consumoPorDestino': consumoPorDestino,
        };
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao gerar relatório: $e')));
      }
    } finally {
      if (mounted) setState(() => _gerando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Relatório de ração (período)'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _DateField(
                      label: 'Início',
                      date: _inicio,
                      onPick: (d) => setState(() => _inicio = d),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DateField(
                      label: 'Fim',
                      date: _fim,
                      onPick: (d) => setState(() => _fim = d),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _gerando ? null : _gerar,
                    child: _gerando
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Gerar'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_resultado != null) ...[
                Text(
                  'Total recebido: ${(_resultado!['totalRecebido'] as num).toStringAsFixed(2)} kg',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text('Distribuído por ponto:'),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: (_resultado!['porPonto'] as Map<String, num>)
                      .entries
                      .map(
                        (e) => Chip(
                          label: Text(
                            '${e.key}: ${e.value.toStringAsFixed(2)} kg',
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
                const Text('Recebido por fornecedor:'),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: (_resultado!['porFornecedor'] as Map<String, num>)
                      .entries
                      .map(
                        (e) => Chip(
                          label: Text(
                            '${e.key.isEmpty ? '-' : e.key}: ${e.value.toStringAsFixed(2)} kg',
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
                Text(
                  'Total consumido: ${(_resultado!['totalConsumido'] as num).toStringAsFixed(2)} kg',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text('Consumo por destino:'),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children:
                      (_resultado!['consumoPorDestino'] as Map<String, num>)
                          .entries
                          .map(
                            (e) => Chip(
                              label: Text(
                                '${e.key}: ${e.value.toStringAsFixed(2)} kg',
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                          )
                          .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}

class _ExportEntradasDistribuicaoDialog extends StatefulWidget {
  const _ExportEntradasDistribuicaoDialog();
  @override
  State<_ExportEntradasDistribuicaoDialog> createState() =>
      _ExportEntradasDistribuicaoDialogState();
}

class _ExportEntradasDistribuicaoDialogState
    extends State<_ExportEntradasDistribuicaoDialog> {
  DateTime _inicio = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _fim = DateTime.now();
  final _fornecedorCtrl = TextEditingController();
  final _insumoCtrl = TextEditingController();
  bool _gerando = false;
  String? _csv;

  @override
  void dispose() {
    _fornecedorCtrl.dispose();
    _insumoCtrl.dispose();
    super.dispose();
  }

  Future<void> _gerar() async {
    setState(() {
      _gerando = true;
      _csv = null;
    });
    try {
      final ini = Timestamp.fromDate(
        DateTime(_inicio.year, _inicio.month, _inicio.day),
      );
      final end = Timestamp.fromDate(
        DateTime(_fim.year, _fim.month, _fim.day + 1),
      );
      var q = FirebaseFirestore.instance
          .collection('movimentacoes_estoque')
          .where('tipoMov', isEqualTo: 'entrada')
          .where('timestamp', isGreaterThanOrEqualTo: ini)
          .where('timestamp', isLessThan: end);
      final fornecedor = _fornecedorCtrl.text.trim();
      if (fornecedor.isNotEmpty) {
        q = q.where('fornecedor', isEqualTo: fornecedor);
      }
      final snap = await q.get();
      final rows = <List<String>>[];
      rows.add([
        'data',
        'insumo',
        'quantidade',
        'unidade',
        'fornecedor',
        'lote',
        'ponto',
        'quantidade_ponto',
      ]);
      for (final d in snap.docs) {
        final m = d.data();
        final data = (m['timestamp'] as Timestamp?)?.toDate();
        final dataTxt = data != null
            ? '${data.year}-${data.month.toString().padLeft(2, '0')}-${data.day.toString().padLeft(2, '0')}'
            : '';
        final entregas = (m['entregasPorPonto'] is List)
            ? (m['entregasPorPonto'] as List)
            : const [];
        if (entregas.isEmpty) {
          rows.add([
            dataTxt,
            (m['nome'] ?? '').toString(),
            (m['quantidade'] ?? '').toString(),
            (m['unidade'] ?? '').toString(),
            (m['fornecedor'] ?? '').toString(),
            (m['lote'] ?? '').toString(),
            '',
            '',
          ]);
        } else {
          for (final e in entregas) {
            rows.add([
              dataTxt,
              (m['nome'] ?? '').toString(),
              (m['quantidade'] ?? '').toString(),
              (m['unidade'] ?? '').toString(),
              (m['fornecedor'] ?? '').toString(),
              (m['lote'] ?? '').toString(),
              (e['nomePonto'] ?? '').toString(),
              (e['quantidade'] ?? '').toString(),
            ]);
          }
        }
      }
      final csv = rows.map((r) => r.map(_escaparCsv).join(',')).join('\n');
      setState(() => _csv = csv);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao exportar: $e')));
      }
    } finally {
      if (mounted) setState(() => _gerando = false);
    }
  }

  String _escaparCsv(String v) {
    final needs = v.contains(',') || v.contains('"') || v.contains('\n');
    var s = v.replaceAll('"', '""');
    if (needs) s = '"' + s + '"';
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Exportar entradas com distribuição'),
      content: SizedBox(
        width: 700,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _DateField(
                      label: 'Início',
                      date: _inicio,
                      onPick: (d) => setState(() => _inicio = d),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DateField(
                      label: 'Fim',
                      date: _fim,
                      onPick: (d) => setState(() => _fim = d),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _fornecedorCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Fornecedor (opcional)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _insumoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Insumo (opcional - filtro client side)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _gerando ? null : _gerar,
                    child: _gerando
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Gerar'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_csv != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            if (_csv == null) return;
                            await Clipboard.setData(ClipboardData(text: _csv!));
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'CSV copiado para a área de transferência.',
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.copy),
                          label: const Text('Copiar CSV'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          _csv!,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.date,
    required this.onPick,
  });
  final String label;
  final DateTime date;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (d != null) onPick(d);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(
          '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
        ),
      ),
    );
  }
}
