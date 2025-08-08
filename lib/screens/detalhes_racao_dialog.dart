import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DetalhesRacaoDialog extends StatelessWidget {
  const DetalhesRacaoDialog({required this.data, super.key});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final dt = (data['timestamp'] as Timestamp).toDate();
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        padding: const EdgeInsets.all(0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFFB2DFDB),
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: const Column(
                children: [
                  Icon(Icons.set_meal, color: Colors.teal, size: 38),
                  SizedBox(height: 6),
                  Text('Detalhes da Ração', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Destino: ${data['viveiro'] ?? data['codigo'] ?? '—'}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('Código: ${data['codigo'] ?? '—'}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  _paramRacao('Quantidade', data['quantidade'], 'kg', icon: Icons.scale_rounded),
                  _paramRacao('Sobras', data['sobras'], 'kg', icon: Icons.recycling_rounded),
                  if (data['probióticoAplicado'] != null)
                    _paramRacao('Probiótico', data['probióticoAplicado'], '', icon: Icons.medical_services_rounded),
                  const SizedBox(height: 14),
                  const Divider(),
                  const SizedBox(height: 6),
                  const Text('Observações:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(data['observacoes'] ?? '—', style: const TextStyle(fontStyle: FontStyle.italic)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: Colors.teal),
                      const SizedBox(width: 4),
                      Text('Data/Hora: ${DateFormat('dd/MM/yyyy HH:mm').format(dt)}'),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 16, color: Colors.teal),
                      const SizedBox(width: 4),
                      Text('Registrado por: ${data['registradoPor'] ?? '—'}'),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fechar', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paramRacao(String label, dynamic valor, String unidade, {IconData? icon}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.teal, size: 18),
            const SizedBox(width: 6),
          ],
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(valor != null ? valor.toString() : '—', style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.w600)),
          if (unidade.isNotEmpty) Text(' $unidade'),
        ],
      ),
    );
  }
}
