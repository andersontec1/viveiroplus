import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/app_scaffold.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/degrade_fundo.dart';
import '../helpers/confirmation_helper.dart';
import 'tela_editar_registro_analise.dart';

class TelaListagemRegistros extends StatefulWidget {
  const TelaListagemRegistros({super.key});

  @override
  State<TelaListagemRegistros> createState() => _TelaListagemRegistrosState();
}

class _TelaListagemRegistrosState extends State<TelaListagemRegistros> {
  String? _tipoSelecionado;
  String? _codigoSelecionado;
  DateTime? _dataInicio;
  DateTime? _dataFim;
  Map<String, String> _viveiros = {};
  Map<String, String> _bercarios = {};
  String _funcaoUsuario = '';
  bool _carregado = false;

  @override
  void initState() {
    super.initState();
    _carregarTudo();
  }

  Future<void> _carregarTudo() async {
    await _carregarDestinos();
    await _carregarFuncaoUsuario();
    setState(() => _carregado = true);
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
      
      print('DEBUG LISTAGEM: Viveiros carregados: $_viveiros');
      print('DEBUG LISTAGEM: Berçários carregados: $_bercarios');
    } catch (e) {
      print('DEBUG LISTAGEM: Erro ao carregar destinos: $e');
    }
  }

  Future<void> _selecionarData({required bool inicio}) async {
    final selecionada = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('pt', 'BR'),
    );
    if (selecionada != null) {
      setState(() {
        if (inicio) {
          _dataInicio = selecionada;
        } else {
          _dataFim = selecionada.add(const Duration(hours: 23, minutes: 59));
        }
      });
    }
  }

  Future<void> _confirmarExclusao(String id) async {
    // Usa o helper padrão de confirmação
    final confirmado = await ConfirmationHelper.showDoubleConfirmation(
      context: context,
      title: 'Excluir registro?',
      content: 'Você tem certeza que deseja excluir este registro de análise?',
      secondTitle: 'Confirma exclusão?',
      secondContent: 'Esta ação é irreversível. Deseja realmente excluir?',
      actionLabel: 'Excluir',
      actionColor: Colors.red,
    );

    if (!confirmado) return;

    try {
      // Mostra loading
      if (!mounted) return;
      ConfirmationHelper.showLoading(
        context: context,
        message: 'Excluindo registro...',
      );

      // Executa a exclusão
      await FirebaseFirestore.instance.collection('registros_diarios').doc(id).delete();
      
      if (!mounted) return;
      Navigator.pop(context); // Remove o loading
      
      // Mostra sucesso
      await ConfirmationHelper.showSuccess(
        context: context,
        title: 'Excluído com sucesso!',
        content: 'O registro de análise foi removido permanentemente.',
      );
    } catch (e) {
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

  void _mostrarDetalhes(Map<String, dynamic> data) {
    final dt = (data['dataHora'] as Timestamp).toDate();
    Widget paramDetalhe(String label, String campo, String unidade, {String? ideal}) {
      final valor = data[campo];
      final fora = _foraDoIdeal(campo, valor);
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: fora ? Colors.red.shade50 : Colors.teal.shade50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (fora)
              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
            if (!fora)
              const Icon(Icons.check_circle, color: Colors.teal, size: 18),
            const SizedBox(width: 6),
            Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
              valor != null ? valor.toString() : '—',
              style: TextStyle(
                color: fora ? Colors.red : Colors.teal.shade900,
                fontWeight: fora ? FontWeight.bold : FontWeight.w600,
              ),
            ),
            if (unidade.isNotEmpty) Text(' $unidade'),
            if (fora && ideal != null)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text('(Ideal: $ideal)', style: const TextStyle(color: Colors.teal, fontSize: 12)),
              ),
          ],
        ),
      );
    }
    final editadoPor = data['editadoPor'];
    final editadoEm = data['editadoEm'];
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Container(
          padding: const EdgeInsets.all(0),
          constraints: const BoxConstraints(maxHeight: 600), // Limita a altura máxima
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFB2DFDB),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                ),
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: const Column(
                  children: [
                    Icon(Icons.analytics, color: Colors.teal, size: 38),
                    SizedBox(height: 6),
                    Text('Detalhes do Registro', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
              ),
              Expanded( // Permite que o conteúdo expand e seja scrollable
                child: SingleChildScrollView( // Adiciona scroll quando necessário
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Destino: ${data['nome'] ?? '—'}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('Código: ${data['codigo'] ?? '—'}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      paramDetalhe('pH da Água', 'ph', '', ideal: '7.5 – 8.5'),
                      paramDetalhe('Oxigênio Dissolvido', 'oxigenio', 'mg/L', ideal: '5.0 – 8.0'),
                      paramDetalhe('Temperatura (°C)', 'temperatura', '°C', ideal: '28.0 – 32.0'),
                      paramDetalhe('Turbidez (NTU)', 'turbidez', 'NTU', ideal: '0 – 50'),
                      paramDetalhe('Porcentagem de Saturação (%)', 'saturacao_percentual', '%', ideal: '80 – 120'),
                      paramDetalhe('Saturação de O2 Dissolvido (%)', 'saturacao_oxigenio', '%', ideal: '80 – 120'),
                      paramDetalhe('Salinidade (ppt)', 'salinidade', 'ppt', ideal: '15.0 – 25.0'),
                      paramDetalhe('Cálcio (mg/L)', 'calcio', 'mg/L', ideal: '100 – 300'),
                      paramDetalhe('Nitrito (mg/L)', 'nitrito', 'mg/L', ideal: '≤ 1.0'),
                      paramDetalhe('Amônia (mg/L)', 'amonia', 'mg/L', ideal: '≤ 0.5'),
                      // Removidos: alcalinidade, dureza, transparência
                      const SizedBox(height: 14),
                      const Divider(),
                      const SizedBox(height: 6),
                      const Text('Observações:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(data['observacoes'] ?? '—', style: const TextStyle(fontStyle: FontStyle.italic)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 16, color: Colors.teal),
                          const SizedBox(width: 4),
                          Text('Data/Hora: ${DateFormat('dd/MM/yyyy HH:mm').format(dt)}'),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.person, size: 16, color: Colors.teal),
                          const SizedBox(width: 4),
                          Text('Registrado por: ${data['registradoPor'] ?? '—'}'),
                        ],
                      ),
                      if (editadoPor != null && editadoPor.toString().isNotEmpty)
                        Row(
                          children: [
                            const Icon(Icons.edit, size: 16, color: Colors.deepOrange),
                            const SizedBox(width: 4),
                            Text('Editado por: $editadoPor', style: const TextStyle(color: Colors.deepOrange)),
                            if (editadoEm != null)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Text(
                                  'em: '
                                  '${editadoEm is Timestamp ? DateFormat('dd/MM/yyyy HH:mm').format(editadoEm.toDate()) : editadoEm.toString()}',
                                  style: const TextStyle(color: Colors.deepOrange, fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fechar', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      )
    );
  }

  void _editarRegistro(String docId, Map<String, dynamic> data) {
    if (!['admin', 'gerente', 'supervisor'].contains(_funcaoUsuario)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Você não tem permissão para editar este registro.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TelaEditarRegistroAnalise(
          docId: docId,
          data: data,
          onSalvo: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Registro atualizado com sucesso!')),
            );
          },
        ),
      ),
    );
  }

  bool _foraDoIdeal(String campo, dynamic valor) {
    if (valor == null) return false;
    final val = double.tryParse(valor.toString());
    if (val == null) return false;
    switch (campo) {
      case 'ph':
        return val < 7.5 || val > 8.5;
      case 'oxigenio':
        return val < 5.0 || val > 8.0;
      case 'temperatura':
        return val < 28.0 || val > 32.0;
      case 'turbidez':
        return val < 0.0 || val > 50.0;
      case 'saturacao_percentual':
        return val < 80.0 || val > 120.0;
      case 'saturacao_oxigenio':
        return val < 80.0 || val > 120.0;
      case 'salinidade':
        return val < 15.0 || val > 25.0;
      case 'calcio':
        return val < 100.0 || val > 300.0;
      case 'nitrito':
        return val > 1.0;
      case 'amonia':
        return val > 0.5;
      case 'alcalinidade':
        return val < 80.0 || val > 120.0;
      case 'dureza':
        return val < 50.0 || val > 150.0;
      case 'transparencia':
        return val < 30.0 || val > 40.0;
      default:
        return false;
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

  @override
  Widget build(BuildContext context) {
    if (!_carregado) {
      return const AppScaffold(
        title: 'Registros de Análise',
        body: DegradeFundo(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    Query registrosRef = FirebaseFirestore.instance.collection('registros_diarios');

    if (_tipoSelecionado != null) {
      registrosRef = registrosRef.where('tipoDestino', isEqualTo: _tipoSelecionado);
    }
    if (_codigoSelecionado != null) {
      registrosRef = registrosRef.where('codigo', isEqualTo: _codigoSelecionado);
    }
    if (_dataInicio != null) {
      registrosRef = registrosRef.where('dataHora', isGreaterThanOrEqualTo: Timestamp.fromDate(_dataInicio!));
    }
    if (_dataFim != null) {
      registrosRef = registrosRef.where('dataHora', isLessThanOrEqualTo: Timestamp.fromDate(_dataFim!));
    }

    registrosRef = registrosRef.orderBy('dataHora', descending: true);

    return AppScaffold(
      title: 'Registros de Análise',
      body: DegradeFundo(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _tipoSelecionado,
                    decoration: const InputDecoration(
                      labelText: 'Tipo',
                      prefixIcon: Icon(Icons.category),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'viveiro', child: Text('Viveiro')),
                      DropdownMenuItem(value: 'bercario', child: Text('Berçário')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _tipoSelecionado = value;
                        _codigoSelecionado = null;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _codigoSelecionado,
                    decoration: const InputDecoration(
                      labelText: 'Filtrar por Código',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    items: (() {
                      List<DropdownMenuItem<String>> items = [];
                      
                      if (_tipoSelecionado == 'viveiro') {
                        // Mostrar apenas viveiros
                        final viveirosSorted = _viveiros.entries.toList()
                          ..sort((a, b) => a.key.compareTo(b.key));
                        
                        items = viveirosSorted
                            .map((e) => DropdownMenuItem<String>(
                                  value: e.key,
                                  child: Text('${e.value} (${e.key})'),
                                ))
                            .toList();
                      } else if (_tipoSelecionado == 'bercario') {
                        // Mostrar apenas berçários
                        final bercariosSorted = _bercarios.entries.toList()
                          ..sort((a, b) => a.key.compareTo(b.key));
                        
                        items = bercariosSorted
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
                    onChanged: (value) => setState(() => _codigoSelecionado = value),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.date_range),
                          label: Text(_dataInicio == null
                              ? 'Data início'
                              : DateFormat('dd/MM/yyyy').format(_dataInicio!)),
                          onPressed: () => _selecionarData(inicio: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.event),
                          label: Text(_dataFim == null
                              ? 'Data fim'
                              : DateFormat('dd/MM/yyyy').format(_dataFim!)),
                          onPressed: () => _selecionarData(inicio: false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.filter_alt_off),
                    label: const Text('Limpar Filtros'),
                    onPressed: () {
                      setState(() {
                        _tipoSelecionado = null;
                        _codigoSelecionado = null;
                        _dataInicio = null;
                        _dataFim = null;
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

                  // Agrupa por data usando o rotulo bonito
                  final registrosPorData = <String, List<QueryDocumentSnapshot>>{};
                  for (var doc in docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final dt = (data['dataHora'] as Timestamp).toDate();
                    final chave = _rotuloData(dt);
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
                          final data = doc.data() as Map<String, dynamic>;
                          final dt = (data['dataHora'] as Timestamp).toDate();
                          final destino = data['nome'] ?? data['codigo'] ?? '—';
                          final por = data['registradoPor'] ?? '—';

                          // Checagem de todos os parâmetros relevantes para chips de alerta
                          final chips = <Widget>[];
                          void addChip(bool cond, String label, Color color) {
                            if (cond) {
                              chips.add(Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Chip(label: Text(label), backgroundColor: color, labelStyle: const TextStyle(color: Colors.white)),
                              ));
                            }
                          }
                          addChip(_foraDoIdeal('ph', data['ph']), 'pH fora', Colors.redAccent);
                          addChip(_foraDoIdeal('oxigenio', data['oxigenio']), 'O2 fora', Colors.orangeAccent);
                          addChip(_foraDoIdeal('temperatura', data['temperatura']), 'Temp. fora', Colors.deepOrange);
                          addChip(_foraDoIdeal('turbidez', data['turbidez']), 'Turbidez fora', Colors.purple);
                          addChip(_foraDoIdeal('saturacao_percentual', data['saturacao_percentual']), 'Sat. % fora', Colors.blueGrey);
                          addChip(_foraDoIdeal('saturacao_oxigenio', data['saturacao_oxigenio']), 'Sat. O2 fora', Colors.blue);
                          addChip(_foraDoIdeal('salinidade', data['salinidade']), 'Salinidade fora', Colors.teal);
                          addChip(_foraDoIdeal('calcio', data['calcio']), 'Cálcio fora', Colors.green);
                          addChip(_foraDoIdeal('nitrito', data['nitrito']), 'Nitrito fora', Colors.brown);
                          addChip(_foraDoIdeal('amonia', data['amonia']), 'Amônia fora', Colors.indigo);
                          // Removidos: alcalinidade, dureza, transparência

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                            child: ListTile(
                              onTap: () => _mostrarDetalhes(data),
                              leading: const Icon(Icons.analytics, color: Colors.teal),
                              title: Text(destino, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Data: ${DateFormat('dd/MM/yyyy HH:mm').format(dt)}'),
                                  Text('Por: $por', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  if (chips.isNotEmpty)
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(children: chips),
                                    ),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'detalhes') {
                                    _mostrarDetalhes(data);
                                  } else if (value == 'excluir') {
                                    _confirmarExclusao(doc.id);
                                  } else if (value == 'editar') {
                                    _editarRegistro(doc.id, data);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'detalhes',
                                    child: ListTile(
                                      leading: Icon(Icons.info),
                                      title: Text('Detalhes'),
                                    ),
                                  ),
                                  if (_funcaoUsuario == 'admin' || _funcaoUsuario == 'gerente')
                                    const PopupMenuItem(
                                      value: 'editar',
                                      child: ListTile(
                                        leading: Icon(Icons.edit),
                                        title: Text('Editar'),
                                      ),
                                    ),
                                  const PopupMenuItem(
                                    value: 'excluir',
                                    child: ListTile(
                                      leading: Icon(Icons.delete),
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