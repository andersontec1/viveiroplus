import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/degrade_fundo.dart';

class TelaNovoCiclo extends StatefulWidget {
  final Map<String, dynamic>? cicloExistente;
  final String? cicloId;

  const TelaNovoCiclo({super.key, this.cicloExistente, this.cicloId});

  @override
  State<TelaNovoCiclo> createState() => _TelaNovoCicloState();
}

class _TelaNovoCicloState extends State<TelaNovoCiclo> {
  static const _corPrimariaEscura = Color(0xFF045D3A);
  static const _corPrimaria = Color(0xFF049F56);

  final _formKey = GlobalKey<FormState>();
  final _qtdCtrl = TextEditingController();
  final _pesoCtrl = TextEditingController();
  final _plDiaCtrl = TextEditingController();
  final _plGramaCtrl = TextEditingController();
  final _dataInicioCtrl = TextEditingController();
  final _previsaoCtrl = TextEditingController();

  String? _codigoSelecionado;
  DateTime _dataInicio = DateTime.now();
  DateTime? _previsaoEncerramento;
  Map<String, String> _destinos = {};
  bool _salvando = false;

  bool get _editando => widget.cicloId != null;

  @override
  void initState() {
    super.initState();
    _carregarDestinos().then((_) {
      if (widget.cicloExistente != null) {
        _preencherCamposParaEdicao(widget.cicloExistente!);
      }
      _sincronizarCamposDatas();
    });
  }

  @override
  void dispose() {
    _qtdCtrl.dispose();
    _pesoCtrl.dispose();
    _plDiaCtrl.dispose();
    _plGramaCtrl.dispose();
    _dataInicioCtrl.dispose();
    _previsaoCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregarDestinos() async {
    final mapa = <String, String>{};

    final snapViveiros = await FirebaseFirestore.instance
        .collection('viveiros')
        .get();
    for (final doc in snapViveiros.docs) {
      final data = doc.data();
      mapa['V-${data['codigo']}'] = '🐟 ${data['nome']} (Viveiro)';
    }

    final snapBercarios = await FirebaseFirestore.instance
        .collection('bercarios')
        .get();
    for (final doc in snapBercarios.docs) {
      final data = doc.data();
      mapa['B-${data['codigo']}'] = '🦐 ${data['nome']} (Berçário)';
    }

    if (mounted) {
      setState(() => _destinos = mapa);
    }
  }

  // Formatter simples para data no formato dd/MM/aaaa
  // Aceita apenas dígitos e insere as barras automaticamente.
  // Limita a 8 dígitos (10 caracteres com as barras).
  static final _dateDigitsOnly = FilteringTextInputFormatter.digitsOnly;
  static final _dateMaxLength = LengthLimitingTextInputFormatter(8);

  static final _dateInputFormatter = _DateInputFormatter();

  void _preencherCamposParaEdicao(Map<String, dynamic> ciclo) {
    final tipo = ciclo['tipo'] as String? ?? '';
    final codigo = (ciclo['codigo'] ?? '').toString();
    _codigoSelecionado = tipo == 'viveiro'
        ? 'V-$codigo'
        : tipo == 'bercario'
        ? 'B-$codigo'
        : null;

    final qtd = ciclo['quantidadeEstocada'];
    if (qtd is num) {
      _qtdCtrl.text = _formatarMilhares(qtd.toInt());
    } else if (qtd is String && qtd.isNotEmpty) {
      final v = int.tryParse(qtd.replaceAll('.', ''));
      _qtdCtrl.text = v != null ? _formatarMilhares(v) : qtd;
    } else {
      _qtdCtrl.text = '';
    }
    _pesoCtrl.text = (ciclo['pesoInicial'] ?? '').toString();
    _plDiaCtrl.text = (ciclo['plDia'] ?? '').toString();
    _plGramaCtrl.text = (ciclo['plGrama'] ?? '').toString();

    final dataInicioTs = ciclo['dataInicio'];
    if (dataInicioTs is Timestamp) {
      _dataInicio = dataInicioTs.toDate();
    }
    final prevTs = ciclo['previsaoEncerramento'];
    if (prevTs is Timestamp) {
      _previsaoEncerramento = prevTs.toDate();
    }
    _sincronizarCamposDatas();
  }

  void _sincronizarCamposDatas() {
    _dataInicioCtrl.text = _formatarData(_dataInicio);
    _previsaoCtrl.text = _previsaoEncerramento != null
        ? _formatarData(_previsaoEncerramento!)
        : '';
  }

  String _formatarData(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = d.year.toString();
    return '$dd/$mm/$yy';
  }

  String _formatarMilhares(int value) {
    final s = value.toString();
    final buf = StringBuffer();
    var count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      buf.write(s[i]);
      count++;
      if (count == 3 && i != 0) {
        buf.write('.');
        count = 0;
      }
    }
    return buf.toString().split('').reversed.join();
  }

