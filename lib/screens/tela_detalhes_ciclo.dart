// Tela de Detalhes do Ciclo
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/degrade_fundo.dart';

class TelaDetalhesCiclo extends StatefulWidget {
  final String cicloId;
  final Map<String, dynamic> dadosCiclo;

  const TelaDetalhesCiclo({
    super.key,
    required this.cicloId,
    required this.dadosCiclo,
  });

  @override
  State<TelaDetalhesCiclo> createState() => _TelaDetalhesCicloState();
}

class _TelaDetalhesCicloState extends State<TelaDetalhesCiclo> {
  static const _corPrimariaEscura = Color(0xFF045D3A);
  static const _corPrimaria = Color(0xFF049F56);

  List<Map<String, dynamic>> _povoamentos = [];
  List<Map<String, dynamic>> _transferencias = [];
  List<Map<String, dynamic>> _analises = [];
  List<Map<String, dynamic>> _racoes = [];
  List<Map<String, dynamic>> _viveirosDisponiveis = [];
  bool _carregando = true;
  Map<String, dynamic>? _dadosViveiro;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    try {
      setState(() => _carregando = true);

      // Carregar dados do viveiro/berçário atual
      final viveiroQuery = await FirebaseFirestore.instance
          .collection('viveiros')
          .where('codigo', isEqualTo: widget.dadosCiclo['codigo'])
          .limit(1)
          .get();

      if (viveiroQuery.docs.isEmpty) {
        // Tentar buscar em berçários
        final bercarioQuery = await FirebaseFirestore.instance
            .collection('bercarios')
            .where('codigo', isEqualTo: widget.dadosCiclo['codigo'])
            .limit(1)
            .get();
        
        if (bercarioQuery.docs.isNotEmpty) {
          _dadosViveiro = {'tipo': 'Berçário', ...bercarioQuery.docs.first.data()};
        }
      } else {
        _dadosViveiro = {'tipo': 'Viveiro', ...viveiroQuery.docs.first.data()};
      }

      // Carregar povoamentos
      final povQuery = await FirebaseFirestore.instance
          .collection('povoamentos')
          .where('cicloId', isEqualTo: widget.cicloId)
          .orderBy('dataRegistro', descending: true)
          .get();

      // Carregar transferências
      final transQuery = await FirebaseFirestore.instance
          .collection('transferencias')
          .where('cicloId', isEqualTo: widget.cicloId)
          .orderBy('dataTransferencia', descending: true)
          .get();

      // Carregar análises de água
      final analiseQuery = await FirebaseFirestore.instance
          .collection('registros_diarios')
          .where('codigo', isEqualTo: widget.dadosCiclo['codigo'])
          .orderBy('dataHora', descending: true)
          .limit(20)
          .get();

      // Carregar registros de ração
      final racaoQuery = await FirebaseFirestore.instance
          .collection('racao')
          .where('codigo', isEqualTo: widget.dadosCiclo['codigo'])
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();

      // Carregar viveiros disponíveis para transferência
      final viveirosQuery = await FirebaseFirestore.instance
          .collection('viveiros')
          .where('tipo', isEqualTo: 'viveiro')
          .where('status', isEqualTo: 'ativo')
          .orderBy('codigo')
          .get();

      setState(() {
        _povoamentos = povQuery.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();
        _transferencias = transQuery.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();
        _analises = analiseQuery.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();
        _racoes = racaoQuery.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();
        _viveirosDisponiveis = viveirosQuery.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();
        _carregando = false;
      });
    } catch (e) {
      print('Erro ao carregar dados: $e');
      setState(() => _carregando = false);
    }
  }

  Future<void> _encerrarCiclo() async {
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
      await FirebaseFirestore.instance.collection('ciclos').doc(widget.cicloId).update({
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
            backgroundColor: _corPrimaria,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pop(context, true); // Retorna true para indicar que houve mudança
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

  Future<void> _mostrarDialogoTransferencia() async {
    if (_viveirosDisponiveis.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning, color: Colors.white),
              SizedBox(width: 8),
              Text('Nenhum viveiro disponível para transferência'),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => _DialogoTransferencia(
        cicloId: widget.cicloId,
        viveirosDisponiveis: _viveirosDisponiveis,
        onTransferencia: _executarTransferencia,
      ),
    );
  }

  Future<void> _executarTransferencia(String viveiroDestinoId, int quantidade, String observacoes) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final now = DateTime.now();
      
      // Criar registro de transferência
      await FirebaseFirestore.instance.collection('transferencias').add({
        'cicloId': widget.cicloId,
        'codigoOrigem': widget.dadosCiclo['codigo'],
        'codigoDestino': viveiroDestinoId,
        'quantidade': quantidade,
        'observacoes': observacoes,
        'dataTransferencia': now,
        'criadoPor': user.uid,
        'status': 'ativa',
      });

      // Buscar nome do viveiro de destino
      final viveiroDestino = _viveirosDisponiveis.firstWhere((v) => v['id'] == viveiroDestinoId);
      final codigoDestino = viveiroDestino['codigo'];
      final nomeDestino = viveiroDestino['nome'] ?? '—';

      // Atualizar o ciclo para o novo viveiro
      await FirebaseFirestore.instance
          .collection('ciclos')
          .doc(widget.cicloId)
          .update({
        'codigo': codigoDestino,
        'nome': nomeDestino,
        'dataUltimaTransferencia': now,
        'updatedAt': now,
        'updatedBy': user.uid,
      });

      // Recarregar dados
      await _carregarDados();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('✅ Transferência realizada com sucesso!'),
              ],
            ),
            backgroundColor: _corPrimaria,
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
                Expanded(child: Text('❌ Erro na transferência: $e')),
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

  String _formatarData(DateTime dt) => DateFormat('dd/MM/yyyy').format(dt);

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
                color: _corPrimariaEscura.withOpacity(0.7),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: _corPrimariaEscura,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    final data = widget.dadosCiclo['dataInicio']?.toDate();
    final encerrado = widget.dadosCiclo['encerrado'] == true;
    final dataEncerramento = widget.dadosCiclo['dataEncerramento']?.toDate();
    final previsaoEncerramento = widget.dadosCiclo['previsaoEncerramento']?.toDate();
    final abertoPor = widget.dadosCiclo['abertoPor'] ?? '—';
    final fechadoPor = widget.dadosCiclo['fechadoPor'] ?? '';
    final pesoFinal = widget.dadosCiclo['pesoFinal'];
    final pesoInicial = (widget.dadosCiclo['pesoInicial'] ?? 0) as num;

    // Cálculo duração
    int duracaoDias; 
    if (encerrado && dataEncerramento != null) {
      duracaoDias = dataEncerramento.difference(data!).inDays;
    } else {
      duracaoDias = DateTime.now().difference(data!).inDays;
    }

    final ganhoPeso = (encerrado && pesoFinal != null && pesoInicial > 0)
        ? (pesoFinal - pesoInicial)
        : null;

    return Container(
      padding: const EdgeInsets.all(20),
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
                          colors: [_corPrimariaEscura, _corPrimaria],
                        ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  encerrado ? Icons.lock : Icons.autorenew,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.dadosCiclo['nome']}',
                      style: const TextStyle(
                        color: _corPrimariaEscura,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Código: ${widget.dadosCiclo['codigo']}',
                      style: TextStyle(
                        color: _corPrimariaEscura.withOpacity(0.7),
                        fontSize: 16,
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
                      : _corPrimaria.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: encerrado ? Colors.grey : _corPrimaria,
                  ),
                ),
                child: Text(
                  encerrado ? '🔒 Encerrado' : '🔄 Ativo',
                  style: TextStyle(
                    color: encerrado ? Colors.grey[600] : _corPrimaria,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Informações principais
          _buildInfoRow('📅 Início', _formatarData(data!)),
          if (previsaoEncerramento != null)
            _buildInfoRow('🎯 Previsão', _formatarData(previsaoEncerramento)),
          if (encerrado && dataEncerramento != null)
            _buildInfoRow('🏁 Encerrado', _formatarData(dataEncerramento)),
          _buildInfoRow('🦐 Estocados', '${widget.dadosCiclo['quantidadeEstocada']} pós-larvas'),
          if (widget.dadosCiclo['pesoInicial'] != null && widget.dadosCiclo['pesoInicial'] > 0)
            _buildInfoRow('⚖️ Peso Inicial', '${widget.dadosCiclo['pesoInicial'].toString().replaceAll('.', ',')} g'),
          if (encerrado && pesoFinal != null)
            _buildInfoRow('🎯 Peso Final', '${pesoFinal.toString().replaceAll('.', ',')} g'),
          _buildInfoRow('⏱️ Duração', '$duracaoDias dias'),
          if (ganhoPeso != null)
            _buildInfoRow('📈 Ganho Médio', '${ganhoPeso.toString().replaceAll('.', ',')} g'),
          
          // Informação do tipo (berçário/viveiro)
          if (_dadosViveiro != null)
            _buildInfoRow(
              _dadosViveiro!['tipo'] == 'Berçário' ? '🏠 Local' : '🏊 Local', 
              '${_dadosViveiro!['tipo']}: ${widget.dadosCiclo['codigo']}'
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
            
            // Botão de transferência para berçário
            if (_dadosViveiro != null && _dadosViveiro!['tipo'] == 'Berçário') ...[
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_corPrimaria.withOpacity(0.8), _corPrimaria.withOpacity(0.6)],
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: _corPrimaria.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.swap_horiz, color: Colors.white),
                    label: const Text(
                      'Transferir para Viveiro',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    onPressed: _mostrarDialogoTransferencia,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Botão de encerrar
            Center(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red.withOpacity(0.8), Colors.red.withOpacity(0.6)],
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.lock, color: Colors.white),
                  label: const Text(
                    'Encerrar Ciclo',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  onPressed: _encerrarCiclo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabContent(String tipo) {
    if (_carregando) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    switch (tipo) {
      case 'povoamentos':
        // Combinear povoamentos e transferências em uma timeline
        List<Map<String, dynamic>> eventosTimeline = [];
        
        // Adicionar povoamentos
        for (var pov in _povoamentos) {
          eventosTimeline.add({
            'tipo': 'povoamento',
            'data': pov['dataRegistro']?.toDate() ?? DateTime.now(),
            'dados': pov,
          });
        }
        
        // Adicionar transferências
        for (var transf in _transferencias) {
          eventosTimeline.add({
            'tipo': 'transferencia',
            'data': transf['dataTransferencia']?.toDate() ?? DateTime.now(),
            'dados': transf,
          });
        }
        
        // Ordenar por data (mais recente primeiro)
        eventosTimeline.sort((a, b) => b['data'].compareTo(a['data']));
        
        if (eventosTimeline.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Nenhum evento registrado',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
          );
        }
        
        return ListView.builder(
          itemCount: eventosTimeline.length,
          itemBuilder: (context, index) {
            final evento = eventosTimeline[index];
            final tipo = evento['tipo'];
            final data = evento['data'];
            final dados = evento['dados'];
            
            if (tipo == 'povoamento') {
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _corPrimaria.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add_circle, color: _corPrimaria),
                  ),
                  title: Text('Povoamento: ${dados['quantidade']} pós-larvas'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Por: ${dados['responsavel'] ?? '—'}'),
                      Text(DateFormat('dd/MM/yyyy HH:mm').format(data)),
                      if (dados['observacoes'] != null && dados['observacoes'].toString().isNotEmpty)
                        Text('Obs: ${dados['observacoes']}', style: const TextStyle(fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
              );
            } else {
              // Transferência
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.swap_horiz, color: Colors.orange),
                  ),
                  title: Text('Transferência: ${dados['quantidade']} unidades'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('De: ${dados['codigoOrigem']} → Para: ${dados['codigoDestino']}'),
                      Text(DateFormat('dd/MM/yyyy HH:mm').format(data)),
                      if (dados['observacoes'] != null && dados['observacoes'].toString().isNotEmpty)
                        Text('Obs: ${dados['observacoes']}', style: const TextStyle(fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
              );
            }
          },
        );

      case 'analises':
        if (_analises.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Nenhuma análise registrada',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
          );
        }
        return ListView.builder(
          itemCount: _analises.length,
          itemBuilder: (context, index) {
            final analise = _analises[index];
            final data = analise['dataHora']?.toDate() ?? DateTime.now();
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.analytics, color: Colors.blue),
                ),
                title: Text(DateFormat('dd/MM/yyyy HH:mm').format(data)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (analise['ph'] != null) Text('pH: ${analise['ph']}'),
                    if (analise['temperatura'] != null) Text('Temp: ${analise['temperatura']}°C'),
                    if (analise['oxigenio'] != null) Text('O₂: ${analise['oxigenio']} mg/L'),
                    Text('Por: ${analise['registradoPor'] ?? '—'}'),
                  ],
                ),
              ),
            );
          },
        );

      case 'racao':
        if (_racoes.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Nenhum registro de ração',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
          );
        }
        return ListView.builder(
          itemCount: _racoes.length,
          itemBuilder: (context, index) {
            final racao = _racoes[index];
            final data = racao['timestamp']?.toDate() ?? DateTime.now();
            final quantidade = racao['quantidade'] ?? 0;
            final sobras = racao['sobras'] ?? 0;
            final consumo = quantidade - sobras;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.restaurant, color: Colors.orange),
                ),
                title: Text('${quantidade}g fornecido'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sobras: ${sobras}g | Consumo: ${consumo}g'),
                    Text(DateFormat('dd/MM/yyyy HH:mm').format(data)),
                    Text('Por: ${racao['registradoPor'] ?? '—'}'),
                  ],
                ),
              ),
            );
          },
        );

      default:
        return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Detalhes do Ciclo',
      body: DegradeFundo(
        child: DefaultTabController(
          length: 4,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: _buildInfoCard(),
              ),
              Container(
                color: Colors.white,
                child: const TabBar(
                  labelColor: _corPrimariaEscura,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: _corPrimaria,
                  tabs: [
                    Tab(text: 'Geral', icon: Icon(Icons.info_outline)),
                    Tab(text: 'Timeline', icon: Icon(Icons.timeline_outlined)),
                    Tab(text: 'Análises', icon: Icon(Icons.analytics_outlined)),
                    Tab(text: 'Ração', icon: Icon(Icons.restaurant_outlined)),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  color: Colors.white,
                  child: TabBarView(
                    children: [
                      // Tab Geral - vazia por agora, o conteúdo já está no card acima
                      const Center(
                        child: Text(
                          'Informações gerais exibidas acima',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ),
                      _buildTabContent('povoamentos'),
                      _buildTabContent('analises'),
                      _buildTabContent('racao'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogoTransferencia extends StatefulWidget {
  final String cicloId;
  final List<Map<String, dynamic>> viveirosDisponiveis;
  final Function(String, int, String) onTransferencia;

  const _DialogoTransferencia({
    required this.cicloId,
    required this.viveirosDisponiveis,
    required this.onTransferencia,
  });

  @override
  State<_DialogoTransferencia> createState() => _DialogoTransferenciaState();
}

class _DialogoTransferenciaState extends State<_DialogoTransferencia> {
  final _formKey = GlobalKey<FormState>();
  final _quantidadeController = TextEditingController();
  final _observacoesController = TextEditingController();
  String? _viveiroSelecionado;

  @override
  void dispose() {
    _quantidadeController.dispose();
    _observacoesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Transferir para Viveiro'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _viveiroSelecionado,
              decoration: const InputDecoration(
                labelText: 'Viveiro de Destino',
                border: OutlineInputBorder(),
              ),
              items: widget.viveirosDisponiveis.map((viveiro) {
                return DropdownMenuItem<String>(
                  value: viveiro['id'],
                  child: Text('${viveiro['codigo']} - ${viveiro['nome'] ?? 'Sem nome'}'),
                );
              }).toList(),
              onChanged: (value) => setState(() => _viveiroSelecionado = value),
              validator: (value) => value == null ? 'Selecione um viveiro' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _quantidadeController,
              decoration: const InputDecoration(
                labelText: 'Quantidade a Transferir',
                border: OutlineInputBorder(),
                suffixText: 'unidades',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Informe a quantidade';
                }
                final quantidade = int.tryParse(value);
                if (quantidade == null || quantidade <= 0) {
                  return 'Quantidade deve ser maior que zero';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _observacoesController,
              decoration: const InputDecoration(
                labelText: 'Observações (opcional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final quantidade = int.parse(_quantidadeController.text);
              final observacoes = _observacoesController.text.trim();
              
              Navigator.pop(context);
              widget.onTransferencia(_viveiroSelecionado!, quantidade, observacoes);
            }
          },
          child: const Text('Transferir'),
        ),
      ],
    );
  }
}
