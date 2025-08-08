import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/degrade_fundo.dart';
import '../helpers/confirmation_helper.dart';
import 'detalhes_racao_dialog.dart';
import 'tela_editar_racao.dart';

class TelaListagemRacao extends StatefulWidget {
  const TelaListagemRacao({super.key});

  @override
  State<TelaListagemRacao> createState() => _TelaListagemRacaoState();
}

class _TelaListagemRacaoState extends State<TelaListagemRacao> {
  bool _carregado = false;
  String? filtroTipo;
  String? filtroCodigo;
  DateTime? dataInicio;
  DateTime? dataFim;
  Map<String, String> _viveiros = {};
  Map<String, String> _bercarios = {};
  String _funcaoUsuario = '';

  @override
  void initState() {
    super.initState();
    _carregarTudo();
    dataInicio = null;
    dataFim = null;

  }

  Future<void> _carregarTudo() async {
    await _carregarDestinos();
    await _carregarFuncaoUsuario();
    setState(() => _carregado = true);
  }

  Future<void> _carregarDestinos() async {
    try {
      // Carregar viveiros
      final snapshotViveiros = await FirebaseFirestore.instance.collection('viveiros').get();
      final viveiros = <String, String>{};
      for (final doc in snapshotViveiros.docs) {
        final data = doc.data();
        final codigo = data['codigo']?.toString() ?? '';
        final nome = data['nome']?.toString() ?? '';
        if (codigo.isNotEmpty && nome.isNotEmpty) {
          viveiros[codigo] = nome;
        }
      }
      
      // Carregar berçários
      final snapshotBercarios = await FirebaseFirestore.instance.collection('bercarios').get();
      final bercarios = <String, String>{};
      for (final doc in snapshotBercarios.docs) {
        final data = doc.data();
        final codigo = data['codigo']?.toString() ?? '';
        final nome = data['nome']?.toString() ?? '';
        if (codigo.isNotEmpty && nome.isNotEmpty) {
          bercarios[codigo] = nome;
        }
      }
      
      setState(() {
        _viveiros = viveiros;
        _bercarios = bercarios;
      });
      
      print('DEBUG: Viveiros carregados: $_viveiros');
      print('DEBUG: Berçários carregados: $_bercarios');
    } catch (e) {
      print('DEBUG: Erro ao carregar destinos: $e');
    }
  }

