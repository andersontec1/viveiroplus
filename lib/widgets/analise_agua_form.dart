import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:viveiro_plus/helpers/parametros_analise_helper.dart';

/// Configuração de um parâmetro da análise de água
class ParametroAnalise {
  const ParametroAnalise({
    required this.label,
    required this.icon,
    required this.minIdeal,
    required this.maxIdeal,
    required this.chaveFirestore,
    this.obrigatorio = false,
  });
  final String label;
  final IconData icon;
  final double minIdeal;
  final double maxIdeal;
  final String chaveFirestore;
  final bool obrigatorio;

  bool foraFaixa(double valor) {
    return valor < minIdeal || valor > maxIdeal;
  }

  String get faixaIdealTexto => '$minIdeal – $maxIdeal';
}

/// Widget reutilizável para formulário de análise de água
class AnaliseAguaForm extends StatefulWidget {
  const AnaliseAguaForm({
    super.key,
    this.dadosIniciais,
    this.modoEdicao = false,
    this.codigoSelecionado,
    this.tipoSelecionado,
    this.dataHoraInicial,
    this.onSalvar,
    this.onCancelar,
    this.mostrarSeletorDestino = true,
  });
  final Map<String, dynamic>? dadosIniciais;
  final bool modoEdicao;
  final String? codigoSelecionado;
  final String? tipoSelecionado;
  final DateTime? dataHoraInicial;
  // Callback agora explicitamente assíncrono para permitir aguardar e bloquear toques múltiplos
  final Future<void> Function(Map<String, dynamic> dados)? onSalvar;
  final VoidCallback? onCancelar;
  final bool mostrarSeletorDestino;

  @override
  State<AnaliseAguaForm> createState() => _AnaliseAguaFormState();
}

