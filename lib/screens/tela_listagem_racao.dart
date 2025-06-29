import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/app_scaffold.dart';

class TelaListagemRacao extends StatefulWidget {
  const TelaListagemRacao({super.key});

  @override
  State<TelaListagemRacao> createState() => _TelaListagemRacaoState();
}

class _TelaListagemRacaoState extends State<TelaListagemRacao> {
  String? filtroTipo;
  String? filtroCodigo;
  DateTime? dataInicio;
  DateTime? dataFim;
  Map<String, String> _mapaDestino = {};

  @override
  void initState() {
    super.initState();
    _carregarDestinos();
    dataInicio = null;
    dataFim = null;
  }

  Future<void> _carregarDestinos() async {
    final mapa = <String, String>{};
    final snapViveiros = await FirebaseFirestore.instance.collection('viveiros').get();
    for (final doc in snapViveiros.docs) {
      final data = doc.data();
      mapa[data['codigo']] = data['nome'];
    }
    final snapBercarios = await FirebaseFirestore.instance.collection('bercarios').get();
    for (final doc in snapBercarios.docs) {
      final data = doc.data();
      mapa[data['codigo']] = data['nome'];
    }
    setState(() => _mapaDestino = mapa);
  }

  Query _montarConsultaComFallback() {
    final col = FirebaseFirestore.instance.collection('racao');
    Query query = col;
    try {
      if (filtroTipo != null) {
        query = query.where('tipoDestino', isEqualTo: filtroTipo);
      }
      if (filtroCodigo != null) {
        query = query.where('codigo', isEqualTo: filtroCodigo);
      }
      if (dataInicio != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(dataInicio!));
      }
      if (dataFim != null) {
        query = query.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(dataFim!));
      }
      return query.orderBy('timestamp', descending: true);
    } catch (e) {
      return col.orderBy('timestamp', descending: true);
    }
  }

  String _rotuloData(DateTime data) {
    final hoje = DateTime.now();
    final ontem = hoje.subtract(const Duration(days: 1));
    final dataBase = DateTime(data.year, data.month, data.day);
    final hojeBase = DateTime(hoje.year, hoje.month, hoje.day);
    final ontemBase = DateTime(ontem.year, ontem.month, ontem.day);

    if (dataBase == hojeBase) return 'Hoje';
    if (dataBase == ontemBase) return 'Ontem';
    return DateFormat("EEEE, d 'de' MMMM 'de' y", 'pt_BR').format(data);
  }

  void _mostrarDetalhesRacao(Map<String, dynamic> data) {
    final dt = (data['timestamp'] as Timestamp).toDate();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Detalhes da Ração'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Destino: ${data['viveiro'] ?? data['codigo'] ?? '—'}'),
            Text('Código: ${data['codigo'] ?? '—'}'),
            Text('Quantidade: ${data['quantidade'] is int ? data['quantidade'] : (data['quantidade'] % 1 == 0 ? data['quantidade'].toInt() : data['quantidade'].toStringAsFixed(1))} kg'),
            Text('Sobras: ${data['sobras'] is int ? data['sobras'] : (data['sobras'] % 1 == 0 ? data['sobras'].toInt() : data['sobras'].toStringAsFixed(1))} kg'),
            Text('Observações: ${data['observacoes'] ?? '—'}'),
            Text('Data/Hora: ${DateFormat('dd/MM/yyyy HH:mm').format(dt)}'),
            Text('Registrado por: ${data.containsKey('registradoPor') ? data['registradoPor'] : '—'}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
        ],
      ),
    );
  }

  Future<void> _confirmarExclusaoRacao(String id) async {
    // Primeiro diálogo de confirmação
    final confirm1 = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir registro?'),
        content: const Text('Você tem certeza que deseja excluir este registro de ração?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continuar')),
        ],
      ),
    );
    if (confirm1 != true) return;

    // Segundo diálogo de confirmação
    final confirm2 = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirma exclusão?'),
        content: const Text('Esta ação é irreversível. Deseja realmente excluir?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Não')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm2 == true) {
      await FirebaseFirestore.instance.collection('racao').doc(id).delete();
      if (!mounted) return;
      // Mostra um dialog mais visível após exclusão
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Feito!'),
          content: const Text('Registro excluído com sucesso.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final registrosRef = _montarConsultaComFallback();
    return AppScaffold(
      title: 'Histórico de Ração',
      body: Column(
        children: [
          Container(
            color: const Color(0xFFDFFBE5),
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: filtroTipo,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de Destino',
                    prefixIcon: Icon(Icons.category_rounded), // ícone mais moderno
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'viveiro', child: Text('Viveiro')),
                    DropdownMenuItem(value: 'bercario', child: Text('Berçário')),
                  ],
                  onChanged: (value) => setState(() {
                    filtroTipo = value;
                    filtroCodigo = null;
                  }),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: filtroCodigo,
                  decoration: const InputDecoration(
                    labelText: 'Filtrar por Código',
                    prefixIcon: Icon(Icons.search_rounded), // ícone mais moderno
                    border: OutlineInputBorder(),
                  ),
                  items: _mapaDestino.entries
                      .where((e) {
                        final isBercario = e.key.toLowerCase().contains('b');
                        return filtroTipo == 'bercario' ? isBercario : !isBercario;
                      })
                      .map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Text('${e.value} (cód: ${e.key})'),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => filtroCodigo = value),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.calendar_month_rounded), // ícone moderno para data início
                        label: Text(dataInicio == null
                            ? 'Data início'
                            : DateFormat('dd/MM/yyyy').format(dataInicio!)),
                        onPressed: () async {
                          final selecionada = await showDatePicker(
                            context: context,
                            initialDate: dataInicio ?? DateTime.now(),
                            firstDate: DateTime(2024),
                            lastDate: DateTime.now(),
                          );
                          if (selecionada != null) {
                            setState(() {
                              dataInicio = DateTime(selecionada.year, selecionada.month, selecionada.day);
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.event_rounded), // ícone moderno para data fim
                        label: Text(dataFim == null
                            ? 'Data fim'
                            : DateFormat('dd/MM/yyyy').format(dataFim!)),
                        onPressed: () async {
                          final selecionada = await showDatePicker(
                            context: context,
                            initialDate: dataFim ?? DateTime.now(),
                            firstDate: DateTime(2024),
                            lastDate: DateTime.now(),
                          );
                          if (selecionada != null) {
                            setState(() {
                              dataFim = DateTime(selecionada.year, selecionada.month, selecionada.day, 23, 59);
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  icon: const Icon(Icons.filter_alt_off_rounded), // ícone moderno para limpar filtros
                  label: const Text('Limpar Filtros'),
                  onPressed: () {
                    setState(() {
                      filtroTipo = null;
                      filtroCodigo = null;
                      dataInicio = null;
                      dataFim = null;
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: registrosRef.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('Nenhum registro encontrado.'));
                }

                final registrosPorData = <String, List<QueryDocumentSnapshot>>{};
                for (var doc in docs) {
                  final data = (doc['timestamp'] as Timestamp).toDate();
                  final chave = _rotuloData(data);
                  registrosPorData.putIfAbsent(chave, () => []).add(doc);
                }

                return ListView(
                  children: registrosPorData.entries.expand((entry) {
                    return [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(entry.key,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                      ...entry.value.map((doc) {
                        final data = doc['timestamp'].toDate();
                        final dataMap = doc.data() as Map<String, dynamic>;
                        final destino = dataMap['viveiro'] ?? dataMap['codigo'] ?? '—';
                        final por = dataMap.containsKey('registradoPor') ? dataMap['registradoPor'] : '—';
                        final qtd = dataMap['quantidade'];
                        final sobras = dataMap['sobras'];

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                          child: ListTile(
                            onTap: () => _mostrarDetalhesRacao(dataMap),
                            leading: const Icon(Icons.fastfood_rounded, color: Colors.teal), // ícone moderno para ração
                            title: Text(destino, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_month_rounded, size: 16, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text('Data: ${DateFormat('dd/MM/yyyy HH:mm').format(data)}'),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.person_rounded, size: 16, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text('Por: $por', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.scale_rounded, size: 16, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text('Quantidade: ${qtd is int ? qtd : (qtd % 1 == 0 ? qtd.toInt() : qtd.toStringAsFixed(1))} kg'),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.recycling_rounded, size: 16, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text('Sobras: ${sobras is int ? sobras : (sobras % 1 == 0 ? sobras.toInt() : sobras.toStringAsFixed(1))} kg', style: const TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ],
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'detalhes') {
                                  _mostrarDetalhesRacao(dataMap);
                                } else if (value == 'excluir') {
                                  _confirmarExclusaoRacao(doc.id);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'detalhes',
                                  child: ListTile(
                                    leading: Icon(Icons.info_rounded), // ícone moderno
                                    title: Text('Detalhes'),
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'excluir',
                                  child: ListTile(
                                    leading: Icon(Icons.delete_forever_rounded, color: Colors.red), // ícone moderno
                                    title: Text('Excluir'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ];
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}