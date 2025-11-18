// Tela Ciclos por Viveiro - com edição e histórico
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/degrade_fundo.dart';
import 'tela_detalhes_ciclo.dart';

class TelaCiclosViveiro extends StatefulWidget {
  const TelaCiclosViveiro({super.key});

  @override
  State<TelaCiclosViveiro> createState() => _TelaCiclosViveiroState();
}

class _TelaCiclosViveiroState extends State<TelaCiclosViveiro> {
  // Estilos reutilizáveis
  static const _corPrimariaEscura = Color(0xFF045D3A);
  static const _corPrimaria = Color(0xFF049F56);

  final _formKey = GlobalKey<FormState>();
  final _qtdCtrl = TextEditingController();
  final _pesoCtrl = TextEditingController();
  final _plDiaCtrl = TextEditingController();
  final _plGramaCtrl = TextEditingController();
  String? _codigoSelecionado;
  DateTime _dataInicio = DateTime.now();
  Map<String, String> _destinos = {};
  bool _salvando = false;
  String? _idEditando;
  int _mostrarApenasAbertos = 1; // 1: em andamento, 2: encerrados, 0: todos
  DateTime? _previsaoEncerramento;
  bool _mostrarFormulario = false; // Controla se o formulário está visível

  // Filtros de busca
  String? _tipoFiltro; // 'viveiro', 'bercario' ou null (todos)
  String? _codigoFiltro; // código específico ou null (todos)

  @override
  void initState() {
    super.initState();
    _carregarDestinos();
    _verificarConectividadeFirestore();
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

  Future<void> _carregarDestinos() async {
    final mapa = <String, String>{};

    // Carregar viveiros
    final snapViveiros = await FirebaseFirestore.instance
        .collection('viveiros')
        .get();
    for (final doc in snapViveiros.docs) {
      final data = doc.data();
      mapa['V-${data['codigo']}'] = '🐟 ${data['nome']} (Viveiro)';
    }

    // Carregar berçários
    final snapBercarios = await FirebaseFirestore.instance
        .collection('bercarios')
        .get();
    for (final doc in snapBercarios.docs) {
      final data = doc.data();
      mapa['B-${data['codigo']}'] = '🦐 ${data['nome']} (Berçário)';
    }

    setState(() => _destinos = mapa);
  }

  Future<void> _salvarCiclo() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);

    if (_previsaoEncerramento != null &&
        _previsaoEncerramento!.isBefore(_dataInicio)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning, color: Colors.white),
              SizedBox(width: 8),
              Text(
                '⚠️ A previsão de encerramento deve ser após a data de início.',
              ),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      setState(() => _salvando = false);
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      final nomeUsuario = user != null
          ? (((await FirebaseFirestore.instance
                        .collection('usuarios')
                        .doc(user.uid)
                        .get())
                    .data()?['nome']) ??
                '—')
          : '—';

      // Extrair tipo e código do valor selecionado (formato: "V-codigo" ou "B-codigo")
      final tipo = _codigoSelecionado!.startsWith('V-')
          ? 'viveiro'
          : 'bercario';
      final codigoLimpo = _codigoSelecionado!.substring(
        2,
      ); // Remove "V-" ou "B-"
      final nomeLimpo =
          _destinos[_codigoSelecionado]
              ?.replaceAll(RegExp(r'🐟|🦐|\s*\(.*\)'), '')
              .trim() ??
          '—';

      final dados = {
        'codigo': codigoLimpo,
        'nome': nomeLimpo,
        'tipo': tipo,
        'dataInicio': Timestamp.fromDate(_dataInicio),
        'previsaoEncerramento': _previsaoEncerramento != null
            ? Timestamp.fromDate(_previsaoEncerramento!)
            : null,
        'quantidadeEstocada': int.parse(_qtdCtrl.text),
        'pesoInicial':
            double.tryParse(_pesoCtrl.text.replaceAll(',', '.')) ?? 0.0,
        'plDia': _plDiaCtrl.text.isNotEmpty
            ? double.tryParse(_plDiaCtrl.text.replaceAll(',', '.'))
            : null,
        'plGrama': _plGramaCtrl.text.isNotEmpty
            ? double.tryParse(_plGramaCtrl.text.replaceAll(',', '.'))
            : null,
      };