class _AnaliseAguaFormState extends State<AnaliseAguaForm> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _registroDt;
  bool _saving = false;
  String? _codigoSelecionado;
  String? _tipoSelecionado;
  Map<String, String> _viveiros = {};
  Map<String, String> _bercarios = {};
  bool _temCampoPreenchido = false;

  // Controllers para todos os campos
  final Map<String, TextEditingController> _controllers = {};
  late TextEditingController _obsCtrl;
  late TextEditingController _dataHoraCtrl;

  // Definição centralizada dos parâmetros
  static const List<ParametroAnalise> _parametros = [
    ParametroAnalise(
      label: 'pH da Água',
      icon: Icons.grain,
      minIdeal: 7.0,
      maxIdeal: 9.0,
      chaveFirestore: 'ph',
    ),
    ParametroAnalise(
      label: 'Oxigênio Dissolvido (mg/L)',
      icon: Icons.air,
      minIdeal: 4.0,
      maxIdeal: 14.0,
      chaveFirestore: 'oxigenio',
    ),
    ParametroAnalise(
      label: 'Porcentagem de Saturação (%)',
      icon: Icons.percent,
      minIdeal: 80.0,
      maxIdeal: 120.0,
      chaveFirestore: 'saturacao_percentual',
    ),
    ParametroAnalise(
      label: 'Temperatura (°C)',
      icon: Icons.thermostat,
      minIdeal: 26.0,
      maxIdeal: 32.0,
      chaveFirestore: 'temperatura',
    ),
    ParametroAnalise(
      label: 'Turbidez (NTU)',
      icon: Icons.blur_on,
      minIdeal: 40.0,
      maxIdeal: 60.0,
      chaveFirestore: 'turbidez',
    ),
    ParametroAnalise(
      label: 'Salinidade (ppt)',
      icon: Icons.opacity,
      minIdeal: 30.0,
      maxIdeal: 45.0,
      chaveFirestore: 'salinidade',
    ),
    ParametroAnalise(
      label: 'Cálcio (mg/L)',
      icon: Icons.science_outlined,
      minIdeal: 100.0,
      maxIdeal: 300.0,
      chaveFirestore: 'calcio',
    ),
    ParametroAnalise(
      label: 'Nitrito (mg/L)',
      icon: Icons.warning_amber,
      minIdeal: 0.0,
      maxIdeal: 0.5,
      chaveFirestore: 'nitrito',
    ),
    ParametroAnalise(
      label: 'Amônia (mg/L)',
      icon: Icons.dangerous,
      minIdeal: 0.0,
      maxIdeal: 1.5,
      chaveFirestore: 'amonia',
    ),
  ];

  // Faixas dinâmicas carregadas do Firestore (fallback: defaults)
  Map<String, Map<String, double>> _faixas =
      ParametrosAnaliseHelper.getDefaultsAsDouble();

  @override
  void initState() {
    super.initState();
    // Inicializa a data/hora ANTES de criar os controllers para evitar LateInitializationError
    _registroDt = widget.dataHoraInicial ?? DateTime.now();
    _inicializarControllers();
    _inicializarDados();
    _carregarDestinos();
    _adicionarListeners();
    _carregarFaixas();
  }

  Future<void> _carregarFaixas() async {
    final map = await ParametrosAnaliseHelper.carregarTodos();
    if (!mounted) return;
    setState(() => _faixas = map);
  }

  void _inicializarControllers() {
    // Inicializar controllers para todos os parâmetros
    for (final param in _parametros) {
      _controllers[param.chaveFirestore] = TextEditingController();
    }
    _obsCtrl = TextEditingController();
    _dataHoraCtrl = TextEditingController(text: _formatDateTime(_registroDt));
  }

  void _inicializarDados() {
    _codigoSelecionado = widget.codigoSelecionado;
    _tipoSelecionado = widget.tipoSelecionado;

    // Se estamos em modo edição, preencher os campos
    if (widget.modoEdicao && widget.dadosIniciais != null) {
      final dados = widget.dadosIniciais!;
      for (final param in _parametros) {
        final valor = dados[param.chaveFirestore];
        if (valor != null) {
          _controllers[param.chaveFirestore]!.text = valor.toString();
        }
      }
      _obsCtrl.text = dados['observacoes']?.toString() ?? '';
      if (dados['dataHora'] is Timestamp) {
        _registroDt = (dados['dataHora'] as Timestamp).toDate();
        _dataHoraCtrl.text = _formatDateTime(_registroDt);
      }
    }
  }

  void _adicionarListeners() {
    for (final controller in _controllers.values) {
      controller.addListener(_verificarCampos);
    }
    _obsCtrl.addListener(_verificarCampos);
    _dataHoraCtrl.addListener(_verificarCampos);
  }

  void _verificarCampos() {
    setState(() {
      _temCampoPreenchido =
          _controllers.values.any((c) => c.text.isNotEmpty) ||
          _obsCtrl.text.isNotEmpty;
    });
  }

  Future<void> _carregarDestinos() async {
    if (!widget.mostrarSeletorDestino) return;
    try {
      final snapshotViveiros = await FirebaseFirestore.instance
          .collection('viveiros')
          .get();
      final viveiros = <String, String>{};
      for (final doc in snapshotViveiros.docs) {
        final data = doc.data();
        final codigo = data['codigo']?.toString() ?? '';
        final nome = data['nome']?.toString() ?? '';
        if (codigo.isNotEmpty && nome.isNotEmpty) {
          viveiros[codigo] = nome;
        }
      }

      final snapshotBercarios = await FirebaseFirestore.instance
          .collection('bercarios')
          .get();
      final bercarios = <String, String>{};
      for (final doc in snapshotBercarios.docs) {
        final data = doc.data();
        final codigo = data['codigo']?.toString() ?? '';
        final nome = data['nome']?.toString() ?? '';
        if (codigo.isNotEmpty && nome.isNotEmpty) {
          bercarios[codigo] = nome;
        }
      }

      if (mounted) {
        setState(() {
          _viveiros = viveiros;
          _bercarios = bercarios;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar destinos: $e');
    }
  }

  String _formatDateTime(DateTime dt) =>
      DateFormat('dd/MM/yyyy HH:mm').format(dt);

  Future<void> _onSubmit() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    if (widget.mostrarSeletorDestino &&
        (_codigoSelecionado == null || _tipoSelecionado == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione o tipo e código do destino')),
      );
      return;
    }

    final List<Map<String, dynamic>> listaForaFaixa = [];
    final Map<String, dynamic> dadosParaSalvar = {};
    for (final param in _parametros) {
      final controller = _controllers[param.chaveFirestore]!;
      if (controller.text.isNotEmpty) {
        final valor = double.tryParse(controller.text.replaceAll(',', '.'));
        if (valor != null) {
          dadosParaSalvar[param.chaveFirestore] = valor;
          final faixa =
              _faixas[param.chaveFirestore] ??
              ParametrosAnaliseHelper.getDefaultsAsDouble()[param
                  .chaveFirestore]!;
          final fora = valor < faixa['min']! || valor > faixa['max']!;
          if (fora) {
            listaForaFaixa.add({
              'nome': param.label,
              'valor': valor,
              'ideal': '${faixa['min']} – ${faixa['max']}',
            });
          }
        }
      }
    }

    dadosParaSalvar['observacoes'] = _obsCtrl.text.trim();
    dadosParaSalvar['dataHora'] = Timestamp.fromDate(_registroDt);

    if (widget.mostrarSeletorDestino && !widget.modoEdicao) {
      final nome = _tipoSelecionado == 'viveiro'
          ? (_viveiros[_codigoSelecionado!] ?? '—')
          : (_bercarios[_codigoSelecionado!] ?? '—');
      dadosParaSalvar['tipoDestino'] = _tipoSelecionado;
      dadosParaSalvar['codigo'] = _codigoSelecionado;
      dadosParaSalvar['nome'] = nome;
      dadosParaSalvar['criadoEm'] = Timestamp.now();
      final user = FirebaseAuth.instance.currentUser;
      String nomeUsuario = '—';
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user.uid)
            .get();
        nomeUsuario = doc.data()?['nome'] ?? '—';
      }
      dadosParaSalvar['registradoPor'] = nomeUsuario;
    }

    if (widget.modoEdicao) {
      final user = FirebaseAuth.instance.currentUser;
      String nomeUsuario = '—';
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user.uid)
            .get();
        nomeUsuario = doc.data()?['nome'] ?? '—';
      }
      dadosParaSalvar['editadoPor'] = nomeUsuario;
      dadosParaSalvar['editadoEm'] = Timestamp.now();
    }

    if (listaForaFaixa.isNotEmpty) {
      final continuar = await _mostrarDialogoForaFaixa(listaForaFaixa);
      if (!continuar) return;
    }

    setState(() => _saving = true);
    try {
      if (widget.onSalvar != null) {
        await widget.onSalvar!(dadosParaSalvar);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _mostrarDialogoForaFaixa(
    List<Map<String, dynamic>> foraFaixa,
  ) async {
    final continuar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 32),
            SizedBox(width: 8),
            Text(
              'Parâmetro(s) fora da faixa',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Os seguintes parâmetros estão fora da faixa ideal:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ...foraFaixa.map(
              (param) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red.shade400, size: 20),
                    const SizedBox(width: 6),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                          children: [
                            TextSpan(
                              text: '${param['nome']}: ',
                              style: const TextStyle(color: Colors.red),
                            ),
                            TextSpan(text: 'Valor: ${param['valor']}  '),
                            TextSpan(
                              text: '(Ideal: ${param['ideal']})',
                              style: const TextStyle(color: Colors.teal),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Deseja continuar mesmo assim?',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Continuar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    return continuar == true;
  }

  Future<bool> _confirmarSaida() async {
    if (!_temCampoPreenchido) return true;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Descartar dados?'),
        content: const Text(
          'Há dados preenchidos. Tem certeza que deseja sair?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    return confirm == true;
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _obsCtrl.dispose();
    _dataHoraCtrl.dispose();
    super.dispose();
  }

  Widget _buildCampoParametro(ParametroAnalise param) {
    final controller = _controllers[param.chaveFirestore]!;
    final text = controller.text;
    final valor = double.tryParse(text);
    final faixa =
        _faixas[param.chaveFirestore] ??
        ParametrosAnaliseHelper.getDefaultsAsDouble()[param.chaveFirestore]!;
    final fora =
        valor != null && (valor < faixa['min']! || valor > faixa['max']!);

    Color? fillColor;
    Color? borderColor;
    if (fora) {
      fillColor = Colors.red.shade100;
      borderColor = Colors.red;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          style: const TextStyle(fontSize: 18),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: param.label,
            prefixIcon: Icon(param.icon),
            fillColor: fillColor,
            filled: fora,
            enabledBorder: borderColor != null
                ? OutlineInputBorder(
                    borderSide: BorderSide(color: borderColor, width: 1.5),
                    borderRadius: BorderRadius.circular(8),
                  )
                : null,
            focusedBorder: borderColor != null
                ? OutlineInputBorder(
                    borderSide: BorderSide(color: borderColor, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  )
                : null,
          ),
          validator: param.obrigatorio
              ? (v) => v == null || v.isEmpty ? 'Informe ${param.label}' : null
              : null,
          onChanged: (_) => setState(() {}),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 4),
          child: Text(
            'Faixa ideal: ${faixa['min']} – ${faixa['max']} Fora disso, notifique o supervisor.',
            style: TextStyle(
              fontSize: 15,
              color: fora ? Colors.red : Colors.teal,
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  // Parametrização movida para tela dedicada; função removida.

  Widget _buildSeletorDestino() {
    if (!widget.mostrarSeletorDestino) return const SizedBox.shrink();

    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: _tipoSelecionado,
          decoration: const InputDecoration(
            labelText: 'Tipo de Destino',
            prefixIcon: Icon(Icons.category),
          ),
          items: const [
            DropdownMenuItem(value: 'viveiro', child: Text('Viveiro')),
            DropdownMenuItem(value: 'bercario', child: Text('Berçário')),
          ],
          onChanged: (value) => setState(() {
            _tipoSelecionado = value;
            _codigoSelecionado = null;
          }),
          validator: (v) => v == null ? 'Escolha viveiro ou berçário' : null,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _codigoSelecionado,
          decoration: const InputDecoration(
            labelText: 'Código',
            prefixIcon: Icon(Icons.water_damage_outlined),
          ),
          items: (() {
            Map<String, String> destinosParaMostrar = {};

            if (_tipoSelecionado == 'viveiro') {
              destinosParaMostrar = _viveiros;
            } else if (_tipoSelecionado == 'bercario') {
              destinosParaMostrar = _bercarios;
            }

            final destinosOrdenados = destinosParaMostrar.entries.toList()
              ..sort((a, b) => a.key.compareTo(b.key));

            return destinosOrdenados
                .map(
                  (e) => DropdownMenuItem(
                    value: e.key,
                    child: Text('${e.value} (cód: ${e.key})'),
                  ),
                )
                .toList();
          })(),
          onChanged: (value) => setState(() => _codigoSelecionado = value),
          validator: (v) =>
              v == null || v.isEmpty ? 'Selecione o código' : null,
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _confirmarSaida();
        if (!mounted) return;
        if (shouldPop) {
          if (!mounted) return;
          Navigator.of(context).pop(result);
        }
      },
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            // Parametrização movida para uma tela dedicada no menu principal
            _buildSeletorDestino(),

            const Divider(thickness: 2, height: 32),
            const Center(
              child: Text(
                'Parâmetros Físicos',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Parâmetros físicos
            _buildCampoParametro(_parametros[0]), // pH
            _buildCampoParametro(_parametros[1]), // Oxigênio
            _buildCampoParametro(_parametros[2]), // Saturação percentual
            _buildCampoParametro(_parametros[3]), // Temperatura
            _buildCampoParametro(_parametros[4]), // Turbidez

            const Divider(thickness: 2, height: 32),
            const Center(
              child: Text(
                'Parâmetros Químicos',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Parâmetros químicos
            _buildCampoParametro(_parametros[5]), // Salinidade
            _buildCampoParametro(_parametros[6]), // Cálcio
            _buildCampoParametro(_parametros[7]), // Nitrito
            _buildCampoParametro(_parametros[8]), // Amônia

            TextFormField(
              controller: _obsCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Observações',
                prefixIcon: Icon(Icons.note_alt),
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _dataHoraCtrl,
              readOnly: true,
              decoration: InputDecoration(
                labelText: widget.modoEdicao
                    ? 'Data/Hora do Registro'
                    : 'Data/Hora do Registro *',
                prefixIcon: const Icon(Icons.calendar_today),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.access_time),
                  onPressed: () async {
                    final dt = await showDatePicker(
                      context: context,
                      initialDate: _registroDt,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (dt != null) {
                      final tm = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(_registroDt),
                      );
                      if (tm != null) {
                        setState(() {
                          _registroDt = DateTime(
                            dt.year,
                            dt.month,
                            dt.day,
                            tm.hour,
                            tm.minute,
                          );
                          _dataHoraCtrl.text = _formatDateTime(_registroDt);
                        });
                      }
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving
                        ? null
                        : () async {
                            if (widget.onCancelar != null) {
                              widget.onCancelar!();
                            } else {
                              final sair = await _confirmarSaida();
                              if (!mounted) return;
                              if (sair) Navigator.of(context).pop();
                            }
                          },
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving ? null : _onSubmit,
                    child: _saving
                        ? const CircularProgressIndicator()
                        : Text(
                            widget.modoEdicao ? 'Salvar Alterações' : 'Salvar',
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
