import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/degrade_fundo.dart';

class TelaAnaliseAgua extends StatefulWidget {
  const TelaAnaliseAgua({super.key});
  @override
  _TelaAnaliseAguaState createState() => _TelaAnaliseAguaState();
}

class _TelaAnaliseAguaState extends State<TelaAnaliseAgua> {
  final _formKey = GlobalKey<FormState>();
  final _phCtrl = TextEditingController();
  final _oxCtrl = TextEditingController();
  final _tempCtrl = TextEditingController();
  final _salinityCtrl = TextEditingController();
  final _calcCtrl = TextEditingController();
  final _nitritoCtrl = TextEditingController();
  final _amoniaCtrl = TextEditingController();
  final _turbidezCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();
  final _saturacaoPorcCtrl = TextEditingController();
  final _saturacaoOxCtrl = TextEditingController();

  DateTime _registroDt = DateTime.now();
  bool _saving = false;
  String? _codigoSelecionado;
  String? _tipoSelecionado;
  Map<String, String> _mapaDestinos = {};
  Map<String, String> _viveiros = {};
  Map<String, String> _bercarios = {};
  bool _temCampoPreenchido = false;

  @override
  void initState() {
    super.initState();
    _carregarDestinos();
    _carregarPermissoes();
    _phCtrl.addListener(_verificarCampos);
    _oxCtrl.addListener(_verificarCampos);
    _tempCtrl.addListener(_verificarCampos);
    _salinityCtrl.addListener(_verificarCampos);
    _calcCtrl.addListener(_verificarCampos);
    _nitritoCtrl.addListener(_verificarCampos);
    _amoniaCtrl.addListener(_verificarCampos);
    _turbidezCtrl.addListener(_verificarCampos);
    _obsCtrl.addListener(_verificarCampos);
  }

  void _verificarCampos() {
    setState(() {
      _temCampoPreenchido = _phCtrl.text.isNotEmpty ||
          _oxCtrl.text.isNotEmpty ||
          _tempCtrl.text.isNotEmpty ||
          _salinityCtrl.text.isNotEmpty ||
          _calcCtrl.text.isNotEmpty ||
          _nitritoCtrl.text.isNotEmpty ||
          _amoniaCtrl.text.isNotEmpty ||
          _turbidezCtrl.text.isNotEmpty ||
          _obsCtrl.text.isNotEmpty;
    });
  }

  Future<void> _carregarPermissoes() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Permissões não são mais usadas nesta tela
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
      
      // Combinar sem conflitos (NÃO MAIS NECESSÁRIO com a nova lógica)
      final mapa = <String, String>{};
      mapa.addAll(viveiros);
      mapa.addAll(bercarios);
      
      setState(() {
        _viveiros = viveiros;
        _bercarios = bercarios;
        _mapaDestinos = mapa;
      });
      
