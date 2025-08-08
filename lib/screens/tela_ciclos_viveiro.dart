// Tela Ciclos por Viveiro - com edição e histórico
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/degrade_fundo.dart';

class TelaCiclosViveiro extends StatefulWidget {
  const TelaCiclosViveiro({super.key});

  @override
  State<TelaCiclosViveiro> createState() => _TelaCiclosViveiroState();
}

class _TelaCiclosViveiroState extends State<TelaCiclosViveiro> {
  final _formKey = GlobalKey<FormState>();
  final _qtdCtrl = TextEditingController();
  final _pesoCtrl = TextEditingController();
  final _pesoFinalCtrl = TextEditingController();
  String? _codigoSelecionado;
  DateTime _dataInicio = DateTime.now();
  Map<String, String> _destinos = {};
  bool _salvando = false;
  String? _idEditando;

  int _mostrarApenasAbertos = 1; // 1: em andamento, 2: encerrados, 0: todos

  DateTime? _previsaoEncerramento;

  @override
  void initState() {
    super.initState();
    _carregarDestinos();
  }

  Future<void> _carregarDestinos() async {
    final snap = await FirebaseFirestore.instance.collection('viveiros').get();
    final mapa = <String, String>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      mapa[data['codigo']] = data['nome'];
    }
    setState(() => _destinos = mapa);
  }

  Future<void> _salvarCiclo() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);

    // Validação de datas
    if (_previsaoEncerramento != null && _previsaoEncerramento!.isBefore(_dataInicio)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning, color: Colors.white),
              SizedBox(width: 8),
              Text('⚠️ A previsão de encerramento deve ser após a data de início.'),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      setState(() => _salvando = false);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    final nomeUsuario = user != null
        ? (((await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get()).data()?['nome']) ?? '—')
        : '—';

    final dados = {
      'codigo': _codigoSelecionado,
      'nome': _destinos[_codigoSelecionado] ?? '—',
      'dataInicio': Timestamp.fromDate(_dataInicio),
      'previsaoEncerramento': _previsaoEncerramento != null ? Timestamp.fromDate(_previsaoEncerramento!) : null,
      'quantidadeEstocada': int.parse(_qtdCtrl.text),
      'pesoInicial': double.tryParse(_pesoCtrl.text.replaceAll(',', '.')) ?? 0.0,
    };

    if (_idEditando != null) {
      await FirebaseFirestore.instance.collection('ciclos').doc(_idEditando).update(dados);
    } else {
      final existe = await FirebaseFirestore.instance
          .collection('ciclos')
          .where('codigo', isEqualTo: _codigoSelecionado)
          .where('encerrado', isEqualTo: false)
          .get();
      if (existe.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.info, color: Colors.white),
                SizedBox(width: 8),
                Text('ℹ️ Já existe um ciclo ativo para esse viveiro.'),
              ],
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        setState(() => _salvando = false);
        return;
      }

      await FirebaseFirestore.instance.collection('ciclos').add({
        ...dados,
        'encerrado': false,
        'abertoPor': nomeUsuario,
        'criadoEm': Timestamp.now(),
      });
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('✅ Ciclo salvo com sucesso!'),
          ],
        ),
        backgroundColor: const Color(0xFF049F56),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    setState(() {
      _qtdCtrl.clear();
      _pesoCtrl.clear();
      _codigoSelecionado = null;
      _idEditando = null;
      _salvando = false;
    });
  }

  Future<void> _encerrarCiclo(String id) async {
    final pesoFinal = await showDialog<double?>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final ctrl = TextEditingController();
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.95),
                  Colors.white.withOpacity(0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.red.withOpacity(0.8), Colors.red.withOpacity(0.6)],
                        ),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(Icons.lock, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      '🔒 Encerrar Ciclo',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF045D3A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: ctrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Color(0xFF045D3A)),
                  decoration: InputDecoration(
                    labelText: 'Peso Médio Final (g)',
                    labelStyle: TextStyle(color: const Color(0xFF045D3A).withOpacity(0.7)),
                    prefixIcon: const Icon(Icons.scale, color: Color(0xFF049F56)),
                    filled: true,
                    fillColor: const Color(0xFF049F56).withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: const Color(0xFF049F56).withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: Color(0xFF049F56), width: 2),
                    ),
                  ),
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
                            side: BorderSide(color: Colors.grey.withOpacity(0.3)),
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
                          gradient: LinearGradient(
                            colors: [Colors.red.withOpacity(0.8), Colors.red.withOpacity(0.6)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            final val = double.tryParse(ctrl.text.replaceAll(',', '.'));
                            Navigator.pop(context, val);
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
                            'Encerrar',
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
        );
      },
    );

    if (pesoFinal == null) return;

    final user = FirebaseAuth.instance.currentUser;
    final nomeUsuario = user != null
        ? ((await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get()).data()?['nome'] ?? '—')
        : '—';

    try {
      await FirebaseFirestore.instance.collection('ciclos').doc(id).update({
        'encerrado': true,
        'fechadoPor': nomeUsuario,
        'dataEncerramento': Timestamp.now(),
        'pesoFinal': pesoFinal,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('✅ Ciclo encerrado com sucesso!'),
              ],
            ),
            backgroundColor: const Color(0xFF049F56),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('❌ Erro ao encerrar ciclo: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }
  @override
  void dispose() {
    _qtdCtrl.dispose();
    _pesoCtrl.dispose();
    _pesoFinalCtrl.dispose();
    super.dispose();
  }

  void _carregarParaEdicao(QueryDocumentSnapshot ciclo) {
    setState(() {
      _idEditando = ciclo.id;
      _codigoSelecionado = ciclo['codigo'];
      _qtdCtrl.text = ciclo['quantidadeEstocada'].toString();
      _pesoCtrl.text = ciclo['pesoInicial'].toString();
      _dataInicio = ciclo['dataInicio'].toDate();
      final dataRaw = ciclo.data();
      final data = (dataRaw is Map<String, dynamic>) ? dataRaw : <String, dynamic>{};
      _previsaoEncerramento = data.containsKey('previsaoEncerramento') && data['previsaoEncerramento'] != null
        ? (data['previsaoEncerramento'] as Timestamp).toDate()
        : null;
    });
  }

  Stream<QuerySnapshot> _ciclosStream() {
    var ref = FirebaseFirestore.instance.collection('ciclos').orderBy('dataInicio', descending: true);
    if (_mostrarApenasAbertos == 1) {
      ref = ref.where('encerrado', isEqualTo: false);
    } else if (_mostrarApenasAbertos == 2) {
      ref = ref.where('encerrado', isEqualTo: true);
    }
    return ref.snapshots();
  }

  String _formatarData(DateTime dt) => DateFormat('dd/MM/yyyy').format(dt);

  Widget _buildFilterChip(String label, int value) {
    final isSelected = _mostrarApenasAbertos == value;
    return InkWell(
      onTap: () => setState(() => _mostrarApenasAbertos = value),
      borderRadius: BorderRadius.circular(25),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF045D3A), Color(0xFF049F56)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [
                    Colors.grey[100]!,
                    Colors.grey[50]!,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected 
                ? const Color(0xFF049F56)
                : Colors.grey[300]!,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF045D3A).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF045D3A),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF049F56).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.calendar_today, size: 20, color: Color(0xFF049F56)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Data de Início',
                      style: TextStyle(
                        color: const Color(0xFF045D3A).withOpacity(0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatarData(_dataInicio),
                      style: const TextStyle(
                        color: Color(0xFF045D3A),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_calendar, color: Color(0xFF049F56)),
                onPressed: () async {
                  final novaData = await showDatePicker(
                    context: context,
                    initialDate: _dataInicio,
                    firstDate: DateTime(2022),
                    lastDate: DateTime.now(),
                  );
                  if (novaData != null) {
                    setState(() => _dataInicio = novaData);
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF049F56).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.event, size: 20, color: Color(0xFF049F56)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Previsão de Encerramento',
                      style: TextStyle(
                        color: const Color(0xFF045D3A).withOpacity(0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _previsaoEncerramento != null ? _formatarData(_previsaoEncerramento!) : 'Não definida',
                      style: TextStyle(
                        color: _previsaoEncerramento != null ? const Color(0xFF045D3A) : const Color(0xFF045D3A).withOpacity(0.6),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_calendar, color: Color(0xFF049F56)),
                onPressed: () async {
                  final novaData = await showDatePicker(
                    context: context,
                    initialDate: _previsaoEncerramento ?? DateTime.now(),
                    firstDate: _dataInicio,
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (novaData != null) {
                    setState(() => _previsaoEncerramento = novaData);
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCicloCard(QueryDocumentSnapshot ciclo) {
    final data = ciclo['dataInicio'].toDate();
    final encerrado = ciclo['encerrado'] == true;
    final dataRaw = ciclo.data();
    final dataMap = (dataRaw != null && dataRaw is Map<String, dynamic>) ? dataRaw : <String, dynamic>{};
    final dataEncerramento = (dataMap['dataEncerramento'] != null && dataMap['dataEncerramento'] is Timestamp)
        ? (dataMap['dataEncerramento'] as Timestamp).toDate()
        : null;
    final previsaoEncerramento = (dataMap['previsaoEncerramento'] != null && dataMap['previsaoEncerramento'] is Timestamp)
        ? (dataMap['previsaoEncerramento'] as Timestamp).toDate()
        : null;
    final abertoPor = (dataMap['abertoPor'] != null) ? dataMap['abertoPor'] : '—';
    final fechadoPor = (dataMap['fechadoPor'] != null) ? dataMap['fechadoPor'] : '';
    final pesoFinal = (dataMap['pesoFinal'] != null) ? dataMap['pesoFinal'] : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header do card
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: encerrado
                        ? LinearGradient(
                            colors: [
                              Colors.grey.withOpacity(0.7),
                              Colors.grey.withOpacity(0.5),
                            ],
                          )
                        : const LinearGradient(
                            colors: [Color(0xFF045D3A), Color(0xFF049F56)],
                          ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    encerrado ? Icons.lock : Icons.autorenew,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${ciclo['nome']}',
                        style: const TextStyle(
                          color: Color(0xFF045D3A),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Código: ${ciclo['codigo']}',
                        style: TextStyle(
                          color: const Color(0xFF045D3A).withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: encerrado 
                        ? Colors.grey.withOpacity(0.3)
                        : const Color(0xFF049F56).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: encerrado ? Colors.grey : const Color(0xFF049F56),
                    ),
                  ),
                  child: Text(
                    encerrado ? '🔒 Encerrado' : '🔄 Ativo',
                    style: TextStyle(
                      color: encerrado ? Colors.grey[300] : const Color(0xFF049F56),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Informações principais
            _buildInfoRow('📅 Início', _formatarData(data)),
            if (previsaoEncerramento != null)
              _buildInfoRow('🎯 Previsão', _formatarData(previsaoEncerramento)),
            if (encerrado && dataEncerramento != null)
              _buildInfoRow('🏁 Encerrado', _formatarData(dataEncerramento)),
            _buildInfoRow('🦐 Estocados', '${ciclo['quantidadeEstocada']} pós-larvas'),
            if (ciclo['pesoInicial'] != null && ciclo['pesoInicial'] > 0)
              _buildInfoRow('⚖️ Peso Inicial', '${ciclo['pesoInicial'].toString().replaceAll('.', ',')} g'),
            if (encerrado && pesoFinal != null)
              _buildInfoRow('🎯 Peso Final', '${pesoFinal.toString().replaceAll('.', ',')} g'),
            
            const SizedBox(height: 16),
            
            // Responsáveis
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  _buildInfoRow('👤 Aberto por', abertoPor),
                  if (fechadoPor.isNotEmpty)
                    _buildInfoRow('🔐 Fechado por', fechadoPor),
                ],
              ),
            ),
            
            if (!encerrado) ...[
              const SizedBox(height: 20),
              // Ações
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(
                    '✏️ Editar',
                    Colors.blue,
                    () => _carregarParaEdicao(ciclo),
                  ),
                  _buildActionButton(
                    '➕ Povoar',
                    const Color(0xFF049F56),
                    () => _abrirRegistroPovoamento(context, ciclo),
                  ),
                  _buildActionButton(
                    '🔒 Encerrar',
                    Colors.red,
                    () => _encerrarCiclo(ciclo.id),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: const Color(0xFF045D3A).withOpacity(0.7),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF045D3A),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, Color color, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.8),
              color.withOpacity(0.6),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Ciclos por Viveiro',
      body: DegradeFundo(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Filtros de visualização modernos
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildFilterChip('🔄 Em Andamento', 1),
                      const SizedBox(width: 12),
                      _buildFilterChip('✅ Encerrados', 2),
                      const SizedBox(width: 12),
                      _buildFilterChip('📋 Todos', 0),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Formulário modernizado
                Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF045D3A), Color(0xFF049F56)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.water_damage, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _idEditando != null ? '✏️ Editando Ciclo' : '🆕 Novo Ciclo',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF045D3A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        value: _codigoSelecionado,
                        items: _destinos.entries
                            .map((e) => DropdownMenuItem(
                                  value: e.key,
                                  child: Text('${e.value} (cód: ${e.key})'),
                                ))
                            .toList(),
                        onChanged: (val) => setState(() => _codigoSelecionado = val),
                        decoration: InputDecoration(
                          labelText: 'Viveiro',
                          labelStyle: TextStyle(color: const Color(0xFF045D3A).withOpacity(0.8)),
                          prefixIcon: const Icon(Icons.water_damage, color: Color(0xFF049F56)),
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: const BorderSide(color: Color(0xFF049F56), width: 2),
                          ),
                        ),
                        dropdownColor: Colors.white,
                        style: const TextStyle(color: Color(0xFF045D3A)),
                        validator: (v) => v == null ? 'Selecione o viveiro' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _qtdCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Color(0xFF045D3A)),
                        decoration: InputDecoration(
                          labelText: 'Quantidade Estocada (pós-larvas)',
                          labelStyle: TextStyle(color: const Color(0xFF045D3A).withOpacity(0.8)),
                          prefixIcon: const Icon(Icons.numbers, color: Color(0xFF049F56)),
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: const BorderSide(color: Color(0xFF049F56), width: 2),
                          ),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Informe a quantidade' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _pesoCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: Color(0xFF045D3A)),
                        decoration: InputDecoration(
                          labelText: 'Peso Médio Inicial (g)',
                          labelStyle: TextStyle(color: const Color(0xFF045D3A).withOpacity(0.8)),
                          prefixIcon: const Icon(Icons.scale, color: Color(0xFF049F56)),
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: const BorderSide(color: Color(0xFF049F56), width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildDateSelector(),
                      const SizedBox(height: 24),
                      Center(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF045D3A), Color(0xFF049F56)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF045D3A).withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            icon: _salvando 
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.save, color: Colors.white),
                            label: Text(
                              _salvando ? 'Salvando...' : (_idEditando != null ? 'Atualizar Ciclo' : 'Salvar Ciclo'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            onPressed: _salvando ? null : _salvarCiclo,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF049F56),
                              foregroundColor: Colors.white,
                              shadowColor: Colors.black.withOpacity(0.3),
                              elevation: 5,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Seção de ciclos registrados modernizada
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF045D3A), Color(0xFF049F56)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(Icons.history, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      '📋 Ciclos Registrados',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF045D3A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Lista de ciclos com altura fixa para permitir scroll interno
              Container(
                height: 400, // Altura fixa para a lista
                child: StreamBuilder<QuerySnapshot>(
                  stream: _ciclosStream(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF049F56)),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Carregando ciclos...',
                              style: TextStyle(color: Color(0xFF045D3A)),
                            ),
                          ],
                        ),
                      );
                    }
                    
                    final docs = snapshot.data!.docs;
                    
                    if (docs.isEmpty) {
                      return Center(
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.water_damage_outlined,
                                size: 64,
                                color: const Color(0xFF049F56).withOpacity(0.6),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Nenhum ciclo encontrado',
                                style: TextStyle(
                                  color: Color(0xFF045D3A),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Crie um novo ciclo para começar',
                                style: TextStyle(
                                  color: const Color(0xFF045D3A).withOpacity(0.6),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    
                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) => _buildCicloCard(docs[index]),
                    );
                  },
                ),
              ), // Fecha o Container da lista de ciclos
              const SizedBox(height: 20), // Espaço adicional no final
            ], // Fecha children do Column principal
          ), // Fecha Padding
        ), // Fecha SingleChildScrollView
      ), // Fecha DegradeFundo (body)
    ),
    ); // Fecha AppScaffold
  }

  void _abrirRegistroPovoamento(BuildContext context, QueryDocumentSnapshot ciclo) async {
    final TextEditingController qtdCtrl = TextEditingController();
    final TextEditingController obsCtrl = TextEditingController();
    final user = FirebaseAuth.instance.currentUser;
    final nomeUsuario = user != null
        ? (((await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get()).data()?['nome']) ?? '—')
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
                Colors.white.withOpacity(0.95),
                Colors.white.withOpacity(0.85),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
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
                    child: const Icon(Icons.add_circle, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    '➕ Registro de Povoamento',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF045D3A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF049F56).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: const Color(0xFF049F56).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.water_damage, color: Color(0xFF049F56)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Viveiro: ${ciclo['nome']} (${ciclo['codigo']})',
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
                  labelStyle: TextStyle(color: const Color(0xFF045D3A).withOpacity(0.7)),
                  prefixIcon: const Icon(Icons.numbers, color: Color(0xFF049F56)),
                  filled: true,
                  fillColor: const Color(0xFF049F56).withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: const Color(0xFF049F56).withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: Color(0xFF049F56), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: obsCtrl,
                style: const TextStyle(color: Color(0xFF045D3A)),
                decoration: InputDecoration(
                  labelText: 'Observações',
                  labelStyle: TextStyle(color: const Color(0xFF045D3A).withOpacity(0.7)),
                  prefixIcon: const Icon(Icons.notes, color: Color(0xFF049F56)),
                  filled: true,
                  fillColor: const Color(0xFF049F56).withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: const Color(0xFF049F56).withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: Color(0xFF049F56), width: 2),
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
                          side: BorderSide(color: Colors.grey.withOpacity(0.3)),
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
                            color: const Color(0xFF045D3A).withOpacity(0.3),
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
                            await FirebaseFirestore.instance.collection('povoamentos').add({
                              'cicloId': ciclo.id,
                              'codigo': ciclo['codigo'],
                              'nome': ciclo['nome'],
                              'quantidade': qtd,
                              'responsavel': nomeUsuario,
                              'observacoes': obsCtrl.text.trim(),
                              'dataRegistro': Timestamp.now(),
                            });
                            
                            if (context.mounted) Navigator.pop(context);
                            
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Row(
                                  children: [
                                    Icon(Icons.check_circle, color: Colors.white),
                                    SizedBox(width: 8),
                                    Text('✅ Povoamento registrado com sucesso!'),
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
                                    const Icon(Icons.error, color: Colors.white),
                                    const SizedBox(width: 8),
                                    Text('❌ Erro: $e'),
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
    );
  }
}
