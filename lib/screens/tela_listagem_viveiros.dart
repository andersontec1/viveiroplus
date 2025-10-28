import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/app_scaffold.dart';
import 'tela_editar_viveiro.dart';
import 'tela_detalhes_viveiro.dart';
import 'tela_cadastro_viveiro.dart';
import '../widgets/degrade_fundo.dart';
import '../widgets/responsive_center.dart';
import '../helpers/confirmation_helper.dart';
import '../helpers/audit_helper.dart';
import '../helpers/security_helper.dart';

class TelaListagemViveiros extends StatefulWidget {
  const TelaListagemViveiros({super.key, this.funcaoUsuario});
  final String? funcaoUsuario;
  @override
  _TelaListagemViveirosState createState() => _TelaListagemViveirosState();
}

class _TelaListagemViveirosState extends State<TelaListagemViveiros> {
  static const List<String> _filtros = ['Todos', 'Viveiro'];
  String _filtroSelecionado = _filtros.first;
  bool _podeExcluir = false;

  @override
  void initState() {
    super.initState();
    _carregarPermissoes();
  }

  Future<void> _carregarPermissoes() async {
    try {
      final adm = await SecurityHelper.temFuncaoAdministrativa();
      if (mounted) setState(() => _podeExcluir = adm);
    } catch (_) {}
  }

  // Verifica dependências antes de excluir um viveiro
  Future<String?> _validarExclusaoViveiro(String codigo) async {
    try {
      // Ciclo ativo bloqueia
      final ciclosAtivos = await FirebaseFirestore.instance
          .collection('ciclos')
          .where('codigo', isEqualTo: codigo)
          .where('encerrado', isEqualTo: false)
          .limit(1)
          .get();
      if (ciclosAtivos.docs.isNotEmpty) {
        return 'Existe um ciclo ativo para este viveiro. Encerre o ciclo antes de excluir.';
      }

      // Outras referências: ração, análises, despescas
      final racao = await FirebaseFirestore.instance
          .collection('racao')
          .where('tipoDestino', isEqualTo: 'viveiro')
          .where('codigoDestino', isEqualTo: codigo)
          .limit(1)
          .get();
      final analises = await FirebaseFirestore.instance
          .collection('registros_diarios')
          .where('tipoDestino', isEqualTo: 'viveiro')
          .where('codigo', isEqualTo: codigo)
          .limit(1)
          .get();
      final despescas = await FirebaseFirestore.instance
          .collection('despescas')
          .where('codigo', isEqualTo: codigo)
          .limit(1)
          .get();

      final temOutrasRefs =
          racao.docs.isNotEmpty ||
          analises.docs.isNotEmpty ||
          despescas.docs.isNotEmpty;
      if (temOutrasRefs) {
        return 'Existem registros relacionados (Ração, Análises ou Despesca). Por integridade, exclua-os ou arquive o viveiro.';
      }
    } catch (e) {
      // Em caso de falha, por segurança, não excluir
      return 'Não foi possível verificar dependências: ${e.toString()}';
    }
    return null; // Pode excluir
  }

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance.collection('viveiros');
    if (_filtroSelecionado == 'Viveiro') {
      query = query.where('temBercario', isEqualTo: false);
    }
    query = query.orderBy('codigo');