      if (_idEditando != null) {
        await FirebaseFirestore.instance
            .collection('ciclos')
            .doc(_idEditando)
            .update(dados);
      } else {
        final existe = await FirebaseFirestore.instance
            .collection('ciclos')
            .where('codigo', isEqualTo: codigoLimpo)
            .where('tipo', isEqualTo: tipo)
            .where('encerrado', isEqualTo: false)
            .get();
        if (existe.docs.isNotEmpty) {
          final tipoTexto = tipo == 'viveiro' ? 'viveiro' : 'berçário';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.info, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('ℹ️ Já existe um ciclo ativo para esse $tipoTexto.'),
                ],
              ),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
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
          backgroundColor: _corPrimaria,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      setState(() {
        _qtdCtrl.clear();
        _pesoCtrl.clear();
        _codigoSelecionado = null;
        _idEditando = null;
        _previsaoEncerramento = null;
        _salvando = false;
        // Fechar formulário após salvar novo ciclo
        if (_idEditando == null) {
          _mostrarFormulario = false;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('❌ Erro ao salvar: $e')),
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
      setState(() => _salvando = false);
    }
  }

  Future<void> _encerrarCiclo(QueryDocumentSnapshot ciclo) async {
    if (ciclo['encerrado'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.info, color: Colors.white),
              SizedBox(width: 8),
              Text('Ciclo já está encerrado.'),
            ],
          ),
          backgroundColor: Colors.grey,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

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
                          colors: [
                            Colors.red.withOpacity(0.8),
                            Colors.red.withOpacity(0.6),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.lock,
                        color: Colors.white,
                        size: 24,
                      ),
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
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(color: Color(0xFF045D3A)),
                  decoration: InputDecoration(
                    labelText: 'Peso Médio Final (g)',
                    labelStyle: TextStyle(
                      color: const Color(0xFF045D3A).withOpacity(0.7),
                    ),
                    prefixIcon: const Icon(
                      Icons.scale,
                      color: Color(0xFF049F56),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF049F56).withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(
                        color: const Color(0xFF049F56).withOpacity(0.3),
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
                              color: Colors.grey.withOpacity(0.3),
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
                          gradient: LinearGradient(
                            colors: [
                              Colors.red.withOpacity(0.8),
                              Colors.red.withOpacity(0.6),
                            ],
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
                            final val = double.tryParse(
                              ctrl.text.replaceAll(',', '.'),
                            );
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
        ? ((await FirebaseFirestore.instance
                      .collection('usuarios')
                      .doc(user.uid)
                      .get())
                  .data()?['nome'] ??
              '—')
        : '—';

    try {
      await FirebaseFirestore.instance
          .collection('ciclos')
          .doc(ciclo.id)
          .update({
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _qtdCtrl.dispose();
    _pesoCtrl.dispose();
    _plDiaCtrl.dispose();
    _plGramaCtrl.dispose();
    super.dispose();
  }

  void _carregarParaEdicao(QueryDocumentSnapshot ciclo) {
    setState(() {
      _idEditando = ciclo.id;
      // Usar mapa seguro para evitar exceções em documentos antigos sem certos campos
      final data = (ciclo.data() is Map<String, dynamic>)
          ? (ciclo.data() as Map<String, dynamic>)
          : <String, dynamic>{};
      final tipo = (data['tipo'] as String?) ?? 'viveiro';
      final codigo = (data['codigo'] ?? '').toString();
      _codigoSelecionado = tipo == 'viveiro' ? 'V-$codigo' : 'B-$codigo';
      _qtdCtrl.text = (data['quantidadeEstocada'] ?? '').toString();
      _pesoCtrl.text = (data['pesoInicial'] ?? '').toString();
      _plDiaCtrl.text = (data['plDia'] ?? '').toString();
      _plGramaCtrl.text = (data['plGrama'] ?? '').toString();
      final dtInicio = data['dataInicio'] as Timestamp?;
      _dataInicio = dtInicio?.toDate() ?? DateTime.now();
      _previsaoEncerramento = (data['previsaoEncerramento'] is Timestamp)
          ? (data['previsaoEncerramento'] as Timestamp).toDate()
          : null;
    });
  }

  String _formatarData(DateTime dt) => DateFormat('dd/MM/yyyy').format(dt);

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

    return filters.join(', ');
  }

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
                  colors: [Colors.grey[100]!, Colors.grey[50]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected ? const Color(0xFF049F56) : Colors.grey[300]!,
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
                  color: _corPrimaria.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.calendar_today,
                  size: 20,
                  color: _corPrimaria,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Data de Início',
                      style: TextStyle(
                        color: _corPrimariaEscura.withOpacity(0.7),
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
                icon: const Icon(Icons.edit_calendar, color: _corPrimaria),
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
                  color: _corPrimaria.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.event, size: 20, color: _corPrimaria),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Previsão de Encerramento (opcional)',
                      style: TextStyle(
                        color: _corPrimariaEscura.withOpacity(0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _previsaoEncerramento != null
                          ? DateFormat(
                              'dd/MM/yyyy',
                            ).format(_previsaoEncerramento!)
                          : 'Não definida',
                      style: TextStyle(
                        color: _previsaoEncerramento != null
                            ? _corPrimariaEscura
                            : _corPrimariaEscura.withOpacity(0.6),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (_previsaoEncerramento != null)
                IconButton(
                  tooltip: 'Limpar',
                  icon: const Icon(Icons.clear, color: Colors.redAccent),
                  onPressed: () => setState(() => _previsaoEncerramento = null),
                ),
              IconButton(
                icon: const Icon(Icons.edit_calendar, color: _corPrimaria),
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

    // Cálculo duração
    final int duracaoDias = (encerrado && dataEncerramento != null)
        ? dataEncerramento.difference(data).inDays
        : DateTime.now().difference(data).inDays;
    final num? ganhoPeso = (encerrado && pesoFinal != null && pesoInicial > 0)
        ? (pesoFinal - pesoInicial)
        : null;

    return InkWell(
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
      child: Container(
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
                          nomeLocal,
                          style: const TextStyle(
                            color: Color(0xFF045D3A),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: tipoLocal == 'viveiro'
                                    ? Colors.blue.withOpacity(0.2)
                                    : Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                tipoLocal == 'viveiro'
                                    ? '🐟 Viveiro'
                                    : '🦐 Berçário',
                                style: TextStyle(
                                  color: tipoLocal == 'viveiro'
                                      ? Colors.blue
                                      : Colors.orange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Código: $codigoLocal',
                              style: TextStyle(
                                color: const Color(0xFF045D3A).withOpacity(0.7),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: encerrado
                              ? Colors.grey.withOpacity(0.3)
                              : const Color(0xFF049F56).withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: encerrado
                                ? Colors.grey
                                : const Color(0xFF049F56),
                          ),
                        ),
                        child: Text(
                          encerrado ? '🔒 Encerrado' : '🔄 Ativo',
                          style: TextStyle(
                            color: encerrado
                                ? Colors.grey[300]
                                : const Color(0xFF049F56),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Informações principais - resumidas
              _buildInfoRow('📅 Início', _formatarData(data)),
              if (previsaoEncerramento != null)
                _buildInfoRow(
                  '🎯 Previsão',
                  _formatarData(previsaoEncerramento),
                ),
              if (encerrado && dataEncerramento != null)
                _buildInfoRow('🏁 Encerrado', _formatarData(dataEncerramento)),
              _buildInfoRow(
                '🦐 Estocados',
                '${dataMap['quantidadeEstocada'] ?? 0} pós-larvas',
              ),
              _buildInfoRow('⏱️ Duração', '$duracaoDias dias'),
              if (dataMap['plDia'] != null)
                _buildInfoRow(
                  '📊 PL / Dia',
                  '${dataMap['plDia'].toString().replaceAll('.', ',')}',
                ),
              if (dataMap['plGrama'] != null && dataMap['tipo'] == 'bercario')
                _buildInfoRow(
                  '📏 PL / g',
                  '${dataMap['plGrama'].toString().replaceAll('.', ',')}',
                ),
              if (ganhoPeso != null)
                _buildInfoRow(
                  '📈 Ganho Médio',
                  '${ganhoPeso.toString().replaceAll('.', ',')} g',
                ),

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
                // Ações - agora com botões mais simples
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton('✏️ Editar', Colors.blue, () {
                      _carregarParaEdicao(ciclo);
                      setState(() => _mostrarFormulario = true);
                    }),
                    _buildActionButton(
                      '➕ Povoar',
                      const Color(0xFF049F56),
                      () => _abrirRegistroPovoamento(context, ciclo),
                    ),
                    _buildActionButton(
                      '🔒 Encerrar',
                      Colors.red,
                      () => _encerrarCiclo(ciclo),
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
            colors: [color.withOpacity(0.8), color.withOpacity(0.6)],
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
      title: 'Gestão de Ciclos',
      floatingActionButton: !_mostrarFormulario
          ? FloatingActionButton.extended(
              onPressed: () => setState(() => _mostrarFormulario = true),
              icon: const Icon(Icons.add),
              label: const Text('Novo Ciclo'),
            )
          : null,
      body: DegradeFundo(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Painel de instruções (alinhado ao padrão da tela de análises)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, color: Colors.blue),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Dicas para gestão de ciclos',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            SizedBox(height: 6),
                            Text(
                              '• Um ciclo ativo por viveiro/berçário. Use os filtros para focar em abertos, encerrados ou todos.',
                            ),
                            Text(
                              '• Clique em um card para ver detalhes; use “Povoar” para registrar acréscimos e “Encerrar” para finalizar.',
                            ),
                            Text(
                              '• Previsão de encerramento não pode ser anterior à data de início. Campos ausentes em ciclos antigos são tratados automaticamente.',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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
                  // Substituído Row por Wrap para evitar overflow horizontal
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _buildFilterChip('🔄 Em Andamento', 1),
                      _buildFilterChip('✅ Encerrados', 2),
                      _buildFilterChip('📋 Todos', 0),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Filtros por tipo e código
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF049F56).withOpacity(0.2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.filter_list, color: Color(0xFF049F56)),
                          SizedBox(width: 8),
                          Text(
                            'Filtros',
                            style: TextStyle(
                              color: Color(0xFF045D3A),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Column(
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: _tipoFiltro,
                            decoration: InputDecoration(
                              labelText: 'Tipo',
                              prefixIcon: const Icon(
                                Icons.category,
                                color: Color(0xFF049F56),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF049F56),
                                  width: 2,
                                ),
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: null,
                                child: Text('Todos'),
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
                              _codigoFiltro =
                                  null; // Reset código quando mudar tipo
                            }),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _codigoFiltro,
                            decoration: InputDecoration(
                              labelText: 'Código',
                              prefixIcon: const Icon(
                                Icons.water_damage,
                                color: Color(0xFF049F56),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF049F56),
                                  width: 2,
                                ),
                              ),
                            ),
                            items: _buildCodigoDropdownItems(),
                            onChanged: (value) =>
                                setState(() => _codigoFiltro = value),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Indicador de filtros ativos
                if (_tipoFiltro != null || _codigoFiltro != null)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF049F56).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF049F56).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.filter_alt,
                          color: Color(0xFF049F56),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Filtros: ${_getActiveFiltersText()}',
                          style: const TextStyle(
                            color: Color(0xFF049F56),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => setState(() {
                            _tipoFiltro = null;
                            _codigoFiltro = null;
                          }),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF049F56),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),

                // Botão para mostrar/esconder formulário
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
                  child: Column(
                    children: [
                      Row(
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
                            child: const Icon(
                              Icons.add_circle,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              _mostrarFormulario
                                  ? '🆕 Novo Ciclo'
                                  : '🆕 Criar Novo Ciclo',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF045D3A),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              _mostrarFormulario
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: const Color(0xFF049F56),
                              size: 28,
                            ),
                            onPressed: () {
                              setState(() {
                                _mostrarFormulario = !_mostrarFormulario;
                                if (!_mostrarFormulario) {
                                  // Limpar formulário quando fechar
                                  _qtdCtrl.clear();
                                  _pesoCtrl.clear();
                                  _codigoSelecionado = null;
                                  _idEditando = null;
                                  _previsaoEncerramento = null;
                                  _dataInicio = DateTime.now();
                                }
                              });
                            },
                          ),
                        ],
                      ),

                      // Formulário (aparece apenas quando _mostrarFormulario for true)
                      if (_mostrarFormulario) ...[
                        const SizedBox(height: 20),
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DropdownButtonFormField<String>(
                                initialValue: _codigoSelecionado,
                                items: () {
                                  final sortedEntries =
                                      _destinos.entries.toList()..sort(
                                        (a, b) => a.key.compareTo(b.key),
                                      );
                                  return sortedEntries
                                      .map(
                                        (e) => DropdownMenuItem(
                                          value: e.key,
                                          child: Text(
                                            '${e.value} (cód: ${e.key})',
                                          ),
                                        ),
                                      )
                                      .toList();
                                }(),
                                onChanged: (val) =>
                                    setState(() => _codigoSelecionado = val),
                                decoration: InputDecoration(
                                  labelText: 'Viveiro ou Berçário',
                                  labelStyle: TextStyle(
                                    color: const Color(
                                      0xFF045D3A,
                                    ).withOpacity(0.8),
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.water_damage,
                                    color: Color(0xFF049F56),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: BorderSide(
                                      color: Colors.grey[300]!,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: BorderSide(
                                      color: Colors.grey[300]!,
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
                                dropdownColor: Colors.white,
                                style: const TextStyle(
                                  color: Color(0xFF045D3A),
                                ),
                                validator: (v) => v == null
                                    ? 'Selecione o viveiro ou berçário'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _qtdCtrl,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(
                                  color: Color(0xFF045D3A),
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Quantidade Estocada (pós-larvas)',
                                  labelStyle: TextStyle(
                                    color: const Color(
                                      0xFF045D3A,
                                    ).withOpacity(0.8),
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.numbers,
                                    color: Color(0xFF049F56),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: BorderSide(
                                      color: Colors.grey[300]!,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: BorderSide(
                                      color: Colors.grey[300]!,
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
                                validator: (v) => v == null || v.isEmpty
                                    ? 'Informe a quantidade'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _pesoCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                style: const TextStyle(
                                  color: Color(0xFF045D3A),
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Peso Médio Inicial (g)',
                                  labelStyle: TextStyle(
                                    color: const Color(
                                      0xFF045D3A,
                                    ).withOpacity(0.8),
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.scale,
                                    color: Color(0xFF049F56),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: BorderSide(
                                      color: Colors.grey[300]!,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: BorderSide(
                                      color: Colors.grey[300]!,
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
                                controller: _plDiaCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                style: const TextStyle(
                                  color: Color(0xFF045D3A),
                                ),
                                decoration: InputDecoration(
                                  labelText: 'PL / Dia',
                                  hintText: 'Opcional',
                                  labelStyle: TextStyle(
                                    color: const Color(
                                      0xFF045D3A,
                                    ).withOpacity(0.8),
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.today,
                                    color: Color(0xFF049F56),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: BorderSide(
                                      color: Colors.grey[300]!,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: BorderSide(
                                      color: Colors.grey[300]!,
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
                              if (_codigoSelecionado != null &&
                                  _codigoSelecionado!.startsWith('B-'))
                                TextFormField(
                                  controller: _plGramaCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  style: const TextStyle(
                                    color: Color(0xFF045D3A),
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'PL / g (Berçário)',
                                    hintText: 'Opcional',
                                    labelStyle: TextStyle(
                                      color: const Color(
                                        0xFF045D3A,
                                      ).withOpacity(0.8),
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.straighten,
                                      color: Color(0xFF049F56),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      borderSide: BorderSide(
                                        color: Colors.grey[300]!,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      borderSide: BorderSide(
                                        color: Colors.grey[300]!,
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
                              if (_codigoSelecionado != null &&
                                  _codigoSelecionado!.startsWith('B-'))
                                const SizedBox(height: 16),
                              const SizedBox(height: 20),
                              _buildDateSelector(),
                              const SizedBox(height: 24),
                              Center(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF045D3A),
                                        Color(0xFF049F56),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(15),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF045D3A,
                                        ).withOpacity(0.4),
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
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    Colors.white,
                                                  ),
                                            ),
                                          )
                                        : const Icon(
                                            Icons.save,
                                            color: Colors.white,
                                          ),
                                    label: Text(
                                      _salvando
                                          ? 'Salvando...'
                                          : (_idEditando != null
                                                ? 'Atualizar Ciclo'
                                                : 'Salvar Ciclo'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    onPressed: _salvando
                                        ? null
                                        : () async {
                                            await _salvarCiclo();
                                            if (_idEditando == null) {
                                              // Se salvou um novo ciclo, fechar o formulário
                                              setState(
                                                () =>
                                                    _mostrarFormulario = false,
                                              );
                                            }
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 32,
                                        vertical: 16,
                                      ),
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
                      ],
                    ],
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
                        child: const Icon(
                          Icons.history,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        '📋 Ciclos Ativos',
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
                SizedBox(
                  height: 500, // Aumentada a altura para melhor visualização
                  child: StreamBuilder<QuerySnapshot>(
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
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: Colors.red.withOpacity(0.3),
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
                      List<QueryDocumentSnapshot> docs = snapshot.data!.docs;

                      // Aplicar filtros na aplicação
                      if (_mostrarApenasAbertos == 1) {
                        docs = docs.where((doc) {
                          final m = (doc.data() as Map<String, dynamic>?) ?? {};
                          return m['encerrado'] == false;
                        }).toList();
                      } else if (_mostrarApenasAbertos == 2) {
                        docs = docs.where((doc) {
                          final m = (doc.data() as Map<String, dynamic>?) ?? {};
                          return m['encerrado'] == true;
                        }).toList();
                      }

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
                                  color: const Color(
                                    0xFF049F56,
                                  ).withOpacity(0.6),
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
                                  _getBuildEmptyMessage(),
                                  style: TextStyle(
                                    color: const Color(
                                      0xFF045D3A,
                                    ).withOpacity(0.6),
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
                        itemBuilder: (context, index) =>
                            _buildCicloCard(docs[index]),
                      );
                    },
                  ),
                ), // Fecha o Container da lista de ciclos
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
                    color: const Color(0xFF049F56).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: const Color(0xFF049F56).withOpacity(0.3),
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
                      color: const Color(0xFF045D3A).withOpacity(0.7),
                    ),
                    prefixIcon: const Icon(
                      Icons.numbers,
                      color: Color(0xFF049F56),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF049F56).withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(
                        color: const Color(0xFF049F56).withOpacity(0.3),
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
                      color: const Color(0xFF045D3A).withOpacity(0.7),
                    ),
                    prefixIcon: const Icon(
                      Icons.notes,
                      color: Color(0xFF049F56),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF049F56).withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(
                        color: const Color(0xFF049F56).withOpacity(0.3),
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
                              color: Colors.grey.withOpacity(0.3),
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
