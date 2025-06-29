import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/app_scaffold.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/degrade_fundo.dart'; // adicione este import

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
  Map<String, String> _destinos = {}; // código → nome
  String _funcaoUsuario = '';

  @override
  void initState() {
    super.initState();
    _carregarDestinos();
    _carregarFuncaoUsuario();
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
    final mapa = <String, String>{};
    final snapshotViveiros = await FirebaseFirestore.instance.collection('viveiros').get();
    for (final doc in snapshotViveiros.docs) {
      final data = doc.data();
      mapa[data['codigo']] = data['nome'];
    }
    final snapshotBercarios = await FirebaseFirestore.instance.collection('bercarios').get();
    for (final doc in snapshotBercarios.docs) {
      final data = doc.data();
      mapa[data['codigo']] = data['nome'];
    }
    setState(() => _destinos = mapa);
  }

  Future<void> _selecionarData({required bool inicio}) async {
    final selecionada = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
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
    // Primeiro diálogo de confirmação
    final confirm1 = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir registro?'),
        content: const Text('Você tem certeza que deseja excluir este registro?'),
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
      await FirebaseFirestore.instance.collection('registros_diarios').doc(id).delete();
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Sucesso!'),
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

  void _mostrarDetalhes(Map<String, dynamic> data) {
    final dt = (data['dataHora'] as Timestamp).toDate();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Detalhes do Registro'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Destino: ${data['nome'] ?? '—'}'),
            Text('Código: ${data['codigo'] ?? '—'}'),
            Text('pH: ${data['ph']}'),
            Text('Oxigênio: ${data['oxigenio']} mg/L'),
            Text('Temperatura: ${data['temperatura']} °C'),
            if (data['salinidade'] != null) Text('Salinidade: ${data['salinidade']} ppt'),
            Text('Observações: ${data['observacoes'] ?? '—'}'),
            Text('Data/Hora: ${DateFormat('dd/MM/yyyy HH:mm').format(dt)}'),
            Text('Registrado por: ${data['registradoPor'] ?? '—'}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
        ],
      ),
    );
  }

  void _editarRegistro(String docId, Map<String, dynamic> data) {
    // Implemente aqui a navegação para tela de edição, se desejar.
    // Exemplo: Navigator.push(context, MaterialPageRoute(builder: (_) => TelaEditarRegistro(...)));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Funcionalidade de edição não implementada.')),
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
    }
    return false;
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
                    items: _destinos.entries
                        .where((e) {
                          final isBercario = e.key.toLowerCase().contains('b');
                          return _tipoSelecionado == 'bercario' ? isBercario : !isBercario;
                        })
                        .map((e) => DropdownMenuItem(
                              value: e.key,
                              child: Text('${e.value} (cód: ${e.key})'),
                            ))
                        .toList(),
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

                          final phAlerta = _foraDoIdeal('ph', data['ph']);
                          final oxAlerta = _foraDoIdeal('oxigenio', data['oxigenio']);
                          final tempAlerta = _foraDoIdeal('temperatura', data['temperatura']);

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
                                  Row(
                                    children: [
                                      if (phAlerta)
                                        const Padding(
                                          padding: EdgeInsets.only(right: 8),
                                          child: Chip(label: Text('pH fora'), backgroundColor: Colors.redAccent, labelStyle: TextStyle(color: Colors.white)),
                                        ),
                                      if (oxAlerta)
                                        const Padding(
                                          padding: EdgeInsets.only(right: 8),
                                          child: Chip(label: Text('O2 fora'), backgroundColor: Colors.orangeAccent, labelStyle: TextStyle(color: Colors.white)),
                                        ),
                                      if (tempAlerta)
                                        const Chip(label: Text('Temp. fora'), backgroundColor: Colors.deepOrange, labelStyle: TextStyle(color: Colors.white)),
                                    ],
                                  )
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