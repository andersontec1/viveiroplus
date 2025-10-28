import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/degrade_fundo.dart';
import '../helpers/confirmation_helper.dart';
import '../helpers/audit_helper.dart';
import '../helpers/security_helper.dart';
import '../widgets/racao_meta_chips.dart';

class TelaDetalhesBercario extends StatefulWidget {
  const TelaDetalhesBercario({
    this.docId,
    required this.codigo,
    required this.nome,
    required this.dadosBercario,
    super.key,
  });

  final String? docId;
  final String codigo;
  final String nome;
  final Map<String, dynamic> dadosBercario;

  @override
  State<TelaDetalhesBercario> createState() => _TelaDetalhesBercarioState();
}

class _TelaDetalhesBercarioState extends State<TelaDetalhesBercario>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _podeExcluir = false;

  // Verifica dependências antes da exclusão (berçário)
  Future<String?> _validarExclusaoBercario(String codigo) async {
    try {
      final ciclosAtivos = await FirebaseFirestore.instance
          .collection('ciclos')
          .where('codigo', isEqualTo: codigo)
          .where('encerrado', isEqualTo: false)
          .limit(1)
          .get();
      if (ciclosAtivos.docs.isNotEmpty) {
        return 'Existe um ciclo ativo para este berçário. Encerre o ciclo antes de excluir.';
      }
      final racao = await FirebaseFirestore.instance
          .collection('racao')
          .where('tipoDestino', isEqualTo: 'bercario')
          .where('codigoDestino', isEqualTo: codigo)
          .limit(1)
          .get();
      final analises = await FirebaseFirestore.instance
          .collection('registros_diarios')
          .where('tipoDestino', isEqualTo: 'bercario')
          .where('codigo', isEqualTo: codigo)
          .limit(1)
          .get();
      final despescas = await FirebaseFirestore.instance
          .collection('despescas')
          .where('codigo', isEqualTo: codigo)
          .limit(1)
          .get();
      if (racao.docs.isNotEmpty ||
          analises.docs.isNotEmpty ||
          despescas.docs.isNotEmpty) {
        return 'Existem registros relacionados (Ração, Análises ou Despesca). Por integridade, exclua-os ou arquive o berçário.';
      }
    } catch (e) {
      return 'Não foi possível verificar dependências: ${e.toString()}';
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _carregarPermissao();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _carregarPermissao() async {
    try {
      final adm = await SecurityHelper.temFuncaoAdministrativa();
      if (mounted) setState(() => _podeExcluir = adm);
    } catch (_) {}
  }

  Widget _buildInfoCard() {
    final area = widget.dadosBercario['area'] ?? '—';
    final volume = widget.dadosBercario['volume'] ?? '—';
    final ts = (widget.dadosBercario['criadoEm'] as Timestamp?)?.toDate();
    final criadoStr = ts != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(ts)
        : 'Data desconhecida';

    Widget infoDetalhe(String label, String valor, {IconData? icon}) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.green, size: 20),
              const SizedBox(width: 8),
            ],
            Text(
              '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              valor,
              style: TextStyle(
                color: Colors.green.shade900,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.spa, color: Colors.green, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.nome,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Código: ${widget.codigo}',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                if (_podeExcluir)
                  IconButton(
                    tooltip: 'Excluir',
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                    onPressed: _excluirBercario,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            infoDetalhe('Área', '$area m²', icon: Icons.square_foot),
            infoDetalhe('Volume', '$volume m³', icon: Icons.water_drop),
            infoDetalhe('Tipo', 'Berçário', icon: Icons.spa),
            infoDetalhe('Criado em', criadoStr, icon: Icons.calendar_today),
          ],
        ),
      ),
    );
  }

  Future<void> _excluirBercario() async {
    if (widget.docId == null || widget.docId!.isEmpty) {
      await ConfirmationHelper.showError(
        context: context,
        content: 'ID do documento não disponível para exclusão.',
      );
      return;
    }

    final motivo = await _validarExclusaoBercario(widget.codigo);
    if (motivo != null) {
      await ConfirmationHelper.showError(
        context: context,
        title: 'Exclusão bloqueada',
        content: motivo,
      );
      return;
    }

    final confirmou = await ConfirmationHelper.showDoubleConfirmation(
      context: context,
      title: 'Excluir Berçário',
      content:
          'Tem certeza que deseja excluir "${widget.nome}" (cód: ${widget.codigo})?',
      secondTitle: 'Confirma exclusão?',
      secondContent: 'Esta ação é irreversível. Deseja realmente excluir?',
      actionLabel: 'Excluir',
      actionColor: Colors.red,
    );
    if (confirmou != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('bercarios')
          .doc(widget.docId)
          .delete();
      await AuditHelper.registrarAcao(
        acao: 'BERCARIO_EXCLUIDO',
        modulo: 'BERCARIOS',
        detalhes: {
          'docId': widget.docId,
          'codigo': widget.codigo,
          'nome': widget.nome,
        },
      );
      if (mounted) {
        await ConfirmationHelper.showSuccess(
          context: context,
          title: 'Berçário excluído',
          content: 'O berçário foi removido com sucesso.',
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        await ConfirmationHelper.showError(
          context: context,
          content: 'Não foi possível excluir o berçário.',
          error: e.toString(),
        );
      }
    }
  }

  Widget _buildRegistrosAnalise() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('registros_diarios')
          .where('codigo', isEqualTo: widget.codigo)
          .where('tipoDestino', isEqualTo: 'bercario')
          .orderBy('dataHora', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Nenhum registro de análise encontrado',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final dataHora = (data['dataHora'] as Timestamp).toDate();
            final registradoPor = data['registradoPor'] ?? '—';

            // Gerar abreviações dos parâmetros registrados
            List<String> parametrosRegistrados = [];

            if (data['ph'] != null && data['ph'].toString().isNotEmpty) {
              parametrosRegistrados.add('pH: ${data['ph']}');
            }
            if (data['oxigenio'] != null &&
                data['oxigenio'].toString().isNotEmpty) {
              parametrosRegistrados.add('O₂: ${data['oxigenio']}mg/L');
            }
            if (data['temperatura'] != null &&
                data['temperatura'].toString().isNotEmpty) {
              parametrosRegistrados.add('T°: ${data['temperatura']}°C');
            }
            if (data['salinidade'] != null &&
                data['salinidade'].toString().isNotEmpty) {
              parametrosRegistrados.add('Sal: ${data['salinidade']}ppt');
            }
            if (data['turbidez'] != null &&
                data['turbidez'].toString().isNotEmpty) {
              parametrosRegistrados.add('Turb: ${data['turbidez']}NTU');
            }
            if (data['nitrito'] != null &&
                data['nitrito'].toString().isNotEmpty) {
              parametrosRegistrados.add('NO₂: ${data['nitrito']}mg/L');
            }
            if (data['amonia'] != null &&
                data['amonia'].toString().isNotEmpty) {
              parametrosRegistrados.add('NH₃: ${data['amonia']}mg/L');
            }
            if (data['nitrato'] != null &&
                data['nitrato'].toString().isNotEmpty) {
              parametrosRegistrados.add('NO₃: ${data['nitrato']}mg/L');
            }
            if (data['alkalinidade'] != null &&
                data['alkalinidade'].toString().isNotEmpty) {
              parametrosRegistrados.add('Alc: ${data['alkalinidade']}mg/L');
            }
            if (data['dureza'] != null &&
                data['dureza'].toString().isNotEmpty) {
              parametrosRegistrados.add('Dur: ${data['dureza']}mg/L');
            }

            // Verificar se há parâmetros fora do ideal
            int parametrosForaIdeal = 0;
            for (var param in [
              'ph',
              'oxigenio',
              'temperatura',
              'salinidade',
              'turbidez',
              'nitrito',
              'amonia',
              'nitrato',
              'alkalinidade',
              'dureza',
            ]) {
              if (_foraDoIdeal(param, data[param])) {
                parametrosForaIdeal++;
              }
            }

            return Card(
              elevation: 4,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: parametrosForaIdeal > 0
                    ? const BorderSide(color: Colors.orange, width: 2)
                    : BorderSide.none,
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _mostrarDetalhesAnalise(data),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.water_drop,
                            color: parametrosForaIdeal > 0
                                ? Colors.orange
                                : Colors.green,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Análise de Água',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  DateFormat(
                                    'dd/MM/yyyy HH:mm',
                                  ).format(dataHora),
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  'Por: $registradoPor',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (parametrosForaIdeal > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$parametrosForaIdeal ⚠️',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (parametrosRegistrados.isNotEmpty) ...[
                        const Text(
                          'Parâmetros registrados:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: parametrosRegistrados.take(6).map((
                            parametro,
                          ) {
                            final parts = parametro.split(': ');
                            final nome = parts[0];

                            // Verificar se este parâmetro específico está fora do ideal
                            String campo = '';
                            switch (nome) {
                              case 'pH':
                                campo = 'ph';
                                break;
                              case 'O₂':
                                campo = 'oxigenio';
                                break;
                              case 'T°':
                                campo = 'temperatura';
                                break;
                              case 'Sal':
                                campo = 'salinidade';
                                break;
                              case 'Turb':
                                campo = 'turbidez';
                                break;
                              case 'NO₂':
                                campo = 'nitrito';
                                break;
                              case 'NH₃':
                                campo = 'amonia';
                                break;
                              case 'NO₃':
                                campo = 'nitrato';
                                break;
                              case 'Alc':
                                campo = 'alkalinidade';
                                break;
                              case 'Dur':
                                campo = 'dureza';
                                break;
                            }

                            final foraIdeal = _foraDoIdeal(campo, data[campo]);

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: foraIdeal
                                    ? Colors.orange.shade100
                                    : Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: foraIdeal
                                      ? Colors.orange
                                      : Colors.green.shade200,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                parametro,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: foraIdeal
                                      ? Colors.orange.shade800
                                      : Colors.green.shade800,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        if (parametrosRegistrados.length > 6)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '+${parametrosRegistrados.length - 6} parâmetros...',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ] else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Nenhum parâmetro registrado',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  bool _foraDoIdeal(String parametro, dynamic valor) {
    if (valor == null) return false;

    try {
      final double val = double.parse(valor.toString());
      switch (parametro) {
        case 'ph':
          return val < 6.5 || val > 8.5;
        case 'oxigenio':
          return val < 5.0 || val > 8.0;
        case 'temperatura':
          return val < 26.0 || val > 30.0;
        case 'salinidade':
          return val < 15.0 || val > 25.0;
        case 'amonia':
          return val < 0.0 || val > 0.1;
        case 'nitrito':
          return val < 0.0 || val > 0.5;
        case 'nitrato':
          return val < 0.0 || val > 40.0;
        case 'turbidez':
          return val < 0.0 || val > 5.0;
        case 'alkalinidade':
          return val < 80.0 || val > 120.0;
        case 'dureza':
          return val < 150.0 || val > 300.0;
        default:
          return false;
      }
    } catch (_) {
      return false;
    }
  }

  Widget _buildRegistrosRacao() {
    // Preferir novos campos (codigoDestino/dataRegistro) com fallback para legado
    Query base = FirebaseFirestore.instance.collection('racao');
    Stream<QuerySnapshot> stream;
    try {
      stream = base
          .where('tipoDestino', isEqualTo: 'bercario')
          .where('codigoDestino', isEqualTo: widget.codigo)
          .orderBy('dataRegistro', descending: true)
          .limit(20)
          .snapshots();
    } catch (_) {
      stream = base
          .where('tipoDestino', isEqualTo: 'bercario')
          .where('codigo', isEqualTo: widget.codigo)
          .orderBy('timestamp', descending: true)
          .limit(20)
          .snapshots();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Nenhum registro de ração encontrado',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final ts =
                (data['dataRegistro'] as Timestamp?) ??
                (data['timestamp'] as Timestamp?);
            final timestamp = ts?.toDate() ?? DateTime.now();
            final quantidade = data['quantidade'] ?? 0;
            final sobras = data['sobras'] ?? 0;
            final registradoPor = data['registradoPor'] ?? '—';
            final int? trato = data['trato'] is num
                ? (data['trato'] as num).toInt()
                : null;
            final int? diaCiclo = data['diaCiclo'] is num
                ? (data['diaCiclo'] as num).toInt()
                : null;
            final double? totalAcumulado = data['totalAcumulado'] is num
                ? (data['totalAcumulado'] as num).toDouble()
                : null;

            // Calcular a ração efetivamente consumida
            final consumo = quantidade - sobras;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
              child: ListTile(
                onTap: () => _mostrarDetalhesRacao(data),
                leading: const Icon(Icons.set_meal, color: Colors.green),
                title: Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(timestamp),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (trato != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          'Trato: ${trato}º',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    Text('Fornecido: ${quantidade}kg | Consumo: ${consumo}kg'),
                    if (sobras > 0)
                      Text(
                        'Sobras: ${sobras}kg',
                        style: TextStyle(color: Colors.orange[700]),
                      ),
                    Text(
                      'Por: $registradoPor',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    if (diaCiclo != null || totalAcumulado != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: RacaoMetaChips(
                          trato: null,
                          diaCiclo: diaCiclo,
                          totalAcumulado: totalAcumulado,
                          baseSwatch: Colors.green,
                        ),
                      ),
                  ],
                ),
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_forward_ios, size: 16),
                    if (sobras > quantidade * 0.2) // Se sobras > 20%
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        child: const Icon(
                          Icons.warning,
                          color: Colors.orange,
                          size: 14,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _mostrarDetalhesAnalise(Map<String, dynamic> data) {
    final dt = (data['dataHora'] as Timestamp).toDate();

    Widget paramDetalhe(
      String label,
      String campo,
      String unidade, {
      String? ideal,
    }) {
      final valor = data[campo];
      final fora = _foraDoIdeal(campo, valor);
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: fora ? Colors.red.shade50 : Colors.green.shade50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (fora)
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.red,
                size: 18,
              ),
            if (!fora)
              const Icon(Icons.check_circle, color: Colors.green, size: 18),
            const SizedBox(width: 6),
            Text(
              '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              valor != null ? valor.toString() : '—',
              style: TextStyle(
                color: fora ? Colors.red : Colors.green.shade900,
                fontWeight: fora ? FontWeight.bold : FontWeight.w600,
              ),
            ),
            if (unidade.isNotEmpty) Text(' $unidade'),
            if (fora && ideal != null)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  '(Ideal: $ideal)',
                  style: const TextStyle(color: Colors.green, fontSize: 12),
                ),
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
          constraints: const BoxConstraints(maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFC8E6C9),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.analytics, color: Colors.green, size: 28),
                    SizedBox(width: 8),
                    Text(
                      'Análise de Água',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              color: Colors.green,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Data: ${DateFormat('dd/MM/yyyy HH:mm').format(dt)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      paramDetalhe('pH', 'ph', '', ideal: '7.0 - 9.0'),
                      paramDetalhe(
                        'Oxigênio',
                        'oxigenio',
                        'mg/L',
                        ideal: '4.0 - 14.0',
                      ),
                      paramDetalhe(
                        'Temperatura',
                        'temperatura',
                        '°C',
                        ideal: '28 - 32',
                      ),
                      paramDetalhe(
                        'Salinidade',
                        'salinidade',
                        'ppt',
                        ideal: '30 - 45',
                      ),
                      if (data['turbidez'] != null)
                        paramDetalhe(
                          'Turbidez',
                          'turbidez',
                          'NTU',
                          ideal: '40 - 60',
                        ),
                      if (data['saturacao_percentual'] != null)
                        paramDetalhe(
                          'Saturação %',
                          'saturacao_percentual',
                          '%',
                          ideal: '80 - 120',
                        ),
                      if (data['saturacao_oxigenio'] != null)
                        paramDetalhe(
                          'Saturação O₂',
                          'saturacao_oxigenio',
                          '%',
                          ideal: '80 - 120',
                        ),
                      if (data['calcio'] != null)
                        paramDetalhe(
                          'Cálcio',
                          'calcio',
                          'mg/L',
                          ideal: '100 - 300',
                        ),
                      if (data['nitrito'] != null)
                        paramDetalhe(
                          'Nitrito',
                          'nitrito',
                          'mg/L',
                          ideal: '0.0 - 0.5',
                        ),
                      if (data['amonia'] != null)
                        paramDetalhe(
                          'Amônia',
                          'amonia',
                          'mg/L',
                          ideal: '0.0 - 1.5',
                        ),

                      if (data['observacoes'] != null &&
                          data['observacoes'].toString().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.note,
                                    color: Colors.blue,
                                    size: 18,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Observações:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(data['observacoes'].toString()),
                            ],
                          ),
                        ),
                      ],

                      if (editadoPor != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Editado:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                'Por: $editadoPor',
                                style: const TextStyle(fontSize: 12),
                              ),
                              if (editadoEm != null)
                                Text(
                                  'Em: ${DateFormat('dd/MM/yyyy HH:mm').format((editadoEm as Timestamp).toDate())}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fechar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _mostrarDetalhesRacao(Map<String, dynamic> data) {
    final ts =
        (data['dataRegistro'] as Timestamp?) ??
        (data['timestamp'] as Timestamp?);
    final dt = ts?.toDate() ?? DateTime.now();
    final quantidade = data['quantidade'] ?? 0;
    final sobras = data['sobras'] ?? 0;
    final consumo = quantidade - sobras;
    final eficiencia = quantidade > 0
        ? ((consumo / quantidade) * 100).toStringAsFixed(1)
        : '0';
    final int? trato = data['trato'] is num
        ? (data['trato'] as num).toInt()
        : null;
    final int? diaCiclo = data['diaCiclo'] is num
        ? (data['diaCiclo'] as num).toInt()
        : null;
    final double? totalAcumulado = data['totalAcumulado'] is num
        ? (data['totalAcumulado'] as num).toDouble()
        : null;

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Container(
          padding: const EdgeInsets.all(0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFC8E6C9),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.set_meal, color: Colors.green, size: 28),
                    SizedBox(width: 8),
                    Text(
                      'Registro de Ração',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            color: Colors.green,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Data: ${DateFormat('dd/MM/yyyy HH:mm').format(dt)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),

                    if (trato != null ||
                        diaCiclo != null ||
                        totalAcumulado != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: RacaoMetaChips(
                          trato: trato,
                          diaCiclo: diaCiclo,
                          totalAcumulado: totalAcumulado,
                          baseSwatch: Colors.green,
                        ),
                      ),

                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.restaurant,
                            color: Colors.green,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Quantidade fornecida: ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '$quantidade kg',
                            style: TextStyle(
                              color: Colors.green.shade900,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: sobras > 0
                            ? Colors.orange.shade50
                            : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            sobras > 0 ? Icons.warning : Icons.check_circle,
                            color: sobras > 0 ? Colors.orange : Colors.green,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Sobras: ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '$sobras kg',
                            style: TextStyle(
                              color: sobras > 0
                                  ? Colors.orange.shade900
                                  : Colors.green.shade900,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.trending_up,
                            color: Colors.blue,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Consumo efetivo: ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '$consumo kg ($eficiencia%)',
                            style: TextStyle(
                              color: Colors.blue.shade900,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (data['probióticoAplicado'] != null &&
                        data['probióticoAplicado'].toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.science,
                                  color: Colors.purple,
                                  size: 18,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Probiótico aplicado:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(data['probióticoAplicado'].toString()),
                          ],
                        ),
                      ),
                    ],

                    if (data['observacoes'] != null &&
                        data['observacoes'].toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.note, color: Colors.amber, size: 18),
                                SizedBox(width: 6),
                                Text(
                                  'Observações:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(data['observacoes'].toString()),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fechar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: widget.nome,
      body: DegradeFundo(
        child: Column(
          children: [
            _buildInfoCard(),
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.green,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.green,
                tabs: const [
                  Tab(icon: Icon(Icons.analytics), text: 'Análise de Água'),
                  Tab(icon: Icon(Icons.set_meal), text: 'Ração'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildRegistrosAnalise(), _buildRegistrosRacao()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
