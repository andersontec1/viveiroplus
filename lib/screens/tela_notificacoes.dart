import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/degrade_fundo.dart';

class TelaNotificacoes extends StatefulWidget {
  const TelaNotificacoes({super.key});

  @override
  _TelaNotificacoesState createState() => _TelaNotificacoesState();
}

class _TelaNotificacoesState extends State<TelaNotificacoes> {
  late final String _userId;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _userId = user?.uid ?? '';
  }

  Future<void> _marcarComoLida(String id) async {
    await FirebaseFirestore.instance
        .collection('notificacoes')
        .doc(id)
        .update({'lida': true});
  }

  Future<void> _marcarTodasComoLidas() async {
    final batch = FirebaseFirestore.instance.batch();
    final snapshot = await FirebaseFirestore.instance
        .collection('notificacoes')
        .where('userId', isEqualTo: _userId)
        .where('lida', isEqualTo: false)
        .get();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'lida': true});
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('notificacoes')
        .where('userId', isEqualTo: _userId)
        .orderBy('timestamp', descending: true);

    return DegradeFundo(
      child: AppScaffold(
        title: 'Notificações',
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _marcarTodasComoLidas,
                    child: Text('Marcar todas como lidas', style: Theme.of(context).textTheme.labelLarge),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: query.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Center(child: Text('Nenhuma notificação.', style: Theme.of(context).textTheme.bodyLarge));
                  }
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final doc = docs[i];
                      final data = doc.data() as Map<String, dynamic>;
                      final lida = data['lida'] as bool? ?? false;
                      final mensagem = data['mensagem'] as String? ?? '';
                      final timestamp = (data['timestamp'] as Timestamp).toDate();
                      final tipo = data['tipo'] as String? ?? 'info';

                      IconData icon;
                      switch (tipo) {
                        case 'alerta':
                          icon = Icons.warning;
                          break;
                        case 'pendencia':
                          icon = Icons.schedule;
                          break;
                        default:
                          icon = Icons.info;
                      }

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading: Icon(icon, color: lida ? Colors.grey : Colors.blue),
                          title: Text(mensagem, style: Theme.of(context).textTheme.bodyMedium),
                          subtitle: Text(
                            '${timestamp.toLocal()}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          trailing: lida
                              ? const Icon(Icons.check, color: Colors.green)
                              : TextButton(
                                  onPressed: () => _marcarComoLida(doc.id),
                                  child: Text('Marcar lida', style: Theme.of(context).textTheme.labelLarge),
                                ),
                          onTap: () {
                            if (!lida) _marcarComoLida(doc.id);
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
