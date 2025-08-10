// Tela de Despesca - Controle operacional do processo de colheita

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/degrade_fundo.dart';
import 'tela_encerramento_ciclo.dart';

class TelaDespesca extends StatefulWidget {
  const TelaDespesca({super.key});

  @override
  State<TelaDespesca> createState() => _TelaDespescaState();
}

class _TelaDespescaState extends State<TelaDespesca> {
  static const _corPrimaria = Color(0xFF049F56);

  final _formKey = GlobalKey<FormState>();
  final _pesoCtrl = TextEditingController();
  final _observacoesCtrl = TextEditingController();

  String? _codigoSelecionado;
  Map<String, String> _viveiros = {};
  Map<String, dynamic>? _cicloAtivo;
  List<Map<String, dynamic>> _despescasAndamento = [];
  DateTime _dataDespesca = DateTime.now();
  TimeOfDay _horaInicio = TimeOfDay.now();
  TimeOfDay? _horaFim;
  bool _despescaFinalizada = false;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _carregarViveiros();
  }

  Future<void> _carregarViveiros() async {
    final snap = await FirebaseFirestore.instance
        .collection('viveiros')
        .orderBy('codigo')
        .get();
    final mapa = <String, String>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      mapa[data['codigo']] = data['nome'];
    }
    setState(() => _viveiros = mapa);
  }

  Future<void> _buscarCicloAtivo(String codigo) async {
    try {
      // Buscar ciclo ativo
      final snap = await FirebaseFirestore.instance
          .collection('ciclos')
          .where('codigo', isEqualTo: codigo)
          .where('encerrado', isEqualTo: false)
          .limit(1)
          .get();
      
      if (snap.docs.isNotEmpty) {
        setState(() => _cicloAtivo = snap.docs.first.data());
        await _carregarDespescasAndamento();
      } else {
        setState(() => _cicloAtivo = null);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('⚠️ Nenhum ciclo ativo encontrado para este viveiro'),
          backgroundColor: Colors.orange,
        ));
      }
    } catch (e) {
      print('Erro ao buscar ciclo ativo: $e');
    }
  }

  Future<void> _carregarDespescasAndamento() async {
    if (_codigoSelecionado == null) return;
    
    final snap = await FirebaseFirestore.instance
        .collection('despescas')
        .where('codigo', isEqualTo: _codigoSelecionado)
        .get();

    final despescas = snap.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList();
    
    // Ordenar no lado do cliente por data de criação (mais recente primeiro)
    despescas.sort((a, b) {
      final dataA = (a['criadoEm'] as Timestamp).toDate();
      final dataB = (b['criadoEm'] as Timestamp).toDate();
      return dataB.compareTo(dataA);
    });

    setState(() {
      _despescasAndamento = despescas;
    });
  }

  Future<void> _salvarDespesca() async {
    if (!_formKey.currentState!.validate() || _cicloAtivo == null) return;

    setState(() => _salvando = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuário não autenticado');

      final nomeUsuario = (await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get()).data()?['nome'] ?? '—';

      final peso = double.tryParse(_pesoCtrl.text.replaceAll(',', '.')) ?? 0;

      // Combinar data e horários
      final dataHoraInicio = DateTime(
        _dataDespesca.year,
        _dataDespesca.month,
        _dataDespesca.day,
        _horaInicio.hour,
        _horaInicio.minute,
      );

      DateTime? dataHoraFim;
      if (_horaFim != null) {
        dataHoraFim = DateTime(
          _dataDespesca.year,
          _dataDespesca.month,
          _dataDespesca.day,
          _horaFim!.hour,
          _horaFim!.minute,
        );
      }

      await FirebaseFirestore.instance.collection('despescas').add({
        'codigo': _codigoSelecionado,
        'nome': _viveiros[_codigoSelecionado] ?? '—',
        'cicloId': _cicloAtivo!['id'] ?? '',
        'dataDespesca': Timestamp.fromDate(_dataDespesca),
        'dataHoraInicio': Timestamp.fromDate(dataHoraInicio),
        'dataHoraFim': dataHoraFim != null ? Timestamp.fromDate(dataHoraFim) : null,
        'peso': peso,
        'observacoes': _observacoesCtrl.text.trim(),
        'despescaFinalizada': _despescaFinalizada,
        'registradoPor': nomeUsuario,
        'criadoEm': Timestamp.now(),
      });

      _limparFormulario();
      await _carregarDespescasAndamento();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Despesca registrada com sucesso!'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Erro ao salvar despesca: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }

    if (mounted) setState(() => _salvando = false);
  }

  void _limparFormulario() {
    _pesoCtrl.clear();
    _observacoesCtrl.clear();
    setState(() {
      _horaFim = null;
      _despescaFinalizada = false;
    });
  }

  String _formatarData(DateTime data) => DateFormat('dd/MM/yyyy').format(data);
  String _formatarHora(TimeOfDay hora) => '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}';

  String _calcularDuracao(DateTime inicio, DateTime fim) {
    final duracao = fim.difference(inicio);
    final horas = duracao.inHours;
    final minutos = duracao.inMinutes % 60;
    
    if (horas > 0) {
      return '${horas}h${minutos > 0 ? ' ${minutos}min' : ''}';
    } else {
      return '${minutos}min';
    }
  }

  Widget _buildResumoItem(String titulo, String valor, IconData icone, Color cor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icone, size: 16, color: cor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            valor,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: cor,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selecionarData() async {
    final data = await showDatePicker(
      context: context,
      initialDate: _dataDespesca,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (data != null) setState(() => _dataDespesca = data);
  }

  Future<void> _selecionarHoraInicio() async {
    final hora = await showTimePicker(context: context, initialTime: _horaInicio);
    if (hora != null) setState(() => _horaInicio = hora);
  }

  Future<void> _selecionarHoraFim() async {
    final hora = await showTimePicker(context: context, initialTime: _horaFim ?? TimeOfDay.now());
    if (hora != null) setState(() => _horaFim = hora);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '🦐 Despesca',
      body: DegradeFundo(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                // Header com informações
                Card(
                  color: _corPrimaria.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Icon(Icons.set_meal, size: 32, color: _corPrimaria),
                        const SizedBox(height: 8),
                        const Text(
                          'Controle Operacional de Despesca',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Registre peso retirado, data e horários de cada despesca',
                          style: TextStyle(color: Colors.grey.shade700),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Seleção do Viveiro
                DropdownButtonFormField<String>(
                  value: _codigoSelecionado,
                  decoration: const InputDecoration(
                    labelText: 'Viveiro',
                    prefixIcon: Icon(Icons.water),
                    border: OutlineInputBorder(),
                  ),
                  items: _viveiros.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text('${e.key} - ${e.value}')))
                      .toList(),
                  onChanged: (v) {
                    setState(() => _codigoSelecionado = v);
                    if (v != null) _buscarCicloAtivo(v);
                  },
                  validator: (v) => v == null ? 'Selecione o viveiro' : null,
                ),

                if (_cicloAtivo != null) ...[
                  const SizedBox(height: 16),
                  
                  // Informações do Ciclo Ativo
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('📊 Ciclo Ativo:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Início: ${_formatarData((_cicloAtivo!['dataInicio'] as Timestamp).toDate())}'),
                          Text('Densidade: ${_cicloAtivo!['densidadeInicial']} cam/m²'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Data da Despesca
                  InkWell(
                    onTap: _selecionarData,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Data da Despesca',
                        prefixIcon: Icon(Icons.calendar_today),
                        border: OutlineInputBorder(),
                      ),
                      child: Text(_formatarData(_dataDespesca)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Horários
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _selecionarHoraInicio,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Hora Início',
                              prefixIcon: Icon(Icons.access_time),
                              border: OutlineInputBorder(),
                            ),
                            child: Text(_formatarHora(_horaInicio)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: _selecionarHoraFim,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Hora Fim (opcional)',
                              prefixIcon: Icon(Icons.access_time_filled),
                              border: OutlineInputBorder(),
                            ),
                            child: Text(_horaFim != null ? _formatarHora(_horaFim!) : 'Não definida'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Peso Retirado
                  TextFormField(
                    controller: _pesoCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Peso Retirado (kg)',
                      prefixIcon: Icon(Icons.monitor_weight),
                      border: OutlineInputBorder(),
                      suffixText: 'kg',
                    ),
                    validator: (v) {
                      final val = double.tryParse((v ?? '').replaceAll(',', '.'));
                      if (val == null || val <= 0) return 'Informe um peso válido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Observações
                  TextFormField(
                    controller: _observacoesCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Observações (opcional)',
                      prefixIcon: Icon(Icons.notes),
                      border: OutlineInputBorder(),
                      hintText: 'Ex: Qualidade dos camarões, mortalidade observada...',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Checkbox de finalização
                  CheckboxListTile(
                    title: const Text('Marcar como despesca finalizada'),
                    subtitle: const Text('Esta é a última despesca deste viveiro'),
                    value: _despescaFinalizada,
                    onChanged: (v) => setState(() => _despescaFinalizada = v ?? false),
                    activeColor: _corPrimaria,
                  ),
                  const SizedBox(height: 20),

                  // Botões de Ação
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _salvando ? null : _salvarDespesca,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _corPrimaria,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          icon: _salvando 
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.save),
                          label: Text(_salvando ? 'Salvando...' : 'Registrar Despesca'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _limparFormulario,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade300,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        icon: const Icon(Icons.clear),
                        label: const Text('Limpar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Lista de Despescas
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '📋 Histórico de Despescas',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      // Botão de encerramento de ciclo
                      if (_despescasAndamento.any((d) => d['despescaFinalizada'] == true))
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TelaEncerramentoCiclo(
                                  codigoViveiro: _codigoSelecionado!,
                                  cicloAtivo: _cicloAtivo!,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.flag),
                          label: const Text('Encerrar Ciclo'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_despescasAndamento.isEmpty)
                    Card(
                      color: Colors.grey.shade50,
                      child: const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Icon(Icons.info_outline, size: 48, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('Nenhuma despesca registrada ainda.'),
                            SizedBox(height: 4),
                            Text(
                              'Registre a primeira despesca preenchendo os campos acima.',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._despescasAndamento.map((despesca) {
                      final dataDespesca = (despesca['dataDespesca'] as Timestamp).toDate();
                      final dataHoraInicio = (despesca['dataHoraInicio'] as Timestamp).toDate();
                      final dataHoraFim = despesca['dataHoraFim'] != null 
                          ? (despesca['dataHoraFim'] as Timestamp).toDate()
                          : null;
                      final finalizada = despesca['despescaFinalizada'] == true;
                      final criadoEm = (despesca['criadoEm'] as Timestamp).toDate();

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        elevation: finalizada ? 3 : 1,
                        color: finalizada ? Colors.green.shade50 : null,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header da despesca
                              Row(
                                children: [
                                  Icon(
                                    finalizada ? Icons.check_circle : Icons.access_time,
                                    color: finalizada ? Colors.green : _corPrimaria,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Despesca - ${_formatarData(dataDespesca)}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: finalizada ? FontWeight.bold : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  if (finalizada)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        'FINALIZADA',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Informações principais
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.monitor_weight, size: 18, color: Colors.teal),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Peso Retirado: ',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                        Text(
                                          '${despesca['peso']} kg',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.teal,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.schedule, size: 18, color: Colors.blue),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Horário: ',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                        Text(
                                          '${DateFormat('HH:mm').format(dataHoraInicio)}',
                                          style: const TextStyle(fontWeight: FontWeight.w500),
                                        ),
                                        if (dataHoraFim != null) ...[
                                          const Text(' até '),
                                          Text(
                                            DateFormat('HH:mm').format(dataHoraFim),
                                            style: const TextStyle(fontWeight: FontWeight.w500),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade100,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              _calcularDuracao(dataHoraInicio, dataHoraFim),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.blue,
                                              ),
                                            ),
                                          ),
                                        ] else ...[
                                          const Text(' • '),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.shade100,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              'Em andamento',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.orange,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Observações (se houver)
                              if (despesca['observacoes'] != null && despesca['observacoes'].toString().isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.amber.shade200),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.note_alt, size: 16, color: Colors.amber.shade700),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Observações:',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              color: Colors.amber.shade700,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        despesca['observacoes'],
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // Informações de registro
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Registrado por: ${despesca['registradoPor']}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'Reg. em ${DateFormat('dd/MM/yy HH:mm').format(criadoEm)}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),

                  // Resumo estatístico
                  if (_despescasAndamento.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_corPrimaria.withOpacity(0.1), _corPrimaria.withOpacity(0.05)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _corPrimaria.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.summarize, color: _corPrimaria, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Resumo das Despescas',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildResumoItem(
                                  'Total de Despescas',
                                  '${_despescasAndamento.length}',
                                  Icons.list_alt,
                                  Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildResumoItem(
                                  'Peso Total Coletado',
                                  '${_despescasAndamento.fold<double>(0, (sum, d) => sum + (d['peso'] as num)).toStringAsFixed(1)} kg',
                                  Icons.monitor_weight,
                                  Colors.teal,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildResumoItem(
                                  'Finalizadas',
                                  '${_despescasAndamento.where((d) => d['despescaFinalizada'] == true).length}',
                                  Icons.check_circle,
                                  Colors.green,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildResumoItem(
                                  'Em Andamento',
                                  '${_despescasAndamento.where((d) => d['despescaFinalizada'] != true).length}',
                                  Icons.access_time,
                                  Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pesoCtrl.dispose();
    _observacoesCtrl.dispose();
    super.dispose();
  }
}
