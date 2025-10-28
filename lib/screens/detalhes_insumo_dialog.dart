import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DetalhesInsumoDialog extends StatelessWidget {

  const DetalhesInsumoDialog({
    required this.data, super.key,
    this.onEditar,
    this.onExcluir,
    this.podeEditar = false,
  });
  final Map<String, dynamic> data;
  final VoidCallback? onEditar;
  final VoidCallback? onExcluir;
  final bool podeEditar;

  @override
  Widget build(BuildContext context) {
    // Preparar campos
    final unidade = data['unidade'] ?? '—';
    final quantidadeInicial = data['quantidade_inicial']?.toString() ?? '—';
    final estoque = (data['estoque'] ?? data['quantidade_inicial'] ?? 0) as num;
    final fornecedor = data['fornecedor'] ?? '—';
    final lote = data['lote'] ?? '—';
    final validade = data['proxima_validade'] ?? data['validade'];
    DateTime? validadeDate;
    if (validade != null && validade is DateTime) {
      validadeDate = validade;
    } else if (validade != null && validade is Timestamp) {
      validadeDate = validade.toDate();
    }
    final vencido = validadeDate != null && validadeDate.isBefore(DateTime.now());
    final pertoVencer = validadeDate != null && !vencido && validadeDate.difference(DateTime.now()).inDays <= 7;
    final qtdVencidos = (data['qtd_lotes_vencidos'] ?? 0) as int;
    final qtdPerto = (data['qtd_lotes_perto_vencer'] ?? 0) as int;
    final baixo = estoque < 5;
    List<Widget> chips = [];
    if (baixo) {
      chips.add(const Chip(label: Text('Estoque baixo'), backgroundColor: Colors.redAccent, labelStyle: TextStyle(color: Colors.white), visualDensity: VisualDensity.compact));
    }
    if (qtdVencidos > 0) {
      chips.add(Chip(label: Text('$qtdVencidos lote(s) vencido(s)'), backgroundColor: Colors.black54, labelStyle: const TextStyle(color: Colors.white), visualDensity: VisualDensity.compact));
    } else if (qtdPerto > 0 || pertoVencer) {
      chips.add(Chip(label: Text(qtdPerto > 0 ? '$qtdPerto lote(s) perto de vencer' : 'Vence em breve'), backgroundColor: Colors.orange, labelStyle: const TextStyle(color: Colors.white), visualDensity: VisualDensity.compact));
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFDFFBE5), Color(0xFFE0F7FA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Icon(Icons.inventory_2_rounded, size: 48, color: baixo ? Colors.red : Colors.teal)),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  data['nome'] ?? '—',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  data['tipo'] ?? '',
                  style: const TextStyle(fontSize: 15, color: Colors.teal, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              ),
              if (chips.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: chips.map((c) => Padding(padding: const EdgeInsets.only(left: 4), child: c)).toList(),
                  ),
                ),
              const SizedBox(height: 10),
              _infoRow('Categoria', data['categoria'] ?? '—', Icons.category_rounded),
              _infoRow('Observações', data['observacoes'] ?? '—', Icons.notes_rounded),
              _infoRow('Unidade', unidade, Icons.straighten_rounded),
              _infoRow('Qtd. Inicial', quantidadeInicial, Icons.numbers_rounded),
              _infoRow('Estoque Atual', estoque.toString(), Icons.inventory_2_rounded),
              _infoRow('Fornecedor', fornecedor, Icons.local_shipping_rounded),
              _infoRow('Lote', lote, Icons.confirmation_number_rounded),
              _infoRow(
                'Próx. Validade',
                validadeDate == null
                    ? '—'
                    : '${validadeDate.day.toString().padLeft(2, '0')}/${validadeDate.month.toString().padLeft(2, '0')}/${validadeDate.year}',
                Icons.event_rounded,
              ),
              _infoRow('Lotes vencidos', qtdVencidos.toString(), Icons.warning_amber_rounded),
              _infoRow('Lotes perto de vencer', qtdPerto.toString(), Icons.schedule_rounded),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (podeEditar)
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, color: Colors.teal),
                      tooltip: 'Editar',
                      onPressed: onEditar,
                    ),
                  if (podeEditar)
                    IconButton(
                      icon: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                      tooltip: 'Excluir',
                      onPressed: onExcluir,
                    ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Fechar',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.teal, size: 20),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
