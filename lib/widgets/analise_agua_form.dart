import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

/// Configuração de um parâmetro da análise de água
class ParametroAnalise {
  final String label;
  final IconData icon;
  final double minIdeal;
  final double maxIdeal;
  final String chaveFirestore;
  final bool obrigatorio;

  const ParametroAnalise({
    required this.label,
    required this.icon,
    required this.minIdeal,
    required this.maxIdeal,
    required this.chaveFirestore,
    this.obrigatorio = false,
  });

  bool foraFaixa(double valor) {
    return valor < minIdeal || valor > maxIdeal;
  }

  String get faixaIdealTexto => '$minIdeal – $maxIdeal';
}

/// Widget reutilizável para formulário de análise de água
class AnaliseAguaForm extends StatefulWidget {
  final Map<String, dynamic>? dadosIniciais;
  final bool modoEdicao;
  final String? codigoSelecionado;
  final String? tipoSelecionado;
  final DateTime? dataHoraInicial;
  final Function(Map<String, dynamic> dados)? onSalvar;
  final VoidCallback? onCancelar;
  final bool mostrarSeletorDestino;

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
      minIdeal: 28.0,
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
      label: 'Saturação de O2 Dissolvido (%)',
      icon: Icons.bubble_chart,
      minIdeal: 80.0,
      maxIdeal: 120.0,
      chaveFirestore: 'saturacao_oxigenio',
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

  @override
  void initState() {
    super.initState();
    _inicializarControllers();
    _inicializarDados();
    _carregarDestinos();
    _adicionarListeners();
  }

  void _inicializarControllers() {
    // Inicializar controllers para todos os parâmetros
    for (final param in _parametros) {
      _controllers[param.chaveFirestore] = TextEditingController();
    }
    _obsCtrl = TextEditingController();
  }

