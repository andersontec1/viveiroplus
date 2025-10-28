import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/degrade_fundo.dart';
import 'tela_editar_bercario.dart';
import 'tela_detalhes_bercario.dart';
import 'tela_cadastro_viveiro.dart';
import '../widgets/responsive_center.dart';
import '../helpers/confirmation_helper.dart';
import '../helpers/audit_helper.dart';
import '../helpers/security_helper.dart';

class TelaListagemBercarios extends StatefulWidget {
  const TelaListagemBercarios({super.key});

  @override
  State<TelaListagemBercarios> createState() => _TelaListagemBercariosState();
}

class _TelaListagemBercariosState extends State<TelaListagemBercarios> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
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

  // Verifica dependências antes de excluir um berçário
  Future<String?> _validarExclusaoBercario(String codigo) async {
    try {
      // Ciclo ativo bloqueia
      final ciclosAtivos = await FirebaseFirestore.instance
          .collection('ciclos')
          .where('codigo', isEqualTo: codigo)
          .where('encerrado', isEqualTo: false)
          .limit(1)
          .get();
      if (ciclosAtivos.docs.isNotEmpty) {
        return 'Existe um ciclo ativo para este berçário. Encerre o ciclo antes de excluir.';
      }

      // Outras referências: ração, análises, despescas
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
  Widget build(BuildContext context) {
    final bercariosQuery = FirebaseFirestore.instance
        .collection('bercarios')
        .orderBy('codigo');

    return AppScaffold(
      title: 'Berçários',
      body: DegradeFundo(
        child: ResponsiveCenter(
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              const SizedBox(height: 10),
              const Center(
                child: Column(
                  children: [
                    Icon(Icons.spa, size: 48, color: Colors.green),
                    SizedBox(height: 6),
                    Text(
                      'Berçários',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Gerencie e visualize todos os berçários cadastrados',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.green,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    SizedBox(height: 16),
                  ],
                ),
              ),
              // Botão de cadastrar berçário (usando cadastro de viveiro)
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
                      'Cadastrar Novo Berçário',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
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
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchText = v),
                  decoration: InputDecoration(
                    hintText: 'Buscar por nome ou código',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.9),
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: bercariosQuery.snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data?.docs ?? [];
                    final filteredDocs = docs.where((doc) {
                      final data = doc.data()! as Map<String, dynamic>;
                      final nome = (data['nome'] ?? '')
                          .toString()
                          .toLowerCase();
                      final codigo = (data['codigo'] ?? '')
                          .toString()
                          .toLowerCase();
                      return _searchText.isEmpty ||
                          nome.contains(_searchText.toLowerCase()) ||
                          codigo.contains(_searchText.toLowerCase());
                    }).toList();

                    if (filteredDocs.isEmpty) {
                      return const Center(
                        child: Text('Nenhum berçário encontrado.'),
                      );
                    }

                    return ListView.separated(
                      itemCount: filteredDocs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final doc = filteredDocs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final codigo = data['codigo'] ?? '---';
                        final nome = data['nome'] ?? 'Sem nome';
                        final docId = doc.id;
                        return Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 2,
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TelaDetalhesBercario(
                                  docId: docId,
                                  codigo: data['codigo'] ?? '',
                                  nome: data['nome'] ?? '—',
                                  dadosBercario: data,
                                ),
                              ),
                            ),
                            child: ListTile(
                              leading: Padding(
                                padding: const EdgeInsets.all(2.0),
                                child: Image.asset(
                                  'assets/images/camaraoico.png',
                                  width: 32,
                                  height: 32,
                                ),
                              ),
                              title: Text(
                                nome,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                'Código: $codigo',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) async {
                                  if (value == 'editar') {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => TelaEditarBercario(
                                          docId: docId,
                                          dados: data,
                                        ),
                                      ),
                                    );
                                  } else if (value == 'excluir') {
                                    if (!_podeExcluir) return;
                                    final motivo =
                                        await _validarExclusaoBercario(codigo);
                                    if (motivo != null) {
                                      await ConfirmationHelper.showError(
                                        context: context,
                                        title: 'Exclusão bloqueada',
                                        content: motivo,
                                      );
                                      return;
                                    }
                                    final confirmou =
                                        await ConfirmationHelper.showDoubleConfirmation(
                                          context: context,
                                          title: 'Excluir Berçário',
                                          content:
                                              'Tem certeza que deseja excluir "$nome" (cód: $codigo)?',
                                          secondTitle: 'Confirma exclusão?',
                                          secondContent:
                                              'Esta ação é irreversível. Deseja realmente excluir?',
                                          actionLabel: 'Excluir',
                                          actionColor: Colors.red,
                                        );
                                    if (confirmou != true) return;
                                    try {
                                      await FirebaseFirestore.instance
                                          .collection('bercarios')
                                          .doc(docId)
                                          .delete();
                                      await AuditHelper.registrarAcao(
                                        acao: 'BERCARIO_EXCLUIDO',
                                        modulo: 'BERCARIOS',
                                        detalhes: {
                                          'docId': docId,
                                          'codigo': codigo,
                                          'nome': nome,
                                        },
                                      );
                                      if (mounted) {
                                        await ConfirmationHelper.showSuccess(
                                          context: context,
                                          title: 'Berçário excluído',
                                          content:
                                              'O berçário foi removido com sucesso.',
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        await ConfirmationHelper.showError(
                                          context: context,
                                          content:
                                              'Não foi possível excluir o berçário.',
                                          error: e.toString(),
                                        );
                                      }
                                    }
                                  }
                                },
                                itemBuilder: (context) => [
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
    );
  }
}