    return AppScaffold(
      title: 'Viveiros',
      backgroundColor: Colors.transparent,
      body: DegradeFundo(
        child: SafeArea(
          child: ResponsiveCenter(
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                const SizedBox(height: 10),
                const Center(
                  child: Column(
                    children: [
                      Icon(Icons.water, size: 48, color: Colors.teal),
                      SizedBox(height: 6),
                      Text(
                        'Viveiros',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Gerencie e visualize todos os viveiros cadastrados',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.teal,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      SizedBox(height: 16),
                    ],
                  ),
                ),
                // Botão de cadastrar viveiro
                if (widget.funcaoUsuario == 'admin' ||
                    widget.funcaoUsuario == 'gerente')
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final resultado = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TelaCadastroViveiro(),
                            ),
                          );
                          if (resultado == true && mounted) {
                            setState(() {});
                          }
                        },
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: const Text(
                          'Cadastrar Novo Viveiro',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: DropdownButtonFormField<String>(
                    initialValue: _filtroSelecionado,
                    decoration: InputDecoration(
                      labelText: 'Filtrar por tipo',
                      labelStyle: Theme.of(context).textTheme.bodyLarge,
                      border: const OutlineInputBorder(),
                    ),
                    style: Theme.of(context).textTheme.bodyLarge,
                    items: _filtros
                        .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                        .toList(),
                    onChanged: (v) => setState(() => _filtroSelecionado = v!),
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
                        return Center(
                          child: Text(
                            'Nenhum viveiro encontrado.',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        );
                      }

                      return ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: docs.length,
                        itemBuilder: (context, i) {
                          final doc = docs[i];
                          final data = doc.data()! as Map<String, dynamic>;
                          final nome = data['nome'] ?? '—';
                          final codigo = data['codigo'] ?? '';
                          final temB = data['temBercario'] as bool? ?? false;
                          final area = data['area'] ?? '-';
                          final volume = data['volume'] ?? '-';
                          final ts = (data['criadoEm'] as Timestamp?)?.toDate();
                          final criadoStr = ts != null
                              ? DateFormat('dd/MM/yyyy HH:mm').format(ts)
                              : 'Data desconhecida';

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 3,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TelaDetalhesViveiro(
                                    docId: doc.id,
                                    codigo: codigo,
                                    nome: nome,
                                    dadosViveiro: data,
                                  ),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  children: [
                                    Icon(
                                      temB ? Icons.spa : Icons.water,
                                      color: temB ? Colors.green : Colors.blue,
                                      size: 36,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '$nome  (cód: $codigo)',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                          ),
                                          Row(
                                            children: [
                                              Text(
                                                'Área: $area m²',
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodySmall,
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                'Volume: $volume m³',
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodySmall,
                                              ),
                                            ],
                                          ),
                                          Text(
                                            'Possui berçário: ${temB ? 'Sim' : 'Não'}',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                          Text(
                                            criadoStr,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      onSelected: (value) async {
                                        if (value == 'editar') {
                                          final atualizado =
                                              await Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      TelaEditarViveiro(
                                                        docId: doc.id,
                                                        dados: data,
                                                      ),
                                                ),
                                              );
                                          if (atualizado == true && mounted) {
                                            setState(() {});
                                          }
                                        } else if (value == 'excluir') {
                                          if (!_podeExcluir) return;
                                          // Checar dependências antes de confirmar
                                          final motivoBloqueio =
                                              await _validarExclusaoViveiro(
                                                codigo,
                                              );
                                          if (motivoBloqueio != null) {
                                            await ConfirmationHelper.showError(
                                              context: context,
                                              title: 'Exclusão bloqueada',
                                              content: motivoBloqueio,
                                            );
                                            return;
                                          }
                                          final confirmou =
                                              await ConfirmationHelper.showDoubleConfirmation(
                                                context: context,
                                                title: 'Excluir Viveiro',
                                                content:
                                                    'Tem certeza que deseja excluir "$nome" (cód: $codigo)?',
                                                secondTitle:
                                                    'Confirma exclusão?',
                                                secondContent:
                                                    'Esta ação é irreversível. Deseja realmente excluir?',
                                                actionLabel: 'Excluir',
                                                actionColor: Colors.red,
                                              );
                                          if (confirmou != true) return;
                                          try {
                                            await doc.reference.delete();
                                            await AuditHelper.registrarAcao(
                                              acao: 'VIVEIRO_EXCLUIDO',
                                              modulo: 'VIVEIROS',
                                              detalhes: {
                                                'docId': doc.id,
                                                'codigo': codigo,
                                                'nome': nome,
                                              },
                                            );
                                            if (mounted) {
                                              await ConfirmationHelper.showSuccess(
                                                context: context,
                                                title: 'Viveiro excluído',
                                                content:
                                                    'O viveiro foi removido com sucesso.',
                                              );
                                              setState(() {});
                                            }
                                          } catch (e) {
                                            if (mounted) {
                                              await ConfirmationHelper.showError(
                                                context: context,
                                                content:
                                                    'Não foi possível excluir o viveiro.',
                                                error: e.toString(),
                                              );
                                            }
                                          }
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        if (widget.funcaoUsuario !=
                                            'arraçoador')
                                          const PopupMenuItem(
                                            value: 'editar',
                                            child: ListTile(
                                              leading: Icon(Icons.edit),
                                              title: Text('Editar'),
                                            ),
                                          ),
                                        if (_podeExcluir)
                                          const PopupMenuItem(
                                            value: 'excluir',
                                            child: ListTile(
                                              leading: Icon(Icons.delete),
                                              title: Text('Excluir'),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
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
        ),
      ),
    );
  }
}
