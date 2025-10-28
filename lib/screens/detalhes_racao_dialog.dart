import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class DetalhesRacaoDialog extends StatefulWidget {
  const DetalhesRacaoDialog({
    Key? key,
    required this.dados,
    required this.docId,
    this.podeExcluir = false,
    this.onExcluir,
  }) : super(key: key);

  final Map<String, dynamic> dados;
  final String docId;
  final bool podeExcluir;
  // Callback assíncrono para exclusão; o diálogo será fechado após concluir
  final Future<void> Function()? onExcluir;

  @override
  State<DetalhesRacaoDialog> createState() => _DetalhesRacaoDialogState();
}

class _DetalhesRacaoDialogState extends State<DetalhesRacaoDialog> {
  bool _excluindo = false;

  // Função helper para obter o nome do destino com compatibilidade
  String _obterNomeDestino() {
    if (widget.dados['destinoNome'] != null &&
        widget.dados['destinoNome'].toString().isNotEmpty) {
      return widget.dados['destinoNome'];
    }
    return widget.dados['viveiro'] ?? 'Sem destino';
  }

  bool _obterStatusProbiotico() {
    if (widget.dados.containsKey('probioticoAplicado')) {
      return widget.dados['probioticoAplicado'] == true;
    }
    if (widget.dados.containsKey('probióticoAplicado')) {
      return widget.dados['probióticoAplicado'] == true;
    }
    return false;
  }

  bool _obterStatusSuplemento() {
    return widget.dados['suplementoAplicado'] == true;
  }