  Future<void> _carregarFuncaoUsuario() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snap = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      setState(() {
        _funcaoUsuario = snap.data()?['funcao'] ?? '';
      });
    }
  }

  Query _montarConsultaComFallback() {
    final col = FirebaseFirestore.instance.collection('racao');
    Query query = col;
    
    print('DEBUG: Filtros aplicados - Tipo: $filtroTipo, Código: $filtroCodigo');
    
    try {
      if (filtroTipo != null && filtroTipo!.isNotEmpty) {
        query = query.where('tipoDestino', isEqualTo: filtroTipo);
        print('DEBUG: Filtro por tipo aplicado: $filtroTipo');
      }
      
      if (filtroCodigo != null && filtroCodigo!.isNotEmpty) {
        query = query.where('codigo', isEqualTo: filtroCodigo);
        print('DEBUG: Filtro por código aplicado: $filtroCodigo');
      }
      
      if (dataInicio != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(dataInicio!));
        print('DEBUG: Filtro por data início aplicado: $dataInicio');
      }
      
      if (dataFim != null) {
        query = query.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(dataFim!));
        print('DEBUG: Filtro por data fim aplicado: $dataFim');
      }
      
      return query.orderBy('timestamp', descending: true);
    } catch (e) {
      print('DEBUG: Erro na consulta, retornando consulta simples: $e');
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
    showDialog(
      context: context,
      builder: (_) => DetalhesRacaoDialog(data: data),
    );
  }

  Future<void> _confirmarExclusaoRacao(String id) async {
    print('DEBUG: Iniciando exclusão para ID: $id');
    
    // Usa o helper padrão de confirmação
    final confirmado = await ConfirmationHelper.showDoubleConfirmation(
      context: context,
      title: 'Excluir registro?',
      content: 'Você tem certeza que deseja excluir este registro de ração?',
      secondTitle: 'Confirma exclusão?',
      secondContent: 'Esta ação é irreversível. Deseja realmente excluir?',
      actionLabel: 'Excluir',
      actionColor: Colors.red,
    );

    if (!confirmado) {
      print('DEBUG: Usuário cancelou a exclusão');
      return;
    }

    print('DEBUG: Usuário confirmou exclusão, executando...');
    
    try {
      // Mostra loading
      if (!mounted) return;
      ConfirmationHelper.showLoading(
        context: context,
        message: 'Excluindo registro...',
      );

      // Executa a exclusão
      print('DEBUG: Tentando excluir documento com ID: $id');
      await FirebaseFirestore.instance.collection('racao').doc(id).delete();
      print('DEBUG: Documento excluído com sucesso do Firebase');
      
      if (!mounted) return;
      Navigator.pop(context); // Remove o loading
      
      // Mostra sucesso
      await ConfirmationHelper.showSuccess(
        context: context,
        title: 'Excluído com sucesso!',
        content: 'O registro de ração foi removido permanentemente.',
      );
    } catch (e) {
      print('DEBUG: Erro durante a exclusão: $e');
      if (!mounted) return;
      Navigator.pop(context); // Remove o loading se ainda estiver ativo
      
      // Mostra erro
      await ConfirmationHelper.showError(
        context: context,
        title: 'Erro na exclusão',
        content: 'Não foi possível excluir o registro.',
        error: e.toString(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_carregado) {
      return const AppScaffold(
        title: 'Histórico de Ração',
        body: DegradeFundo(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final registrosRef = _montarConsultaComFallback();
    return AppScaffold(
      title: 'Histórico de Ração',
      body: DegradeFundo(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Icons.set_meal, size: 56, color: Colors.teal),
                      SizedBox(height: 8),
                      Text(
                        'Histórico de Ração',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Consulte todos os registros de ração lançados nos viveiros e berçários',
                        style: TextStyle(fontSize: 15, color: Colors.teal, fontWeight: FontWeight.w400),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: filtroTipo,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de Destino',
                      prefixIcon: Icon(Icons.category_rounded),
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
                      prefixIcon: Icon(Icons.search_rounded),
                      border: OutlineInputBorder(),
                    ),
                    items: (() {
                      List<DropdownMenuItem<String>> items = [];
                      
                      if (filtroTipo == 'viveiro') {
                        // Mostrar apenas viveiros
                        final destinosOrdenados = _viveiros.entries.toList()
                          ..sort((a, b) => a.key.compareTo(b.key));
                        
                        items = destinosOrdenados
                            .map((e) => DropdownMenuItem<String>(
                                  value: e.key,
                                  child: Text('${e.value} (${e.key})'),
                                ))
                            .toList();
                      } else if (filtroTipo == 'bercario') {
                        // Mostrar apenas berçários
                        final destinosOrdenados = _bercarios.entries.toList()
                          ..sort((a, b) => a.key.compareTo(b.key));
                        
                        items = destinosOrdenados
                            .map((e) => DropdownMenuItem<String>(
                                  value: e.key,
                                  child: Text('${e.value} (${e.key})'),
                                ))
                            .toList();
                      } else {
                        // Se nenhum tipo selecionado, mostrar todos mas separados
                        final viveiroItems = _viveiros.entries
                            .map((e) => DropdownMenuItem<String>(
                                  value: e.key,
                                  child: Text('Viveiro ${e.value} (${e.key})'),
                                ))
                            .toList();
                        
                        final bercarioItems = _bercarios.entries
                            .map((e) => DropdownMenuItem<String>(
                                  value: e.key,
                                  child: Text('Berçário ${e.value} (${e.key})'),
                                ))
                            .toList();
                        
                        items = [...viveiroItems, ...bercarioItems];
                        items.sort((a, b) => a.value!.compareTo(b.value!));
                      }
                      
                      return items;
                    })(),
                    onChanged: (value) => setState(() => filtroCodigo = value),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.calendar_month_rounded),
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
                          icon: const Icon(Icons.event_rounded),
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
                    icon: const Icon(Icons.filter_alt_off_rounded),
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
                              leading: const Icon(Icons.set_meal, color: Colors.teal),
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
                                  if (dataMap['probióticoAplicado'] != null)
                                    Row(
                                      children: [
                                        const Icon(Icons.medical_services_rounded, size: 16, color: Colors.green),
                                        const SizedBox(width: 4),
                                        Text('Probiótico: ${dataMap['probióticoAplicado']}', style: const TextStyle(fontSize: 13)),
                                      ],
                                    ),
                                  if (dataMap['suplementoAplicado'] != null)
                                    Row(
                                      children: [
                                        const Icon(Icons.add_box_rounded, size: 16, color: Colors.blue),
                                        const SizedBox(width: 4),
                                        Text('Suplemento: ${dataMap['suplementoAplicado']}', style: const TextStyle(fontSize: 13)),
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
                                  } else if (value == 'editar') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => TelaEditarRacao(
                                          docId: doc.id,
                                          data: dataMap,
                                          onSalvo: () {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Registro de ração atualizado com sucesso!')),
                                            );
                                          },
                                        ),
                                      ),
                                    );
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'detalhes',
                                    child: ListTile(
                                      leading: Icon(Icons.info_rounded),
                                      title: Text('Detalhes'),
                                    ),
                                  ),
                                  if (['admin', 'gerente', 'supervisor'].contains(_funcaoUsuario))
                                    const PopupMenuItem(
                                      value: 'editar',
                                      child: ListTile(
                                        leading: Icon(Icons.edit_rounded, color: Colors.teal),
                                        title: Text('Editar'),
                                      ),
                                    ),
                                  const PopupMenuItem(
                                    value: 'excluir',
                                    child: ListTile(
                                      leading: Icon(Icons.delete_forever_rounded, color: Colors.red),
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
      ),
    );
  }
}