  DateTime? _parseData(String input) {
    final t = input.trim();
    final re = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$');
    final m = re.firstMatch(t);
    if (m == null) return null;
    final d = int.tryParse(m.group(1)!);
    final mth = int.tryParse(m.group(2)!);
    final y = int.tryParse(m.group(3)!);
    if (d == null || mth == null || y == null) return null;
    try {
      final parsed = DateTime(y, mth, d);
      if (parsed.day == d && parsed.month == mth && parsed.year == y) {
        return parsed;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _salvarCiclo() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);

    if (_previsaoEncerramento != null &&
        _previsaoEncerramento!.isBefore(_dataInicio)) {
      if (mounted) {
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
      }
      setState(() => _salvando = false);
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      String nomeUsuario = '—';
      if (user != null) {
        final snap = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user.uid)
            .get();
        nomeUsuario = (snap.data()?['nome'] as String?) ?? '—';
      }

      final tipo = _codigoSelecionado!.startsWith('V-')
          ? 'viveiro'
          : 'bercario';
      final codigoLimpo = _codigoSelecionado!.substring(2);
      final nomeLimpo =
          _destinos[_codigoSelecionado]
              ?.replaceAll(RegExp(r'🐟|🦐|\s*\(.*\)'), '')
              .trim() ??
          '—';

      final dados = <String, dynamic>{
        'codigo': codigoLimpo,
        'nome': nomeLimpo,
        'tipo': tipo,
        'dataInicio': Timestamp.fromDate(_dataInicio),
        'previsaoEncerramento': _previsaoEncerramento != null
            ? Timestamp.fromDate(_previsaoEncerramento!)
            : null,
        'quantidadeEstocada': int.parse(_qtdCtrl.text.replaceAll('.', '')),
        'pesoInicial':
            double.tryParse(_pesoCtrl.text.replaceAll(',', '.')) ?? 0.0,
        'plDia': _plDiaCtrl.text.isNotEmpty
            ? double.tryParse(_plDiaCtrl.text.replaceAll(',', '.'))
            : null,
        'plGrama': _plGramaCtrl.text.isNotEmpty
            ? double.tryParse(_plGramaCtrl.text.replaceAll(',', '.'))
            : null,
      };

      final ciclosRef = FirebaseFirestore.instance.collection('ciclos');

      if (_editando && widget.cicloId != null) {
        await ciclosRef.doc(widget.cicloId).update(dados);
      } else {
        final existe = await ciclosRef
            .where('codigo', isEqualTo: codigoLimpo)
            .where('tipo', isEqualTo: tipo)
            .where('encerrado', isEqualTo: false)
            .get();
        if (existe.docs.isNotEmpty) {
          final tipoTexto = tipo == 'viveiro' ? 'viveiro' : 'berçário';
          if (mounted) {
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
          }
          setState(() => _salvando = false);
          return;
        }

        await ciclosRef.add({
          ...dados,
          'encerrado': false,
          'abertoPor': nomeUsuario,
          'criadoEm': Timestamp.now(),
        });
      }

      if (mounted) {
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
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
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
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _selecionarDataInicio() async {
    final selecionada = await showDatePicker(
      context: context,
      initialDate: _dataInicio,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selecionada != null) {
      setState(() {
        _dataInicio = selecionada;
        _dataInicioCtrl.text = _formatarData(selecionada);
      });
    }
  }

  Future<void> _selecionarPrevisao() async {
    final base = _previsaoEncerramento ?? _dataInicio;
    final selecionada = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: _dataInicio,
      lastDate: DateTime(2100),
    );
    if (selecionada != null) {
      setState(() {
        _previsaoEncerramento = selecionada;
        _previsaoCtrl.text = _formatarData(selecionada);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _editando ? 'Editar Ciclo' : 'Novo Ciclo',
      body: DegradeFundo(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [_corPrimariaEscura, _corPrimaria],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.timeline,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _editando
                                  ? 'Editar ciclo existente'
                                  : 'Cadastrar novo ciclo',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _corPrimariaEscura,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Defina o viveiro/berçário, biomassa inicial e datas para controlar melhor a produção.',
                          style: TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: _codigoSelecionado,
                    items: () {
                      final sortedEntries = _destinos.entries.toList()
                        ..sort((a, b) => a.key.compareTo(b.key));
                      return sortedEntries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text('${e.value} (cód: ${e.key})'),
                            ),
                          )
                          .toList();
                    }(),
                    onChanged: (val) =>
                        setState(() => _codigoSelecionado = val),
                    decoration: InputDecoration(
                      labelText: 'Viveiro ou Berçário',
                      labelStyle: TextStyle(
                        color: _corPrimariaEscura.withValues(alpha: 0.8),
                      ),
                      prefixIcon: const Icon(
                        Icons.water_damage,
                        color: _corPrimaria,
                      ),
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
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(15)),
                        borderSide: BorderSide(color: _corPrimaria, width: 2),
                      ),
                    ),
                    dropdownColor: Colors.white,
                    style: const TextStyle(color: _corPrimariaEscura),
                    validator: (v) =>
                        v == null ? 'Selecione o viveiro ou berçário' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _qtdCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _ThousandsInputFormatter(),
                    ],
                    style: const TextStyle(color: _corPrimariaEscura),
                    decoration: InputDecoration(
                      labelText: 'Quantidade Estocada (pós-larvas)',
                      labelStyle: TextStyle(
                        color: _corPrimariaEscura.withValues(alpha: 0.8),
                      ),
                      prefixIcon: const Icon(
                        Icons.numbers,
                        color: _corPrimaria,
                      ),
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
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(15)),
                        borderSide: BorderSide(color: _corPrimaria, width: 2),
                      ),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Informe a quantidade' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _pesoCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(color: _corPrimariaEscura),
                    decoration: InputDecoration(
                      labelText: 'Peso Médio Inicial (g)',
                      labelStyle: TextStyle(
                        color: _corPrimariaEscura.withValues(alpha: 0.8),
                      ),
                      prefixIcon: const Icon(Icons.scale, color: _corPrimaria),
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
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(15)),
                        borderSide: BorderSide(color: _corPrimaria, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _plDiaCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(color: _corPrimariaEscura),
                    decoration: InputDecoration(
                      labelText: 'PL / Dia',
                      hintText: 'Opcional',
                      labelStyle: TextStyle(
                        color: _corPrimariaEscura.withValues(alpha: 0.8),
                      ),
                      prefixIcon: const Icon(Icons.today, color: _corPrimaria),
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
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(15)),
                        borderSide: BorderSide(color: _corPrimaria, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_codigoSelecionado != null &&
                      _codigoSelecionado!.startsWith('B-'))
                    TextFormField(
                      controller: _plGramaCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(color: _corPrimariaEscura),
                      decoration: InputDecoration(
                        labelText: 'PL / g (Berçário)',
                        hintText: 'Opcional',
                        labelStyle: TextStyle(
                          color: _corPrimariaEscura.withValues(alpha: 0.8),
                        ),
                        prefixIcon: const Icon(
                          Icons.straighten,
                          color: _corPrimaria,
                        ),
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
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(15)),
                          borderSide: BorderSide(color: _corPrimaria, width: 2),
                        ),
                      ),
                    ),
                  if (_codigoSelecionado != null &&
                      _codigoSelecionado!.startsWith('B-'))
                    const SizedBox(height: 16),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _dataInicioCtrl,
                          decoration: InputDecoration(
                            labelText: 'Data de início (dd/MM/aaaa)',
                            labelStyle: TextStyle(
                              color: _corPrimariaEscura.withValues(alpha: 0.8),
                            ),
                            prefixIcon: const Icon(
                              Icons.date_range,
                              color: _corPrimaria,
                            ),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.event),
                              onPressed: _selecionarDataInicio,
                            ),
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
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(15),
                              ),
                              borderSide: BorderSide(
                                color: _corPrimaria,
                                width: 2,
                              ),
                            ),
                          ),
                          keyboardType: TextInputType.datetime,
                          inputFormatters: [
                            _dateDigitsOnly,
                            _dateMaxLength,
                            _dateInputFormatter,
                          ],
                          onChanged: (_) {
                            final d = _parseData(_dataInicioCtrl.text);
                            if (d != null) setState(() => _dataInicio = d);
                          },
                          validator: (v) {
                            final d = _parseData(v ?? '');
                            if (d == null) return 'Informe uma data válida';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _previsaoCtrl,
                          decoration: InputDecoration(
                            labelText: 'Previsão de encerramento (opcional)',
                            labelStyle: TextStyle(
                              color: _corPrimariaEscura.withValues(alpha: 0.8),
                            ),
                            prefixIcon: const Icon(
                              Icons.event,
                              color: _corPrimaria,
                            ),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_previsaoCtrl.text.isNotEmpty)
                                  IconButton(
                                    tooltip: 'Limpar',
                                    icon: const Icon(
                                      Icons.clear,
                                      color: Colors.redAccent,
                                    ),
                                    onPressed: () => setState(() {
                                      _previsaoEncerramento = null;
                                      _previsaoCtrl.clear();
                                    }),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.edit_calendar),
                                  onPressed: _selecionarPrevisao,
                                ),
                              ],
                            ),
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
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(15),
                              ),
                              borderSide: BorderSide(
                                color: _corPrimaria,
                                width: 2,
                              ),
                            ),
                          ),
                          keyboardType: TextInputType.datetime,
                          inputFormatters: [
                            _dateDigitsOnly,
                            _dateMaxLength,
                            _dateInputFormatter,
                          ],
                          onChanged: (_) {
                            final d = _parseData(_previsaoCtrl.text);
                            setState(() => _previsaoEncerramento = d);
                          },
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            final d = _parseData(v);
                            if (d == null) return 'Data inválida';
                            if (d.isBefore(_dataInicio)) {
                              return 'Previsão não pode ser antes do início';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_corPrimariaEscura, _corPrimaria],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: _corPrimariaEscura.withValues(alpha: 0.4),
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
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(Icons.save, color: Colors.white),
                        label: Text(
                          _salvando
                              ? 'Salvando...'
                              : _editando
                              ? 'Atualizar Ciclo'
                              : 'Salvar Ciclo',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        onPressed: _salvando ? null : _salvarCiclo,
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
          ),
        ),
      ),
    );
  }
}

class _DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length && i < 8; i++) {
      buffer.write(digits[i]);
      if (i == 1 || i == 3) buffer.write('/');
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
      composing: TextRange.empty,
    );
  }
}

class _ThousandsInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }
    final formatted = _format(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
      composing: TextRange.empty,
    );
  }

  String _format(String digits) {
    final buf = StringBuffer();
    var count = 0;
    for (int i = digits.length - 1; i >= 0; i--) {
      buf.write(digits[i]);
      count++;
      if (count == 3 && i != 0) {
        buf.write('.');
        count = 0;
      }
    }
    return buf.toString().split('').reversed.join();
  }
}
