import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/degrade_fundo.dart';
import 'tela_despesca.dart';

class TelaSelecaoViveiroDespesca extends StatefulWidget {
  const TelaSelecaoViveiroDespesca({super.key});

  @override
  State<TelaSelecaoViveiroDespesca> createState() =>
      _TelaSelecaoViveiroDespescaState();
}

class _TelaSelecaoViveiroDespescaState
    extends State<TelaSelecaoViveiroDespesca> {
  Map<String, Map<String, dynamic>> _viveirosComCiclo = {};
  Map<String, Map<String, dynamic>> _despescasAtivas = {};
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() => _carregando = true);

    try {
      await Future.wait([
        _carregarViveirosComCicloAtivo(),
        _carregarDespescasAtivas(),
      ]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar dados: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() => _carregando = false);
  }

  Future<void> _carregarViveirosComCicloAtivo() async {
    final viveirosSnap = await FirebaseFirestore.instance
        .collection('viveiros')
        .orderBy('codigo')
        .get();

    final viveirosTemp = <String, Map<String, dynamic>>{};

    for (final viveiroDoc in viveirosSnap.docs) {
      final viveiroData = viveiroDoc.data();
      final codigo = viveiroData['codigo'];

      // Verificar se tem ciclo ativo
      final cicloSnap = await FirebaseFirestore.instance
          .collection('ciclos')
          .where('codigo', isEqualTo: codigo)
          .where('encerrado', isEqualTo: false)
          .limit(1)
          .get();

      if (cicloSnap.docs.isNotEmpty) {
        viveirosTemp[codigo] = {
          'nome': viveiroData['nome'],
          'area': viveiroData['area'],
          'ciclo': cicloSnap.docs.first.data(),
          'cicloId': cicloSnap.docs.first.id,
        };
      }
    }

    setState(() => _viveirosComCiclo = viveirosTemp);
  }

  Future<void> _carregarDespescasAtivas() async {
    final despescasSnap = await FirebaseFirestore.instance
        .collection('despescas')
        .where('statusDespesca', whereIn: ['planejada', 'em_andamento'])
        .get();

    final despescasTemp = <String, Map<String, dynamic>>{};

    for (final doc in despescasSnap.docs) {
      final data = doc.data();
      final codigo = data['codigo'];
      despescasTemp[codigo] = {...data, 'id': doc.id};
    }

    setState(() => _despescasAtivas = despescasTemp);
  }

  Future<void> _iniciarNovaDespesca(String codigoViveiro) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuário não autenticado');

      final viveiro = _viveirosComCiclo[codigoViveiro]!;

      // Criar nova despesca no Firebase
      final despescaDoc = await FirebaseFirestore.instance
          .collection('despescas')
          .add({
            'codigo': codigoViveiro,
            'nome': viveiro['nome'],
            'cicloId': viveiro['cicloId'],
            'statusDespesca': 'planejada',
            'dataCriacao': Timestamp.now(),
            'dataInicio': null,
            'dataFim': null,
            'dias': [], // Array para armazenar dados de cada dia
            'pesoTotal': 0.0,
            'basquetasTotal': 0,
            'criadoPor': user.displayName ?? user.email ?? 'Usuário',
            'criadoEm': Timestamp.now(),
          });

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TelaDespesca(
              despescaId: despescaDoc.id,
              codigoViveiro: codigoViveiro,
              nomeViveiro: viveiro['nome'],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao iniciar despesca: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _continuarDespesca(
    String codigoViveiro,
    String despescaId,
  ) async {
    final viveiro = _viveirosComCiclo[codigoViveiro]!;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TelaDespesca(
          despescaId: despescaId,
          codigoViveiro: codigoViveiro,
          nomeViveiro: viveiro['nome'],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: AppScaffold(
        title: 'Selecionar Viveiro',
        body: DegradeFundo(
          child: _carregando
              ? const Center(child: CircularProgressIndicator())
              : _viveirosComCiclo.isEmpty
              ? _buildSemViveiros()
              : _buildListaViveiros(),
        ),
      ),
    );
  }

  Widget _buildSemViveiros() {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline, size: 64, color: Colors.orange.shade600),
              const SizedBox(height: 16),
              const Text(
                'Nenhum Viveiro Disponível',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Não há viveiros com ciclos ativos para despesca.',
                style: TextStyle(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _carregarDados,
                icon: const Icon(Icons.refresh),
                label: const Text('Atualizar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListaViveiros() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _viveirosComCiclo.length,
      itemBuilder: (context, index) {
        final codigo = _viveirosComCiclo.keys.elementAt(index);
        final viveiro = _viveirosComCiclo[codigo]!;
        final temDespescaAtiva = _despescasAtivas.containsKey(codigo);
        final despesca = temDespescaAtiva ? _despescasAtivas[codigo]! : null;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: temDespescaAtiva
                  ? Colors.orange.shade600
                  : Colors.green.shade600,
              child: Text(
                codigo,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              '$codigo - ${viveiro['nome']}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Área: ${viveiro['area']} ha'),
                const SizedBox(height: 4),
                if (temDespescaAtiva) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.warning,
                        size: 16,
                        color: Colors.orange.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Despesca em andamento',
                        style: TextStyle(
                          color: Colors.orange.shade600,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Status: ${_getStatusTexto(despesca!['statusDespesca'])}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Colors.green.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Disponível para despesca',
                        style: TextStyle(color: Colors.green.shade600),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            trailing: temDespescaAtiva
                ? ElevatedButton.icon(
                    onPressed: () =>
                        _continuarDespesca(codigo, despesca!['id']),
                    icon: const Icon(Icons.edit),
                    label: const Text('Continuar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: () => _iniciarNovaDespesca(codigo),
                    icon: const Icon(Icons.add),
                    label: const Text('Iniciar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
          ),
        );
      },
    );
  }

  String _getStatusTexto(String status) {
    switch (status) {
      case 'planejada':
        return 'Planejada';
      case 'em_andamento':
        return 'Em Andamento';
      case 'concluida':
        return 'Concluída';
      case 'auditada':
        return 'Auditada';
      default:
        return status;
    }
  }
}