      print('DEBUG ANALISE: Viveiros carregados: $_viveiros');
      print('DEBUG ANALISE: Berçários carregados: $_bercarios');
      print('DEBUG ANALISE: Mapa geral: $_mapaDestinos');
    } catch (e) {
      print('DEBUG ANALISE: Erro ao carregar destinos: $e');
    }
  }

  String _formatDateTime(DateTime dt) {
    return DateFormat('dd/MM/yyyy HH:mm').format(dt);
  }

  bool _foraFaixa(String tipo, double valor) {
    switch (tipo) {
      case 'ph': return valor < 7.5 || valor > 8.5;
      case 'ox': return valor < 5.0 || valor > 8.0;
      case 'temp': return valor < 28.0 || valor > 32.0;
      case 'sal': return valor < 15.0 || valor > 25.0;
      case 'calc': return valor < 100 || valor > 300;
      case 'nitrito': return valor > 1.0;
      case 'amonia': return valor > 0.5;
      case 'turbidez': return valor < 0.0 || valor > 50.0;
      case 'saturacao_percentual': return valor < 80.0 || valor > 120.0;
      case 'saturacao_oxigenio': return valor < 80.0 || valor > 120.0;
      default: return false;
    }
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_codigoSelecionado == null || _tipoSelecionado == null) return;

    final ph = double.tryParse(_phCtrl.text) ?? 0.0;
    final ox = double.tryParse(_oxCtrl.text) ?? 0.0;
    final temp = double.tryParse(_tempCtrl.text) ?? 0.0;
    final sal = double.tryParse(_salinityCtrl.text) ?? 0.0;
    final calc = double.tryParse(_calcCtrl.text) ?? 0.0;
    final nitrito = double.tryParse(_nitritoCtrl.text.isEmpty ? '0' : _nitritoCtrl.text) ?? 0.0;
    final amonia = double.tryParse(_amoniaCtrl.text.isEmpty ? '0' : _amoniaCtrl.text) ?? 0.0;
    final turbidez = double.tryParse(_turbidezCtrl.text) ?? 0.0;
    final saturacaoPorc = double.tryParse(_saturacaoPorcCtrl.text) ?? 0.0;
    final saturacaoOx = double.tryParse(_saturacaoOxCtrl.text) ?? 0.0;

    final List<Map<String, dynamic>> fora = [];
    if (_foraFaixa('ph', ph)) fora.add({'nome': 'pH', 'valor': ph, 'ideal': '7.5 – 8.5'});
    if (_foraFaixa('ox', ox)) fora.add({'nome': 'Oxigênio', 'valor': ox, 'ideal': '5.0 – 8.0'});
    if (_foraFaixa('temp', temp)) fora.add({'nome': 'Temperatura', 'valor': temp, 'ideal': '28.0 – 32.0'});
    if (_foraFaixa('sal', sal)) fora.add({'nome': 'Salinidade', 'valor': sal, 'ideal': '15.0 – 25.0'});
    if (_foraFaixa('calc', calc)) fora.add({'nome': 'Cálcio', 'valor': calc, 'ideal': '100 – 300'});
    if (_foraFaixa('nitrito', nitrito)) fora.add({'nome': 'Nitrito', 'valor': nitrito, 'ideal': '≤ 1.0'});
    if (_foraFaixa('amonia', amonia)) fora.add({'nome': 'Amônia', 'valor': amonia, 'ideal': '≤ 0.5'});

    if (fora.isNotEmpty) {
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
              ...fora.map((param) => Padding(
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
      if (continuar != true) return;
    }

    setState(() => _saving = true);

    final col = FirebaseFirestore.instance.collection('registros_diarios');
    
    // Buscar o nome correto baseado no tipo selecionado
    final nome = _tipoSelecionado == 'viveiro' 
        ? (_viveiros[_codigoSelecionado!] ?? '—')
        : (_bercarios[_codigoSelecionado!] ?? '—');
        
    print('DEBUG ANALISE: Salvando registro - Tipo: $_tipoSelecionado, Código: $_codigoSelecionado, Nome: $nome');
    
    String nomeUsuario = '—';

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      nomeUsuario = doc.data()?['nome'] ?? '—';
    }

    await col.add({
      'tipoDestino': _tipoSelecionado,
      'codigo': _codigoSelecionado,
      'nome': nome,
      'ph': ph,
      'oxigenio': ox,
      'temperatura': temp,
      'turbidez': turbidez,
      'salinidade': sal,
      'calcio': calc,
      'nitrito': nitrito,
      'amonia': amonia,
      'observacoes': _obsCtrl.text.trim(),
      'dataHora': Timestamp.fromDate(_registroDt),
      'criadoEm': Timestamp.now(),
      'registradoPor': nomeUsuario,
      'saturacao_percentual': saturacaoPorc,
      'saturacao_oxigenio': saturacaoOx,
    });

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.green.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 8),
            Text('Registro Salvo!', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('A análise foi registrada com sucesso.', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text('Você pode consultar ou editar este registro na tela de listagem.', style: TextStyle(color: Colors.teal)),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            icon: const Icon(Icons.done, color: Colors.white),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.of(context).pop(),
            label: const Text('Fechar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    Navigator.of(context).pop();
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
    _phCtrl.dispose();
    _oxCtrl.dispose();
    _tempCtrl.dispose();
    _salinityCtrl.dispose();
    _calcCtrl.dispose();
    _nitritoCtrl.dispose();
    _amoniaCtrl.dispose();
    _turbidezCtrl.dispose();
    _obsCtrl.dispose();
    _saturacaoPorcCtrl.dispose();
    _saturacaoOxCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _confirmarSaida,
      child: AppScaffold(
        title: 'Análise da Água',
        body: DegradeFundo(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  const SizedBox(height: 10),
                  const Center(
                    child: Column(
                      children: [
                        Icon(Icons.science, size: 48),
                        SizedBox(height: 6),
                        Text(
                          'Análise da Água',
                          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Registre os parâmetros de qualidade da água dos viveiros e berçários de forma rápida e segura',
                          style: TextStyle(fontSize: 15, color: Colors.teal, fontWeight: FontWeight.w400),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 20),
                      ],
                    ),
                  ),
                  // Card informativo de horários e parâmetros
                  Card(
                    color: const Color(0xFFe3f2fd),
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 18),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.schedule, color: Colors.blue, size: 22),
                              SizedBox(width: 8),
                              Text('Horários e Parâmetros de Análise', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _linhaHorario('4:00', 'Oxigênio e Saturação'),
                          _linhaHorario('8:00', 'pH, Amônia e Nitrito'),
                          _linhaHorario('13:00', 'Turbidez(NTU), Temperatura e Salinidade'),
                          _linhaHorario('16:00', 'pH, Oxigênio e Saturação'),
                          const SizedBox(height: 8),
                          const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline, color: Colors.orange, size: 18),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Obs: Amônia e Nitrito — 1 Vez por semana nos Viveiros, e 3 Vezes por Semana nos Berçários.',
                                  style: TextStyle(fontSize: 13, color: Colors.black87),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
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
                      _codigoSelecionado = null; // Reseta o código quando o tipo muda
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
                      // Retorna os itens baseado no tipo selecionado
                      Map<String, String> destinosParaMostrar = {};
                      
                      if (_tipoSelecionado == 'viveiro') {
                        destinosParaMostrar = _viveiros;
                      } else if (_tipoSelecionado == 'bercario') {
                        destinosParaMostrar = _bercarios;
                      }
                      
                      // Ordenar por código antes de retornar
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
                  // --- Divisão dos parâmetros ---
                  const Divider(thickness: 2, height: 32),
                  const Center(
                    child: Text(
                      'Parâmetros Físicos',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _campoNumComFaixa(_phCtrl, 'pH da Água', Icons.grain, 7.5, 8.5, 'ph', obrigatorio: false),
                  _campoNumComFaixa(_oxCtrl, 'Oxigênio Dissolvido (mg/L)', Icons.air, 5.0, 8.0, 'ox', obrigatorio: false),
                  _campoNumComFaixa(_tempCtrl, 'Temperatura (°C)', Icons.thermostat, 28.0, 32.0, 'temp', obrigatorio: false),
                  _campoNumComFaixa(_turbidezCtrl, 'Turbidez (NTU)', Icons.blur_on, 0.0, 50.0, 'turbidez', obrigatorio: false),
                  // Saturação percentual (com faixa ideal e cor)
                  _campoNumComFaixa(
                    _saturacaoPorcCtrl,
                    'Porcentagem de Saturação (%)',
                    Icons.percent,
                    80.0,
                    120.0,
                    'saturacao_percentual',
                    obrigatorio: false,
                  ),
                  // Saturação O2 dissolvido (com faixa ideal e cor)
                  _campoNumComFaixa(
                    _saturacaoOxCtrl,
                    'Saturação de O2 Dissolvido (%)',
                    Icons.bubble_chart,
                    80.0,
                    120.0,
                    'saturacao_oxigenio',
                    obrigatorio: false,
                  ),
                  const Divider(thickness: 2, height: 32),
                  const Center(
                    child: Text(
                      'Parâmetros Químicos',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _campoNumComFaixa(_salinityCtrl, 'Salinidade (ppt)', Icons.opacity, 15.0, 25.0, 'sal', obrigatorio: false),
                  _campoNumComFaixa(_calcCtrl, 'Cálcio (mg/L)', Icons.science_outlined, 100.0, 300.0, 'calc', obrigatorio: false),
                  _campoNumComFaixa(_nitritoCtrl, 'Nitrito (mg/L)', Icons.warning_amber, 0.0, 1.0, 'nitrito', obrigatorio: false),
                  _campoNumComFaixa(_amoniaCtrl, 'Amônia (mg/L)', Icons.dangerous, 0.0, 0.5, 'amonia', obrigatorio: false),
                  TextFormField(
                    controller: _obsCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Observações',
                      prefixIcon: Icon(Icons.note_alt),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Campo de data/hora do registro (editável para todos)
                  TextFormField(
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Data/Hora do Registro',
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
                              setState(() => _registroDt =
                                  DateTime(dt.year, dt.month, dt.day, tm.hour, tm.minute));
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
                          onPressed: () async {
                            final sair = await _confirmarSaida();
                            if (sair) Navigator.of(context).pop();
                          },
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saving ? null : _onSubmit,
                          child: _saving ? const CircularProgressIndicator() : const Text('Salvar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _campoNumComFaixa(
    TextEditingController controller,
    String label,
    IconData icon,
    double min,
    double max,
    String tipo, {
    bool obrigatorio = true,
  }) {
    final text = controller.text;
    final valor = double.tryParse(text);
    final fora = valor != null && _foraFaixa(tipo, valor);
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
            labelText: label,
            prefixIcon: Icon(icon),
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
          validator: obrigatorio
              ? (v) => v == null || v.isEmpty ? 'Informe $label' : null
              : null,
          onChanged: (_) => setState(() {}),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 4),
          child: Text(
            'Faixa ideal: $min – $max Fora disso, notifique o supervisor.',
            style: TextStyle(fontSize: 15, color: fora ? Colors.red : Colors.teal),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _linhaHorario(String hora, String parametros) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(hora, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(parametros, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }
}