  void _inicializarDados() {
    _registroDt = widget.dataHoraInicial ?? DateTime.now();
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
      }
    }
  }

  void _adicionarListeners() {
    for (final controller in _controllers.values) {
      controller.addListener(_verificarCampos);
    }
    _obsCtrl.addListener(_verificarCampos);
  }

  void _verificarCampos() {
    setState(() {
      _temCampoPreenchido = _controllers.values.any((c) => c.text.isNotEmpty) || 
                           _obsCtrl.text.isNotEmpty;
    });
  }

  Future<void> _carregarDestinos() async {
    if (!widget.mostrarSeletorDestino) return;
    
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
    } catch (e) {
      print('Erro ao carregar destinos: $e');
    }
  }

  String _formatDateTime(DateTime dt) {
    return DateFormat('dd/MM/yyyy HH:mm').format(dt);
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (widget.mostrarSeletorDestino && (_codigoSelecionado == null || _tipoSelecionado == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione o tipo e código do destino')),
      );
      return;
    }

    // Verificar campos preenchidos e fora de faixa
    final List<Map<String, dynamic>> foraFaixa = [];
    final Map<String, dynamic> dadosParaSalvar = {};

    for (final param in _parametros) {
      final controller = _controllers[param.chaveFirestore]!;
      if (controller.text.isNotEmpty) {
        final valor = double.tryParse(controller.text);
        if (valor != null) {
          dadosParaSalvar[param.chaveFirestore] = valor;
          if (param.foraFaixa(valor)) {
            foraFaixa.add({
              'nome': param.label,
              'valor': valor,
              'ideal': param.faixaIdealTexto,
            });
          }
        }
      }
    }

    // Adicionar observações e data/hora
    dadosParaSalvar['observacoes'] = _obsCtrl.text.trim();
    dadosParaSalvar['dataHora'] = Timestamp.fromDate(_registroDt);

    // Se não estamos em modo edição, adicionar dados do destino
    if (widget.mostrarSeletorDestino && !widget.modoEdicao) {
      final nome = _tipoSelecionado == 'viveiro' 
          ? (_viveiros[_codigoSelecionado!] ?? '—')
          : (_bercarios[_codigoSelecionado!] ?? '—');
          
      dadosParaSalvar['tipoDestino'] = _tipoSelecionado;
      dadosParaSalvar['codigo'] = _codigoSelecionado;
      dadosParaSalvar['nome'] = nome;
      dadosParaSalvar['criadoEm'] = Timestamp.now();
      
      // Adicionar informações do usuário
      final user = FirebaseAuth.instance.currentUser;
      String nomeUsuario = '—';
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
        nomeUsuario = doc.data()?['nome'] ?? '—';
      }
      dadosParaSalvar['registradoPor'] = nomeUsuario;
    }

    // Se estamos em modo edição, adicionar dados de auditoria
    if (widget.modoEdicao) {
      final user = FirebaseAuth.instance.currentUser;
      String nomeUsuario = '—';
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
        nomeUsuario = doc.data()?['nome'] ?? '—';
      }
      dadosParaSalvar['editadoPor'] = nomeUsuario;
      dadosParaSalvar['editadoEm'] = Timestamp.now();
    }

    // Validar parâmetros fora de faixa
    if (foraFaixa.isNotEmpty) {
      final continuar = await _mostrarDialogoForaFaixa(foraFaixa);
      if (!continuar) return;
    }

    setState(() => _saving = true);

    // Chamar callback de salvamento
    if (widget.onSalvar != null) {
      widget.onSalvar!(dadosParaSalvar);
    }

    setState(() => _saving = false);
  }

  Future<bool> _mostrarDialogoForaFaixa(List<Map<String, dynamic>> foraFaixa) async {
    final continuar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 32),
            SizedBox(width: 8),
            Text('Parâmetro(s) fora da faixa', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Os seguintes parâmetros estão fora da faixa ideal:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...foraFaixa.map((param) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(Icons.error, color: Colors.red.shade400, size: 20),
                  const SizedBox(width: 6),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                        children: [
                          TextSpan(text: '${param['nome']}: ', style: const TextStyle(color: Colors.red)),
                          TextSpan(text: 'Valor: ${param['valor']}  '),
                          TextSpan(text: '(Ideal: ${param['ideal']})', style: const TextStyle(color: Colors.teal)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 16),
            const Text('Deseja continuar mesmo assim?', style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continuar', style: TextStyle(color: Colors.white)),
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
      builder: (_) => AlertDialog(
        title: const Text('Descartar dados?'),
        content: const Text('Há dados preenchidos. Tem certeza que deseja sair?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sair')),
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
    super.dispose();
  }

  Widget _buildCampoParametro(ParametroAnalise param) {
    final controller = _controllers[param.chaveFirestore]!;
    final text = controller.text;
    final valor = double.tryParse(text);
    final fora = valor != null && param.foraFaixa(valor);
    
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
            'Faixa ideal: ${param.faixaIdealTexto} Fora disso, notifique o supervisor.',
            style: TextStyle(fontSize: 15, color: fora ? Colors.red : Colors.teal),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildSeletorDestino() {
    if (!widget.mostrarSeletorDestino) return const SizedBox.shrink();

    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: _tipoSelecionado,
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
          value: _codigoSelecionado,
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
                .map((e) => DropdownMenuItem(
                      value: e.key,
                      child: Text('${e.value} (cód: ${e.key})'),
                    ))
                .toList();
          })(),
          onChanged: (value) => setState(() => _codigoSelecionado = value),
          validator: (v) => v == null || v.isEmpty ? 'Selecione o código' : null,
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _confirmarSaida,
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            _buildSeletorDestino(),
            
            const Divider(thickness: 2, height: 32),
            const Center(
              child: Text(
                'Parâmetros Físicos',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal),
              ),
            ),
            const SizedBox(height: 8),
            
            // Parâmetros físicos
            _buildCampoParametro(_parametros[0]), // pH
            _buildCampoParametro(_parametros[1]), // Oxigênio
            _buildCampoParametro(_parametros[2]), // Saturação percentual
            _buildCampoParametro(_parametros[3]), // Temperatura
            _buildCampoParametro(_parametros[4]), // Turbidez
            _buildCampoParametro(_parametros[5]), // Saturação O2
            
            const Divider(thickness: 2, height: 32),
            const Center(
              child: Text(
                'Parâmetros Químicos',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal),
              ),
            ),
            const SizedBox(height: 8),
            
            // Parâmetros químicos
            _buildCampoParametro(_parametros[6]), // Salinidade
            _buildCampoParametro(_parametros[7]), // Cálcio
            _buildCampoParametro(_parametros[8]), // Nitrito
            _buildCampoParametro(_parametros[9]), // Amônia
            
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
              readOnly: true,
              decoration: InputDecoration(
                labelText: widget.modoEdicao ? 'Data/Hora do Registro' : 'Data/Hora do Registro *',
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
                        setState(() => _registroDt = DateTime(dt.year, dt.month, dt.day, tm.hour, tm.minute));
                      }
                    }
                  },
                ),
                hintText: _formatDateTime(_registroDt),
              ),
            ),
            const SizedBox(height: 24),
            
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () async {
                      if (widget.onCancelar != null) {
                        widget.onCancelar!();
                      } else {
                        final sair = await _confirmarSaida();
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
                        : Text(widget.modoEdicao ? 'Salvar Alterações' : 'Salvar'),
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