  @override
  Widget build(BuildContext context) {
    final timestamp = widget.dados['dataRegistro'] as Timestamp?;
    final dataRegistro = timestamp?.toDate() ?? DateTime.now();

    final destino = _obterNomeDestino();
    final temProbiotico = _obterStatusProbiotico();
    final temSuplemento = _obterStatusSuplemento();

    final String? insumoNome =
        (widget.dados['insumoNome'] as String?) ??
        (widget.dados['insumoId'] as String?);
    final List<dynamic> lotesUsados = (widget.dados['lotesUsados'] is List)
        ? (widget.dados['lotesUsados'] as List)
        : const [];
    final String? loteSelecionado = (widget.dados['loteSelecionado'] as String?)
        ?.trim();
    final bool ehLegado =
        ((widget.dados['insumoId'] == null ||
            (widget.dados['insumoId'] is String &&
                (widget.dados['insumoId'] as String).trim().isEmpty)) &&
        lotesUsados.isEmpty &&
        (loteSelecionado == null || loteSelecionado.isEmpty));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        padding: const EdgeInsets.all(0),
        constraints: const BoxConstraints(maxHeight: 640, maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cabeçalho estilo Análise de Água
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
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
                    if (ehLegado)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Registro legado sem vínculo de insumo/lote. Para reaplicar FEFO em edições, vincule um insumo ou execute o backfill.',
                                style: TextStyle(color: Colors.amber.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Data/hora
                    _infoContainer(
                      icon: Icons.calendar_today,
                      color: Colors.green,
                      child: Text(
                        'Data: ${DateFormat('dd/MM/yyyy HH:mm').format(dataRegistro)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    // Destino
                    _infoRowChip(
                      icon: Icons.place,
                      color: Colors.teal,
                      label: 'Destino',
                      value: destino,
                    ),
                    // Quantidade
                    _metricContainer(
                      icon: Icons.restaurant,
                      color: Colors.green,
                      label: 'Quantidade fornecida',
                      value: '${widget.dados['quantidade'] ?? 0} kg',
                    ),
                    if (widget.dados['trato'] != null)
                      _infoRowChip(
                        icon: Icons.fastfood,
                        color: Colors.indigo,
                        label: 'Trato',
                        value: '${widget.dados['trato']}º Trato',
                      )
                    else if (widget.dados['horario'] != null &&
                        widget.dados['horario'].toString().isNotEmpty)
                      _infoRowChip(
                        icon: Icons.schedule,
                        color: Colors.indigo,
                        label: 'Horário',
                        value: widget.dados['horario'],
                      ),
                    if (widget.dados['registradoPor'] != null &&
                        widget.dados['registradoPor'].toString().isNotEmpty)
                      _infoRowChip(
                        icon: Icons.person,
                        color: Colors.blueGrey,
                        label: 'Responsável',
                        value: widget.dados['registradoPor'],
                      ),
                    if (widget.dados['diaCiclo'] != null)
                      _infoRowChip(
                        icon: Icons.today,
                        color: Colors.teal,
                        label: 'Dia do ciclo',
                        value: 'Dia ${widget.dados['diaCiclo']}',
                      ),
                    if (widget.dados['totalAcumulado'] != null)
                      _metricContainer(
                        icon: Icons.summarize,
                        color: Colors.teal,
                        label: 'Total até o momento',
                        value:
                            '${(widget.dados['totalAcumulado'] as num).toDouble().toStringAsFixed(2)} kg',
                      ),
                    if (insumoNome != null)
                      _infoRowChip(
                        icon: Icons.inventory_2,
                        color: Colors.brown,
                        label: 'Insumo',
                        value: insumoNome,
                      ),
                    if (lotesUsados.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Lotes usados:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          ...lotesUsados.take(6).map((lu) {
                            final m = (lu is Map) ? lu : <String, dynamic>{};
                            final codigo =
                                (m['lote'] ??
                                        m['codigo'] ??
                                        m['loteCodigo'] ??
                                        '')
                                    .toString();
                            final qtd = (m['quantidade'] ?? m['qtd'] ?? 0)
                                .toString();
                            final label = codigo.isNotEmpty
                                ? '$codigo ($qtd kg)'
                                : '$qtd kg';
                            return Chip(
                              label: Text(
                                label,
                                style: const TextStyle(fontSize: 12),
                              ),
                              visualDensity: VisualDensity.compact,
                            );
                          }),
                          if (lotesUsados.length > 6)
                            Chip(
                              label: Text(
                                '+${lotesUsados.length - 6}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                    ],
                    if (temProbiotico || temSuplemento) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Aditivos aplicados:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (temProbiotico)
                            Chip(
                              label: const Text('Probiótico'),
                              backgroundColor: Colors.green,
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                          if (temSuplemento)
                            Chip(
                              label: const Text('Suplemento'),
                              backgroundColor: Colors.orange,
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                    ],
                    if (widget.dados['observacoes'] != null &&
                        widget.dados['observacoes'].toString().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _noteContainer(
                        icon: Icons.note,
                        color: Colors.amber,
                        title: 'Observações:',
                        text: widget.dados['observacoes'].toString(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: _excluindo ? null : () => Navigator.pop(context),
                    child: const Text('Fechar'),
                  ),
                  if (widget.podeExcluir)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: _excluindo
                          ? null
                          : () async {
                              if (widget.onExcluir == null) return;
                              setState(() => _excluindo = true);
                              try {
                                await widget.onExcluir!.call();
                                if (mounted) {
                                  Navigator.of(context).pop('deleted');
                                }
                              } catch (_) {
                                if (mounted) setState(() => _excluindo = false);
                              }
                            },
                      icon: const Icon(
                        Icons.delete,
                        color: Colors.white,
                        size: 18,
                      ),
                      label: _excluindo
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Excluindo…',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ],
                            )
                          : const Text(
                              'Excluir',
                              style: TextStyle(color: Colors.white),
                            ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // _buildInfoRow removido após padronização visual

  Widget _infoContainer({
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          child,
        ],
      ),
    );
  }

  Widget _metricContainer({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(
            value,
            style: TextStyle(
              color: Colors.green.shade900,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _noteContainer({
    required IconData icon,
    required Color color,
    required String title,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Text(text),
        ],
      ),
    );
  }

  Widget _infoRowChip({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
